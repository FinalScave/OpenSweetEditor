import { resourceManager } from '@kit.LocalizationKit';
import { util } from '@kit.ArkTS';
import {
  ApplyMode,
  DecorationContext,
  DecorationProvider,
  DecorationReceiver,
  DecorationResult,
  DecorationResultBuilder,
  DecorationType,
  Diagnostic,
  Document as EditorDocument,
  EditorTheme,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  InlayType,
  CodeLensItem,
  SeparatorStyle,
  SeparatorGuide,
  StyleSpan,
  TextRange
} from '@qiplat/sweeteditor';
import { sweetline } from '@qiplat/sweetline';
import { DEMO_RAWFILE_SYNTAX_ROOT, DEMO_STYLE_COLOR } from './DemoSamples';
import { DemoFileMetadata } from './DemoTypes';

const DEFAULT_ANALYSIS_FILE_NAME: string = 'sample.cpp';
const MAX_DYNAMIC_DIAGNOSTICS: number = 8;
const CODELENS_RUN: number = 1;
const CODELENS_DEBUG: number = 2;

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

export class DemoDecorationProvider implements DecorationProvider {
  static readonly ICON_TYPE: number = 1;
  static readonly ICON_AT: number = 2;
  private static readonly textDecoder: util.TextDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
  private static highlightEngine: sweetline.HighlightEngine | null = null;
  private static initPromise: Promise<boolean> | null = null;
  private readonly documentProvider: () => EditorDocument | null;
  private documentAnalyzer: sweetline.DocumentAnalyzer | null = null;
  private cacheHighlight: sweetline.DocumentHighlightSlice | null = null;
  private analyzedFileName: string = DEFAULT_ANALYSIS_FILE_NAME;

  constructor(documentProvider: () => EditorDocument | null) {
    this.documentProvider = documentProvider;
  }

  static async ensureSweetLineReady(manager: resourceManager.ResourceManager | null): Promise<boolean> {
    if (DemoDecorationProvider.highlightEngine !== null) {
      return true;
    }
    if (DemoDecorationProvider.initPromise !== null) {
      return DemoDecorationProvider.initPromise;
    }
    if (manager === null) {
      return false;
    }
    const initTask = DemoDecorationProvider.createHighlightEngine(manager);
    DemoDecorationProvider.initPromise = initTask;
    try {
      return await initTask;
    } finally {
      DemoDecorationProvider.initPromise = null;
    }
  }

  getCapabilities(): Set<DecorationType> {
    return new Set<DecorationType>([
      DecorationType.SYNTAX_HIGHLIGHT,
      DecorationType.INDENT_GUIDE,
      DecorationType.FOLD_REGION,
      DecorationType.INLAY_HINT,
      DecorationType.DIAGNOSTIC,
      DecorationType.SEPARATOR_GUIDE,
      DecorationType.GUTTER_ICON,
      DecorationType.CODELENS
    ]);
  }

  provideDecorations(context: DecorationContext, receiver: DecorationReceiver): void {
    const diagnostics = new Map<number, Diagnostic[]>();
    receiver.accept(this.buildSweetLineDecorationResult(context, diagnostics));

    setTimeout(() => {
      if (receiver.isCancelled()) {
        return;
      }
      receiver.accept(new DecorationResultBuilder()
        .diagnostics(diagnostics, ApplyMode.REPLACE_ALL)
        .build());
    }, 500);
  }

