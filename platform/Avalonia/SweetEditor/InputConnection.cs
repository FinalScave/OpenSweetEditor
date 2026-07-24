#nullable enable
using System;
using System.Collections.Generic;
using Avalonia.Input.TextInput;
using AvaloniaRect = Avalonia.Rect;

namespace SweetEditor {
	internal sealed class InputConnection : IDisposable {
		private const long SurroundingTextMarginUtf16 = 4096;

		private readonly SweetEditorControl owner;
		private ImeState state = new();
		private ImeTextContext? context;
		private EditorTextInputClient? client;
		private ImeSelection? pendingCompositionBaseline;
		private ImeOffsetRange? pendingCompositionTarget;
		private bool compositionEnabled = true;
		private bool contextValid;
		private bool applyingImeCommands;
		private bool restartBlocked;
		private bool pendingSelectionChanged;
		private bool pendingSurroundingTextChanged;
		private bool pendingCursorRectangleChanged;
		private bool disposed;

		internal InputConnection(SweetEditorControl owner) {
			this.owner = owner;
		}

		internal bool IsActive => state.ResultCode == ImeResultCode.OK && state.SessionId > 0;

		internal bool HasComposition => IsRange(state.CompositionRange);

		internal void BeginSession(bool newGeneration = false) {
			if (newGeneration) {
				restartBlocked = false;
			}
			if (disposed || IsActive || restartBlocked || !owner.CanBeginImeSession) {
				return;
			}

			ImeState next = owner.EditorCoreInternal.BeginImeSession(ImeMutationModel.COMMAND);
			if (next.ResultCode != ImeResultCode.OK || next.SessionId <= 0) {
				return;
			}

			state = next;
			client = new EditorTextInputClient(this, next.SessionId);
			context = null;
			contextValid = false;
			pendingSelectionChanged = true;
			pendingSurroundingTextChanged = true;
			pendingCursorRectangleChanged = true;
		}

		internal void EndSession(bool resetNativeComposition) {
			long sessionId = IsActive ? state.SessionId : 0;
			EditorTextInputClient? previousClient = client;
			restartBlocked = true;
			ClearBinding();
			if (sessionId > 0) {
				owner.DispatchEditorActionResult(owner.EditorCoreInternal.EndImeSession(sessionId));
			}
			if (resetNativeComposition) {
				previousClient?.NotifyReset();
			}
		}

		internal TextInputMethodClient? GetClient() {
			BeginSession();
			if (!IsActive || client == null) {
				return null;
			}
			if (!contextValid && !RefreshContext()) {
				EndSession(true);
				return null;
			}
			return client;
		}

		internal void SetCompositionEnabled(bool enabled) {
			if (compositionEnabled == enabled) {
				return;
			}

			compositionEnabled = enabled;
			if (!enabled) {
				ClearPendingCompositionTarget();
			}
			owner.EditorCoreInternal.SetCompositionEnabled(enabled);
			if (!enabled && HasComposition) {
				Apply(Command(ImeCommandKind.CANCEL_COMPOSITION));
				client?.NotifyReset();
			}
		}

		internal bool CommitText(string text) {
			BeginSession();
			if (!IsActive) {
				return restartBlocked;
			}
			ClearPendingCompositionTarget();
			Apply(new ImeCommand { Kind = ImeCommandKind.COMMIT_TEXT, Text = text });
			return true;
		}

		internal bool CancelComposition() {
			if (!HasComposition) {
				return false;
			}
			ClearPendingCompositionTarget();
			Apply(Command(ImeCommandKind.CANCEL_COMPOSITION));
			client?.NotifyReset();
			return true;
		}

		internal void Synchronize(EditorActionResult result) {
			if (disposed) {
				return;
			}
			if (result.ImeHostAction != ImeHostAction.NONE) {
				EditorTextInputClient? previousClient = client;
				restartBlocked = true;
				ClearBinding();
				previousClient?.NotifyReset();
				return;
			}
			if (!IsActive) {
				return;
			}

			bool hadComposition = HasComposition;
			ImeState next = result.ImeState;
			if (next.ResultCode == ImeResultCode.OK && next.SessionId == state.SessionId) {
				state = next;
			}

			if (!applyingImeCommands &&
			    (result.ContentChanged || result.CursorChanged || result.SelectionChanged || result.CompositionChanged)) {
				ClearPendingCompositionTarget();
			}
			if (result.ContentChanged || result.CursorChanged || result.SelectionChanged || result.CompositionChanged) {
				contextValid = false;
			}
			if (!applyingImeCommands) {
				pendingSelectionChanged |= result.CursorChanged || result.SelectionChanged || result.CompositionChanged;
				pendingSurroundingTextChanged |= result.ContentChanged || result.CompositionChanged;
			}
			pendingCursorRectangleChanged |= result.CursorChanged || result.SelectionChanged ||
			                                 result.CompositionChanged || result.ScrollChanged || result.ScaleChanged;
			if (!applyingImeCommands && hadComposition && !HasComposition && result.CompositionChanged) {
				NotifyStateChanged(force: true);
			}
		}

