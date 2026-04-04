part of '../sweeteditor.dart';

class SweetEditorController {
  _SweetEditorWidgetState? _state;
  final EditorEventBus _eventBus = EditorEventBus();
  final EditorSettings settings = EditorSettings();
  EditorKeyMap _keyMap = EditorKeyMap.defaultKeyMap();
  EditorIconProvider? _iconProvider;
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
    state._applyIconProvider(_iconProvider);
    state._applyKeyMap(_keyMap);
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

  core.EditorCore? get _editorCore => _state?._editorCore;

  void _withEditorCore(void Function(core.EditorCore editorCore) action) {
    if (_closed) return;
    final editorCore = _editorCore;
    if (editorCore == null) return;
    action(editorCore);
  }

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

  void moveLineUp() {
    _withEditorCore((editorCore) {
      final result = editorCore.moveLineUp();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.insert,
        result,
      );
    });
  }

  void moveLineDown() {
    _withEditorCore((editorCore) {
      final result = editorCore.moveLineDown();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.insert,
        result,
      );
    });
  }

  void copyLineUp() {
    _withEditorCore((editorCore) {
      final result = editorCore.copyLineUp();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.insert,
        result,
      );
    });
  }

  void copyLineDown() {
    _withEditorCore((editorCore) {
      final result = editorCore.copyLineDown();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.insert,
        result,
      );
    });
  }

  void deleteLine() {
    _withEditorCore((editorCore) {
      final result = editorCore.deleteLine();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.delete_,
        result,
      );
    });
  }

  void insertLineAbove() {
    _withEditorCore((editorCore) {
      final result = editorCore.insertLineAbove();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.insert,
        result,
      );
    });
  }

  void insertLineBelow() {
    _withEditorCore((editorCore) {
      final result = editorCore.insertLineBelow();
      _state?._interactionController.dispatchTextChangedForController(
        TextChangeAction.insert,
        result,
      );
    });
  }

  void undo() {
    _state?._interactionController.undo();
  }

  void redo() {
    _state?._interactionController.redo();
  }

  bool get canUndo => _state?._editorCore?.canUndo ?? false;
  bool get canRedo => _state?._editorCore?.canRedo ?? false;

  core.TextRange getWordRangeAtCursor() =>
      _state?._editorCore?.getWordRangeAtCursor() ??
      const core.TextRange(core.TextPosition(0, 0), core.TextPosition(0, 0));

  String getWordAtCursor() => _state?._editorCore?.getWordAtCursor() ?? '';

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

  void showCompletionItems(List<CompletionItem> items) =>
      _state?._completionProviderManager.showItems(items);

  void dismissCompletion() => _state?._completionProviderManager.dismiss();

  void setCompletionItemRenderer(CompletionItemViewBuilder? renderer) =>
      _state?._completionPopupController.setViewBuilder(renderer);

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
    _state?._editorCore?.toggleFoldAt(line);
    _state?._flush();
  }

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

  void setScroll(double scrollX, double scrollY) {
    _state?._editorCore?.setScroll(scrollX, scrollY);
    _state?._flush();
  }

  core.CursorRect getPositionRect(int line, int column) =>
      _state?._editorCore?.getPositionRect(line, column) ??
      const core.CursorRect();

  core.CursorRect getCursorRect() =>
      _state?._editorCore?.getCursorRect() ?? const core.CursorRect();

  ({int startLine, int endLine}) getVisibleLineRange() {
    final visualLines = _state?._session.renderModel.visualLines;
    if (visualLines == null || visualLines.isEmpty) {
      return (startLine: 0, endLine: -1);
    }
    return (
      startLine: visualLines.first.logicalLine,
      endLine: visualLines.last.logicalLine,
    );
  }

  int getTotalLineCount() =>
      _state?._document?.lineCount ?? _pendingDocument?.lineCount ?? 0;

  void scrollToLine(
    int line, {
    core.ScrollBehavior behavior = core.ScrollBehavior.center,
  }) {
    _state?._editorCore?.scrollToLine(line, behavior: behavior);
    _state?._flush();
  }

  bool isLineVisible(int line) =>
      _state?._editorCore?.isLineVisible(line) ?? true;

  int get totalLineCount => getTotalLineCount();

  EditorKeyMap getKeyMap() => _keyMap;

  void setKeyMap(EditorKeyMap keyMap) {
    if (_closed) return;
    _keyMap = keyMap;
    _state?._applyKeyMap(keyMap);
  }

  void setEditorIconProvider(EditorIconProvider? provider) {
    if (_closed) return;
    _iconProvider = provider;
    _state?._applyIconProvider(provider);
  }

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

  void registerTextStyle(
    int styleId,
    int color, {
    int backgroundColor = 0,
    int fontStyle = 0,
  }) {
    _withEditorCore(
      (editorCore) => editorCore.registerTextStyle(
        styleId,
        color,
        backgroundColor: backgroundColor,
        fontStyle: fontStyle,
      ),
    );
  }

  void registerBatchTextStyles(Map<int, core.TextStyle> stylesById) {
    _withEditorCore((editorCore) {
      editorCore.registerBatchTextStyles(stylesById);
    });
  }

  void setLineSpans(
    int line,
    core.SpanLayer layer,
    List<core.StyleSpan> spans,
  ) {
    _withEditorCore((editorCore) {
      editorCore.setLineSpans(line, layer, spans);
    });
  }

  void setBatchLineSpans(
    core.SpanLayer layer,
    Map<int, List<core.StyleSpan>> spansByLine,
  ) {
    _withEditorCore((editorCore) {
      editorCore.setBatchLineSpans(layer, spansByLine);
    });
  }

  void setLineInlayHints(int line, List<core.InlayHint> hints) {
    _withEditorCore((editorCore) {
      editorCore.setLineInlayHints(line, hints);
    });
  }

  void setBatchLineInlayHints(Map<int, List<core.InlayHint>> hintsByLine) {
    _withEditorCore((editorCore) {
      editorCore.setBatchLineInlayHints(hintsByLine);
    });
  }

  void setLinePhantomTexts(int line, List<core.PhantomText> phantoms) {
    _withEditorCore((editorCore) {
      editorCore.setLinePhantomTexts(line, phantoms);
    });
  }

  void setBatchLinePhantomTexts(
    Map<int, List<core.PhantomText>> phantomsByLine,
  ) {
    _withEditorCore((editorCore) {
      editorCore.setBatchLinePhantomTexts(phantomsByLine);
    });
  }

  void setLineGutterIcons(int line, List<core.GutterIcon> icons) {
    _withEditorCore((editorCore) {
      editorCore.setLineGutterIcons(line, icons);
    });
  }

  void setBatchLineGutterIcons(Map<int, List<core.GutterIcon>> iconsByLine) {
    _withEditorCore((editorCore) {
      editorCore.setBatchLineGutterIcons(iconsByLine);
    });
  }

  void setLineDiagnostics(int line, List<core.Diagnostic> items) {
    _withEditorCore((editorCore) {
      editorCore.setLineDiagnostics(line, items);
    });
  }

  void setBatchLineDiagnostics(
    Map<int, List<core.Diagnostic>> itemsByLine,
  ) {
    _withEditorCore((editorCore) {
      editorCore.setBatchLineDiagnostics(itemsByLine);
    });
  }

  void setIndentGuides(List<core.IndentGuide> guides) {
    _withEditorCore((editorCore) {
      editorCore.setIndentGuides(guides);
    });
  }

  void setBracketGuides(List<core.BracketGuide> guides) {
    _withEditorCore((editorCore) {
      editorCore.setBracketGuides(guides);
    });
  }

  void setFlowGuides(List<core.FlowGuide> guides) {
    _withEditorCore((editorCore) {
      editorCore.setFlowGuides(guides);
    });
  }

  void setSeparatorGuides(List<core.SeparatorGuide> guides) {
    _withEditorCore((editorCore) {
      editorCore.setSeparatorGuides(guides);
    });
  }

  void setFoldRegions(List<core.FoldRegion> regions) {
    _withEditorCore((editorCore) {
      editorCore.setFoldRegions(regions);
    });
  }

  void setMatchedBrackets(
    int openLine,
    int openColumn,
    int closeLine,
    int closeColumn,
  ) {
    _withEditorCore((editorCore) {
      editorCore.setMatchedBrackets(
        openLine,
        openColumn,
        closeLine,
        closeColumn,
      );
    });
  }

  void clearMatchedBrackets() {
    _withEditorCore((editorCore) => editorCore.clearMatchedBrackets());
  }

  void clearHighlights([core.SpanLayer? layer]) {
    _withEditorCore((editorCore) {
      editorCore.clearHighlights(layer);
    });
  }

  void clearInlayHints() {
    _withEditorCore((editorCore) => editorCore.clearInlayHints());
  }

  void clearPhantomTexts() {
    _withEditorCore((editorCore) => editorCore.clearPhantomTexts());
  }

  void clearGutterIcons() {
    _withEditorCore((editorCore) => editorCore.clearGutterIcons());
  }

  void clearGuides() {
    _withEditorCore((editorCore) => editorCore.clearGuides());
  }

  void clearDiagnostics() {
    _withEditorCore((editorCore) => editorCore.clearDiagnostics());
  }

  void clearAllDecorations() {
    _withEditorCore((editorCore) => editorCore.clearAllDecorations());
  }

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
