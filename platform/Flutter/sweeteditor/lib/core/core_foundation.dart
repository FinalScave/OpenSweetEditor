// ignore_for_file: unused_element

part of 'editor_core.dart';

enum CaretAffinity {
  downstream(0),
  upstream(1);

  const CaretAffinity(this.value);
  final int value;

  static CaretAffinity fromValue(int value) {
    switch (value) {
      case 0: return downstream;
      case 1: return upstream;
      default: throw ArgumentError.value(value, 'value', 'Unknown CaretAffinity value');
    }
  }
}

class IntRange {
  const IntRange({
    this.start = 0,
    this.end = -1,
  });

  final int start;
  final int end;
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

class Size {
  const Size({
    this.width = 0.0,
    this.height = 0.0,
  });

  final double width;
  final double height;
}

class TabStopGroup {
  const TabStopGroup({
    this.index = 0,
    this.ranges = const [],
    this.defaultText = '',
  });

  final int index;
  final List<TextRange> ranges;
  final String defaultText;
}

class TextChange {
  const TextChange({
    this.range = const TextRange(),
    this.newText = '',
  });

  final TextRange range;
  final String newText;
}

class TextEdit {
  const TextEdit({
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
