import { MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import {
  CodeLensItem,
  Diagnostic,
  EditorTheme,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  InlayType,
  SeparatorGuide,
  SeparatorStyle,
  StyleSpan
} from '@qiplat/sweeteditor';
import { sweetline } from '@qiplat/sweetline';
import { DEMO_STYLE_COLOR } from '../demo/DemoSamples';
import {
  DecorationWorkerAnalyzeMessage,
  DecorationWorkerRequestMessage,
  DecorationWorkerResultMessage,
  LineDecorationItems
} from '../demo/DemoDecorationWorkerTypes';

const DEFAULT_ANALYSIS_FILE_NAME: string = 'sample.cpp';
const MAX_DYNAMIC_DIAGNOSTICS: number = 8;
const CODELENS_RUN: number = 1;
const CODELENS_DEBUG: number = 2;
const ICON_TYPE: number = 1;
const ICON_AT: number = 2;

class TokenRangeInfo {
  readonly line: number;
  readonly startColumn: number;
  readonly endColumn: number;

  constructor(line: number, startColumn: number, endColumn: number) {
    this.line = line;
    this.startColumn = startColumn;
    this.endColumn = endColumn;
  }

  length(): number {
    return this.endColumn - this.startColumn;
  }
}

class DemoDecorationWorker {
  private highlightEngine: sweetline.HighlightEngine | null = null;
  private documentAnalyzer: sweetline.DocumentAnalyzer | null = null;
  private analyzedFileName: string = DEFAULT_ANALYSIS_FILE_NAME;
  private sourceLines: string[] = [];

  handleMessage(message: DecorationWorkerRequestMessage): void {
    if (message.type === 'init') {
      this.initializeEngine(message.syntaxJsons);
      return;
    }
    this.analyze(message);
  }

  private initializeEngine(syntaxJsons: string[]): void {
    const engine = new sweetline.HighlightEngine(new sweetline.HighlightConfig(false, false, 4));
    this.registerDemoStyleMap(engine);
    for (let index = 0; index < syntaxJsons.length; index++) {
      const compiled = engine.compileSyntaxFromJson(syntaxJsons[index]);
      if (compiled === null) {
        throw new Error(`Failed to compile syntax index ${index}`);
      }
    }
    this.highlightEngine = engine;
    this.documentAnalyzer = null;
    this.analyzedFileName = DEFAULT_ANALYSIS_FILE_NAME;
    this.sourceLines = [];
  }

  private analyze(message: DecorationWorkerAnalyzeMessage): void {
    const startedAt = Date.now();
    try {
      const result = this.buildDecorationResult(message, startedAt);
      worker.workerPort.postMessage(result);
    } catch (error) {
      try {
        worker.workerPort.postMessage(this.buildEmptyResultMessage(message.requestId, Date.now() - startedAt, `${error}`));
      } catch (_postError) {
      }
    }
  }

  private buildDecorationResult(message: DecorationWorkerAnalyzeMessage,
    startedAt: number): DecorationWorkerResultMessage {
    if (this.highlightEngine === null) {
      return this.buildEmptyResultMessage(message.requestId, Date.now() - startedAt, null);
    }

    const syntaxSpans = new Map<number, StyleSpan[]>();
    const inlayHints = new Map<number, InlayHint[]>();
    const gutterIcons = new Map<number, GutterIcon[]>();
    const codeLensItems = new Map<number, CodeLensItem[]>();
    const diagnostics = new Map<number, Diagnostic[]>();
    const indentGuides: IndentGuide[] = [];
    const foldRegions: FoldRegion[] = [];
    const separatorGuides: SeparatorGuide[] = [];
    const seenColorHints = new Set<string>();
    const seenDiagnostics = new Set<string>();
    const diagnosticCount: number[] = [0];
    let firstKeywordRange: TokenRangeInfo | null = null;

    const fileChanged = message.fileName !== this.analyzedFileName;
    if (message.text !== null || this.documentAnalyzer === null || fileChanged) {
      this.loadDocument(message.fileName, message.text === null ? '' : message.text);
    }
    if (this.documentAnalyzer === null) {
      return this.buildEmptyResultMessage(message.requestId, Date.now() - startedAt, null);
    }

    const visibleRange = new sweetline.LineRange(
      Math.max(0, message.visibleStartLine),
      Math.max(0, message.visibleEndLine - Math.max(0, message.visibleStartLine) + 1)
    );
    const highlightSlice = this.documentAnalyzer.analyzeLineRange(visibleRange);
    if (highlightSlice === null || highlightSlice.lines.length === 0) {
      return this.buildEmptyResultMessage(message.requestId, Date.now() - startedAt, null);
    }

    for (let line = 0; line < highlightSlice.lines.length; line++) {
      const lineHighlight = highlightSlice.lines[line];
      for (let spanIndex = 0; spanIndex < lineHighlight.spans.length; spanIndex++) {
        const token = lineHighlight.spans[spanIndex];
        this.appendStyleSpan(syntaxSpans, token);
        this.appendColorInlayHint(inlayHints, seenColorHints, token);
        this.appendTextInlayHint(inlayHints, token);
        this.appendSeparator(separatorGuides, token);
        this.appendGutterIcons(gutterIcons, token);
        this.appendCodeLens(codeLensItems, token);
        firstKeywordRange = this.appendDynamicDemoDecorations(
          diagnostics,
          seenDiagnostics,
          diagnosticCount,
          firstKeywordRange,
          token
        );
      }
    }

    this.appendDiagnosticFallbackIfNeeded(diagnostics, seenDiagnostics, diagnosticCount, firstKeywordRange);

    if (message.totalLineCount < 2048) {
      const guideResult = this.documentAnalyzer.analyzeIndentGuides();
      const seenFolds = new Set<string>();
      for (let index = 0; index < guideResult.guideLines.length; index++) {
        const guide = guideResult.guideLines[index];
        if (guide.endLine < guide.startLine) {
          continue;
        }
        const column = Math.max(guide.column, 0);
        indentGuides.push({
          start: { line: guide.startLine, column },
          end: { line: guide.endLine, column }
        });

        if (guide.endLine <= guide.startLine) {
          continue;
        }
        const key = `${guide.startLine}:${guide.endLine}`;
        if (seenFolds.has(key)) {
          continue;
        }
        seenFolds.add(key);
        foldRegions.push({
          startLine: guide.startLine,
          endLine: guide.endLine
        });
      }
    }

    return {
      type: 'result',
      requestId: message.requestId,
      syntaxSpans: this.serializeMap(syntaxSpans),
      inlayHints: this.serializeMap(inlayHints),
      diagnostics: this.serializeMap(diagnostics),
      gutterIcons: this.serializeMap(gutterIcons),
      codeLensItems: this.serializeMap(codeLensItems),
      indentGuides,
      foldRegions,
      separatorGuides,
      analysisMs: Date.now() - startedAt,
      error: null
    };
  }

  private buildEmptyResultMessage(requestId: number, elapsedMs: number, error: string | null): DecorationWorkerResultMessage {
    return {
      type: 'result',
      requestId,
      syntaxSpans: [],
      inlayHints: [],
      diagnostics: [],
      gutterIcons: [],
      codeLensItems: [],
      indentGuides: [],
      foldRegions: [],
      separatorGuides: [],
      analysisMs: elapsedMs,
      error
    };
  }

  private loadDocument(fileName: string, text: string): void {
    this.documentAnalyzer = null;
    this.analyzedFileName = fileName;
    this.sourceLines = splitLines(text);
    const analyzer = this.highlightEngine!.loadDocument(
      new sweetline.Document(this.buildAnalysisUri(fileName), text)
    );
    if (analyzer !== null) {
      this.documentAnalyzer = analyzer;
    }
  }

  private appendDynamicDemoDecorations(diagnostics: Map<number, Diagnostic[]>,
    seenDiagnostics: Set<string>,
    diagnosticCount: number[],
    firstKeywordRange: TokenRangeInfo | null,
    token: sweetline.TokenSpan): TokenRangeInfo | null {
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return firstKeywordRange;
    }
    const literal = this.getTokenLiteral(range);
    if (literal.length === 0) {
      return firstKeywordRange;
    }

    if (token.styleId === EditorTheme.STYLE_KEYWORD) {
      return firstKeywordRange === null ? range : firstKeywordRange;
    }

    if (token.styleId === EditorTheme.STYLE_COMMENT) {
      const upper = literal.toUpperCase();
      const fixmeIndex = upper.indexOf('FIXME');
      if (fixmeIndex >= 0) {
        this.appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount, range.line, range.startColumn + fixmeIndex, 5, 0);
      }
      const todoIndex = upper.indexOf('TODO');
      if (todoIndex >= 0) {
        this.appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount, range.line, range.startColumn + todoIndex, 4, 1);
      }
      return firstKeywordRange;
    }

    if (token.styleId === DEMO_STYLE_COLOR) {
      return firstKeywordRange;
    }

    if (token.styleId === EditorTheme.STYLE_ANNOTATION) {
      this.appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount, range.line, range.startColumn, range.length(), 3);
    }
    return firstKeywordRange;
  }

  private appendStyleSpan(syntaxSpans: Map<number, StyleSpan[]>, token: sweetline.TokenSpan): void {
    if (token.styleId <= 0) {
      return;
    }
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    let lineSpans = syntaxSpans.get(range.line);
    if (lineSpans === undefined) {
      lineSpans = [];
      syntaxSpans.set(range.line, lineSpans);
    }
    lineSpans.push({
      column: range.startColumn,
      length: range.length(),
      styleId: token.styleId
    });
  }

  private appendColorInlayHint(inlayHints: Map<number, InlayHint[]>,
    seenHints: Set<string>,
    token: sweetline.TokenSpan): void {
    if (token.styleId !== DEMO_STYLE_COLOR) {
      return;
    }
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const literal = this.getTokenLiteral(range);
    const color = this.parseColorLiteral(literal);
    if (color === null) {
      return;
    }
    const key = `${range.line}:${range.startColumn}:${literal}`;
    if (seenHints.has(key)) {
      return;
    }
    seenHints.add(key);
    let lineHints = inlayHints.get(range.line);
    if (lineHints === undefined) {
      lineHints = [];
      inlayHints.set(range.line, lineHints);
    }
    lineHints.push({
      type: InlayType.Color,
      column: range.startColumn,
      text: null,
      intValue: color
    });
  }

  private appendTextInlayHint(inlayHints: Map<number, InlayHint[]>, token: sweetline.TokenSpan): void {
    if (token.styleId !== EditorTheme.STYLE_KEYWORD) {
      return;
    }
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const literal = this.getTokenLiteral(range);
    let hintText = '';
    if (literal === 'const') {
      hintText = 'immutable';
    } else if (literal === 'return') {
      hintText = 'value: ';
    } else if (literal === 'case') {
      hintText = 'condition: ';
    }
    if (hintText.length === 0) {
      return;
    }
    let lineHints = inlayHints.get(range.line);
    if (lineHints === undefined) {
      lineHints = [];
      inlayHints.set(range.line, lineHints);
    }
    lineHints.push({
      type: InlayType.Text,
      column: range.endColumn + 1,
      text: hintText,
      intValue: 0
    });
  }

  private appendSeparator(separatorGuides: SeparatorGuide[], token: sweetline.TokenSpan): void {
    if (token.styleId !== EditorTheme.STYLE_COMMENT) {
      return;
    }
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const lineText = this.getLineText(range.line);
    if (range.endColumn > lineText.length) {
      return;
    }
    let count = -1;
    let isDouble = false;
    for (let index = 0; index < lineText.length; index++) {
      const ch = lineText[index];
      if (count < 0) {
        if (ch === '/') {
          continue;
        }
        if (ch === '=') {
          count = 1;
          isDouble = true;
        } else if (ch === '-') {
          count = 1;
          isDouble = false;
        }
      } else if (isDouble && ch === '=') {
        count++;
      } else if (!isDouble && ch === '-') {
        count++;
      } else {
        break;
      }
    }
    if (count > 0) {
      separatorGuides.push({
        line: range.line,
        style: isDouble ? SeparatorStyle.DOUBLE : SeparatorStyle.SINGLE,
        count,
        textEndColumn: lineText.length
      });
    }
  }

  private appendGutterIcons(gutterIcons: Map<number, GutterIcon[]>, token: sweetline.TokenSpan): void {
    if (token.styleId !== EditorTheme.STYLE_KEYWORD && token.styleId !== EditorTheme.STYLE_ANNOTATION) {
      return;
    }
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    let iconId = 0;
    if (token.styleId === EditorTheme.STYLE_KEYWORD) {
      const literal = this.getTokenLiteral(range);
      if (literal === 'class' || literal === 'struct') {
        iconId = ICON_TYPE;
      }
    } else {
      iconId = ICON_AT;
    }
    if (iconId === 0) {
      return;
    }
    let lineIcons = gutterIcons.get(range.line);
    if (lineIcons === undefined) {
      lineIcons = [];
      gutterIcons.set(range.line, lineIcons);
    }
    lineIcons.push({ iconId });
  }

  private appendCodeLens(codeLensItems: Map<number, CodeLensItem[]>, token: sweetline.TokenSpan): void {
    if (codeLensItems.size > 0) {
      return;
    }
    if (token.styleId !== EditorTheme.STYLE_KEYWORD) {
      return;
    }
    const range = this.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const literal = this.getTokenLiteral(range);
    if (literal === 'class' || literal === 'struct') {
      codeLensItems.set(range.line, [
        { column: range.startColumn, text: '\u25B6 Run', commandId: CODELENS_RUN },
        { column: range.startColumn, text: '\u25CE Debug', commandId: CODELENS_DEBUG }
      ]);
    }
  }

  private appendDiagnostic(diagnostics: Map<number, Diagnostic[]>,
    seenDiagnostics: Set<string>,
    diagnosticCount: number[],
    line: number,
    column: number,
    length: number,
    severity: number): void {
    if (diagnosticCount[0] >= MAX_DYNAMIC_DIAGNOSTICS || line < 0 || column < 0 || length <= 0) {
      return;
    }
    const key = `${line}:${column}:${length}:${severity}`;
    if (seenDiagnostics.has(key)) {
      return;
    }
    seenDiagnostics.add(key);
    let lineItems = diagnostics.get(line);
    if (lineItems === undefined) {
      lineItems = [];
      diagnostics.set(line, lineItems);
    }
    lineItems.push({
      column,
      length,
      severity
    });
    diagnosticCount[0]++;
  }

  private appendDiagnosticFallbackIfNeeded(diagnostics: Map<number, Diagnostic[]>,
    seenDiagnostics: Set<string>,
    diagnosticCount: number[],
    firstKeywordRange: TokenRangeInfo | null): void {
    if (diagnosticCount[0] > 0 || firstKeywordRange === null) {
      return;
    }
    this.appendDiagnostic(
      diagnostics,
      seenDiagnostics,
      diagnosticCount,
      firstKeywordRange.line,
      firstKeywordRange.startColumn,
      firstKeywordRange.length(),
      3
    );
  }

  private extractSingleLineTokenRange(token: sweetline.TokenSpan | null): TokenRangeInfo | null {
    if (token === null || token.range === null || token.range.start === null || token.range.end === null) {
      return null;
    }
    const startLine = token.range.start.line;
    const endLine = token.range.end.line;
    const startColumn = token.range.start.column;
    const endColumn = token.range.end.column;
    if (startLine < 0 || startLine !== endLine || startColumn < 0 || endColumn <= startColumn) {
      return null;
    }
    return new TokenRangeInfo(startLine, startColumn, endColumn);
  }

  private getTokenLiteral(range: TokenRangeInfo): string {
    const lineText = this.getLineText(range.line);
    if (range.endColumn > lineText.length) {
      return '';
    }
    return lineText.slice(range.startColumn, range.endColumn);
  }

  private getLineText(line: number): string {
    if (line < 0 || line >= this.sourceLines.length) {
      return '';
    }
    return this.sourceLines[line];
  }

  private parseColorLiteral(literal: string): number | null {
    if (literal.length > 2 && literal[0] === '0' && (literal[1] === 'x' || literal[1] === 'X')) {
      const hex = literal.slice(2).replace(/[_uUlL]/g, '');
      const parsed = Number.parseInt(hex, 16);
      if (!Number.isNaN(parsed)) {
        return parsed;
      }
    }
    return null;
  }

  private buildAnalysisUri(fileName: string): string {
    return `file:///${fileName}`;
  }

  private registerDemoStyleMap(engine: sweetline.HighlightEngine): void {
    engine.registerStyleName('keyword', EditorTheme.STYLE_KEYWORD);
    engine.registerStyleName('type', EditorTheme.STYLE_TYPE);
    engine.registerStyleName('string', EditorTheme.STYLE_STRING);
    engine.registerStyleName('comment', EditorTheme.STYLE_COMMENT);
    engine.registerStyleName('preprocessor', EditorTheme.STYLE_PREPROCESSOR);
    engine.registerStyleName('macro', EditorTheme.STYLE_PREPROCESSOR);
    engine.registerStyleName('method', EditorTheme.STYLE_FUNCTION);
    engine.registerStyleName('function', EditorTheme.STYLE_FUNCTION);
    engine.registerStyleName('variable', EditorTheme.STYLE_VARIABLE);
    engine.registerStyleName('field', EditorTheme.STYLE_VARIABLE);
    engine.registerStyleName('number', EditorTheme.STYLE_NUMBER);
    engine.registerStyleName('class', EditorTheme.STYLE_CLASS);
    engine.registerStyleName('builtin', EditorTheme.STYLE_BUILTIN);
    engine.registerStyleName('annotation', EditorTheme.STYLE_ANNOTATION);
    engine.registerStyleName('color', DEMO_STYLE_COLOR);
  }

  private serializeMap<T>(source: Map<number, T[]>): LineDecorationItems<T>[] {
    const out: LineDecorationItems<T>[] = [];
    source.forEach((items, line) => {
      out.push({ line, items });
    });
    return out;
  }
}

function splitLines(text: string): string[] {
  return text.split(/\r\n|\n|\r/);
}

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;
const decorationWorker = new DemoDecorationWorker();
workerPort.onmessage = (event: MessageEvents): void => {
  decorationWorker.handleMessage(event.data as DecorationWorkerRequestMessage);
};
