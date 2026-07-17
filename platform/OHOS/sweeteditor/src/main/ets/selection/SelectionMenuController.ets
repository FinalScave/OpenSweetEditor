import {
  SelectionMenuItem,
  SelectionMenuItemProvider,
  SelectionMenuState
} from './SelectionMenuTypes';
import { EditorEventBus } from '../event/EditorEventBus';
import { SelectionMenuItemClickEvent } from '../event/EditorEvent';
import {
  EditorActionResult,
  hasActiveInteraction,
  needsViewportMotion
} from '../core/CoreAction';
import { SweetEditorController } from '../SweetEditorController';
import { SweetEditor } from '../SweetEditor';
import { popupRect, PopupRect } from '../ui/PopupPositioner';

const SHOW_DELAY_MS = 100;

enum SelectionMenuLifecycleState {
  HIDDEN,
  PENDING_SHOW,
  VISIBLE,
  SUSPENDED
}

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
 */
export class SelectionMenuController {
  private editor: SweetEditor;
  private controller: SweetEditorController;
  private eventBus: EditorEventBus;
  private itemProvider: SelectionMenuItemProvider | null = null;
  private startHandle: SelectionHandleInfo | null = null;
  private endHandle: SelectionHandleInfo | null = null;
  private lifecycleState: SelectionMenuLifecycleState = SelectionMenuLifecycleState.HIDDEN;
  private hasSelection: boolean = false;
  private coreBlocked: boolean = false;
  private showTimerId: number = -1;
  private stateListener: ((state: SelectionMenuState) => void) | null = null;
  private state: SelectionMenuState = { visible: false, items: [], anchorRect: popupRect(0, 0, 0, 0) };

  constructor(editor: SweetEditor, controller: SweetEditorController, eventBus: EditorEventBus) {
    this.editor = editor;
    this.controller = controller;
    this.eventBus = eventBus;
  }

  setItemProvider(provider: SelectionMenuItemProvider | null): void {
    this.itemProvider = provider;
  }

  setStateListener(listener: ((state: SelectionMenuState) => void) | null): void {
    this.stateListener = listener;
    this.emitState();
  }

  updateSelectionHandles(start: SelectionHandleInfo | null, end: SelectionHandleInfo | null): void {
    this.startHandle = start;
    this.endHandle = end;
    if (this.lifecycleState === SelectionMenuLifecycleState.VISIBLE) {
      this.updateVisibleState(this.state.items);
    }
  }

  private clearSelectionHandles(): void {
    this.startHandle = null;
    this.endHandle = null;
  }

  onEditorActionResult(result: EditorActionResult): void {
    this.hasSelection = result.hasSelectionAfter;
    this.coreBlocked = hasActiveInteraction(result) || needsViewportMotion(result);

    if (result.contentChanged || !this.hasSelection) {
      if (result.contentChanged) {
        this.clearSelectionHandles();
      }
      this.dismiss();
      return;
    }

    const wantsShow = result.selectionChanged;
    if (this.coreBlocked) {
      if (wantsShow || this.lifecycleState !== SelectionMenuLifecycleState.HIDDEN) {
        this.suspend();
      }
      return;
    }

    if (wantsShow || this.lifecycleState === SelectionMenuLifecycleState.SUSPENDED) {
      this.scheduleShow();
    }
  }

  dismiss(): void {
    this.cancelPendingShow();
    this.lifecycleState = SelectionMenuLifecycleState.HIDDEN;
    this.updateHiddenState();
  }

  onMenuItemClicked(item: SelectionMenuItem): void {
    switch (item.id) {
      case SelectionMenuItem.ACTION_CUT:
        this.editor.cutToClipboard();
        this.dismiss();
        break;
      case SelectionMenuItem.ACTION_COPY:
        this.editor.copyToClipboard();
        this.dismiss();
        break;
      case SelectionMenuItem.ACTION_PASTE:
        this.editor.pasteFromClipboard();
        this.dismiss();
        break;
      case SelectionMenuItem.ACTION_SELECT_ALL:
        this.editor.selectAll();
        break;
      default:
        this.eventBus.emit('selectionMenuItemClick', new SelectionMenuItemClickEvent(item));
        this.dismiss();
        break;
    }
  }

  private scheduleShow(): void {
    if (!this.hasSelection) {
      this.dismiss();
      return;
    }
    if (this.coreBlocked) {
      this.suspend();
      return;
    }
    this.cancelPendingShow();
    if (this.lifecycleState === SelectionMenuLifecycleState.VISIBLE) {
      this.updateHiddenState();
    }
    this.lifecycleState = SelectionMenuLifecycleState.PENDING_SHOW;
    this.showTimerId = setTimeout(() => {
      this.showTimerId = -1;
      this.doShow();
    }, SHOW_DELAY_MS);
  }

  private cancelPendingShow(): void {
    if (this.showTimerId >= 0) {
      clearTimeout(this.showTimerId);
      this.showTimerId = -1;
    }
  }

  private suspend(): void {
    this.cancelPendingShow();
    if (this.lifecycleState === SelectionMenuLifecycleState.VISIBLE) {
      this.updateHiddenState();
    }
    this.lifecycleState = SelectionMenuLifecycleState.SUSPENDED;
  }

  private doShow(): void {
    if (this.lifecycleState !== SelectionMenuLifecycleState.PENDING_SHOW) {
      return;
    }
    if (!this.hasSelection || !this.editor.hasSelection()) {
      this.dismiss();
      return;
    }
    if (this.coreBlocked) {
      this.suspend();
      return;
    }

    const items = this.buildItems();
    if (items.length === 0) {
      this.dismiss();
      return;
    }

    this.lifecycleState = SelectionMenuLifecycleState.VISIBLE;
    this.state = {
      visible: true,
      items: [...items],
      anchorRect: this.computeMenuAnchorRect()
    };
    this.emitState();
  }

  private buildItems(): SelectionMenuItem[] {
    if (this.itemProvider) {
      return this.itemProvider.provideMenuItems(this.controller) || [];
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

  private computeMenuAnchorRect(): PopupRect {
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

      return popupRect(
        Math.min(startX, endX),
        Math.min(startY, endY),
        Math.max(startX, endX),
        Math.max(startBottom, endBottom)
      );
    } else {
      anchorX = this.editor.getViewWidth() * 0.5;
      topY = 0;
      bottomY = 0;
    }

    return popupRect(anchorX, topY, anchorX, bottomY);
  }

  private updateVisibleState(items: SelectionMenuItem[]): void {
    if (this.lifecycleState !== SelectionMenuLifecycleState.VISIBLE) {
      return;
    }
    const anchorRect = this.computeMenuAnchorRect();
    this.state = {
      visible: true,
      items: [...items],
      anchorRect: anchorRect
    };
    this.emitState();
  }

  private updateHiddenState(): void {
    this.state = {
      visible: false,
      items: [],
      anchorRect: popupRect(
        this.state.anchorRect.left,
        this.state.anchorRect.top,
        this.state.anchorRect.right,
        this.state.anchorRect.bottom
      )
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
      anchorRect: popupRect(
        this.state.anchorRect.left,
        this.state.anchorRect.top,
        this.state.anchorRect.right,
        this.state.anchorRect.bottom
      )
    });
  }
}
