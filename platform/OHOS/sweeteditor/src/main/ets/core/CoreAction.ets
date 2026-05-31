import { PointF, TextChange, TextPosition, TextRange } from './CoreFoundation';
import { ImeSyncSnapshot } from './CoreIme';
import { EventType, GestureType, HitTarget } from './CoreInteraction';
import { KeyModifier } from './CoreKeymap';
import { PointerCursorType } from './CoreVisual';

export enum EditorActionReason {
  NONE = 0,
  SETUP = 1,
  TEXT_EDIT = 2,
  KEY_INPUT = 3,
  IME = 4,
  GESTURE = 5,
  ANIMATION = 6,
  PROGRAMMATIC = 7,
  DECORATION = 8,
  FOLDING = 9,
  LINKED_EDITING = 10,
  TEXT_INSERT = 11,
  TEXT_REPLACE = 12,
  TEXT_DELETE = 13,
  TEXT_UNDO = 14,
  TEXT_REDO = 15,
}

export function editorActionReasonFromValue(value: number): EditorActionReason {
  switch (value) {
    case 0: return EditorActionReason.NONE;
    case 1: return EditorActionReason.SETUP;
    case 2: return EditorActionReason.TEXT_EDIT;
    case 3: return EditorActionReason.KEY_INPUT;
    case 4: return EditorActionReason.IME;
    case 5: return EditorActionReason.GESTURE;
    case 6: return EditorActionReason.ANIMATION;
    case 7: return EditorActionReason.PROGRAMMATIC;
    case 8: return EditorActionReason.DECORATION;
    case 9: return EditorActionReason.FOLDING;
    case 10: return EditorActionReason.LINKED_EDITING;
    case 11: return EditorActionReason.TEXT_INSERT;
    case 12: return EditorActionReason.TEXT_REPLACE;
    case 13: return EditorActionReason.TEXT_DELETE;
    case 14: return EditorActionReason.TEXT_UNDO;
    case 15: return EditorActionReason.TEXT_REDO;
    default: return EditorActionReason.NONE;
  }
}

export enum ScrollBehavior {
  GOTO_TOP = 0,
  GOTO_CENTER = 1,
  GOTO_BOTTOM = 2,
}

export function scrollBehaviorFromValue(value: number): ScrollBehavior {
  switch (value) {
    case 0: return ScrollBehavior.GOTO_TOP;
    case 1: return ScrollBehavior.GOTO_CENTER;
    case 2: return ScrollBehavior.GOTO_BOTTOM;
    default: return ScrollBehavior.GOTO_TOP;
  }
}

export interface EditorActionResult {
  handled: boolean;
  needsRedraw: boolean;
  reason: EditorActionReason;
  contentChanged: boolean;
  cursorChanged: boolean;
  selectionChanged: boolean;
  scrollChanged: boolean;
  scaleChanged: boolean;
  pointerCursorChanged: boolean;
  compositionChanged: boolean;
  decorationChanged: boolean;
  needsImeSync: boolean;
  needsEdgeScroll: boolean;
  needsFling: boolean;
  needsAnimation: boolean;
  isHandleDrag: boolean;
  changes: TextChange[];
  cursorBefore: TextPosition;
  cursorAfter: TextPosition;
  hasSelectionBefore: boolean;
  hasSelectionAfter: boolean;
  selectionBefore: TextRange;
  selectionAfter: TextRange;
  scrollXBefore: number;
  scrollYBefore: number;
  scrollXAfter: number;
  scrollYAfter: number;
  scaleBefore: number;
  scaleAfter: number;
  pointerCursorBefore: PointerCursorType;
  pointerCursorAfter: PointerCursorType;
  imeSync: ImeSyncSnapshot;
  gestureType: GestureType;
  gestureEventType: EventType;
  tapPoint: PointF;
  hitTarget: HitTarget;
  modifiers: number;
  command: number;
}
