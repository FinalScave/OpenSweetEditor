import {
  BracketGuide,
  Diagnostic,
  FlowGuide,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  CodeLensItem,
  LinkSpan,
  PhantomText,
  SeparatorGuide,
  StyleSpan
} from '../core/CoreAdornments';
import { TextChange } from '../core/EditorCore';
import { IntRange } from '../core/CoreFoundation';
import { EditorMetadata, LanguageConfiguration } from '../EditorTypes';

export enum DecorationType {
  SYNTAX_HIGHLIGHT = 'syntax_highlight',
  SEMANTIC_HIGHLIGHT = 'semantic_highlight',
  INLAY_HINT = 'inlay_hint',
  DIAGNOSTIC = 'diagnostic',
  FOLD_REGION = 'fold_region',
  INDENT_GUIDE = 'indent_guide',
  BRACKET_GUIDE = 'bracket_guide',
  FLOW_GUIDE = 'flow_guide',
  SEPARATOR_GUIDE = 'separator_guide',
  GUTTER_ICON = 'gutter_icon',
  PHANTOM_TEXT = 'phantom_text',
  CODELENS = 'codelens',
  LINK = 'link'
}

export { TextChange } from '../core/EditorCore';

export class DecorationContext {
  readonly visibleLineRange: IntRange;
  readonly totalLineCount: number;
  readonly textChanges: TextChange[];
  readonly languageConfiguration: LanguageConfiguration | null;
  readonly editorMetadata: EditorMetadata | null;

  constructor(visibleLineRange: IntRange, totalLineCount: number,
    textChanges: TextChange[],
    languageConfiguration: LanguageConfiguration | null,
    editorMetadata: EditorMetadata | null) {
    this.visibleLineRange = visibleLineRange;
    this.totalLineCount = totalLineCount;
    this.textChanges = [...textChanges];
    this.languageConfiguration = languageConfiguration;
    this.editorMetadata = editorMetadata;
  }
}

/**
 * Async callback for providers to submit decoration snapshots.
 * `accept(...)` may be called synchronously or asynchronously, including from a
 * background thread. The manager will switch back to the UI event loop before
 * applying the result to editor state or updating host-visible UI.
 */
export interface DecorationReceiver {
  accept(result: DecorationResult): boolean;

  isCancelled(): boolean;
}

/**
 * Decoration provider interface.
 * `provideDecorations(...)` is invoked from the editor's UI thread / UI event loop.
 * Providers may publish 0..n snapshots asynchronously through the receiver.
 */
export interface DecorationProvider {
  getCapabilities(): Set<DecorationType>;

  provideDecorations(context: DecorationContext, receiver: DecorationReceiver): void;
}

export enum ApplyMode {
  MERGE = 'merge',
  REPLACE_ALL = 'replace_all',
  REPLACE_RANGE = 'replace_range'
}

/**
 * Decoration result returned by a provider.
 */
export class DecorationResult {
  syntaxSpans: Map<number, StyleSpan[]> | null = null;
  semanticSpans: Map<number, StyleSpan[]> | null = null;
  inlayHints: Map<number, InlayHint[]> | null = null;
  diagnostics: Map<number, Diagnostic[]> | null = null;
  indentGuides: IndentGuide[] | null = null;
  bracketGuides: BracketGuide[] | null = null;
  flowGuides: FlowGuide[] | null = null;
  separatorGuides: SeparatorGuide[] | null = null;
  foldRegions: FoldRegion[] | null = null;
  gutterIcons: Map<number, GutterIcon[]> | null = null;
  phantomTexts: Map<number, PhantomText[]> | null = null;
  codeLensItems: Map<number, CodeLensItem[]> | null = null;
  links: Map<number, LinkSpan[]> | null = null;
  syntaxSpansMode: ApplyMode = ApplyMode.MERGE;
  semanticSpansMode: ApplyMode = ApplyMode.MERGE;
  inlayHintsMode: ApplyMode = ApplyMode.MERGE;
  diagnosticsMode: ApplyMode = ApplyMode.MERGE;
  indentGuidesMode: ApplyMode = ApplyMode.MERGE;
  bracketGuidesMode: ApplyMode = ApplyMode.MERGE;
  flowGuidesMode: ApplyMode = ApplyMode.MERGE;
  separatorGuidesMode: ApplyMode = ApplyMode.MERGE;
  foldRegionsMode: ApplyMode = ApplyMode.MERGE;
  gutterIconsMode: ApplyMode = ApplyMode.MERGE;
  phantomTextsMode: ApplyMode = ApplyMode.MERGE;
  codeLensItemsMode: ApplyMode = ApplyMode.MERGE;
  linksMode: ApplyMode = ApplyMode.MERGE;

