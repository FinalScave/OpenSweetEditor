import {
  ApplyMode,
  DecorationContext,
  DecorationProvider,
  DecorationReceiver,
  DecorationResultBuilder,
  DecorationType,
  DiagnosticItem,
  Document,
  EditorTheme,
  FoldRegion,
  IndentGuide,
  InlayHint,
  InlayType,
  SeparatorGuide,
  StyleSpan,
  TextPosition
} from '@qiplat/sweeteditor';
import { DEMO_STYLE_COLOR } from './DemoSamples';
import { DemoFileMetadata } from './DemoTypes';

type DemoLanguage = 'java' | 'kotlin' | 'lua' | 'cpp' | 'text';

class StructureDecorations {
  readonly indentGuides: IndentGuide[];
  readonly foldRegions: FoldRegion[];

  constructor(indentGuides: IndentGuide[], foldRegions: FoldRegion[]) {
    this.indentGuides = indentGuides;
    this.foldRegions = foldRegions;
  }
}

export class DemoDecorationProvider implements DecorationProvider {
  private readonly documentProvider: () => Document | null;

  constructor(documentProvider: () => Document | null) {
    this.documentProvider = documentProvider;
  }

  getCapabilities(): Set<DecorationType> {
    return new Set<DecorationType>([
      DecorationType.SYNTAX_HIGHLIGHT,
      DecorationType.INLAY_HINT,
      DecorationType.DIAGNOSTIC,
      DecorationType.INDENT_GUIDE,
      DecorationType.FOLD_REGION
    ]);
  }

  provideDecorations(context: DecorationContext, receiver: DecorationReceiver): void {
    const document = this.documentProvider();
    if (!document) {
      receiver.accept(new DecorationResultBuilder().build());
      return;
    }

    const language = this.resolveLanguage(context.editorMetadata);
    const lineCount = document.getLineCount();
    const visibleStart = Math.max(0, context.visibleStartLine);
    const visibleEnd = Math.min(lineCount - 1, context.visibleEndLine);
    const allLines: string[] = [];
    const syntaxSpans = new Map<number, StyleSpan[]>();
    const inlayHints = new Map<number, InlayHint[]>();
    const diagnostics = new Map<number, DiagnosticItem[]>();

    for (let line = 0; line < lineCount; line++) {
      allLines.push(document.getLineText(line));
    }

    for (let line = visibleStart; line <= visibleEnd; line++) {
      const text = allLines[line];
      const spans = this.buildStyleSpans(text, language);
      if (spans.length > 0) {
        syntaxSpans.set(line, spans);
      }
      const hints = this.buildInlayHints(text);
      if (hints.length > 0) {
        inlayHints.set(line, hints);
      }
      const lineDiagnostics = this.buildDiagnostics(text);
      if (lineDiagnostics.length > 0) {
        diagnostics.set(line, lineDiagnostics);
      }
    }

    const structure = this.buildStructureDecorations(allLines);
    receiver.accept(
      new DecorationResultBuilder()
        .syntaxSpans(syntaxSpans, ApplyMode.REPLACE_RANGE)
        .inlayHints(inlayHints, ApplyMode.REPLACE_RANGE)
        .diagnostics(diagnostics, ApplyMode.REPLACE_RANGE)
        .indentGuides(structure.indentGuides, ApplyMode.REPLACE_ALL)
        .foldRegions(structure.foldRegions, ApplyMode.REPLACE_ALL)
        .build()
    );
  }

  private resolveLanguage(metadata: object | null): DemoLanguage {
    if (metadata instanceof DemoFileMetadata) {
      switch (metadata.languageId) {
        case 'java':
        case 'kotlin':
        case 'lua':
        case 'cpp':
          return metadata.languageId;
        default:
          break;
      }
    }
    return 'text';
  }

