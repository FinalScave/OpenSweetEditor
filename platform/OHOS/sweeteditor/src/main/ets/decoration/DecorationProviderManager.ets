import {
  ApplyMode,
  DecorationContext,
  DecorationProvider,
  DecorationReceiver,
  DecorationResult,
  TextChange
} from './DecorationTypes';
import { IntRange } from '../core/CoreFoundation';
import {
  BracketGuide,
  Diagnostic,
  DocumentHighlight,
  FlowGuide,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  PhantomText,
  CodeLensItem,
  LinkSpan,
  SeparatorGuide,
  StyleSpan
} from '../core/CoreAdornments';
import { SweetEditor } from '../SweetEditor';
import hilog from '@ohos.hilog';

const HILOG_DOMAIN = 0x3D12;
const TAG = 'DecorationMgr';

interface ProviderState {
  snapshot: DecorationResult | null;
  activeReceiver: ManagedReceiver | null;
}

const APPLY_MODE_PRIORITY_MERGE = 0;
const APPLY_MODE_PRIORITY_REPLACE_RANGE = 1;
const APPLY_MODE_PRIORITY_REPLACE_ALL = 2;

/**
 * Decoration provider manager.
 * Handles provider registration, refresh scheduling, debounce, scroll throttle,
 * overscan, result merging, and applying decorations to the editor.
 */
export class DecorationProviderManager {
  private editor: SweetEditor;
  private providers: DecorationProvider[] = [];
  private providerStates: Map<DecorationProvider, ProviderState> = new Map();
  private pendingTextChanges: TextChange[] = [];
  private generation: number = 0;
  private applyScheduled: boolean = false;
  private lastVisibleLineRange: IntRange = { start: 0, end: -1 };
  private scrollRefreshScheduled: boolean = false;
  private pendingScrollRefresh: boolean = false;
  private lastScrollRefreshTimeMs: number = 0;
  private refreshTimerId: number = -1;
  private scrollRefreshTimerId: number = -1;
  private applyTimerId: number = -1;
  private tornDown: boolean = false;

  constructor(editor: SweetEditor) {
    this.editor = editor;
  }

  addProvider(provider: DecorationProvider): void {
    if (this.tornDown) {
      return;
    }
    if (!this.providers.includes(provider)) {
      this.providers.push(provider);
      this.providerStates.set(provider, { snapshot: null, activeReceiver: null });
      this.requestRefresh();
    }
  }

  removeProvider(provider: DecorationProvider): void {
    if (this.tornDown) {
      return;
    }
    const idx = this.providers.indexOf(provider);
    if (idx >= 0) {
      this.providers.splice(idx, 1);
    }
    const state = this.providerStates.get(provider);
    if (state && state.activeReceiver) {
      state.activeReceiver.cancel();
    }
    this.providerStates.delete(provider);
    this.scheduleApply();
  }

  requestRefresh(): void {
    if (this.tornDown) {
      return;
    }
    this.scheduleRefresh(0, null);
  }

  onDocumentLoaded(): void {
    if (this.tornDown) {
      return;
    }
    this.scheduleRefresh(0, null);
  }

  onTextChanged(changes: TextChange[]): void {
    if (this.tornDown) {
      return;
    }
    this.scheduleRefresh(50, changes);
  }

  onScrollChanged(): void {
    if (this.tornDown) {
      return;
    }
    this.scheduleScrollRefresh();
  }

  private scheduleRefresh(delayMs: number, changes: TextChange[] | null): void {
    if (changes) {
      this.pendingTextChanges.push(...changes);
    }
    if (this.refreshTimerId >= 0) {
      clearTimeout(this.refreshTimerId);
    }
    this.refreshTimerId = setTimeout(() => {
      this.refreshTimerId = -1;
      this.doRefresh();
    }, delayMs);
  }

  private scheduleScrollRefresh(): void {
    const now = Date.now();
    const elapsed = now - this.lastScrollRefreshTimeMs;
    const settings = this.editor.getSettings();
    const minInterval = settings ? settings.getDecorationScrollRefreshMinIntervalMs() : 200;
    const delay = elapsed >= minInterval ? 0 : (minInterval - elapsed);

    if (this.scrollRefreshScheduled) {
      this.pendingScrollRefresh = true;
      return;
    }
    this.scrollRefreshScheduled = true;
    this.scrollRefreshTimerId = setTimeout(() => {
      this.scrollRefreshScheduled = false;
      if (this.refreshTimerId >= 0) {
        clearTimeout(this.refreshTimerId);
      }
      this.refreshTimerId = -1;
      this.doRefresh();
      this.lastScrollRefreshTimeMs = Date.now();
      if (this.pendingScrollRefresh) {
        this.pendingScrollRefresh = false;
        this.scheduleScrollRefresh();
      }
    }, delay);
  }

