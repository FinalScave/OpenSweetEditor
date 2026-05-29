import { AutoIndentMode, CurrentLineRenderMode, FoldArrowMode, WrapMode } from './core/CoreConfig';
import { SweetEditor } from './SweetEditor';

const DEFAULT_CONTENT_START_PADDING: number = 3.0;
const DEFAULT_GUTTER_STICKY: boolean = false;

export class EditorSettings {
  private editor: SweetEditor;
  private textSize: number = 28;
  private fontFamily: string = 'monospace';
  private scale: number = 1.0;
  private foldArrowMode: FoldArrowMode = FoldArrowMode.ALWAYS;
  private wrapMode: WrapMode = WrapMode.NONE;
  private lineSpacingAdd: number = 0;
  private lineSpacingMult: number = 1.0;
  private contentStartPadding: number = DEFAULT_CONTENT_START_PADDING;
  private showSplitLine: boolean = true;
  private gutterSticky: boolean = DEFAULT_GUTTER_STICKY;
  private gutterVisible: boolean = true;
  private currentLineRenderMode: CurrentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
  private autoIndentMode: AutoIndentMode = AutoIndentMode.KEEP_INDENT;
  private backspaceUnindent: boolean = true;
  private readOnly: boolean = false;
  private maxGutterIcons: number = 0;
  private decorationScrollRefreshMinIntervalMs: number = 16;
  private decorationOverscanViewportMultiplier: number = 1.5;

  constructor(editor: SweetEditor) {
    this.editor = editor;
  }

  setEditorTextSize(size: number): void {
    this.textSize = size;
    this.editor.applySettingsTextSize(size);
  }

  getEditorTextSize(): number {
    return this.textSize;
  }

  setFontFamily(fontFamily: string): void {
    this.fontFamily = fontFamily;
    this.editor.applySettingsFontFamily(fontFamily);
  }

  getFontFamily(): string {
    return this.fontFamily;
  }

  setScale(scale: number): void {
    this.scale = scale;
    this.editor.applySettingsScale(scale);
  }

  getScale(): number {
    return this.scale;
  }

  setFoldArrowMode(mode: FoldArrowMode): void {
    this.foldArrowMode = mode;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setFoldArrowMode(mode));
    }
  }

  getFoldArrowMode(): FoldArrowMode {
    return this.foldArrowMode;
  }

  setWrapMode(mode: WrapMode): void {
    this.wrapMode = mode;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setWrapMode(mode));
    }
  }

  getWrapMode(): WrapMode {
    return this.wrapMode;
  }

  setLineSpacing(add: number, mult: number): void {
    this.lineSpacingAdd = add;
    this.lineSpacingMult = mult;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setLineSpacing(add, mult));
    }
  }

  getLineSpacingAdd(): number {
    return this.lineSpacingAdd;
  }

  getLineSpacingMult(): number {
    return this.lineSpacingMult;
  }

  setContentStartPadding(padding: number): void {
    this.contentStartPadding = Math.max(0, padding);
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setContentStartPadding(this.contentStartPadding));
    }
  }

  getContentStartPadding(): number {
    return this.contentStartPadding;
  }

  setShowSplitLine(show: boolean): void {
    this.showSplitLine = show;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setShowSplitLine(show));
    }
  }

  isShowSplitLine(): boolean {
    return this.showSplitLine;
  }

  setGutterSticky(sticky: boolean): void {
    this.gutterSticky = sticky;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setGutterSticky(sticky));
    }
  }

  isGutterSticky(): boolean {
    return this.gutterSticky;
  }

  setGutterVisible(visible: boolean): void {
    this.gutterVisible = visible;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setGutterVisible(visible));
    }
  }

  isGutterVisible(): boolean {
    return this.gutterVisible;
  }

  setCurrentLineRenderMode(mode: CurrentLineRenderMode): void {
    this.currentLineRenderMode = mode;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setCurrentLineRenderMode(mode));
    }
  }

  getCurrentLineRenderMode(): CurrentLineRenderMode {
    return this.currentLineRenderMode;
  }

  setAutoIndentMode(mode: AutoIndentMode): void {
    this.autoIndentMode = mode;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setAutoIndentMode(mode));
    }
  }

  getAutoIndentMode(): AutoIndentMode {
    return this.autoIndentMode;
  }

  setBackspaceUnindent(enabled: boolean): void {
    this.backspaceUnindent = enabled;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setBackspaceUnindent(enabled));
    }
  }

  isBackspaceUnindent(): boolean {
    return this.backspaceUnindent;
  }

  setReadOnly(readOnly: boolean): void {
    this.readOnly = readOnly;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setReadOnly(readOnly));
    }
  }

  isReadOnly(): boolean {
    return this.readOnly;
  }

  setMaxGutterIcons(count: number): void {
    this.maxGutterIcons = count;
    const editorCore = this.editor.getEditorCore();
    if (editorCore) {
      this.editor.dispatchEditorActionResult(editorCore.setMaxGutterIcons(count));
    }
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
