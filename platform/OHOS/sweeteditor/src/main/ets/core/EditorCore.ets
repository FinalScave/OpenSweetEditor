import native from 'libsweeteditor.so';
import { ProtocolDecoder, ProtocolEncoder } from './CoreProtocol';
import {
  AutoIndentMode,
  CurrentLineRenderMode,
  FoldArrowMode,
  ScrollBehavior,
  TextPosition,
  TextRange,
  WrapMode
} from './CoreFoundation';
import { KeyMap } from './CoreKeymap';
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
} from './CoreAdornments';
import { CursorRect, EditorRenderModel, PointF, ScrollMetrics } from './CoreVisual';
import { LinkedEditingModel } from './CoreLinkedEditing';

export enum EventType {
  UNDEFINED = 0,
  TOUCH_DOWN = 1,
  TOUCH_POINTER_DOWN = 2,
  TOUCH_MOVE = 3,
  TOUCH_POINTER_UP = 4,
  TOUCH_UP = 5,
  TOUCH_CANCEL = 6,
  MOUSE_DOWN = 7,
  MOUSE_MOVE = 8,
  MOUSE_UP = 9,
  MOUSE_WHEEL = 10,
  MOUSE_RIGHT_DOWN = 11,
  DIRECT_SCALE = 12,
  DIRECT_SCROLL = 13
}

export enum Modifier {
  NONE = 0,
  SHIFT = 1,
  CTRL = 2,
  ALT = 4,
  META = 8
}

export enum GestureType {
  UNDEFINED = 0,
  TAP = 1,
  DOUBLE_TAP = 2,
  LONG_PRESS = 3,
  SCALE = 4,
  SCROLL = 5,
  FAST_SCROLL = 6,
  DRAG_SELECT = 7,
  CONTEXT_MENU = 8
}

export enum HitTargetType {
  NONE = 0,
  INLAY_HINT_TEXT = 1,
  INLAY_HINT_ICON = 2,
  GUTTER_ICON = 3,
  FOLD_PLACEHOLDER = 4,
  FOLD_GUTTER = 5,
  INLAY_HINT_COLOR = 6
}

export enum ScrollbarMode {
  ALWAYS = 0,
  TRANSIENT = 1,
  NEVER = 2
}

export enum ScrollbarTrackTapMode {
  JUMP = 0,
  DISABLED = 1
}

export enum EditorEventType {
  TextChanged,
  CursorChanged,
  SelectionChanged,
  ScrollChanged,
  ScaleChanged,
  LongPress,
  DoubleTap,
  ContextMenu,
  GutterIconClick,
  InlayHintClick,
  FoldToggle
}

export interface TextChange {
  range: TextRange;
  newText: string;
}

export interface TextEditResult {
  changes: TextChange[];
}

export interface HitTarget {
  type: HitTargetType;
  line: number;
  column: number;
  iconId: number;
  colorValue: number;
}

export interface GestureResult {
  type: GestureType;
  tapPoint: PointF;
  cursorPosition: TextPosition;
  hasSelection: boolean;
  selection: TextRange;
  viewScrollX: number;
  viewScrollY: number;
  viewScale: number;
  hitTarget: HitTarget;
  isHandleDrag: boolean;
  needsEdgeScroll: boolean;
  needsFling: boolean;
  needsAnimation: boolean;
}

export interface KeyEventResult {
  handled: boolean;
  contentChanged: boolean;
  cursorChanged: boolean;
  selectionChanged: boolean;
  editResult: TextEditResult | null;
  command: number;
}

export interface GestureEvent {
  type: EventType;
  points: PointF[];
  modifiers: Modifier;
  wheelDeltaX: number;
  wheelDeltaY: number;
  directScale: number;
}

export class EditorOptions {
  touchSlop: number = 10;
  doubleTapTimeout: number = 300;
  longPressMs: number = 500;
  flingFriction: number = 2.0;
  flingMinVelocity: number = 30;
  flingMaxVelocity: number = 12000;
  maxUndoStackSize: number = 512;
}

export class HandleConfig {
  // Offset rects are relative to the cursor bottom anchor (the handle tip).
  startLeft: number = -32.1;
  startTop: number = -8.0;
  startRight: number = 8.0;
  startBottom: number = 32.1;
  endLeft: number = -8.0;
  endTop: number = -8.0;
  endRight: number = 32.1;
  endBottom: number = 32.1;
}

