import { Document } from './core/EditorCore';
import { ScrollBehavior } from './core/CoreAction';
import { IntRange, TabStopGroup, TextEdit, TextPosition, TextRange } from './core/CoreFoundation';
import { CursorRect, ScrollMetrics } from './core/CoreVisual';
import { SearchRequest, SearchState, createEmptySearchState } from './core/CoreSearch';
import {
  BracketGuide,
  Diagnostic,
  DocumentHighlight,
  FlowGuide,
  FoldRegion,
  CodeLensItem,
  GutterIcon,
  IndentGuide,
  InlayHint,
  LinkSpan,
  PhantomText,
  SeparatorGuide,
  SpanLayer,
  StyleSpan,
  TextStyle
} from './core/CoreAdornments';
import { EditorIconProvider, EditorMetadata, EditorTheme, LanguageConfiguration } from './EditorTypes';
import { EditorKeyMap } from './EditorKeymap';
import { EditorSettings } from './EditorSettings';
import {
  ContextMenuEvent,
  CodeLensClickEvent,
  CursorChangedEvent,
  DocumentLoadedEvent,
  DoubleTapEvent,
  EditorEvent,
  EditorEventListener,
  FoldToggleEvent,
  GutterIconClickEvent,
  InlayHintClickEvent,
  LinkClickEvent,
  LongPressEvent,
  ScaleChangedEvent,
  ScrollChangedEvent,
  SelectionMenuItemClickEvent,
  SelectionChangedEvent,
  TextChangedEvent
} from './event/EditorEvent';
import {
  CompletionItem,
  CompletionItemViewBuilder,
  CompletionProvider
} from './completion/CompletionTypes';
import { InlineSuggestion, InlineSuggestionListener } from './copilot/InlineSuggestionTypes';
import { DecorationProvider } from './decoration/DecorationTypes';
import { NewLineActionProvider } from './newline/NewLineTypes';
import { SelectionMenuItemProvider } from './selection/SelectionMenuTypes';
import { SweetEditor } from './SweetEditor';

export class SweetEditorController {
  private api: SweetEditor | null = null;
  private associatedEditor: SweetEditor | null = null;
  private inactive: boolean = false;
  private eventListeners: Map<string, EditorEventListener<EditorEvent>[]> = new Map();
  private readyListeners: Array<() => void> = [];

  bind(api: SweetEditor): void {
    if (this.inactive) {
      return;
    }
    if (this.associatedEditor === null) {
      this.associatedEditor = api;
    } else if (this.associatedEditor !== api) {
      throw new Error('SweetEditorController cannot be rebound to another editor instance.');
    }
    if (this.api === api) {
      return;
    }
    if (this.api !== null) {
      throw new Error('SweetEditorController cannot be bound to multiple widgets at the same time.');
    }
    this.api = api;
    this.attachStoredEventListeners(api);
    const listeners = [...this.readyListeners];
    this.readyListeners = [];
    for (const listener of listeners) {
      listener();
    }
  }

  unbind(api: SweetEditor): void {
    if (this.api === api) {
      this.eventListeners.forEach((listeners, type): void => {
        for (const listener of listeners) {
          this.detachEventListener(api, type, listener);
        }
      });
      this.api = null;
      this.inactive = true;
      this.readyListeners = [];
      this.eventListeners.clear();
    }
  }

  whenReady(listener: () => void): void {
    if (this.inactive) {
      return;
    }
    if (this.api) {
      listener();
      return;
    }
    this.readyListeners.push(listener);
  }