  private doRefresh(): void {
    if (this.tornDown) {
      return;
    }
    const refreshStartMs = Date.now();
    this.generation++;
    const currentGeneration = this.generation;

    const visible = this.editor.getVisibleLineRange();
    this.lastVisibleLineRange = visible;
    const total = this.editor.getTotalLineCount();
    const changes = [...this.pendingTextChanges];
    this.pendingTextChanges = [];

    let contextStart = visible.start;
    let contextEnd = visible.end;
    if (total > 0 && visible.end >= visible.start) {
      const overscanLines = this.calculateOverscanLines(visible.start, visible.end);
      contextStart = Math.max(0, visible.start - overscanLines);
      contextEnd = Math.min(total - 1, visible.end + overscanLines);
    }

    const context = new DecorationContext(
      { start: contextStart, end: contextEnd }, total, changes,
      this.editor.getLanguageConfiguration(), this.editor.getMetadata()
    );

    for (const provider of this.providers) {
      let state = this.providerStates.get(provider);
      if (!state) {
        state = { snapshot: null, activeReceiver: null };
        this.providerStates.set(provider, state);
      }
      if (state.activeReceiver) {
        state.activeReceiver.cancel();
      }
      const receiver = new ManagedReceiver(provider, currentGeneration, this);
      state.activeReceiver = receiver;
      try {
        provider.provideDecorations(context, receiver);
      } catch (e) {
        hilog.error(HILOG_DOMAIN, TAG, 'provider failed: %{public}s', `${e}`);
      }
    }
    this.editor.recordDecorationPerf('refresh', Date.now() - refreshStartMs);
  }

  private scheduleApply(): void {
    if (this.tornDown) {
      return;
    }
    if (this.applyScheduled) {
      return;
    }
    this.applyScheduled = true;
    this.applyTimerId = setTimeout(() => {
      this.applyTimerId = -1;
      this.applyMerged();
    }, 0);
  }

