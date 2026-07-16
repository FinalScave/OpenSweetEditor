// ignore_for_file: unused_element

part of 'editor_core.dart';

class AnimationFlag {
  AnimationFlag._();
  static const int none = 0;
  static const int edgeScroll = 1;
  static const int fling = 2;
  static const int transientScrollbar = 4;
}

enum EditorActionSource {
  none(0),
  setup(1),
  programmatic(2),
  keyboard(3),
  ime(4),
  gesture(5),
  animation(6),
  decoration(7),
  folding(8),
  search(9),
  linkedEditing(10);

  const EditorActionSource(this.value);
  final int value;

  static EditorActionSource fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return setup;
      case 2: return programmatic;
      case 3: return keyboard;
      case 4: return ime;
      case 5: return gesture;
      case 6: return animation;
      case 7: return decoration;
      case 8: return folding;
      case 9: return search;
      case 10: return linkedEditing;
      default: return none;
    }
  }
}

enum ScrollBehavior {
  gotoTop(0),
  gotoCenter(1),
  gotoBottom(2);

  const ScrollBehavior(this.value);
  final int value;

  static ScrollBehavior fromValue(int value) {
    switch (value) {
      case 0: return gotoTop;
      case 1: return gotoCenter;
      case 2: return gotoBottom;
      default: return gotoTop;
    }
  }
}

enum TextChangeKind {
  none(0),
  insertion(1),
  replacement(2),
  deletion(3),
  move(4),
  undo(5),
  redo(6),
  mixed(7);

  const TextChangeKind(this.value);
  final int value;

  static TextChangeKind fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return insertion;
      case 2: return replacement;
      case 3: return deletion;
      case 4: return move;
      case 5: return undo;
      case 6: return redo;
      case 7: return mixed;
      default: return none;
    }
  }
}

class EditorActionResult {
  const EditorActionResult({
    this.handled = false,
    this.needsRedraw = false,
    this.source = EditorActionSource.none,
    this.textChangeKind = TextChangeKind.none,
    this.contentChanged = false,
    this.cursorChanged = false,
    this.selectionChanged = false,
    this.scrollChanged = false,
    this.scaleChanged = false,
    this.pointerCursorChanged = false,
    this.compositionChanged = false,
    this.decorationChanged = false,
    this.needsImeSync = false,
    this.animationFlags = 0,
    this.nextAnimationDelayMs = 0,
    this.isHandleDrag = false,
    this.changes = const [],
    this.cursorBefore = const TextPosition(),
    this.cursorAfter = const TextPosition(),
    this.hasSelectionBefore = false,
    this.hasSelectionAfter = false,
    this.selectionBefore = const TextRange(),
    this.selectionAfter = const TextRange(),
    this.scrollXBefore = 0.0,
    this.scrollYBefore = 0.0,
    this.scrollXAfter = 0.0,
    this.scrollYAfter = 0.0,
    this.scaleBefore = 1.0,
    this.scaleAfter = 1.0,
    this.pointerCursorBefore = PointerCursorType.text,
    this.pointerCursorAfter = PointerCursorType.text,
    this.imeSync = const ImeSyncSnapshot(),
    this.gestureType = GestureType.undefined,
    this.gestureEventType = EventType.undefined,
    this.tapPoint = const PointF(),
    this.hitTarget = const HitTarget(),
    this.modifiers = 0,
    this.command = 0,
  });

  final bool handled;
  final bool needsRedraw;
  final EditorActionSource source;
  final TextChangeKind textChangeKind;
  final bool contentChanged;
  final bool cursorChanged;
  final bool selectionChanged;
  final bool scrollChanged;
  final bool scaleChanged;
  final bool pointerCursorChanged;
  final bool compositionChanged;
  final bool decorationChanged;
  final bool needsImeSync;
  final int animationFlags;
  final int nextAnimationDelayMs;
  final bool isHandleDrag;
  final List<TextChange> changes;
  final TextPosition cursorBefore;
  final TextPosition cursorAfter;
  final bool hasSelectionBefore;
  final bool hasSelectionAfter;
  final TextRange selectionBefore;
  final TextRange selectionAfter;
  final double scrollXBefore;
  final double scrollYBefore;
  final double scrollXAfter;
  final double scrollYAfter;
  final double scaleBefore;
  final double scaleAfter;
  final PointerCursorType pointerCursorBefore;
  final PointerCursorType pointerCursorAfter;
  final ImeSyncSnapshot imeSync;
  final GestureType gestureType;
  final EventType gestureEventType;
  final PointF tapPoint;
  final HitTarget hitTarget;
  final int modifiers;
  final int command;
}

extension EditorActionResultAnimationHelpers on EditorActionResult {
  bool hasAnimationFlag(int flag) => (animationFlags & flag) != 0;

  bool get needsAnimation => animationFlags != AnimationFlag.none;

  bool get needsViewportMotion =>
      hasAnimationFlag(AnimationFlag.edgeScroll) ||
      hasAnimationFlag(AnimationFlag.fling);
}
