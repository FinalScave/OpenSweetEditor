import {
  CodeLensItem,
  Diagnostic,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  SeparatorGuide,
  StyleSpan
} from '@qiplat/sweeteditor';

export interface LineDecorationItems<T> {
  line: number;
  items: T[];
}

export interface DecorationWorkerInitMessage {
  type: 'init';
  syntaxJsons: string[];
}

export interface DecorationWorkerAnalyzeMessage {
  type: 'analyze';
  requestId: number;
  fileName: string;
  totalLineCount: number;
  visibleStartLine: number;
  visibleEndLine: number;
  text: string | null;
}

export interface DecorationWorkerResultMessage {
  type: 'result';
  requestId: number;
  syntaxSpans: LineDecorationItems<StyleSpan>[];
  inlayHints: LineDecorationItems<InlayHint>[];
  diagnostics: LineDecorationItems<Diagnostic>[];
  gutterIcons: LineDecorationItems<GutterIcon>[];
  codeLensItems: LineDecorationItems<CodeLensItem>[];
  indentGuides: IndentGuide[];
  foldRegions: FoldRegion[];
  separatorGuides: SeparatorGuide[];
  analysisMs: number;
  error: string | null;
}

export type DecorationWorkerRequestMessage = DecorationWorkerInitMessage | DecorationWorkerAnalyzeMessage;
