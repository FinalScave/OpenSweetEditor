using System;
using System.Collections.Generic;
using System.Linq;
using Avalonia.Threading;

namespace SweetEditor {
	public sealed class SweetEditorController : IDisposable {
		public event EventHandler<TextChangedEventArgs>? TextChanged;
		public event EventHandler<CursorChangedEventArgs>? CursorChanged;
		public event EventHandler<SelectionChangedEventArgs>? SelectionChanged;
		public event EventHandler<ScrollChangedEventArgs>? ScrollChanged;
		public event EventHandler<ScaleChangedEventArgs>? ScaleChanged;
		public event EventHandler<DocumentLoadedEventArgs>? DocumentLoaded;
		public event EventHandler<LongPressEventArgs>? LongPress;
		public event EventHandler<DoubleTapEventArgs>? DoubleTap;
		public event EventHandler<ContextMenuEventArgs>? ContextMenu;
		public event EventHandler<InlayHintClickEventArgs>? InlayHintClick;
		public event EventHandler<GutterIconClickEventArgs>? GutterIconClick;
		public event EventHandler<CodeLensClickEventArgs>? CodeLensClick;
		public event EventHandler<FoldToggleEventArgs>? FoldToggle;
		public event EventHandler<SelectionMenuItemClickEventArgs>? SelectionMenuItemClick;
		public event Action<IReadOnlyList<CompletionItem>>? CompletionItemsUpdated;
		public event Action? CompletionDismissed;
		public event Action<InlineSuggestion>? InlineSuggestionAccepted;
		public event Action<InlineSuggestion>? InlineSuggestionDismissed;

		private readonly object gate = new();
		private readonly Queue<Action<SweetEditorControl>> pendingActions = new();
		private readonly List<Action> readyCallbacks = new();

		private SweetEditorControl? boundEditor;
		private bool disposed;

		internal bool IsReady {
			get {
				lock (gate) {
					return !disposed && boundEditor != null;
				}
			}
		}

		private static KeyMap CreateDefaultKeyMap() {
			return KeyMap.DefaultKeyMap().Clone();
		}

		public void WhenReady(Action callback) {
			if (callback == null) {
				return;
			}

			bool invokeNow;
			lock (gate) {
				if (disposed) {
					return;
				}
				invokeNow = boundEditor != null;
				if (!invokeNow) {
					readyCallbacks.Add(callback);
				}
			}

			if (invokeNow) {
				RunOnUiThread(callback);
			}
		}

		internal void Bind(SweetEditorControl editor) {
			if (editor == null) {
				return;
			}

			List<Action<SweetEditorControl>> actions;
			List<Action> callbacks;
			lock (gate) {
				if (disposed) {
					return;
				}
				if (boundEditor != null && !ReferenceEquals(boundEditor, editor)) {
					throw new InvalidOperationException("SweetEditorController is already bound to another control.");
				}
				if (ReferenceEquals(boundEditor, editor)) {
					return;
				}

				boundEditor = editor;
				actions = pendingActions.ToList();
				pendingActions.Clear();
				callbacks = new List<Action>(readyCallbacks);
				readyCallbacks.Clear();
			}

			AttachEvents(editor);

			foreach (var callback in callbacks) {
				SafeInvoke(callback);
			}
			foreach (var action in actions) {
				SafeRun(editor, action);
			}
		}

		internal void Unbind(SweetEditorControl editor) {
			if (editor == null) {
				return;
			}

			bool shouldDetach;
			lock (gate) {
				shouldDetach = ReferenceEquals(boundEditor, editor);
				if (shouldDetach) {
					boundEditor = null;
				}
			}

			if (shouldDetach) {
				DetachEvents(editor);
			}
		}

		internal void Unbind() {
			SweetEditorControl? editor;
			lock (gate) {
				editor = boundEditor;
			}
			if (editor != null) {
				Unbind(editor);
			}
		}