  private applyMerged(): void {
    if (this.tornDown) {
      return;
    }
    const applyStartMs = Date.now();
    this.applyScheduled = false;

    const syntaxSpans = new Map<number, StyleSpan[]>();
    const semanticSpans = new Map<number, StyleSpan[]>();
    const overlaySpans = new Map<number, StyleSpan[]>();
    const inlayHints = new Map<number, InlayHint[]>();
    const diagnostics = new Map<number, Diagnostic[]>();
    const documentHighlights = new Map<number, DocumentHighlight[]>();
    let indentGuides: IndentGuide[] | null = null;
    let bracketGuides: BracketGuide[] | null = null;
    let flowGuides: FlowGuide[] | null = null;
    let separatorGuides: SeparatorGuide[] | null = null;
    const foldRegions: FoldRegion[] = [];
    const gutterIcons = new Map<number, GutterIcon[]>();
    const phantomTexts = new Map<number, PhantomText[]>();
    const codeLensItems = new Map<number, CodeLensItem[]>();
    const links = new Map<number, LinkSpan[]>();

    let syntaxMode = ApplyMode.MERGE;
    let semanticMode = ApplyMode.MERGE;
    let overlayMode = ApplyMode.MERGE;
    let inlayMode = ApplyMode.MERGE;
    let diagnosticMode = ApplyMode.MERGE;
    let documentHighlightMode = ApplyMode.MERGE;
    let indentMode = ApplyMode.MERGE;
    let bracketMode = ApplyMode.MERGE;
    let flowMode = ApplyMode.MERGE;
    let separatorMode = ApplyMode.MERGE;
    let foldMode = ApplyMode.MERGE;
    let gutterMode = ApplyMode.MERGE;
    let phantomMode = ApplyMode.MERGE;
    let codeLensMode = ApplyMode.MERGE;
    let linksMode = ApplyMode.MERGE;

    for (const provider of this.providers) {
      const state = this.providerStates.get(provider);
      if (!state || !state.snapshot) {
        continue;
      }
      const r = state.snapshot;

      syntaxMode = mergeMode(syntaxMode, r.syntaxSpansMode);
      if (r.syntaxSpans) {
        appendMapOfArrays(syntaxSpans, r.syntaxSpans);
      }
      semanticMode = mergeMode(semanticMode, r.semanticSpansMode);
      if (r.semanticSpans) {
        appendMapOfArrays(semanticSpans, r.semanticSpans);
      }
      overlayMode = mergeMode(overlayMode, r.overlaySpansMode);
      if (r.overlaySpans) {
        appendMapOfArrays(overlaySpans, r.overlaySpans);
      }
      inlayMode = mergeMode(inlayMode, r.inlayHintsMode);
      if (r.inlayHints) {
        appendMapOfArrays(inlayHints, r.inlayHints);
      }
      diagnosticMode = mergeMode(diagnosticMode, r.diagnosticsMode);
      if (r.diagnostics) {
        appendMapOfArrays(diagnostics, r.diagnostics);
      }
      documentHighlightMode = mergeMode(documentHighlightMode, r.documentHighlightsMode);
      if (r.documentHighlights) {
        appendMapOfArrays(documentHighlights, r.documentHighlights);
      }
      gutterMode = mergeMode(gutterMode, r.gutterIconsMode);
      if (r.gutterIcons) {
        appendMapOfArrays(gutterIcons, r.gutterIcons);
      }
      phantomMode = mergeMode(phantomMode, r.phantomTextsMode);
      if (r.phantomTexts) {
        appendMapOfArrays(phantomTexts, r.phantomTexts);
      }
      codeLensMode = mergeMode(codeLensMode, r.codeLensItemsMode);
      if (r.codeLensItems) {
        appendMapOfArrays(codeLensItems, r.codeLensItems);
      }
      linksMode = mergeMode(linksMode, r.linksMode);
      if (r.links) {
        appendMapOfArrays(links, r.links);
      }

      indentMode = mergeMode(indentMode, r.indentGuidesMode);
      if (r.indentGuides) {
        indentGuides = [...r.indentGuides];
      }
      bracketMode = mergeMode(bracketMode, r.bracketGuidesMode);
      if (r.bracketGuides) {
        bracketGuides = [...r.bracketGuides];
      }
      flowMode = mergeMode(flowMode, r.flowGuidesMode);
      if (r.flowGuides) {
        flowGuides = [...r.flowGuides];
      }
      separatorMode = mergeMode(separatorMode, r.separatorGuidesMode);
      if (r.separatorGuides) {
        separatorGuides = [...r.separatorGuides];
      }
      foldMode = mergeMode(foldMode, r.foldRegionsMode);
      if (r.foldRegions) {
        foldRegions.push(...r.foldRegions);
      }
    }

    this.applySpanMode(0, syntaxMode);
    this.applySpanMode(1, semanticMode);
    this.applySpanMode(2, overlayMode);
    this.editor.setBatchLineSpans(0, syntaxSpans);
    this.editor.setBatchLineSpans(1, semanticSpans);
    this.editor.setBatchLineSpans(2, overlaySpans);

    this.applyInlayMode(inlayMode);
    this.editor.setBatchLineInlayHints(inlayHints);

    this.applyDiagnosticMode(diagnosticMode);
    this.editor.setBatchLineDiagnostics(diagnostics);

    this.applyDocumentHighlightMode(documentHighlightMode);
    this.editor.setBatchLineDocumentHighlights(documentHighlights);

    this.applyIndentGuidesMode(indentMode, indentGuides);
    this.applyBracketGuidesMode(bracketMode, bracketGuides);
    this.applyFlowGuidesMode(flowMode, flowGuides);
    this.applySeparatorGuidesMode(separatorMode, separatorGuides);

    if (foldMode === ApplyMode.REPLACE_ALL || foldMode === ApplyMode.REPLACE_RANGE) {
      this.editor.setFoldRegions(foldRegions);
    } else if (foldRegions.length > 0) {
      this.editor.setFoldRegions(foldRegions);
    }

    this.applyGutterMode(gutterMode);
    this.editor.setBatchLineGutterIcons(gutterIcons);

    this.applyPhantomMode(phantomMode);
    this.editor.setBatchLinePhantomTexts(phantomTexts);

    this.applyCodeLensMode(codeLensMode);
    this.editor.setBatchLineCodeLens(codeLensItems);

    this.applyLinksMode(linksMode);
    this.editor.setBatchLineLinks(links);

    this.editor.recordDecorationPerf('apply', Date.now() - applyStartMs);
  }

