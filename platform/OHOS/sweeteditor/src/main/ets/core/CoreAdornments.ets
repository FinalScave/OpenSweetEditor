import { TextPosition } from './CoreFoundation';

export enum SpanLayer {
  SYNTAX = 0,
  SEMANTIC = 1
}

export enum InlayType {
  Text = 0,
  Icon = 1,
  Color = 2
}

export interface TextStyle {
  color: number;
  backgroundColor: number;
  fontStyle: number;
}

export interface StyleSpan {
  column: number;
  length: number;
  styleId: number;
}

export interface InlayHint {
  type: InlayType;
  column: number;
  text: string | null;
  intValue: number;
}

export interface PhantomText {
  column: number;
  text: string;
}

export interface GutterIcon {
  iconId: number;
}

export interface DiagnosticItem {
  column: number;
  length: number;
  severity: number;
  color: number;
}

export interface FoldRegion {
  startLine: number;
  endLine: number;
}

export interface IndentGuide {
  start: TextPosition;
  end: TextPosition;
}

export interface BracketGuide {
  parent: TextPosition;
  end: TextPosition;
  children: TextPosition[];
}

export interface FlowGuide {
  start: TextPosition;
  end: TextPosition;
}

export interface SeparatorGuide {
  line: number;
  style: number;
  count: number;
  textEndColumn: number;
}

