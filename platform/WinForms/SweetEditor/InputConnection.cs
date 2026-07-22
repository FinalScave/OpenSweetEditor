#nullable enable
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace SweetEditor {
	internal sealed class InputConnection : IDisposable {
		internal const int WmImeStartComposition = 0x010D;
		internal const int WmImeEndComposition = 0x010E;
		internal const int WmImeComposition = 0x010F;
		internal const int WmImeChar = 0x0286;
		internal const int WmChar = 0x0102;

		private const int GcsCompReadStr = 0x0001;
		private const int GcsCompReadAttr = 0x0002;
		private const int GcsCompReadClause = 0x0004;
		private const int GcsCompStr = 0x0008;
		private const int GcsCompAttr = 0x0010;
		private const int GcsCompClause = 0x0020;
		private const int GcsCursorPos = 0x0080;
		private const int GcsDeltaStart = 0x0100;
		private const int GcsResultReadStr = 0x0200;
		private const int GcsResultReadClause = 0x0400;
		private const int GcsResultStr = 0x0800;
		private const int GcsResultClause = 0x1000;
		private const int CsInsertChar = 0x2000;
		private const int CsNoMoveCaret = 0x4000;
		private const int MetadataMask = GcsCompReadStr | GcsCompReadAttr | GcsCompReadClause |
			GcsCompAttr | GcsCompClause | GcsDeltaStart | GcsResultReadStr |
			GcsResultReadClause | GcsResultClause;
		private const int ImmErrorNoData = -1;
		private const int NiCompositionStr = 0x0015;
		private const int CpsCancel = 0x0004;

		[DllImport("imm32.dll")]
		private static extern IntPtr ImmGetContext(IntPtr hWnd);

		[DllImport("imm32.dll")]
		private static extern bool ImmReleaseContext(IntPtr hWnd, IntPtr hIMC);

		[DllImport("imm32.dll", CharSet = CharSet.Unicode)]
		private static extern int ImmGetCompositionString(IntPtr hIMC, int index, byte[]? buffer, int bufferLength);

		[DllImport("imm32.dll")]
		private static extern bool ImmNotifyIME(IntPtr hIMC, int action, int index, int value);

		private readonly SweetEditorControl owner;
		private ImeState state = new();
		private string expectedImeChars = string.Empty;
		private int expectedImeCharIndex;
		private char? pendingWmChar;
		private char? pendingImeHighSurrogate;
		private bool restartBlocked;
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
			if (disposed || IsActive || !owner.Focused || owner.EditorCoreInternal.IsReadOnly() ||
			    owner.EditorCoreInternal.GetDocument() == null || restartBlocked) {
				return;
			}

			ImeState next = owner.EditorCoreInternal.BeginImeSession(ImeMutationModel.COMMAND);
			if (next.ResultCode == ImeResultCode.OK && next.SessionId > 0) {
				state = next;
			}
		}

		internal void EndSession(bool cancelNativeComposition) {
			long sessionId = IsActive ? state.SessionId : 0;
			restartBlocked = true;
			ClearBinding();
			if (sessionId > 0) {
				owner.DispatchEditorActionResult(owner.EditorCoreInternal.EndImeSession(sessionId));
			}
			if (cancelNativeComposition) {
				ScheduleNativeCompositionCancel();
			}
		}

		internal void Synchronize(EditorActionResult result) {
			if (disposed) {
				return;
			}
			if (result.ImeHostAction != ImeHostAction.NONE) {
				restartBlocked = true;
				ClearBinding();
				ScheduleNativeCompositionCancel();
				return;
			}
			if (IsActive && owner.EditorCoreInternal.IsReadOnly()) {
				EndSession(true);
				return;
			}

			ImeState next = result.ImeState;
			if (IsActive && next.ResultCode == ImeResultCode.OK && next.SessionId == state.SessionId) {
				state = next;
			}
		}

		internal bool HandleWindowMessage(ref Message message) {
			if (disposed) {
				return false;
			}

			switch (message.Msg) {
				case WmImeStartComposition:
					HandleStartComposition();
					return false;
				case WmImeComposition:
					HandleComposition(message.WParam, message.LParam);
					message.Result = IntPtr.Zero;
					return true;
				case WmImeEndComposition:
					if (HasComposition) {
						EndSession(false);
					}
					return false;
				case WmImeChar:
					HandleImeChar((char)(message.WParam.ToInt64() & 0xFFFF));
					message.Result = IntPtr.Zero;
					return true;
				case WmChar:
					char character = (char)(message.WParam.ToInt64() & 0xFFFF);
					if (pendingWmChar == character) {
						pendingWmChar = null;
						message.Result = IntPtr.Zero;
						return true;
					}
					pendingWmChar = null;
					expectedImeChars = string.Empty;
					expectedImeCharIndex = 0;
					return false;
				default:
					return false;
			}
		}

		private void HandleStartComposition() {
			BeginSession(true);
			if (!IsActive || HasComposition || !IsSelection(state.Selection)) {
				return;
			}

			long start = Math.Min(state.Selection.AnchorUtf16, state.Selection.ActiveUtf16);
			long end = Math.Max(state.Selection.AnchorUtf16, state.Selection.ActiveUtf16);
			Apply(new ImeCommand {
				Kind = ImeCommandKind.BEGIN_COMPOSITION,
				TargetRange = Range(ImeCoordinateSpace.DOCUMENT, start, end)
			});
		}

		private void HandleComposition(IntPtr wParam, IntPtr lParam) {
			EnsureSession();
			if (!IsActive) {
				return;
			}

			int flags = unchecked((int)lParam.ToInt64());
			bool hasResult = (flags & GcsResultStr) != 0;
			bool hasComposition = (flags & GcsCompStr) != 0;
			bool hasCursor = (flags & GcsCursorPos) != 0;
			bool insertCharacter = (flags & CsInsertChar) != 0 && !hasResult && !hasComposition;
			if (!hasResult && !hasComposition && !hasCursor && !insertCharacter) {
				if ((flags & MetadataMask) == 0 && HasComposition) {
					Apply(Command(ImeCommandKind.CANCEL_COMPOSITION));
				}
				return;
			}

			IntPtr hIMC = ImmGetContext(owner.Handle);
			if (hIMC == IntPtr.Zero) {
				CloseAfterNativeReadFailure();
				return;
			}

			try {
				if (!TryBuildCompositionCommands(hIMC, wParam, flags, hasResult, hasComposition, hasCursor,
						insertCharacter, out List<ImeCommand> commands, out string resultText)) {
					CloseAfterNativeReadFailure();
					return;
				}
				if (commands.Count == 0) {
					return;
				}

				EditorActionResult result = owner.EditorCoreInternal.ApplyImeCommands(new ImeCommandBatch {
					SessionId = state.SessionId,
					Commands = commands
				});
				owner.DispatchEditorActionResult(result);
				if (hasResult && result.ImeState.ResultCode == ImeResultCode.OK) {
					pendingImeHighSurrogate = null;
					expectedImeChars = resultText;
					expectedImeCharIndex = 0;
				}
			} finally {
				ImmReleaseContext(owner.Handle, hIMC);
			}
		}

		private bool TryBuildCompositionCommands(IntPtr hIMC, IntPtr wParam, int flags, bool hasResult,
			bool hasComposition, bool hasCursor, bool insertCharacter, out List<ImeCommand> commands,
			out string resultText) {
			commands = new List<ImeCommand>(3);
			resultText = string.Empty;
			string compositionText = string.Empty;
			if (hasResult && !TryReadString(hIMC, GcsResultStr, out resultText)) {
				return false;
			}
			if (hasComposition && !TryReadString(hIMC, GcsCompStr, out compositionText)) {
				return false;
			}

			ImeState before = state;
			if (hasResult) {
				commands.Add(new ImeCommand { Kind = ImeCommandKind.COMMIT_TEXT, Text = resultText });
			}

			if (hasComposition) {
				CursorRead cursorRead = ReadCursor(hIMC);
				if ((hasCursor && cursorRead.Status == CursorStatus.NoData) || cursorRead.Status == CursorStatus.Error) {
					return false;
				}
				ImeCommand update = new() {
					Kind = ImeCommandKind.UPDATE_COMPOSITION,
					Text = compositionText
				};
				if (cursorRead.Status == CursorStatus.Value) {
					if (!IsValidUtf16Offset(compositionText, cursorRead.Offset)) {
						return false;
					}
					update.SelectionAfter = Selection(ImeCoordinateSpace.COMPOSITION, cursorRead.Offset);
				} else if (TryGetCompositionCaret(before, out long relativeCaret)) {
					long fallback = Math.Min(relativeCaret, compositionText.Length);
					fallback = ClampToUtf16BoundaryLeft(compositionText, fallback);
					update.SelectionAfter = Selection(ImeCoordinateSpace.COMPOSITION, fallback);
				}
				commands.Add(update);
			} else if (insertCharacter) {
				char character = (char)(wParam.ToInt64() & 0xFFFF);
				if (char.IsSurrogate(character) || !TryGetCurrentCompositionText(out string currentText)) {
					return false;
				}
				long caret = TryGetCompositionCaret(before, out long relativeCaret) ? relativeCaret : 0;
				if (!IsValidUtf16Offset(currentText, caret)) {
					return false;
				}
				string nextText = currentText.Insert((int)caret, character.ToString());
				long nextCaret = (flags & CsNoMoveCaret) != 0 ? caret : caret + 1;
				commands.Add(new ImeCommand {
					Kind = ImeCommandKind.UPDATE_COMPOSITION,
					Text = nextText,
					SelectionAfter = Selection(ImeCoordinateSpace.COMPOSITION, nextCaret)
				});
			} else if (hasCursor && !hasResult && HasComposition) {
				CursorRead cursorRead = ReadCursor(hIMC);
				long compositionLength = state.CompositionRange.EndUtf16 - state.CompositionRange.StartUtf16;
				if (cursorRead.Status != CursorStatus.Value || cursorRead.Offset > compositionLength ||
				    !TryGetCurrentCompositionText(out string currentText) ||
				    !IsValidUtf16Offset(currentText, cursorRead.Offset)) {
					return false;
				}
				commands.Add(new ImeCommand {
					Kind = ImeCommandKind.SET_SELECTION,
					SelectionAfter = Selection(ImeCoordinateSpace.COMPOSITION, cursorRead.Offset)
				});
			}

			return true;
		}

		private void HandleImeChar(char character) {
			if (expectedImeCharIndex < expectedImeChars.Length &&
			    expectedImeChars[expectedImeCharIndex] == character) {
				expectedImeCharIndex++;
				if (expectedImeCharIndex == expectedImeChars.Length) {
					expectedImeChars = string.Empty;
					expectedImeCharIndex = 0;
				}
				pendingWmChar = character;
				return;
			}

			expectedImeChars = string.Empty;
				expectedImeCharIndex = 0;
			EnsureSession();
			if (char.IsHighSurrogate(character)) {
				pendingImeHighSurrogate = character;
				pendingWmChar = character;
				return;
			}
			if (char.IsLowSurrogate(character) && pendingImeHighSurrogate.HasValue) {
				if (IsActive) {
					Apply(new ImeCommand {
						Kind = ImeCommandKind.COMMIT_TEXT,
						Text = new string(new[] { pendingImeHighSurrogate.Value, character })
					});
				}
				pendingImeHighSurrogate = null;
				pendingWmChar = character;
				return;
			}
			pendingImeHighSurrogate = null;
			if (IsActive && !char.IsLowSurrogate(character)) {
				Apply(new ImeCommand { Kind = ImeCommandKind.COMMIT_TEXT, Text = character.ToString() });
			}
			pendingWmChar = character;
		}

		private void EnsureSession() {
			if (!IsActive) {
				BeginSession();
			}
		}

		private void Apply(params ImeCommand[] commands) {
			if (!IsActive || commands.Length == 0) {
				return;
			}
			owner.DispatchEditorActionResult(owner.EditorCoreInternal.ApplyImeCommands(new ImeCommandBatch {
				SessionId = state.SessionId,
				Commands = new List<ImeCommand>(commands)
			}));
		}

		private bool TryGetCurrentCompositionText(out string text) {
			text = string.Empty;
			if (!HasComposition) {
				return true;
			}
			long length = state.CompositionRange.EndUtf16 - state.CompositionRange.StartUtf16;
			ImeTextContext context = owner.EditorCoreInternal.GetImeContext(state.SessionId, ImeTextSource.EDITING,
				state.CompositionRange.StartUtf16, length);
			if (context.ResultCode != ImeResultCode.OK || context.SliceStartUtf16 != state.CompositionRange.StartUtf16) {
				return false;
			}
			text = context.Text;
			return text.Length == length;
		}

		private static bool TryGetCompositionCaret(ImeState source, out long relativeCaret) {
			relativeCaret = 0;
			if (!IsRange(source.CompositionRange) || !IsSelection(source.Selection)) {
				return false;
			}
			long active = source.Selection.ActiveUtf16;
			if (active < source.CompositionRange.StartUtf16 || active > source.CompositionRange.EndUtf16) {
				return false;
			}
			relativeCaret = active - source.CompositionRange.StartUtf16;
			return true;
		}

		private static bool TryReadString(IntPtr hIMC, int index, out string text) {
			text = string.Empty;
			int requestedBytes = ImmGetCompositionString(hIMC, index, null, 0);
			if (requestedBytes < 0 || (requestedBytes & 1) != 0) {
				return false;
			}
			if (requestedBytes == 0) {
				return true;
			}

			byte[] buffer = new byte[requestedBytes];
			int actualBytes = ImmGetCompositionString(hIMC, index, buffer, buffer.Length);
			if (actualBytes < 0 || actualBytes > requestedBytes || (actualBytes & 1) != 0) {
				return false;
			}
			text = System.Text.Encoding.Unicode.GetString(buffer, 0, actualBytes);
			return true;
		}

		private static CursorRead ReadCursor(IntPtr hIMC) {
			int value = ImmGetCompositionString(hIMC, GcsCursorPos, null, 0);
			if (value == ImmErrorNoData) {
				return new CursorRead(CursorStatus.NoData, 0);
			}
			return value < 0 ? new CursorRead(CursorStatus.Error, 0) : new CursorRead(CursorStatus.Value, value);
		}

		private void CloseAfterNativeReadFailure() {
			long sessionId = IsActive ? state.SessionId : 0;
			restartBlocked = true;
			ClearBinding();
			if (sessionId > 0) {
				owner.DispatchEditorActionResult(owner.EditorCoreInternal.EndImeSession(sessionId));
			}
			ScheduleNativeCompositionCancel();
		}

		private void CancelNativeComposition() {
			if (!owner.IsHandleCreated) {
				return;
			}
			IntPtr hIMC = ImmGetContext(owner.Handle);
			if (hIMC == IntPtr.Zero) {
				return;
			}
			try {
				ImmNotifyIME(hIMC, NiCompositionStr, CpsCancel, 0);
			} finally {
				ImmReleaseContext(owner.Handle, hIMC);
			}
		}

		private void ScheduleNativeCompositionCancel() {
			if (!owner.IsHandleCreated || owner.IsDisposed) {
				return;
			}
			owner.BeginInvoke(new Action(() => {
				if (!disposed && restartBlocked) {
					CancelNativeComposition();
				}
			}));
		}

		private void ClearBinding() {
			state = new ImeState();
			expectedImeChars = string.Empty;
			expectedImeCharIndex = 0;
			pendingWmChar = null;
			pendingImeHighSurrogate = null;
		}

		private static ImeCommand Command(ImeCommandKind kind) => new() { Kind = kind };

		private static ImeOffsetRange Range(ImeCoordinateSpace space, long start, long end) => new() {
			CoordinateSpace = space,
			StartUtf16 = start,
			EndUtf16 = end
		};

		private static ImeSelection Selection(ImeCoordinateSpace space, long offset) => new() {
			CoordinateSpace = space,
			AnchorUtf16 = offset,
			ActiveUtf16 = offset,
			Affinity = CaretAffinity.DOWNSTREAM
		};

		private static bool IsRange(ImeOffsetRange range) {
			return range.StartUtf16 >= 0 && range.EndUtf16 >= range.StartUtf16;
		}

		private static bool IsSelection(ImeSelection selection) {
			return selection.AnchorUtf16 >= 0 && selection.ActiveUtf16 >= 0;
		}

		private static bool IsValidUtf16Offset(string text, long offset) {
			if (offset < 0 || offset > text.Length) {
				return false;
			}
			return offset == 0 || offset == text.Length ||
			       !(char.IsHighSurrogate(text[(int)offset - 1]) && char.IsLowSurrogate(text[(int)offset]));
		}

		private static long ClampToUtf16BoundaryLeft(string text, long offset) {
			long safe = Math.Clamp(offset, 0, text.Length);
			if (safe > 0 && safe < text.Length && char.IsHighSurrogate(text[(int)safe - 1]) &&
			    char.IsLowSurrogate(text[(int)safe])) {
				safe--;
			}
			return safe;
		}

		public void Dispose() {
			if (disposed) {
				return;
			}
			EndSession(false);
			disposed = true;
		}

		private enum CursorStatus {
			NoData,
			Value,
			Error
		}

		private readonly struct CursorRead {
			internal CursorRead(CursorStatus status, int offset) {
				Status = status;
				Offset = offset;
			}

			internal CursorStatus Status { get; }
			internal int Offset { get; }
		}
	}
}
