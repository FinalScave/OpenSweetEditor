import '../editor_core.dart' as core;
import '../selection/selection_types.dart';

/// Base class for editor events.
abstract class EditorEvent {}

/// Editor event listener callback.
typedef EditorEventListener<T extends EditorEvent> = void Function(T event);

/// Text change action type.
enum TextChangeAction { insert, delete_, key, composition, undo, redo }

class TextChangedEvent implements EditorEvent {
  final List<core.TextChange> changes;
  final TextChangeAction? action;

  const TextChangedEvent({required this.changes, this.action});
}

class CursorChangedEvent implements EditorEvent {
  final core.TextPosition cursorPosition;

  const CursorChangedEvent({required this.cursorPosition});
}

class SelectionChangedEvent implements EditorEvent {
  final bool hasSelection;
  final core.TextRange? selection;
  final core.TextPosition cursorPosition;

  const SelectionChangedEvent({
    required this.hasSelection,
    this.selection,
    required this.cursorPosition,
  });
}

class ScrollChangedEvent implements EditorEvent {
  final double scrollX;
  final double scrollY;

  const ScrollChangedEvent({required this.scrollX, required this.scrollY});
}

class ScaleChangedEvent implements EditorEvent {
  final double scale;

  const ScaleChangedEvent({required this.scale});
}

class LongPressEvent implements EditorEvent {
  final core.TextPosition cursorPosition;
  final core.PointF screenPoint;

  const LongPressEvent({
    required this.cursorPosition,
    required this.screenPoint,
  });
}

class DoubleTapEvent implements EditorEvent {
  final core.TextPosition cursorPosition;
  final bool hasSelection;
  final core.TextRange? selection;
  final core.PointF screenPoint;

  const DoubleTapEvent({
    required this.cursorPosition,
    required this.hasSelection,
    this.selection,
    required this.screenPoint,
  });
}

class ContextMenuEvent implements EditorEvent {
  final core.TextPosition cursorPosition;
  final core.PointF screenPoint;

  const ContextMenuEvent({
    required this.cursorPosition,
    required this.screenPoint,
  });
}

class GutterIconClickEvent implements EditorEvent {
  final int line;
  final int iconId;
  final core.PointF screenPoint;

  const GutterIconClickEvent({
    required this.line,
    required this.iconId,
    required this.screenPoint,
  });
}

class InlayHintClickEvent implements EditorEvent {
  final int line;
  final int column;
  final core.InlayType type;
  final int intValue;
  final core.PointF screenPoint;

  const InlayHintClickEvent({
    required this.line,
    required this.column,
    required this.type,
    this.intValue = 0,
    required this.screenPoint,
  });
}

class FoldToggleEvent implements EditorEvent {
  final int line;
  final bool isGutter;
  final core.PointF screenPoint;

  const FoldToggleEvent({
    required this.line,
    required this.isGutter,
    required this.screenPoint,
  });
}

class DocumentLoadedEvent implements EditorEvent {}

class SelectionMenuItemClickEvent implements EditorEvent {
  final SelectionMenuItem item;

  const SelectionMenuItemClickEvent({required this.item});
}