export class ScrollbarConfig {
  thickness: number = 10.0;
  minThumb: number = 24.0;
  thumbHitPadding: number = 0.0;
  mode: ScrollbarMode = ScrollbarMode.ALWAYS;
  thumbDraggable: boolean = true;
  trackTapMode: ScrollbarTrackTapMode = ScrollbarTrackTapMode.JUMP;
  fadeDelayMs: number = 700;
  fadeDurationMs: number = 300;
}

export class Document {
  private handle: number = 0;

  static fromString(text: string): Document {
    const doc = new Document();
    doc.handle = native.createDocumentFromString(text);
    return doc;
  }

  static fromFile(path: string): Document {
    const doc = new Document();
    doc.handle = native.createDocumentFromFile(path);
    return doc;
  }

  getHandle(): number {
    return this.handle;
  }

  getText(): string {
    if (this.handle === 0) {
      return '';
    }
    return native.getDocumentText(this.handle);
  }

  getLineCount(): number {
    if (this.handle === 0) {
      return 0;
    }
    return native.getDocumentLineCount(this.handle);
  }

  getLineText(line: number): string {
    if (this.handle === 0) {
      return '';
    }
    return native.getDocumentLineText(this.handle, line);
  }

  destroy(): void {
    if (this.handle !== 0) {
      native.freeDocument(this.handle);
      this.handle = 0;
    }
  }
}

export class EditorCore {
  private handle: number = 0;
  private document: Document | null = null;
  private handleConfig: HandleConfig = new HandleConfig();
  private scrollbarConfig: ScrollbarConfig = new ScrollbarConfig();

  // ==================== Construction/Initialization/Lifecycle ====================

  constructor(measurer: native.TextMeasurer, options?: EditorOptions) {
    const optionsData = options ? ProtocolEncoder.packEditorOptions(options) : undefined;
    this.handle = native.createEditor(measurer, optionsData);
  }

  getHandle(): number {
    return this.handle;
  }

  destroy(): void {
    if (this.handle !== 0) {
      native.freeEditor(this.handle);
      this.handle = 0;
    }
    this.document = null;
  }

  loadDocument(doc: Document): void {
    this.document = doc;
    native.setEditorDocument(this.handle, doc.getHandle());
  }

  getDocument(): Document | null {
    return this.document;
  }

  // ==================== Viewport/Font/Appearance Configuration ====================

  setViewport(width: number, height: number): void {
    native.setEditorViewport(this.handle, width, height);
  }

  onFontMetricsChanged(): void {
    native.editorOnFontMetricsChanged(this.handle);
  }

  setFoldArrowMode(mode: FoldArrowMode): void {
    native.editorSetFoldArrowMode(this.handle, mode as number);
  }

  setWrapMode(mode: WrapMode): void {
    native.editorSetWrapMode(this.handle, mode as number);
  }

  setTabSize(tabSize: number): void {
    native.editorSetTabSize(this.handle, tabSize);
  }

  setInsertSpaces(enabled: boolean): void {
    native.editorSetInsertSpaces(this.handle, enabled ? 1 : 0);
  }

  setKeyMap(keyMap: KeyMap): void {
    const data = keyMap.toArrayBuffer();
    native.editorSetKeyMap(this.handle, data, data.byteLength);
  }

  setScale(scale: number): void {
    native.editorSetScale(this.handle, scale);
  }

  setLineSpacing(add: number, mult: number): void {
    native.editorSetLineSpacing(this.handle, add, mult);
  }

  setContentStartPadding(padding: number): void {
    native.editorSetContentStartPadding(this.handle, padding);
  }

  setShowSplitLine(show: boolean): void {
    native.editorSetShowSplitLine(this.handle, show);
  }

  setGutterSticky(sticky: boolean): void {
    native.editorSetGutterSticky(this.handle, sticky);
  }

  setGutterVisible(visible: boolean): void {
    native.editorSetGutterVisible(this.handle, visible);
  }

  setCurrentLineRenderMode(mode: CurrentLineRenderMode): void {
    native.editorSetCurrentLineRenderMode(this.handle, mode as number);
  }

  // ==================== Rendering ====================

  buildRenderModel(): EditorRenderModel {
    const payload = native.buildEditorRenderModel(this.handle);
    return ProtocolDecoder.decodeRenderModel(payload);
  }

