part of '../sweeteditor.dart';

const double _kCompletionItemHeight = 32;
const int _kCompletionMaxVisible = 6;
const double _kCompletionPopupWidth = 300;
const double _kCompletionSideMargin = 8;
const double _kCompletionTopMargin = 4;

/// Positioned completion popup overlay.
class CompletionPopupWidget extends StatelessWidget {
  const CompletionPopupWidget({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.position,
    required this.themeColors,
    required this.viewportSize,
    required this.onItemTap,
  });

  final List<CompletionItem> items;
  final int selectedIndex;
  final PopupPosition position;
  final CompletionThemeColors themeColors;
  final Size viewportSize;
  final void Function(int index) onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final popupWidth = math.min(
      _kCompletionPopupWidth,
      math.max(220.0, viewportSize.width - _kCompletionSideMargin * 2),
    );
    final visibleCount = math.min(items.length, _kCompletionMaxVisible);
    final popupHeight = visibleCount * _kCompletionItemHeight;

    final preferBelow =
        position.belowY + popupHeight <=
        viewportSize.height - _kCompletionTopMargin;
    final top = preferBelow
        ? position.belowY.clamp(
            _kCompletionTopMargin,
            viewportSize.height - popupHeight - _kCompletionTopMargin,
          )
        : position.aboveY.clamp(
            _kCompletionTopMargin,
            viewportSize.height - popupHeight - _kCompletionTopMargin,
          );
    final left = position.x.clamp(
      _kCompletionSideMargin,
      viewportSize.width - popupWidth - _kCompletionSideMargin,
    );

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: popupWidth,
        height: popupHeight,
        decoration: BoxDecoration(
          color: Color(themeColors.panelBgColor),
          border: Border.all(
            color: Color(themeColors.panelBorderColor),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemExtent: _kCompletionItemHeight,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onItemTap(index),
              child: Container(
                color: isSelected ? Color(themeColors.selectedBgColor) : null,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (item.kind != CompletionItem.kindText) ...[
                      _CompletionKindBadge(kind: item.kind),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: Color(themeColors.labelColor),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.detail != null && item.detail!.isNotEmpty) ...[
                      // detail is nullable
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          item.detail!,
                          style: TextStyle(
                            color: Color(themeColors.detailColor),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompletionKindBadge extends StatelessWidget {
  const _CompletionKindBadge({required this.kind});

  final int kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _kindColor(kind).withAlpha(40),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        _kindLabel(kind),
        style: TextStyle(
          color: _kindColor(kind),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _kindLabel(int kind) {
    // Common CompletionItemKind values
    switch (kind) {
      case 1:
        return 'T'; // Text
      case 2:
        return 'M'; // Method
      case 3:
        return 'F'; // Function
      case 4:
        return 'C'; // Constructor
      case 5:
        return 'F'; // Field
      case 6:
        return 'V'; // Variable
      case 7:
        return 'C'; // Class
      case 8:
        return 'I'; // Interface
      case 9:
        return 'M'; // Module
      case 10:
        return 'P'; // Property
      case 14:
        return 'K'; // Keyword
      case 15:
        return 'S'; // Snippet
      default:
        return '?';
    }
  }

  static Color _kindColor(int kind) {
    switch (kind) {
      case 2:
      case 3:
        return const Color(0xFF73DACA); // Method/Function
      case 4:
        return const Color(0xFFE0AF68); // Constructor
      case 5:
      case 6:
      case 10:
        return const Color(0xFF7AA2F7); // Field/Variable/Property
      case 7:
      case 8:
        return const Color(0xFFBB9AF7); // Class/Interface
      case 14:
        return const Color(0xFFF7768E); // Keyword
      case 15:
        return const Color(0xFF9ECE6A); // Snippet
      default:
        return const Color(0xFF8FA3BF);
    }
  }
}
