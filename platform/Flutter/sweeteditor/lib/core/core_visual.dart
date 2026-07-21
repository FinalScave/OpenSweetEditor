// ignore_for_file: unused_element

part of 'editor_core.dart';

enum FoldState {
  none(0),
  expanded(1),
  collapsed(2);

  const FoldState(this.value);
  final int value;

  static FoldState fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return expanded;
      case 2: return collapsed;
      default: throw ArgumentError.value(value, 'value', 'Unknown FoldState value');
    }
  }
}

enum GuideDirection {
  vertical(0),
  horizontal(1);

  const GuideDirection(this.value);
  final int value;

  static GuideDirection fromValue(int value) {
    switch (value) {
      case 0: return vertical;
      case 1: return horizontal;
      default: throw ArgumentError.value(value, 'value', 'Unknown GuideDirection value');
    }
  }
}

enum GuideStyle {
  solid(0),
  dashed(1),
  double(2);

  const GuideStyle(this.value);
  final int value;

  static GuideStyle fromValue(int value) {
    switch (value) {
      case 0: return solid;
      case 1: return dashed;
      case 2: return double;
      default: throw ArgumentError.value(value, 'value', 'Unknown GuideStyle value');
    }
  }
}

enum GuideType {
  indent(0),
  bracket(1),
  flow(2),
  separator(3);

  const GuideType(this.value);
  final int value;

  static GuideType fromValue(int value) {
    switch (value) {
      case 0: return indent;
      case 1: return bracket;
      case 2: return flow;
      case 3: return separator;
      default: throw ArgumentError.value(value, 'value', 'Unknown GuideType value');
    }
  }
}

enum PointerCursorType {
  default_(0),
  text(1),
  hand(2);

  const PointerCursorType(this.value);
  final int value;

  static PointerCursorType fromValue(int value) {
    switch (value) {
      case 0: return default_;
      case 1: return text;
      case 2: return hand;
      default: throw ArgumentError.value(value, 'value', 'Unknown PointerCursorType value');
    }
  }
}

enum RangeEffectKind {
  selection(0),
  searchMatch(1),
  searchCurrent(2),
  documentHighlightText(3),
  documentHighlightRead(4),
  documentHighlightWrite(5),
  linkedEditingActive(6),
  linkedEditingInactive(7),
  imeComposition(8),
  bracketMatch(9),
  diagnosticError(10),
  diagnosticWarning(11),
  diagnosticInfo(12),
  diagnosticHint(13);

  const RangeEffectKind(this.value);
  final int value;

  static RangeEffectKind fromValue(int value) {
    switch (value) {
      case 0: return selection;
      case 1: return searchMatch;
      case 2: return searchCurrent;
      case 3: return documentHighlightText;
      case 4: return documentHighlightRead;
      case 5: return documentHighlightWrite;
      case 6: return linkedEditingActive;
      case 7: return linkedEditingInactive;
      case 8: return imeComposition;
      case 9: return bracketMatch;
      case 10: return diagnosticError;
      case 11: return diagnosticWarning;
      case 12: return diagnosticInfo;
      case 13: return diagnosticHint;
      default: throw ArgumentError.value(value, 'value', 'Unknown RangeEffectKind value');
    }
  }
}

enum VisualLineKind {
  content(0),
  phantom(1),
  codelens(2);

  const VisualLineKind(this.value);
  final int value;

  static VisualLineKind fromValue(int value) {
    switch (value) {
      case 0: return content;
      case 1: return phantom;
      case 2: return codelens;
      default: throw ArgumentError.value(value, 'value', 'Unknown VisualLineKind value');
    }
  }
}

enum VisualRunType {
  text(0),
  whitespace(1),
  tab(2),
  newline(3),
  inlayHint(4),
  phantomText(5),
  foldPlaceholder(6),
  codelens(7),
  link(8);

  const VisualRunType(this.value);
  final int value;

