part of '../sweeteditor.dart';

/// Lightweight Flutter-style controller for [SweetEditorWidget].
///
/// Create this in your State, pass it to [SweetEditorWidget], and use it
/// to interact with the editor. Methods are no-ops if the widget is not
/// yet mounted (no deferred action queue — matches Flutter conventions).
class SweetEditorController {
  _SweetEditorWidgetState? _state;
  final EditorEventBus _eventBus = EditorEventBus();
  final EditorSettings settings = EditorSettings();
  String? _pendingText;
  bool _closed = false;

  void _attach(_SweetEditorWidgetState state) {
    if (_closed) {
      throw StateError('SweetEditorController is already closed');
    }
    _state = state;
    final pendingText = _pendingText;
    if (pendingText != null) {
      _pendingText = null;
      state._loadText(pendingText);
    }
  }

  void _detach() {
    _state = null;
  }

  bool get isAttached => _state != null;

  void loadText(String text) {
    if (_closed) return;
    if (_state != null) {
      _state!._loadText(text);
    } else {
      _pendingText = text;
    }
  }

  String getContent() => _state?._getContent() ?? (_pendingText ?? '');
  int get lineCount => _state?._document?.lineCount ?? 0;
  String getLineText(int line) => _state?._document?.getLineText(line) ?? '';

  LanguageConfiguration? languageConfiguration;
  EditorMetadata? metadata;

  core.TextPosition getCursorPosition() =>
      _state?._editorCore?.getCursorPosition() ?? const core.TextPosition(0, 0);

  void setCursorPosition(int line, int column) {
    _state?._editorCore?.setCursorPosition(line, column);
    _state?._flush();
  }

  void gotoPosition(int line, int column) {
    _state?._editorCore?.gotoPosition(line, column);
    _state?._flush();
  }

  core.TextRange? getSelection() => _state?._editorCore?.getSelection();

  void setSelection(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
  ) {
    _state?._editorCore?.setSelection(
      startLine,
      startColumn,
      endLine,
      endColumn,
    );
    _state?._flush();
  }

  void selectAll() {
    _state?._editorCore?.selectAll();
    _state?._flush();
  }

  String getSelectedText() => _state?._editorCore?.getSelectedText() ?? '';

  void insertText(String text) {
    _state?._editorCore?.insertText(text);
    _state?._flush();
  }

  void undo() {
    _state?._editorCore?.undo();
    _state?._flush();
  }

  void redo() {
    _state?._editorCore?.redo();
    _state?._flush();
  }

  bool get canUndo => _state?._editorCore?.canUndo ?? false;
  bool get canRedo => _state?._editorCore?.canRedo ?? false;

  void addCompletionProvider(CompletionProvider provider) =>
      _state?._completionProviderManager.addProvider(provider);

  void removeCompletionProvider(CompletionProvider provider) =>
      _state?._completionProviderManager.removeProvider(provider);

  void addDecorationProvider(DecorationProvider provider) =>
      _state?._decorationProviderManager.addProvider(provider);

  void removeDecorationProvider(DecorationProvider provider) =>
      _state?._decorationProviderManager.removeProvider(provider);

  void requestDecorationRefresh() =>
      _state?._decorationProviderManager.requestRefresh();

  void addNewLineActionProvider(NewLineActionProvider provider) =>
      _state?._newLineActionProviderManager.addProvider(provider);

  void removeNewLineActionProvider(NewLineActionProvider provider) =>
      _state?._newLineActionProviderManager.removeProvider(provider);

  void showInlineSuggestion(InlineSuggestion suggestion) =>
      _state?._inlineSuggestionController.show(suggestion);

  bool get isInlineSuggestionShowing =>
      _state?._inlineSuggestionController.isShowing ?? false;

  void setInlineSuggestionListener(InlineSuggestionListener? listener) =>
      _state?._inlineSuggestionController.setListener(listener);

  bool get hasSelection => _state?._editorCore?.getSelection() != null;

  void setSelectionMenuItemProvider(SelectionMenuItemProvider? provider) =>
      _state?._selectionMenuController.setItemProvider(provider);

  Stream<TextChangedEvent> get onTextChanged => _eventBus.on<TextChangedEvent>();

  Stream<CursorChangedEvent> get onCursorChanged =>
      _eventBus.on<CursorChangedEvent>();

  Stream<SelectionChangedEvent> get onSelectionChanged =>
      _eventBus.on<SelectionChangedEvent>();

  Stream<ScrollChangedEvent> get onScrollChanged =>
      _eventBus.on<ScrollChangedEvent>();

  Stream<ScaleChangedEvent> get onScaleChanged => _eventBus.on<ScaleChangedEvent>();

  Stream<LongPressEvent> get onLongPress => _eventBus.on<LongPressEvent>();

  Stream<DoubleTapEvent> get onDoubleTap => _eventBus.on<DoubleTapEvent>();

  Stream<ContextMenuEvent> get onContextMenu =>
      _eventBus.on<ContextMenuEvent>();

  Stream<GutterIconClickEvent> get onGutterIconClick =>
      _eventBus.on<GutterIconClickEvent>();

  Stream<InlayHintClickEvent> get onInlayHintClick =>
      _eventBus.on<InlayHintClickEvent>();

  Stream<FoldToggleEvent> get onFoldToggle => _eventBus.on<FoldToggleEvent>();

  Stream<DocumentLoadedEvent> get onDocumentLoaded =>
      _eventBus.on<DocumentLoadedEvent>();

  Stream<SelectionMenuItemClickEvent> get onSelectionMenuItemClick =>
      _eventBus.on<SelectionMenuItemClickEvent>();

  void toggleFold(int line) {
    _state?._editorCore?.toggleFold(line);
    _state?._flush();
  }

  void foldAll() {
    _state?._editorCore?.foldAll();
    _state?._flush();
  }

  void unfoldAll() {
    _state?._editorCore?.unfoldAll();
    _state?._flush();
  }

  core.ScrollMetrics getScrollMetrics() =>
      _state?._editorCore?.getScrollMetrics() ?? core.ScrollMetrics.empty;

  void scrollToLine(
    int line, {
    core.ScrollBehavior behavior = core.ScrollBehavior.gotoCenter,
  }) {
    _state?._editorCore?.scrollToLine(line, behavior: behavior);
    _state?._flush();
  }

  void setTheme(EditorTheme theme) => _state?._applyTheme(theme);

  void flush() => _state?._flush();

  Future<void> close() async {
    if (_closed) return;
    if (_state != null) {
      throw StateError(
        'Cannot close SweetEditorController while it is attached to a widget',
      );
    }
    _closed = true;
    await _eventBus.close();
  }
}
