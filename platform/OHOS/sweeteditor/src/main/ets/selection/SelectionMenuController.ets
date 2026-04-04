import { SelectionMenuItem, SelectionMenuItemProvider, SelectionMenuState } from './SelectionMenuTypes';
import { EditorEventBus } from '../event/EditorEventBus';
import { SelectionMenuItemClickEvent } from '../event/EditorEvent';
import { GestureResult, GestureType } from '../core/EditorCore';
import { PointF } from '../core/CoreVisual';
import { SweetEditor } from '../SweetEditor';

const SHOW_DELAY_MS = 100;

/**
 * Selection handle position data.
 */
export interface SelectionHandleInfo {
  visible: boolean;
  x: number;
  y: number;
  height: number;
}

/**
 * Controls the lifecycle of the selection context menu.
 * State machine: HIDDEN �?VISIBLE (on double-tap + selection) �?HIDDEN (on tap/scroll/scale).
 */
export class SelectionMenuController {
  private editor: SweetEditor;
  private eventBus: EditorEventBus;
  private itemProvider: SelectionMenuItemProvider | null = null;
  private startHandle: SelectionHandleInfo | null = null;
  private endHandle: SelectionHandleInfo | null = null;
  private handleDragActive: boolean = false;
  private selectionInteractionActive: boolean = false;
  private hiddenByViewportGesture: boolean = false;
  private pendingShow: boolean = false;
  private showing: boolean = false;
  private showTimerId: number = -1;
  private stateListener: ((state: SelectionMenuState) => void) | null = null;
  private state: SelectionMenuState = { visible: false, items: [], x: 0, y: 0 };

  constructor(editor: SweetEditor, eventBus: EditorEventBus) {
    this.editor = editor;
    this.eventBus = eventBus;
  }

  setItemProvider(provider: SelectionMenuItemProvider | null): void {
    this.itemProvider = provider;
    if (this.showing) {
      this.updateVisibleState(this.buildItems());
    }
  }

  setStateListener(listener: ((state: SelectionMenuState) => void) | null): void {
    this.stateListener = listener;
    this.emitState();
  }

  getState(): SelectionMenuState {
    return {
      visible: this.state.visible,
      items: [...this.state.items],
      x: this.state.x,
      y: this.state.y
    };
  }

  updateSelectionHandles(start: SelectionHandleInfo | null, end: SelectionHandleInfo | null): void {
    this.startHandle = start;
    this.endHandle = end;
    if (this.showing) {
      this.updateVisibleState(this.state.items);
    }
  }

  clearSelectionHandles(): void {
    this.startHandle = null;
    this.endHandle = null;
  }

  isShowing(): boolean {
    return this.showing;
  }

  onGestureResult(result: GestureResult, isPointerReleased: boolean): void {
    let shouldShowAfterRelease = false;

    if (result.isHandleDrag) {
      this.selectionInteractionActive = true;
      if (!this.handleDragActive) {
        this.handleDragActive = true;
        this.hideImmediate();
      }
      return;
    }

    if (this.handleDragActive) {
      this.handleDragActive = false;
      if (result.hasSelection) {
        shouldShowAfterRelease = true;
      }
    }

    switch (result.type) {
      case GestureType.DOUBLE_TAP:
        this.hiddenByViewportGesture = false;
        if (result.hasSelection) {
          this.scheduleShow();
        }
        break;
      case GestureType.TAP:
        this.hiddenByViewportGesture = false;
        this.hideImmediate();
        break;
      case GestureType.SCROLL:
      case GestureType.FAST_SCROLL:
      case GestureType.SCALE:
        this.hiddenByViewportGesture = true;
        this.hideImmediate();
        break;
      case GestureType.DRAG_SELECT:
        this.selectionInteractionActive = true;
        this.hideImmediate();
        break;
    }

    const animationTickEnded = !result.needsAnimation;
    const canRestoreNow = (isPointerReleased && !result.needsAnimation) || animationTickEnded;
    if (this.hiddenByViewportGesture && canRestoreNow) {
      this.hiddenByViewportGesture = false;
      if (result.hasSelection) {
        this.scheduleShow();
      }
    }

    if (isPointerReleased) {
      const shouldShowFromSelectionInteraction = this.selectionInteractionActive &&
        result.hasSelection &&
        !this.hiddenByViewportGesture &&
        !result.needsAnimation;
      this.selectionInteractionActive = false;
      if (shouldShowAfterRelease || shouldShowFromSelectionInteraction) {
        this.scheduleShow();
      }
    }
  }

  onSelectAll(): void {
    this.scheduleShow();
  }

  onTextChanged(): void {
    this.clearSelectionHandles();
    this.hide();
  }

