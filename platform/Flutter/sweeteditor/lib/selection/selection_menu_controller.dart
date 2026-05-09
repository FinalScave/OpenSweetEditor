import 'dart:async';

import '../editor_core.dart' as core;
import '../widget/editor_overlay.dart';

import 'selection_types.dart';

class SelectionMenuOverlayState {
  const SelectionMenuOverlayState({required this.items});

  final List<SelectionMenuItem> items;
}

/// Controls the lifecycle of the selection context menu.
///
/// State machine:
///   HIDDEN --(double-tap/long-press + selection)--> VISIBLE
///   VISIBLE --(handle drag / scroll / scale / tap)--> HIDDEN
///   HIDDEN --(handle drag end + selection)--> VISIBLE
class SelectionMenuController {
  static const int _showDelayMs = 100;

  SelectionMenuController({bool enabled = true}) : _enabled = enabled;

  final bool _enabled;
  SelectionMenuItemProvider? _itemProvider;
  bool _handleDragActive = false;
  bool _hiddenByViewportGesture = false;
  bool _visible = false;
  Timer? _showTimer;
  List<SelectionMenuItem> _currentItems = [];
  SelectionMenuContext Function(bool hasSelection)? buildContext;
  EditorOverlayBinding<SelectionMenuOverlayState>? _overlayBinding;

  bool get isVisible => _visible;
  List<SelectionMenuItem> get currentItems => _currentItems;

  void setItemProvider(SelectionMenuItemProvider? provider) {
    _itemProvider = provider;
  }

  void bindOverlay(EditorOverlayBinding<SelectionMenuOverlayState>? binding) {
    _overlayBinding = binding;
  }

  void onGestureResult(core.GestureResult result, bool hasSelection) {
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

    switch (result.type) {
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
      final context =
          buildContext?.call(hasSelection) ??
          SelectionMenuContext(
            hasSelection: hasSelection,
            cursorPosition: const core.TextPosition(0, 0),
          );
      return _itemProvider!.provideMenuItems(context);
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
      final wasVisible = _visible;
      _visible = true;
      _hiddenByViewportGesture = false;
      final overlayState = SelectionMenuOverlayState(
        items: List<SelectionMenuItem>.unmodifiable(_currentItems),
      );
      if (wasVisible) {
        _overlayBinding?.update(overlayState);
      } else {
        _overlayBinding?.show(overlayState);
      }
    });
  }

  void _hideImmediate() {
    _showTimer?.cancel();
    if (_visible) {
      _visible = false;
      _overlayBinding?.hide();
    }
  }

  void hide() => _hideImmediate();

  void dispose() {
    _showTimer?.cancel();
    _overlayBinding = null;
  }
}
