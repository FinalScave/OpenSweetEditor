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
    required this.theme,
    this.itemBuilder,
    required this.viewportSize,
    required this.onItemTap,
  });

  final List<CompletionItem> items;
  final int selectedIndex;
  final PopupPosition position;
  final EditorTheme theme;
  final CompletionItemWidgetBuilder? itemBuilder;
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
          color: Color(theme.completionBgColor),
          border: Border.all(
            color: Color(theme.completionBorderColor),
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
            final customItemBuilder = itemBuilder;
            return GestureDetector(
              onTap: () => onItemTap(index),
              child: Container(
                color: isSelected
                    ? Color(theme.completionSelectedBgColor)
                    : null,
                child: customItemBuilder == null
                    ? _DefaultCompletionItem(item: item, theme: theme)
                    : customItemBuilder(context, item, index, isSelected),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DefaultCompletionItem extends StatelessWidget {
  const _DefaultCompletionItem({required this.item, required this.theme});

  final CompletionItem item;
  final EditorTheme theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
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
                  color: Color(theme.completionLabelColor),
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.detail != null && item.detail!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  item.detail!,
                  style: TextStyle(
                    color: Color(theme.completionDetailColor),
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
    switch (kind) {
      case CompletionItem.kindKeyword:
        return 'K';
      case CompletionItem.kindFunction:
        return 'F';
      case CompletionItem.kindVariable:
        return 'V';
      case CompletionItem.kindClass:
        return 'C';
      case CompletionItem.kindInterface:
        return 'I';
      case CompletionItem.kindModule:
        return 'M';
      case CompletionItem.kindProperty:
        return 'P';
      case CompletionItem.kindSnippet:
        return 'S';
      case CompletionItem.kindText:
        return 'T';
      default:
        return '?';
    }
  }

  static Color _kindColor(int kind) {
    switch (kind) {
      case CompletionItem.kindFunction:
        return const Color(0xFF73DACA);
      case CompletionItem.kindVariable:
      case CompletionItem.kindProperty:
        return const Color(0xFF7AA2F7);
      case CompletionItem.kindClass:
      case CompletionItem.kindInterface:
        return const Color(0xFFBB9AF7);
      case CompletionItem.kindModule:
        return const Color(0xFFE0AF68);
      case CompletionItem.kindKeyword:
        return const Color(0xFFF7768E);
      case CompletionItem.kindSnippet:
        return const Color(0xFF9ECE6A);
      default:
        return const Color(0xFF8FA3BF);
    }
  }
}
