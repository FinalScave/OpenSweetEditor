// ignore_for_file: unused_element

part of 'editor_core.dart';

enum EventType {
  undefined(0),
  touchDown(1),
  touchPointerDown(2),
  touchMove(3),
  touchPointerUp(4),
  touchUp(5),
  touchCancel(6),
  mouseDown(7),
  mouseMove(8),
  mouseUp(9),
  mouseWheel(10),
  mouseRightDown(11),
  directScale(12),
  directScroll(13),
  directGestureBegin(14),
  directGestureEnd(15);

  const EventType(this.value);
  final int value;

  static EventType fromValue(int value) {
    switch (value) {
      case 0: return undefined;
      case 1: return touchDown;
      case 2: return touchPointerDown;
      case 3: return touchMove;
      case 4: return touchPointerUp;
      case 5: return touchUp;
      case 6: return touchCancel;
      case 7: return mouseDown;
      case 8: return mouseMove;
      case 9: return mouseUp;
      case 10: return mouseWheel;
      case 11: return mouseRightDown;
      case 12: return directScale;
      case 13: return directScroll;
      case 14: return directGestureBegin;
      case 15: return directGestureEnd;
      default: throw ArgumentError.value(value, 'value', 'Unknown EventType value');
    }
  }
}

enum GestureType {
  undefined(0),
  tap(1),
  doubleTap(2),
  longPress(3),
  scale(4),
  scroll(5),
  fastScroll(6),
  dragSelect(7),
  contextMenu(8);

  const GestureType(this.value);
  final int value;

  static GestureType fromValue(int value) {
    switch (value) {
      case 0: return undefined;
      case 1: return tap;
      case 2: return doubleTap;
      case 3: return longPress;
      case 4: return scale;
      case 5: return scroll;
      case 6: return fastScroll;
      case 7: return dragSelect;
      case 8: return contextMenu;
      default: throw ArgumentError.value(value, 'value', 'Unknown GestureType value');
    }
  }
}

enum HitTargetType {
  none(0),
  inlayHintText(1),
  inlayHintIcon(2),
  inlayHintColor(3),
  codelens(4),
  link(5),
  gutterIcon(6),
  foldGutter(7),
  foldPlaceholder(8);

  const HitTargetType(this.value);
  final int value;

  static HitTargetType fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return inlayHintText;
      case 2: return inlayHintIcon;
      case 3: return inlayHintColor;
      case 4: return codelens;
      case 5: return link;
      case 6: return gutterIcon;
      case 7: return foldGutter;
      case 8: return foldPlaceholder;
      default: throw ArgumentError.value(value, 'value', 'Unknown HitTargetType value');
    }
  }
}

class GestureEvent {
  const GestureEvent({
    this.type = EventType.undefined,
    this.points = const [],
    this.modifiers = 0,
    this.wheelDeltaX = 0.0,
    this.wheelDeltaY = 0.0,
    this.directScale = 1.0,
  });

  final EventType type;
  final List<PointF> points;
  final int modifiers;
  final double wheelDeltaX;
  final double wheelDeltaY;
  final double directScale;
}

class HitTarget {
  const HitTarget({
    this.type = HitTargetType.none,
    this.line = 0,
    this.column = 0,
    this.iconId = 0,
    this.colorValue = 0,
  });

  final HitTargetType type;
  final int line;
  final int column;
  final int iconId;
  final int colorValue;
}
