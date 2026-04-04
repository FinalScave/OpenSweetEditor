import { InlayType } from '../core/CoreAdornments';
import { TextPosition, TextRange } from '../core/CoreFoundation';
import { TextChange } from '../core/EditorCore';
import { PointF } from '../core/CoreVisual';
import { SelectionMenuItem } from '../selection/SelectionMenuTypes';

/**
 * Base interface for editor events.
 * Each concrete event is an immutable data object that implements this interface.
 */
export interface EditorEvent {}

/**
 * Editor event listener callback type.
 */
export type EditorEventListener<T extends EditorEvent> = (event: T) => void;

export enum TextChangeAction {
  INSERT = 'insert',
  DELETE = 'delete',
  KEY = 'key',
  COMPOSITION = 'composition',
  UNDO = 'undo',
  REDO = 'redo'
}

export class TextChangedEvent implements EditorEvent {
  readonly changes: TextChange[];
  readonly action: TextChangeAction | null;

  constructor(changes: TextChange[], action: TextChangeAction | null = null) {
    this.changes = [...changes];
    this.action = action;
  }
}

export class CursorChangedEvent implements EditorEvent {
  readonly cursorPosition: TextPosition;

  constructor(cursorPosition: TextPosition) {
    this.cursorPosition = cursorPosition;
  }
}

export class SelectionChangedEvent implements EditorEvent {
  readonly hasSelection: boolean;
  readonly selection: TextRange | null;
  readonly cursorPosition: TextPosition;

  constructor(hasSelection: boolean, selection: TextRange | null, cursorPosition: TextPosition) {
    this.hasSelection = hasSelection;
    this.selection = selection;
    this.cursorPosition = cursorPosition;
  }
}

export class ScrollChangedEvent implements EditorEvent {
  readonly scrollX: number;
  readonly scrollY: number;

  constructor(scrollX: number, scrollY: number) {
    this.scrollX = scrollX;
    this.scrollY = scrollY;
  }
}

export class ScaleChangedEvent implements EditorEvent {
  readonly scale: number;

  constructor(scale: number) {
    this.scale = scale;
  }
}

export class LongPressEvent implements EditorEvent {
  readonly cursorPosition: TextPosition;
  readonly screenPoint: PointF;

  constructor(cursorPosition: TextPosition, screenPoint: PointF) {
    this.cursorPosition = cursorPosition;
    this.screenPoint = screenPoint;
  }
}

export class DoubleTapEvent implements EditorEvent {
  readonly cursorPosition: TextPosition;
  readonly hasSelection: boolean;
  readonly selection: TextRange | null;
  readonly screenPoint: PointF;

  constructor(cursorPosition: TextPosition, hasSelection: boolean,
    selection: TextRange | null, screenPoint: PointF) {
    this.cursorPosition = cursorPosition;
    this.hasSelection = hasSelection;
    this.selection = selection;
    this.screenPoint = screenPoint;
  }
}

export class ContextMenuEvent implements EditorEvent {
  readonly cursorPosition: TextPosition;
  readonly screenPoint: PointF;

  constructor(cursorPosition: TextPosition, screenPoint: PointF) {
    this.cursorPosition = cursorPosition;
    this.screenPoint = screenPoint;
  }
}

export class GutterIconClickEvent implements EditorEvent {
  readonly line: number;
  readonly iconId: number;
  readonly screenPoint: PointF;

  constructor(line: number, iconId: number, screenPoint: PointF) {
    this.line = line;
    this.iconId = iconId;
    this.screenPoint = screenPoint;
  }
}

export class InlayHintClickEvent implements EditorEvent {
  readonly line: number;
  readonly column: number;
  readonly type: InlayType;
  readonly intValue: number;
  readonly screenPoint: PointF;

  constructor(line: number, column: number, type: InlayType, intValue: number, screenPoint: PointF) {
    this.line = line;
    this.column = column;
    this.type = type;
    this.intValue = intValue;
    this.screenPoint = screenPoint;
  }
}

export class FoldToggleEvent implements EditorEvent {
  readonly line: number;
  readonly isGutter: boolean;
  readonly screenPoint: PointF;

  constructor(line: number, isGutter: boolean, screenPoint: PointF) {
    this.line = line;
    this.isGutter = isGutter;
    this.screenPoint = screenPoint;
  }
}

export class DocumentLoadedEvent implements EditorEvent {
}

export class SelectionMenuItemClickEvent implements EditorEvent {
  readonly item: SelectionMenuItem;

  constructor(item: SelectionMenuItem) {
    this.item = new SelectionMenuItem(item.id, item.label, item.enabled);
  }
}