  private buildStyleSpans(lineText: string, language: DemoLanguage): StyleSpan[] {
    const spans: StyleSpan[] = [];
    const commentStart = this.findCommentStart(lineText, language);
    const codeEnd = commentStart >= 0 ? commentStart : lineText.length;
    if (commentStart >= 0) {
      spans.push({ column: commentStart, length: lineText.length - commentStart, styleId: EditorTheme.STYLE_COMMENT });
    }

    const occupied: Array<[number, number]> = [];
    this.collectMatches(lineText.slice(0, codeEnd), /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g, EditorTheme.STYLE_STRING,
      spans, occupied);
    this.collectMatches(lineText.slice(0, codeEnd), /#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b/g, DEMO_STYLE_COLOR, spans,
      occupied);
    this.collectMatches(lineText.slice(0, codeEnd), /@\w+/g, EditorTheme.STYLE_ANNOTATION, spans, occupied);
    this.collectMatches(lineText.slice(0, codeEnd), /\b\d+(?:\.\d+)?\b/g, EditorTheme.STYLE_NUMBER, spans, occupied);

    const keywords = this.getKeywords(language);
    if (keywords.length > 0) {
      const keywordPattern = new RegExp(`\\b(?:${keywords.join('|')})\\b`, 'g');
      this.collectMatches(lineText.slice(0, codeEnd), keywordPattern, EditorTheme.STYLE_KEYWORD, spans, occupied);
    }

    const typeWords = this.getTypeWords(language);
    if (typeWords.length > 0) {
      const typePattern = new RegExp(`\\b(?:${typeWords.join('|')})\\b`, 'g');
      this.collectMatches(lineText.slice(0, codeEnd), typePattern, EditorTheme.STYLE_TYPE, spans, occupied);
    }

    if (language === 'cpp' && lineText.trimStart().startsWith('#')) {
      spans.push({ column: 0, length: codeEnd, styleId: EditorTheme.STYLE_PREPROCESSOR });
    }

    this.collectFunctionSpans(lineText.slice(0, codeEnd), spans, occupied);
    this.collectClassNameSpans(lineText.slice(0, codeEnd), spans, occupied);
    spans.sort((a, b) => a.column - b.column);
    return spans;
  }

