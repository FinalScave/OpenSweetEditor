// ignore_for_file: unused_element

part of 'editor_core.dart';

enum EditorActionReason {
  none(0),
  setup(1),
  textEdit(2),
  keyInput(3),
  ime(4),
  gesture(5),
  animation(6),
  programmatic(7),
  decoration(8),
  folding(9),
  linkedEditing(10),
  textInsert(11),
  textReplace(12),
  textDelete(13),
  textUndo(14),
  textRedo(15),
  search(16);

  const EditorActionReason(this.value);
  final int value;

  static EditorActionReason fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return setup;
      case 2: return textEdit;
      case 3: return keyInput;
      case 4: return ime;
      case 5: return gesture;
      case 6: return animation;
      case 7: return programmatic;
      case 8: return decoration;
      case 9: return folding;
      case 10: return linkedEditing;
      case 11: return textInsert;
      case 12: return textReplace;
      case 13: return textDelete;
      case 14: return textUndo;
      case 15: return textRedo;
      case 16: return search;
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

class EditorActionResult {
  const EditorActionResult({
    this.handled = false,
    this.needsRedraw = false,
    this.reason = EditorActionReason.none,
    this.contentChanged = false,
    this.cursorChanged = false,
    this.selectionChanged = false,
    this.scrollChanged = false,
    this.scaleChanged = false,
    this.pointerCursorChanged = false,
    this.compositionChanged = false,
    this.decorationChanged = false,
    this.needsImeSync = false,
    this.needsEdgeScroll = false,
    this.needsFling = false,
    this.needsAnimation = false,
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
  final EditorActionReason reason;
  final bool contentChanged;
  final bool cursorChanged;
  final bool selectionChanged;
  final bool scrollChanged;
  final bool scaleChanged;
  final bool pointerCursorChanged;
  final bool compositionChanged;
  final bool decorationChanged;
  final bool needsImeSync;
  final bool needsEdgeScroll;
  final bool needsFling;
  final bool needsAnimation;
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