  teardown(): void {
    if (this.tornDown) {
      return;
    }
    this.tornDown = true;
    if (this.refreshTimerId >= 0) {
      clearTimeout(this.refreshTimerId);
      this.refreshTimerId = -1;
    }
    if (this.scrollRefreshTimerId >= 0) {
      clearTimeout(this.scrollRefreshTimerId);
      this.scrollRefreshTimerId = -1;
    }
    if (this.applyTimerId >= 0) {
      clearTimeout(this.applyTimerId);
      this.applyTimerId = -1;
    }
    this.applyScheduled = false;
    this.scrollRefreshScheduled = false;
    this.pendingScrollRefresh = false;
    this.pendingTextChanges = [];
    this.generation++;
    for (const state of this.providerStates.values()) {
      if (state.activeReceiver) {
        state.activeReceiver.cancel();
      }
      state.activeReceiver = null;
      state.snapshot = null;
    }
    this.providers = [];
    this.providerStates.clear();
  }

  private applySpanMode(layer: number, mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearHighlights(layer);
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearSpanRange(layer, this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyInlayMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearInlayHints();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearInlayRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyDiagnosticMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearDiagnostics();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearDiagnosticRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyDocumentHighlightMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearDocumentHighlights();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearDocumentHighlightRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyGutterMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearGutterIcons();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearGutterRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyPhantomMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearPhantomTexts();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearPhantomRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyCodeLensMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearCodeLens();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearCodeLensRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyLinksMode(mode: ApplyMode): void {
    if (mode === ApplyMode.REPLACE_ALL) {
      this.editor.clearLinks();
    } else if (mode === ApplyMode.REPLACE_RANGE) {
      this.clearLinksRange(this.lastVisibleLineRange.start, this.lastVisibleLineRange.end);
    }
  }

  private applyIndentGuidesMode(mode: ApplyMode, data: IndentGuide[] | null): void {
    if (mode === ApplyMode.REPLACE_ALL || mode === ApplyMode.REPLACE_RANGE) {
      this.editor.setIndentGuides(data || []);
    } else if (data !== null) {
      this.editor.setIndentGuides(data);
    }
  }

  private applyBracketGuidesMode(mode: ApplyMode, data: BracketGuide[] | null): void {
    if (mode === ApplyMode.REPLACE_ALL || mode === ApplyMode.REPLACE_RANGE) {
      this.editor.setBracketGuides(data || []);
    } else if (data !== null) {
      this.editor.setBracketGuides(data);
    }
  }

  private applyFlowGuidesMode(mode: ApplyMode, data: FlowGuide[] | null): void {
    if (mode === ApplyMode.REPLACE_ALL || mode === ApplyMode.REPLACE_RANGE) {
      this.editor.setFlowGuides(data || []);
    } else if (data !== null) {
      this.editor.setFlowGuides(data);
    }
  }

  private applySeparatorGuidesMode(mode: ApplyMode, data: SeparatorGuide[] | null): void {
    if (mode === ApplyMode.REPLACE_ALL || mode === ApplyMode.REPLACE_RANGE) {
      this.editor.setSeparatorGuides(data || []);
    } else if (data !== null) {
      this.editor.setSeparatorGuides(data);
    }
  }

  private calculateOverscanLines(visibleStart: number, visibleEnd: number): number {
    const viewportLineCount = visibleEnd >= visibleStart ? (visibleEnd - visibleStart + 1) : 0;
    if (viewportLineCount <= 0) {
      return 0;
    }
    const settings = this.editor.getSettings();
    const multiplier = Math.max(0, settings ? settings.getDecorationOverscanViewportMultiplier() : 0.5);
    return Math.max(0, Math.ceil(viewportLineCount * multiplier));
  }

  private clearSpanRange(layer: number, startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<StyleSpan>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineSpans(layer, empty);
  }

  private clearInlayRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<InlayHint>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineInlayHints(empty);
  }

  private clearDiagnosticRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<Diagnostic>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineDiagnostics(empty);
  }

