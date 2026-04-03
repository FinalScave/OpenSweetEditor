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
  core.Document? _pendingDocument;
  EditorTheme? _pendingTheme;
  LanguageConfiguration? _languageConfiguration;
  bool _closed = false;
  final List<VoidCallback> _readyCallbacks = <VoidCallback>[];

  void _attach(_SweetEditorWidgetState state) {
    if (_closed) {
      throw StateError('SweetEditorController is already closed');
    }
    final currentState = _state;
    if (currentState != null && !identical(currentState, state)) {
      throw StateError(
        'SweetEditorController cannot be attached to multiple widgets',
      );
    }
    _state = state;
    final pendingTheme = _pendingTheme;
    if (pendingTheme != null) {
      _pendingTheme = null;
      state._applyTheme(pendingTheme);
    }
    final pendingDocument = _pendingDocument;
    if (pendingDocument != null) {
      _pendingDocument = null;
      state._loadDocument(pendingDocument);
    }
    final pendingText = _pendingText;
    if (pendingText != null) {
      _pendingText = null;
      state._loadText(pendingText);
    }
    if (_languageConfiguration != null) {
      state._applyLanguageConfiguration(_languageConfiguration);
    }
    final callbacks = List<VoidCallback>.from(_readyCallbacks);
    _readyCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void _detach() {
    _state = null;
  }

  bool get isAttached => _state != null;

  void whenReady(VoidCallback callback) {
    if (_closed) return;
    if (_state != null) {
      callback();
      return;
    }
    _readyCallbacks.add(callback);
  }

  void loadDocument(core.Document document) {
    if (_closed) return;
    if (_state != null) {
      _state!._loadDocument(document);
    } else {
      _pendingText = null;
      _pendingDocument = document;
    }
  }

  void loadText(String text) {
    if (_closed) return;
    if (_state != null) {
      _state!._loadText(text);
    } else {
      _pendingDocument = null;
      _pendingText = text;
    }
  }

  core.Document? getDocument() => _state?._document ?? _pendingDocument;

  String getContent() =>
      _state?._getContent() ?? _pendingDocument?.text ?? (_pendingText ?? '');
  int get lineCount =>
      _state?._document?.lineCount ?? _pendingDocument?.lineCount ?? 0;
  String getLineText(int line) =>
      _state?._document?.getLineText(line) ??
      _pendingDocument?.getLineText(line) ??
      '';

  LanguageConfiguration? get languageConfiguration => _languageConfiguration;

  set languageConfiguration(LanguageConfiguration? value) {
    if (_closed) return;
    _languageConfiguration = value;
    _state?._applyLanguageConfiguration(value);
  }

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
    _state?._interactionController.selectAll();
  }

  String getSelectedText() => _state?._editorCore?.getSelectedText() ?? '';

  void insertText(String text) {
    _state?._interactionController.insertText(text);
  }

  void replaceText(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
    String text,
  ) {
    _state?._interactionController.replaceText(
      core.TextRange(
        core.TextPosition(startLine, startColumn),
        core.TextPosition(endLine, endColumn),
      ),
      text,
    );
  }

  void deleteText(int startLine, int startColumn, int endLine, int endColumn) {
    _state?._interactionController.deleteText(
      core.TextRange(
        core.TextPosition(startLine, startColumn),
        core.TextPosition(endLine, endColumn),
      ),
    );
  }

  void insertSnippet(String snippetTemplate) {
    _state?._interactionController.insertSnippet(snippetTemplate);
  }

  void undo() {
    _state?._interactionController.undo();
  }

  void redo() {
    _state?._interactionController.redo();
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

  void triggerCompletion() => _state?._completionProviderManager
      .triggerCompletion(CompletionTriggerKind.invoked, null);

  void dismissCompletion() => _state?._completionProviderManager.dismiss();

  bool get isCompletionShowing =>
      _state?._completionPopupController.isShowing ?? false;

  void showInlineSuggestion(InlineSuggestion suggestion) =>
      _state?._inlineSuggestionController.show(suggestion);

  void dismissInlineSuggestion() =>
      _state?._inlineSuggestionController.dismiss();

  bool get isInlineSuggestionShowing =>
      _state?._inlineSuggestionController.isShowing ?? false;

  void setInlineSuggestionListener(InlineSuggestionListener? listener) =>
      _state?._inlineSuggestionController.setListener(listener);

  bool get hasSelection => _state?._editorCore?.getSelection() != null;

  void setSelectionMenuItemProvider(SelectionMenuItemProvider? provider) =>
      _state?._selectionMenuController.setItemProvider(provider);

  Stream<TextChangedEvent> get onTextChanged =>
      _eventBus.on<TextChangedEvent>();

  Stream<CursorChangedEvent> get onCursorChanged =>
      _eventBus.on<CursorChangedEvent>();

  Stream<SelectionChangedEvent> get onSelectionChanged =>
      _eventBus.on<SelectionChangedEvent>();

  Stream<ScrollChangedEvent> get onScrollChanged =>
      _eventBus.on<ScrollChangedEvent>();

  Stream<ScaleChangedEvent> get onScaleChanged =>
      _eventBus.on<ScaleChangedEvent>();

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

  void toggleFoldAt(int line) {
    _state?._editorCore?.toggleFold(line);
    _state?._flush();
  }

  void toggleFold(int line) => toggleFoldAt(line);

  void foldAt(int line) {
    _state?._editorCore?.foldAt(line);
    _state?._flush();
  }

  void unfoldAt(int line) {
    _state?._editorCore?.unfoldAt(line);
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

  bool isLineVisible(int line) =>
      _state?._editorCore?.isLineVisible(line) ?? true;

  void applyTheme(EditorTheme theme) {
    if (_closed) return;
    if (_state != null) {
      _state!._applyTheme(theme);
    } else {
      _pendingTheme = theme;
    }
  }

  void setTheme(EditorTheme theme) => applyTheme(theme);

  EditorTheme? getTheme() => _state?._theme ?? _pendingTheme;

  void flush() => _state?._flush();

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pendingText = null;
    _pendingDocument = null;
    _pendingTheme = null;
    _languageConfiguration = null;
    _readyCallbacks.clear();
    _state?._releaseFromController();
    await _eventBus.close();
  }

  Future<void> dispose() => close();
}
