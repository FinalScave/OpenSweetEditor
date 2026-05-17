import { argbToCssColor } from '../ui/EditorColor';

export const INLINE_SUGGESTION_BAR_HEIGHT = 28;
export const INLINE_SUGGESTION_BAR_RADIUS = 6;
export const INLINE_SUGGESTION_BAR_HORIZONTAL_PADDING = 4;
export const INLINE_SUGGESTION_BAR_BUTTON_HORIZONTAL_PADDING = 10;
export const INLINE_SUGGESTION_BAR_DIVIDER_WIDTH = 1;
export const INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN = 6;
export const INLINE_SUGGESTION_BAR_GAP = 2;
export const INLINE_SUGGESTION_BAR_SIDE_MARGIN = 8;
export const INLINE_SUGGESTION_BAR_ESTIMATED_WIDTH = 132;

@Component
export struct InlineSuggestionBarView {
  @Prop left: number = 0;
  @Prop top: number = 0;
  @Prop bgColor: number = 0;
  @Prop acceptColor: number = 0;
  @Prop dismissColor: number = 0;
  onAccept: () => void = (): void => {};
  onDismiss: () => void = (): void => {};

  build() {
    Row() {
      this.buildInlineSuggestionBarButton('Accept', true)

      Blank()
        .width(INLINE_SUGGESTION_BAR_DIVIDER_WIDTH)
        .height(INLINE_SUGGESTION_BAR_HEIGHT - INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN * 2)
        .backgroundColor(getInlineSuggestionOverlayColor(this.bgColor))
        .margin({ top: INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN, bottom: INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN })

      this.buildInlineSuggestionBarButton('Dismiss', false)
    }
    .height(INLINE_SUGGESTION_BAR_HEIGHT)
    .padding({ left: INLINE_SUGGESTION_BAR_HORIZONTAL_PADDING, right: INLINE_SUGGESTION_BAR_HORIZONTAL_PADDING })
    .backgroundColor(argbToCssColor(this.bgColor))
    .borderRadius(INLINE_SUGGESTION_BAR_RADIUS)
    .shadow({
      radius: 8,
      color: '#22000000',
      offsetX: 0,
      offsetY: 2
    })
    .position({
      x: this.left,
      y: this.top
    })
    .zIndex(8)
  }

  @Builder
  private buildInlineSuggestionBarButton(label: string, isAccept: boolean): void {
    Text(label)
      .fontSize(11)
      .fontWeight(isAccept ? '700' : '400')
      .fontColor(isAccept ? argbToCssColor(this.acceptColor) : argbToCssColor(this.dismissColor))
      .height('100%')
      .textAlign(TextAlign.Center)
      .padding({ left: INLINE_SUGGESTION_BAR_BUTTON_HORIZONTAL_PADDING, right: INLINE_SUGGESTION_BAR_BUTTON_HORIZONTAL_PADDING })
      .onClick(() => {
        if (isAccept) {
          this.onAccept();
        } else {
          this.onDismiss();
        }
      })
  }
}

function getInlineSuggestionOverlayColor(bgColor: number): string {
  const r = (bgColor >>> 16) & 0xFF;
  const g = (bgColor >>> 8) & 0xFF;
  const b = bgColor & 0xFF;
  const luminance = 0.299 * r + 0.587 * g + 0.114 * b;
  return luminance > 128 ? 'rgba(0, 0, 0, 0.133)' : 'rgba(255, 255, 255, 0.133)';
}
