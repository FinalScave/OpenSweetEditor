import { TextPosition } from './CoreFoundation';

export enum DiagnosticSeverity {
  DIAG_ERROR = 0,
  DIAG_WARNING = 1,
  DIAG_INFO = 2,
  DIAG_HINT = 3,
}

export function diagnosticSeverityFromValue(value: number): DiagnosticSeverity {
  switch (value) {
    case 0: return DiagnosticSeverity.DIAG_ERROR;
    case 1: return DiagnosticSeverity.DIAG_WARNING;
    case 2: return DiagnosticSeverity.DIAG_INFO;
    case 3: return DiagnosticSeverity.DIAG_HINT;
    default: return DiagnosticSeverity.DIAG_ERROR;
  }
}

export enum InlayType {
  TEXT = 0,
  ICON = 1,
  COLOR = 2,
}

export function inlayTypeFromValue(value: number): InlayType {
  switch (value) {
    case 0: return InlayType.TEXT;
    case 1: return InlayType.ICON;
    case 2: return InlayType.COLOR;
    default: return InlayType.TEXT;
  }
}

export enum SeparatorStyle {
  SINGLE = 0,
  DOUBLE = 1,
}

export function separatorStyleFromValue(value: number): SeparatorStyle {
  switch (value) {
    case 0: return SeparatorStyle.SINGLE;
    case 1: return SeparatorStyle.DOUBLE;
    default: return SeparatorStyle.SINGLE;
  }
}

export enum SpanLayer {
  SYNTAX = 0,
  SEMANTIC = 1,
}

export function spanLayerFromValue(value: number): SpanLayer {
  switch (value) {
    case 0: return SpanLayer.SYNTAX;
    case 1: return SpanLayer.SEMANTIC;
    default: return SpanLayer.SYNTAX;
  }
}

export class BracketGuide {
  parent: TextPosition;
  end: TextPosition;
  children: TextPosition[];
}

export class CodeLensItem {
  column: number = 0;
  commandId: number = 0;
  text: string;
}

export class Diagnostic {
  column: number = 0;
  length: number = 0;
  severity: DiagnosticSeverity = DiagnosticSeverity.DIAG_ERROR;
}

export class FlowGuide {
  start: TextPosition;
  end: TextPosition;
}

export class FoldRegion {
  startLine: number = 0;
  endLine: number = 0;
  collapsed: boolean = false;
}

export class GutterIcon {
  iconId: number = 0;
}

export class IndentGuide {
  start: TextPosition;
  end: TextPosition;
}

export class InlayHint {
  type: InlayType = InlayType.TEXT;
  column: number = 0;
  intValue: number = 0;
  text: string;
}

export class LinkSpan {
  column: number = 0;
  length: number = 0;
  target: string;
}

export class PhantomText {
  column: number = 0;
  text: string;
}

export class SeparatorGuide {
  line: number;
  style: SeparatorStyle;
  count: number;
  textEndColumn: number;
}

export interface StyleSpan {
  column: number;
  length: number;
  styleId: number;
}

export interface TextStyle {
  color: number;
  backgroundColor: number;
  fontStyle: number;
}
