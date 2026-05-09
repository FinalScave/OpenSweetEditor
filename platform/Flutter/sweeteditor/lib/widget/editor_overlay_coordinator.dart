part of '../sweeteditor.dart';

const double _kSelectionMenuMeasureHeight = 36;
const double _kSelectionMenuMeasureHorizontalInset = 4;
const double _kSelectionMenuMeasureItemHorizontalPadding = 12;
const double _kSelectionMenuMeasureFontSize = 12;
const double _kSelectionMenuMeasureDividerWidth = 1;

class EditorOverlayCoordinator {
  EditorOverlayCoordinator({
    required EditorSession session,
    required EditorPlatformBehavior platformBehavior,
  }) : _session = session,
       _platformBehavior = platformBehavior {
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
  final EditorPlatformBehavior _platformBehavior;
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
    final handleClearance = _platformBehavior.selectionMenuHandleClearance;

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
