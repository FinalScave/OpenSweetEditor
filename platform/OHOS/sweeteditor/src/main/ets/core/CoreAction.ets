import { PointF, TextChange, TextPosition, TextRange } from './CoreFoundation';
import { ImeHostAction, ImeState } from './CoreIme';
import { EventType, GestureType, HitTarget } from './CoreInteraction';
import { KeyModifier } from './CoreKeymap';
import { PointerCursorType } from './CoreVisual';

export class AnimationFlag {
  static readonly NONE: number = 0;
  static readonly EDGE_SCROLL: number = 1;
  static readonly FLING: number = 2;
  static readonly TRANSIENT_SCROLLBAR: number = 4;
}

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
    default: throw new Error('Unknown EditorActionSource value: ' + value);
  }
}

export class InteractionFlag {
  static readonly NONE: number = 0;
  static readonly PRIMARY_POINTER: number = 1;
  static readonly SELECTION_DRAG: number = 2;
  static readonly VIEWPORT_GESTURE: number = 4;
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
    default: throw new Error('Unknown ScrollBehavior value: ' + value);
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
    default: throw new Error('Unknown TextChangeKind value: ' + value);
  }
}

export interface EditorActionResult {
  handled: boolean;
  needsRedraw: boolean;
  source: EditorActionSource;
  textChangeKind: TextChangeKind;
  cursorChanged: boolean;
  selectionChanged: boolean;
  scrollChanged: boolean;
  scaleChanged: boolean;
  pointerCursorChanged: boolean;
  compositionChanged: boolean;
  decorationChanged: boolean;
  animationFlags: number;
  nextAnimationDelayMs: number;
  interactionFlags: number;
  textChanges: TextChange[];
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
  imeHostAction: ImeHostAction;
  imeState: ImeState;
  gestureType: GestureType;
  gestureEventType: EventType;
  tapPoint: PointF;
  hitTarget: HitTarget;
  modifiers: number;
  command: number;
}

export function hasAnimationFlag(result: EditorActionResult, flag: number): boolean {
  return (result.animationFlags & flag) !== 0;
}

export function needsAnimation(result: EditorActionResult): boolean {
  return result.animationFlags !== AnimationFlag.NONE;
}

export function needsViewportMotion(result: EditorActionResult): boolean {
  return hasAnimationFlag(result, AnimationFlag.EDGE_SCROLL) ||
    hasAnimationFlag(result, AnimationFlag.FLING);
}

export function hasInteractionFlag(result: EditorActionResult, flag: number): boolean {
  return (result.interactionFlags & flag) !== 0;
}

export function hasActiveInteraction(result: EditorActionResult): boolean {
  return result.interactionFlags !== InteractionFlag.NONE;
}
