part of '../sweeteditor.dart';

class SweetEditorController {
  _SweetEditorWidgetState? _state;
  final EditorEventBus _eventBus = EditorEventBus();
  final List<VoidCallback> _readyCallbacks = <VoidCallback>[];
  bool _associationEstablished = false;
  bool _terminated = false;

  void _attach(_SweetEditorWidgetState state) {
    if (_associationEstablished) {
      if (!identical(_state, state)) {
        throw StateError(
          'SweetEditorController cannot be rebound to another editor instance',
        );
      }
      return;
    }
    _associationEstablished = true;
    _state = state;
    final callbacks = List<VoidCallback>.from(_readyCallbacks);
    _readyCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  void _detach() {
    _state = null;
    _terminated = true;
    _readyCallbacks.clear();
  }

  bool get isAttached => _state != null;

  void _withEditorCore(void Function(core.EditorCore editorCore) action) {
    if (_terminated) return;
    final editorCore = _state?._session.editorCore;
    if (editorCore == null) return;
    action(editorCore);
  }

  void _runEditorCoreAction(
    core.EditorActionResult? Function(core.EditorCore editorCore) action,
  ) {
    _withEditorCore((editorCore) {
      _state?._dispatchEditorActionResult(action(editorCore));
    });
  }

  void whenReady(VoidCallback callback) {
    if (_state != null) {
      callback();
      return;
    }
    if (_terminated) return;
    _readyCallbacks.add(callback);
  }

  void loadDocument(core.Document document) {
    if (_terminated) return;
    _state?._loadDocument(document);
  }

  void loadText(String text) {
    if (_terminated) return;
    _state?._loadText(text);
  }

  core.Document? getDocument() => _state?._session.document;

  String getContent() => _state?._session.getContent() ?? '';
  int get lineCount => _state?._session.document?.lineCount ?? 0;
  String getLineText(int line) =>
      _state?._session.document?.getLineText(line) ?? '';

  EditorSettings? get settings => getSettings();

  EditorSettings? getSettings() => _state?._session.settings;

  LanguageConfiguration? get languageConfiguration =>
      getLanguageConfiguration();

  set languageConfiguration(LanguageConfiguration? value) =>
      setLanguageConfiguration(value);

  LanguageConfiguration? getLanguageConfiguration() =>
      _state?._session.languageConfiguration;

  void setLanguageConfiguration(LanguageConfiguration? value) {
    if (_terminated) return;
    _state?._applyLanguageConfiguration(value);
  }

  EditorMetadata? get metadata => getMetadata();

  set metadata(EditorMetadata? value) => setMetadata(value);

  EditorMetadata? getMetadata() => _state?._session.metadata;

  void setMetadata(EditorMetadata? value) {
    if (_terminated) return;
    _state?._applyMetadata(value);
  }

  core.TextPosition getCursorPosition() =>
      _state?._session.editorCore?.getCursorPosition() ??
      const core.TextPosition(line: 0, column: 0);

  void setCursorPosition(Object positionOrLine, [int? column]) {
    final position = _resolveTextPositionArgument(
      positionOrLine,
      column,
      methodName: 'setCursorPosition',
    );
    final result = _state?._session.editorCore?.setCursorPosition(
      position.line,
      position.column,
    );
    _state?._dispatchEditorActionResult(result);
  }

  void gotoPosition(int line, int column) {
    final result = _state?._session.editorCore?.gotoPosition(line, column);
    _state?._dispatchEditorActionResult(result);
  }

  core.TextRange? getSelection() => _state?._session.editorCore?.getSelection();

  void setSelection(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
  ) {
    final result = _state?._session.editorCore?.setSelection(
      startLine,
      startColumn,
      endLine,
      endColumn,
    );
    _state?._dispatchEditorActionResult(result);
  }

  void selectAll() {
    _state?._interactionController.selectAll();
  }

  String getSelectedText() =>
      _state?._session.editorCore?.getSelectedText() ?? '';

  void insertText(String text) {
    _state?._interactionController.insertText(text);
  }

  /// Inserts text at the specified document position.
  void insertTextAt(core.TextPosition position, String text) {
    _state?._interactionController.insertTextAt(position, text);
  }

  void replaceText(
    Object rangeOrStartLine,
    Object textOrStartColumn, [
    int? endLine,
    int? endColumn,
    String? text,
  ]) {
    final args = _resolveReplaceTextArguments(
      rangeOrStartLine,
      textOrStartColumn,
      endLine,
      endColumn,
      text,
    );
    _state?._interactionController.replaceText(args.$1, args.$2);
  }

  void deleteText(
    Object rangeOrStartLine, [
    int? startColumn,
    int? endLine,
    int? endColumn,
  ]) {
    final range = _resolveTextRangeArgument(
      rangeOrStartLine,
      startColumn,
      endLine,
      endColumn,
      methodName: 'deleteText',
    );
    _state?._interactionController.deleteText(range);
  }

  /// Applies multiple text edits as one undoable operation.
  ///
  /// Edits use the original document coordinates. The first edit is the primary edit.
  void applyTextEdits(List<core.TextEdit> edits) {
    _state?._interactionController.applyTextEdits(edits);
  }

  void insertSnippet(String snippetTemplate) {
    _state?._interactionController.insertSnippet(snippetTemplate);
  }

  void moveLineUp() {
    _withEditorCore((editorCore) {
      final result = editorCore.moveLineUp();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void moveLineDown() {
    _withEditorCore((editorCore) {
      final result = editorCore.moveLineDown();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void copyLineUp() {
    _withEditorCore((editorCore) {
      final result = editorCore.copyLineUp();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void copyLineDown() {
    _withEditorCore((editorCore) {
      final result = editorCore.copyLineDown();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void deleteLine() {
    _withEditorCore((editorCore) {
      final result = editorCore.deleteLine();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void insertLineAbove() {
    _withEditorCore((editorCore) {
      final result = editorCore.insertLineAbove();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void insertLineBelow() {
    _withEditorCore((editorCore) {
      final result = editorCore.insertLineBelow();
      _state?._dispatchEditorActionResult(result);
    });
  }

  void undo() {
    _state?._interactionController.undo();
  }

  void redo() {
    _state?._interactionController.redo();
  }

  bool get canUndo => _state?._session.editorCore?.canUndo ?? false;
  bool get canRedo => _state?._session.editorCore?.canRedo ?? false;

  void search(core.SearchRequest request) {
    _runEditorCoreAction((editorCore) => editorCore.search(request));
  }

  void findNextSearchMatch() {
    _runEditorCoreAction((editorCore) => editorCore.findNextSearchMatch());
  }

  void findPreviousSearchMatch() {
    _runEditorCoreAction((editorCore) => editorCore.findPreviousSearchMatch());
  }

  void replaceCurrentSearchMatch(String replacement) {
    _runEditorCoreAction(
      (editorCore) => editorCore.replaceCurrentSearchMatch(replacement),
    );
  }

  void replaceAllSearchMatches(String replacement) {
    _runEditorCoreAction(
      (editorCore) => editorCore.replaceAllSearchMatches(replacement),
    );
  }

  void clearSearch() {
    _runEditorCoreAction((editorCore) => editorCore.clearSearch());
  }

  core.SearchState getSearchState() =>
      _state?._session.editorCore?.getSearchState() ?? const core.SearchState();

  core.TextRange getWordRangeAtCursor() =>
      _state?._session.editorCore?.getWordRangeAtCursor() ??
      const core.TextRange(
        start: core.TextPosition(line: 0, column: 0),
        end: core.TextPosition(line: 0, column: 0),
      );

  String getWordAtCursor() =>
      _state?._session.editorCore?.getWordAtCursor() ?? '';

  void addCompletionProvider(CompletionProvider provider) =>
      _state?._session.completionProviderManager.addProvider(provider);

  void removeCompletionProvider(CompletionProvider provider) =>
      _state?._session.completionProviderManager.removeProvider(provider);

  void addDecorationProvider(DecorationProvider provider) =>
      _state?._session.decorationProviderManager.addProvider(provider);

  void removeDecorationProvider(DecorationProvider provider) =>
      _state?._session.decorationProviderManager.removeProvider(provider);

  void requestDecorationRefresh() =>
      _state?._session.decorationProviderManager.requestRefresh();

  void addNewLineActionProvider(NewLineActionProvider provider) =>
      _state?._session.newLineActionProviderManager.addProvider(provider);

  void removeNewLineActionProvider(NewLineActionProvider provider) =>
      _state?._session.newLineActionProviderManager.removeProvider(provider);

  void triggerCompletion() => _state?._session.completionProviderManager
      .triggerCompletion(CompletionTriggerKind.invoked, null);

  void showCompletionItems(List<CompletionItem> items) =>
      _state?._session.completionProviderManager.showItems(items);

  void dismissCompletion() =>
      _state?._session.completionProviderManager.dismiss();

  void setCompletionItemRenderer(CompletionItemWidgetBuilder? renderer) =>
      _state?._session.completionPopupController.setItemBuilder(renderer);

  bool get isCompletionShowing =>
      _state?._session.completionPopupController.isShowing ?? false;

  void showInlineSuggestion(InlineSuggestion suggestion) =>
      _state?._session.inlineSuggestionController.show(suggestion);

  void dismissInlineSuggestion() =>
      _state?._session.inlineSuggestionController.dismiss();

  bool get isInlineSuggestionShowing =>
      _state?._session.inlineSuggestionController.isShowing ?? false;

  void setInlineSuggestionListener(InlineSuggestionListener? listener) =>
      _state?._session.inlineSuggestionController.setListener(listener);

  bool get hasSelection => _state?._session.editorCore?.getSelection() != null;

  void setSelectionMenuItemProvider(SelectionMenuItemProvider? provider) =>
      _state?._session.selectionMenuController.setItemProvider(provider);

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

  Stream<CodeLensClickEvent> get onCodeLensClick =>
      _eventBus.on<CodeLensClickEvent>();

  Stream<LinkClickEvent> get onLinkClick => _eventBus.on<LinkClickEvent>();

  Stream<FoldToggleEvent> get onFoldToggle => _eventBus.on<FoldToggleEvent>();

  Stream<DocumentLoadedEvent> get onDocumentLoaded =>
      _eventBus.on<DocumentLoadedEvent>();

  Stream<SelectionMenuItemClickEvent> get onSelectionMenuItemClick =>
      _eventBus.on<SelectionMenuItemClickEvent>();

  void toggleFoldAt(int line) {
    final result = _state?._session.editorCore?.toggleFoldAt(line);
    _state?._dispatchEditorActionResult(result);
  }

  void foldAt(int line) {
    final result = _state?._session.editorCore?.foldAt(line);
    _state?._dispatchEditorActionResult(result);
  }

  void unfoldAt(int line) {
    final result = _state?._session.editorCore?.unfoldAt(line);
    _state?._dispatchEditorActionResult(result);
  }

  void foldAll() {
    final result = _state?._session.editorCore?.foldAll();
    _state?._dispatchEditorActionResult(result);
  }

  void unfoldAll() {
    final result = _state?._session.editorCore?.unfoldAll();
    _state?._dispatchEditorActionResult(result);
  }

  core.ScrollMetrics getScrollMetrics() =>
      _state?._session.editorCore?.getScrollMetrics() ??
      const core.ScrollMetrics();

  void setScroll(double scrollX, double scrollY) {
    final result = _state?._session.editorCore?.setScroll(scrollX, scrollY);
    _state?._dispatchEditorActionResult(result);
  }

  core.CursorRect getPositionRect(int line, int column) =>
      _state?._session.editorCore?.getPositionRect(line, column) ??
      const core.CursorRect();

  core.CursorRect getCursorRect() =>
      _state?._session.editorCore?.getCursorRect() ?? const core.CursorRect();

  core.IntRange getVisibleLineRange() =>
      _state?._session.getVisibleLineRange() ??
      const core.IntRange(start: 0, end: -1);

  int getTotalLineCount() => _state?._session.document?.lineCount ?? 0;

  void scrollToLine(
    int line, {
    core.ScrollBehavior behavior = core.ScrollBehavior.gotoCenter,
  }) {
    final result = _state?._session.editorCore?.scrollToLine(
      line,
      behavior: behavior,
    );
    _state?._dispatchEditorActionResult(result);
  }

  bool isLineVisible(int line) =>
      _state?._session.editorCore?.isLineVisible(line) ?? true;

  int get totalLineCount => getTotalLineCount();

  EditorKeyMap getKeyMap() =>
      _state?._session.keyMap ?? EditorKeyMap.defaultKeyMap();

  void setKeyMap(EditorKeyMap keyMap) {
    if (_terminated) return;
    _state?._applyKeyMap(keyMap);
  }

  void setEditorIconProvider(EditorIconProvider? provider) {
    if (_terminated) return;
    _state?._applyIconProvider(provider);
  }

  void applyTheme(EditorTheme theme) {
    if (_terminated) return;
    _state?._applyTheme(theme);
  }

  void setTheme(EditorTheme theme) => applyTheme(theme);

  EditorTheme? getTheme() => _state?._session.theme;

  void registerTextStyle(
    int styleId,
    int color, {
    int backgroundColor = 0,
    int fontStyle = 0,
  }) {
    _runEditorCoreAction(
      (editorCore) => editorCore.registerTextStyle(
        styleId,
        color,
        backgroundColor: backgroundColor,
        fontStyle: fontStyle,
      ),
    );
  }

  void registerBatchTextStyles(Map<int, core.TextStyle> stylesById) {
    _runEditorCoreAction(
      (editorCore) => editorCore.registerBatchTextStyles(stylesById),
    );
  }

  void setLineSpans(
    int line,
    core.SpanLayer layer,
    List<core.StyleSpan> spans,
  ) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLineSpans(line, layer, spans),
    );
  }

  void setBatchLineSpans(
    core.SpanLayer layer,
    Map<int, List<core.StyleSpan>> spansByLine,
  ) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineSpans(layer, spansByLine),
    );
  }

  void setLineInlayHints(int line, List<core.InlayHint> hints) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLineInlayHints(line, hints),
    );
  }

  void setBatchLineInlayHints(Map<int, List<core.InlayHint>> hintsByLine) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineInlayHints(hintsByLine),
    );
  }

  void setLinePhantomTexts(int line, List<core.PhantomText> phantoms) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLinePhantomTexts(line, phantoms),
    );
  }

  void setBatchLinePhantomTexts(
    Map<int, List<core.PhantomText>> phantomsByLine,
  ) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLinePhantomTexts(phantomsByLine),
    );
  }

  void setLineGutterIcons(int line, List<core.GutterIcon> icons) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLineGutterIcons(line, icons),
    );
  }

  void setBatchLineGutterIcons(Map<int, List<core.GutterIcon>> iconsByLine) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineGutterIcons(iconsByLine),
    );
  }

  void setLineCodeLens(int line, List<core.CodeLensItem> items) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLineCodeLens(line, items),
    );
  }

  void setBatchLineCodeLens(Map<int, List<core.CodeLensItem>> itemsByLine) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineCodeLens(itemsByLine),
    );
  }

  void setLineLinks(int line, List<core.LinkSpan> links) {
    _runEditorCoreAction((editorCore) => editorCore.setLineLinks(line, links));
  }

  void setBatchLineLinks(Map<int, List<core.LinkSpan>> linksByLine) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineLinks(linksByLine),
    );
  }

  String getLinkTargetAt(int line, int column) =>
      _state?._session.editorCore?.getLinkTargetAt(line, column) ?? '';

  void setLineDiagnostics(int line, List<core.Diagnostic> items) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLineDiagnostics(line, items),
    );
  }

  void setBatchLineDiagnostics(Map<int, List<core.Diagnostic>> itemsByLine) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineDiagnostics(itemsByLine),
    );
  }

  void setLineDocumentHighlights(int line, List<core.DocumentHighlight> items) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setLineDocumentHighlights(line, items),
    );
  }

  void setBatchLineDocumentHighlights(
    Map<int, List<core.DocumentHighlight>> itemsByLine,
  ) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setBatchLineDocumentHighlights(itemsByLine),
    );
  }

  void setIndentGuides(List<core.IndentGuide> guides) {
    _runEditorCoreAction((editorCore) => editorCore.setIndentGuides(guides));
  }

  void setBracketGuides(List<core.BracketGuide> guides) {
    _runEditorCoreAction((editorCore) => editorCore.setBracketGuides(guides));
  }

  void setFlowGuides(List<core.FlowGuide> guides) {
    _runEditorCoreAction((editorCore) => editorCore.setFlowGuides(guides));
  }

  void setSeparatorGuides(List<core.SeparatorGuide> guides) {
    _runEditorCoreAction((editorCore) => editorCore.setSeparatorGuides(guides));
  }

  void setFoldRegions(List<core.FoldRegion> regions) {
    _runEditorCoreAction((editorCore) => editorCore.setFoldRegions(regions));
  }

  void setMatchedBrackets(
    int openLine,
    int openColumn,
    int closeLine,
    int closeColumn,
  ) {
    _runEditorCoreAction(
      (editorCore) => editorCore.setMatchedBrackets(
        openLine,
        openColumn,
        closeLine,
        closeColumn,
      ),
    );
  }

  void clearMatchedBrackets() {
    _runEditorCoreAction((editorCore) => editorCore.clearMatchedBrackets());
  }

  void clearHighlights([core.SpanLayer? layer]) {
    _runEditorCoreAction((editorCore) => editorCore.clearHighlights(layer));
  }

  void clearInlayHints() {
    _runEditorCoreAction((editorCore) => editorCore.clearInlayHints());
  }

  void clearPhantomTexts() {
    _runEditorCoreAction((editorCore) => editorCore.clearPhantomTexts());
  }

  void clearGutterIcons() {
    _runEditorCoreAction((editorCore) => editorCore.clearGutterIcons());
  }

  void clearCodeLens() {
    _runEditorCoreAction((editorCore) => editorCore.clearCodeLens());
  }

  void clearLinks() {
    _runEditorCoreAction((editorCore) => editorCore.clearLinks());
  }

  void clearGuides() {
    _runEditorCoreAction((editorCore) => editorCore.clearGuides());
  }

  void clearDiagnostics() {
    _runEditorCoreAction((editorCore) => editorCore.clearDiagnostics());
  }

  void clearDocumentHighlights() {
    _runEditorCoreAction((editorCore) => editorCore.clearDocumentHighlights());
  }

  void clearAllDecorations() {
    _runEditorCoreAction((editorCore) => editorCore.clearAllDecorations());
  }

  /// Installs an externally computed line-level diff.
  void setDiffChanges(List<core.DiffChange> changes) {
    _runEditorCoreAction((editorCore) => editorCore.setDiffChanges(changes));
  }

  /// Computes a line-level diff against the supplied original document text.
  void computeDiff(String originalText) {
    _runEditorCoreAction((editorCore) => editorCore.computeDiff(originalText));
  }

  /// Sets layered style spans for removed original lines.
  void setBatchDiffLineSpans(
    core.SpanLayer layer,
    Map<int, List<core.StyleSpan>> spansByOriginalLine,
  ) {
    _runEditorCoreAction(
      (editorCore) =>
          editorCore.setBatchDiffLineSpans(layer, spansByOriginalLine),
    );
  }

  /// Clears the current diff snapshot.
  void clearDiff() {
    _runEditorCoreAction((editorCore) => editorCore.clearDiff());
  }

  void flush() => _state?._flush();

  core.TextPosition _resolveTextPositionArgument(
    Object positionOrLine,
    int? column, {
    required String methodName,
  }) {
    if (positionOrLine is core.TextPosition && column == null) {
      return positionOrLine;
    }
    if (positionOrLine is int && column != null) {
      return core.TextPosition(line: positionOrLine, column: column);
    }
    throw ArgumentError(
      '$methodName expects either a TextPosition or line and column integers.',
    );
  }

  core.TextRange _resolveTextRangeArgument(
    Object rangeOrStartLine,
    int? startColumn,
    int? endLine,
    int? endColumn, {
    required String methodName,
  }) {
    if (rangeOrStartLine is core.TextRange &&
        startColumn == null &&
        endLine == null &&
        endColumn == null) {
      return rangeOrStartLine;
    }
    if (rangeOrStartLine is int &&
        startColumn != null &&
        endLine != null &&
        endColumn != null) {
      return core.TextRange(
        start: core.TextPosition(line: rangeOrStartLine, column: startColumn),
        end: core.TextPosition(line: endLine, column: endColumn),
      );
    }
    throw ArgumentError(
      '$methodName expects either a TextRange or four integer coordinates.',
    );
  }

  (core.TextRange, String) _resolveReplaceTextArguments(
    Object rangeOrStartLine,
    Object textOrStartColumn,
    int? endLine,
    int? endColumn,
    String? text,
  ) {
    if (rangeOrStartLine is core.TextRange &&
        textOrStartColumn is String &&
        endLine == null &&
        endColumn == null &&
        text == null) {
      return (rangeOrStartLine, textOrStartColumn);
    }
    if (rangeOrStartLine is int &&
        textOrStartColumn is int &&
        endLine != null &&
        endColumn != null &&
        text != null) {
      return (
        core.TextRange(
          start: core.TextPosition(
            line: rangeOrStartLine,
            column: textOrStartColumn,
          ),
          end: core.TextPosition(line: endLine, column: endColumn),
        ),
        text,
      );
    }
    throw ArgumentError(
      'replaceText expects either (TextRange, String) or '
      '(int, int, int, int, String).',
    );
  }
}
