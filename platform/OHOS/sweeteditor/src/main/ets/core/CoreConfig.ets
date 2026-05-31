import { OffsetRect } from './CoreFoundation';

export enum AutoIndentMode {
  NONE = 0,
  KEEP_INDENT = 1,
}

export function autoIndentModeFromValue(value: number): AutoIndentMode {
  switch (value) {
    case 0: return AutoIndentMode.NONE;
    case 1: return AutoIndentMode.KEEP_INDENT;
    default: return AutoIndentMode.NONE;
  }
}

export enum CurrentLineRenderMode {
  BACKGROUND = 0,
  BORDER = 1,
  NONE = 2,
}

export function currentLineRenderModeFromValue(value: number): CurrentLineRenderMode {
  switch (value) {
    case 0: return CurrentLineRenderMode.BACKGROUND;
    case 1: return CurrentLineRenderMode.BORDER;
    case 2: return CurrentLineRenderMode.NONE;
    default: return CurrentLineRenderMode.BACKGROUND;
  }
}

export enum FoldArrowMode {
  AUTO = 0,
  ALWAYS = 1,
  HIDDEN = 2,
}

export function foldArrowModeFromValue(value: number): FoldArrowMode {
  switch (value) {
    case 0: return FoldArrowMode.AUTO;
    case 1: return FoldArrowMode.ALWAYS;
    case 2: return FoldArrowMode.HIDDEN;
    default: return FoldArrowMode.AUTO;
  }
}

export enum ScrollbarMode {
  ALWAYS = 0,
  TRANSIENT = 1,
  NEVER = 2,
}

export function scrollbarModeFromValue(value: number): ScrollbarMode {
  switch (value) {
    case 0: return ScrollbarMode.ALWAYS;
    case 1: return ScrollbarMode.TRANSIENT;
    case 2: return ScrollbarMode.NEVER;
    default: return ScrollbarMode.ALWAYS;
  }
}

export enum ScrollbarTrackTapMode {
  JUMP = 0,
  DISABLED = 1,
}

export function scrollbarTrackTapModeFromValue(value: number): ScrollbarTrackTapMode {
  switch (value) {
    case 0: return ScrollbarTrackTapMode.JUMP;
    case 1: return ScrollbarTrackTapMode.DISABLED;
    default: return ScrollbarTrackTapMode.JUMP;
  }
}

export enum WrapMode {
  NONE = 0,
  CHAR_BREAK = 1,
  WORD_BREAK = 2,
}

export function wrapModeFromValue(value: number): WrapMode {
  switch (value) {
    case 0: return WrapMode.NONE;
    case 1: return WrapMode.CHAR_BREAK;
    case 2: return WrapMode.WORD_BREAK;
    default: return WrapMode.NONE;
  }
}

export class EditorOptions {
  touchSlop: number = 10;
  doubleTapTimeout: number = 300;
  longPressMs: number = 500;
  flingFriction: number = 3.5;
  flingMinVelocity: number = 50.0;
  flingMaxVelocity: number = 8000.0;
  maxUndoStackSize: number = 512;
  keyChordTimeoutMs: number = 2000;
  revealSelectionEndOnSelectAll: boolean = false;
}

export class HandleConfig {
  startHitOffset: OffsetRect = { left: -32.1, top: -8.0, right: 8.0, bottom: 32.1 };
  endHitOffset: OffsetRect = { left: -8.0, top: -8.0, right: 32.1, bottom: 32.1 };
}

export class ScrollbarConfig {
  thickness: number = 10.0;
  minThumb: number = 24.0;
  thumbHitPadding: number = 0.0;
  mode: ScrollbarMode = ScrollbarMode.ALWAYS;
  thumbDraggable: boolean = true;
  trackTapMode: ScrollbarTrackTapMode = ScrollbarTrackTapMode.JUMP;
  fadeDelayMs: number = 700;
  fadeDurationMs: number = 300;
}
