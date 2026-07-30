part of '../sweeteditor.dart';

const double _kSelectionMenuMeasureHeight = 36;
const double _kSelectionMenuMeasureHorizontalInset = 4;
const double _kSelectionMenuMeasureItemHorizontalPadding = 12;
const double _kSelectionMenuMeasureFontSize = 12;
const double _kSelectionMenuMeasureDividerWidth = 1;

class EditorOverlayCoordinator {
  EditorOverlayCoordinator({required EditorSession session})
    : _session = session {
    _session.completionPopupController.bindOverlay(
      _createOverlayUpdater(_completionOverlay),
    );
    _session.inlineSuggestionController.bindOverlay(
      _createOverlayUpdater(_inlineSuggestionOverlay),
    );
    _session.selectionMenuController.bindOverlay(
      _createOverlayUpdater(_selectionMenuOverlay),
    );
  }

  final EditorSession _session;
  final ValueNotifier<CompletionPopupOverlayState?> _completionOverlay =
      ValueNotifier(null);
  final ValueNotifier<InlineSuggestionOverlayState?> _inlineSuggestionOverlay =
      ValueNotifier(null);
  final ValueNotifier<List<SelectionMenuItem>?> _selectionMenuOverlay =
      ValueNotifier(null);
  late final Listenable _overlayListenable = Listenable.merge([
    _completionOverlay,
    _inlineSuggestionOverlay,
    _selectionMenuOverlay,
  ]);

  ValueNotifier<CompletionPopupOverlayState?> get completionOverlay =>
      _completionOverlay;
  ValueNotifier<InlineSuggestionOverlayState?> get inlineSuggestionOverlay =>
      _inlineSuggestionOverlay;
  ValueNotifier<List<SelectionMenuItem>?> get selectionMenuOverlay =>
      _selectionMenuOverlay;
  Listenable get overlayListenable => _overlayListenable;

  void onRenderModelUpdated(core.EditorRenderModel model) {
    if (_session.completionPopupController.isShowing && model.cursor.visible) {
      _session.completionPopupController.updateCursorPosition(
        model.cursor.position.x,
        model.cursor.position.y,
        model.cursor.height,
      );
    }

    if (_session.inlineSuggestionController.isShowing && model.cursor.visible) {
      _session.inlineSuggestionController.updatePosition(
        model.cursor.position.x,
        model.cursor.position.y,
        model.cursor.height,
      );
    }

    final selectionMenuItems = _selectionMenuOverlay.value;
    if (selectionMenuItems != null) {
      _selectionMenuOverlay.value = List<SelectionMenuItem>.unmodifiable(
        selectionMenuItems,
      );
    }
  }

  Offset computeSelectionMenuPosition(
    Size viewportSize,
    List<SelectionMenuItem> items,
  ) {
    final model = _session.renderModel;
    final start = model.selectionStartHandle;
    final end = model.selectionEndHandle;

    double anchorX;
    double topY;
    double bottomY;
    if (start.visible) {
      final startX = start.position.x;
      final startY = start.position.y;
      final startBottom = startY + start.height;
      final endX = end.visible ? end.position.x : startX;
      final endY = end.visible ? end.position.y : startY;
      final endBottom = end.visible ? endY + end.height : startBottom;
      anchorX = (startX + endX) * 0.5;
      topY = math.min(startY, endY);
      bottomY = math.max(startBottom, endBottom);
    } else {
      anchorX = viewportSize.width * 0.5;
      topY = 0;
      bottomY = 0;
    }

    final menuWidth = _measureSelectionMenuWidth(items);
    const menuHeight = _kSelectionMenuMeasureHeight;
    const offsetY = 8.0;
    final handleClearance = _session.platformBehavior.isMobileStyle
        ? 32.0
        : 0.0;

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

  EditorOverlayUpdater<T> _createOverlayUpdater<T>(ValueNotifier<T?> target) =>
      (data) => target.value = data;

  double _measureSelectionMenuWidth(List<SelectionMenuItem> items) {
    if (items.isEmpty) return 0;
    var width = _kSelectionMenuMeasureHorizontalInset * 2;
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        width += _kSelectionMenuMeasureDividerWidth;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: items[i].label,
          style: const TextStyle(fontSize: _kSelectionMenuMeasureFontSize),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      width += painter.width + _kSelectionMenuMeasureItemHorizontalPadding * 2;
    }
    return width;
  }
}
