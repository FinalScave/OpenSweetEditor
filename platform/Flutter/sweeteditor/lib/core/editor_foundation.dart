part of '../editor_core.dart';

/// Text position in document (0-based line/column).
class TextPosition {
  const TextPosition(this.line, this.column);

  final int line;
  final int column;

  @override
  String toString() => 'TextPosition(line: $line, column: $column)';
}

/// Text range in document.
class TextRange {
  const TextRange(this.start, this.end);

  final TextPosition start;
  final TextPosition end;

  @override
  String toString() => 'TextRange(start: $start, end: $end)';
}

/// Fold arrow display mode.
enum FoldArrowMode {
  auto_(0),
  always(1),
  hidden(2);

  const FoldArrowMode(this.value);
  final int value;
}

/// Wrap mode.
enum WrapMode {
  none(0),
  charBreak(1),
  wordBreak(2);

  const WrapMode(this.value);
  final int value;
}

/// Auto indent mode.
enum AutoIndentMode {
  none(0),
  keepIndent(1);

  const AutoIndentMode(this.value);
  final int value;
}

/// Current line render mode.
enum CurrentLineRenderMode {
  background(0),
  border(1),
  none(2);

  const CurrentLineRenderMode(this.value);
  final int value;
}

/// Scroll behavior.
enum ScrollBehavior {
  top(0),
  center(1),
  bottom(2);

  const ScrollBehavior(this.value);
  final int value;
}
