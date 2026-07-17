import { PointF } from './CoreFoundation';
import { KeyModifier } from './CoreKeymap';

export enum EventType {
  UNDEFINED = 0,
  TOUCH_DOWN = 1,
  TOUCH_POINTER_DOWN = 2,
  TOUCH_MOVE = 3,
  TOUCH_POINTER_UP = 4,
  TOUCH_UP = 5,
  TOUCH_CANCEL = 6,
  MOUSE_DOWN = 7,
  MOUSE_MOVE = 8,
  MOUSE_UP = 9,
  MOUSE_WHEEL = 10,
  MOUSE_RIGHT_DOWN = 11,
  DIRECT_SCALE = 12,
  DIRECT_SCROLL = 13,
  DIRECT_GESTURE_BEGIN = 14,
  DIRECT_GESTURE_END = 15,
}

export function eventTypeFromValue(value: number): EventType {
  switch (value) {
    case 0: return EventType.UNDEFINED;
    case 1: return EventType.TOUCH_DOWN;
    case 2: return EventType.TOUCH_POINTER_DOWN;
    case 3: return EventType.TOUCH_MOVE;
    case 4: return EventType.TOUCH_POINTER_UP;
    case 5: return EventType.TOUCH_UP;
    case 6: return EventType.TOUCH_CANCEL;
    case 7: return EventType.MOUSE_DOWN;
    case 8: return EventType.MOUSE_MOVE;
    case 9: return EventType.MOUSE_UP;
    case 10: return EventType.MOUSE_WHEEL;
    case 11: return EventType.MOUSE_RIGHT_DOWN;
    case 12: return EventType.DIRECT_SCALE;
    case 13: return EventType.DIRECT_SCROLL;
    case 14: return EventType.DIRECT_GESTURE_BEGIN;
    case 15: return EventType.DIRECT_GESTURE_END;
    default: return EventType.UNDEFINED;
  }
}

export enum GestureType {
  UNDEFINED = 0,
  TAP = 1,
  DOUBLE_TAP = 2,
  LONG_PRESS = 3,
  SCALE = 4,
  SCROLL = 5,
  FAST_SCROLL = 6,
  DRAG_SELECT = 7,
  CONTEXT_MENU = 8,
}

export function gestureTypeFromValue(value: number): GestureType {
  switch (value) {
    case 0: return GestureType.UNDEFINED;
    case 1: return GestureType.TAP;
    case 2: return GestureType.DOUBLE_TAP;
    case 3: return GestureType.LONG_PRESS;
    case 4: return GestureType.SCALE;
    case 5: return GestureType.SCROLL;
    case 6: return GestureType.FAST_SCROLL;
    case 7: return GestureType.DRAG_SELECT;
    case 8: return GestureType.CONTEXT_MENU;
    default: return GestureType.UNDEFINED;
  }
}

export enum HitTargetType {
  NONE = 0,
  INLAY_HINT_TEXT = 1,
  INLAY_HINT_ICON = 2,
  INLAY_HINT_COLOR = 3,
  CODELENS = 4,
  LINK = 5,
  GUTTER_ICON = 6,
  FOLD_GUTTER = 7,
  FOLD_PLACEHOLDER = 8,
}

export function hitTargetTypeFromValue(value: number): HitTargetType {
  switch (value) {
    case 0: return HitTargetType.NONE;
    case 1: return HitTargetType.INLAY_HINT_TEXT;
    case 2: return HitTargetType.INLAY_HINT_ICON;
    case 3: return HitTargetType.INLAY_HINT_COLOR;
    case 4: return HitTargetType.CODELENS;
    case 5: return HitTargetType.LINK;
    case 6: return HitTargetType.GUTTER_ICON;
    case 7: return HitTargetType.FOLD_GUTTER;
    case 8: return HitTargetType.FOLD_PLACEHOLDER;
    default: return HitTargetType.NONE;
  }
}

export class GestureEvent {
  type: EventType = EventType.UNDEFINED;
  points: PointF[] = [];
  modifiers: number = KeyModifier.NONE;
  wheelDeltaX: number = 0;
  wheelDeltaY: number = 0;
  directScale: number = 1;
}

export interface HitTarget {
  type: HitTargetType;
  line: number;
  column: number;
  iconId: number;
  colorValue: number;
}