  getLayoutMetrics(): ArrayBuffer | undefined {
    return native.getLayoutMetrics(this.handle);
  }

  // ==================== Gesture/Keyboard Event Handling ====================

  handleGestureEvent(event: GestureEvent): GestureResult {
    const pointsArray: number[] = [];
    for (const p of event.points) {
      pointsArray.push(p.x, p.y);
    }
    const payload = native.handleEditorGestureEventEx(
      this.handle,
      event.type as number,
      event.points.length,
      pointsArray,
      event.modifiers as number,
      event.wheelDeltaX,
      event.wheelDeltaY,
      event.directScale
    );
    return ProtocolDecoder.decodeGestureResult(payload);
  }

  handleGestureEventEx(event: GestureEvent): GestureResult {
    return this.handleGestureEvent(event);
  }

  handleSimpleGestureEvent(type: EventType, pointerCount: number, points: number[]): GestureResult {
    const payload = native.handleEditorGestureEvent(this.handle, type as number, pointerCount, points);
    return ProtocolDecoder.decodeGestureResult(payload);
  }

  tickEdgeScroll(): GestureResult {
    return ProtocolDecoder.decodeGestureResult(native.editorTickEdgeScroll(this.handle));
  }

  tickFling(): GestureResult {
    return ProtocolDecoder.decodeGestureResult(native.editorTickFling(this.handle));
  }

  tickAnimations(): GestureResult {
    return ProtocolDecoder.decodeGestureResult(native.editorTickAnimations(this.handle));
  }

  handleKeyEvent(keyCode: number, text: string | null, modifiers: number): KeyEventResult {
    const payload = native.handleEditorKeyEvent(this.handle, keyCode, text, modifiers);
    return ProtocolDecoder.decodeKeyEventResult(payload);
  }

  // ==================== Text Editing ====================