  private clearDocumentHighlightRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<DocumentHighlight>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineDocumentHighlights(empty);
  }

  private clearGutterRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<GutterIcon>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineGutterIcons(empty);
  }

  private clearPhantomRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<PhantomText>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLinePhantomTexts(empty);
  }

  private clearCodeLensRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<CodeLensItem>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineCodeLens(empty);
  }

  private clearLinksRange(startLine: number, endLine: number): void {
    const empty = buildEmptyMapRange<LinkSpan>(startLine, endLine);
    if (empty.size === 0) {
      return;
    }
    this.editor.setBatchLineLinks(empty);
  }

  /** @internal Called by ManagedReceiver when a provider submits results. */
  onProviderResult(provider: DecorationProvider, result: DecorationResult, receiverGeneration: number): void {
    if (receiverGeneration !== this.generation) {
      return;
    }
    let state = this.providerStates.get(provider);
    if (!state) {
      state = { snapshot: null, activeReceiver: null };
      this.providerStates.set(provider, state);
    }
    this.mergePatch(state, result);
    this.scheduleApply();
  }

  getGeneration(): number {
    return this.generation;
  }

  private mergePatch(state: ProviderState, patch: DecorationResult): void {
    if (!state.snapshot) {
      state.snapshot = new DecorationResult();
    }
    const target = state.snapshot;

    if (patch.syntaxSpans !== null) {
      target.syntaxSpans = patch.syntaxSpans;
      target.syntaxSpansMode = patch.syntaxSpansMode;
    } else if (patch.syntaxSpansMode !== ApplyMode.MERGE) {
      target.syntaxSpans = null;
      target.syntaxSpansMode = patch.syntaxSpansMode;
    }
    if (patch.semanticSpans !== null) {
      target.semanticSpans = patch.semanticSpans;
      target.semanticSpansMode = patch.semanticSpansMode;
    } else if (patch.semanticSpansMode !== ApplyMode.MERGE) {
      target.semanticSpans = null;
      target.semanticSpansMode = patch.semanticSpansMode;
    }
    if (patch.overlaySpans !== null) {
      target.overlaySpans = patch.overlaySpans;
      target.overlaySpansMode = patch.overlaySpansMode;
    } else if (patch.overlaySpansMode !== ApplyMode.MERGE) {
      target.overlaySpans = null;
      target.overlaySpansMode = patch.overlaySpansMode;
    }
    if (patch.inlayHints !== null) {
      target.inlayHints = patch.inlayHints;
      target.inlayHintsMode = patch.inlayHintsMode;
    } else if (patch.inlayHintsMode !== ApplyMode.MERGE) {
      target.inlayHints = null;
      target.inlayHintsMode = patch.inlayHintsMode;
    }
    if (patch.diagnostics !== null) {
      target.diagnostics = patch.diagnostics;
      target.diagnosticsMode = patch.diagnosticsMode;
    } else if (patch.diagnosticsMode !== ApplyMode.MERGE) {
      target.diagnostics = null;
      target.diagnosticsMode = patch.diagnosticsMode;
    }
    if (patch.documentHighlights !== null) {
      target.documentHighlights = patch.documentHighlights;
      target.documentHighlightsMode = patch.documentHighlightsMode;
    } else if (patch.documentHighlightsMode !== ApplyMode.MERGE) {
      target.documentHighlights = null;
      target.documentHighlightsMode = patch.documentHighlightsMode;
    }
    if (patch.indentGuides !== null) {
      target.indentGuides = patch.indentGuides;
      target.indentGuidesMode = patch.indentGuidesMode;
    } else if (patch.indentGuidesMode !== ApplyMode.MERGE) {
      target.indentGuides = null;
      target.indentGuidesMode = patch.indentGuidesMode;
    }
    if (patch.bracketGuides !== null) {
      target.bracketGuides = patch.bracketGuides;
      target.bracketGuidesMode = patch.bracketGuidesMode;
    } else if (patch.bracketGuidesMode !== ApplyMode.MERGE) {
      target.bracketGuides = null;
      target.bracketGuidesMode = patch.bracketGuidesMode;
    }
    if (patch.flowGuides !== null) {
      target.flowGuides = patch.flowGuides;
      target.flowGuidesMode = patch.flowGuidesMode;
    } else if (patch.flowGuidesMode !== ApplyMode.MERGE) {
      target.flowGuides = null;
      target.flowGuidesMode = patch.flowGuidesMode;
    }
    if (patch.separatorGuides !== null) {
      target.separatorGuides = patch.separatorGuides;
      target.separatorGuidesMode = patch.separatorGuidesMode;
    } else if (patch.separatorGuidesMode !== ApplyMode.MERGE) {
      target.separatorGuides = null;
      target.separatorGuidesMode = patch.separatorGuidesMode;
    }
    if (patch.foldRegions !== null) {
      target.foldRegions = patch.foldRegions;
      target.foldRegionsMode = patch.foldRegionsMode;
    } else if (patch.foldRegionsMode !== ApplyMode.MERGE) {
      target.foldRegions = null;
      target.foldRegionsMode = patch.foldRegionsMode;
    }
    if (patch.gutterIcons !== null) {
      target.gutterIcons = patch.gutterIcons;
      target.gutterIconsMode = patch.gutterIconsMode;
    } else if (patch.gutterIconsMode !== ApplyMode.MERGE) {
      target.gutterIcons = null;
      target.gutterIconsMode = patch.gutterIconsMode;
    }
    if (patch.phantomTexts !== null) {
      target.phantomTexts = patch.phantomTexts;
      target.phantomTextsMode = patch.phantomTextsMode;
    } else if (patch.phantomTextsMode !== ApplyMode.MERGE) {
      target.phantomTexts = null;
      target.phantomTextsMode = patch.phantomTextsMode;
    }
    if (patch.codeLensItems !== null) {
      target.codeLensItems = patch.codeLensItems;
      target.codeLensItemsMode = patch.codeLensItemsMode;
    } else if (patch.codeLensItemsMode !== ApplyMode.MERGE) {
      target.codeLensItems = null;
      target.codeLensItemsMode = patch.codeLensItemsMode;
    }
    if (patch.links !== null) {
      target.links = patch.links;
      target.linksMode = patch.linksMode;
    } else if (patch.linksMode !== ApplyMode.MERGE) {
      target.links = null;
      target.linksMode = patch.linksMode;
    }
  }
}

