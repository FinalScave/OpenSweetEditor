export enum AutoIndentMode {
  NONE = 0,
  KEEP_INDENT = 1,
}

export function autoIndentModeFromValue(value: number): AutoIndentMode {
  switch (value) {
    case 0: return AutoIndentMode.NONE;
    case 1: return AutoIndentMode.KEEP_INDENT;
    default: throw new Error('Unknown AutoIndentMode value: ' + value);
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
    default: throw new Error('Unknown CurrentLineRenderMode value: ' + value);
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
    default: throw new Error('Unknown FoldArrowMode value: ' + value);
  }
}

export enum RangeEffectUnderlineStyle {
  NONE = 0,
  SOLID = 1,
  DASHED = 2,
  WAVY = 3,
}

export function rangeEffectUnderlineStyleFromValue(value: number): RangeEffectUnderlineStyle {
  switch (value) {
    case 0: return RangeEffectUnderlineStyle.NONE;
    case 1: return RangeEffectUnderlineStyle.SOLID;
    case 2: return RangeEffectUnderlineStyle.DASHED;
    case 3: return RangeEffectUnderlineStyle.WAVY;
    default: throw new Error('Unknown RangeEffectUnderlineStyle value: ' + value);
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
    default: throw new Error('Unknown ScrollbarMode value: ' + value);
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
    default: throw new Error('Unknown ScrollbarTrackTapMode value: ' + value);
  }
}

export enum WhitespaceRenderMode {
  NONE = 0,
  BOUNDARY = 1,
  SELECTION = 2,
  TRAILING = 3,
  ALL = 4,
}

export function whitespaceRenderModeFromValue(value: number): WhitespaceRenderMode {
  switch (value) {
    case 0: return WhitespaceRenderMode.NONE;
    case 1: return WhitespaceRenderMode.BOUNDARY;
    case 2: return WhitespaceRenderMode.SELECTION;
    case 3: return WhitespaceRenderMode.TRAILING;
    case 4: return WhitespaceRenderMode.ALL;
    default: throw new Error('Unknown WhitespaceRenderMode value: ' + value);
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
    default: throw new Error('Unknown WrapMode value: ' + value);
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

export class EditorRangeEffectStyles {
  selection: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  searchMatch: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  searchCurrent: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  documentHighlightText: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  documentHighlightRead: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  documentHighlightWrite: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  linkedEditingActive: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  linkedEditingInactive: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  imeComposition: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  bracketMatch: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  diagnosticError: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  diagnosticWarning: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  diagnosticInfo: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
  diagnosticHint: RangeEffectStyle = { foregroundColor: 0, backgroundColor: 0, borderColor: 0, underlineColor: 0, underlineStyle: RangeEffectUnderlineStyle.NONE };
}

export class EditorRenderColors {
  textForeground: number = 0;
  linkForeground: number = 0;
  activeLinkForeground: number = 0;
  codelensForeground: number = 0;
  activeCodelensForeground: number = 0;
  diffAddedLineBackground: number = 0;
  diffRemovedLineBackground: number = 0;
  diffAddedGutterBackground: number = 0;
  diffRemovedGutterBackground: number = 0;
}

export class HandleConfig {
  startHitArea: HandleHitArea = { left: -32.1, top: -8.0, right: 8.0, bottom: 32.1 };
  endHitArea: HandleHitArea = { left: -8.0, top: -8.0, right: 32.1, bottom: 32.1 };
}

export interface HandleHitArea {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface RangeEffectStyle {
  foregroundColor: number;
  backgroundColor: number;
  borderColor: number;
  underlineColor: number;
  underlineStyle: RangeEffectUnderlineStyle;
}

export class ScrollbarConfig {
  thickness: number = 12.0;
  minThumb: number = 24.0;
  thumbHitPadding: number = 0.0;
  mode: ScrollbarMode = ScrollbarMode.ALWAYS;
  thumbDraggable: boolean = true;
  trackTapMode: ScrollbarTrackTapMode = ScrollbarTrackTapMode.JUMP;
  fadeDelayMs: number = 700;
  fadeDurationMs: number = 300;
}
