import 'dart:async';

import '../core/editor_core.dart' as core;
import '../widget/editor_overlay.dart';

import 'selection_types.dart';

/// Controls the lifecycle of the selection context menu.
///
/// State machine:
///   HIDDEN --(double-tap/long-press + selection)--> VISIBLE
///   VISIBLE --(handle drag / scroll / scale / tap)--> HIDDEN
///   HIDDEN --(handle drag end + selection)--> VISIBLE
class SelectionMenuController {
  static const int _showDelayMs = 100;

  SelectionMenuController({
    bool enabled = true,
    required SelectionMenuContext Function(bool hasSelection) buildContext,
  }) : _enabled = enabled,
       _buildContext = buildContext;

  final bool _enabled;
  final SelectionMenuContext Function(bool hasSelection) _buildContext;
  SelectionMenuItemProvider? _itemProvider;
  bool _handleDragActive = false;
  bool _hiddenByViewportGesture = false;
  bool _visible = false;
  Timer? _showTimer;
  List<SelectionMenuItem> _currentItems = [];
  EditorOverlayUpdater<List<SelectionMenuItem>>? _overlayUpdater;

  bool get isVisible => _visible;
  List<SelectionMenuItem> get currentItems => _currentItems;

  void setItemProvider(SelectionMenuItemProvider? provider) {
    _itemProvider = provider;
  }

  void bindOverlay(EditorOverlayUpdater<List<SelectionMenuItem>>? updater) {
    _overlayUpdater = updater;
  }

  void onGestureActionResult(
    core.EditorActionResult result,
    bool hasSelection,
  ) {
    if (!_enabled) {
      _hideImmediate();
      return;
    }

    if (result.isHandleDrag) {
      if (!_handleDragActive) {
        _handleDragActive = true;
        _hideImmediate();
      }
      return;
    }

    if (_handleDragActive) {
      _handleDragActive = false;
      if (hasSelection) {
        _scheduleShow(hasSelection);
      }
      return;
    }

    switch (result.gestureType) {
      case core.GestureType.doubleTap:
      case core.GestureType.longPress:
        if (hasSelection) {
          _scheduleShow(hasSelection);
        }
      case core.GestureType.tap:
        _hideImmediate();
      case core.GestureType.scroll:
      case core.GestureType.scale:
        if (_visible && !_hiddenByViewportGesture) {
          _hiddenByViewportGesture = true;
          _hideImmediate();
        }
      case core.GestureType.dragSelect:
        break;
      default:
        break;
    }
  }

  void onSelectAll() {
    if (!_enabled) {
      _hideImmediate();
      return;
    }
    _scheduleShow(true);
  }

  void onTextChanged() {
    _handleDragActive = false;
    _hiddenByViewportGesture = false;
    _hideImmediate();
  }

  List<SelectionMenuItem> _buildItems(bool hasSelection) {
    if (_itemProvider != null) {
      return _itemProvider!.provideMenuItems(_buildContext(hasSelection));
    }
    return _buildDefaultItems(hasSelection);
  }

  static List<SelectionMenuItem> _buildDefaultItems(bool hasSelection) {
    return [
      SelectionMenuItem(
        id: SelectionMenuItem.actionCut,
        label: 'Cut',
        enabled: hasSelection,
      ),
      SelectionMenuItem(
        id: SelectionMenuItem.actionCopy,
        label: 'Copy',
        enabled: hasSelection,
      ),
      SelectionMenuItem(id: SelectionMenuItem.actionPaste, label: 'Paste'),
      SelectionMenuItem(
        id: SelectionMenuItem.actionSelectAll,
        label: 'Select All',
      ),
    ];
  }

  void _scheduleShow(bool hasSelection) {
    if (!_enabled) {
      _hideImmediate();
      return;
    }
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(milliseconds: _showDelayMs), () {
      _currentItems = _buildItems(hasSelection);
      _visible = true;
      _hiddenByViewportGesture = false;
      final overlayItems = List<SelectionMenuItem>.unmodifiable(_currentItems);
      _overlayUpdater?.call(overlayItems);
    });
  }

  void _hideImmediate() {
    _showTimer?.cancel();
    if (_visible) {
      _visible = false;
      _overlayUpdater?.call(null);
    }
  }

  void hide() => _hideImmediate();

  void dispose() {
    _showTimer?.cancel();
    _overlayUpdater = null;
  }
}