  private buildSweetLineDecorationResult(context: DecorationContext,
    dynamicDiagnostics: Map<number, Diagnostic[]>): DecorationResult {
    if (DemoDecorationProvider.highlightEngine === null) {
      return this.buildEmptyResult();
    }

    const syntaxSpans = new Map<number, StyleSpan[]>();
    const inlayHints = new Map<number, InlayHint[]>();
    const gutterIcons = new Map<number, GutterIcon[]>();
    const codeLensItems = new Map<number, CodeLensItem[]>();
    const indentGuides: IndentGuide[] = [];
    const foldRegions: FoldRegion[] = [];
    const separatorGuides: SeparatorGuide[] = [];
    const seenColorHints = new Set<string>();
    const seenDiagnostics = new Set<string>();
    const diagnosticCount: number[] = [0];
    let firstKeywordRange: TokenRangeInfo | null = null;

    const editorDocument = this.documentProvider();
    if (editorDocument === null) {
      return this.buildEmptyResult();
    }

    const currentFileName = DemoDecorationProvider.resolveCurrentFileName(context);
    const text = editorDocument.getText();
    const fileChanged = currentFileName !== this.analyzedFileName;
    const visibleRange = new sweetline.LineRange(
      Math.max(0, context.visibleLineRange.start),
      Math.max(0, context.visibleLineRange.end - Math.max(0, context.visibleLineRange.start) + 1)
    );

    if (this.cacheHighlight === null || this.documentAnalyzer === null || fileChanged) {
      this.documentAnalyzer = null;
      this.cacheHighlight = null;
      const analyzer = DemoDecorationProvider.highlightEngine.loadDocument(
        new sweetline.Document(DemoDecorationProvider.buildAnalysisUri(currentFileName), text)
      );
      if (analyzer === null) {
        return this.buildEmptyResult();
      }
      this.documentAnalyzer = analyzer;
      this.analyzedFileName = currentFileName;
    }

    if (this.documentAnalyzer !== null && context.textChanges.length > 0) {
      for (let index = 0; index < context.textChanges.length; index++) {
        const change = context.textChanges[index];
        this.cacheHighlight = this.documentAnalyzer.analyzeIncrementalInLineRange(
          DemoDecorationProvider.convertAsSLTextRange(change.range),
          change.newText,
          visibleRange
        );
      }
    } else if (this.documentAnalyzer !== null) {
      this.cacheHighlight = this.documentAnalyzer.analyzeLineRange(visibleRange);
    }

    if (this.cacheHighlight === null || this.cacheHighlight.lines.length === 0) {
      return this.buildEmptyResult();
    }

    for (let line = 0; line < this.cacheHighlight.lines.length; line++) {
      const lineHighlight = this.cacheHighlight.lines[line];
      for (let spanIndex = 0; spanIndex < lineHighlight.spans.length; spanIndex++) {
        const token = lineHighlight.spans[spanIndex];
        this.appendStyleSpan(syntaxSpans, token);
        this.appendColorInlayHint(inlayHints, seenColorHints, editorDocument, token);
        this.appendTextInlayHint(inlayHints, editorDocument, token);
        this.appendSeparator(separatorGuides, editorDocument, token);
        this.appendGutterIcons(gutterIcons, editorDocument, token);
        this.appendCodeLens(codeLensItems, editorDocument, token);
        firstKeywordRange = this.appendDynamicDemoDecorations(
          dynamicDiagnostics,
          seenDiagnostics,
          diagnosticCount,
          firstKeywordRange,
          editorDocument,
          token
        );
      }
    }

    DemoDecorationProvider.appendDiagnosticFallbackIfNeeded(
      dynamicDiagnostics,
      seenDiagnostics,
      diagnosticCount,
      firstKeywordRange
    );

    if (context.totalLineCount < 2048 && this.documentAnalyzer !== null) {
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

    return new DecorationResultBuilder()
      .syntaxSpans(syntaxSpans, ApplyMode.MERGE)
      .inlayHints(inlayHints, ApplyMode.REPLACE_RANGE)
      .indentGuides(indentGuides, ApplyMode.REPLACE_ALL)
      .foldRegions(foldRegions, ApplyMode.REPLACE_ALL)
      .separatorGuides(separatorGuides, ApplyMode.REPLACE_ALL)
      .gutterIcons(gutterIcons, ApplyMode.REPLACE_ALL)
      .codeLensItems(codeLensItems, ApplyMode.REPLACE_ALL)
      .build();
  }

  private buildEmptyResult(): DecorationResult {
    return new DecorationResultBuilder()
      .syntaxSpans(new Map<number, StyleSpan[]>(), ApplyMode.MERGE)
      .inlayHints(new Map<number, InlayHint[]>(), ApplyMode.REPLACE_RANGE)
      .indentGuides([], ApplyMode.REPLACE_ALL)
      .foldRegions([], ApplyMode.REPLACE_ALL)
      .separatorGuides([], ApplyMode.REPLACE_ALL)
      .gutterIcons(new Map<number, GutterIcon[]>(), ApplyMode.REPLACE_ALL)
      .build();
  }

  private appendDynamicDemoDecorations(diagnostics: Map<number, Diagnostic[]>,
    seenDiagnostics: Set<string>,
    diagnosticCount: number[],
    firstKeywordRange: TokenRangeInfo | null,
    editorDocument: EditorDocument,
    token: sweetline.TokenSpan): TokenRangeInfo | null {
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
    if (range === null) {
      return firstKeywordRange;
    }
    const literal = DemoDecorationProvider.getTokenLiteral(editorDocument, range);
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
        DemoDecorationProvider.appendDiagnostic(
          diagnostics,
          seenDiagnostics,
          diagnosticCount,
          range.line,
          range.startColumn + fixmeIndex,
          5,
          0
        );
      }
      const todoIndex = upper.indexOf('TODO');
      if (todoIndex >= 0) {
        DemoDecorationProvider.appendDiagnostic(
          diagnostics,
          seenDiagnostics,
          diagnosticCount,
          range.line,
          range.startColumn + todoIndex,
          4,
          1
        );
      }
      return firstKeywordRange;
    }

