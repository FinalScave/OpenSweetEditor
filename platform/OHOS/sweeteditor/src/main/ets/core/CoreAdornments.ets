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

export enum SeparatorStyle {
  SINGLE = 0,
  DOUBLE = 1
}

export class FontStyle {
  static readonly NORMAL: number = 0;
  static readonly BOLD: number = 1;
  static readonly ITALIC: number = 2;
  static readonly STRIKETHROUGH: number = 4;
}

export enum DiagnosticSeverity {
  ERROR = 0,
  WARNING = 1,
  INFO = 2,
  HINT = 3
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

export interface CodeLensItem {
  column: number;
  text: string;
  commandId: number;
}

export interface LinkSpan {
  column: number;
  length: number;
  target: string;
}

export interface GutterIcon {
  iconId: number;
}

export interface Diagnostic {
  column: number;
  length: number;
  severity: number;
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
  style: SeparatorStyle;
  count: number;
  textEndColumn: number;
}