  loadDocument(document: Document): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    api.loadDocument(document);
  }

  getDocument(): Document | null {
    const api = this.getActiveApi();
    return api ? api.getDocument() : null;
  }

  getSettings(): EditorSettings | null {
    const api = this.getActiveApi();
    return api ? api.getSettings() : null;
  }

  applyTheme(theme: EditorTheme): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    api.applyTheme(theme);
  }

  getTheme(): EditorTheme | null {
    const api = this.getActiveApi();
    return api ? api.getTheme() : null;
  }

  setLanguageConfiguration(config: LanguageConfiguration | null): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    api.setLanguageConfiguration(config);
  }

  getLanguageConfiguration(): LanguageConfiguration | null {
    const api = this.getActiveApi();
    return api ? api.getLanguageConfiguration() : null;
  }

  setMetadata(metadata: EditorMetadata | null): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    api.setMetadata(metadata);
  }

  getMetadata(): EditorMetadata | null {
    const api = this.getActiveApi();
    return api ? api.getMetadata() : null;
  }

  setEditorIconProvider(provider: EditorIconProvider | null): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    api.setEditorIconProvider(provider);
  }

  getKeyMap(): EditorKeyMap {
    const api = this.getActiveApi();
    return api ? api.getKeyMap() : EditorKeyMap.defaultKeyMap();
  }

  setKeyMap(keyMap: EditorKeyMap): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    api.setKeyMap(keyMap);
  }

  addDecorationProvider(provider: DecorationProvider): void {
    this.run((api) => api.addDecorationProvider(provider));
  }

  removeDecorationProvider(provider: DecorationProvider): void {
    this.run((api) => api.removeDecorationProvider(provider));
  }

  addCompletionProvider(provider: CompletionProvider): void {
    this.run((api) => api.addCompletionProvider(provider));
  }

  removeCompletionProvider(provider: CompletionProvider): void {
    this.run((api) => api.removeCompletionProvider(provider));
  }

  addNewLineActionProvider(provider: NewLineActionProvider): void {
    this.run((api) => api.addNewLineActionProvider(provider));
  }

  removeNewLineActionProvider(provider: NewLineActionProvider): void {
    this.run((api) => api.removeNewLineActionProvider(provider));
  }

  insertText(text: string): void {
    this.run((api) => api.insertText(text));
  }

  /**
   * Inserts text at the specified document position.
   */
  insertTextAt(position: TextPosition, text: string): void {
    this.run((api) => api.insertTextAt(position, text));
  }

  replaceText(range: TextRange, newText: string): void {
    this.run((api) => api.replaceText(range, newText));
  }

  deleteText(range: TextRange): void {
    this.run((api) => api.deleteText(range));
  }

  /**
   * Applies multiple text edits as one undoable operation.
   *
   * Edits use the original document coordinates. The first edit is the primary edit.
   */
  applyTextEdits(edits: TextEdit[]): void {
    this.run((api) => api.applyTextEdits(edits));
  }

  moveLineUp(): void {
    this.run((api) => api.moveLineUp());
  }

  moveLineDown(): void {
    this.run((api) => api.moveLineDown());
  }

  copyLineUp(): void {
    this.run((api) => api.copyLineUp());
  }

  copyLineDown(): void {
    this.run((api) => api.copyLineDown());
  }

  deleteLine(): void {
    this.run((api) => api.deleteLine());
  }

  insertLineAbove(): void {
    this.run((api) => api.insertLineAbove());
  }

  insertLineBelow(): void {
    this.run((api) => api.insertLineBelow());
  }

  triggerCompletion(): void {
    this.run((api) => api.triggerCompletion());
  }

  showCompletionItems(items: CompletionItem[]): void {
    this.run((api) => api.showCompletionItems(items));
  }

  dismissCompletion(): void {
    this.run((api) => api.dismissCompletion());
  }

  setCompletionItemViewBuilder(builder: CompletionItemViewBuilder | null): void {
    this.run((api) => api.setCompletionItemViewBuilder(builder));
  }

  showInlineSuggestion(suggestion: InlineSuggestion): void {
    this.run((api) => api.showInlineSuggestion(suggestion));
  }

  dismissInlineSuggestion(): void {
    this.run((api) => api.dismissInlineSuggestion());
  }

  isInlineSuggestionShowing(): boolean {
    return this.api ? this.api.isInlineSuggestionShowing() : false;
  }

  setInlineSuggestionListener(listener: InlineSuggestionListener | null): void {
    this.run((api) => api.setInlineSuggestionListener(listener));
  }

  requestDecorationRefresh(): void {
    this.run((api) => api.requestDecorationRefresh());
  }

  selectAll(): void {
    this.run((api) => api.selectAll());
  }

  getSelectedText(): string {
    return this.api ? this.api.getSelectedText() : '';
  }

  setSelection(startLineOrRange: number | TextRange, startColumn?: number, endLine?: number, endColumn?: number): void {
    this.run((api) => api.setSelection(startLineOrRange, startColumn, endLine, endColumn));
  }

  getSelection(): TextRange | null {
    return this.api ? this.api.getSelection() : null;
  }

  getCursorPosition(): TextPosition {
    return this.api ? this.api.getCursorPosition() : { line: 0, column: 0 };
  }

  getWordRangeAtCursor(): TextRange {
    return this.api ? this.api.getWordRangeAtCursor() : { start: { line: 0, column: 0 }, end: { line: 0, column: 0 } };
  }

  getWordAtCursor(): string {
    return this.api ? this.api.getWordAtCursor() : '';
  }

  setCursorPosition(position: TextPosition): void {
    this.run((api) => api.setCursorPosition(position));
  }

  gotoPosition(line: number, column: number): void {
    this.run((api) => api.gotoPosition(line, column));
  }

  scrollToLine(line: number, behavior: ScrollBehavior = ScrollBehavior.GOTO_CENTER): void {
    this.run((api) => api.scrollToLine(line, behavior));
  }

  setScroll(scrollX: number, scrollY: number): void {
    this.run((api) => api.setScroll(scrollX, scrollY));
  }

  getScrollMetrics(): ScrollMetrics {
    return this.api ? this.api.getScrollMetrics() : {
      scale: 1,
      scrollX: 0,
      scrollY: 0,
      maxScrollX: 0,
      maxScrollY: 0,
      contentSize: { width: 0, height: 0 },
      viewportSize: { width: 0, height: 0 },
      textAreaX: 0,
      textAreaWidth: 0,
      canScrollX: false,
      canScrollY: false
    };
  }

  getPositionRect(line: number, column: number): CursorRect {
    return this.api ? this.api.getPositionRect(line, column) : { x: 0, y: 0, height: 0 };
  }

  getCursorRect(): CursorRect {
    return this.api ? this.api.getCursorRect() : { x: 0, y: 0, height: 0 };
  }

  getVisibleLineRange(): IntRange {
    return this.api ? this.api.getVisibleLineRange() : { start: 0, end: -1 };
  }

  getTotalLineCount(): number {
    const api = this.getActiveApi();
    return api ? api.getTotalLineCount() : 0;
  }

  registerTextStyle(styleId: number, color: number, backgroundColorOrFontStyle: number, fontStyle?: number): void {
    this.run((api) => api.registerTextStyle(styleId, color, backgroundColorOrFontStyle, fontStyle));
  }

  registerBatchTextStyles(stylesById: Map<number, TextStyle>): void {
    this.run((api) => api.registerBatchTextStyles(stylesById));
  }

  setLineSpans(line: number, layer: SpanLayer, spans: StyleSpan[]): void {
    this.run((api) => api.setLineSpans(line, layer, spans));
  }

  setBatchLineSpans(layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): void {
    this.run((api) => api.setBatchLineSpans(layer, spansByLine));
  }

  setLineInlayHints(line: number, hints: InlayHint[]): void {
    this.run((api) => api.setLineInlayHints(line, hints));
  }

  setBatchLineInlayHints(hintsByLine: Map<number, InlayHint[]>): void {
    this.run((api) => api.setBatchLineInlayHints(hintsByLine));
  }

  setLinePhantomTexts(line: number, phantoms: PhantomText[]): void {
    this.run((api) => api.setLinePhantomTexts(line, phantoms));
  }

  setBatchLinePhantomTexts(phantomsByLine: Map<number, PhantomText[]>): void {
    this.run((api) => api.setBatchLinePhantomTexts(phantomsByLine));
  }

  setLineGutterIcons(line: number, icons: GutterIcon[]): void {
    this.run((api) => api.setLineGutterIcons(line, icons));
  }

  setBatchLineGutterIcons(iconsByLine: Map<number, GutterIcon[]>): void {
    this.run((api) => api.setBatchLineGutterIcons(iconsByLine));
  }

  setLineCodeLens(line: number, items: CodeLensItem[]): void {
    this.run((api) => api.setLineCodeLens(line, items));
  }

  setBatchLineCodeLens(itemsByLine: Map<number, CodeLensItem[]>): void {
    this.run((api) => api.setBatchLineCodeLens(itemsByLine));
  }

  setLineLinks(line: number, links: LinkSpan[]): void {
    this.run((api) => api.setLineLinks(line, links));
  }

  setBatchLineLinks(linksByLine: Map<number, LinkSpan[]>): void {
    this.run((api) => api.setBatchLineLinks(linksByLine));
  }

  getLinkTargetAt(line: number, column: number): string {
    return this.api ? this.api.getLinkTargetAt(line, column) : '';
  }

  setLineDiagnostics(line: number, items: Diagnostic[]): void {
    this.run((api) => api.setLineDiagnostics(line, items));
  }

  setBatchLineDiagnostics(diagsByLine: Map<number, Diagnostic[]>): void {
    this.run((api) => api.setBatchLineDiagnostics(diagsByLine));
  }

  setLineDocumentHighlights(line: number, items: DocumentHighlight[]): void {
    this.run((api) => api.setLineDocumentHighlights(line, items));
  }

  setBatchLineDocumentHighlights(highlightsByLine: Map<number, DocumentHighlight[]>): void {
    this.run((api) => api.setBatchLineDocumentHighlights(highlightsByLine));
  }

  setIndentGuides(guides: IndentGuide[]): void {
    this.run((api) => api.setIndentGuides(guides));
  }

  setBracketGuides(guides: BracketGuide[]): void {
    this.run((api) => api.setBracketGuides(guides));
  }

  setFlowGuides(guides: FlowGuide[]): void {
    this.run((api) => api.setFlowGuides(guides));
  }

  setSeparatorGuides(guides: SeparatorGuide[]): void {
    this.run((api) => api.setSeparatorGuides(guides));
  }

  setFoldRegions(regions: FoldRegion[]): void {
    this.run((api) => api.setFoldRegions(regions));
  }

  toggleFoldAt(line: number): void {
    this.run((api) => api.toggleFoldAt(line));
  }

  foldAt(line: number): void {
    this.run((api) => api.foldAt(line));
  }

  unfoldAt(line: number): void {
    this.run((api) => api.unfoldAt(line));
  }

  foldAll(): void {
    this.run((api) => api.foldAll());
  }

  unfoldAll(): void {
    this.run((api) => api.unfoldAll());
  }

  isLineVisible(line: number): boolean {
    return this.api ? this.api.isLineVisible(line) : true;
  }

  insertSnippet(template: string): void {
    this.run((api) => api.insertSnippet(template));
  }

  startLinkedEditing(groups: TabStopGroup[]): void {
    this.run((api) => api.startLinkedEditing(groups));
  }

  isInLinkedEditing(): boolean {
    return this.api ? this.api.isInLinkedEditing() : false;
  }

  linkedEditingNext(): void {
    this.run((api) => api.linkedEditingNext());
  }

  linkedEditingPrev(): void {
    this.run((api) => api.linkedEditingPrev());
  }

  cancelLinkedEditing(): void {
    this.run((api) => api.cancelLinkedEditing());
  }

  clearHighlights(layer?: SpanLayer): void {
    this.run((api) => api.clearHighlights(layer));
  }

  clearInlayHints(): void {
    this.run((api) => api.clearInlayHints());
  }

  clearPhantomTexts(): void {
    this.run((api) => api.clearPhantomTexts());
  }

  clearGutterIcons(): void {
    this.run((api) => api.clearGutterIcons());
  }

  clearCodeLens(): void {
    this.run((api) => api.clearCodeLens());
  }

  clearLinks(): void {
    this.run((api) => api.clearLinks());
  }

  clearGuides(): void {
    this.run((api) => api.clearGuides());
  }

  clearDiagnostics(): void {
    this.run((api) => api.clearDiagnostics());
  }

  clearDocumentHighlights(): void {
    this.run((api) => api.clearDocumentHighlights());
  }

  clearAllDecorations(): void {
    this.run((api) => api.clearAllDecorations());
  }

  copyToClipboard(): void {
    this.run((api) => api.copyToClipboard());
  }

  pasteFromClipboard(): void {
    this.run((api) => api.pasteFromClipboard());
  }

  cutToClipboard(): void {
    this.run((api) => api.cutToClipboard());
  }

  setSelectionMenuItemProvider(provider: SelectionMenuItemProvider | null): void {
    this.run((api) => api.setSelectionMenuItemProvider(provider));
  }

  onTextChanged(listener: EditorEventListener<TextChangedEvent>): void {
    this.addEventListener('textChanged', listener as EditorEventListener<EditorEvent>);
  }

  offTextChanged(listener: EditorEventListener<TextChangedEvent>): void {
    this.removeEventListener('textChanged', listener as EditorEventListener<EditorEvent>);
  }

  onCursorChanged(listener: EditorEventListener<CursorChangedEvent>): void {
    this.addEventListener('cursorChanged', listener as EditorEventListener<EditorEvent>);
  }

  offCursorChanged(listener: EditorEventListener<CursorChangedEvent>): void {
    this.removeEventListener('cursorChanged', listener as EditorEventListener<EditorEvent>);
  }

  onSelectionChanged(listener: EditorEventListener<SelectionChangedEvent>): void {
    this.addEventListener('selectionChanged', listener as EditorEventListener<EditorEvent>);
  }

  offSelectionChanged(listener: EditorEventListener<SelectionChangedEvent>): void {
    this.removeEventListener('selectionChanged', listener as EditorEventListener<EditorEvent>);
  }

  onScrollChanged(listener: EditorEventListener<ScrollChangedEvent>): void {
    this.addEventListener('scrollChanged', listener as EditorEventListener<EditorEvent>);
  }

  offScrollChanged(listener: EditorEventListener<ScrollChangedEvent>): void {
    this.removeEventListener('scrollChanged', listener as EditorEventListener<EditorEvent>);
  }

  onScaleChanged(listener: EditorEventListener<ScaleChangedEvent>): void {
    this.addEventListener('scaleChanged', listener as EditorEventListener<EditorEvent>);
  }

  offScaleChanged(listener: EditorEventListener<ScaleChangedEvent>): void {
    this.removeEventListener('scaleChanged', listener as EditorEventListener<EditorEvent>);
  }

  onLongPress(listener: EditorEventListener<LongPressEvent>): void {
    this.addEventListener('longPress', listener as EditorEventListener<EditorEvent>);
  }

  offLongPress(listener: EditorEventListener<LongPressEvent>): void {
    this.removeEventListener('longPress', listener as EditorEventListener<EditorEvent>);
  }

  onDoubleTap(listener: EditorEventListener<DoubleTapEvent>): void {
    this.addEventListener('doubleTap', listener as EditorEventListener<EditorEvent>);
  }

  offDoubleTap(listener: EditorEventListener<DoubleTapEvent>): void {
    this.removeEventListener('doubleTap', listener as EditorEventListener<EditorEvent>);
  }

  onContextMenu(listener: EditorEventListener<ContextMenuEvent>): void {
    this.addEventListener('contextMenu', listener as EditorEventListener<EditorEvent>);
  }

  offContextMenu(listener: EditorEventListener<ContextMenuEvent>): void {
    this.removeEventListener('contextMenu', listener as EditorEventListener<EditorEvent>);
  }

  onGutterIconClick(listener: EditorEventListener<GutterIconClickEvent>): void {
    this.addEventListener('gutterIconClick', listener as EditorEventListener<EditorEvent>);
  }

  offGutterIconClick(listener: EditorEventListener<GutterIconClickEvent>): void {
    this.removeEventListener('gutterIconClick', listener as EditorEventListener<EditorEvent>);
  }

  onInlayHintClick(listener: EditorEventListener<InlayHintClickEvent>): void {
    this.addEventListener('inlayHintClick', listener as EditorEventListener<EditorEvent>);
  }

  offInlayHintClick(listener: EditorEventListener<InlayHintClickEvent>): void {
    this.removeEventListener('inlayHintClick', listener as EditorEventListener<EditorEvent>);
  }

  onCodeLensClick(listener: EditorEventListener<CodeLensClickEvent>): void {
    this.addEventListener('codeLensClick', listener as EditorEventListener<EditorEvent>);
  }

  offCodeLensClick(listener: EditorEventListener<CodeLensClickEvent>): void {
    this.removeEventListener('codeLensClick', listener as EditorEventListener<EditorEvent>);
  }

  onLinkClick(listener: EditorEventListener<LinkClickEvent>): void {
    this.addEventListener('linkClick', listener as EditorEventListener<EditorEvent>);
  }

  offLinkClick(listener: EditorEventListener<LinkClickEvent>): void {
    this.removeEventListener('linkClick', listener as EditorEventListener<EditorEvent>);
  }

  onFoldToggle(listener: EditorEventListener<FoldToggleEvent>): void {
    this.addEventListener('foldToggle', listener as EditorEventListener<EditorEvent>);
  }

  offFoldToggle(listener: EditorEventListener<FoldToggleEvent>): void {
    this.removeEventListener('foldToggle', listener as EditorEventListener<EditorEvent>);
  }

  onDocumentLoaded(listener: EditorEventListener<DocumentLoadedEvent>): void {
    this.addEventListener('documentLoaded', listener as EditorEventListener<EditorEvent>);
  }

  offDocumentLoaded(listener: EditorEventListener<DocumentLoadedEvent>): void {
    this.removeEventListener('documentLoaded', listener as EditorEventListener<EditorEvent>);
  }

  onSelectionMenuItemClick(listener: EditorEventListener<SelectionMenuItemClickEvent>): void {
    this.addEventListener('selectionMenuItemClick', listener as EditorEventListener<EditorEvent>);
  }

  offSelectionMenuItemClick(listener: EditorEventListener<SelectionMenuItemClickEvent>): void {
    this.removeEventListener('selectionMenuItemClick', listener as EditorEventListener<EditorEvent>);
  }

  undo(): void {
    this.run((api) => api.undo());
  }

  redo(): void {
    this.run((api) => api.redo());
  }

  canUndo(): boolean {
    return this.api ? this.api.canUndo() : false;
  }

  canRedo(): boolean {
    return this.api ? this.api.canRedo() : false;
  }

  search(request: SearchRequest): void {
    this.run((api) => api.search(request));
  }

  findNextSearchMatch(): void {
    this.run((api) => api.findNextSearchMatch());
  }

  findPreviousSearchMatch(): void {
    this.run((api) => api.findPreviousSearchMatch());
  }

  replaceCurrentSearchMatch(replacement: string): void {
    this.run((api) => api.replaceCurrentSearchMatch(replacement));
  }

  replaceAllSearchMatches(replacement: string): void {
    this.run((api) => api.replaceAllSearchMatches(replacement));
  }

  clearSearch(): void {
    this.run((api) => api.clearSearch());
  }

  getSearchState(): SearchState {
    return this.api ? this.api.getSearchState() : createEmptySearchState();
  }

  setPerfOverlayEnabled(enabled: boolean): void {
    this.run((api) => api.setPerfOverlayEnabled(enabled));
  }

  isPerfOverlayEnabled(): boolean {
    return this.api ? this.api.isPerfOverlayEnabled() : false;
  }

  flush(): void {
    this.run((api) => api.flush());
  }

  private addEventListener(type: string, listener: EditorEventListener<EditorEvent>): void {
    if (this.inactive) {
      return;
    }
    let listeners = this.eventListeners.get(type);
    if (!listeners) {
      listeners = [];
      this.eventListeners.set(type, listeners);
    }
    if (listeners.includes(listener)) {
      return;
    }
    listeners.push(listener);
    if (this.api) {
      this.attachEventListener(this.api, type, listener);
    }
  }

  private removeEventListener(type: string, listener: EditorEventListener<EditorEvent>): void {
    const listeners = this.eventListeners.get(type);
    if (listeners) {
      const index = listeners.indexOf(listener);
      if (index >= 0) {
        listeners.splice(index, 1);
      }
      if (listeners.length === 0) {
        this.eventListeners.delete(type);
      }
    }
    if (this.api) {
      this.detachEventListener(this.api, type, listener);
    }
  }

  private attachStoredEventListeners(api: SweetEditor): void {
    this.eventListeners.forEach((listeners, type): void => {
      for (const listener of listeners) {
        this.attachEventListener(api, type, listener);
      }
    });
  }

  private attachEventListener(api: SweetEditor, type: string, listener: EditorEventListener<EditorEvent>): void {
    switch (type) {
      case 'textChanged':
        api.onTextChanged(listener as EditorEventListener<TextChangedEvent>);
        break;
      case 'cursorChanged':
        api.onCursorChanged(listener as EditorEventListener<CursorChangedEvent>);
        break;
      case 'selectionChanged':
        api.onSelectionChanged(listener as EditorEventListener<SelectionChangedEvent>);
        break;
      case 'scrollChanged':
        api.onScrollChanged(listener as EditorEventListener<ScrollChangedEvent>);
        break;
      case 'scaleChanged':
        api.onScaleChanged(listener as EditorEventListener<ScaleChangedEvent>);
        break;
      case 'longPress':
        api.onLongPress(listener as EditorEventListener<LongPressEvent>);
        break;
      case 'doubleTap':
        api.onDoubleTap(listener as EditorEventListener<DoubleTapEvent>);
        break;
      case 'contextMenu':
        api.onContextMenu(listener as EditorEventListener<ContextMenuEvent>);
        break;
      case 'gutterIconClick':
        api.onGutterIconClick(listener as EditorEventListener<GutterIconClickEvent>);
        break;
      case 'inlayHintClick':
        api.onInlayHintClick(listener as EditorEventListener<InlayHintClickEvent>);
        break;
      case 'codeLensClick':
        api.onCodeLensClick(listener as EditorEventListener<CodeLensClickEvent>);
        break;
      case 'linkClick':
        api.onLinkClick(listener as EditorEventListener<LinkClickEvent>);
        break;
      case 'foldToggle':
        api.onFoldToggle(listener as EditorEventListener<FoldToggleEvent>);
        break;
      case 'documentLoaded':
        api.onDocumentLoaded(listener as EditorEventListener<DocumentLoadedEvent>);
        break;
      case 'selectionMenuItemClick':
        api.onSelectionMenuItemClick(listener as EditorEventListener<SelectionMenuItemClickEvent>);
        break;
    }
  }

  private detachEventListener(api: SweetEditor, type: string, listener: EditorEventListener<EditorEvent>): void {
    switch (type) {
      case 'textChanged':
        api.offTextChanged(listener as EditorEventListener<TextChangedEvent>);
        break;
      case 'cursorChanged':
        api.offCursorChanged(listener as EditorEventListener<CursorChangedEvent>);
        break;
      case 'selectionChanged':
        api.offSelectionChanged(listener as EditorEventListener<SelectionChangedEvent>);
        break;
      case 'scrollChanged':
        api.offScrollChanged(listener as EditorEventListener<ScrollChangedEvent>);
        break;
      case 'scaleChanged':
        api.offScaleChanged(listener as EditorEventListener<ScaleChangedEvent>);
        break;
      case 'longPress':
        api.offLongPress(listener as EditorEventListener<LongPressEvent>);
        break;
      case 'doubleTap':
        api.offDoubleTap(listener as EditorEventListener<DoubleTapEvent>);
        break;
      case 'contextMenu':
        api.offContextMenu(listener as EditorEventListener<ContextMenuEvent>);
        break;
      case 'gutterIconClick':
        api.offGutterIconClick(listener as EditorEventListener<GutterIconClickEvent>);
        break;
      case 'inlayHintClick':
        api.offInlayHintClick(listener as EditorEventListener<InlayHintClickEvent>);
        break;
      case 'codeLensClick':
        api.offCodeLensClick(listener as EditorEventListener<CodeLensClickEvent>);
        break;
      case 'linkClick':
        api.offLinkClick(listener as EditorEventListener<LinkClickEvent>);
        break;
      case 'foldToggle':
        api.offFoldToggle(listener as EditorEventListener<FoldToggleEvent>);
        break;
      case 'documentLoaded':
        api.offDocumentLoaded(listener as EditorEventListener<DocumentLoadedEvent>);
        break;
      case 'selectionMenuItemClick':
        api.offSelectionMenuItemClick(listener as EditorEventListener<SelectionMenuItemClickEvent>);
        break;
    }
  }

  private run(action: (api: SweetEditor) => void): void {
    const api = this.getActiveApi();
    if (!api) {
      return;
    }
    action(api);
  }

  private getActiveApi(): SweetEditor | null {
    if (this.inactive) {
      return null;
    }
    return this.api;
  }
}
