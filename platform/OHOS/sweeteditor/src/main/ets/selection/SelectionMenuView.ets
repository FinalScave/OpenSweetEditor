import { argbToCssColor } from '../ui/EditorColor';
import { SelectionMenuItem } from './SelectionMenuTypes';

export const SELECTION_MENU_ITEM_HEIGHT = 26;
export const SELECTION_MENU_ITEM_MIN_WIDTH = 40;
export const SELECTION_MENU_HORIZONTAL_PADDING = 8;
export const SELECTION_MENU_PANEL_PADDING = 4;
export const SELECTION_MENU_SIDE_MARGIN = 8;
export const SELECTION_MENU_TOP_MARGIN = 8;

@Component
export struct SelectionMenuView {
  @Prop items: SelectionMenuItem[] = [];
  @Prop left: number = 0;
  @Prop top: number = 0;
  @Prop bgColor: number = 0;
  @Prop menuBorderColor: number = 0;
  @Prop dividerColor: number = 0;
  @Prop textColor: number = 0;
  onItemClick: (item: SelectionMenuItem) => void = (_item: SelectionMenuItem): void => {};

  build() {
    Row() {
      ForEach(this.items, (item: SelectionMenuItem, index: number) => {
        this.buildSelectionMenuItem(item)
        if (index < this.items.length - 1) {
          Blank()
            .width(1)
            .height(14)
            .backgroundColor(argbToCssColor(this.dividerColor))
        }
      }, (item: SelectionMenuItem) => `${item.id}-${item.label}`)
    }
    .padding(SELECTION_MENU_PANEL_PADDING)
    .backgroundColor(argbToCssColor(this.bgColor))
    .borderRadius(6)
    .border({
      width: 1,
      color: argbToCssColor(this.menuBorderColor)
    })
    .position({
      x: this.left,
      y: this.top
    })
    .zIndex(10)
  }

  @Builder
  private buildSelectionMenuItem(item: SelectionMenuItem): void {
    Text(item.label)
      .fontSize(11)
      .fontWeight('400')
      .fontColor(argbToCssColor(this.textColor))
      .textAlign(TextAlign.Center)
      .padding({ left: SELECTION_MENU_HORIZONTAL_PADDING, right: SELECTION_MENU_HORIZONTAL_PADDING })
      .width(getSelectionMenuItemWidth(item))
      .height(SELECTION_MENU_ITEM_HEIGHT)
      .opacity(item.enabled ? 1.0 : 0.45)
      .onClick(() => {
        if (!item.enabled) {
          return;
        }
        this.onItemClick(item);
      })
  }
}

export function getSelectionMenuPanelWidth(items: SelectionMenuItem[]): number {
  let width = SELECTION_MENU_PANEL_PADDING * 2;
  for (let i = 0; i < items.length; i++) {
    width += getSelectionMenuItemWidth(items[i]);
    if (i < items.length - 1) {
      width += 1;
    }
  }
  return width;
}

export function getSelectionMenuPanelHeight(): number {
  return SELECTION_MENU_ITEM_HEIGHT + SELECTION_MENU_PANEL_PADDING * 2;
}

export function getSelectionMenuItemWidth(item: SelectionMenuItem): number {
  return Math.max(
    SELECTION_MENU_ITEM_MIN_WIDTH,
    item.label.length * 9 + SELECTION_MENU_HORIZONTAL_PADDING * 2
  );
}
