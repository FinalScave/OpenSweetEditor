part of '../sweeteditor.dart';

const int _maxVisibleItems = 6;
const double _itemHeightVp = 32;
const double _popupWidthVp = 300;
const double _gapVp = 4;

/// Popup position for the completion panel.
class PopupPosition {
  const PopupPosition({
    required this.x,
    required this.belowY,
    required this.aboveY,
    required this.popupWidth,
    required this.popupHeight,
  });

  final double x;
  final double belowY;
  final double aboveY;
  final double popupWidth;
  final double popupHeight;
}

class CompletionPopupOverlayState {
  const CompletionPopupOverlayState({
    required this.items,
    required this.selectedIndex,
    required this.position,
  });

  final List<CompletionItem> items;
  final int selectedIndex;
  final PopupPosition position;
}

/// Completion popup controller (logic layer).
class CompletionPopupController {
  CompletionPopupController();

  List<CompletionItem> _items = [];
  int _selectedIndex = 0;
  bool _showing = false;
  void Function(CompletionItem)? _confirmHandler;
  CompletionItemWidgetBuilder? _itemBuilder;
  double _cachedCursorX = 0;
  double _cachedCursorY = 0;
  double _cachedCursorHeight = 0;
  EditorOverlayUpdater<CompletionPopupOverlayState>? _overlayUpdater;

  void setConfirmHandler(void Function(CompletionItem)? handler) {
    _confirmHandler = handler;
  }

  void setItemBuilder(CompletionItemWidgetBuilder? builder) {
    _itemBuilder = builder;
    if (_showing) {
      _overlayUpdater?.call(_buildOverlayState());
    }
  }

  void bindOverlay(EditorOverlayUpdater<CompletionPopupOverlayState>? updater) {
    _overlayUpdater = updater;
  }

  bool get isShowing => _showing;
  List<CompletionItem> get items => _items;
  int get selectedIndex => _selectedIndex;
  CompletionItemWidgetBuilder? get itemBuilder => _itemBuilder;

  void showItems(List<CompletionItem> newItems) {
    _items = List.of(newItems);
    _selectedIndex = 0;
    if (_items.isEmpty) {
      dismiss();
    } else {
      _show();
    }
  }

  bool handleKeyCode(int keyCode) {
    if (!_showing || _items.isEmpty) return false;
    switch (keyCode) {
      case 13: // Enter
        confirmSelected();
        return true;
      case 27: // Escape
        dismiss();
        return true;
      case 38: // Up
        _moveSelection(-1);
        return true;
      case 40: // Down
        _moveSelection(1);
        return true;
      default:
        return false;
    }
  }

  void updateCursorPosition(
    double cursorX,
    double cursorY,
    double cursorHeight,
  ) {
    _cachedCursorX = cursorX;
    _cachedCursorY = cursorY;
    _cachedCursorHeight = cursorHeight;
    if (_showing) {
      _overlayUpdater?.call(_buildOverlayState());
    }
  }

  void dismiss() {
    if (!_showing) return;
    _showing = false;
    _overlayUpdater?.call(null);
  }

  void confirmSelected() {
    if (_selectedIndex >= 0 && _selectedIndex < _items.length) {
      final item = _items[_selectedIndex];
      dismiss();
      _confirmHandler?.call(item);
    }
  }

  void confirmItem(int index) {
    if (index >= 0 && index < _items.length) {
      _selectedIndex = index;
      confirmSelected();
    }
  }

  void _show() {
    _showing = true;
    _overlayUpdater?.call(_buildOverlayState());
  }

  void _moveSelection(int delta) {
    if (_items.isEmpty) return;
    final old = _selectedIndex;
    _selectedIndex = (_selectedIndex + delta).clamp(0, _items.length - 1);
    if (old != _selectedIndex) {
      _overlayUpdater?.call(_buildOverlayState());
    }
  }

  CompletionPopupOverlayState _buildOverlayState() {
    return CompletionPopupOverlayState(
      items: List<CompletionItem>.unmodifiable(_items),
      selectedIndex: _selectedIndex,
      position: _computePosition(),
    );
  }

  PopupPosition _computePosition() {
    final popupHeight =
        _itemHeightVp * _items.length.clamp(0, _maxVisibleItems);
    final belowY = _cachedCursorY + _cachedCursorHeight + _gapVp;
    final aboveY = _cachedCursorY - popupHeight - _gapVp;
    return PopupPosition(
      x: _cachedCursorX,
      belowY: belowY,
      aboveY: aboveY,
      popupWidth: _popupWidthVp,
      popupHeight: popupHeight,
    );
  }
}
