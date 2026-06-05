import native from 'libsweeteditor.so';
import { CoreProtocol } from './CoreProtocol';
import {
  IntRange,
  PointF,
  TextPosition,
  TextRange
} from './CoreFoundation';
import { EditorActionResult, ScrollBehavior } from './CoreAction';
import {
  AutoIndentMode,
  CurrentLineRenderMode,
  EditorRangeEffectStyles,
  EditorRenderColors,
  EditorOptions,
  FoldArrowMode,
  HandleConfig,
  ScrollbarConfig,
  WrapMode
} from './CoreConfig';
import { EventType, GestureEvent } from './CoreInteraction';
import {
  ImeDocumentTextReplacement,
  ImeInputContextTextReplacement,
  ImeInputStateTextReplacement,
  ImeInputContext,
  ImeScriptClass,
  ImeSyncSnapshot,
  ImeTextModelState,
  ImeTextReplacement,
  ImeTextUnit
} from './CoreIme';
import { KeyBinding } from './CoreKeymap';
import { SearchRequest, SearchState } from './CoreSearch';
import {
  BracketGuide,
  CodeLensItem,
  LinkSpan,
  Diagnostic,
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
import { CursorRect, EditorRenderModel, ScrollMetrics } from './CoreVisual';
import { LinkedEditingModel } from './CoreLinkedEditing';

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
    const optionsData = options ? CoreProtocol.encodeEditorOptions(options) : undefined;
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

  loadDocument(doc: Document): EditorActionResult {
    this.document = doc;
    return CoreProtocol.decodeEditorActionResult(native.setEditorDocument(this.handle, doc.getHandle()));
  }

  getDocument(): Document | null {
    return this.document;
  }

  // ==================== Viewport/Font/Appearance Configuration ====================

  setViewport(width: number, height: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.setEditorViewport(this.handle, width, height));
  }

  onFontMetricsChanged(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorOnFontMetricsChanged(this.handle));
  }

  setFoldArrowMode(mode: FoldArrowMode): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetFoldArrowMode(this.handle, mode as number));
  }

  setWrapMode(mode: WrapMode): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetWrapMode(this.handle, mode as number));
  }

  setTabSize(tabSize: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetTabSize(this.handle, tabSize));
  }

  setInsertSpaces(enabled: boolean): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetInsertSpaces(this.handle, enabled ? 1 : 0));
  }

  setKeyMap(bindings: KeyBinding[]): EditorActionResult {
    const data = CoreProtocol.encodeSetKeyMapPayload(bindings);
    return CoreProtocol.decodeEditorActionResult(native.editorSetKeyMap(this.handle, data, data.byteLength));
  }

  setScale(scale: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetScale(this.handle, scale));
  }

  setLineSpacing(add: number, mult: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetLineSpacing(this.handle, add, mult));
  }

  setContentStartPadding(padding: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetContentStartPadding(this.handle, padding));
  }

  setShowSplitLine(show: boolean): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetShowSplitLine(this.handle, show));
  }

  setGutterSticky(sticky: boolean): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetGutterSticky(this.handle, sticky));
  }

  setGutterVisible(visible: boolean): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetGutterVisible(this.handle, visible));
  }

  setCurrentLineRenderMode(mode: CurrentLineRenderMode): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetCurrentLineRenderMode(this.handle, mode as number));
  }

  // ==================== Rendering ====================

  buildRenderModel(): EditorRenderModel {
    const payload = native.buildEditorRenderModel(this.handle);
    return CoreProtocol.decodeEditorRenderModel(payload);
  }

  getLayoutMetrics(): ArrayBuffer | undefined {
    return native.getLayoutMetrics(this.handle);
  }

  // ==================== Gesture/Keyboard Event Handling ====================

  handleGestureEvent(event: GestureEvent): EditorActionResult {
    const data = CoreProtocol.encodeGestureEvent(event);
    const payload = native.handleEditorGestureEvent(this.handle, data, data.byteLength);
    return CoreProtocol.decodeEditorActionResult(payload);
  }

  handleSimpleGestureEvent(type: EventType, pointerCount: number, points: number[]): EditorActionResult {
    const event = new GestureEvent();
    event.type = type;
    const count = Math.min(pointerCount, Math.floor(points.length / 2));
    for (let i = 0; i < count; i++) {
      event.points.push({ x: points[i * 2], y: points[i * 2 + 1] });
    }
    return this.handleGestureEvent(event);
  }

  tickAnimations(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorTickAnimations(this.handle));
  }

  updatePointerModifiers(modifiers: number): EditorActionResult {
    const payload = native.editorUpdatePointerModifiers(this.handle, modifiers);
    return CoreProtocol.decodeEditorActionResult(payload);
  }

  handleKeyEvent(keyCode: number, text: string | null, modifiers: number): EditorActionResult {
    const payload = native.handleEditorKeyEvent(this.handle, keyCode, text, modifiers);
    return CoreProtocol.decodeEditorActionResult(payload);
  }

  // ==================== Text Editing ====================

  insertText(text: string): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorInsertText(this.handle, text));
  }

  replaceText(startLine: number, startColumn: number, endLine: number, endColumn: number,
    text: string): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorReplaceText(this.handle, startLine, startColumn, endLine, endColumn, text)
    );
  }

  deleteText(startLine: number, startColumn: number, endLine: number, endColumn: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorDeleteText(this.handle, startLine, startColumn, endLine, endColumn)
    );
  }

  backspace(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorBackspace(this.handle));
  }

  deleteForward(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorDeleteForward(this.handle));
  }

  // ==================== Line Operations ====================

  moveLineUp(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveLineUp(this.handle));
  }

  moveLineDown(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveLineDown(this.handle));
  }

  copyLineUp(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorCopyLineUp(this.handle));
  }

  copyLineDown(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorCopyLineDown(this.handle));
  }

  deleteLine(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorDeleteLine(this.handle));
  }

  insertLineAbove(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorInsertLineAbove(this.handle));
  }

  insertLineBelow(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorInsertLineBelow(this.handle));
  }

  // ==================== Undo/Redo ====================

  undo(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorUndo(this.handle));
  }

  redo(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorRedo(this.handle));
  }

  canUndo(): boolean {
    return native.editorCanUndo(this.handle);
  }

  canRedo(): boolean {
    return native.editorCanRedo(this.handle);
  }

  search(request: SearchRequest): EditorActionResult {
    const payload = CoreProtocol.encodeSearchRequest(request);
    return CoreProtocol.decodeEditorActionResult(native.editorSearch(this.handle, payload, payload.byteLength));
  }

  findNextSearchMatch(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorFindNextSearchMatch(this.handle));
  }

  findPreviousSearchMatch(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorFindPreviousSearchMatch(this.handle));
  }

  replaceCurrentSearchMatch(replacement: string): EditorActionResult {
    const payload = CoreProtocol.encodeUtf8String(replacement);
    return CoreProtocol.decodeEditorActionResult(native.editorReplaceCurrentSearchMatch(this.handle, payload, payload.byteLength));
  }

  replaceAllSearchMatches(replacement: string): EditorActionResult {
    const payload = CoreProtocol.encodeUtf8String(replacement);
    return CoreProtocol.decodeEditorActionResult(native.editorReplaceAllSearchMatches(this.handle, payload, payload.byteLength));
  }

  clearSearch(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearSearch(this.handle));
  }

  getSearchState(): SearchState {
    return CoreProtocol.decodeSearchState(native.editorGetSearchState(this.handle));
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

  setCursorPosition(line: number, column: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetCursorPosition(this.handle, line, column));
  }

  selectAll(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSelectAll(this.handle));
  }

  setSelection(startLineOrRange: number | TextRange, startColumn?: number,
               endLine?: number, endColumn?: number): EditorActionResult {
    if (typeof startLineOrRange === 'number') {
      return CoreProtocol.decodeEditorActionResult(native.editorSetSelection(
        this.handle,
        startLineOrRange,
        startColumn ?? 0,
        endLine ?? startLineOrRange,
        endColumn ?? (startColumn ?? 0)));
    }
    return CoreProtocol.decodeEditorActionResult(native.editorSetSelection(
      this.handle,
      startLineOrRange.start.line,
      startLineOrRange.start.column,
      startLineOrRange.end.line,
      startLineOrRange.end.column));
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

  moveCursorLeft(extendSelection: boolean = false): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveCursorLeft(this.handle, extendSelection));
  }

  moveCursorRight(extendSelection: boolean = false): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveCursorRight(this.handle, extendSelection));
  }

  moveCursorUp(extendSelection: boolean = false): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveCursorUp(this.handle, extendSelection));
  }

  moveCursorDown(extendSelection: boolean = false): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveCursorDown(this.handle, extendSelection));
  }

  moveCursorToLineStart(extendSelection: boolean = false): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveCursorToLineStart(this.handle, extendSelection));
  }

  moveCursorToLineEnd(extendSelection: boolean = false): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorMoveCursorToLineEnd(this.handle, extendSelection));
  }

  // ==================== IME Composition Input ====================

  updateImePreedit(text: string | null, scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeUpdatePreedit(this.handle, text, scriptHint as number)
    );
  }

  setImeComposingText(text: string | null,
                      cursorOffset: number = 1,
                      scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeSetComposingText(this.handle, text, cursorOffset, scriptHint as number)
    );
  }

  setImeComposingTextSelection(text: string | null,
                               selectionStartOffset: number,
                               selectionEndOffset: number,
                               scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeSetComposingTextSelection(
        this.handle,
        text,
        selectionStartOffset,
        selectionEndOffset,
        scriptHint as number)
    );
  }

  commitImeText(text: string | null, scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeCommitText(this.handle, text, scriptHint as number)
    );
  }

  finishImePreedit(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorImeFinishPreedit(this.handle));
  }

  cancelImePreedit(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorImeCancelPreedit(this.handle));
  }

  markImeDocumentRange(range: TextRange, scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeMarkDocumentRange(
        this.handle,
        range.start.line,
        range.start.column,
        range.end.line,
        range.end.column,
        scriptHint as number
      )
    );
  }

  markImeDocumentRangeByOffset(startOffset: number,
                               endOffset: number,
                               scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeMarkDocumentRangeByOffset(this.handle, startOffset, endOffset, scriptHint as number)
    );
  }

  replaceImeText(replacement: ImeTextReplacement): EditorActionResult {
    const data = CoreProtocol.encodeImeTextReplacement(replacement);
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeReplaceText(this.handle, data)
    );
  }

  replaceImeDocumentText(replacement: ImeDocumentTextReplacement): EditorActionResult {
    const data = CoreProtocol.encodeImeDocumentTextReplacement(replacement);
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeReplaceDocumentText(this.handle, data)
    );
  }

  replaceImeInputContextText(replacement: ImeInputContextTextReplacement): EditorActionResult {
    const data = CoreProtocol.encodeImeInputContextTextReplacement(replacement);
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeReplaceInputContextText(this.handle, data)
    );
  }

  markImeInputContextRange(startOffset: number,
                           endOffset: number,
                            scriptHint: ImeScriptClass = ImeScriptClass.UNKNOWN): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeMarkInputContextRange(this.handle, startOffset, endOffset, scriptHint as number)
    );
  }

  notifyImeDocumentSelectionChanged(startOffset: number, endOffset: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeNotifyDocumentSelectionChanged(this.handle, startOffset, endOffset)
    );
  }

  notifyImeInputContextSelectionChanged(startOffset: number, endOffset: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeNotifyInputContextSelectionChanged(this.handle, startOffset, endOffset)
    );
  }

  updateImeTextModelState(state: ImeTextModelState): EditorActionResult {
    const data = CoreProtocol.encodeImeTextModelState(state);
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeUpdateTextModelState(this.handle, data)
    );
  }

  updateImeInputStateSelection(contextId: number,
                               documentStartOffset: number,
                               selectionStartOffset: number,
                               selectionEndOffset: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeUpdateInputStateSelection(
        this.handle,
        contextId,
        documentStartOffset,
        selectionStartOffset,
        selectionEndOffset)
    );
  }

  replaceImeInputStateText(replacement: ImeInputStateTextReplacement): EditorActionResult {
    const data = CoreProtocol.encodeImeInputStateTextReplacement(replacement);
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeReplaceInputStateText(this.handle, data)
    );
  }

  deleteImeBackward(beforeLength: number = 1,
                    textUnit: ImeTextUnit = ImeTextUnit.GRAPHEME): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeDeleteBackward(this.handle, beforeLength, textUnit as number)
    );
  }

  deleteImeForward(afterLength: number = 1,
                   textUnit: ImeTextUnit = ImeTextUnit.GRAPHEME): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeDeleteForward(this.handle, afterLength, textUnit as number)
    );
  }

  deleteImeSurrounding(beforeLength: number,
                       afterLength: number,
                       textUnit: ImeTextUnit = ImeTextUnit.GRAPHEME): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeDeleteSurrounding(this.handle, beforeLength, afterLength, textUnit as number)
    );
  }

  notifyImeSelectionChanged(range: TextRange): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeNotifySelectionChanged(
        this.handle,
        range.start.line,
        range.start.column,
        range.end.line,
        range.end.column
      )
    );
  }

  notifyImeCursorChanged(cursor: TextPosition): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeNotifyCursorChanged(this.handle, cursor.line, cursor.column)
    );
  }

  isComposing(): boolean {
    return native.editorIsComposing(this.handle);
  }

  getComposingRange(): TextRange | null {
    const arr = native.editorGetComposingRange(this.handle);
    if (arr === null || arr[0] < 0) {
      return null;
    }
    return {
      start: { line: arr[0], column: arr[1] },
      end: { line: arr[2], column: arr[3] }
    };
  }

  getComposingSessionRange(): TextRange | null {
    const arr = native.editorGetComposingSessionRange(this.handle);
    if (arr === null || arr[0] < 0) {
      return null;
    }
    return {
      start: { line: arr[0], column: arr[1] },
      end: { line: arr[2], column: arr[3] }
    };
  }

  setImeKeyboardScriptClass(scriptClass: ImeScriptClass): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorImeSetKeyboardScriptClass(this.handle, scriptClass as number));
  }

  getImeKeyboardScriptClass(): ImeScriptClass {
    return native.editorImeGetKeyboardScriptClass(this.handle) as ImeScriptClass;
  }

  getImeSyncSnapshot(): ImeSyncSnapshot {
    return CoreProtocol.decodeImeSyncSnapshot(native.editorGetImeSyncSnapshot(this.handle));
  }

  getImeInputContext(beforeLength: number, afterLength: number): ImeInputContext {
    return CoreProtocol.decodeImeInputContext(
      native.editorGetImeInputContext(this.handle, beforeLength, afterLength)
    );
  }

  // ==================== Read-Only Mode ====================

  setReadOnly(readOnly: boolean): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetReadOnly(this.handle, readOnly));
  }

  isReadOnly(): boolean {
    return native.editorIsReadOnly(this.handle);
  }

  // ==================== Auto Indent ====================

  setAutoIndentMode(mode: AutoIndentMode): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetAutoIndentMode(this.handle, mode as number));
  }

  getAutoIndentMode(): number {
    return native.editorGetAutoIndentMode(this.handle);
  }

  setBackspaceUnindent(enabled: boolean): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBackspaceUnindent(this.handle, enabled ? 1 : 0));
  }

  // ==================== Handle Config ====================

  setHandleConfig(config: HandleConfig): EditorActionResult {
    this.handleConfig = config;
    const data = CoreProtocol.encodeHandleConfig(config);
    return CoreProtocol.decodeEditorActionResult(native.editorSetHandleConfig(this.handle, data, data.byteLength));
  }

  getHandleConfig(): HandleConfig {
    return this.handleConfig;
  }

  // ==================== Scrollbar Config ====================

  setScrollbarConfig(config: ScrollbarConfig): EditorActionResult {
    this.scrollbarConfig = config;
    const data = CoreProtocol.encodeScrollbarConfig(config);
    return CoreProtocol.decodeEditorActionResult(native.editorSetScrollbarConfig(this.handle, data, data.byteLength));
  }

  getScrollbarConfig(): ScrollbarConfig {
    return this.scrollbarConfig;
  }

  setEditorRenderColors(colors: EditorRenderColors): EditorActionResult {
    const data = CoreProtocol.encodeEditorRenderColors(colors);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetEditorRenderColors(this.handle, data, data.byteLength));
  }

  setEditorRangeEffectStyles(styles: EditorRangeEffectStyles): EditorActionResult {
    const data = CoreProtocol.encodeEditorRangeEffectStyles(styles);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetEditorRangeEffectStyles(this.handle, data, data.byteLength));
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

  scrollToLine(line: number, behavior: ScrollBehavior = ScrollBehavior.GOTO_CENTER): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorScrollToLine(this.handle, line, behavior as number));
  }

  gotoPosition(line: number, column: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorGotoPosition(this.handle, line, column));
  }

  ensureCursorVisible(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorEnsureCursorVisible(this.handle));
  }

  setScroll(scrollX: number, scrollY: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetScroll(this.handle, scrollX, scrollY));
  }

  getScrollMetrics(): ScrollMetrics {
    return CoreProtocol.decodeScrollMetrics(native.editorGetScrollMetrics(this.handle));
  }

  getVisibleLineRange(): IntRange {
    const visible = native.editorGetVisibleLineRange(this.handle);
    return {
      start: visible && visible.length > 0 ? visible[0] : 0,
      end: visible && visible.length > 1 ? visible[1] : -1
    };
  }

  // ==================== Style Registration + Highlight Spans ====================

  registerTextStyle(styleId: number, color: number,
                    backgroundColorOrFontStyle: number, fontStyle?: number): EditorActionResult {
    const backgroundColor = fontStyle === undefined ? 0 : backgroundColorOrFontStyle;
    const resolvedFontStyle = fontStyle === undefined ? backgroundColorOrFontStyle : fontStyle;
    return CoreProtocol.decodeEditorActionResult(
      native.editorRegisterTextStyle(this.handle, styleId, color, backgroundColor, resolvedFontStyle));
  }

  registerBatchTextStyles(stylesByIdOrData: Map<number, TextStyle> | ArrayBuffer,
                          _size?: number): EditorActionResult | null {
    if (stylesByIdOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorRegisterBatchTextStyles(this.handle, stylesByIdOrData, stylesByIdOrData.byteLength));
    }
    if (stylesByIdOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeRegisterBatchTextStylesPayload(stylesByIdOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorRegisterBatchTextStyles(this.handle, data, data.byteLength));
  }

  setLineSpans(lineOrData: number | ArrayBuffer, layerOrSize: number, spans?: StyleSpan[]): EditorActionResult {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLineSpans(this.handle, lineOrData, lineOrData.byteLength));
    }
    const data = CoreProtocol.encodeSetLineSpansPayload(lineOrData, layerOrSize, spans ?? []);
    return CoreProtocol.decodeEditorActionResult(native.editorSetLineSpans(this.handle, data, data.byteLength));
  }

  setBatchLineSpans(layerOrData: number | ArrayBuffer,
                    spansByLineOrSize: Map<number, StyleSpan[]> | number): EditorActionResult | null {
    if (layerOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLineSpans(this.handle, layerOrData, layerOrData.byteLength));
    }
    if (!(spansByLineOrSize instanceof Map) || spansByLineOrSize.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLineSpansPayload(layerOrData, spansByLineOrSize);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLineSpans(this.handle, data, data.byteLength));
  }

  clearLineSpans(line: number, layer: SpanLayer): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearLineSpans(this.handle, line, layer as number));
  }

  // ==================== InlayHint / PhantomText ====================

  setLineInlayHints(lineOrData: number | ArrayBuffer,
                    hintsOrSize: InlayHint[] | number): EditorActionResult | null {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLineInlayHints(this.handle, lineOrData, lineOrData.byteLength));
    }
    if (!Array.isArray(hintsOrSize)) {
      return null;
    }
    const data = CoreProtocol.encodeSetLineInlayHintsPayload(lineOrData, hintsOrSize);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetLineInlayHints(this.handle, data, data.byteLength));
  }

  setBatchLineInlayHints(hintsByLineOrData: Map<number, InlayHint[]> | ArrayBuffer,
                         _size?: number): EditorActionResult | null {
    if (hintsByLineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLineInlayHints(this.handle, hintsByLineOrData, hintsByLineOrData.byteLength));
    }
    if (hintsByLineOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLineInlayHintsPayload(hintsByLineOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLineInlayHints(this.handle, data, data.byteLength));
  }

  setLinePhantomTexts(lineOrData: number | ArrayBuffer,
                      phantomsOrSize: PhantomText[] | number): EditorActionResult | null {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLinePhantomTexts(this.handle, lineOrData, lineOrData.byteLength));
    }
    if (!Array.isArray(phantomsOrSize)) {
      return null;
    }
    const data = CoreProtocol.encodeSetLinePhantomTextsPayload(lineOrData, phantomsOrSize);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetLinePhantomTexts(this.handle, data, data.byteLength));
  }

  setBatchLinePhantomTexts(phantomsByLineOrData: Map<number, PhantomText[]> | ArrayBuffer,
                           _size?: number): EditorActionResult | null {
    if (phantomsByLineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLinePhantomTexts(this.handle, phantomsByLineOrData, phantomsByLineOrData.byteLength));
    }
    if (phantomsByLineOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLinePhantomTextsPayload(phantomsByLineOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLinePhantomTexts(this.handle, data, data.byteLength));
  }

  // ==================== Gutter Icons ====================

  setLineGutterIcons(lineOrData: number | ArrayBuffer,
                     iconsOrSize: GutterIcon[] | number): EditorActionResult | null {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLineGutterIcons(this.handle, lineOrData, lineOrData.byteLength));
    }
    if (!Array.isArray(iconsOrSize)) {
      return null;
    }
    const data = CoreProtocol.encodeSetLineGutterIconsPayload(lineOrData, iconsOrSize);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetLineGutterIcons(this.handle, data, data.byteLength));
  }

  setBatchLineGutterIcons(iconsByLineOrData: Map<number, GutterIcon[]> | ArrayBuffer,
                          _size?: number): EditorActionResult | null {
    if (iconsByLineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLineGutterIcons(this.handle, iconsByLineOrData, iconsByLineOrData.byteLength));
    }
    if (iconsByLineOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLineGutterIconsPayload(iconsByLineOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLineGutterIcons(this.handle, data, data.byteLength));
  }

  setMaxGutterIcons(count: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetMaxGutterIcons(this.handle, count));
  }

  // ==================== CodeLens ====================

  setLineCodeLens(lineOrData: number | ArrayBuffer,
                  itemsOrSize?: CodeLensItem[] | number): EditorActionResult | null {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLineCodeLens(this.handle, lineOrData, lineOrData.byteLength));
    }
    if (!Array.isArray(itemsOrSize)) {
      return null;
    }
    const data = CoreProtocol.encodeSetLineCodeLensPayload(lineOrData, itemsOrSize);
    return CoreProtocol.decodeEditorActionResult(native.editorSetLineCodeLens(this.handle, data, data.byteLength));
  }

  setBatchLineCodeLens(itemsByLineOrData: Map<number, CodeLensItem[]> | ArrayBuffer,
                       _size?: number): EditorActionResult | null {
    if (itemsByLineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLineCodeLens(this.handle, itemsByLineOrData, itemsByLineOrData.byteLength));
    }
    if (itemsByLineOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLineCodeLensPayload(itemsByLineOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLineCodeLens(this.handle, data, data.byteLength));
  }

  clearCodeLens(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearCodeLens(this.handle));
  }

  // ==================== Links ====================

  setLineLinks(lineOrData: number | ArrayBuffer, linksOrSize?: LinkSpan[] | number): EditorActionResult | null {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLineLinks(this.handle, lineOrData, lineOrData.byteLength));
    }
    if (!Array.isArray(linksOrSize)) {
      return null;
    }
    const data = CoreProtocol.encodeSetLineLinksPayload(lineOrData, linksOrSize);
    return CoreProtocol.decodeEditorActionResult(native.editorSetLineLinks(this.handle, data, data.byteLength));
  }

  setBatchLineLinks(linksByLineOrData: Map<number, LinkSpan[]> | ArrayBuffer,
                    _size?: number): EditorActionResult | null {
    if (linksByLineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLineLinks(this.handle, linksByLineOrData, linksByLineOrData.byteLength));
    }
    if (linksByLineOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLineLinksPayload(linksByLineOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLineLinks(this.handle, data, data.byteLength));
  }

  clearLinks(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearLinks(this.handle));
  }

  getLinkTargetAt(line: number, column: number): string {
    return native.editorGetLinkTargetAt(this.handle, line, column);
  }

  // ==================== Diagnostic Decorations ====================

  setLineDiagnostics(lineOrData: number | ArrayBuffer,
                     itemsOrSize: Diagnostic[] | number): EditorActionResult | null {
    if (lineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetLineDiagnostics(this.handle, lineOrData, lineOrData.byteLength));
    }
    if (!Array.isArray(itemsOrSize)) {
      return null;
    }
    const data = CoreProtocol.encodeSetLineDiagnosticsPayload(lineOrData, itemsOrSize);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetLineDiagnostics(this.handle, data, data.byteLength));
  }

  setBatchLineDiagnostics(diagsByLineOrData: Map<number, Diagnostic[]> | ArrayBuffer,
                          _size?: number): EditorActionResult | null {
    if (diagsByLineOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBatchLineDiagnostics(this.handle, diagsByLineOrData, diagsByLineOrData.byteLength));
    }
    if (diagsByLineOrData.size === 0) {
      return null;
    }
    const data = CoreProtocol.encodeSetBatchLineDiagnosticsPayload(diagsByLineOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetBatchLineDiagnostics(this.handle, data, data.byteLength));
  }

  // ==================== Guide (Code Structure Lines) ====================

  setIndentGuides(guidesOrData: IndentGuide[] | ArrayBuffer, _size?: number): EditorActionResult {
    if (guidesOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetIndentGuides(this.handle, guidesOrData, guidesOrData.byteLength));
    }
    const data = CoreProtocol.encodeSetIndentGuidesPayload(guidesOrData);
    return CoreProtocol.decodeEditorActionResult(native.editorSetIndentGuides(this.handle, data, data.byteLength));
  }

  setBracketGuides(guidesOrData: BracketGuide[] | ArrayBuffer, _size?: number): EditorActionResult {
    if (guidesOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetBracketGuides(this.handle, guidesOrData, guidesOrData.byteLength));
    }
    const data = CoreProtocol.encodeSetBracketGuidesPayload(guidesOrData);
    return CoreProtocol.decodeEditorActionResult(native.editorSetBracketGuides(this.handle, data, data.byteLength));
  }

  setFlowGuides(guidesOrData: FlowGuide[] | ArrayBuffer, _size?: number): EditorActionResult {
    if (guidesOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetFlowGuides(this.handle, guidesOrData, guidesOrData.byteLength));
    }
    const data = CoreProtocol.encodeSetFlowGuidesPayload(guidesOrData);
    return CoreProtocol.decodeEditorActionResult(native.editorSetFlowGuides(this.handle, data, data.byteLength));
  }

  setSeparatorGuides(guidesOrData: SeparatorGuide[] | ArrayBuffer, _size?: number): EditorActionResult {
    if (guidesOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetSeparatorGuides(this.handle, guidesOrData, guidesOrData.byteLength));
    }
    const data = CoreProtocol.encodeSetSeparatorGuidesPayload(guidesOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetSeparatorGuides(this.handle, data, data.byteLength));
  }

  // ==================== Bracket Pair Highlight ====================

  setBracketPairs(openChars: number[], closeChars: number[]): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorSetBracketPairs(this.handle, openChars, closeChars));
  }

  setAutoClosingPairs(openChars: number[], closeChars: number[]): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetAutoClosingPairs(this.handle, openChars, closeChars));
  }

  setMatchedBrackets(openLine: number, openCol: number,
                     closeLine: number, closeCol: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(
      native.editorSetMatchedBrackets(this.handle, openLine, openCol, closeLine, closeCol));
  }

  clearMatchedBrackets(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearMatchedBrackets(this.handle));
  }

  // ==================== Code Folding ====================

  setFoldRegions(regionsOrData: FoldRegion[] | ArrayBuffer, _size?: number): EditorActionResult {
    if (regionsOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorSetFoldRegions(this.handle, regionsOrData, regionsOrData.byteLength));
    }
    const data = CoreProtocol.encodeSetFoldRegionsPayload(regionsOrData);
    return CoreProtocol.decodeEditorActionResult(native.editorSetFoldRegions(this.handle, data, data.byteLength));
  }

  toggleFoldAt(line: number): EditorActionResult {
    return this.toggleFold(line);
  }

  toggleFold(line: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorToggleFold(this.handle, line));
  }

  foldAt(line: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorFoldAt(this.handle, line));
  }

  unfoldAt(line: number): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorUnfoldAt(this.handle, line));
  }

  foldAll(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorFoldAll(this.handle));
  }

  unfoldAll(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorUnfoldAll(this.handle));
  }

  isLineVisible(line: number): boolean {
    return native.editorIsLineVisible(this.handle, line);
  }

  // ==================== Linked Editing ====================

  insertSnippet(snippetTemplate: string): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorInsertSnippet(this.handle, snippetTemplate));
  }

  startLinkedEditing(modelOrData: LinkedEditingModel | ArrayBuffer, _size?: number): EditorActionResult {
    if (modelOrData instanceof ArrayBuffer) {
      return CoreProtocol.decodeEditorActionResult(
        native.editorStartLinkedEditing(this.handle, modelOrData, modelOrData.byteLength));
    }
    const data = CoreProtocol.encodeStartLinkedEditingPayload(modelOrData);
    return CoreProtocol.decodeEditorActionResult(
      native.editorStartLinkedEditing(this.handle, data, data.byteLength));
  }

  isInLinkedEditing(): boolean {
    return native.editorIsInLinkedEditing(this.handle);
  }

  linkedEditingNext(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorLinkedEditingNext(this.handle));
  }

  linkedEditingPrev(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorLinkedEditingPrev(this.handle));
  }

  cancelLinkedEditing(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorCancelLinkedEditing(this.handle));
  }

  // ==================== Clear Operations ====================

  clearHighlights(layer?: SpanLayer): EditorActionResult {
    if (layer === undefined) {
      return CoreProtocol.decodeEditorActionResult(native.editorClearHighlights(this.handle));
    }
    return CoreProtocol.decodeEditorActionResult(native.editorClearHighlightsLayer(this.handle, layer as number));
  }

  clearInlayHints(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearInlayHints(this.handle));
  }

  clearPhantomTexts(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearPhantomTexts(this.handle));
  }

  clearGutterIcons(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearGutterIcons(this.handle));
  }

  clearGuides(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearGuides(this.handle));
  }

  clearDiagnostics(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearDiagnostics(this.handle));
  }

  clearAllDecorations(): EditorActionResult {
    return CoreProtocol.decodeEditorActionResult(native.editorClearAllDecorations(this.handle));
  }
}