		public void Dispose() {
			if (disposed) {
				return;
			}

			SweetEditorControl? editor;
			lock (gate) {
				if (disposed) {
					return;
				}
				disposed = true;
				editor = boundEditor;
				boundEditor = null;
				pendingActions.Clear();
				readyCallbacks.Clear();
			}

			if (editor != null) {
				DetachEvents(editor);
				editor.DetachController(this);
			}
		}

		public void LoadDocument(Document document) => Invoke(e => e.LoadDocument(document));

		public Document? GetDocument() => Read(e => e.GetDocument(), null);

		public void ApplyTheme(EditorTheme theme) => Invoke(e => e.ApplyTheme(theme));

		public EditorTheme? GetTheme() => Read(e => e.GetTheme(), null);

		public EditorSettings? GetSettings() => Read(e => e.GetSettings(), null);

		public KeyMap GetKeyMap() => Read(e => e.GetKeyMap(), CreateDefaultKeyMap());

		public void SetKeyMap(KeyMap keyMap) => Invoke(e => e.SetKeyMap(keyMap));

		public void SetEditorIconProvider(EditorIconProvider? provider) => Invoke(e => e.SetEditorIconProvider(provider));

		public void SetLanguageConfiguration(LanguageConfiguration? config) => Invoke(e => e.SetLanguageConfiguration(config));

		public LanguageConfiguration? GetLanguageConfiguration() => Read(e => e.GetLanguageConfiguration(), null);

		public LayoutMetrics GetLayoutMetrics() => Read(e => e.GetLayoutMetrics(), default);

		public void SetMetadata(IEditorMetadata? metadata) => Invoke(e => e.SetMetadata(metadata));

		public IEditorMetadata? GetMetadata() => Read(e => e.GetMetadata(), null);

		public void AddNewLineActionProvider(INewLineActionProvider provider) => Invoke(e => e.AddNewLineActionProvider(provider));

		public void RemoveNewLineActionProvider(INewLineActionProvider provider) => Invoke(e => e.RemoveNewLineActionProvider(provider));

		public void AddDecorationProvider(IDecorationProvider provider) => Invoke(e => e.AddDecorationProvider(provider));

		public void RemoveDecorationProvider(IDecorationProvider provider) => Invoke(e => e.RemoveDecorationProvider(provider));

		public void RequestDecorationRefresh() => Invoke(e => e.RequestDecorationRefresh());

		public void AddCompletionProvider(ICompletionProvider provider) => Invoke(e => e.AddCompletionProvider(provider));

		public void RemoveCompletionProvider(ICompletionProvider provider) => Invoke(e => e.RemoveCompletionProvider(provider));

		public void TriggerCompletion() => Invoke(e => e.TriggerCompletion());

		public void ShowCompletionItems(List<CompletionItem> items) => Invoke(e => e.ShowCompletionItems(items));

		public void DismissCompletion() => Invoke(e => e.DismissCompletion());

		public void SetCompletionItemRenderer(ICompletionItemRenderer? renderer) => Invoke(e => e.SetCompletionItemRenderer(renderer));

		public void ShowInlineSuggestion(InlineSuggestion suggestion) => Invoke(e => e.ShowInlineSuggestion(suggestion));

		public void DismissInlineSuggestion() => Invoke(e => e.DismissInlineSuggestion());

		public void AcceptInlineSuggestion() => Invoke(e => e.AcceptInlineSuggestion());

		public bool IsInlineSuggestionShowing() => Read(e => e.IsInlineSuggestionShowing(), false);

		public void SetInlineSuggestionListener(IInlineSuggestionListener? listener) => Invoke(e => e.SetInlineSuggestionListener(listener));

		public void SetSelectionMenuItemProvider(ISelectionMenuItemProvider? provider) => Invoke(e => e.SetSelectionMenuItemProvider(provider));

		public void SetSelectionMenuListener(ISelectionMenuListener? listener) => Invoke(e => e.SetSelectionMenuListener(listener));

