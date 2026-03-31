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

/// Theme colors for the completion panel.
class CompletionThemeColors {
  const CompletionThemeColors({
    required this.panelBgColor,
    required this.panelBorderColor,
    required this.selectedBgColor,
    required this.labelColor,
    required this.detailColor,
  });

  final int panelBgColor;
  final int panelBorderColor;
  final int selectedBgColor;
  final int labelColor;
  final int detailColor;
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
class CompletionPopupController implements CompletionUpdateListener {
  CompletionPopupController({
    required int panelBgColor,
    required int panelBorderColor,
    required int selectedBgColor,
    required int labelColor,
    required int detailColor,
  }) : _panelBgColor = panelBgColor,
       _panelBorderColor = panelBorderColor,
       _selectedBgColor = selectedBgColor,
       _labelColor = labelColor,
       _detailColor = detailColor;

  List<CompletionItem> _items = [];
  int _selectedIndex = 0;
  bool _showing = false;
  void Function(CompletionItem)? _confirmHandler;
  double _cachedCursorX = 0;
  double _cachedCursorY = 0;
  double _cachedCursorHeight = 0;
  int _panelBgColor;
  int _panelBorderColor;
  int _selectedBgColor;
  int _labelColor;
  int _detailColor;
  EditorOverlayBinding<CompletionPopupOverlayState>? _overlayBinding;

  void applyTheme(
    int panelBgColor,
    int panelBorderColor,
    int selectedBgColor,
    int labelColor,
    int detailColor,
  ) {
    _panelBgColor = panelBgColor;
    _panelBorderColor = panelBorderColor;
    _selectedBgColor = selectedBgColor;
    _labelColor = labelColor;
    _detailColor = detailColor;
  }

  void setConfirmHandler(void Function(CompletionItem)? handler) {
    _confirmHandler = handler;
  }

  void setViewBuilder(CompletionItemViewBuilder? builder) {
    // Reserved for future custom rendering support.
  }

  void bindOverlay(EditorOverlayBinding<CompletionPopupOverlayState>? binding) {
    _overlayBinding = binding;
  }

  bool get isShowing => _showing;
  List<CompletionItem> get items => _items;
  int get selectedIndex => _selectedIndex;
  CompletionThemeColors get themeColors => CompletionThemeColors(
    panelBgColor: _panelBgColor,
    panelBorderColor: _panelBorderColor,
    selectedBgColor: _selectedBgColor,
    labelColor: _labelColor,
    detailColor: _detailColor,
  );

  @override
  void onCompletionItemsUpdated(List<CompletionItem> newItems) {
    _items = List.of(newItems);
    _selectedIndex = 0;
    if (_items.isEmpty) {
      dismiss();
    } else {
      _show();
    }
  }

  @override
  void onCompletionDismissed() => dismiss();

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
      _overlayBinding?.update(_buildOverlayState());
    }
  }

  void dismiss() {
    if (!_showing) return;
    _showing = false;
    _overlayBinding?.hide();
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
    final wasShowing = _showing;
    _showing = true;
    final overlayState = _buildOverlayState();
    if (wasShowing) {
      _overlayBinding?.update(overlayState);
    } else {
      _overlayBinding?.show(overlayState);
    }
  }

  void _moveSelection(int delta) {
    if (_items.isEmpty) return;
    final old = _selectedIndex;
    _selectedIndex = (_selectedIndex + delta).clamp(0, _items.length - 1);
    if (old != _selectedIndex) {
      _overlayBinding?.update(_buildOverlayState());
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