    if (token.styleId === DEMO_STYLE_COLOR) {
      return firstKeywordRange;
    }

    if (token.styleId === EditorTheme.STYLE_ANNOTATION) {
      DemoDecorationProvider.appendDiagnostic(
        diagnostics,
        seenDiagnostics,
        diagnosticCount,
        range.line,
        range.startColumn,
        range.length(),
        3
      );
    }
    return firstKeywordRange;
  }

  private appendStyleSpan(syntaxSpans: Map<number, StyleSpan[]>, token: sweetline.TokenSpan): void {
    if (token.styleId <= 0) {
      return;
    }
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
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
    editorDocument: EditorDocument,
    token: sweetline.TokenSpan): void {
    if (token.styleId !== DEMO_STYLE_COLOR) {
      return;
    }
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const literal = DemoDecorationProvider.getTokenLiteral(editorDocument, range);
    const color = DemoDecorationProvider.parseColorLiteral(literal);
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

  private appendTextInlayHint(inlayHints: Map<number, InlayHint[]>,
    editorDocument: EditorDocument,
    token: sweetline.TokenSpan): void {
    if (token.styleId !== EditorTheme.STYLE_KEYWORD) {
      return;
    }
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const literal = DemoDecorationProvider.getTokenLiteral(editorDocument, range);
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

  private appendSeparator(separatorGuides: SeparatorGuide[],
    editorDocument: EditorDocument,
    token: sweetline.TokenSpan): void {
    if (token.styleId !== EditorTheme.STYLE_COMMENT) {
      return;
    }
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const lineText = editorDocument.getLineText(range.line);
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

  private appendGutterIcons(gutterIcons: Map<number, GutterIcon[]>,
    editorDocument: EditorDocument,
    token: sweetline.TokenSpan): void {
    if (token.styleId !== EditorTheme.STYLE_KEYWORD && token.styleId !== EditorTheme.STYLE_ANNOTATION) {
      return;
    }
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    let iconId = 0;
    if (token.styleId === EditorTheme.STYLE_KEYWORD) {
      const literal = DemoDecorationProvider.getTokenLiteral(editorDocument, range);
      if (literal === 'class' || literal === 'struct') {
        iconId = DemoDecorationProvider.ICON_TYPE;
      }
    } else {
      iconId = DemoDecorationProvider.ICON_AT;
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

  private appendCodeLens(codeLensItems: Map<number, CodeLensItem[]>,
    editorDocument: EditorDocument,
    token: sweetline.TokenSpan): void {
    if (codeLensItems.size > 0) {
      return;
    }
    if (token.styleId !== EditorTheme.STYLE_KEYWORD) {
      return;
    }
    const range = DemoDecorationProvider.extractSingleLineTokenRange(token);
    if (range === null) {
      return;
    }
    const literal = DemoDecorationProvider.getTokenLiteral(editorDocument, range);
    if (literal === 'class' || literal === 'struct') {
      codeLensItems.set(range.line, [
        { column: range.startColumn, text: '▶ Run', commandId: CODELENS_RUN },
        { column: range.startColumn, text: '◎ Debug', commandId: CODELENS_DEBUG }
      ]);
    }
  }

  private static appendDiagnostic(diagnostics: Map<number, Diagnostic[]>,
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

  private static appendDiagnosticFallbackIfNeeded(diagnostics: Map<number, Diagnostic[]>,
    seenDiagnostics: Set<string>,
    diagnosticCount: number[],
    firstKeywordRange: TokenRangeInfo | null): void {
    if (diagnosticCount[0] > 0 || firstKeywordRange === null) {
      return;
    }
    DemoDecorationProvider.appendDiagnostic(
      diagnostics,
      seenDiagnostics,
      diagnosticCount,
      firstKeywordRange.line,
      firstKeywordRange.startColumn,
      firstKeywordRange.length(),
      3
    );
  }

  private static buildAnalysisUri(fileName: string): string {
    return `file:///${fileName}`;
  }

  private static resolveCurrentFileName(context: DecorationContext): string {
    if (context.editorMetadata instanceof DemoFileMetadata && context.editorMetadata.fileName.length > 0) {
      return context.editorMetadata.fileName;
    }
    return DEFAULT_ANALYSIS_FILE_NAME;
  }

  private static parseColorLiteral(literal: string): number | null {
    if (literal.length > 2 && literal[0] === '0' && (literal[1] === 'x' || literal[1] === 'X')) {
      const hex = literal.slice(2).replace(/[_uUlL]/g, '');
      const parsed = Number.parseInt(hex, 16);
      if (!Number.isNaN(parsed)) {
        return parsed;
      }
    }
    return null;
  }

  private static extractSingleLineTokenRange(token: sweetline.TokenSpan | null): TokenRangeInfo | null {
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

  private static getTokenLiteral(editorDocument: EditorDocument, range: TokenRangeInfo): string {
    const lineText = editorDocument.getLineText(range.line);
    if (range.endColumn > lineText.length) {
      return '';
    }
    return lineText.slice(range.startColumn, range.endColumn);
  }

  private static convertAsSLTextRange(range: TextRange): sweetline.TextRange {
    return new sweetline.TextRange(
      new sweetline.TextPosition(range.start.line, range.start.column),
      new sweetline.TextPosition(range.end.line, range.end.column)
    );
  }

  private static async createHighlightEngine(manager: resourceManager.ResourceManager): Promise<boolean> {
    if (DemoDecorationProvider.highlightEngine !== null) {
      return true;
    }
    const engine = new sweetline.HighlightEngine(new sweetline.HighlightConfig(false, false, 4));
    DemoDecorationProvider.registerDemoStyleMap(engine);

    let syntaxFiles: string[] = [];
    try {
      syntaxFiles = await manager.getRawFileList(DEMO_RAWFILE_SYNTAX_ROOT);
    } catch (error) {
      throw new Error(`Failed to list syntax rawfiles under ${DEMO_RAWFILE_SYNTAX_ROOT}: ${String(error)}`);
    }
    const sortedSyntaxFiles = [...syntaxFiles].sort((left: string, right: string) => left.localeCompare(right));
    if (sortedSyntaxFiles.length === 0) {
      throw new Error(`No syntax files found under rawfile/${DEMO_RAWFILE_SYNTAX_ROOT}`);
    }

    for (let index = 0; index < sortedSyntaxFiles.length; index++) {
      const assetName = sortedSyntaxFiles[index];
      let syntaxContent: Uint8Array;
      try {
        syntaxContent = await manager.getRawFileContent(`${DEMO_RAWFILE_SYNTAX_ROOT}/${assetName}`);
      } catch (error) {
        throw new Error(`Failed to load syntax rawfile ${assetName}: ${String(error)}`);
      }
      const syntaxJson = DemoDecorationProvider.textDecoder.decodeToString(syntaxContent);
      const compiled = engine.compileSyntaxFromJson(syntaxJson);
      if (compiled === null) {
        throw new Error(`Failed to compile syntax rawfile: ${assetName}`);
      }
    }

    DemoDecorationProvider.highlightEngine = engine;
    return true;
  }

  private static registerDemoStyleMap(engine: sweetline.HighlightEngine): void {
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
}
