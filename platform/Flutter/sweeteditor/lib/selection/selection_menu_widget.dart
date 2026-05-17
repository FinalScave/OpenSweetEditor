import 'package:flutter/material.dart';

import '../editor_types.dart';
import 'selection_types.dart';

const double _kSelectionMenuHeight = 36;
const double _kSelectionMenuHorizontalInset = 4;
const double _kSelectionMenuItemHorizontalPadding = 12;
const double _kSelectionMenuFontSize = 12;
const double _kSelectionMenuDividerWidth = 1;
const double _kSelectionMenuDividerHeight = 20;

/// Floating selection menu rendered from a list of [SelectionMenuItem]s.
class SelectionMenuWidget extends StatelessWidget {
  const SelectionMenuWidget({
    super.key,
    required this.position,
    required this.items,
    required this.onItemTap,
    required this.theme,
  });

  final Offset position;
  final List<SelectionMenuItem> items;
  final void Function(SelectionMenuItem item) onItemTap;
  final EditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Color(theme.selectionMenuBgColor),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: _kSelectionMenuHorizontalInset,
          ),
          height: _kSelectionMenuHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) _divider(),
                _button(items[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(SelectionMenuItem item) {
    return GestureDetector(
      onTap: item.enabled ? () => onItemTap(item) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kSelectionMenuItemHorizontalPadding,
        ),
        child: Center(
          child: Text(
            item.label,
            style: TextStyle(
              color: _itemTextColor(item),
              fontSize: _kSelectionMenuFontSize,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: _kSelectionMenuDividerWidth,
      height: _kSelectionMenuDividerHeight,
      color: Color(theme.selectionMenuDividerColor),
    );
  }

  Color _itemTextColor(SelectionMenuItem item) {
    final color = Color(theme.selectionMenuTextColor);
    return item.enabled ? color : color.withValues(alpha: 0.31);
  }
}