  dismiss(): void {
    this.cancelPendingShow();
    this.showing = false;
    this.selectionInteractionActive = false;
    this.updateHiddenState();
  }

  onMenuItemClicked(item: SelectionMenuItem): void {
    switch (item.id) {
      case SelectionMenuItem.ACTION_CUT:
        this.editor.cutToClipboard();
        this.hide();
        break;
      case SelectionMenuItem.ACTION_COPY:
        this.editor.copyToClipboard();
        this.hide();
        break;
      case SelectionMenuItem.ACTION_PASTE:
        this.editor.pasteFromClipboard();
        this.hide();
        break;
      case SelectionMenuItem.ACTION_SELECT_ALL:
        this.editor.selectAll();
        break;
      default:
        this.eventBus.emit('selectionMenuItemClick', new SelectionMenuItemClickEvent(item));
        this.hide();
        break;
    }
  }

  private scheduleShow(): void {
    this.cancelPendingShow();
    this.pendingShow = true;
    this.showTimerId = setTimeout(() => {
      this.showTimerId = -1;
      this.doShow();
    }, SHOW_DELAY_MS);
  }

  private cancelPendingShow(): void {
    this.pendingShow = false;
    if (this.showTimerId >= 0) {
      clearTimeout(this.showTimerId);
      this.showTimerId = -1;
    }
  }

  private hide(): void {
    this.cancelPendingShow();
    if (this.showing) {
      this.showing = false;
      this.updateHiddenState();
    }
  }

  private hideImmediate(): void {
    this.cancelPendingShow();
    if (this.showing) {
      this.showing = false;
      this.updateHiddenState();
    }
  }

  private doShow(): void {
    if (!this.pendingShow) {
      return;
    }
    this.pendingShow = false;
    if (!this.editor.hasSelection()) {
      return;
    }

    const items = this.buildItems();
    if (items.length === 0) {
      return;
    }

    const pos = this.computeMenuPosition();
    this.showing = true;
    this.state = {
      visible: true,
      items: [...items],
      x: pos.x,
      y: pos.y
    };
    this.emitState();
  }

  private buildItems(): SelectionMenuItem[] {
    if (this.itemProvider) {
      return this.itemProvider.provideMenuItems() || [];
    }
    return this.buildDefaultMenuItems();
  }

  private buildDefaultMenuItems(): SelectionMenuItem[] {
    const hasSelection = this.editor.hasSelection();
    return [
      new SelectionMenuItem(SelectionMenuItem.ACTION_CUT, 'Cut', hasSelection),
      new SelectionMenuItem(SelectionMenuItem.ACTION_COPY, 'Copy', hasSelection),
      new SelectionMenuItem(SelectionMenuItem.ACTION_PASTE, 'Paste'),
      new SelectionMenuItem(SelectionMenuItem.ACTION_SELECT_ALL, 'Select All')
    ];
  }

  private computeMenuPosition(): PointF {
    let anchorX: number;
    let topY: number;
    let bottomY: number;

    if (this.startHandle && this.startHandle.visible) {
      const startX = this.startHandle.x;
      const startY = this.startHandle.y;
      const startBottom = startY + this.startHandle.height;

      let endX = startX;
      let endBottom = startBottom;
      let endY = startY;
      if (this.endHandle && this.endHandle.visible) {
        endX = this.endHandle.x;
        endY = this.endHandle.y;
        endBottom = endY + this.endHandle.height;
      }

      anchorX = (startX + endX) * 0.5;
      topY = Math.min(startY, endY);
      bottomY = Math.max(startBottom, endBottom);
    } else {
      anchorX = this.editor.getViewWidth() * 0.5;
      topY = 0;
      bottomY = 0;
    }

    const menuHeight = 36;
    const offsetY = 8;
    const handleClearance = 32;

    let screenY = topY - menuHeight - offsetY;
    if (screenY < 0) {
      screenY = bottomY + offsetY + handleClearance;
    }

    return { x: anchorX, y: screenY };
  }

  private updateVisibleState(items: SelectionMenuItem[]): void {
    if (!this.showing) {
      return;
    }
    const pos = this.computeMenuPosition();
    this.state = {
      visible: true,
      items: [...items],
      x: pos.x,
      y: pos.y
    };
    this.emitState();
  }

  private updateHiddenState(): void {
    this.state = {
      visible: false,
      items: [],
      x: this.state.x,
      y: this.state.y
    };
    this.emitState();
  }

  private emitState(): void {
    if (!this.stateListener) {
      return;
    }
    this.stateListener({
      visible: this.state.visible,
      items: [...this.state.items],
      x: this.state.x,
      y: this.state.y
    });
  }
}