class ManagedReceiver implements DecorationReceiver {
  private provider: DecorationProvider;
  private receiverGeneration: number;
  private manager: DecorationProviderManager;
  private cancelled: boolean = false;

  constructor(provider: DecorationProvider, receiverGeneration: number, manager: DecorationProviderManager) {
    this.provider = provider;
    this.receiverGeneration = receiverGeneration;
    this.manager = manager;
  }

  cancel(): void {
    this.cancelled = true;
  }

  accept(result: DecorationResult): boolean {
    if (this.cancelled || this.receiverGeneration !== this.manager.getGeneration()) {
      return false;
    }
    const snapshot = result.copy();
    setTimeout(() => {
      if (this.cancelled || this.receiverGeneration !== this.manager.getGeneration()) {
        return;
      }
      this.manager.onProviderResult(this.provider, snapshot, this.receiverGeneration);
    }, 0);
    return true;
  }

  isCancelled(): boolean {
    return this.cancelled || this.receiverGeneration !== this.manager.getGeneration();
  }
}

function mergeMode(current: ApplyMode, next: ApplyMode): ApplyMode {
  if (priority(next) > priority(current)) {
    return next;
  }
  return current;
}

function priority(mode: ApplyMode): number {
  switch (mode) {
    case ApplyMode.MERGE:
      return APPLY_MODE_PRIORITY_MERGE;
    case ApplyMode.REPLACE_RANGE:
      return APPLY_MODE_PRIORITY_REPLACE_RANGE;
    case ApplyMode.REPLACE_ALL:
      return APPLY_MODE_PRIORITY_REPLACE_ALL;
    default:
      return APPLY_MODE_PRIORITY_MERGE;
  }
}

function buildEmptyMapRange<T>(startLine: number, endLine: number): Map<number, T[]> {
  const out = new Map<number, T[]>();
  if (endLine < startLine) {
    return out;
  }
  for (let line = startLine; line <= endLine; line++) {
    out.set(line, []);
  }
  return out;
}

function appendMapOfArrays<T>(out: Map<number, T[]>, patch: Map<number, T[]>): void {
  patch.forEach((src, key) => {
    let target = out.get(key);
    if (!target) {
      target = [];
      out.set(key, target);
    }
    target.push(...(src || []));
  });
}
