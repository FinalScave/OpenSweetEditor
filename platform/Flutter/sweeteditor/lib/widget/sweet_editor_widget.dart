part of '../sweeteditor.dart';

/// A Flutter widget that wraps the native SweetEditor engine.
///
/// Renders a full code editor with syntax highlighting, cursor, selection,
/// completion popup, inline suggestions, decorations, guides, and scrollbars.
///
/// Usage:
/// ```
/// final controller = SweetEditorController();
/// SweetEditorWidget(
///   controller: controller,
///   text: 'hello world',
/// );
/// ```
class SweetEditorWidget extends StatefulWidget {
  const SweetEditorWidget({
    super.key,
    required this.controller,
    this.document,
    this.text,
    this.theme,
    this.settings,
    this.keyMap,
    this.iconProvider,
    this.languageConfiguration,
    this.metadata,
    this.fontFamily = 'monospace',
    this.fontSize = 14,
    this.autofocus = true,
  });

  final SweetEditorController controller;
  final core.Document? document;
  final String? text;
  final EditorTheme? theme;
  final EditorSettings? settings;
  final EditorKeyMap? keyMap;
  final EditorIconProvider? iconProvider;
  final LanguageConfiguration? languageConfiguration;
  final EditorMetadata? metadata;
  final String fontFamily;
  final double fontSize;
  final bool autofocus;

  @override
  State<SweetEditorWidget> createState() => _SweetEditorWidgetState();
}

