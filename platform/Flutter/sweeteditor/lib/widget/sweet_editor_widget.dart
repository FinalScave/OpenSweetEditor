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
    with TickerProviderStateMixin, TextInputClient {
  late EditorSession _session;
  late EditorOverlayCoordinator _overlayCoordinator;
  late EditorInteractionController _interactionController;
  late final EditorPlatformBehavior _platformBehavior;
  late final FocusNode _focusNode;
  final GlobalKey _editorKey = GlobalKey();
  TextInputConnection? _textInputConnection;
  TextEditingValue _textEditingValue = TextEditingValue.empty;
  int _textInputWindowStartOffset = 0;
  bool _handlingTextInputUpdate = false;
  bool _pendingShowTextInput = false;
  Size? _pendingViewportSize;
  bool _viewportUpdateScheduled = false;
  bool _editorResourcesReleased = false;
  core.PointerCursorType _pointerCursorType = core.PointerCursorType.text;

  EditorEventBus get _eventBus => widget.controller._eventBus;
  core.EditorCore? get _editorCore => _session.editorCore;
  core.Document? get _document => _session.document;
  EditorTheme get _theme => _session.theme;
  EditorCanvasPainter get _painter => _session.painter;
  CompletionProviderManager get _completionProviderManager =>
      _session.completionProviderManager;
  CompletionPopupController get _completionPopupController =>
      _session.completionPopupController;
  InlineSuggestionController get _inlineSuggestionController =>
      _session.inlineSuggestionController;
  DecorationProviderManager get _decorationProviderManager =>
      _session.decorationProviderManager;
  NewLineActionProviderManager get _newLineActionProviderManager =>
      _session.newLineActionProviderManager;
  SelectionMenuController get _selectionMenuController =>
      _session.selectionMenuController;
  EditorSettings get _settings => _session.settings;

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
    _session.onRequestDecorationRefresh =
        _decorationProviderManager.requestRefresh;
    _session.onRenderModelUpdated = (model) {
      final pointerCursorChanged =
          model.pointerCursorType != _pointerCursorType;
      _pointerCursorType = model.pointerCursorType;
      _overlayCoordinator.onRenderModelUpdated(model);
      _updateTextInputGeometry();
      if (pointerCursorChanged && mounted) {
        setState(() {});
      }
    };
    _session.onPlatformScaleChanged = _updateTextInputStyle;
    _session.bindSettings();
    _session.setHandleConfig(_platformBehavior.handleConfig);
    _session.setScrollbarConfig(_platformBehavior.scrollbarConfig);
    _applyDeclarativeInputs();
    widget.controller._attach(this);
    _interactionController.startCursorBlink();
  }

  void _initSubsystems() {
    _session = EditorSession(
      controller: widget.controller,
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
      completionPopupController: CompletionPopupController(
        panelBgColor:
            widget.theme?.completionBgColor ??
            EditorTheme.dark().completionBgColor,
        panelBorderColor:
            widget.theme?.completionBorderColor ??
            EditorTheme.dark().completionBorderColor,
        selectedBgColor:
            widget.theme?.completionSelectedBgColor ??
            EditorTheme.dark().completionSelectedBgColor,
        labelColor:
            widget.theme?.completionLabelColor ??
            EditorTheme.dark().completionLabelColor,
        detailColor:
            widget.theme?.completionDetailColor ??
            EditorTheme.dark().completionDetailColor,
      ),
      selectionMenuController: SelectionMenuController(
        enabled: _platformBehavior.showsFloatingSelectionMenu,
      ),
    );

    final completionProviderManager = _session.completionProviderManager;
    _overlayCoordinator = EditorOverlayCoordinator(
      session: _session,
      platformBehavior: _platformBehavior,
    );
    _interactionController = EditorInteractionController(
      session: _session,
      tickerProvider: this,
    );

    _session.completionPopupController.setConfirmHandler(
      _interactionController.onCompletionItemConfirmed,
    );
    completionProviderManager.setListener(_session.completionPopupController);
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
    _decorationProviderManager.onDocumentLoaded();
    _eventBus.publish(DocumentLoadedEvent());
    _flush();
  }

  String _getContent() => _session.getContent();

  void _flush() {
    if (!mounted) return;
    if (!_handlingTextInputUpdate) {
      _syncTextInputState();
    }
    _session.requestFlush();
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
        _flush();
      }
    });
  }

  void _applyTheme(EditorTheme theme) {
    _session.applyTheme(theme);
    _overlayCoordinator.applyTheme(theme);
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
    _decorationProviderManager.requestRefresh();
    _flush();
  }

  void _applyMetadata(EditorMetadata? metadata) {
    _session.applyMetadata(metadata);
    _decorationProviderManager.requestRefresh();
    _flush();
  }

  void _releaseEditorResources() {
    if (_editorResourcesReleased) return;
    _editorResourcesReleased = true;
    _interactionController.dispose();
    _overlayCoordinator.dispose();
    _completionProviderManager.dispose();
    _decorationProviderManager.dispose();
    widget.controller._detach();
    _session.dispose();
  }

  @override
  TextEditingValue? get currentTextEditingValue => _textEditingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    final editorCore = _editorCore;
    if (editorCore == null) {
      _textEditingValue = value;
      return;
    }
    if (value == _textEditingValue) {
      return;
    }

    final previousValue = _textEditingValue;
    _handlingTextInputUpdate = true;
    try {
      _applyImeEditingValue(editorCore, previousValue, value);
    } finally {
      _handlingTextInputUpdate = false;
    }

    _textEditingValue = value;
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
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _textInputConnection = null;
  }

  @override
  void showToolbar() {}

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
      inputAction: TextInputAction.newline,
      readOnly: _settings.isReadOnly(),
      autocorrect: false,
      enableSuggestions: false,
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

  void _updateTextInputStyle() {
    if (!(_textInputConnection?.attached ?? false)) {
      return;
    }
    _textInputConnection!.setStyle(
      fontFamily: _settings.getFontFamily(),
      fontSize: _settings.getEditorTextSize() * _session.effectiveScale,
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
    final snapshot = _editorCore?.getImeSyncSnapshot();
    if (snapshot == null) {
      _textInputWindowStartOffset = 0;
      return TextEditingValue.empty;
    }
    final documentText = _getContent();
    final cursorOffset = _textPositionToOffset(documentText, snapshot.cursor);
    final exposesTextWindow =
        snapshot.contextPolicy != core.ImeContextPolicy.none ||
        snapshot.platformTextWindowText.isNotEmpty;
    final text = exposesTextWindow ? snapshot.platformTextWindowText : '';
    _textInputWindowStartOffset = exposesTextWindow
        ? _normalizeDocumentOffset(
            snapshot.platformTextWindowStartOffset,
            documentText,
          )
        : cursorOffset;
    final selectionStart = _normalizeTextInputOffset(
      exposesTextWindow ? snapshot.platformTextWindowSelectionStartOffset : 0,
      text,
    );
    final selectionEnd = _normalizeTextInputOffset(
      exposesTextWindow ? snapshot.platformTextWindowSelectionEndOffset : 0,
      text,
    );
    final selection = TextSelection(
      baseOffset: selectionStart,
      extentOffset: selectionEnd,
    );
    var composing = TextRange.empty;
    if (snapshot.platformTextWindowComposingStartOffset >= 0 &&
        snapshot.platformTextWindowComposingEndOffset >= 0) {
      final composingStart = _normalizeTextInputOffset(
        snapshot.platformTextWindowComposingStartOffset,
        text,
      );
      final composingEnd = _normalizeTextInputOffset(
        snapshot.platformTextWindowComposingEndOffset,
        text,
      );
      if (composingEnd > composingStart) {
        composing = TextRange(start: composingStart, end: composingEnd);
      }
    }
    return TextEditingValue(
      text: text,
      selection: selection,
      composing: composing,
    );
  }

  void _applyImeEditingValue(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
  ) {
    final textChanged = value.text != previousValue.text;
    final composingActive = _isActiveTextRange(value.composing, value.text);
    final previousComposingActive = _isActiveTextRange(
      previousValue.composing,
      previousValue.text,
    );

    if (textChanged) {
      final change = _computeTextReplacement(previousValue.text, value.text);
      if (composingActive) {
        final preeditText = value.text.substring(
          value.composing.start,
          value.composing.end,
        );
        _dispatchImeAction(editorCore.updateImePreedit(preeditText));
      } else {
        final documentText = _getContent();
        final range = _textInputOffsetsToDocumentRange(
          documentText,
          change.$1,
          change.$2,
        );
        final replacingComposition =
            previousComposingActive || editorCore.isComposing;
        final core.ImeActionResult result;
        if (replacingComposition || change.$1 == change.$2) {
          result = editorCore.commitImeText(change.$3);
        } else {
          result = editorCore.replaceImeText(range, change.$3);
        }
        _dispatchImeAction(result);
      }
    } else if (composingActive) {
      final documentText = _getContent();
      final range = _textInputOffsetsToDocumentRange(
        documentText,
        value.composing.start,
        value.composing.end,
      );
      final result = previousComposingActive
          ? editorCore.markImeDocumentRange(range)
          : editorCore.updateImePreedit(
              value.text.substring(value.composing.start, value.composing.end),
            );
      _dispatchImeAction(result);
    } else if (previousComposingActive || editorCore.isComposing) {
      _dispatchImeAction(editorCore.finishImePreedit());
    }

    if (!textChanged &&
        !composingActive &&
        !previousComposingActive &&
        !editorCore.isComposing &&
        value.selection != previousValue.selection) {
      _notifyImeSelectionFromTextInput(editorCore, value);
    }
  }

  void _notifyImeSelectionFromTextInput(
    core.EditorCore editorCore,
    TextEditingValue value,
  ) {
    if (!_isValidSelection(value.selection, value.text)) {
      return;
    }
    final documentText = _getContent();
    final start = _textInputOffsetToDocumentPosition(
      documentText,
      value.selection.start,
    );
    final end = _textInputOffsetToDocumentPosition(
      documentText,
      value.selection.end,
    );
    final result = value.selection.isCollapsed
        ? editorCore.notifyImeCursorChanged(end)
        : editorCore.notifyImeSelectionChanged(core.TextRange(start, end));
    _dispatchImeAction(result);
  }

  void _dispatchImeAction(core.ImeActionResult result) {
    _interactionController.dispatchImeActionResult(result);
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

  int _normalizeDocumentOffset(int offset, String documentText) {
    return math.max(0, math.min(offset, documentText.length));
  }

  core.TextPosition _textInputOffsetToDocumentPosition(
    String documentText,
    int localOffset,
  ) {
    final documentOffset = _normalizeDocumentOffset(
      _textInputWindowStartOffset + localOffset,
      documentText,
    );
    return _offsetToTextPosition(documentText, documentOffset);
  }

  core.TextRange _textInputOffsetsToDocumentRange(
    String documentText,
    int localStart,
    int localEnd,
  ) {
    return core.TextRange(
      _textInputOffsetToDocumentPosition(documentText, localStart),
      _textInputOffsetToDocumentPosition(documentText, localEnd),
    );
  }

  (int, int, String) _computeTextReplacement(String oldText, String newText) {
    var prefix = 0;
    final maxPrefix = math.min(oldText.length, newText.length);
    while (prefix < maxPrefix &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    return (prefix, oldSuffix, newText.substring(prefix, newSuffix));
  }

  int _textPositionToOffset(String text, core.TextPosition position) {
    var line = 0;
    var index = 0;
    while (line < position.line && index < text.length) {
      final codeUnit = text.codeUnitAt(index++);
      if (codeUnit == 0x0D) {
        if (index < text.length && text.codeUnitAt(index) == 0x0A) {
          index++;
        }
        line++;
      } else if (codeUnit == 0x0A) {
        line++;
      }
    }
    return (index + position.column).clamp(0, text.length);
  }

  core.TextPosition _offsetToTextPosition(String text, int offset) {
    final clampedOffset = offset.clamp(0, text.length);
    var line = 0;
    var column = 0;
    var index = 0;
    while (index < clampedOffset) {
      final codeUnit = text.codeUnitAt(index++);
      if (codeUnit == 0x0D) {
        if (index < text.length &&
            text.codeUnitAt(index) == 0x0A &&
            index < clampedOffset) {
          index++;
        }
        line++;
        column = 0;
      } else if (codeUnit == 0x0A) {
        line++;
        column = 0;
      } else {
        column++;
      }
    }
    return core.TextPosition(line, column);
  }

  void _handleGestureInputResult(core.GestureResult? result) {
    if (_editorResourcesReleased) return;
    if (result == null) return;
    if (result.type != core.GestureType.tap) {
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
            onPointerUp: (event) {
              final result = _interactionController.onPointerUp(event);
              _handleGestureInputResult(result);
            },
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
                          _overlayCoordinator.completionOverlay.value.data;
                      final inlineSuggestionOverlay = _overlayCoordinator
                          .inlineSuggestionOverlay
                          .value
                          .data;
                      final selectionMenuOverlay =
                          _overlayCoordinator.selectionMenuOverlay.value.data;

                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: child!),
                          if (completionOverlay != null)
                            CompletionPopupWidget(
                              items: completionOverlay.items,
                              selectedIndex: completionOverlay.selectedIndex,
                              position: completionOverlay.position,
                              themeColors:
                                  _completionPopupController.themeColors,
                              viewportSize: newSize,
                              onItemTap: (index) =>
                                  _completionPopupController.confirmItem(index),
                            ),
                          if (inlineSuggestionOverlay != null)
                            InlineSuggestionBarWidget(
                              x: inlineSuggestionOverlay.x,
                              y: inlineSuggestionOverlay.y,
                              cursorHeight:
                                  inlineSuggestionOverlay.cursorHeight,
                              theme: _theme,
                              onAccept: () =>
                                  _inlineSuggestionController.accept(),
                              onDismiss: () =>
                                  _inlineSuggestionController.dismiss(),
                            ),
                          if (selectionMenuOverlay != null &&
                              selectionMenuOverlay.items.isNotEmpty)
                            SelectionMenuWidget(
                              position: _overlayCoordinator
                                  .computeSelectionMenuPosition(
                                    newSize,
                                    selectionMenuOverlay.items,
                                  ),
                              items: selectionMenuOverlay.items,
                              bgColor: _theme.completionBgColor,
                              textColor: _theme.completionLabelColor,
                              onItemTap:
                                  _interactionController.onSelectionMenuItemTap,
                            ),
                        ],
                      );
                    },
                    child: SizedBox.expand(
                      key: _editorKey,
                      child: CustomPaint(size: newSize, painter: _painter),
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
