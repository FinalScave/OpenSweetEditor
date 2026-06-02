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
      default: return none;
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
      default: return background;
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
      default: return auto;
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
      default: return always;
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
      default: return jump;
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
      default: return none;
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

class EditorRenderColors {
  const EditorRenderColors({
    this.textForeground = 0,
    this.selectionForeground = 0,
    this.linkForeground = 0,
    this.activeLinkForeground = 0,
    this.codelensForeground = 0,
    this.activeCodelensForeground = 0,
  });

  final int textForeground;
  final int selectionForeground;
  final int linkForeground;
  final int activeLinkForeground;
  final int codelensForeground;
  final int activeCodelensForeground;
}

class HandleConfig {
  const HandleConfig({
    this.startHitOffset = const OffsetRect(),
    this.endHitOffset = const OffsetRect(),
  });

  final OffsetRect startHitOffset;
  final OffsetRect endHitOffset;
}

class ScrollbarConfig {
  const ScrollbarConfig({
    this.thickness = 10.0,
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
