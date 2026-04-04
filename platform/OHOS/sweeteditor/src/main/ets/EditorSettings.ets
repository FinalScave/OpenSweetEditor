import { AutoIndentMode, CurrentLineRenderMode, FoldArrowMode, WrapMode } from './core/CoreFoundation';
import { SweetEditor } from './SweetEditor';

export class EditorSettings {
  private editor: SweetEditor;
  private textSize: number = 28;
  private fontFamily: string = 'monospace';
  private scale: number = 1.0;
  private foldArrowMode: FoldArrowMode = FoldArrowMode.ALWAYS;
  private wrapMode: WrapMode = WrapMode.NONE;
  private lineSpacingAdd: number = 0;
  private lineSpacingMult: number = 1.0;
  private contentStartPadding: number = 0;
  private showSplitLine: boolean = true;
  private gutterSticky: boolean = true;
  private gutterVisible: boolean = true;
  private currentLineRenderMode: CurrentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
  private autoIndentMode: AutoIndentMode = AutoIndentMode.KEEP_INDENT;
  private backspaceUnindent: boolean = true;
  private readOnly: boolean = false;
  private compositionEnabled: boolean = true;
  private maxGutterIcons: number = 0;
  private decorationScrollRefreshMinIntervalMs: number = 16;
  private decorationOverscanViewportMultiplier: number = 1.5;

  constructor(editor: SweetEditor) {
    this.editor = editor;
  }

  setEditorTextSize(size: number): void {
    this.textSize = size;
    this.editor.applyTextSize(size);
  }

  getEditorTextSize(): number {
    return this.textSize;
  }

  setFontFamily(fontFamily: string): void {
    this.fontFamily = fontFamily;
    this.editor.applyFontFamily(fontFamily);
  }

  getFontFamily(): string {
    return this.fontFamily;
  }

  setScale(scale: number): void {
    this.scale = scale;
    this.editor.applyScale(scale);
  }

  getScale(): number {
    return this.scale;
  }

  setFoldArrowMode(mode: FoldArrowMode): void {
    this.foldArrowMode = mode;
    this.editor.applyFoldArrowMode(mode);
  }

  getFoldArrowMode(): FoldArrowMode {
    return this.foldArrowMode;
  }

  setWrapMode(mode: WrapMode): void {
    this.wrapMode = mode;
    this.editor.applyWrapMode(mode);
  }

  getWrapMode(): WrapMode {
    return this.wrapMode;
  }

  setLineSpacing(add: number, mult: number): void {
    this.lineSpacingAdd = add;
    this.lineSpacingMult = mult;
    this.editor.applyLineSpacing(add, mult);
  }

  getLineSpacingAdd(): number {
    return this.lineSpacingAdd;
  }

  getLineSpacingMult(): number {
    return this.lineSpacingMult;
  }

  setContentStartPadding(padding: number): void {
    this.contentStartPadding = Math.max(0, padding);
    this.editor.applyContentStartPadding(this.contentStartPadding);
  }

  getContentStartPadding(): number {
    return this.contentStartPadding;
  }

  setShowSplitLine(show: boolean): void {
    this.showSplitLine = show;
    this.editor.applyShowSplitLine(show);
  }

  isShowSplitLine(): boolean {
    return this.showSplitLine;
  }

  setGutterSticky(sticky: boolean): void {
    this.gutterSticky = sticky;
    this.editor.applyGutterSticky(sticky);
  }

  isGutterSticky(): boolean {
    return this.gutterSticky;
  }

  setGutterVisible(visible: boolean): void {
    this.gutterVisible = visible;
    this.editor.applyGutterVisible(visible);
  }

  isGutterVisible(): boolean {
    return this.gutterVisible;
  }

  setCurrentLineRenderMode(mode: CurrentLineRenderMode): void {
    this.currentLineRenderMode = mode;
    this.editor.applyCurrentLineRenderMode(mode);
  }

  getCurrentLineRenderMode(): CurrentLineRenderMode {
    return this.currentLineRenderMode;
  }

  setAutoIndentMode(mode: AutoIndentMode): void {
    this.autoIndentMode = mode;
    this.editor.applyAutoIndentMode(mode);
  }

  getAutoIndentMode(): AutoIndentMode {
    return this.autoIndentMode;
  }

  setBackspaceUnindent(enabled: boolean): void {
    this.backspaceUnindent = enabled;
    this.editor.applyBackspaceUnindent(enabled);
  }

  isBackspaceUnindent(): boolean {
    return this.backspaceUnindent;
  }

  setReadOnly(readOnly: boolean): void {
    this.readOnly = readOnly;
    this.editor.applyReadOnly(readOnly);
  }

  isReadOnly(): boolean {
    return this.readOnly;
  }

  setCompositionEnabled(enabled: boolean): void {
    this.compositionEnabled = enabled;
    this.editor.applyCompositionEnabled(enabled);
  }

  isCompositionEnabled(): boolean {
    return this.compositionEnabled;
  }

  setMaxGutterIcons(count: number): void {
    this.maxGutterIcons = count;
    this.editor.applyMaxGutterIcons(count);
  }

  getMaxGutterIcons(): number {
    return this.maxGutterIcons;
  }

  setDecorationScrollRefreshMinIntervalMs(intervalMs: number): void {
    this.decorationScrollRefreshMinIntervalMs = Math.max(0, intervalMs);
    this.editor.requestDecorationRefresh();
  }

  getDecorationScrollRefreshMinIntervalMs(): number {
    return this.decorationScrollRefreshMinIntervalMs;
  }

  setDecorationOverscanViewportMultiplier(multiplier: number): void {
    this.decorationOverscanViewportMultiplier = Math.max(0, multiplier);
    this.editor.requestDecorationRefresh();
  }

  getDecorationOverscanViewportMultiplier(): number {
    return this.decorationOverscanViewportMultiplier;
  }
}