		internal void NotifyStateChanged(bool textViewChanged = false, bool force = false) {
			if (!IsActive || client == null) {
				return;
			}
			if (!contextValid && !RefreshContext()) {
				EndSession(true);
				return;
			}

			client.NotifyStateChanged(
				textViewChanged,
				force || pendingSelectionChanged,
				force || pendingSurroundingTextChanged,
				force || pendingCursorRectangleChanged);
			pendingSelectionChanged = false;
			pendingSurroundingTextChanged = false;
			pendingCursorRectangleChanged = false;
		}

		public void Dispose() {
			if (disposed) {
				return;
			}
			EndSession(false);
			disposed = true;
		}

		private void ApplyPreeditText(EditorTextInputClient source, long sessionId, string? preeditText,
			int? cursorPosition) {
			if (!IsCurrent(source, sessionId) || !compositionEnabled) {
				return;
			}
			if (preeditText == null) {
				ClearPendingCompositionTarget();
				if (HasComposition) {
					Apply(Command(ImeCommandKind.CANCEL_COMPOSITION));
				}
				return;
			}

			string text = preeditText;
			if (text.Length == 0 && !HasComposition) {
				return;
			}

			ImeCommand command = new() {
				Kind = ImeCommandKind.UPDATE_COMPOSITION,
				Text = text
			};
			if (cursorPosition is int offset && IsValidUtf16Offset(text, offset)) {
				command.SelectionAfter = Selection(ImeCoordinateSpace.COMPOSITION, offset, offset);
			}

			if (!HasComposition &&
			    pendingCompositionBaseline is { } baseline &&
			    pendingCompositionTarget is { } target &&
			    SelectionMatchesRange(state.Selection, target)) {
				ClearPendingCompositionTarget();
				command.TargetRange = target;
				Apply(
					new ImeCommand {
						Kind = ImeCommandKind.SET_SELECTION,
						SelectionAfter = baseline
					},
					command);
				return;
			}

			ClearPendingCompositionTarget();
			Apply(command);
		}

		private string GetSurroundingText(EditorTextInputClient source, long sessionId) {
			return EnsureContext(source, sessionId) ? context!.Text : string.Empty;
		}

		private TextSelection GetSelection(EditorTextInputClient source, long sessionId) {
			if (!EnsureContext(source, sessionId) ||
			    !TryGetLocalSelection(context!, out int start, out int end)) {
				return new TextSelection(0, 0);
			}
			return new TextSelection(start, end);
		}

		private void SetSelection(EditorTextInputClient source, long sessionId, TextSelection selection) {
			if (!IsCurrent(source, sessionId)) {
				return;
			}
			if ((!contextValid || context == null) && !RefreshContext()) {
				EndSession(true);
				return;
			}
			ImeTextContext currentContext = context!;
			if (selection.Start < 0 || selection.End < 0 ||
			    selection.Start > currentContext.Text.Length || selection.End > currentContext.Text.Length) {
				EndSession(true);
				return;
			}

			if (currentContext.SliceStartUtf16 > long.MaxValue - selection.Start ||
			    currentContext.SliceStartUtf16 > long.MaxValue - selection.End) {
				EndSession(true);
				return;
			}

			long start = currentContext.SliceStartUtf16 + selection.Start;
			long end = currentContext.SliceStartUtf16 + selection.End;
			ImeSelection next = PreserveSelectionDirection(start, end);
			ImeSelection baseline = CopySelection(state.Selection);
			bool compositionTargetCandidate = !HasComposition && start != end;
			ClearPendingCompositionTarget();
			Apply(new ImeCommand {
				Kind = ImeCommandKind.SET_SELECTION,
				SelectionAfter = next
			});
			if (compositionTargetCandidate && IsActive && !HasComposition &&
			    IsSelection(baseline) && SelectionMatchesRange(state.Selection, start, end)) {
				pendingCompositionBaseline = baseline;
				pendingCompositionTarget = new ImeOffsetRange {
					CoordinateSpace = ImeCoordinateSpace.DOCUMENT,
					StartUtf16 = Math.Min(start, end),
					EndUtf16 = Math.Max(start, end)
				};
			}
		}