class _SweetEditorWidgetState extends State<SweetEditorWidget>
    with TickerProviderStateMixin, DeltaTextInputClient {
  late EditorSession _session;
  late EditorOverlayCoordinator _overlayCoordinator;
  late EditorInteractionController _interactionController;
  late final EditorPlatformBehavior _platformBehavior;
  late final FocusNode _focusNode;
  final GlobalKey _editorKey = GlobalKey();
  TextInputConnection? _textInputConnection;
  TextEditingValue _textEditingValue = TextEditingValue.empty;
  int _textInputContextId = 0;
  int _textInputContextRevision = 0;
  int _textInputDocumentStartOffset = 0;
  bool _textInputContextReady = false;
  bool _handlingTextInputUpdate = false;
  bool _pendingShowTextInput = false;
  Size? _pendingViewportSize;
  bool _viewportUpdateScheduled = false;
  bool _editorResourcesReleased = false;
  bool _pendingDocumentLoadedNotification = false;
  Ticker? _animationTicker;
  bool _animating = false;
  core.PointerCursorType _pointerCursorType = core.PointerCursorType.text;

  EditorEventBus get _eventBus => widget.controller._eventBus;

  @override
  void initState() {
    super.initState();
    _platformBehavior = EditorPlatformBehavior.resolve();
    _focusNode = FocusNode(debugLabel: 'SweetEditor');
    _focusNode.addListener(_handleFocusChanged);
    _initEditor();
  }

  @override
  void didUpdateWidget(covariant SweetEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      throw StateError(
        'SweetEditorWidget cannot change controller after the editor is mounted',
      );
    }

    final defaultTheme = EditorTheme.dark();
    _applyTheme(widget.theme ?? defaultTheme);
    _session.applyDeclarativeSettings(
      widget.settings,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
      gutterSticky: _platformBehavior.gutterStickyDefault,
    );
    _applyKeyMap(widget.keyMap ?? EditorKeyMap.defaultKeyMap());
    _applyIconProvider(widget.iconProvider);
    _applyLanguageConfiguration(widget.languageConfiguration);
    _applyMetadata(widget.metadata);

    final documentChanged = !identical(widget.document, oldWidget.document);
    final textChanged = widget.text != oldWidget.text;
    if (widget.document != null) {
      if (documentChanged) {
        _loadDocument(widget.document!);
      }
    } else if (documentChanged || textChanged) {
      _loadText(widget.text ?? '');
    }
  }

  @override
  void dispose() {
    _closeTextInputConnection();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _releaseEditorResources();
    super.dispose();
  }

  void _initEditor() {
    _initSubsystems();
    _session.bindSettings();
    _applyDeclarativeInputs();
    widget.controller._attach(this);
    _interactionController.startCursorBlink();
  }

  void _initSubsystems() {
    _session = EditorSession(
      eventBus: _eventBus,
      hostCallbacks: EditorSessionHostCallbacks(
        onRenderModelUpdated: _handleRenderModelUpdated,
        onTextInputStyleInvalidated: _updateTextInputStyle,
        onHostActionResult: _handleEditorActionResult,
        onAnimationStateChanged: _setAnimationRunning,
      ),
      theme: widget.theme ?? EditorTheme.dark(),
      initialSettings: widget.settings,
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      gutterSticky: _platformBehavior.gutterStickyDefault,
      platformBehavior: _platformBehavior,
      initialKeyMap: widget.keyMap ?? EditorKeyMap.defaultKeyMap(),
      initialIconProvider: widget.iconProvider,
      initialLanguageConfiguration: widget.languageConfiguration,
      initialMetadata: widget.metadata,
    );

    _overlayCoordinator = EditorOverlayCoordinator(session: _session);
    _interactionController = EditorInteractionController(
      session: _session,
    );

    _session.completionPopupController.setConfirmHandler(
      _interactionController.onCompletionItemConfirmed,
    );
  }

  void _handleRenderModelUpdated(core.EditorRenderModel model) {
    final pointerCursorChanged = model.pointerCursorType != _pointerCursorType;
    _pointerCursorType = model.pointerCursorType;
    _overlayCoordinator.onRenderModelUpdated(model);
    _updateTextInputGeometry();
    if (pointerCursorChanged && mounted) {
      setState(() {});
    }
    _dispatchPendingDocumentLoaded();
  }

  void _applyDeclarativeInputs() {
    final document = widget.document;
    if (document != null) {
      _loadDocument(document);
      return;
    }
    final text = widget.text;
    if (text != null) {
      _loadText(text);
    }
  }

  void _loadText(String text) {
    _session.loadText(text);
    _onDocumentLoaded();
  }

  void _loadDocument(core.Document document) {
    _session.loadDocument(document, takeOwnership: false);
    _onDocumentLoaded();
  }

  void _onDocumentLoaded() {
    _pendingDocumentLoadedNotification = true;
    _clearTextInputStateContext();
    if (!_handlingTextInputUpdate) {
      _syncTextInputState(force: true);
    }
  }

  void _dispatchPendingDocumentLoaded() {
    if (!_pendingDocumentLoadedNotification || !mounted) return;
    _pendingDocumentLoadedNotification = false;
    _session.decorationProviderManager.onDocumentLoaded();
    _eventBus.publish(DocumentLoadedEvent());
  }

  void _flush() {
    if (!mounted) return;
    if (!_handlingTextInputUpdate) {
      _syncTextInputState();
    }
    _session.requestFlush();
  }

  void _setAnimationRunning(bool running) {
    if (_editorResourcesReleased) return;
    if (running) {
      if (_animating) return;
      _animating = true;
      _animationTicker ??= createTicker(_onAnimationTick);
      _animationTicker!.start();
      return;
    }
    if (!_animating) return;
    _animating = false;
    _animationTicker?.stop();
  }

  void _onAnimationTick(Duration elapsed) {
    if (_editorResourcesReleased || !_animating) return;
    _session.tickAnimations();
  }

  void _scheduleViewportUpdate(Size size) {
    _pendingViewportSize = size;
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      final pendingSize = _pendingViewportSize;
      _pendingViewportSize = null;
      if (!mounted || pendingSize == null) return;
      if (pendingSize.width <= 0 || pendingSize.height <= 0) return;
      if (pendingSize != _session.viewportSize) {
        _session.setViewport(pendingSize);
      }
    });
  }

  void _applyTheme(EditorTheme theme) {
    _session.applyTheme(theme);
    if (mounted) {
      setState(() {});
    }
    _flush();
  }

  void _applyIconProvider(EditorIconProvider? provider) {
    _session.applyIconProvider(provider);
    _flush();
  }

  void _applyKeyMap(EditorKeyMap keyMap) {
    _session.applyKeyMap(keyMap);
  }

  void _applyLanguageConfiguration(LanguageConfiguration? config) {
    _session.applyLanguageConfiguration(config);
    _session.decorationProviderManager.requestRefresh();
  }

  void _applyMetadata(EditorMetadata? metadata) {
    _session.applyMetadata(metadata);
  }

  void _releaseEditorResources() {
    if (_editorResourcesReleased) return;
    _setAnimationRunning(false);
    _editorResourcesReleased = true;
    _animationTicker?.dispose();
    _animationTicker = null;
    _interactionController.dispose();
    _overlayCoordinator.dispose();
    widget.controller._detach();
    _session.dispose();
  }

  @override
  TextEditingValue? get currentTextEditingValue => _textEditingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    _handleTextEditingValue(value);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (textEditingDeltas.isEmpty) {
      return;
    }
    final editorCore = _session.editorCore;
    var nextValue = _textEditingValue;
    if (editorCore == null) {
      for (final delta in textEditingDeltas) {
        if (delta.oldText != nextValue.text) {
          _clearTextInputStateContext();
          return;
        }
        nextValue = delta.apply(nextValue);
      }
      _textEditingValue = nextValue;
      _clearTextInputStateContext();
      return;
    }
    if (!_ensureTextInputContextReady()) {
      return;
    }
    nextValue = _textEditingValue;

    var hasStaleDelta = false;
    var probedValue = nextValue;
    for (final delta in textEditingDeltas) {
      if (delta.oldText != probedValue.text) {
        hasStaleDelta = true;
        break;
      }
      probedValue = delta.apply(probedValue);
    }

    if (hasStaleDelta) {
      _syncTextInputState(force: true);
      return;
    }

    var forceTextInputStateSync = false;
    _handlingTextInputUpdate = true;
    try {
      for (final delta in textEditingDeltas) {
        final appliedValue = delta.apply(nextValue);
        final result = _updateImeTextUpdatePatch(
          editorCore,
          delta,
          appliedValue,
        );
        forceTextInputStateSync =
            _dispatchImeAction(result, clearTextInputContext: false) ||
            forceTextInputStateSync;
        nextValue = appliedValue;
      }
    } finally {
      _handlingTextInputUpdate = false;
    }

    _textEditingValue = nextValue;
    if (forceTextInputStateSync) {
      _clearTextInputStateContext();
      _syncTextInputState(force: true);
    }
  }

  core.EditorActionResult _updateImeTextUpdateSnapshot(
    core.EditorCore editorCore,
    TextEditingValue value,
  ) {
    final composingActive = _isActiveTextRange(value.composing, value.text);
    final selectionValid = _isValidSelection(value.selection, value.text);
    return editorCore.handleImeTextUpdateMessage(
      core.ImeTextUpdateMessage(
        kind: core.ImeTextUpdateKind.snapshot,
        scope: _platformBehavior.imeTextUpdateScope,
        contextId: _textInputContextId,
        contextRevision: _textInputContextRevision,
        documentStartOffset: _textInputDocumentStartOffset,
        text: value.text,
        selection: core.ImeOffsetRange(
          start: selectionValid ? value.selection.start : -1,
          end: selectionValid ? value.selection.end : -1,
        ),
        markedRange: core.ImeMarkedRange(
          role: composingActive
              ? _platformBehavior.textInputComposingRole
              : core.ImeMarkedRangeRole.none,
          range: core.ImeOffsetRange(
            start: composingActive ? value.composing.start : -1,
            end: composingActive ? value.composing.end : -1,
          ),
        ),
      ),
    );
  }

  core.EditorActionResult _updateImeTextUpdatePatch(
    core.EditorCore editorCore,
    TextEditingDelta delta,
    TextEditingValue appliedValue,
  ) {
    final composingActive = _isActiveTextRange(
      appliedValue.composing,
      appliedValue.text,
    );
    final selectionValid = _isValidSelection(
      appliedValue.selection,
      appliedValue.text,
    );
    var deltaStartOffset = -1;
    var deltaEndOffset = -1;
    var deltaText = '';
    if (delta is TextEditingDeltaInsertion) {
      deltaStartOffset = delta.insertionOffset;
      deltaEndOffset = delta.insertionOffset;
      deltaText = delta.textInserted;
    } else if (delta is TextEditingDeltaDeletion) {
      deltaStartOffset = delta.deletedRange.start;
      deltaEndOffset = delta.deletedRange.end;
    } else if (delta is TextEditingDeltaReplacement) {
      deltaStartOffset = delta.replacedRange.start;
      deltaEndOffset = delta.replacedRange.end;
      deltaText = delta.replacementText;
    }

    return editorCore.handleImeTextUpdateMessage(
      core.ImeTextUpdateMessage(
        kind: core.ImeTextUpdateKind.patch,
        scope: _platformBehavior.imeTextUpdateScope,
        contextId: _textInputContextId,
        contextRevision: _textInputContextRevision,
        documentStartOffset: _textInputDocumentStartOffset,
        text: delta.oldText,
        patch: core.ImeTextPatch(
          range: core.ImeOffsetRange(
            start: deltaStartOffset,
            end: deltaEndOffset,
          ),
          text: deltaText,
        ),
        selection: core.ImeOffsetRange(
          start: selectionValid ? appliedValue.selection.start : -1,
          end: selectionValid ? appliedValue.selection.end : -1,
        ),
        markedRange: core.ImeMarkedRange(
          role: composingActive
              ? _platformBehavior.textInputComposingRole
              : core.ImeMarkedRangeRole.none,
          range: core.ImeOffsetRange(
            start: composingActive ? appliedValue.composing.start : -1,
            end: composingActive ? appliedValue.composing.end : -1,
          ),
        ),
      ),
    );
  }

  void _handleTextEditingValue(TextEditingValue value) {
    final editorCore = _session.editorCore;
    if (editorCore == null) {
      _textEditingValue = value;
      _clearTextInputStateContext();
      return;
    }
    if (value == _textEditingValue) {
      return;
    }
    if (!_ensureTextInputContextReady()) {
      return;
    }

    var forceTextInputStateSync = false;
    _handlingTextInputUpdate = true;
    try {
      final result = _updateImeTextUpdateSnapshot(editorCore, value);
      forceTextInputStateSync = _dispatchImeAction(result);
    } finally {
      _handlingTextInputUpdate = false;
    }

    _textEditingValue = value;
    if (forceTextInputStateSync) {
      _syncTextInputState(force: true);
    }
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.search:
      case TextInputAction.send:
        _focusNode.unfocus();
      default:
        break;
    }
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _textInputConnection = null;
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  void showToolbar() {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void performSelector(String selectorName) {
    _interactionController.performSelector(selectorName);
  }

  void _handleFocusChanged() {
    if (_editorResourcesReleased) {
      _pendingShowTextInput = false;
      _closeTextInputConnection();
      return;
    }
    if (_focusNode.hasFocus) {
      final show = _pendingShowTextInput;
      _pendingShowTextInput = false;
      _openTextInputConnection(show: show);
    } else {
      _pendingShowTextInput = false;
      _closeTextInputConnection();
    }
  }

  void _openTextInputConnection({required bool show}) {
    if (_editorResourcesReleased ||
        !_platformBehavior.usesPlatformTextInput ||
        !_focusNode.hasFocus ||
        !mounted) {
      return;
    }
    final configuration = TextInputConfiguration(
      viewId: View.of(context).viewId,
      inputType: TextInputType.multiline,
      inputAction: _platformBehavior.usesTextInputNewlineAction
          ? TextInputAction.newline
          : TextInputAction.none,
      readOnly: _session.settings.isReadOnly(),
      autocorrect: true,
      enableSuggestions: true,
      enableDeltaModel: _platformBehavior.usesDeltaTextInputModel,
    );
    if (_textInputConnection?.attached ?? false) {
      _textInputConnection!.updateConfig(configuration);
    } else {
      _textInputConnection = TextInput.attach(this, configuration);
    }
    _updateTextInputStyle();
    _syncTextInputState(force: true);
    _updateTextInputGeometry();
    if (show || !_platformBehavior.showsSoftKeyboard) {
      _textInputConnection?.show();
    }
  }

  void _closeTextInputConnection() {
    _textInputConnection?.close();
    _textInputConnection = null;
    _clearTextInputStateContext();
  }

  void _syncTextInputState({bool force = false}) {
    final nextValue = _buildEditingValueFromEditor();
    if (!force && nextValue == _textEditingValue) {
      return;
    }
    _textEditingValue = nextValue;
    if (_textInputConnection?.attached ?? false) {
      _updateTextInputStyle();
      _textInputConnection!.setEditingState(nextValue);
    }
  }

  bool _ensureTextInputContextReady() {
    if (_textInputContextReady) {
      return true;
    }
    _syncTextInputState(force: true);
    return _textInputContextReady;
  }

  void _updateTextInputStyle() {
    if (!(_textInputConnection?.attached ?? false)) {
      return;
    }
    _textInputConnection!.setStyle(
      fontFamily: _session.effectiveFontFamily,
      fontSize: _session.settings.getEditorTextSize() * _session.effectiveScale,
      fontWeight: FontWeight.w400,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
  }

  void _updateTextInputGeometry() {
    if (!(_textInputConnection?.attached ?? false)) {
      return;
    }
    final renderBox =
        _editorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    _textInputConnection!.setEditableSizeAndTransform(
      renderBox.size,
      renderBox.getTransformTo(null),
    );

    final cursor = _session.renderModel.cursor;
    if (cursor.visible) {
      _textInputConnection!.setCaretRect(
        Rect.fromLTWH(cursor.position.x, cursor.position.y, 1, cursor.height),
      );
    }
  }

  TextEditingValue _buildEditingValueFromEditor() {
    final editorCore = _session.editorCore;
    if (editorCore == null) {
      _clearTextInputStateContext();
      return TextEditingValue.empty;
    }

    final inputContext = editorCore.getImeTextUpdateInputContext(
      _platformBehavior.imeTextUpdateScope,
      1024,
      1024,
    );
    final exposesTextWindow =
        inputContext.kind == core.ImeInputContextKind.documentWindow ||
        inputContext.kind == core.ImeInputContextKind.transientInput;
    _textInputContextReady = exposesTextWindow && inputContext.id != 0;
    _textInputContextId = _textInputContextReady ? inputContext.id : 0;
    _textInputContextRevision = _textInputContextReady
        ? inputContext.revision
        : 0;
    _textInputDocumentStartOffset = _textInputContextReady
        ? inputContext.documentStartOffset
        : 0;

    final text = exposesTextWindow ? inputContext.text : '';
    final selectionStart = _normalizeTextInputOffset(
      exposesTextWindow ? inputContext.selection.start : 0,
      text,
    );
    final selectionEnd = _normalizeTextInputOffset(
      exposesTextWindow ? inputContext.selection.end : 0,
      text,
    );
    final selection = TextSelection(
      baseOffset: selectionStart,
      extentOffset: selectionEnd,
    );
    var composing = TextRange.empty;
    final core.ImeOffsetRange? markedRange =
        exposesTextWindow && inputContext.hasSystemMarkRange
        ? inputContext.systemMarkRange
        : exposesTextWindow && inputContext.hasPreeditRange
        ? inputContext.preeditRange
        : null;
    if (markedRange != null) {
      final composingStart = _normalizeTextInputOffset(markedRange.start, text);
      final composingEnd = _normalizeTextInputOffset(markedRange.end, text);
      if (composingEnd > composingStart) {
        composing = TextRange(start: composingStart, end: composingEnd);
      }
    }
    final editingValue = TextEditingValue(
      text: text,
      selection: selection,
      composing: composing,
    );
    return editingValue;
  }

  void _clearTextInputStateContext() {
    _textInputContextId = 0;
    _textInputContextRevision = 0;
    _textInputDocumentStartOffset = 0;
    _textInputContextReady = false;
  }

  bool _dispatchImeAction(
    core.EditorActionResult result, {
    bool clearTextInputContext = true,
  }) {
    _dispatchEditorActionResult(result);
    if (result.imeSync.clearSystemMark && clearTextInputContext) {
      _clearTextInputStateContext();
    }
    return result.imeSync.clearSystemMark;
  }

  bool _isActiveTextRange(TextRange range, String text) {
    return range.isValid &&
        !range.isCollapsed &&
        range.start >= 0 &&
        range.end <= text.length;
  }

  bool _isValidSelection(TextSelection selection, String text) {
    return selection.isValid &&
        selection.start >= 0 &&
        selection.end >= 0 &&
        selection.start <= text.length &&
        selection.end <= text.length;
  }

  int _normalizeTextInputOffset(int offset, String text) {
    return math.max(0, math.min(offset, text.length));
  }

  void _handleEditorActionResult(core.EditorActionResult result) {
    if (_editorResourcesReleased) return;
    if (result.needsImeSync && !_handlingTextInputUpdate) {
      _syncTextInputState(force: true);
    }
    if (result.gestureType == core.GestureType.undefined) {
      return;
    }
    if (result.gestureType != core.GestureType.tap) {
      _pendingShowTextInput = false;
      return;
    }

    final shouldShowKeyboard =
        _platformBehavior.showsSoftKeyboard &&
        result.hitTarget.type == core.HitTargetType.none;
    if (!_focusNode.hasFocus) {
      _pendingShowTextInput = shouldShowKeyboard;
      _focusNode.requestFocus();
      return;
    }

    _pendingShowTextInput = false;
    if (shouldShowKeyboard) {
      _openTextInputConnection(show: true);
    }
  }

  void _dispatchEditorActionResult(core.EditorActionResult? result) {
    if (result == null) return;
    _interactionController.resetCursorBlink();
    _session.handleEditorActionResult(result);
  }

  MouseCursor _resolveMouseCursor() {
    if (_editorResourcesReleased || !_platformBehavior.usesMouseCursor) {
      return SystemMouseCursors.basic;
    }
    switch (_pointerCursorType) {
      case core.PointerCursorType.default_:
        return SystemMouseCursors.basic;
      case core.PointerCursorType.text:
        return SystemMouseCursors.text;
      case core.PointerCursorType.hand:
        return SystemMouseCursors.click;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: !_editorResourcesReleased,
      skipTraversal: _editorResourcesReleased,
      onKeyEvent: _editorResourcesReleased
          ? (_, _) => KeyEventResult.ignored
          : _interactionController.handleKeyEvent,
      child: IgnorePointer(
        ignoring: _editorResourcesReleased,
        child: MouseRegion(
          cursor: _resolveMouseCursor(),
          onExit: (event) => _interactionController.onPointerExit(event),
          child: Listener(
            onPointerDown: _interactionController.onPointerDown,
            onPointerMove: _interactionController.onPointerMove,
            onPointerHover: _interactionController.onPointerHover,
            onPointerUp: _interactionController.onPointerUp,
            onPointerCancel: _interactionController.onPointerCancel,
            onPointerSignal: _interactionController.onPointerSignal,
            onPointerPanZoomStart: _interactionController.onPointerPanZoomStart,
            onPointerPanZoomUpdate:
                _interactionController.onPointerPanZoomUpdate,
            onPointerPanZoomEnd: _interactionController.onPointerPanZoomEnd,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final newSize = constraints.biggest;
                if (newSize != _session.viewportSize &&
                    newSize.width > 0 &&
                    newSize.height > 0) {
                  _scheduleViewportUpdate(newSize);
                }

                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _overlayCoordinator.overlayListenable,
                    builder: (context, child) {
                      final completionOverlay =
                          _overlayCoordinator.completionOverlay.value;
                      final inlineSuggestionOverlay =
                          _overlayCoordinator.inlineSuggestionOverlay.value;
                      final selectionMenuOverlay =
                          _overlayCoordinator.selectionMenuOverlay.value;

                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: child!),
                          if (completionOverlay != null)
                            CompletionPopupWidget(
                              items: completionOverlay.items,
                              selectedIndex: completionOverlay.selectedIndex,
                              position: completionOverlay.position,
                              theme: _session.theme,
                              itemBuilder: _session
                                  .completionPopupController
                                  .itemBuilder,
                              viewportSize: newSize,
                              onItemTap: (index) => _session
                                  .completionPopupController
                                  .confirmItem(index),
                            ),
                          if (inlineSuggestionOverlay != null)
                            InlineSuggestionBarWidget(
                              x: inlineSuggestionOverlay.x,
                              y: inlineSuggestionOverlay.y,
                              cursorHeight:
                                  inlineSuggestionOverlay.cursorHeight,
                              theme: _session.theme,
                              onAccept: () =>
                                  _session.inlineSuggestionController.accept(),
                              onDismiss: () =>
                                  _session.inlineSuggestionController.dismiss(),
                            ),
                          if (selectionMenuOverlay != null &&
                              selectionMenuOverlay.isNotEmpty)
                            SelectionMenuWidget(
                              position: _overlayCoordinator
                                  .computeSelectionMenuPosition(
                                    newSize,
                                    selectionMenuOverlay,
                                  ),
                              items: selectionMenuOverlay,
                              theme: _session.theme,
                              onItemTap:
                                  _interactionController.onSelectionMenuItemTap,
                            ),
                        ],
                      );
                    },
                    child: SizedBox.expand(
                      key: _editorKey,
                      child: CustomPaint(
                        size: newSize,
                        painter: _session.painter,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
