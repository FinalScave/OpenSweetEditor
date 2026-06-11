import '../core/editor_core.dart' as core;
import '../selection/selection_types.dart';

/// Base class for editor events.
abstract class EditorEvent {}

/// Editor event listener callback.
typedef EditorEventListener<T extends EditorEvent> = void Function(T event);

class TextChangedEvent implements EditorEvent {
  final List<core.TextChange> changes;
  final core.TextChangeKind kind;
  final core.EditorActionSource source;

  const TextChangedEvent({
    required this.changes,
    required this.kind,
    required this.source,
  });
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
  final core.PointF locationInEditor;

  const LongPressEvent({
    required this.cursorPosition,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class DoubleTapEvent implements EditorEvent {
  final core.TextPosition cursorPosition;
  final bool hasSelection;
  final core.TextRange? selection;
  final core.PointF locationInEditor;

  const DoubleTapEvent({
    required this.cursorPosition,
    required this.hasSelection,
    this.selection,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class ContextMenuEvent implements EditorEvent {
  final core.TextPosition cursorPosition;
  final core.PointF locationInEditor;

  const ContextMenuEvent({
    required this.cursorPosition,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class GutterIconClickEvent implements EditorEvent {
  final int line;
  final int iconId;
  final core.PointF locationInEditor;

  const GutterIconClickEvent({
    required this.line,
    required this.iconId,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class InlayHintClickEvent implements EditorEvent {
  final int line;
  final int column;
  final core.InlayType type;
  final int intValue;
  final core.PointF locationInEditor;

  const InlayHintClickEvent({
    required this.line,
    required this.column,
    required this.type,
    this.intValue = 0,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class FoldToggleEvent implements EditorEvent {
  final int line;
  final bool isGutter;
  final core.PointF locationInEditor;

  const FoldToggleEvent({
    required this.line,
    required this.isGutter,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class CodeLensClickEvent implements EditorEvent {
  final int line;
  final int column;
  final int commandId;
  final core.PointF locationInEditor;

  const CodeLensClickEvent({
    required this.line,
    required this.column,
    required this.commandId,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class LinkClickEvent implements EditorEvent {
  final int line;
  final int column;
  final String target;
  final core.PointF locationInEditor;

  const LinkClickEvent({
    required this.line,
    required this.column,
    required this.target,
    core.PointF? locationInEditor,
    @Deprecated('Use locationInEditor instead.') core.PointF? screenPoint,
  }) : assert(locationInEditor != null || screenPoint != null),
       locationInEditor =
           locationInEditor ?? screenPoint ?? const core.PointF();

  @Deprecated('Use locationInEditor instead.')
  core.PointF get screenPoint => locationInEditor;
}

class DocumentLoadedEvent implements EditorEvent {}

class SelectionMenuItemClickEvent implements EditorEvent {
  final SelectionMenuItem item;

  const SelectionMenuItemClickEvent({required this.item});
}