  copy(): DecorationResult {
    const out = new DecorationResult();
    out.syntaxSpans = copyMapOfArrays(this.syntaxSpans);
    out.semanticSpans = copyMapOfArrays(this.semanticSpans);
    out.inlayHints = copyMapOfArrays(this.inlayHints);
    out.diagnostics = copyMapOfArrays(this.diagnostics);
    out.indentGuides = this.indentGuides ? [...this.indentGuides] : null;
    out.bracketGuides = this.bracketGuides ? [...this.bracketGuides] : null;
    out.flowGuides = this.flowGuides ? [...this.flowGuides] : null;
    out.separatorGuides = this.separatorGuides ? [...this.separatorGuides] : null;
    out.foldRegions = this.foldRegions ? [...this.foldRegions] : null;
    out.gutterIcons = copyMapOfArrays(this.gutterIcons);
    out.phantomTexts = copyMapOfArrays(this.phantomTexts);
    out.codeLensItems = copyMapOfArrays(this.codeLensItems);
    out.links = copyMapOfArrays<LinkSpan>(this.links);
    out.syntaxSpansMode = this.syntaxSpansMode;
    out.semanticSpansMode = this.semanticSpansMode;
    out.inlayHintsMode = this.inlayHintsMode;
    out.diagnosticsMode = this.diagnosticsMode;
    out.indentGuidesMode = this.indentGuidesMode;
    out.bracketGuidesMode = this.bracketGuidesMode;
    out.flowGuidesMode = this.flowGuidesMode;
    out.separatorGuidesMode = this.separatorGuidesMode;
    out.foldRegionsMode = this.foldRegionsMode;
    out.gutterIconsMode = this.gutterIconsMode;
    out.phantomTextsMode = this.phantomTextsMode;
    out.codeLensItemsMode = this.codeLensItemsMode;
    out.linksMode = this.linksMode;
    return out;
  }
}

export class DecorationResultBuilder {
  private result = new DecorationResult();

  syntaxSpans(value: Map<number, StyleSpan[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.syntaxSpans = value;
    this.result.syntaxSpansMode = mode;
    return this;
  }

  semanticSpans(value: Map<number, StyleSpan[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.semanticSpans = value;
    this.result.semanticSpansMode = mode;
    return this;
  }

  inlayHints(value: Map<number, InlayHint[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.inlayHints = value;
    this.result.inlayHintsMode = mode;
    return this;
  }

  diagnostics(value: Map<number, Diagnostic[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.diagnostics = value;
    this.result.diagnosticsMode = mode;
    return this;
  }

  indentGuides(value: IndentGuide[] | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.indentGuides = value;
    this.result.indentGuidesMode = mode;
    return this;
  }

  bracketGuides(value: BracketGuide[] | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.bracketGuides = value;
    this.result.bracketGuidesMode = mode;
    return this;
  }

  flowGuides(value: FlowGuide[] | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.flowGuides = value;
    this.result.flowGuidesMode = mode;
    return this;
  }

  separatorGuides(value: SeparatorGuide[] | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.separatorGuides = value;
    this.result.separatorGuidesMode = mode;
    return this;
  }

  foldRegions(value: FoldRegion[] | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.foldRegions = value;
    this.result.foldRegionsMode = mode;
    return this;
  }

  gutterIcons(value: Map<number, GutterIcon[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.gutterIcons = value;
    this.result.gutterIconsMode = mode;
    return this;
  }

  phantomTexts(value: Map<number, PhantomText[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.phantomTexts = value;
    this.result.phantomTextsMode = mode;
    return this;
  }

  codeLensItems(value: Map<number, CodeLensItem[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.codeLensItems = value;
    this.result.codeLensItemsMode = mode;
    return this;
  }

  links(value: Map<number, LinkSpan[]> | null, mode: ApplyMode): DecorationResultBuilder {
    this.result.links = value;
    this.result.linksMode = mode;
    return this;
  }

  build(): DecorationResult {
    return this.result;
  }
}

function copyMapOfArrays<T>(source: Map<number, T[]> | null): Map<number, T[]> | null {
  if (!source) {
    return null;
  }
  const out = new Map<number, T[]>();
  source.forEach((value, key) => {
    out.set(key, value ? [...value] : []);
  });
  return out;
}