		public void SetSelectionMenuHostManaged(bool hostManaged) => Invoke(e => e.SetSelectionMenuHostManaged(hostManaged));

		public bool IsSelectionMenuShowing() => Read(e => e.IsSelectionMenuShowing(), false);

		internal void DismissSelectionMenu() => Invoke(e => e.DismissSelectionMenu());

		public void SetPerfOverlayEnabled(bool enabled) => Invoke(e => e.SetPerfOverlayEnabled(enabled));

		public bool IsPerfOverlayEnabled() => Read(e => e.IsPerfOverlayEnabled(), false);

		public void InsertText(string text) => Invoke(e => e.InsertText(text));

		public void ReplaceText(TextRange range, string newText) => Invoke(e => e.ReplaceText(range, newText));

		public void DeleteText(TextRange range) => Invoke(e => e.DeleteText(range));

		public void MoveLineUp() => Invoke(e => e.MoveLineUp());

		public void MoveLineDown() => Invoke(e => e.MoveLineDown());

		public void CopyLineUp() => Invoke(e => e.CopyLineUp());

		public void CopyLineDown() => Invoke(e => e.CopyLineDown());

		public void DeleteLine() => Invoke(e => e.DeleteLine());

		public void InsertLineAbove() => Invoke(e => e.InsertLineAbove());

		public void InsertLineBelow() => Invoke(e => e.InsertLineBelow());

		public bool Undo() => Read(e => e.Undo(), false);

		public bool Redo() => Read(e => e.Redo(), false);

		public bool CanUndo() => Read(e => e.CanUndo(), false);

		public bool CanRedo() => Read(e => e.CanRedo(), false);

		public void CopyToClipboard() => Invoke(e => e.CopyToClipboard());

		public void PasteFromClipboard() => Invoke(e => e.PasteFromClipboard());

		public void CutToClipboard() => Invoke(e => e.CutToClipboard());

		public void SelectAll() => Invoke(e => e.SelectAll());

		public string GetSelectedText() => Read(e => e.GetSelectedText(), string.Empty);

		public void SetSelection(int startLine, int startColumn, int endLine, int endColumn) =>
			Invoke(e => e.SetSelection(startLine, startColumn, endLine, endColumn));

		public (bool hasSelection, TextRange range) GetSelection() => Read(e => e.GetSelection(), (false, default));

		public void SetCursorPosition(TextPosition position) => Invoke(e => e.SetCursorPosition(position));

		public TextPosition GetCursorPosition() => Read(e => e.GetCursorPosition(), default);

		public TextRange? GetWordRangeAtCursor() => Read(e => e.GetWordRangeAtCursor(), null);

		public string GetWordAtCursor() => Read(e => e.GetWordAtCursor(), string.Empty);

		public void GotoPosition(int line, int column = 0) => Invoke(e => e.GotoPosition(line, column));

		public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.CENTER) => Invoke(e => e.ScrollToLine(line, behavior));

		public void SetScroll(float scrollX, float scrollY) => Invoke(e => e.SetScroll(scrollX, scrollY));

		public ScrollMetrics GetScrollMetrics() => Read(e => e.GetScrollMetrics(), default);

		public CursorRect GetPositionRect(int line, int column) => Read(e => e.GetPositionRect(line, column), default);

		public CursorRect GetCursorRect() => Read(e => e.GetCursorRect(), default);

		public bool ToggleFoldAt(int line) => Read(e => e.ToggleFoldAt(line), false);

		public bool FoldAt(int line) => Read(e => e.FoldAt(line), false);

		public bool UnfoldAt(int line) => Read(e => e.UnfoldAt(line), false);

		public bool IsLineVisible(int line) => Read(e => e.IsLineVisible(line), false);

		public void FoldAll() => Invoke(e => e.FoldAll());

		public void UnfoldAll() => Invoke(e => e.UnfoldAll());

