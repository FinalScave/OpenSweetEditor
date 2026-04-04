export enum FoldArrowMode {
  AUTO = 0,
  ALWAYS = 1,
  HIDDEN = 2
}

export enum WrapMode {
  NONE = 0,
  CHAR_BREAK = 1,
  WORD_BREAK = 2
}

export enum AutoIndentMode {
  NONE = 0,
  KEEP_INDENT = 1
}

export enum CurrentLineRenderMode {
  BACKGROUND = 0,
  BORDER = 1,
  NONE = 2
}

export enum ScrollBehavior {
  TOP = 0,
  CENTER = 1,
  BOTTOM = 2
}

export interface TextPosition {
  line: number;
  column: number;
}

export interface TextRange {
  start: TextPosition;
  end: TextPosition;
}

