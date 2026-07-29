import 'dart:async';

import '../core/editor_core.dart' as core;
import '../widget/editor_overlay.dart';

import 'selection_types.dart';

enum _SelectionMenuLifecycleState { hidden, pendingShow, visible, suspended }

/// Controls the lifecycle of the selection context menu.
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
  _SelectionMenuLifecycleState _state = _SelectionMenuLifecycleState.hidden;
  bool _hasSelection = false;
  bool _coreBlocked = false;
  Timer? _showTimer;
  EditorOverlayUpdater<List<SelectionMenuItem>>? _overlayUpdater;

  void setItemProvider(SelectionMenuItemProvider? provider) {
    _itemProvider = provider;
  }

  void bindOverlay(EditorOverlayUpdater<List<SelectionMenuItem>>? updater) {
    _overlayUpdater = updater;
  }

  void onEditorActionResult(core.EditorActionResult result) {
    if (!_enabled) {
      hide();
      return;
    }

    _hasSelection = result.hasSelectionAfter;
    _coreBlocked = result.hasActiveInteraction || result.needsViewportMotion;

    if (result.textChanges.isNotEmpty || !_hasSelection) {
      hide();
      return;
    }

    final wantsShow = result.selectionChanged;
    if (_coreBlocked) {
      if (wantsShow || _state != _SelectionMenuLifecycleState.hidden) {
        _suspend();
      }
      return;
    }

    if (wantsShow || _state == _SelectionMenuLifecycleState.suspended) {
      _scheduleShow();
    }
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

  void _scheduleShow() {
    if (!_enabled || !_hasSelection) {
      hide();
      return;
    }
    if (_coreBlocked) {
      _suspend();
      return;
    }
    _showTimer?.cancel();
    if (_state == _SelectionMenuLifecycleState.visible) {
      _overlayUpdater?.call(null);
    }
    _state = _SelectionMenuLifecycleState.pendingShow;
    _showTimer = Timer(const Duration(milliseconds: _showDelayMs), () {
      if (_state != _SelectionMenuLifecycleState.pendingShow) return;
      if (!_hasSelection) {
        hide();
        return;
      }
      if (_coreBlocked) {
        _suspend();
        return;
      }
      final items = _buildItems(_hasSelection);
      if (items.isEmpty) {
        hide();
        return;
      }
      _state = _SelectionMenuLifecycleState.visible;
      final overlayItems = List<SelectionMenuItem>.unmodifiable(items);
      _overlayUpdater?.call(overlayItems);
    });
  }

  void _suspend() {
    _showTimer?.cancel();
    if (_state == _SelectionMenuLifecycleState.visible) {
      _overlayUpdater?.call(null);
    }
    _state = _SelectionMenuLifecycleState.suspended;
  }

  void hide() {
    _showTimer?.cancel();
    if (_state == _SelectionMenuLifecycleState.visible) {
      _overlayUpdater?.call(null);
    }
    _state = _SelectionMenuLifecycleState.hidden;
  }

  void dispose() {
    _showTimer?.cancel();
    _overlayUpdater = null;
  }
}