		private ImeSelection PreserveSelectionDirection(long start, long end) {
			long normalizedStart = Math.Min(start, end);
			long normalizedEnd = Math.Max(start, end);
			if (IsSelection(state.Selection) &&
			    Math.Min(state.Selection.AnchorUtf16, state.Selection.ActiveUtf16) == normalizedStart &&
			    Math.Max(state.Selection.AnchorUtf16, state.Selection.ActiveUtf16) == normalizedEnd) {
				return state.Selection;
			}
			return Selection(ImeCoordinateSpace.DOCUMENT, start, end);
		}

		private void ExecuteContextMenuAction(EditorTextInputClient source, long sessionId, ContextMenuAction action) {
			if (IsCurrent(source, sessionId)) {
				owner.ExecuteTextInputContextMenuAction(action);
			}
		}

		private void Apply(params ImeCommand[] commands) {
			if (!IsActive || commands.Length == 0) {
				return;
			}

			pendingSelectionChanged = false;
			pendingSurroundingTextChanged = false;
			long sessionId = state.SessionId;
			bool wasApplyingImeCommands = applyingImeCommands;
			applyingImeCommands = true;
			EditorActionResult result;
			try {
				result = owner.EditorCoreInternal.ApplyImeCommands(new ImeCommandBatch {
					SessionId = sessionId,
					Commands = new List<ImeCommand>(commands)
				});
				owner.DispatchEditorActionResult(result);
			} finally {
				applyingImeCommands = wasApplyingImeCommands;
			}
			ImeResultCode resultCode = result.ImeState.ResultCode;
			if (IsActive && state.SessionId == sessionId && result.ImeHostAction == ImeHostAction.NONE &&
			    resultCode is ImeResultCode.SESSION_MISMATCH or ImeResultCode.REJECTED or ImeResultCode.READ_ONLY) {
				EndSession(true);
			}
		}

		private bool RefreshContext() {
			if (!IsActive || !IsSelection(state.Selection)) {
				return false;
			}

			long first = Math.Min(state.Selection.AnchorUtf16, state.Selection.ActiveUtf16);
			long last = Math.Max(state.Selection.AnchorUtf16, state.Selection.ActiveUtf16);
			if (IsRange(state.CompositionRange)) {
				first = Math.Min(first, state.CompositionRange.StartUtf16);
				last = Math.Max(last, state.CompositionRange.EndUtf16);
			}

			long start = Math.Max(0, first - Math.Min(first, SurroundingTextMarginUtf16));
			long end = last > long.MaxValue - SurroundingTextMarginUtf16
				? long.MaxValue
				: last + SurroundingTextMarginUtf16;
			ImeTextContext next = owner.EditorCoreInternal.GetImeContext(
				state.SessionId, ImeTextSource.COMMITTED, start, end - start);
			if (next.ResultCode != ImeResultCode.OK ||
			    !TryGetLocalSelection(next, out _, out _)) {
				return false;
			}

			context = next;
			contextValid = true;
			return true;
		}

		private static bool TryGetLocalSelection(ImeTextContext source, out int start, out int end) {
			start = 0;
			end = 0;
			if (!IsSelection(source.Selection)) {
				return false;
			}

			long sliceStart = source.SliceStartUtf16;
			if (sliceStart < 0 || sliceStart > long.MaxValue - source.Text.Length) {
				return false;
			}
			long sliceEnd = sliceStart + source.Text.Length;
			long normalizedStart = Math.Min(source.Selection.AnchorUtf16, source.Selection.ActiveUtf16);
			long normalizedEnd = Math.Max(source.Selection.AnchorUtf16, source.Selection.ActiveUtf16);
			if (normalizedStart < sliceStart || normalizedEnd > sliceEnd) {
				return false;
			}

			long localStart = normalizedStart - sliceStart;
			long localEnd = normalizedEnd - sliceStart;
			if (localStart > int.MaxValue || localEnd > int.MaxValue) {
				return false;
			}
			start = (int)localStart;
			end = (int)localEnd;
			return true;
		}

		private bool EnsureContext(EditorTextInputClient source, long sessionId) {
			return IsCurrent(source, sessionId) &&
			       ((contextValid && context != null) || RefreshContext());
		}

