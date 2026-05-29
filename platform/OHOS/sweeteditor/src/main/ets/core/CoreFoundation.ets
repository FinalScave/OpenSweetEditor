export interface IntRange {
  start: number;
  end: number;
}

export interface OffsetRect {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export interface PointF {
  x: number;
  y: number;
}

export interface Rect {
  origin: PointF;
  width: number;
  height: number;
}

export interface TextChange {
  range: TextRange;
  newText: string;
}

export interface TextPosition {
  line: number;
  column: number;
}

export interface TextRange {
  start: TextPosition;
  end: TextPosition;
}
