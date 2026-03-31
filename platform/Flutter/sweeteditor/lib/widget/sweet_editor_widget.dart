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
/// controller.loadText('hello world');
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
    with TickerProviderStateMixin {
  late EditorSession _session;
  late EditorOverlayCoordinator _overlayCoordinator;
  late EditorInteractionController _interactionController;
  Size? _pendingViewportSize;
  bool _viewportUpdateScheduled = false;

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
    _initEditor();
  }

  @override
  void dispose() {
    _interactionController.dispose();
    _overlayCoordinator.dispose();
    _completionProviderManager.dispose();
    _decorationProviderManager.dispose();
    widget.controller._detach();
    _session.dispose();
    super.dispose();
  }

  void _initEditor() {
    _initSubsystems();
    _session.onRequestDecorationRefresh =
        _decorationProviderManager.requestRefresh;
    _session.onRenderModelUpdated = _overlayCoordinator.onRenderModelUpdated;
    _session.bindSettings();
    _session.setHandleConfig(_computeHandleHitConfig());
    widget.controller._attach(this);
    _interactionController.startCursorBlink();
  }

  void _initSubsystems() {
    _session = EditorSession(
      controller: widget.controller,
      theme: widget.theme ?? EditorTheme.dark(),
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      completionPopupController: CompletionPopupController(
        panelBgColor: widget.theme?.completionBgColor ??
            EditorTheme.dark().completionBgColor,
        panelBorderColor: widget.theme?.completionBorderColor ??
            EditorTheme.dark().completionBorderColor,
        selectedBgColor: widget.theme?.completionSelectedBgColor ??
            EditorTheme.dark().completionSelectedBgColor,
        labelColor:
            widget.theme?.completionLabelColor ?? EditorTheme.dark().completionLabelColor,
        detailColor: widget.theme?.completionDetailColor ??
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

  void _loadText(String text) {
    _session.loadText(text);
    _decorationProviderManager.onDocumentLoaded();
    _eventBus.publish(DocumentLoadedEvent());
    _flush();
  }

  String _getContent() => _session.getContent();

  void _flush() {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _interactionController.handleKeyEvent,
      child: Listener(
        onPointerDown: _interactionController.onPointerDown,
        onPointerMove: _interactionController.onPointerMove,
        onPointerUp: _interactionController.onPointerUp,
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
                          onDismiss: () => _inlineSuggestionController.dismiss(),
                        ),
                      if (selectionMenuOverlay != null &&
                          selectionMenuOverlay.items.isNotEmpty)
                        SelectionMenuWidget(
                          position:
                              _overlayCoordinator.computeSelectionMenuPosition(
                                newSize,
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
