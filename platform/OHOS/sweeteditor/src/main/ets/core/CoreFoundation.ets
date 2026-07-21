export enum CaretAffinity {
  DOWNSTREAM = 0,
  UPSTREAM = 1,
}

export function caretAffinityFromValue(value: number): CaretAffinity {
  switch (value) {
    case 0: return CaretAffinity.DOWNSTREAM;
    case 1: return CaretAffinity.UPSTREAM;
    default: throw new Error('Unknown CaretAffinity value: ' + value);
  }
}

export interface IntRange {
  start: number;
  end: number;
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

export interface Size {
  width: number;
  height: number;
}

export class TabStopGroup {
  index: number = 0;
  ranges: TextRange[] = [];
  defaultText: string = '';
}

export interface TextChange {
  range: TextRange;
  newText: string;
}

export interface TextEdit {
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