  static VisualRunType fromValue(int value) {
    switch (value) {
      case 0: return text;
      case 1: return whitespace;
      case 2: return tab;
      case 3: return newline;
      case 4: return inlayHint;
      case 5: return phantomText;
      case 6: return foldPlaceholder;
      case 7: return codelens;
      case 8: return link;
      default: throw ArgumentError.value(value, 'value', 'Unknown VisualRunType value');
    }
  }
}

class Cursor {
  const Cursor({
    this.textPosition = const TextPosition(),
    this.position = const PointF(),
    this.height = 0.0,
    this.visible = true,
    this.showDragger = false,
  });

  final TextPosition textPosition;
  final PointF position;
  final double height;
  final bool visible;
  final bool showDragger;
}

class CursorRect {
  const CursorRect({
    this.x = 0.0,
    this.y = 0.0,
    this.height = 0.0,
  });

  final double x;
  final double y;
  final double height;
}

class EditorRenderModel {
  const EditorRenderModel({
    this.splitX = 0.0,
    this.splitLineVisible = true,
    this.scrollX = 0.0,
    this.scrollY = 0.0,
    this.viewportSize = const Size(),
    this.currentLine = const PointF(),
    this.currentLineRenderMode = CurrentLineRenderMode.background,
    this.lines = const [],
    this.cursor = const Cursor(),
    this.rangeEffects = const [],
    this.selectionStartHandle = const SelectionHandle(),
    this.selectionEndHandle = const SelectionHandle(),
    this.guideSegments = const [],
    this.maxGutterIcons = 0,
    this.gutterIcons = const [],
    this.foldMarkers = const [],
    this.verticalScrollbar = const ScrollbarModel(),
    this.horizontalScrollbar = const ScrollbarModel(),
    this.gutterSticky = true,
    this.gutterVisible = true,
    this.pointerCursorType = PointerCursorType.text,
  });

  final double splitX;
  final bool splitLineVisible;
  final double scrollX;
  final double scrollY;
  final Size viewportSize;
  final PointF currentLine;
  final CurrentLineRenderMode currentLineRenderMode;
  final List<VisualLine> lines;
  final Cursor cursor;
  final List<RangeEffectRenderItem> rangeEffects;
  final SelectionHandle selectionStartHandle;
  final SelectionHandle selectionEndHandle;
  final List<GuideSegment> guideSegments;
  final int maxGutterIcons;
  final List<GutterIconRenderItem> gutterIcons;
  final List<FoldMarkerRenderItem> foldMarkers;
  final ScrollbarModel verticalScrollbar;
  final ScrollbarModel horizontalScrollbar;
  final bool gutterSticky;
  final bool gutterVisible;
  final PointerCursorType pointerCursorType;
}

class FoldMarkerRenderItem {
  const FoldMarkerRenderItem({
    this.logicalLine = 0,
    this.foldState = FoldState.none,
    this.rect = const Rect(),
  });

  final int logicalLine;
  final FoldState foldState;
  final Rect rect;
}

class GuideSegment {
  const GuideSegment({
    this.direction = GuideDirection.vertical,
    this.type = GuideType.indent,
    this.style = GuideStyle.solid,
    this.start = const PointF(),
    this.end = const PointF(),
    this.arrowEnd = false,
  });

  final GuideDirection direction;
  final GuideType type;
  final GuideStyle style;
  final PointF start;
  final PointF end;
  final bool arrowEnd;
}

class GutterIconRenderItem {
  const GutterIconRenderItem({
    this.logicalLine = 0,
    this.iconId = 0,
    this.rect = const Rect(),
  });

  final int logicalLine;
  final int iconId;
  final Rect rect;
}

