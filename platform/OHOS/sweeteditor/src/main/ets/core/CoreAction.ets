import { PointF, TextChange, TextPosition, TextRange } from './CoreFoundation';
import { ImeSyncSnapshot } from './CoreIme';
import { EventType, GestureType, HitTarget } from './CoreInteraction';
import { KeyModifier } from './CoreKeymap';
import { PointerCursorType } from './CoreVisual';

export enum EditorActionSource {
  NONE = 0,
  SETUP = 1,
  PROGRAMMATIC = 2,
  KEYBOARD = 3,
  IME = 4,
  GESTURE = 5,
  ANIMATION = 6,
  DECORATION = 7,
  FOLDING = 8,
  SEARCH = 9,
  LINKED_EDITING = 10,
}

export function editorActionSourceFromValue(value: number): EditorActionSource {
  switch (value) {
    case 0: return EditorActionSource.NONE;
    case 1: return EditorActionSource.SETUP;
    case 2: return EditorActionSource.PROGRAMMATIC;
    case 3: return EditorActionSource.KEYBOARD;
    case 4: return EditorActionSource.IME;
    case 5: return EditorActionSource.GESTURE;
    case 6: return EditorActionSource.ANIMATION;
    case 7: return EditorActionSource.DECORATION;
    case 8: return EditorActionSource.FOLDING;
    case 9: return EditorActionSource.SEARCH;
    case 10: return EditorActionSource.LINKED_EDITING;
    default: return EditorActionSource.NONE;
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

export enum TextChangeKind {
  NONE = 0,
  INSERTION = 1,
  REPLACEMENT = 2,
  DELETION = 3,
  MOVE = 4,
  UNDO = 5,
  REDO = 6,
  MIXED = 7,
}

export function textChangeKindFromValue(value: number): TextChangeKind {
  switch (value) {
    case 0: return TextChangeKind.NONE;
    case 1: return TextChangeKind.INSERTION;
    case 2: return TextChangeKind.REPLACEMENT;
    case 3: return TextChangeKind.DELETION;
    case 4: return TextChangeKind.MOVE;
    case 5: return TextChangeKind.UNDO;
    case 6: return TextChangeKind.REDO;
    case 7: return TextChangeKind.MIXED;
    default: return TextChangeKind.NONE;
  }
}

export interface EditorActionResult {
  handled: boolean;
  needsRedraw: boolean;
  source: EditorActionSource;
  textChangeKind: TextChangeKind;
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
