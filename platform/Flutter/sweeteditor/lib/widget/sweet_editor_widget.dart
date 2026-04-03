part of '../sweeteditor.dart';

/// A Flutter widget that wraps the native SweetEditor engine.
///
/// Renders a full code editor with syntax highlighting, cursor, selection,
/// completion popup, inline suggestions, decorations, guides, and scrollbars.
///
/// Usage:
/// ```
/// final controller = SweetEditorController();
/// SweetEditorWidget(controller: controller);
/// controller.loadDocument(core.Document.fromString('hello world'));
/// ```
class SweetEditorWidget extends StatefulWidget {
  const SweetEditorWidget({
    super.key,
    required this.controller,
    this.theme,
    this.fontFamily = 'monospace',
    this.fontSize = 14,
    this.autofocus = true,
  });

  final SweetEditorController controller;
  final EditorTheme? theme;
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
  late final FocusNode _focusNode;
  final GlobalKey _editorKey = GlobalKey();
  TextInputConnection? _textInputConnection;
  TextEditingValue _textEditingValue = TextEditingValue.empty;
  bool _handlingTextInputUpdate = false;
  bool _pendingShowTextInput = false;
  Size? _pendingViewportSize;
  bool _viewportUpdateScheduled = false;
  bool _released = false;

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

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'SweetEditor');
    _focusNode.addListener(_handleFocusChanged);
    _initEditor();
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
      _overlayCoordinator.onRenderModelUpdated(model);
      _updateTextInputGeometry();
    };
    _session.bindSettings();
    _session.setHandleConfig(_computeHandleHitConfig());
    _session.setScrollbarConfig(_buildScrollbarConfig());
    widget.controller._attach(this);
    _interactionController.startCursorBlink();
  }

  void _initSubsystems() {
    _session = EditorSession(
      controller: widget.controller,
      theme: widget.theme ?? EditorTheme.dark(),
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      gutterSticky: _isDesktopStylePlatform,
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
      selectionMenuController: SelectionMenuController(),
    );

    final completionProviderManager = _session.completionProviderManager;
    _overlayCoordinator = EditorOverlayCoordinator(session: _session);
    _interactionController = EditorInteractionController(
      session: _session,
      tickerProvider: this,
    );

    _session.completionPopupController.setConfirmHandler(
      _interactionController.onCompletionItemConfirmed,
    );
    completionProviderManager.setListener(_session.completionPopupController);
  }

  static core.HandleConfig _computeHandleHitConfig() {
    const double r = 10.0;
    const double d = 24.0;
    const double angle = 45.0 * math.pi / 180.0;
    final cos = math.cos(angle);
    final sin = math.sin(angle);

    final points = <List<double>>[
      [0, 0],
      [-r, d],
      [r, d],
      [0, d + r],
      [0, d - r * 0.8],
    ];

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in points) {
      final rx = p[0] * cos - p[1] * sin;
      final ry = p[0] * sin + p[1] * cos;
      minX = math.min(minX, rx);
      minY = math.min(minY, ry);
      maxX = math.max(maxX, rx);
      maxY = math.max(maxY, ry);
    }

    const pad = 8.0;
    return core.HandleConfig(
      startLeft: minX - pad,
      startTop: minY - pad,
      startRight: maxX + pad,
      startBottom: maxY + pad,
      endLeft: -maxX - pad,
      endTop: minY - pad,
      endRight: -minX + pad,
      endBottom: maxY + pad,
    );
  }

  core.ScrollbarConfig _buildScrollbarConfig() {
    final isMobile = !_isDesktopStylePlatform;
    return core.ScrollbarConfig(
      thickness: isMobile ? 8.0 : 6.0,
      minThumb: isMobile ? 40.0 : 32.0,
      thumbHitPadding: isMobile ? 20.0 : 0.0,
      mode: core.ScrollbarMode.transient,
      thumbDraggable: true,
      trackTapMode: core.ScrollbarTrackTapMode.disabled,
      fadeDelayMs: 700,
      fadeDurationMs: 300,
    );
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

  void _applyLanguageConfiguration(LanguageConfiguration? config) {
    _session.applyLanguageConfiguration(config);
    _decorationProviderManager.requestRefresh();
    _flush();
  }

  void _releaseFromController() {
    if (_released) return;
    _closeTextInputConnection();
    _releaseEditorResources();
    if (mounted) {
      setState(() {});
    }
  }

  void _releaseEditorResources() {
    if (_released) return;
    _released = true;
    _interactionController.dispose();
    _overlayCoordinator.dispose();
    _completionProviderManager.dispose();
    _decorationProviderManager.dispose();
    widget.controller._detach();
    _session.dispose();
  }

  bool get _usesPlatformTextInput =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _isDesktopStylePlatform =>
      kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS);

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
      if (value.text != previousValue.text) {
        final change = _computeTextReplacement(previousValue.text, value.text);
        final replaceRange = core.TextRange(
          _offsetToTextPosition(previousValue.text, change.$1),
          _offsetToTextPosition(previousValue.text, change.$2),
        );
        _interactionController.replaceText(
          replaceRange,
          change.$3,
          action: value.composing.isValid && !value.composing.isCollapsed
              ? TextChangeAction.composition
              : TextChangeAction.key,
        );
      }

      if (value.selection != previousValue.selection ||
          value.text != previousValue.text) {
        _applySelectionFromTextInput(value.selection, value.text);
      }
    } finally {
      _handlingTextInputUpdate = false;
    }

    _syncTextInputState(force: true);
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
  void performSelector(String selectorName) {}

  void _handleFocusChanged() {
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
    if (!_usesPlatformTextInput || !_focusNode.hasFocus || !mounted) {
      return;
    }
    final configuration = TextInputConfiguration(
      viewId: View.of(context).viewId,
      inputType: TextInputType.multiline,
      inputAction: TextInputAction.newline,
      readOnly: widget.controller.settings.isReadOnly(),
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
    if (show) {
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
      fontFamily: widget.controller.settings.getFontFamily(),
      fontSize:
          widget.controller.settings.getEditorTextSize() *
          widget.controller.settings.getScale(),
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
    final text = _getContent();
    final selection = _buildTextSelection(text);
    return TextEditingValue(
      text: text,
      selection: selection,
      composing: TextRange.empty,
    );
  }

  TextSelection _buildTextSelection(String text) {
    final selection = _editorCore?.getSelection();
    if (selection != null) {
      return TextSelection(
        baseOffset: _textPositionToOffset(text, selection.start),
        extentOffset: _textPositionToOffset(text, selection.end),
      );
    }
    final cursor =
        _editorCore?.getCursorPosition() ?? const core.TextPosition(0, 0);
    final offset = _textPositionToOffset(text, cursor);
    return TextSelection.collapsed(offset: offset);
  }

  void _applySelectionFromTextInput(TextSelection selection, String text) {
    final editorCore = _editorCore;
    if (editorCore == null) return;
    final startOffset = selection.start.clamp(0, text.length);
    final endOffset = selection.end.clamp(0, text.length);
    final start = _offsetToTextPosition(text, startOffset);
    final end = _offsetToTextPosition(text, endOffset);
    if (selection.isCollapsed) {
      editorCore.setCursorPosition(end.line, end.column);
      _eventBus.publish(CursorChangedEvent(cursorPosition: end));
      _eventBus.publish(
        SelectionChangedEvent(
          hasSelection: false,
          selection: null,
          cursorPosition: end,
        ),
      );
    } else {
      final range = core.TextRange(start, end);
      editorCore.setSelection(start.line, start.column, end.line, end.column);
      _eventBus.publish(CursorChangedEvent(cursorPosition: end));
      _eventBus.publish(
        SelectionChangedEvent(
          hasSelection: true,
          selection: range,
          cursorPosition: end,
        ),
      );
    }
    _selectionMenuController.hide();
    _flush();
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
    if (result == null) return;
    if (result.type != core.GestureType.tap) {
      _pendingShowTextInput = false;
      return;
    }

    final shouldShowKeyboard = result.hitTarget.type == core.HitTargetType.none;
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

  @override
  Widget build(BuildContext context) {
    if (_released) {
      return const SizedBox.shrink();
    }
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _interactionController.handleKeyEvent,
      child: Listener(
        onPointerDown: _interactionController.onPointerDown,
        onPointerMove: _interactionController.onPointerMove,
        onPointerUp: (event) {
          final result = _interactionController.onPointerUp(event);
          _handleGestureInputResult(result);
        },
        onPointerSignal: _interactionController.onPointerSignal,
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
                  final inlineSuggestionOverlay =
                      _overlayCoordinator.inlineSuggestionOverlay.value.data;
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
                          themeColors: _completionPopupController.themeColors,
                          viewportSize: newSize,
                          onItemTap: (index) =>
                              _completionPopupController.confirmItem(index),
                        ),
                      if (inlineSuggestionOverlay != null)
                        InlineSuggestionBarWidget(
                          x: inlineSuggestionOverlay.x,
                          y: inlineSuggestionOverlay.y,
                          cursorHeight: inlineSuggestionOverlay.cursorHeight,
                          theme: _theme,
                          onAccept: () => _inlineSuggestionController.accept(),
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
    );
  }
}