  private buildInlayHints(lineText: string): InlayHint[] {
    const hints: InlayHint[] = [];
    const colorPattern = /#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b/g;
    let colorMatch: RegExpExecArray | null = colorPattern.exec(lineText);
    while (colorMatch) {
      hints.push({
        type: InlayType.Color,
        column: colorMatch.index + colorMatch[0].length,
        text: null,
        intValue: this.parseColorLiteral(colorMatch[0])
      });
      colorMatch = colorPattern.exec(lineText);
    }

    if (/\b(fun|void|public|private|protected|static)\b/.test(lineText) && /\(/.test(lineText)) {
      hints.push({
        type: InlayType.Text,
        column: lineText.length,
        text: '  demo',
        intValue: 0
      });
    }
    return hints;
  }

  private buildDiagnostics(lineText: string): DiagnosticItem[] {
    const diagnostics: DiagnosticItem[] = [];
    const fixmeIndex = lineText.toUpperCase().indexOf('FIXME');
    if (fixmeIndex >= 0) {
      diagnostics.push({ column: fixmeIndex, length: 5, severity: 0, color: 0 });
    }
    const todoIndex = lineText.toUpperCase().indexOf('TODO');
    if (todoIndex >= 0) {
      diagnostics.push({ column: todoIndex, length: 4, severity: 1, color: 0 });
    }
    return diagnostics;
  }

  private buildStructureDecorations(lines: string[]): StructureDecorations {
    const indentGuides: IndentGuide[] = [];
    const foldRegions: FoldRegion[] = [];
    const separatorGuides: SeparatorGuide[] = [];
    const indents = lines.map((line) => this.getIndentColumn(line));
    const nonEmpty = lines.map((line) => line.trim().length > 0);

    for (let line = 0; line < lines.length - 1; line++) {
      if (!nonEmpty[line]) {
        continue;
      }
      const nextLine = this.findNextNonEmptyLine(line + 1, nonEmpty);
      if (nextLine < 0 || indents[nextLine] <= indents[line]) {
        continue;
      }

      const guideColumn = indents[nextLine];
      let endLine = nextLine;
      let cursor = nextLine + 1;
      while (cursor < lines.length) {
        if (!nonEmpty[cursor]) {
          cursor++;
          continue;
        }
        if (indents[cursor] < guideColumn) {
          break;
        }
        endLine = cursor;
        cursor++;
      }

      if (endLine > nextLine) {
        indentGuides.push({
          start: this.position(nextLine, guideColumn),
          end: this.position(endLine, guideColumn)
        });
        foldRegions.push({
          startLine: line,
          endLine
        });
      }
    }

    return new StructureDecorations(indentGuides, foldRegions);
  }

  private collectMatches(source: string, pattern: RegExp, styleId: number, spans: StyleSpan[],
    occupied: Array<[number, number]>): void {
    let match: RegExpExecArray | null = pattern.exec(source);
    while (match) {
      const start = match.index;
      const end = start + match[0].length;
      if (!this.hasOverlap(start, end, occupied)) {
        spans.push({ column: start, length: match[0].length, styleId });
        occupied.push([start, end]);
      }
      match = pattern.exec(source);
    }
  }

  private collectFunctionSpans(source: string, spans: StyleSpan[], occupied: Array<[number, number]>): void {
    const pattern = /\b([A-Za-z_]\w*)\s*(?=\()/g;
    let match: RegExpExecArray | null = pattern.exec(source);
    while (match) {
      const word = match[1];
      const start = match.index;
      const end = start + word.length;
      if (!this.hasOverlap(start, end, occupied) && !this.isReservedWord(word)) {
        spans.push({ column: start, length: word.length, styleId: EditorTheme.STYLE_FUNCTION });
        occupied.push([start, end]);
      }
      match = pattern.exec(source);
    }
  }

  private collectClassNameSpans(source: string, spans: StyleSpan[], occupied: Array<[number, number]>): void {
    const pattern = /\b(?:class|interface|object|struct|enum)\s+([A-Za-z_]\w*)/g;
    let match: RegExpExecArray | null = pattern.exec(source);
    while (match) {
      const word = match[1];
      const start = match.index + match[0].lastIndexOf(word);
      const end = start + word.length;
      if (!this.hasOverlap(start, end, occupied)) {
        spans.push({ column: start, length: word.length, styleId: EditorTheme.STYLE_CLASS });
        occupied.push([start, end]);
      }
      match = pattern.exec(source);
    }
  }

  private isReservedWord(word: string): boolean {
    return this.getKeywords('java').includes(word) ||
      this.getKeywords('kotlin').includes(word) ||
      this.getKeywords('lua').includes(word) ||
      this.getKeywords('cpp').includes(word);
  }

  private hasOverlap(start: number, end: number, occupied: Array<[number, number]>): boolean {
    for (let index = 0; index < occupied.length; index++) {
      const existingStart = occupied[index][0];
      const existingEnd = occupied[index][1];
      if (start < existingEnd && end > existingStart) {
        return true;
      }
    }
    return false;
  }

  private findCommentStart(lineText: string, language: DemoLanguage): number {
    if (language === 'lua') {
      return lineText.indexOf('--');
    }
    return lineText.indexOf('//');
  }

  private parseColorLiteral(literal: string): number {
    const hex = literal.slice(1);
    if (hex.length === 8) {
      return parseInt(hex, 16);
    }
    return 0xFF000000 | parseInt(hex, 16);
  }

  private getIndentColumn(lineText: string): number {
    let column = 0;
    for (let i = 0; i < lineText.length; i++) {
      const ch = lineText[i];
      if (ch === ' ') {
        column++;
        continue;
      }
      if (ch === '\t') {
        column += 2;
        continue;
      }
      break;
    }
    return column;
  }

  private findNextNonEmptyLine(fromLine: number, nonEmpty: boolean[]): number {
    for (let line = fromLine; line < nonEmpty.length; line++) {
      if (nonEmpty[line]) {
        return line;
      }
    }
    return -1;
  }

  private position(line: number, column: number): TextPosition {
    return { line, column };
  }

  private getKeywords(language: DemoLanguage): string[] {
    switch (language) {
      case 'java':
        return [
          'abstract', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum',
          'extends', 'final', 'finally', 'for', 'if', 'implements', 'import', 'interface', 'new', 'package',
          'private', 'protected', 'public', 'return', 'static', 'super', 'switch', 'this', 'throw', 'throws', 'try',
          'while'
        ];
      case 'kotlin':
        return [
          'as', 'break', 'class', 'companion', 'continue', 'data', 'else', 'enum', 'false', 'for', 'fun', 'if', 'in',
          'interface', 'is', 'null', 'object', 'override', 'package', 'private', 'protected', 'public', 'return',
          'super', 'this', 'true', 'typealias', 'val', 'var', 'when', 'while'
        ];
      case 'lua':
        return [
          'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function', 'if', 'in', 'local', 'nil',
          'not', 'or', 'repeat', 'return', 'then', 'true', 'until', 'while'
        ];
      case 'cpp':
        return [
          'alignas', 'auto', 'bool', 'break', 'case', 'catch', 'class', 'const', 'constexpr', 'continue', 'default',
          'delete', 'else', 'enum', 'false', 'float', 'for', 'if', 'include', 'inline', 'int', 'namespace', 'new',
          'nullptr', 'private', 'protected', 'public', 'return', 'static', 'struct', 'switch', 'template', 'this',
          'throw', 'true', 'try', 'typename', 'using', 'virtual', 'void', 'while'
        ];
      default:
        return [];
    }
  }

  private getTypeWords(language: DemoLanguage): string[] {
    switch (language) {
      case 'java':
        return ['String', 'Integer', 'Long', 'Boolean', 'List', 'Map', 'Set', 'Object'];
      case 'kotlin':
        return ['String', 'Int', 'Long', 'Boolean', 'Unit', 'List', 'Map', 'Set', 'Any'];
      case 'lua':
        return ['string', 'number', 'boolean', 'table'];
      case 'cpp':
        return ['int', 'float', 'double', 'char', 'bool', 'void', 'size_t', 'string', 'auto'];
      default:
        return [];
    }
  }
}
