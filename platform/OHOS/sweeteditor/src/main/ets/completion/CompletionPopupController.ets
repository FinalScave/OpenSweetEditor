import { CompletionItem, CompletionItemViewBuilder } from './CompletionTypes';
import { CompletionUpdateListener } from './CompletionProviderManager';

const MAX_VISIBLE_ITEMS = 6;
const ITEM_HEIGHT_VP = 32;
const POPUP_WIDTH_VP = 300;
const GAP_VP = 4;

/**
 * Completion popup controller (logic layer).
 * Manages items, selected index, keyboard navigation, and cursor-following positioning.
 * UI rendering is delegated to the host via callbacks, since OHOS does not have
 * a direct equivalent to Android PopupWindow + RecyclerView.
 */
export class CompletionPopupController implements CompletionUpdateListener {
  private items: CompletionItem[] = [];
  private selectedIndex: number = 0;
  private showing: boolean = false;
  private confirmHandler: ((item: CompletionItem) => void) | null = null;
  private viewBuilder: CompletionItemViewBuilder | null = null;
  private cachedCursorX: number = 0;
  private cachedCursorY: number = 0;
  private cachedCursorHeight: number = 0;
  private panelBgColor: number;
  private panelBorderColor: number;
  private selectedBgColor: number;
  private labelColor: number;
  private detailColor: number;
  private onShowCallback: ((items: CompletionItem[], selectedIndex: number, position: PopupPosition) => void) | null =
    null;
  private onUpdateCallback: ((items: CompletionItem[], selectedIndex: number, position: PopupPosition) => void) | null =
    null;
  private onDismissCallback: (() => void) | null = null;

  constructor(panelBgColor: number, panelBorderColor: number, selectedBgColor: number,
    labelColor: number, detailColor: number) {
    this.panelBgColor = panelBgColor;
    this.panelBorderColor = panelBorderColor;
    this.selectedBgColor = selectedBgColor;
    this.labelColor = labelColor;
    this.detailColor = detailColor;
  }

  applyTheme(panelBgColor: number, panelBorderColor: number, selectedBgColor: number,
    labelColor: number, detailColor: number): void {
    this.panelBgColor = panelBgColor;
    this.panelBorderColor = panelBorderColor;
    this.selectedBgColor = selectedBgColor;
    this.labelColor = labelColor;
    this.detailColor = detailColor;
  }

  setConfirmHandler(handler: ((item: CompletionItem) => void) | null): void {
    this.confirmHandler = handler;
  }

  setViewBuilder(builder: CompletionItemViewBuilder | null): void {
    this.viewBuilder = builder;
  }

  setOnShowCallback(cb: ((items: CompletionItem[], selectedIndex: number,
    position: PopupPosition) => void) | null): void {
    this.onShowCallback = cb;
  }

  setOnUpdateCallback(cb: ((items: CompletionItem[], selectedIndex: number,
    position: PopupPosition) => void) | null): void {
    this.onUpdateCallback = cb;
  }

  setOnDismissCallback(cb: (() => void) | null): void {
    this.onDismissCallback = cb;
  }

  isShowing(): boolean {
    return this.showing;
  }

  getItems(): CompletionItem[] {
    return this.items;
  }

  getSelectedIndex(): number {
    return this.selectedIndex;
  }

  getThemeColors(): CompletionThemeColors {
    return {
      panelBgColor: this.panelBgColor,
      panelBorderColor: this.panelBorderColor,
      selectedBgColor: this.selectedBgColor,
      labelColor: this.labelColor,
      detailColor: this.detailColor
    };
  }

  onCompletionItemsUpdated(newItems: CompletionItem[]): void {
    this.items = [...newItems];
    this.selectedIndex = 0;
    if (this.items.length === 0) {
      this.dismiss();
    } else {
      this.show();
    }
  }

  onCompletionDismissed(): void {
    this.dismiss();
  }

  /**
   * Handle key codes for navigation.
   * Returns true if consumed.
   */
  handleKeyCode(keyCode: number): boolean {
    if (!this.showing || this.items.length === 0) {
      return false;
    }
    switch (keyCode) {
      case 66: // Enter
        this.confirmSelected();
        return true;
      case 111: // Escape
        this.dismiss();
        return true;
      case 19: // Up
        this.moveSelection(-1);
        return true;
      case 20: // Down
        this.moveSelection(1);
        return true;
      default:
        return false;
    }
  }

  updateCursorPosition(cursorX: number, cursorY: number, cursorHeight: number): void {
    this.cachedCursorX = cursorX;
    this.cachedCursorY = cursorY;
    this.cachedCursorHeight = cursorHeight;
    if (this.showing && this.onUpdateCallback) {
      this.onUpdateCallback(this.items, this.selectedIndex, this.computePosition());
    }
  }

  dismiss(): void {
    if (!this.showing) {
      return;
    }
    this.showing = false;
    if (this.onDismissCallback) {
      this.onDismissCallback();
    }
  }

  private show(): void {
    this.showing = true;
    const position = this.computePosition();
    if (this.onShowCallback) {
      this.onShowCallback(this.items, this.selectedIndex, position);
    }
  }

  private moveSelection(delta: number): void {
    if (this.items.length === 0) {
      return;
    }
    const old = this.selectedIndex;
    this.selectedIndex = Math.max(0, Math.min(this.items.length - 1, this.selectedIndex + delta));
    if (old !== this.selectedIndex && this.onUpdateCallback) {
      this.onUpdateCallback(this.items, this.selectedIndex, this.computePosition());
    }
  }

  confirmSelected(): void {
    if (this.selectedIndex >= 0 && this.selectedIndex < this.items.length) {
      const item = this.items[this.selectedIndex];
      this.dismiss();
      if (this.confirmHandler) {
        this.confirmHandler(item);
      }
    }
  }

  confirmItem(index: number): void {
    if (index >= 0 && index < this.items.length) {
      this.selectedIndex = index;
      this.confirmSelected();
    }
  }

  private computePosition(): PopupPosition {
    const gap = GAP_VP;
    const popupHeight = ITEM_HEIGHT_VP * Math.min(this.items.length, MAX_VISIBLE_ITEMS);
    const belowY = this.cachedCursorY + this.cachedCursorHeight + gap;
    const aboveY = this.cachedCursorY - popupHeight - gap;

    return {
      x: this.cachedCursorX,
      belowY: belowY,
      aboveY: aboveY,
      popupWidth: POPUP_WIDTH_VP,
      popupHeight: popupHeight
    };
  }
}

export interface PopupPosition {
  x: number;
  belowY: number;
  aboveY: number;
  popupWidth: number;
  popupHeight: number;
}

export interface CompletionThemeColors {
  panelBgColor: number;
  panelBorderColor: number;
  selectedBgColor: number;
  labelColor: number;
  detailColor: number;
}

