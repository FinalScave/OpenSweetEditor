// ignore_for_file: unused_element

part of 'editor_core.dart';

class IntRange {
  const IntRange({
    this.start = 0,
    this.end = -1,
  });

  final int start;
  final int end;
}

class OffsetRect {
  const OffsetRect({
    this.left = 0.0,
    this.top = 0.0,
    this.right = 0.0,
    this.bottom = 0.0,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

class PointF {
  const PointF({
    this.x = 0.0,
    this.y = 0.0,
  });

  final double x;
  final double y;
}

class Rect {
  const Rect({
    this.origin = const PointF(),
    this.width = 0.0,
    this.height = 0.0,
  });

  final PointF origin;
  final double width;
  final double height;
}

class TextChange {
  const TextChange({
    this.range = const TextRange(),
    this.newText = '',
  });

  final TextRange range;
  final String newText;
}

class TextPosition {
  const TextPosition({
    this.line = 0,
    this.column = 0,
  });

  final int line;
  final int column;
}

class TextRange {
  const TextRange({
    this.start = const TextPosition(),
    this.end = const TextPosition(),
  });

  final TextPosition start;
  final TextPosition end;
}

extension TextRangeCoreHelpers on TextRange {
  bool get isCollapsed => start.line == end.line && start.column == end.column;
}

extension IntRangeCoreHelpers on IntRange {
  bool get isEmpty => end < start;

  bool contains(int value) => !isEmpty && value >= start && value <= end;

  int get length => isEmpty ? 0 : (end - start + 1);
}
