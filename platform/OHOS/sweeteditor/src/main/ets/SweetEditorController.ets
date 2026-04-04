import { Document, TextEditResult } from './core/EditorCore';
import { ScrollBehavior, TextPosition, TextRange } from './core/CoreFoundation';
import { CursorRect, ScrollMetrics } from './core/CoreVisual';
import {
  BracketGuide,
  DiagnosticItem,
  FlowGuide,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  PhantomText,
  SeparatorGuide,
  SpanLayer,
  StyleSpan,
  TextStyle
} from './core/CoreAdornments';
import { LinkedEditingModel } from './core/CoreLinkedEditing';
import { EditorIconProvider, EditorMetadata, EditorTheme, LanguageConfiguration } from './EditorTypes';
import { EditorKeyMap } from './EditorKeymap';
import { EditorSettings } from './EditorSettings';
import {
  ContextMenuEvent,
  CursorChangedEvent,
  DocumentLoadedEvent,
  DoubleTapEvent,
  EditorEvent,
  EditorEventListener,
  FoldToggleEvent,
  GutterIconClickEvent,
  InlayHintClickEvent,
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
  private pendingActions: Array<(api: SweetEditor) => void> = [];
  private eventListeners: Map<string, EditorEventListener<EditorEvent>[]> = new Map();
  private readyListeners: Array<() => void> = [];
  private document: Document | null = null;
  private theme: EditorTheme | null = null;
  private languageConfiguration: LanguageConfiguration | null = null;
  private metadata: EditorMetadata | null = null;
  private iconProvider: EditorIconProvider | null = null;
  private keyMap: EditorKeyMap = EditorKeyMap.defaultKeyMap();

  bind(api: SweetEditor): void {
    this.api = api;
    this.attachStoredEventListeners(api);
    if (this.document) {
      api.loadDocument(this.document);
    }
    if (this.theme) {
      api.applyTheme(this.theme);
    }
    api.setKeyMap(this.keyMap);
    api.setLanguageConfiguration(this.languageConfiguration);
    api.setMetadata(this.metadata);
    api.setEditorIconProvider(this.iconProvider);
    const actions = [...this.pendingActions];
    this.pendingActions = [];
    for (const action of actions) {
      action(api);
    }
    const listeners = [...this.readyListeners];
    this.readyListeners = [];
    for (const listener of listeners) {
      listener();
    }
  }

  unbind(api: SweetEditor): void {
    if (this.api === api) {
      this.eventListeners.forEach((listeners, type) => {
        for (const listener of listeners) {
          this.detachEventListener(api, type, listener);
        }
      });
      this.api = null;
    }
  }

  whenReady(listener: () => void): void {
    if (this.api) {
      listener();
      return;
    }
    this.readyListeners.push(listener);
  }

  loadDocument(document: Document): void {
    this.document = document;
    if (this.api) {
      this.api.loadDocument(document);
      return;
    }
  }

  getDocument(): Document | null {
    return this.api ? this.api.getDocument() : this.document;
  }

  getSettings(): EditorSettings | null {
    return this.api ? this.api.getSettings() : null;
  }

  applyTheme(theme: EditorTheme): void {
    this.theme = theme;
    if (this.api) {
      this.api.applyTheme(theme);
    }
  }

  getTheme(): EditorTheme | null {
    return this.api ? this.api.getTheme() : this.theme;
  }

  setLanguageConfiguration(config: LanguageConfiguration | null): void {
    this.languageConfiguration = config;
    if (this.api) {
      this.api.setLanguageConfiguration(config);
    }
  }

  getLanguageConfiguration(): LanguageConfiguration | null {
    return this.api ? this.api.getLanguageConfiguration() : this.languageConfiguration;
  }

  setMetadata(metadata: EditorMetadata | null): void {
    this.metadata = metadata;
    if (this.api) {
      this.api.setMetadata(metadata);
    }
  }

  getMetadata(): EditorMetadata | null {
    return this.api ? this.api.getMetadata() : this.metadata;
  }

  setEditorIconProvider(provider: EditorIconProvider | null): void {
    this.iconProvider = provider;
    if (this.api) {
      this.api.setEditorIconProvider(provider);
    }
  }

  getKeyMap(): EditorKeyMap {
    return this.keyMap;
  }

  setKeyMap(keyMap: EditorKeyMap): void {
    this.keyMap = keyMap;
    if (this.api) {
      this.api.setKeyMap(keyMap);
    }
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

  insertText(text: string): TextEditResult | null {
    return this.api ? this.api.insertText(text) : null;
  }

  replaceText(range: TextRange, newText: string): TextEditResult | null {
    return this.api ? this.api.replaceText(range, newText) : null;
  }

  deleteText(range: TextRange): TextEditResult | null {
    return this.api ? this.api.deleteText(range) : null;
  }

  moveLineUp(): TextEditResult | null {
    return this.api ? this.api.moveLineUp() : null;
  }

  moveLineDown(): TextEditResult | null {
    return this.api ? this.api.moveLineDown() : null;
  }

  copyLineUp(): TextEditResult | null {
    return this.api ? this.api.copyLineUp() : null;
  }

  copyLineDown(): TextEditResult | null {
    return this.api ? this.api.copyLineDown() : null;
  }

  deleteLine(): TextEditResult | null {
    return this.api ? this.api.deleteLine() : null;
  }

  insertLineAbove(): TextEditResult | null {
    return this.api ? this.api.insertLineAbove() : null;
  }

  insertLineBelow(): TextEditResult | null {
    return this.api ? this.api.insertLineBelow() : null;
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

  scrollToLine(line: number, behavior: ScrollBehavior = ScrollBehavior.CENTER): void {
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
      contentWidth: 0,
      contentHeight: 0,
      viewportWidth: 0,
      viewportHeight: 0,
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

  getVisibleLineRange(): number[] {
    return this.api ? this.api.getVisibleLineRange() : [0, -1];
  }

  getTotalLineCount(): number {
    return this.api ? this.api.getTotalLineCount() : (this.document ? this.document.getLineCount() : 0);
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

  setLineDiagnostics(line: number, items: DiagnosticItem[]): void {
    this.run((api) => api.setLineDiagnostics(line, items));
  }

  setBatchLineDiagnostics(diagsByLine: Map<number, DiagnosticItem[]>): void {
    this.run((api) => api.setBatchLineDiagnostics(diagsByLine));
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

  toggleFoldAt(line: number): boolean {
    return this.api ? this.api.toggleFoldAt(line) : false;
  }

  foldAt(line: number): boolean {
    return this.api ? this.api.foldAt(line) : false;
  }

  unfoldAt(line: number): boolean {
    return this.api ? this.api.unfoldAt(line) : false;
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

  insertSnippet(template: string): TextEditResult | null {
    return this.api ? this.api.insertSnippet(template) : null;
  }

  startLinkedEditing(model: LinkedEditingModel): void {
    this.run((api) => api.startLinkedEditing(model));
  }

  isInLinkedEditing(): boolean {
    return this.api ? this.api.isInLinkedEditing() : false;
  }

  linkedEditingNext(): boolean {
    return this.api ? this.api.linkedEditingNext() : false;
  }

  linkedEditingPrev(): boolean {
    return this.api ? this.api.linkedEditingPrev() : false;
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

  clearGuides(): void {
    this.run((api) => api.clearGuides());
  }

  clearDiagnostics(): void {
    this.run((api) => api.clearDiagnostics());
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

  undo(): TextEditResult | null {
    return this.api ? this.api.undo() : null;
  }

  redo(): TextEditResult | null {
    return this.api ? this.api.redo() : null;
  }

  canUndo(): boolean {
    return this.api ? this.api.canUndo() : false;
  }

  canRedo(): boolean {
    return this.api ? this.api.canRedo() : false;
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
    this.eventListeners.forEach((listeners, type) => {
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
    if (this.api) {
      action(this.api);
      return;
    }
    this.pendingActions.push(action);
  }
}
