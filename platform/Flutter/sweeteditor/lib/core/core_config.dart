// ignore_for_file: unused_element

part of 'editor_core.dart';

enum AutoIndentMode {
  none(0),
  keepIndent(1);

  const AutoIndentMode(this.value);
  final int value;

  static AutoIndentMode fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return keepIndent;
      default: throw ArgumentError.value(value, 'value', 'Unknown AutoIndentMode value');
    }
  }
}

enum CurrentLineRenderMode {
  background(0),
  border(1),
  none(2);

  const CurrentLineRenderMode(this.value);
  final int value;

  static CurrentLineRenderMode fromValue(int value) {
    switch (value) {
      case 0: return background;
      case 1: return border;
      case 2: return none;
      default: throw ArgumentError.value(value, 'value', 'Unknown CurrentLineRenderMode value');
    }
  }
}

enum FoldArrowMode {
  auto(0),
  always(1),
  hidden(2);

  const FoldArrowMode(this.value);
  final int value;

  static FoldArrowMode fromValue(int value) {
    switch (value) {
      case 0: return auto;
      case 1: return always;
      case 2: return hidden;
      default: throw ArgumentError.value(value, 'value', 'Unknown FoldArrowMode value');
    }
  }
}

enum RangeEffectUnderlineStyle {
  none(0),
  solid(1),
  dashed(2),
  wavy(3);

  const RangeEffectUnderlineStyle(this.value);
  final int value;

  static RangeEffectUnderlineStyle fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return solid;
      case 2: return dashed;
      case 3: return wavy;
      default: throw ArgumentError.value(value, 'value', 'Unknown RangeEffectUnderlineStyle value');
    }
  }
}

enum ScrollbarMode {
  always(0),
  transient(1),
  never(2);

  const ScrollbarMode(this.value);
  final int value;

  static ScrollbarMode fromValue(int value) {
    switch (value) {
      case 0: return always;
      case 1: return transient;
      case 2: return never;
      default: throw ArgumentError.value(value, 'value', 'Unknown ScrollbarMode value');
    }
  }
}

enum ScrollbarTrackTapMode {
  jump(0),
  disabled(1);

  const ScrollbarTrackTapMode(this.value);
  final int value;

  static ScrollbarTrackTapMode fromValue(int value) {
    switch (value) {
      case 0: return jump;
      case 1: return disabled;
      default: throw ArgumentError.value(value, 'value', 'Unknown ScrollbarTrackTapMode value');
    }
  }
}

enum WhitespaceRenderMode {
  none(0),
  boundary(1),
  selection(2),
  trailing(3),
  all(4);

  const WhitespaceRenderMode(this.value);
  final int value;

  static WhitespaceRenderMode fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return boundary;
      case 2: return selection;
      case 3: return trailing;
      case 4: return all;
      default: throw ArgumentError.value(value, 'value', 'Unknown WhitespaceRenderMode value');
    }
  }
}

enum WrapMode {
  none(0),
  charBreak(1),
  wordBreak(2);

  const WrapMode(this.value);
  final int value;

  static WrapMode fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return charBreak;
      case 2: return wordBreak;
      default: throw ArgumentError.value(value, 'value', 'Unknown WrapMode value');
    }
  }
}

class EditorOptions {
  const EditorOptions({
    this.touchSlop = 10.0,
    this.doubleTapTimeout = 300,
    this.longPressMs = 500,
    this.flingFriction = 3.5,
    this.flingMinVelocity = 50.0,
    this.flingMaxVelocity = 8000.0,
    this.maxUndoStackSize = 512,
    this.keyChordTimeoutMs = 2000,
    this.revealSelectionEndOnSelectAll = false,
  });

  final double touchSlop;
  final int doubleTapTimeout;
  final int longPressMs;
  final double flingFriction;
  final double flingMinVelocity;
  final double flingMaxVelocity;
  final int maxUndoStackSize;
  final int keyChordTimeoutMs;
  final bool revealSelectionEndOnSelectAll;
}

class EditorRangeEffectStyles {
  const EditorRangeEffectStyles({
    this.selection = const RangeEffectStyle(),
    this.searchMatch = const RangeEffectStyle(),
    this.searchCurrent = const RangeEffectStyle(),
    this.documentHighlightText = const RangeEffectStyle(),
    this.documentHighlightRead = const RangeEffectStyle(),
    this.documentHighlightWrite = const RangeEffectStyle(),
    this.linkedEditingActive = const RangeEffectStyle(),
    this.linkedEditingInactive = const RangeEffectStyle(),
    this.imeComposition = const RangeEffectStyle(),
    this.bracketMatch = const RangeEffectStyle(),
    this.diagnosticError = const RangeEffectStyle(),
    this.diagnosticWarning = const RangeEffectStyle(),
    this.diagnosticInfo = const RangeEffectStyle(),
    this.diagnosticHint = const RangeEffectStyle(),
  });

  final RangeEffectStyle selection;
  final RangeEffectStyle searchMatch;
  final RangeEffectStyle searchCurrent;
  final RangeEffectStyle documentHighlightText;
  final RangeEffectStyle documentHighlightRead;
  final RangeEffectStyle documentHighlightWrite;
  final RangeEffectStyle linkedEditingActive;
  final RangeEffectStyle linkedEditingInactive;
  final RangeEffectStyle imeComposition;
  final RangeEffectStyle bracketMatch;
  final RangeEffectStyle diagnosticError;
  final RangeEffectStyle diagnosticWarning;
  final RangeEffectStyle diagnosticInfo;
  final RangeEffectStyle diagnosticHint;
}

class EditorRenderColors {
  const EditorRenderColors({
    this.textForeground = 0,
    this.linkForeground = 0,
    this.activeLinkForeground = 0,
    this.codelensForeground = 0,
    this.activeCodelensForeground = 0,
  });

  final int textForeground;
  final int linkForeground;
  final int activeLinkForeground;
  final int codelensForeground;
  final int activeCodelensForeground;
}

class HandleConfig {
  const HandleConfig({
    this.startHitArea = const HandleHitArea(),
    this.endHitArea = const HandleHitArea(),
  });

  final HandleHitArea startHitArea;
  final HandleHitArea endHitArea;
}

class HandleHitArea {
  const HandleHitArea({
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

class RangeEffectStyle {
  const RangeEffectStyle({
    this.foregroundColor = 0,
    this.backgroundColor = 0,
    this.borderColor = 0,
    this.underlineColor = 0,
    this.underlineStyle = RangeEffectUnderlineStyle.none,
  });

  final int foregroundColor;
  final int backgroundColor;
  final int borderColor;
  final int underlineColor;
  final RangeEffectUnderlineStyle underlineStyle;
}

class ScrollbarConfig {
  const ScrollbarConfig({
    this.thickness = 12.0,
    this.minThumb = 24.0,
    this.thumbHitPadding = 0.0,
    this.mode = ScrollbarMode.always,
    this.thumbDraggable = true,
    this.trackTapMode = ScrollbarTrackTapMode.jump,
    this.fadeDelayMs = 700,
    this.fadeDurationMs = 300,
  });

  final double thickness;
  final double minThumb;
  final double thumbHitPadding;
  final ScrollbarMode mode;
  final bool thumbDraggable;
  final ScrollbarTrackTapMode trackTapMode;
  final int fadeDelayMs;
  final int fadeDurationMs;
}