  insertText(text: string): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorInsertText(this.handle, text));
  }

  replaceText(startLine: number, startColumn: number, endLine: number, endColumn: number,
    text: string): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(
      native.editorReplaceText(this.handle, startLine, startColumn, endLine, endColumn, text)
    );
  }

  deleteText(startLine: number, startColumn: number, endLine: number, endColumn: number): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(
      native.editorDeleteText(this.handle, startLine, startColumn, endLine, endColumn)
    );
  }

  backspace(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorBackspace(this.handle));
  }

  deleteForward(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorDeleteForward(this.handle));
  }

  // ==================== Line Operations ====================

  moveLineUp(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorMoveLineUp(this.handle));
  }

  moveLineDown(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorMoveLineDown(this.handle));
  }

  copyLineUp(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorCopyLineUp(this.handle));
  }

  copyLineDown(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorCopyLineDown(this.handle));
  }

  deleteLine(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorDeleteLine(this.handle));
  }

  insertLineAbove(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorInsertLineAbove(this.handle));
  }

  insertLineBelow(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorInsertLineBelow(this.handle));
  }

  // ==================== Undo/Redo ====================

  undo(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorUndo(this.handle));
  }

  redo(): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorRedo(this.handle));
  }

  canUndo(): boolean {
    return native.editorCanUndo(this.handle);
  }

  canRedo(): boolean {
    return native.editorCanRedo(this.handle);
  }

  // ==================== Cursor/Selection Management ====================

  getCursorPosition(): TextPosition {
    const arr = native.editorGetCursorPosition(this.handle);
    return { line: arr[0], column: arr[1] };
  }

  getWordRangeAtCursor(): TextRange {
    const arr = native.editorGetWordRangeAtCursor(this.handle);
    return {
      start: { line: arr[0], column: arr[1] },
      end: { line: arr[2], column: arr[3] }
    };
  }

  getWordAtCursor(): string {
    return native.editorGetWordAtCursor(this.handle);
  }

  setCursorPosition(line: number, column: number): void {
    native.editorSetCursorPosition(this.handle, line, column);
  }

  selectAll(): void {
    native.editorSelectAll(this.handle);
  }

  setSelection(startLineOrRange: number | TextRange, startColumn?: number, endLine?: number, endColumn?: number): void {
    if (typeof startLineOrRange === 'number') {
      native.editorSetSelection(
        this.handle,
        startLineOrRange,
        startColumn ?? 0,
        endLine ?? startLineOrRange,
        endColumn ?? (startColumn ?? 0));
      return;
    }
    native.editorSetSelection(
      this.handle,
      startLineOrRange.start.line,
      startLineOrRange.start.column,
      startLineOrRange.end.line,
      startLineOrRange.end.column);
  }

  getSelection(): TextRange | null {
    const arr = native.editorGetSelection(this.handle);
    if (arr === null) {
      return null;
    }
    return {
      start: { line: arr[0], column: arr[1] },
      end: { line: arr[2], column: arr[3] }
    };
  }

  getSelectedText(): string {
    return native.editorGetSelectedText(this.handle);
  }

  moveCursorLeft(extendSelection: boolean = false): void {
    native.editorMoveCursorLeft(this.handle, extendSelection);
  }

  moveCursorRight(extendSelection: boolean = false): void {
    native.editorMoveCursorRight(this.handle, extendSelection);
  }

  moveCursorUp(extendSelection: boolean = false): void {
    native.editorMoveCursorUp(this.handle, extendSelection);
  }

  moveCursorDown(extendSelection: boolean = false): void {
    native.editorMoveCursorDown(this.handle, extendSelection);
  }

  moveCursorToLineStart(extendSelection: boolean = false): void {
    native.editorMoveCursorToLineStart(this.handle, extendSelection);
  }

  moveCursorToLineEnd(extendSelection: boolean = false): void {
    native.editorMoveCursorToLineEnd(this.handle, extendSelection);
  }

  // ==================== IME Composition Input ====================

  compositionStart(): void {
    native.editorCompositionStart(this.handle);
  }

  compositionUpdate(text: string | null): void {
    native.editorCompositionUpdate(this.handle, text);
  }

  compositionEnd(committedText?: string | null): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorCompositionEnd(this.handle, committedText));
  }

  compositionCancel(): void {
    native.editorCompositionCancel(this.handle);
  }

  isComposing(): boolean {
    return native.editorIsComposing(this.handle);
  }

  setCompositionEnabled(enabled: boolean): void {
    native.editorSetCompositionEnabled(this.handle, enabled);
  }

  isCompositionEnabled(): boolean {
    return native.editorIsCompositionEnabled(this.handle);
  }

  // ==================== Read-Only Mode ====================

  setReadOnly(readOnly: boolean): void {
    native.editorSetReadOnly(this.handle, readOnly);
  }

  isReadOnly(): boolean {
    return native.editorIsReadOnly(this.handle);
  }

  // ==================== Auto Indent ====================

  setAutoIndentMode(mode: AutoIndentMode): void {
    native.editorSetAutoIndentMode(this.handle, mode as number);
  }

  getAutoIndentMode(): number {
    return native.editorGetAutoIndentMode(this.handle);
  }

  setBackspaceUnindent(enabled: boolean): void {
    native.editorSetBackspaceUnindent(this.handle, enabled ? 1 : 0);
  }

  // ==================== Handle Config ====================

  setHandleConfig(config: HandleConfig): void {
    this.handleConfig = config;
    native.editorSetHandleConfig(this.handle,
      config.startLeft, config.startTop, config.startRight, config.startBottom,
      config.endLeft, config.endTop, config.endRight, config.endBottom);
  }

  getHandleConfig(): HandleConfig {
    return this.handleConfig;
  }

  // ==================== Scrollbar Config ====================

  setScrollbarConfig(config: ScrollbarConfig): void {
    this.scrollbarConfig = config;
    native.editorSetScrollbarConfig(this.handle,
      config.thickness, config.minThumb, config.thumbHitPadding,
      config.mode as number, config.thumbDraggable,
      config.trackTapMode as number, config.fadeDelayMs, config.fadeDurationMs);
  }

  getScrollbarConfig(): ScrollbarConfig {
    return this.scrollbarConfig;
  }

  // ==================== Position Coordinate Query ====================

  getPositionRect(line: number, column: number): CursorRect {
    const arr = native.editorGetPositionRect(this.handle, line, column);
    return { x: arr[0], y: arr[1], height: arr[2] };
  }

  getCursorRect(): CursorRect {
    const arr = native.editorGetCursorRect(this.handle);
    return { x: arr[0], y: arr[1], height: arr[2] };
  }

  // ==================== Scroll/Navigation ====================

  scrollToLine(line: number, behavior: ScrollBehavior = ScrollBehavior.CENTER): void {
    native.editorScrollToLine(this.handle, line, behavior as number);
  }

  gotoPosition(line: number, column: number): void {
    native.editorGotoPosition(this.handle, line, column);
  }

  ensureCursorVisible(): void {
    native.editorEnsureCursorVisible(this.handle);
  }

  setScroll(scrollX: number, scrollY: number): void {
    native.editorSetScroll(this.handle, scrollX, scrollY);
  }

  getScrollMetrics(): ScrollMetrics {
    return ProtocolDecoder.decodeScrollMetrics(native.editorGetScrollMetrics(this.handle));
  }

  // ==================== Style Registration + Highlight Spans ====================

  registerTextStyle(styleId: number, color: number, backgroundColorOrFontStyle: number, fontStyle?: number): void {
    const backgroundColor = fontStyle === undefined ? 0 : backgroundColorOrFontStyle;
    const resolvedFontStyle = fontStyle === undefined ? backgroundColorOrFontStyle : fontStyle;
    native.editorRegisterTextStyle(this.handle, styleId, color, backgroundColor, resolvedFontStyle);
  }

  registerBatchTextStyles(stylesByIdOrData: Map<number, TextStyle> | ArrayBuffer, _size?: number): void {
    if (stylesByIdOrData instanceof ArrayBuffer) {
      native.editorRegisterBatchTextStyles(this.handle, stylesByIdOrData, stylesByIdOrData.byteLength);
      return;
    }
    if (stylesByIdOrData.size === 0) {
      return;
    }
    const data = ProtocolEncoder.packBatchTextStyles(stylesByIdOrData);
    native.editorRegisterBatchTextStyles(this.handle, data, data.byteLength);
  }

  setLineSpans(lineOrData: number | ArrayBuffer, layerOrSize: number, spans?: StyleSpan[]): void {
    if (lineOrData instanceof ArrayBuffer) {
      native.editorSetLineSpans(this.handle, lineOrData, lineOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packLineSpans(lineOrData, layerOrSize, spans ?? []);
    native.editorSetLineSpans(this.handle, data, data.byteLength);
  }

  setBatchLineSpans(layerOrData: number | ArrayBuffer, spansByLineOrSize: Map<number, StyleSpan[]> | number): void {
    if (layerOrData instanceof ArrayBuffer) {
      native.editorSetBatchLineSpans(this.handle, layerOrData, layerOrData.byteLength);
      return;
    }
    if (!(spansByLineOrSize instanceof Map) || spansByLineOrSize.size === 0) {
      return;
    }
    const data = ProtocolEncoder.packBatchLineSpans(layerOrData, spansByLineOrSize);
    native.editorSetBatchLineSpans(this.handle, data, data.byteLength);
  }

  clearLineSpans(line: number, layer: SpanLayer): void {
    native.editorClearLineSpans(this.handle, line, layer as number);
  }

  // ==================== InlayHint / PhantomText ====================

  setLineInlayHints(lineOrData: number | ArrayBuffer, hintsOrSize: InlayHint[] | number): void {
    if (lineOrData instanceof ArrayBuffer) {
      native.editorSetLineInlayHints(this.handle, lineOrData, lineOrData.byteLength);
      return;
    }
    if (!Array.isArray(hintsOrSize)) {
      return;
    }
    const data = ProtocolEncoder.packLineInlayHints(lineOrData, hintsOrSize);
    native.editorSetLineInlayHints(this.handle, data, data.byteLength);
  }

  setBatchLineInlayHints(hintsByLineOrData: Map<number, InlayHint[]> | ArrayBuffer, _size?: number): void {
    if (hintsByLineOrData instanceof ArrayBuffer) {
      native.editorSetBatchLineInlayHints(this.handle, hintsByLineOrData, hintsByLineOrData.byteLength);
      return;
    }
    if (hintsByLineOrData.size === 0) {
      return;
    }
    const data = ProtocolEncoder.packBatchLineInlayHints(hintsByLineOrData);
    native.editorSetBatchLineInlayHints(this.handle, data, data.byteLength);
  }

  setLinePhantomTexts(lineOrData: number | ArrayBuffer, phantomsOrSize: PhantomText[] | number): void {
    if (lineOrData instanceof ArrayBuffer) {
      native.editorSetLinePhantomTexts(this.handle, lineOrData, lineOrData.byteLength);
      return;
    }
    if (!Array.isArray(phantomsOrSize)) {
      return;
    }
    const data = ProtocolEncoder.packLinePhantomTexts(lineOrData, phantomsOrSize);
    native.editorSetLinePhantomTexts(this.handle, data, data.byteLength);
  }

  setBatchLinePhantomTexts(phantomsByLineOrData: Map<number, PhantomText[]> | ArrayBuffer, _size?: number): void {
    if (phantomsByLineOrData instanceof ArrayBuffer) {
      native.editorSetBatchLinePhantomTexts(this.handle, phantomsByLineOrData, phantomsByLineOrData.byteLength);
      return;
    }
    if (phantomsByLineOrData.size === 0) {
      return;
    }
    const data = ProtocolEncoder.packBatchLinePhantomTexts(phantomsByLineOrData);
    native.editorSetBatchLinePhantomTexts(this.handle, data, data.byteLength);
  }

  // ==================== Gutter Icons ====================

  setLineGutterIcons(lineOrData: number | ArrayBuffer, iconsOrSize: GutterIcon[] | number): void {
    if (lineOrData instanceof ArrayBuffer) {
      native.editorSetLineGutterIcons(this.handle, lineOrData, lineOrData.byteLength);
      return;
    }
    if (!Array.isArray(iconsOrSize)) {
      return;
    }
    const data = ProtocolEncoder.packLineGutterIcons(lineOrData, iconsOrSize);
    native.editorSetLineGutterIcons(this.handle, data, data.byteLength);
  }

  setBatchLineGutterIcons(iconsByLineOrData: Map<number, GutterIcon[]> | ArrayBuffer, _size?: number): void {
    if (iconsByLineOrData instanceof ArrayBuffer) {
      native.editorSetBatchLineGutterIcons(this.handle, iconsByLineOrData, iconsByLineOrData.byteLength);
      return;
    }
    if (iconsByLineOrData.size === 0) {
      return;
    }
    const data = ProtocolEncoder.packBatchLineGutterIcons(iconsByLineOrData);
    native.editorSetBatchLineGutterIcons(this.handle, data, data.byteLength);
  }

  setMaxGutterIcons(count: number): void {
    native.editorSetMaxGutterIcons(this.handle, count);
  }

  // ==================== Diagnostic Decorations ====================

  setLineDiagnostics(lineOrData: number | ArrayBuffer, itemsOrSize: DiagnosticItem[] | number): void {
    if (lineOrData instanceof ArrayBuffer) {
      native.editorSetLineDiagnostics(this.handle, lineOrData, lineOrData.byteLength);
      return;
    }
    if (!Array.isArray(itemsOrSize)) {
      return;
    }
    const data = ProtocolEncoder.packLineDiagnostics(lineOrData, itemsOrSize);
    native.editorSetLineDiagnostics(this.handle, data, data.byteLength);
  }

  setBatchLineDiagnostics(diagsByLineOrData: Map<number, DiagnosticItem[]> | ArrayBuffer, _size?: number): void {
    if (diagsByLineOrData instanceof ArrayBuffer) {
      native.editorSetBatchLineDiagnostics(this.handle, diagsByLineOrData, diagsByLineOrData.byteLength);
      return;
    }
    if (diagsByLineOrData.size === 0) {
      return;
    }
    const data = ProtocolEncoder.packBatchLineDiagnostics(diagsByLineOrData);
    native.editorSetBatchLineDiagnostics(this.handle, data, data.byteLength);
  }

  // ==================== Guide (Code Structure Lines) ====================

  setIndentGuides(guidesOrData: IndentGuide[] | ArrayBuffer, _size?: number): void {
    if (guidesOrData instanceof ArrayBuffer) {
      native.editorSetIndentGuides(this.handle, guidesOrData, guidesOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packIndentGuides(guidesOrData);
    native.editorSetIndentGuides(this.handle, data, data.byteLength);
  }

  setBracketGuides(guidesOrData: BracketGuide[] | ArrayBuffer, _size?: number): void {
    if (guidesOrData instanceof ArrayBuffer) {
      native.editorSetBracketGuides(this.handle, guidesOrData, guidesOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packBracketGuides(guidesOrData);
    native.editorSetBracketGuides(this.handle, data, data.byteLength);
  }

  setFlowGuides(guidesOrData: FlowGuide[] | ArrayBuffer, _size?: number): void {
    if (guidesOrData instanceof ArrayBuffer) {
      native.editorSetFlowGuides(this.handle, guidesOrData, guidesOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packFlowGuides(guidesOrData);
    native.editorSetFlowGuides(this.handle, data, data.byteLength);
  }

  setSeparatorGuides(guidesOrData: SeparatorGuide[] | ArrayBuffer, _size?: number): void {
    if (guidesOrData instanceof ArrayBuffer) {
      native.editorSetSeparatorGuides(this.handle, guidesOrData, guidesOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packSeparatorGuides(guidesOrData);
    native.editorSetSeparatorGuides(this.handle, data, data.byteLength);
  }

  // ==================== Bracket Pair Highlight ====================

  setBracketPairs(openChars: number[], closeChars: number[]): void {
    native.editorSetBracketPairs(this.handle, openChars, closeChars);
  }

  setAutoClosingPairs(openChars: number[], closeChars: number[]): void {
    native.editorSetAutoClosingPairs(this.handle, openChars, closeChars);
  }

  setMatchedBrackets(openLine: number, openCol: number, closeLine: number, closeCol: number): void {
    native.editorSetMatchedBrackets(this.handle, openLine, openCol, closeLine, closeCol);
  }

  clearMatchedBrackets(): void {
    native.editorClearMatchedBrackets(this.handle);
  }

  // ==================== Code Folding ====================

  setFoldRegions(regionsOrData: FoldRegion[] | ArrayBuffer, _size?: number): void {
    if (regionsOrData instanceof ArrayBuffer) {
      native.editorSetFoldRegions(this.handle, regionsOrData, regionsOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packFoldRegions(regionsOrData);
    native.editorSetFoldRegions(this.handle, data, data.byteLength);
  }

  toggleFoldAt(line: number): boolean {
    return this.toggleFold(line);
  }

  toggleFold(line: number): boolean {
    return native.editorToggleFold(this.handle, line);
  }

  foldAt(line: number): boolean {
    return native.editorFoldAt(this.handle, line);
  }

  unfoldAt(line: number): boolean {
    return native.editorUnfoldAt(this.handle, line);
  }

  foldAll(): void {
    native.editorFoldAll(this.handle);
  }

  unfoldAll(): void {
    native.editorUnfoldAll(this.handle);
  }

  isLineVisible(line: number): boolean {
    return native.editorIsLineVisible(this.handle, line);
  }

  // ==================== Linked Editing ====================

  insertSnippet(snippetTemplate: string): TextEditResult {
    return ProtocolDecoder.decodeTextEditResult(native.editorInsertSnippet(this.handle, snippetTemplate));
  }

  startLinkedEditing(modelOrData: LinkedEditingModel | ArrayBuffer, _size?: number): void {
    if (modelOrData instanceof ArrayBuffer) {
      native.editorStartLinkedEditing(this.handle, modelOrData, modelOrData.byteLength);
      return;
    }
    const data = ProtocolEncoder.packLinkedEditingModel(modelOrData);
    native.editorStartLinkedEditing(this.handle, data, data.byteLength);
  }

  isInLinkedEditing(): boolean {
    return native.editorIsInLinkedEditing(this.handle);
  }

  linkedEditingNext(): boolean {
    return native.editorLinkedEditingNext(this.handle);
  }

  linkedEditingPrev(): boolean {
    return native.editorLinkedEditingPrev(this.handle);
  }

  cancelLinkedEditing(): void {
    native.editorCancelLinkedEditing(this.handle);
  }

  // ==================== Clear Operations ====================

  clearHighlights(layer?: SpanLayer): void {
    if (layer === undefined) {
      native.editorClearHighlights(this.handle);
      return;
    }
    native.editorClearHighlightsLayer(this.handle, layer as number);
  }

  clearInlayHints(): void {
    native.editorClearInlayHints(this.handle);
  }

  clearPhantomTexts(): void {
    native.editorClearPhantomTexts(this.handle);
  }

  clearGutterIcons(): void {
    native.editorClearGutterIcons(this.handle);
  }

  clearGuides(): void {
    native.editorClearGuides(this.handle);
  }

  clearDiagnostics(): void {
    native.editorClearDiagnostics(this.handle);
  }

  clearAllDecorations(): void {
    native.editorClearAllDecorations(this.handle);
  }
}

