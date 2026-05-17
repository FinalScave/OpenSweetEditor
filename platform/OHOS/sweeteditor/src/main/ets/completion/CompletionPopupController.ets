import { CompletionItem } from './CompletionTypes';
import { CompletionUpdateListener } from './CompletionProviderManager';
import { OverlayKeyAction } from '../EditorKeyboard';
import {
  COMPLETION_ITEM_HEIGHT,
  COMPLETION_MAX_VISIBLE_ITEMS,
  COMPLETION_PANEL_VERTICAL_PADDING,
  COMPLETION_POPUP_GAP,
  COMPLETION_POPUP_WIDTH
} from './CompletionPopupLayout';
import { popupRect, PopupRect } from '../ui/PopupPositioner';

/**
 * Completion popup controller (logic layer).
 * Manages items, selected index, keyboard navigation, and cursor-following positioning.
 * UI rendering is delegated to the host via callbacks.
 */
export class CompletionPopupController implements CompletionUpdateListener {
  private items: CompletionItem[] = [];
  private selectedIndex: number = 0;
  private showing: boolean = false;
  private confirmHandler: ((item: CompletionItem) => void) | null = null;
  private cachedCursorX: number = 0;
  private cachedCursorY: number = 0;
  private cachedCursorHeight: number = 0;
  private onShowCallback: ((items: CompletionItem[], selectedIndex: number, position: PopupPosition) => void) | null =
    null;
  private onUpdateCallback: ((items: CompletionItem[], selectedIndex: number, position: PopupPosition) => void) | null =
    null;
  private onDismissCallback: (() => void) | null = null;

  setConfirmHandler(handler: ((item: CompletionItem) => void) | null): void {
    this.confirmHandler = handler;
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

  handleKeyAction(action: OverlayKeyAction): boolean {
    if (!this.showing || this.items.length === 0) {
      return false;
    }
    switch (action) {
      case OverlayKeyAction.ENTER:
        this.confirmSelected();
        return true;
      case OverlayKeyAction.ESCAPE:
        this.dismiss();
        return true;
      case OverlayKeyAction.UP:
        this.moveSelection(-1);
        return true;
      case OverlayKeyAction.DOWN:
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
    const popupHeight = COMPLETION_ITEM_HEIGHT * Math.min(this.items.length, COMPLETION_MAX_VISIBLE_ITEMS) +
      COMPLETION_PANEL_VERTICAL_PADDING * 2;

    return {
      anchorRect: popupRect(this.cachedCursorX, this.cachedCursorY,
        this.cachedCursorX, this.cachedCursorY + this.cachedCursorHeight),
      popupWidth: COMPLETION_POPUP_WIDTH,
      popupHeight: popupHeight,
      gap: COMPLETION_POPUP_GAP
    };
  }
}

export interface PopupPosition {
  anchorRect: PopupRect;
  popupWidth: number;
  popupHeight: number;
  gap: number;
}