		public void RegisterTextStyle(uint styleId, int color, int backgroundColor, int fontStyle) =>
			Invoke(e => e.RegisterTextStyle(styleId, color, backgroundColor, fontStyle));

		public void RegisterBatchTextStyles(IReadOnlyDictionary<uint, TextStyle> stylesById) =>
			Invoke(e => e.RegisterBatchTextStyles(stylesById));

		public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans) =>
			Invoke(e => e.SetLineSpans(line, layer, spans));

		public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine) =>
			Invoke(e => e.SetBatchLineSpans(layer, spansByLine));

		public void ClearLineSpans(int line, SpanLayer layer) => Invoke(e => e.ClearLineSpans(line, layer));

		public void SetLineInlayHints(int line, IList<InlayHint> hints) => Invoke(e => e.SetLineInlayHints(line, hints));

		public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) =>
			Invoke(e => e.SetBatchLineInlayHints(hintsByLine));

		public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms) => Invoke(e => e.SetLinePhantomTexts(line, phantoms));

		public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) =>
			Invoke(e => e.SetBatchLinePhantomTexts(phantomsByLine));

		public void SetLineGutterIcons(int line, IList<GutterIcon> icons) => Invoke(e => e.SetLineGutterIcons(line, icons));

		public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) =>
			Invoke(e => e.SetBatchLineGutterIcons(iconsByLine));

		public void SetMaxGutterIcons(int count) => Invoke(e => e.SetMaxGutterIcons(count));

		public int GetMaxGutterIcons() => Read(e => e.GetMaxGutterIcons(), 0);

		public void SetLineCodeLens(int line, IList<CodeLensItem> items) => Invoke(e => e.SetLineCodeLens(line, items));

		public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine) =>
			Invoke(e => e.SetBatchLineCodeLens(itemsByLine));

		public void SetLineDiagnostics<TDiagnostic>(int line, IList<TDiagnostic> items) where TDiagnostic : Diagnostic => Invoke(e => e.SetLineDiagnostics(line, items));

		public void SetBatchLineDiagnostics<TDiagnostic>(Dictionary<int, IList<TDiagnostic>> diagsByLine) where TDiagnostic : Diagnostic =>
			Invoke(e => e.SetBatchLineDiagnostics(diagsByLine));

		public void SetIndentGuides(IList<IndentGuide> guides) => Invoke(e => e.SetIndentGuides(guides));

		public void SetBracketGuides(IList<BracketGuide> guides) => Invoke(e => e.SetBracketGuides(guides));

		public void SetFlowGuides(IList<FlowGuide> guides) => Invoke(e => e.SetFlowGuides(guides));

		public void SetSeparatorGuides(IList<SeparatorGuide> guides) => Invoke(e => e.SetSeparatorGuides(guides));

		public void SetFoldRegions(IList<FoldRegion> regions) => Invoke(e => e.SetFoldRegions(regions));

		public void ClearHighlights() => Invoke(e => e.ClearHighlights());

		public void ClearHighlights(SpanLayer layer) => Invoke(e => e.ClearHighlights(layer));

		public void ClearInlayHints() => Invoke(e => e.ClearInlayHints());

		public void ClearPhantomTexts() => Invoke(e => e.ClearPhantomTexts());

		public void ClearGutterIcons() => Invoke(e => e.ClearGutterIcons());

		public void ClearCodeLens() => Invoke(e => e.ClearCodeLens());

		public void ClearGuides() => Invoke(e => e.ClearGuides());

		public void ClearDiagnostics() => Invoke(e => e.ClearDiagnostics());

		public void ClearAllDecorations() => Invoke(e => e.ClearAllDecorations());

		public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn) =>
			Invoke(e => e.SetMatchedBrackets(openLine, openColumn, closeLine, closeColumn));

		public void ClearMatchedBrackets() => Invoke(e => e.ClearMatchedBrackets());

		public TextEditResult InsertSnippet(string snippetTemplate) =>
			Read(e => e.InsertSnippet(snippetTemplate), TextEditResult.Empty);

		public void StartLinkedEditing(LinkedEditingModel model) => Invoke(e => e.StartLinkedEditing(model));

		public bool IsInLinkedEditing() => Read(e => e.IsInLinkedEditing(), false);

		public bool LinkedEditingNext() => Read(e => e.LinkedEditingNext(), false);

		public bool LinkedEditingPrev() => Read(e => e.LinkedEditingPrev(), false);

		public void CancelLinkedEditing() => Invoke(e => e.CancelLinkedEditing());

		public void Flush() => Invoke(e => e.Flush());

		public (int start, int end) GetVisibleLineRange() => Read(e => e.GetVisibleLineRange(), (0, -1));

		public int GetTotalLineCount() => Read(e => e.GetTotalLineCount(), -1);

		private void Invoke(Action<SweetEditorControl> action) {
			if (action == null) {
				return;
			}

			SweetEditorControl? target;
			lock (gate) {
				if (disposed) {
					return;
				}
				target = boundEditor;
				if (target == null) {
					pendingActions.Enqueue(action);
					return;
				}
			}

			RunOnUiThread(() => {
				SweetEditorControl? current;
				lock (gate) {
					current = boundEditor;
				}
				if (!ReferenceEquals(current, target) || disposed) {
					return;
				}
				SafeRun(target, action);
			});
		}

		private T Read<T>(Func<SweetEditorControl, T> getter, T fallback) {
			if (getter == null) {
				return fallback;
			}

			SweetEditorControl? target;
			lock (gate) {
				if (disposed || boundEditor == null) {
					return fallback;
				}
				target = boundEditor;
			}

			if (Dispatcher.UIThread.CheckAccess()) {
				return SafeRead(target, getter, fallback);
			}

			try {
				return Dispatcher.UIThread.InvokeAsync(() => SafeRead(target, getter, fallback)).GetAwaiter().GetResult();
			} catch {
				return fallback;
			}
		}

		private static T SafeRead<T>(SweetEditorControl editor, Func<SweetEditorControl, T> getter, T fallback) {
			try {
				return getter(editor);
			} catch {
				return fallback;
			}
		}

		private static void SafeRun(SweetEditorControl editor, Action<SweetEditorControl> action) {
			try {
				action(editor);
			} catch (Exception ex) {
				Console.Error.WriteLine($"SweetEditorController action error: {ex.Message}");
			}
		}

		private static void SafeInvoke(Action callback) {
			try {
				callback();
			} catch (Exception ex) {
				Console.Error.WriteLine($"SweetEditorController callback error: {ex.Message}");
			}
		}

		private static void RunOnUiThread(Action action) {
			if (action == null) {
				return;
			}
			if (Dispatcher.UIThread.CheckAccess()) {
				action();
			} else {
				Dispatcher.UIThread.Post(action);
			}
		}

		private void AttachEvents(SweetEditorControl editor) {
			editor.TextChanged += HandleTextChanged;
			editor.CursorChanged += HandleCursorChanged;
			editor.SelectionChanged += HandleSelectionChanged;
			editor.ScrollChanged += HandleScrollChanged;
			editor.ScaleChanged += HandleScaleChanged;
			editor.DocumentLoaded += HandleDocumentLoaded;
			editor.LongPress += HandleLongPress;
			editor.DoubleTap += HandleDoubleTap;
			editor.ContextMenu += HandleContextMenu;
			editor.InlayHintClick += HandleInlayHintClick;
			editor.GutterIconClick += HandleGutterIconClick;
			editor.CodeLensClick += HandleCodeLensClick;
			editor.FoldToggle += HandleFoldToggle;
			editor.SelectionMenuItemClick += HandleSelectionMenuItemClick;
			editor.CompletionItemsUpdated += HandleCompletionItemsUpdated;
			editor.CompletionDismissed += HandleCompletionDismissed;
			editor.InlineSuggestionAccepted += HandleInlineSuggestionAccepted;
			editor.InlineSuggestionDismissed += HandleInlineSuggestionDismissed;
		}

		private void DetachEvents(SweetEditorControl editor) {
			editor.TextChanged -= HandleTextChanged;
			editor.CursorChanged -= HandleCursorChanged;
			editor.SelectionChanged -= HandleSelectionChanged;
			editor.ScrollChanged -= HandleScrollChanged;
			editor.ScaleChanged -= HandleScaleChanged;
			editor.DocumentLoaded -= HandleDocumentLoaded;
			editor.LongPress -= HandleLongPress;
			editor.DoubleTap -= HandleDoubleTap;
			editor.ContextMenu -= HandleContextMenu;
			editor.InlayHintClick -= HandleInlayHintClick;
			editor.GutterIconClick -= HandleGutterIconClick;
			editor.CodeLensClick -= HandleCodeLensClick;
			editor.FoldToggle -= HandleFoldToggle;
			editor.SelectionMenuItemClick -= HandleSelectionMenuItemClick;
			editor.CompletionItemsUpdated -= HandleCompletionItemsUpdated;
			editor.CompletionDismissed -= HandleCompletionDismissed;
			editor.InlineSuggestionAccepted -= HandleInlineSuggestionAccepted;
			editor.InlineSuggestionDismissed -= HandleInlineSuggestionDismissed;
		}

		private void HandleTextChanged(object? sender, TextChangedEventArgs e) => TextChanged?.Invoke(this, e);
		private void HandleCursorChanged(object? sender, CursorChangedEventArgs e) => CursorChanged?.Invoke(this, e);
		private void HandleSelectionChanged(object? sender, SelectionChangedEventArgs e) => SelectionChanged?.Invoke(this, e);
		private void HandleScrollChanged(object? sender, ScrollChangedEventArgs e) => ScrollChanged?.Invoke(this, e);
		private void HandleScaleChanged(object? sender, ScaleChangedEventArgs e) => ScaleChanged?.Invoke(this, e);
		private void HandleDocumentLoaded(object? sender, DocumentLoadedEventArgs e) => DocumentLoaded?.Invoke(this, e);
		private void HandleLongPress(object? sender, LongPressEventArgs e) => LongPress?.Invoke(this, e);
		private void HandleDoubleTap(object? sender, DoubleTapEventArgs e) => DoubleTap?.Invoke(this, e);
		private void HandleContextMenu(object? sender, ContextMenuEventArgs e) => ContextMenu?.Invoke(this, e);
		private void HandleInlayHintClick(object? sender, InlayHintClickEventArgs e) => InlayHintClick?.Invoke(this, e);
		private void HandleGutterIconClick(object? sender, GutterIconClickEventArgs e) => GutterIconClick?.Invoke(this, e);
		private void HandleCodeLensClick(object? sender, CodeLensClickEventArgs e) => CodeLensClick?.Invoke(this, e);
		private void HandleFoldToggle(object? sender, FoldToggleEventArgs e) => FoldToggle?.Invoke(this, e);
		private void HandleSelectionMenuItemClick(object? sender, SelectionMenuItemClickEventArgs e) => SelectionMenuItemClick?.Invoke(this, e);
		private void HandleCompletionItemsUpdated(IReadOnlyList<CompletionItem> items) => CompletionItemsUpdated?.Invoke(items);
		private void HandleCompletionDismissed() => CompletionDismissed?.Invoke();
		private void HandleInlineSuggestionAccepted(InlineSuggestion suggestion) => InlineSuggestionAccepted?.Invoke(suggestion);
		private void HandleInlineSuggestionDismissed(InlineSuggestion suggestion) => InlineSuggestionDismissed?.Invoke(suggestion);
	}
}
