import { argbToCssColor } from '../ui/EditorColor';
import { EditorTheme } from '../EditorTypes';
import { CompletionItem, CompletionItemViewBuilder } from './CompletionTypes';
import {
  COMPLETION_ITEM_HEIGHT,
  COMPLETION_PANEL_VERTICAL_PADDING,
  COMPLETION_POPUP_WIDTH
} from './CompletionPopupLayout';

const COMPLETION_KIND_BADGE_SIZE = 18;
const COMPLETION_KIND_BADGE_RADIUS = 4;
const COMPLETION_KIND_BADGE_GAP = 8;

@Builder
function emptyCompletionItemViewBuilder(_item: CompletionItem, _isSelected: boolean, _theme: EditorTheme): void {}

@Component
export struct CompletionPopupView {
  @Prop items: CompletionItem[] = [];
  @Prop selectedIndex: number = 0;
  @Prop left: number = 0;
  @Prop top: number = 0;
  @Prop panelWidth: number = COMPLETION_POPUP_WIDTH;
  @Prop hasCustomItemViewBuilder: boolean = false;
  theme: EditorTheme = EditorTheme.dark();
  @BuilderParam itemViewBuilder: CompletionItemViewBuilder = emptyCompletionItemViewBuilder;
  onConfirmItem: (index: number) => void = (_index: number): void => {};

  build() {
    Column() {
      ForEach(this.items, (item: CompletionItem, index: number) => {
        this.buildCompletionPopupItem(item, index)
      }, (item: CompletionItem, index: number) => `${item.label}-${index}`)
    }
    .padding({ left: 4, right: 4, top: COMPLETION_PANEL_VERTICAL_PADDING, bottom: COMPLETION_PANEL_VERTICAL_PADDING })
    .width(this.panelWidth)
    .backgroundColor(argbToCssColor(this.theme.completionBgColor))
    .borderRadius(12)
    .border({
      width: 1,
      color: argbToCssColor(this.theme.completionBorderColor)
    })
    .shadow({
      radius: 16,
      color: '#32000000',
      offsetX: 0,
      offsetY: 4
    })
    .position({
      x: this.left,
      y: this.top
    })
    .zIndex(9)
  }

  @Builder
  private buildCompletionPopupItem(item: CompletionItem, index: number): void {
    if (this.hasCustomItemViewBuilder) {
      Row() {
        this.itemViewBuilder(item, index === this.selectedIndex, this.theme)
      }
      .width('100%')
      .height(COMPLETION_ITEM_HEIGHT)
      .onClick(() => {
        this.onConfirmItem(index);
      })
    } else {
      this.buildDefaultCompletionPopupItem(item, index)
    }
  }

  @Builder
  private buildDefaultCompletionPopupItem(item: CompletionItem, index: number): void {
    Row() {
      Text(this.getCompletionKindBadgeText(item.kind))
        .width(COMPLETION_KIND_BADGE_SIZE)
        .height(COMPLETION_KIND_BADGE_SIZE)
        .textAlign(TextAlign.Center)
        .fontSize(10)
        .fontWeight('700')
        .fontColor('#FFFFFFFF')
        .backgroundColor(this.getCompletionKindBadgeColor(item.kind))
        .borderRadius(COMPLETION_KIND_BADGE_RADIUS)
        .margin({ right: COMPLETION_KIND_BADGE_GAP })

      Text(item.label)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontSize(13)
        .fontWeight('400')
        .fontColor(argbToCssColor(this.theme.completionLabelColor))

      if (item.detail !== null && item.detail.length > 0) {
        Text(item.detail)
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(11)
          .fontColor(argbToCssColor(this.theme.completionDetailColor))
      }
    }
    .width('100%')
    .height(COMPLETION_ITEM_HEIGHT)
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .backgroundColor(index === this.selectedIndex
      ? argbToCssColor(this.theme.completionSelectedBgColor)
      : '#00000000')
    .borderRadius(6)
    .onClick(() => {
      this.onConfirmItem(index);
    })
  }

  private getCompletionKindBadgeText(kind: number): string {
    switch (kind) {
      case CompletionItem.KIND_KEYWORD:
        return 'K';
      case CompletionItem.KIND_FUNCTION:
        return 'F';
      case CompletionItem.KIND_VARIABLE:
        return 'V';
      case CompletionItem.KIND_CLASS:
        return 'C';
      case CompletionItem.KIND_INTERFACE:
        return 'I';
      case CompletionItem.KIND_MODULE:
        return 'M';
      case CompletionItem.KIND_PROPERTY:
        return 'P';
      case CompletionItem.KIND_SNIPPET:
        return 'S';
      default:
        return 'T';
    }
  }

  private getCompletionKindBadgeColor(kind: number): string {
    switch (kind) {
      case CompletionItem.KIND_KEYWORD:
        return '#FFC678DD';
      case CompletionItem.KIND_FUNCTION:
        return '#FF61AFEF';
      case CompletionItem.KIND_VARIABLE:
        return '#FFE5C07B';
      case CompletionItem.KIND_CLASS:
        return '#FFE06C75';
      case CompletionItem.KIND_INTERFACE:
        return '#FF56B6C2';
      case CompletionItem.KIND_MODULE:
        return '#FFD19A66';
      case CompletionItem.KIND_PROPERTY:
        return '#FF98C379';
      case CompletionItem.KIND_SNIPPET:
        return '#FFBE5046';
      default:
        return '#FF7A8494';
    }
  }
}
