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
    default: throw new Error('Unknown DiagnosticSeverity value: ' + value);
  }
}

export enum DocumentHighlightKind {
  TEXT = 0,
  READ = 1,
  WRITE = 2,
}

export function documentHighlightKindFromValue(value: number): DocumentHighlightKind {
  switch (value) {
    case 0: return DocumentHighlightKind.TEXT;
    case 1: return DocumentHighlightKind.READ;
    case 2: return DocumentHighlightKind.WRITE;
    default: throw new Error('Unknown DocumentHighlightKind value: ' + value);
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
    default: throw new Error('Unknown InlayType value: ' + value);
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
    default: throw new Error('Unknown SeparatorStyle value: ' + value);
  }
}

export enum SpanLayer {
  SYNTAX = 0,
  SEMANTIC = 1,
  OVERLAY = 2,
}

export function spanLayerFromValue(value: number): SpanLayer {
  switch (value) {
    case 0: return SpanLayer.SYNTAX;
    case 1: return SpanLayer.SEMANTIC;
    case 2: return SpanLayer.OVERLAY;
    default: throw new Error('Unknown SpanLayer value: ' + value);
  }
}

export class BracketGuide {
  parent: TextPosition = { line: 0, column: 0 };
  end: TextPosition = { line: 0, column: 0 };
  children: TextPosition[] = [];
}

export class CodeLensItem {
  column: number = 0;
  commandId: number = 0;
  text: string = '';
}

export class Diagnostic {
  column: number = 0;
  length: number = 0;
  severity: DiagnosticSeverity = DiagnosticSeverity.DIAG_ERROR;
}

export class DocumentHighlight {
  column: number = 0;
  length: number = 0;
  kind: DocumentHighlightKind = DocumentHighlightKind.TEXT;
}

export class FlowGuide {
  start: TextPosition = { line: 0, column: 0 };
  end: TextPosition = { line: 0, column: 0 };
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
  start: TextPosition = { line: 0, column: 0 };
  end: TextPosition = { line: 0, column: 0 };
}

export class InlayHint {
  type: InlayType = InlayType.TEXT;
  column: number = 0;
  intValue: number = 0;
  text: string = '';
}

export class LinkSpan {
  column: number = 0;
  length: number = 0;
  target: string = '';
}

export class PhantomText {
  column: number = 0;
  text: string = '';
}

export class SeparatorGuide {
  line: number = 0;
  style: SeparatorStyle = SeparatorStyle.SINGLE;
  count: number = 0;
  textEndColumn: number = 0;
}

export interface StyleSpan {
  column: number;
  length: number;
  styleId: number;
}

export class TextStyle {
  static readonly NORMAL: number = 0;
  static readonly BOLD: number = 1;
  static readonly ITALIC: number = 2;
  static readonly STRIKETHROUGH: number = 4;

  color: number = 0;
  backgroundColor: number = 0;
  fontStyle: number = 0;
}