class LayoutMetrics {
  const LayoutMetrics({
    this.fontHeight = 20.0,
    this.fontAscent = 0.0,
    this.lineSpacingAdd = 0.0,
    this.lineSpacingMult = 1.2,
    this.lineNumberMargin = 10.0,
    this.lineNumberWidth = 10.0,
    this.contentStartPadding = 0.0,
    this.maxGutterIcons = 0,
    this.inlayHintPadding = 0.0,
    this.inlayHintMargin = 0.0,
    this.foldArrowMode = FoldArrowMode.auto,
    this.hasFoldRegions = false,
    this.gutterSticky = true,
    this.gutterVisible = true,
  });

  final double fontHeight;
  final double fontAscent;
  final double lineSpacingAdd;
  final double lineSpacingMult;
  final double lineNumberMargin;
  final double lineNumberWidth;
  final double contentStartPadding;
  final int maxGutterIcons;
  final double inlayHintPadding;
  final double inlayHintMargin;
  final FoldArrowMode foldArrowMode;
  final bool hasFoldRegions;
  final bool gutterSticky;
  final bool gutterVisible;
}

class RangeEffectRenderItem {
  const RangeEffectRenderItem({
    this.rect = const Rect(),
    this.kind = RangeEffectKind.selection,
    this.style = const RangeEffectStyle(),
  });

  final Rect rect;
  final RangeEffectKind kind;
  final RangeEffectStyle style;
}

class ScrollMetrics {
  const ScrollMetrics({
    this.scale = 1.0,
    this.scrollX = 0.0,
    this.scrollY = 0.0,
    this.maxScrollX = 0.0,
    this.maxScrollY = 0.0,
    this.contentSize = const Size(),
    this.viewportSize = const Size(),
    this.textAreaX = 0.0,
    this.textAreaWidth = 0.0,
    this.canScrollX = false,
    this.canScrollY = false,
  });

  final double scale;
  final double scrollX;
  final double scrollY;
  final double maxScrollX;
  final double maxScrollY;
  final Size contentSize;
  final Size viewportSize;
  final double textAreaX;
  final double textAreaWidth;
  final bool canScrollX;
  final bool canScrollY;
}

class ScrollbarModel {
  const ScrollbarModel({
    this.visible = false,
    this.alpha = 0.0,
    this.thumbActive = false,
    this.track = const Rect(),
    this.thumb = const Rect(),
  });

  final bool visible;
  final double alpha;
  final bool thumbActive;
  final Rect track;
  final Rect thumb;
}

class SelectionHandle {
  const SelectionHandle({
    this.position = const PointF(),
    this.height = 0.0,
    this.visible = false,
  });

  final PointF position;
  final double height;
  final bool visible;
}

class VisualLine {
  const VisualLine({
    this.logicalLine = 0,
    this.wrapIndex = 0,
    this.lineNumberPosition = const PointF(),
    this.runs = const [],
    this.kind = VisualLineKind.content,
    this.ownsGutterSemantics = false,
    this.foldState = FoldState.none,
  });

  final int logicalLine;
  final int wrapIndex;
  final PointF lineNumberPosition;
  final List<VisualRun> runs;
  final VisualLineKind kind;
  final bool ownsGutterSemantics;
  final FoldState foldState;
}

class VisualRun {
  const VisualRun({
    this.type = VisualRunType.text,
    this.x = 0.0,
    this.y = 0.0,
    this.text = '',
    this.style = const TextStyle(),
    this.iconId = 0,
    this.colorValue = 0,
    this.width = 0.0,
    this.padding = 0.0,
    this.margin = 0.0,
    this.active = false,
  });

  final VisualRunType type;
  final double x;
  final double y;
  final String text;
  final TextStyle style;
  final int iconId;
  final int colorValue;
  final double width;
  final double padding;
  final double margin;
  final bool active;
}

extension FoldMarkerRenderItemRectAccess on FoldMarkerRenderItem {
  PointF get origin => rect.origin;

  double get width => rect.width;

  double get height => rect.height;
}

extension GutterIconRenderItemRectAccess on GutterIconRenderItem {
  PointF get origin => rect.origin;

  double get width => rect.width;

  double get height => rect.height;
}
