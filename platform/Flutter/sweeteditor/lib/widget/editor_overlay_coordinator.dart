part of '../sweeteditor.dart';

class EditorOverlayCoordinator {
  EditorOverlayCoordinator({required EditorSession session}) : _session = session {
    _session.completionPopupController.bindOverlay(
      _createOverlayBinding(_completionOverlay),
    );
    _session.inlineSuggestionController.bindOverlay(
      _createOverlayBinding(_inlineSuggestionOverlay),
    );
    _session.selectionMenuController.buildContext = _buildSelectionMenuContext;
    _session.selectionMenuController.bindOverlay(
      _createOverlayBinding(_selectionMenuOverlay),
    );
  }

  final EditorSession _session;
  final ValueNotifier<EditorOverlayState<CompletionPopupOverlayState>>
  _completionOverlay = ValueNotifier(const EditorOverlayState.hidden());
  final ValueNotifier<EditorOverlayState<InlineSuggestionOverlayState>>
  _inlineSuggestionOverlay = ValueNotifier(const EditorOverlayState.hidden());
  final ValueNotifier<EditorOverlayState<SelectionMenuOverlayState>>
  _selectionMenuOverlay = ValueNotifier(const EditorOverlayState.hidden());
  late final Listenable _overlayListenable = Listenable.merge([
    _completionOverlay,
    _inlineSuggestionOverlay,
    _selectionMenuOverlay,
  ]);

  ValueNotifier<EditorOverlayState<CompletionPopupOverlayState>>
  get completionOverlay => _completionOverlay;
  ValueNotifier<EditorOverlayState<InlineSuggestionOverlayState>>
  get inlineSuggestionOverlay => _inlineSuggestionOverlay;
  ValueNotifier<EditorOverlayState<SelectionMenuOverlayState>>
  get selectionMenuOverlay => _selectionMenuOverlay;
  Listenable get overlayListenable => _overlayListenable;

  void applyTheme(EditorTheme theme) {
    _session.completionPopupController.applyTheme(
      theme.completionBgColor,
      theme.completionBorderColor,
      theme.completionSelectedBgColor,
      theme.completionLabelColor,
      theme.completionDetailColor,
    );
  }

  void onRenderModelUpdated(core.EditorRenderModel model) {
    if (_session.completionPopupController.isShowing && model.cursor.visible) {
      _session.completionPopupController.updateCursorPosition(
        model.cursor.position.x - model.scrollX,
        model.cursor.position.y - model.scrollY,
        model.cursor.height,
      );
    }

    if (_session.inlineSuggestionController.isShowing && model.cursor.visible) {
      _session.inlineSuggestionController.updatePosition(
        model.cursor.position.x - model.scrollX,
        model.cursor.position.y - model.scrollY,
        model.cursor.height,
      );
    }
  }

  Offset computeSelectionMenuPosition(Size viewportSize) {
    final model = _session.renderModel;
    final sx = model.scrollX;
    final sy = model.scrollY;
    final start = model.selectionStartHandle;
    final end = model.selectionEndHandle;

    double anchorX;
    double topY;
    double bottomY;
    if (start.visible) {
      final startX = start.position.x - sx;
      final startY = start.position.y - sy;
      final startBottom = startY + start.height;
      final endX = end.visible ? end.position.x - sx : startX;
      final endY = end.visible ? end.position.y - sy : startY;
      final endBottom = end.visible ? endY + end.height : startBottom;
      anchorX = (startX + endX) * 0.5;
      topY = math.min(startY, endY);
      bottomY = math.max(startBottom, endBottom);
    } else {
      anchorX = viewportSize.width * 0.5;
      topY = 0;
      bottomY = 0;
    }

    const menuWidth = 240.0;
    const menuHeight = 36.0;
    const offsetY = 8.0;
    const handleClearance = 32.0;

    final x = (anchorX - menuWidth / 2)
        .clamp(0.0, math.max(0.0, viewportSize.width - menuWidth))
        .toDouble();
    final aboveY = topY - menuHeight - offsetY;
    final belowY = bottomY + offsetY + handleClearance;
    final y = (aboveY >= 0 ? aboveY : belowY)
        .clamp(0.0, math.max(0.0, viewportSize.height - menuHeight))
        .toDouble();
    return Offset(x, y);
  }

  void dispose() {
    _session.completionPopupController.bindOverlay(null);
    _session.inlineSuggestionController.bindOverlay(null);
    _session.selectionMenuController.bindOverlay(null);
    _completionOverlay.dispose();
    _inlineSuggestionOverlay.dispose();
    _selectionMenuOverlay.dispose();
  }

  SelectionMenuContext _buildSelectionMenuContext(bool hasSelection) {
    final editorCore = _session.editorCore;
    final cursorPosition =
        editorCore?.getCursorPosition() ?? const core.TextPosition(0, 0);
    return SelectionMenuContext(
      hasSelection: hasSelection,
      cursorPosition: cursorPosition,
      selection: editorCore?.getSelection(),
      selectedText: editorCore?.getSelectedText() ?? '',
    );
  }

  EditorOverlayBinding<T> _createOverlayBinding<T>(
    ValueNotifier<EditorOverlayState<T>> target,
  ) {
    void updateOverlay(T? data) {
      target.value = data == null
          ? EditorOverlayState<T>.hidden()
          : EditorOverlayState<T>.visible(data);
    }

    return EditorOverlayBinding<T>(
      show: (data) => updateOverlay(data),
      update: (data) => updateOverlay(data),
      hide: () => updateOverlay(null),
    );
  }
}