		private bool IsCurrent(EditorTextInputClient source, long sessionId) {
			return IsActive && sessionId == state.SessionId && ReferenceEquals(source, client);
		}

		private void ClearBinding() {
			state = new ImeState();
			context = null;
			client = null;
			ClearPendingCompositionTarget();
			contextValid = false;
			pendingSelectionChanged = false;
			pendingSurroundingTextChanged = false;
			pendingCursorRectangleChanged = false;
		}

		private void ClearPendingCompositionTarget() {
			pendingCompositionBaseline = null;
			pendingCompositionTarget = null;
		}

		private static ImeCommand Command(ImeCommandKind kind) => new() { Kind = kind };

		private static ImeSelection Selection(ImeCoordinateSpace space, long anchor, long active) => new() {
			CoordinateSpace = space,
			AnchorUtf16 = anchor,
			ActiveUtf16 = active,
			Affinity = anchor == active ? CaretAffinity.DOWNSTREAM : CaretAffinity.UPSTREAM
		};

		private static bool IsRange(ImeOffsetRange range) {
			return range.StartUtf16 >= 0 && range.EndUtf16 >= range.StartUtf16;
		}

		private static bool IsSelection(ImeSelection selection) {
			return selection.AnchorUtf16 >= 0 && selection.ActiveUtf16 >= 0;
		}

		private static ImeSelection CopySelection(ImeSelection selection) {
			return new ImeSelection {
				CoordinateSpace = selection.CoordinateSpace,
				AnchorUtf16 = selection.AnchorUtf16,
				ActiveUtf16 = selection.ActiveUtf16,
				Affinity = selection.Affinity
			};
		}

		private static bool SelectionMatchesRange(ImeSelection selection, ImeOffsetRange range) {
			return range.CoordinateSpace == ImeCoordinateSpace.DOCUMENT &&
			       SelectionMatchesRange(selection, range.StartUtf16, range.EndUtf16);
		}

		private static bool SelectionMatchesRange(ImeSelection selection, long start, long end) {
			return IsSelection(selection) &&
			       Math.Min(selection.AnchorUtf16, selection.ActiveUtf16) == Math.Min(start, end) &&
			       Math.Max(selection.AnchorUtf16, selection.ActiveUtf16) == Math.Max(start, end);
		}

		private static bool IsValidUtf16Offset(string text, int offset) {
			if (offset < 0 || offset > text.Length) {
				return false;
			}
			return offset == 0 || offset == text.Length ||
			       !(char.IsHighSurrogate(text[offset - 1]) && char.IsLowSurrogate(text[offset]));
		}

		private sealed class EditorTextInputClient : TextInputMethodClient {
			private readonly InputConnection owner;
			private readonly long sessionId;

			internal EditorTextInputClient(InputConnection owner, long sessionId) {
				this.owner = owner;
				this.sessionId = sessionId;
			}

			public override global::Avalonia.Visual TextViewVisual => owner.owner;

			public override bool SupportsPreedit => owner.compositionEnabled;

			public override bool SupportsSurroundingText => true;

			public override string SurroundingText => owner.GetSurroundingText(this, sessionId);

			public override AvaloniaRect CursorRectangle => owner.owner.GetTextInputCursorRectangle();

			public override TextSelection Selection {
				get => owner.GetSelection(this, sessionId);
				set => owner.SetSelection(this, sessionId, value);
			}

			public override void SetPreeditText(string? preeditText) {
				SetPreeditText(preeditText, null);
			}

			public override void SetPreeditText(string? preeditText, int? cursorPosition) {
				owner.ApplyPreeditText(this, sessionId, preeditText, cursorPosition);
			}

			public override void ExecuteContextMenuAction(ContextMenuAction action) {
				owner.ExecuteContextMenuAction(this, sessionId, action);
			}

			internal void NotifyStateChanged(bool textViewChanged, bool selectionChanged,
				bool surroundingTextChanged, bool cursorRectangleChanged) {
				if (textViewChanged) {
					RaiseTextViewVisualChanged();
				}
				if (selectionChanged) {
					RaiseSelectionChanged();
				}
				if (surroundingTextChanged) {
					RaiseSurroundingTextChanged();
				}
				if (cursorRectangleChanged) {
					RaiseCursorRectangleChanged();
				}
			}

			internal void NotifyReset() {
				RequestReset();
			}
		}
	}
}
