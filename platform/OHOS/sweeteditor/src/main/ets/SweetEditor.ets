import {
  Document,
  EditorCore,
  EditorOptions,
  EventType,
  GestureEvent,
  GestureResult,
  GestureType,
  HitTargetType,
  KeyEventResult,
  Modifier,
  TextChange,
  TextEditResult
} from './core/EditorCore';
import { ScrollBehavior, TextPosition, TextRange } from './core/EditorFoundation';
import { CursorRect, EditorRenderModel, PointF, ScrollMetrics } from './core/EditorVisual';
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
  StyleSpan
} from './core/EditorAdornments';
import { LinkedEditingModel } from './core/EditorLinkedEditing';
import { EditorIconProvider, EditorMetadata, EditorTheme, LanguageConfiguration } from './EditorTypes';
import { EditorSettings } from './EditorSettings';
import { EditorRenderer } from './EditorRenderer';
import { EditorEventBus } from './event/EditorEventBus';
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
  SelectionChangedEvent,
  TextChangeAction,
  TextChangedEvent
} from './event/EditorEvent';
import { CompletionProviderManager } from './completion/CompletionProviderManager';
import { CompletionPopupController } from './completion/CompletionPopupController';
import {
  CompletionItem,
  CompletionItemViewBuilder,
  CompletionItemViewFactory,
  CompletionProvider,
  CompletionTriggerKind
} from './completion/CompletionTypes';
import { InlineSuggestionController } from './copilot/InlineSuggestionController';
import { InlineSuggestion, InlineSuggestionListener } from './copilot/InlineSuggestionTypes';
import { DecorationProviderManager } from './decoration/DecorationProviderManager';
import { DecorationProvider } from './decoration/DecorationTypes';
import { NewLineActionProvider } from './newline/NewLineTypes';
import { NewLineActionProviderManager } from './newline/NewLineActionProviderManager';
import { SelectionMenuController } from './selection/SelectionMenuController';
import { SelectionMenuItemProvider } from './selection/SelectionMenuTypes';
import pasteboard from '@ohos.pasteboard';
import display from '@ohos.display';
import hilog from '@ohos.hilog';
import { inputMethod } from '@kit.IMEKit';
import { window } from '@kit.ArkUI';

const TAG = 'SweetEditor';
const HILOG_DOMAIN = 0x3D12;
const CURSOR_BLINK_INTERVAL_MS = 500;
const ANIMATION_FRAME_INTERVAL_MS = 16;
const TRANSIENT_SCROLLBAR_REFRESH_MIN_MS = 16;
const DEFAULT_CONTENT_START_PADDING_DP = 3.0;
const EDITOR_FOCUS_ID = 'sweeteditor-canvas';

interface PreviewCapableInputController {
  on(type: 'setPreviewText', callback: (text: string, range: inputMethod.Range) => void): void;

  on(type: 'finishTextPreview', callback: () => void): void;

  off(type: 'setPreviewText', callback?: (text: string, range: inputMethod.Range) => void): void;

  off(type: 'finishTextPreview', callback?: () => void): void;
}

interface SweetEditorExternalApi {
  loadDocument(document: Document): void;

  getDocument(): Document | null;

  getSettings(): EditorSettings | null;

  applyTheme(theme: EditorTheme): void;

  getTheme(): EditorTheme;

  setLanguageConfiguration(config: LanguageConfiguration | null): void;

  setMetadata(metadata: EditorMetadata | null): void;

  setEditorIconProvider(provider: EditorIconProvider | null): void;

  addDecorationProvider(provider: DecorationProvider): void;

  addCompletionProvider(provider: CompletionProvider): void;

  requestDecorationRefresh(): void;

  subscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void;

  unsubscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void;

  undo(): TextEditResult;

  redo(): TextEditResult;

  canUndo(): boolean;

  canRedo(): boolean;
}

export class SweetEditorController {
  private api: SweetEditorExternalApi | null = null;
  private pendingActions: Array<(api: SweetEditorExternalApi) => void> = [];
  private readyListeners: Array<() => void> = [];

  bind(api: SweetEditorExternalApi): void {
    this.api = api;
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

  unbind(api: SweetEditorExternalApi): void {
    if (this.api === api) {
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
    this.run((api) => api.loadDocument(document));
  }

  getDocument(): Document | null {
    return this.api ? this.api.getDocument() : null;
  }

  getSettings(): EditorSettings | null {
    return this.api ? this.api.getSettings() : null;
  }

  applyTheme(theme: EditorTheme): void {
    this.run((api) => api.applyTheme(theme));
  }

  getTheme(): EditorTheme | null {
    return this.api ? this.api.getTheme() : null;
  }

  setLanguageConfiguration(config: LanguageConfiguration | null): void {
    this.run((api) => api.setLanguageConfiguration(config));
  }

  setMetadata(metadata: EditorMetadata | null): void {
    this.run((api) => api.setMetadata(metadata));
  }

  setEditorIconProvider(provider: EditorIconProvider | null): void {
    this.run((api) => api.setEditorIconProvider(provider));
  }

  addDecorationProvider(provider: DecorationProvider): void {
    this.run((api) => api.addDecorationProvider(provider));
  }

  addCompletionProvider(provider: CompletionProvider): void {
    this.run((api) => api.addCompletionProvider(provider));
  }

  requestDecorationRefresh(): void {
    this.run((api) => api.requestDecorationRefresh());
  }

  subscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void {
    this.run((api) => api.subscribe(eventName, listener));
  }

  unsubscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void {
    if (this.api) {
      this.api.unsubscribe(eventName, listener);
    }
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

  private run(action: (api: SweetEditorExternalApi) => void): void {
    if (this.api) {
      action(this.api);
      return;
    }
    this.pendingActions.push(action);
  }
}

class BoundSweetEditorExternalApi implements SweetEditorExternalApi {
  private readonly editor: SweetEditor;

  constructor(editor: SweetEditor) {
    this.editor = editor;
  }

  loadDocument(document: Document): void {
    this.editor.loadDocument(document);
  }

  getDocument(): Document | null {
    return this.editor.getDocument();
  }

  getSettings(): EditorSettings | null {
    return this.editor.getSettings();
  }

  applyTheme(theme: EditorTheme): void {
    this.editor.applyTheme(theme);
  }

  getTheme(): EditorTheme {
    return this.editor.getTheme();
  }

  setLanguageConfiguration(config: LanguageConfiguration | null): void {
    this.editor.setLanguageConfiguration(config);
  }

  setMetadata(metadata: EditorMetadata | null): void {
    this.editor.setMetadata(metadata);
  }

  setEditorIconProvider(provider: EditorIconProvider | null): void {
    this.editor.setEditorIconProvider(provider);
  }

  addDecorationProvider(provider: DecorationProvider): void {
    this.editor.addDecorationProvider(provider);
  }

  addCompletionProvider(provider: CompletionProvider): void {
    this.editor.addCompletionProvider(provider);
  }

  requestDecorationRefresh(): void {
    this.editor.requestDecorationRefresh();
  }

  subscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void {
    this.editor.subscribe(eventName, listener);
  }

  unsubscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void {
    this.editor.unsubscribe(eventName, listener);
  }

  undo(): TextEditResult {
    return this.editor.undo();
  }

  redo(): TextEditResult {
    return this.editor.redo();
  }

  canUndo(): boolean {
    return this.editor.canUndo();
  }

  canRedo(): boolean {
    return this.editor.canRedo();
  }
}

/**
 * SweetEditor ArkUI component, providing code editing, syntax highlighting,
 * code folding, InlayHint and other features.
 *
 * Based on C++ core (EditorCore) for text layout and editing logic,
 * this component handles OHOS platform rendering, gestures, input method
 * integration and public APIs.
 */
@Component
export struct SweetEditor {
  controller: SweetEditorController | null = null;
  private editorCore: EditorCore | null = null;
  private renderer: EditorRenderer | null = null;
  private settings: EditorSettings | null = null;
  private theme: EditorTheme = EditorTheme.dark();
  private eventBus: EditorEventBus = new EditorEventBus();
  private document: Document | null = null;
  private languageConfiguration: LanguageConfiguration | null = null;
  private metadata: EditorMetadata | null = null;
  private canvasContext: CanvasRenderingContext2D | null = null;
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private cachedModel: EditorRenderModel | null = null;
  private modelDirty: boolean = true;
  private cursorVisible: boolean = true;
  private cursorBlinkTimerId: number = -1;
  private animationActive: boolean = false;
  private animationTimerId: number = -1;
  private transientScrollbarTimerId: number = -1;
  private density: number = 2.0;
  private viewWidth: number = 0;
  private viewHeight: number = 0;
  private initialized: boolean = false;
  // Subsystem controllers
  private decorationProviderManager: DecorationProviderManager | null = null;
  private completionProviderManager: CompletionProviderManager | null = null;
  private completionPopupController: CompletionPopupController | null = null;
  private inlineSuggestionController: InlineSuggestionController | null = null;
  private selectionMenuController: SelectionMenuController | null = null;
  private newLineActionProviderManager: NewLineActionProviderManager | null = null;
  private inputController: inputMethod.InputMethodController = inputMethod.getController();
  private imeAttached: boolean = false;
  private imeSyncScheduled: boolean = false;
  private editorFocused: boolean = false;
  private pendingShowKeyboard: boolean = false;
  private imeWindowId: number = -1;
  private editorGlobalX: number = 0;
  private editorGlobalY: number = 0;
  private controllerApi: SweetEditorExternalApi | null = null;
  private readonly onImeInsertText = (text: string): void => {
    if (this.editorCore && this.editorCore.isComposing()) {
      this.commitComposition(text);
      return;
    }
    this.insertText(text);
  };
  private readonly onImeDeleteLeft = (length: number): void => {
    this.deleteLeftByLength(length);
  };
  private readonly onImeDeleteRight = (length: number): void => {
    this.deleteRightByLength(length);
  };
  private readonly onImeMoveCursor = (direction: inputMethod.Direction): void => {
    this.moveCursorByIme(direction, false);
  };
  private readonly onImeSelectByMovement = (movement: inputMethod.Movement): void => {
    this.moveCursorByIme(movement.direction, true);
  };
  private readonly onImeSelectByRange = (range: inputMethod.Range): void => {
    this.selectRangeByIme(range);
  };
  private readonly onImeFunctionKey = (_functionKey: inputMethod.FunctionKey): void => {
    this.handleImeEnterKey();
  };
  private readonly onImeExtendAction = (action: inputMethod.ExtendAction): void => {
    this.handleImeExtendAction(action);
  };
  private readonly onImeKeyboardStatus = (status: inputMethod.KeyboardStatus): void => {
    if (status === inputMethod.KeyboardStatus.HIDE) {
      this.imeAttached = false;
    }
  };
  private readonly onImeSetPreviewText = (text: string, range: inputMethod.Range): void => {
    this.handleImePreviewText(text, range);
  };
  private readonly onImeFinishTextPreview = (): void => {
    this.finishImePreviewText();
  };
  @State private canvasWidth: number = 0;
  @State private canvasHeight: number = 0;

  aboutToAppear(): void {
    try {
      const defaultDisplay = display.getDefaultDisplaySync();
      this.density = defaultDisplay.densityPixels;
    } catch (e) {
      this.density = 2.0;
    }
    this.resolveImeWindowId();
  }

  aboutToDisappear(): void {
    this.stopCursorBlink();
    this.stopAnimation();
    this.clearTransientScrollbarTimer();
    this.unregisterImeCallbacks();
    this.detachInputMethod();
    if (this.selectionMenuController) {
      this.selectionMenuController.dismiss();
    }
    if (this.completionPopupController) {
      this.completionPopupController.dismiss();
    }
    if (this.controller && this.controllerApi) {
      this.controller.unbind(this.controllerApi);
    }
  }

  build() {
    Canvas(this.canvasContext = new CanvasRenderingContext2D(this.canvasSettings))
      .id(EDITOR_FOCUS_ID)
      .key(EDITOR_FOCUS_ID)
      .tabIndex(0)
      .focusOnTouch(true)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.initEditor();
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        const w = newValue.width as number;
        const h = newValue.height as number;
        this.editorGlobalX = this.lengthToNumber(newValue.globalPosition.x);
        this.editorGlobalY = this.lengthToNumber(newValue.globalPosition.y);
        if (w > 0 && h > 0 && (w !== this.viewWidth || h !== this.viewHeight)) {
          this.viewWidth = w;
          this.viewHeight = h;
          this.canvasWidth = w;
          this.canvasHeight = h;
          if (this.editorCore) {
            this.editorCore.setViewport(w, h);
            this.flush();
          }
        } else if (this.imeAttached) {
          this.scheduleImeSync();
        }
      })
      .onTouch((event: TouchEvent) => {
        this.handleTouchEvent(event);
      })
      .onKeyEvent((event: KeyEvent) => {
        if (event.type === KeyType.Down) {
          this.handleKeyEvent(event, true);
        }
      })
      .onFocus(() => {
        this.editorFocused = true;
        if (this.pendingShowKeyboard) {
          setTimeout(() => {
            if (this.pendingShowKeyboard) {
              this.ensureInputMethodAttached(true);
            }
          }, 0);
        }
      })
      .onBlur(() => {
        this.editorFocused = false;
        this.pendingShowKeyboard = false;
        this.hideInputMethod();
      })
      .focusable(true)
  }

  private initEditor(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    this.renderer = new EditorRenderer(this.theme, this.density);

    const touchSlop = 10;
    const options = new EditorOptions();
    options.touchSlop = touchSlop;
    options.doubleTapTimeout = 300;

    const ctx = this.canvasContext!;
    this.renderer.attachCanvasContext(ctx);

    this.editorCore = new EditorCore(this.renderer.getMeasurer(), options);
    this.editorCore.setHandleConfig(this.renderer.getHandleConfig());
    this.registerImeCallbacks();

    this.settings = new EditorSettings(this);
    this.settings.setContentStartPadding(DEFAULT_CONTENT_START_PADDING_DP);
    this.settings.setGutterSticky(false);

    this.editorCore.registerBatchTextStyles(this.theme.textStyles);

    this.initSubsystems();
    this.bindController();

    this.startCursorBlink();
    this.flush();
  }

  private bindController(): void {
    if (!this.controller) {
      return;
    }
    if (!this.controllerApi) {
      this.controllerApi = new BoundSweetEditorExternalApi(this);
    }
    this.controller.bind(this.controllerApi);
  }

  private initSubsystems(): void {
    // DecorationProviderManager
    this.decorationProviderManager = new DecorationProviderManager(this);

    // CompletionProviderManager + CompletionPopupController
    this.completionProviderManager = new CompletionProviderManager(this);
    const tc = this.theme;
    this.completionPopupController = new CompletionPopupController(
      tc.completionBgColor, tc.completionBorderColor,
      tc.completionSelectedBgColor, tc.completionLabelColor, tc.completionDetailColor
    );
    this.completionProviderManager.setListener(this.completionPopupController);
    this.completionPopupController.setConfirmHandler(
      (item: CompletionItem): void => this.applyCompletionItemInternal(item));

    // InlineSuggestionController
    this.inlineSuggestionController = new InlineSuggestionController(this, this.eventBus);

    // SelectionMenuController
    this.selectionMenuController = new SelectionMenuController(this, this.eventBus);

    // NewLineActionProviderManager
    this.newLineActionProviderManager = new NewLineActionProviderManager();
  }

  // ==================== Document Loading ====================

  loadDocument(document: Document): void {
    this.document = document;
    if (this.editorCore) {
      this.editorCore.loadDocument(document);
      this.eventBus.publish(new DocumentLoadedEvent());
      if (this.decorationProviderManager) {
        this.decorationProviderManager.onDocumentLoaded();
      }
      this.flush();
    }
  }

  getDocument(): Document | null {
    return this.document;
  }

  // ==================== Settings ====================

  getSettings(): EditorSettings | null {
    return this.settings;
  }

  getTheme(): EditorTheme {
    return this.theme;
  }

  applyTheme(theme: EditorTheme): void {
    this.theme = theme;
    if (this.renderer) {
      this.renderer.applyTheme(theme);
    }
    if (this.editorCore) {
      this.editorCore.registerBatchTextStyles(theme.textStyles);
    }
    if (this.completionPopupController) {
      this.completionPopupController.applyTheme(
        theme.completionBgColor, theme.completionBorderColor,
        theme.completionSelectedBgColor, theme.completionLabelColor, theme.completionDetailColor
      );
    }
    this.flush();
  }

  applyTextSize(textSize: number): void {
    if (this.renderer) {
      this.renderer.applyTextSize(textSize);
    }
    if (this.editorCore) {
      this.editorCore.onFontMetricsChanged();
    }
    this.flush();
  }

  applyFontFamily(fontFamily: string): void {
    if (this.renderer) {
      this.renderer.applyFontFamily(fontFamily);
    }
    if (this.editorCore) {
      this.editorCore.onFontMetricsChanged();
    }
    this.flush();
  }

  applyScale(scale: number): void {
    if (this.editorCore) {
      this.editorCore.setScale(scale);
    }
    this.syncPlatformScale(scale);
    this.flush();
  }

  getEditorCore(): EditorCore | null {
    return this.editorCore;
  }

  getVisibleLineRange(): number[] {
    const model = this.cachedModel;
    if (!model || !model.visualLines || model.visualLines.length === 0) {
      return [0, -1];
    }
    let start = Number.MAX_SAFE_INTEGER;
    let end = -1;
    for (const line of model.visualLines) {
      if (line.logicalLine < start) {
        start = line.logicalLine;
      }
      if (line.logicalLine > end) {
        end = line.logicalLine;
      }
    }
    if (start === Number.MAX_SAFE_INTEGER) {
      start = 0;
    }
    return [start, end];
  }

  getTotalLineCount(): number {
    return this.document ? this.document.getLineCount() : -1;
  }

  // ==================== Text Editing ====================

  insertText(text: string): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.insertText(text);
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  replaceText(range: TextRange, newText: string): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.replaceText(
      range.start.line, range.start.column,
      range.end.line, range.end.column, newText
    );
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  deleteText(range: TextRange): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.deleteText(
      range.start.line, range.start.column,
      range.end.line, range.end.column
    );
    this.dispatchTextChanged(TextChangeAction.DELETE, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  // ==================== Line Operations ====================

  moveLineUp(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.moveLineUp();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  moveLineDown(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.moveLineDown();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  copyLineUp(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.copyLineUp();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  copyLineDown(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.copyLineDown();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  deleteLine(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.deleteLine();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  insertLineAbove(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.insertLineAbove();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  insertLineBelow(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.insertLineBelow();
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  // ==================== Undo/Redo ====================

  undo(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.undo();
    this.dispatchTextChanged(TextChangeAction.UNDO, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  redo(): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.redo();
    this.dispatchTextChanged(TextChangeAction.REDO, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  canUndo(): boolean {
    return this.editorCore ? this.editorCore.canUndo() : false;
  }

  canRedo(): boolean {
    return this.editorCore ? this.editorCore.canRedo() : false;
  }

  // ==================== Cursor/Selection Management ====================

  selectAll(): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.selectAll();
    if (this.selectionMenuController) {
      this.selectionMenuController.onSelectAll();
    }
    this.flush();
  }

  getSelectedText(): string {
    return this.editorCore ? this.editorCore.getSelectedText() : '';
  }

  setSelection(startLineOrRange: number | TextRange, startColumn?: number,
    endLine?: number, endColumn?: number): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setSelection(startLineOrRange, startColumn, endLine, endColumn);
    this.flush();
  }

  getSelection(): TextRange | null {
    return this.editorCore ? this.editorCore.getSelection() : null;
  }

  hasSelection(): boolean {
    return this.editorCore ? this.editorCore.getSelection() !== null : false;
  }

  setSelectionMenuItemProvider(provider: SelectionMenuItemProvider | null): void {
    if (this.selectionMenuController) {
      this.selectionMenuController.setItemProvider(provider);
    }
  }

  getCursorPosition(): TextPosition {
    return this.editorCore ? this.editorCore.getCursorPosition() : { line: 0, column: 0 };
  }

  getWordRangeAtCursor(): TextRange {
    return this.editorCore ? this.editorCore.getWordRangeAtCursor()
      : { start: { line: 0, column: 0 }, end: { line: 0, column: 0 } };
  }

  getWordAtCursor(): string {
    return this.editorCore ? this.editorCore.getWordAtCursor() : '';
  }

  setCursorPosition(position: TextPosition): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setCursorPosition(position.line, position.column);
    this.flush();
  }

  setSelectionRange(range: TextRange): void {
    this.setSelection(range);
  }

  // ==================== Clipboard Operations ====================

  async copyToClipboard(): Promise<void> {
    const selected = this.getSelectedText();
    if (selected && selected.length > 0) {
      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, selected);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        await systemPasteboard.setData(pasteData);
      } catch (e) {
      }
    }
  }

  async pasteFromClipboard(): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const hasData = await systemPasteboard.hasData();
      if (hasData) {
        const pasteData = await systemPasteboard.getData();
        const text = pasteData.getPrimaryText();
        if (text && text.length > 0) {
          this.insertText(text);
        }
      }
    } catch (e) {
    }
  }

  async cutToClipboard(): Promise<void> {
    const selected = this.getSelectedText();
    if (selected && selected.length > 0) {
      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, selected);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        await systemPasteboard.setData(pasteData);
        this.insertText('');
      } catch (e) {
      }
    }
  }

  // ==================== Position/Coordinate Query API ====================

  getPositionRect(line: number, column: number): CursorRect {
    return this.editorCore ? this.editorCore.getPositionRect(line, column)
      : { x: 0, y: 0, height: 0 };
  }

  getCursorRect(): CursorRect {
    return this.editorCore ? this.editorCore.getCursorRect()
      : { x: 0, y: 0, height: 0 };
  }

  getViewWidth(): number {
    return this.viewWidth;
  }

  getViewHeight(): number {
    return this.viewHeight;
  }

  // ==================== Scroll/Navigation ====================

  gotoPosition(line: number, column: number): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.gotoPosition(line, column);
    this.flush();
  }

  scrollToLine(line: number, behavior: ScrollBehavior = ScrollBehavior.CENTER): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.scrollToLine(line, behavior);
    this.flush();
  }

  setScroll(scrollX: number, scrollY: number): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setScroll(scrollX, scrollY);
    this.flush();
  }

  getScrollMetrics(): ScrollMetrics {
    if (!this.editorCore) {
      return {
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
    return this.editorCore.getScrollMetrics();
  }

  // ==================== Decoration System ====================

  registerTextStyle(styleId: number, color: number, backgroundColorOrFontStyle: number, fontStyle?: number): void {
    if (this.editorCore) {
      this.editorCore.registerTextStyle(styleId, color, backgroundColorOrFontStyle, fontStyle);
    }
  }

  registerTextStyleSimple(styleId: number, color: number, fontStyle: number): void {
    this.registerTextStyle(styleId, color, fontStyle);
  }

  setLineSpans(line: number, layer: SpanLayer, spans: StyleSpan[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineSpans(line, layer as number, spans);
  }

  setBatchLineSpans(layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLineSpans(layer as number, spansByLine);
  }

  setLineInlayHints(line: number, hints: InlayHint[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineInlayHints(line, hints);
  }

  setBatchLineInlayHints(hintsByLine: Map<number, InlayHint[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLineInlayHints(hintsByLine);
  }

  setLinePhantomTexts(line: number, phantoms: PhantomText[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLinePhantomTexts(line, phantoms);
  }

  setBatchLinePhantomTexts(phantomsByLine: Map<number, PhantomText[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLinePhantomTexts(phantomsByLine);
  }

  setLineGutterIcons(line: number, icons: GutterIcon[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineGutterIcons(line, icons);
  }

  setBatchLineGutterIcons(iconsByLine: Map<number, GutterIcon[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLineGutterIcons(iconsByLine);
  }

  setLineDiagnostics(line: number, items: DiagnosticItem[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineDiagnostics(line, items);
  }

  setBatchLineDiagnostics(diagsByLine: Map<number, DiagnosticItem[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLineDiagnostics(diagsByLine);
  }

  setIndentGuides(guides: IndentGuide[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setIndentGuides(guides);
  }

  setBracketGuides(guides: BracketGuide[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBracketGuides(guides);
  }

  setFlowGuides(guides: FlowGuide[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setFlowGuides(guides);
  }

  setSeparatorGuides(guides: SeparatorGuide[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setSeparatorGuides(guides);
  }

  setFoldRegions(regions: FoldRegion[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setFoldRegions(regions);
  }

  toggleFoldAt(line: number): boolean {
    if (!this.editorCore) {
      return false;
    }
    const result = this.editorCore.toggleFoldAt(line);
    if (result) {
      this.flush();
    }
    return result;
  }

  foldAt(line: number): boolean {
    if (!this.editorCore) {
      return false;
    }
    const result = this.editorCore.foldAt(line);
    if (result) {
      this.flush();
    }
    return result;
  }

  unfoldAt(line: number): boolean {
    if (!this.editorCore) {
      return false;
    }
    const result = this.editorCore.unfoldAt(line);
    if (result) {
      this.flush();
    }
    return result;
  }

  foldAll(): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.foldAll();
    this.flush();
  }

  unfoldAll(): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.unfoldAll();
    this.flush();
  }

  isLineVisible(line: number): boolean {
    return this.editorCore ? this.editorCore.isLineVisible(line) : true;
  }

  insertSnippet(snippetTemplate: string): TextEditResult {
    if (!this.editorCore) {
      return { changes: [] };
    }
    const result = this.editorCore.insertSnippet(snippetTemplate);
    this.dispatchTextChanged(TextChangeAction.INSERT, result);
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  startLinkedEditing(model: LinkedEditingModel): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.startLinkedEditing(model);
    this.resetCursorBlink();
    this.flush();
  }

  isInLinkedEditing(): boolean {
    return this.editorCore ? this.editorCore.isInLinkedEditing() : false;
  }

  linkedEditingNext(): boolean {
    if (!this.editorCore) {
      return false;
    }
    const result = this.editorCore.linkedEditingNext();
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  linkedEditingPrev(): boolean {
    if (!this.editorCore) {
      return false;
    }
    const result = this.editorCore.linkedEditingPrev();
    this.resetCursorBlink();
    this.flush();
    return result;
  }

  cancelLinkedEditing(): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.cancelLinkedEditing();
    this.flush();
  }

  clearHighlights(layer?: SpanLayer): void {
    if (this.editorCore) {
      this.editorCore.clearHighlights(layer);
    }
  }

  clearHighlightsLayer(layer: SpanLayer): void {
    if (this.editorCore) {
      this.editorCore.clearHighlights(layer);
    }
  }

  clearInlayHints(): void {
    if (this.editorCore) {
      this.editorCore.clearInlayHints();
    }
  }

  clearPhantomTexts(): void {
    if (this.editorCore) {
      this.editorCore.clearPhantomTexts();
    }
  }

  clearGutterIcons(): void {
    if (this.editorCore) {
      this.editorCore.clearGutterIcons();
    }
  }

  clearGuides(): void {
    if (this.editorCore) {
      this.editorCore.clearGuides();
    }
  }

  clearDiagnostics(): void {
    if (this.editorCore) {
      this.editorCore.clearDiagnostics();
    }
  }

  clearAllDecorations(): void {
    if (this.editorCore) {
      this.editorCore.clearAllDecorations();
    }
  }

  flush(): void {
    this.modelDirty = true;
    this.invalidateCanvas();
    this.scheduleImeSync();
  }

  // ==================== View Layer Extension Configuration ====================

  setLanguageConfiguration(config: LanguageConfiguration | null): void {
    this.languageConfiguration = config;
    if (config && this.editorCore) {
      if (config.brackets.length > 0) {
        const opens: number[] = [];
        const closes: number[] = [];
        for (const pair of config.brackets) {
          opens.push(pair.open.length > 0 ? pair.open.codePointAt(0)! : 0);
          closes.push(pair.close.length > 0 ? pair.close.codePointAt(0)! : 0);
        }
        this.editorCore.setBracketPairs(opens, closes);
      }
      if (config.tabSize > 0) {
        this.editorCore.setTabSize(config.tabSize);
      }
    }
  }

  getLanguageConfiguration(): LanguageConfiguration | null {
    return this.languageConfiguration;
  }

  setMetadata(metadata: EditorMetadata | null): void {
    this.metadata = metadata;
  }

  getMetadata(): EditorMetadata | null {
    return this.metadata;
  }

  setEditorIconProvider(provider: EditorIconProvider | null): void {
    if (this.renderer) {
      this.renderer.setEditorIconProvider(provider);
    }
  }

  // ==================== Extension Provider API ====================

  addDecorationProvider(provider: DecorationProvider): void {
    if (this.decorationProviderManager) {
      this.decorationProviderManager.addProvider(provider);
    }
  }

  removeDecorationProvider(provider: DecorationProvider): void {
    if (this.decorationProviderManager) {
      this.decorationProviderManager.removeProvider(provider);
    }
  }

  requestDecorationRefresh(): void {
    if (this.decorationProviderManager) {
      this.decorationProviderManager.requestRefresh();
    }
  }

  addCompletionProvider(provider: CompletionProvider): void {
    if (this.completionProviderManager) {
      this.completionProviderManager.addProvider(provider);
    }
  }

  removeCompletionProvider(provider: CompletionProvider): void {
    if (this.completionProviderManager) {
      this.completionProviderManager.removeProvider(provider);
    }
  }

  triggerCompletion(): void {
    if (this.completionProviderManager) {
      this.completionProviderManager.triggerCompletion(CompletionTriggerKind.INVOKED, null);
    }
  }

  showCompletionItems(items: CompletionItem[]): void {
    if (this.completionProviderManager) {
      this.completionProviderManager.showItems(items);
    }
  }

  dismissCompletion(): void {
    if (this.completionProviderManager) {
      this.completionProviderManager.dismiss();
    }
  }

  setCompletionItemViewFactory(factory: CompletionItemViewFactory | null): void {
    this.setCompletionItemViewBuilder(factory);
  }

  setCompletionItemViewBuilder(builder: CompletionItemViewBuilder | null): void {
    if (this.completionPopupController) {
      this.completionPopupController.setViewBuilder(builder);
    }
  }

  // ==================== Inline Suggestion (Copilot) API ====================

  showInlineSuggestion(suggestion: InlineSuggestion): void {
    if (this.inlineSuggestionController) {
      this.inlineSuggestionController.show(suggestion);
    }
  }

  dismissInlineSuggestion(): void {
    if (this.inlineSuggestionController) {
      this.inlineSuggestionController.dismiss();
    }
  }

  isInlineSuggestionShowing(): boolean {
    return this.inlineSuggestionController ? this.inlineSuggestionController.isShowing() : false;
  }

  setInlineSuggestionListener(listener: InlineSuggestionListener | null): void {
    if (this.inlineSuggestionController) {
      this.inlineSuggestionController.setListener(listener);
    }
  }

  addNewLineActionProvider(provider: NewLineActionProvider): void {
    if (this.newLineActionProviderManager) {
      this.newLineActionProviderManager.addProvider(provider);
    }
  }

  removeNewLineActionProvider(provider: NewLineActionProvider): void {
    if (this.newLineActionProviderManager) {
      this.newLineActionProviderManager.removeProvider(provider);
    }
  }

  // ==================== Event Subscription ====================

  subscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void {
    this.eventBus.subscribe(eventName, listener);
  }

  unsubscribe<T extends EditorEvent>(eventName: string, listener: EditorEventListener<T>): void {
    this.eventBus.unsubscribe(eventName, listener);
  }

  // ==================== Performance Debug API ====================

  setPerfOverlayEnabled(enabled: boolean): void {
    if (this.renderer) {
      this.renderer.getPerfOverlay().setEnabled(enabled);
    }
  }

  isPerfOverlayEnabled(): boolean {
    return this.renderer ? this.renderer.getPerfOverlay().isEnabled() : false;
  }

  // ==================== IME Internal Methods (package-private) ====================

  compositionUpdate(text: string): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.compositionUpdate(text);
    this.flush();
  }

  commitComposition(text: string): void {
    if (!this.editorCore) {
      return;
    }
    const result = this.editorCore.compositionEnd(text);
    this.dispatchTextChanged(TextChangeAction.COMPOSITION, result);
    this.flush();
  }

  // ==================== Keyboard Event Handling ====================

  private handleKeyEvent(event: KeyEvent, allowTextFallback: boolean): void {
    if (!this.editorCore) {
      return;
    }

    const keyCode = event.keyCode;
    const modifiers = this.getNativeModifiers(event);

    // Inline suggestion interception (Tab/Escape)
    if (this.inlineSuggestionController && this.inlineSuggestionController.isShowing()) {
      const ohosToAndroid = this.mapOhosKeyCodeToAndroid(keyCode);
      if (ohosToAndroid !== 0 && this.inlineSuggestionController.handleKeyCode(ohosToAndroid)) {
        return;
      }
    }

    // Completion panel interception (Enter/Escape/Up/Down)
    if (this.completionPopupController && this.completionPopupController.isShowing()) {
      const ohosToAndroid = this.mapOhosKeyCodeToAndroid(keyCode);
      if (ohosToAndroid !== 0 && this.completionPopupController.handleKeyCode(ohosToAndroid)) {
        return;
      }
    }

    // Ctrl shortcuts
    if ((modifiers & 2) !== 0) {
      if (this.handleCtrlShortcut(event)) {
        this.resetCursorBlink();
        this.flush();
        return;
      }
    }

    const nativeKeyCode = this.mapOhosKeyCodeToNative(keyCode);
    if (nativeKeyCode !== 0) {
      // Enter key: check NewLineActionProvider first
      if (nativeKeyCode === 13 && this.tryHandleNewLineAction()) {
        return;
      }

      const result = this.editorCore.handleKeyEvent(nativeKeyCode, null, modifiers);
      this.dispatchKeyEventResult(result);
      this.resetCursorBlink();
      this.flush();
      return;
    }

    if (!allowTextFallback || (modifiers & ~1) !== 0) {
      return;
    }

    const text = this.extractPrintableKeyText(event);
    if (text === null) {
      return;
    }

    const result = this.editorCore.handleKeyEvent(0, text, modifiers);
    this.dispatchKeyEventResult(result);
    this.resetCursorBlink();
    this.flush();
  }

  private handleCtrlShortcut(event: KeyEvent): boolean {
    switch (event.keyCode) {
      case 2017: // A
        this.selectAll();
        return true;
      case 2019: // C
        this.copyToClipboard();
        return true;
      case 2038: // V
        this.pasteFromClipboard();
        return true;
      case 2040: // X
        this.cutToClipboard();
        return true;
      case 2042: // Z
        if (this.isModifierPressed(event, 'shift')) {
          this.redo();
        } else {
          this.undo();
        }
        return true;
      default:
        return false;
    }
  }

  private mapOhosKeyCodeToNative(ohosKeyCode: number): number {
    switch (ohosKeyCode) {
      case 2055:
        return 8; // BACKSPACE
      case 2049:
        return 9; // TAB
      case 2054:
        return 13; // ENTER
      case 2070:
        return 27; // ESCAPE
      case 2071:
        return 46; // DELETE (FORWARD_DEL)
      case 2012:
        return 37; // DPAD_LEFT
      case 2013:
        return 38; // DPAD_UP
      case 2014:
        return 39; // DPAD_RIGHT
      case 2015:
        return 40; // DPAD_DOWN
      case 2081:
        return 36; // HOME
      case 2082:
        return 35; // END
      case 2059:
        return 33; // PAGE_UP
      case 2060:
        return 34; // PAGE_DOWN
      default:
        return 0;
    }
  }

  private mapOhosKeyCodeToAndroid(ohosKeyCode: number): number {
    switch (ohosKeyCode) {
      case 2049:
        return 61; // TAB
      case 2054:
        return 66; // ENTER
      case 2070:
        return 111; // ESCAPE
      case 2013:
        return 19; // UP
      case 2015:
        return 20; // DOWN
      default:
        return 0;
    }
  }

  private isModifierPressed(event: KeyEvent, key: string): boolean {
    if (!event.getModifierKeyState) {
      return false;
    }
    return event.getModifierKeyState([key]);
  }

  private getNativeModifiers(event: KeyEvent): number {
    let modifiers = 0;
    if (this.isModifierPressed(event, 'shift')) {
      modifiers |= 1;
    }
    if (this.isModifierPressed(event, 'ctrl')) {
      modifiers |= 2;
    }
    if (this.isModifierPressed(event, 'alt')) {
      modifiers |= 4;
    }
    if (event.metaKey === 1) {
      modifiers |= 8;
    }
    return modifiers;
  }

  private extractPrintableKeyText(event: KeyEvent): string | null {
    const keyText = event.keyText;
    if (!keyText || Array.from(keyText).length !== 1) {
      return null;
    }

    return this.isPrintableText(keyText) ? keyText : null;
  }

  private isPrintableText(text: string): boolean {
    return text.length > 0 && !/[\u0000-\u001f\u007f]/.test(text);
  }

  // ==================== Completion Internal ====================

  applyCompletionItemInternal(item: CompletionItem): void {
    if (!this.editorCore) {
      return;
    }
    let text = item.insertText !== null ? item.insertText : item.label;
    const isSnippet = item.insertTextFormat === CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;

    let replaceRange: TextRange | null = null;
    if (item.textEdit !== null) {
      replaceRange = item.textEdit.range;
      text = item.textEdit.newText;
    } else {
      const wr = this.getWordRangeAtCursor();
      if (wr.start.line !== wr.end.line || wr.start.column !== wr.end.column) {
        replaceRange = wr;
      }
    }

    if (replaceRange !== null) {
      this.deleteText(replaceRange);
    }
    if (isSnippet) {
      this.insertSnippet(text);
    } else {
      this.insertText(text);
    }
  }

  // ==================== Touch Event Handling ====================

  private handleTouchEvent(event: TouchEvent): void {
    if (!this.editorCore) {
      return;
    }

    const gestureEvent = this.convertTouchToGestureEvent(event);
    const result = this.editorCore.handleGestureEvent(gestureEvent);

    const screenPoint: PointF = event.touches.length > 0
      ? { x: event.touches[0].x, y: event.touches[0].y }
      : { x: 0, y: 0 };

    this.fireGestureEvents(result, screenPoint);

    const isPointerReleased = event.type === TouchType.Up || event.type === TouchType.Cancel;
    if (this.selectionMenuController) {
      this.selectionMenuController.onGestureResult(result, isPointerReleased);
    }

    if (result.type === GestureType.TAP) {
      if (result.hitTarget.type === HitTargetType.NONE) {
        this.showSoftKeyboard();
      }
      this.resetCursorBlink();
    } else if (result.type === GestureType.SCALE) {
      this.syncPlatformScale(result.viewScale);
    }

    this.flush();

    if (result.needsAnimation && !this.animationActive) {
      this.startAnimation();
    } else if (!result.needsAnimation && this.animationActive) {
      this.stopAnimation();
    }
  }

  private convertTouchToGestureEvent(event: TouchEvent): GestureEvent {
    let eventType: EventType;
    switch (event.type) {
      case TouchType.Down:
        eventType = event.touches.length > 1 ? EventType.TOUCH_POINTER_DOWN : EventType.TOUCH_DOWN;
        break;
      case TouchType.Move:
        eventType = EventType.TOUCH_MOVE;
        break;
      case TouchType.Up:
        eventType = event.touches.length > 1 ? EventType.TOUCH_POINTER_UP : EventType.TOUCH_UP;
        break;
      case TouchType.Cancel:
        eventType = EventType.TOUCH_CANCEL;
        break;
      default:
        eventType = EventType.TOUCH_DOWN;
    }

    const points: PointF[] = [];
    for (const touch of event.touches) {
      points.push({ x: touch.x, y: touch.y });
    }

    return {
      type: eventType,
      points: points,
      modifiers: Modifier.NONE,
      wheelDeltaX: 0,
      wheelDeltaY: 0,
      directScale: 0
    };
  }

  // ==================== Event Dispatch ====================

  private fireGestureEvents(result: GestureResult, screenPoint: PointF): void {
    switch (result.type) {
      case GestureType.LONG_PRESS:
        this.eventBus.publish(new LongPressEvent(result.cursorPosition, screenPoint));
        this.eventBus.publish(new CursorChangedEvent(result.cursorPosition));
        break;
      case GestureType.DOUBLE_TAP:
        this.eventBus.publish(new DoubleTapEvent(
          result.cursorPosition, result.hasSelection, result.selection, screenPoint));
        this.eventBus.publish(new CursorChangedEvent(result.cursorPosition));
        if (result.hasSelection) {
          this.eventBus.publish(new SelectionChangedEvent(
            true, result.selection, result.cursorPosition));
        }
        break;
      case GestureType.TAP:
        this.eventBus.publish(new CursorChangedEvent(result.cursorPosition));
        if (result.hitTarget && result.hitTarget.type !== HitTargetType.NONE) {
          this.fireHitTargetEvent(result, screenPoint);
        }
        break;
      case GestureType.SCROLL:
      case GestureType.FAST_SCROLL:
        this.eventBus.publish(new ScrollChangedEvent(result.viewScrollX, result.viewScrollY));
        if (this.decorationProviderManager) {
          this.decorationProviderManager.onScrollChanged();
        }
        break;
      case GestureType.SCALE:
        this.eventBus.publish(new ScaleChangedEvent(result.viewScale));
        break;
      case GestureType.DRAG_SELECT:
        this.eventBus.publish(new SelectionChangedEvent(
          result.hasSelection, result.selection, result.cursorPosition));
        break;
      case GestureType.CONTEXT_MENU:
        this.eventBus.publish(new ContextMenuEvent(result.cursorPosition, screenPoint));
        break;
    }
  }

  private fireHitTargetEvent(result: GestureResult, screenPoint: PointF): void {
    const ht = result.hitTarget;
    switch (ht.type) {
      case HitTargetType.INLAY_HINT_TEXT:
      case HitTargetType.INLAY_HINT_ICON:
        this.eventBus.publish(new InlayHintClickEvent(
          ht.line, ht.column, ht.iconId,
          ht.type === HitTargetType.INLAY_HINT_ICON, screenPoint));
        break;
      case HitTargetType.INLAY_HINT_COLOR:
        this.eventBus.publish(new InlayHintClickEvent(
          ht.line, ht.column, ht.colorValue, screenPoint));
        break;
      case HitTargetType.GUTTER_ICON:
        this.eventBus.publish(new GutterIconClickEvent(ht.line, ht.iconId, screenPoint));
        break;
      case HitTargetType.FOLD_PLACEHOLDER:
      case HitTargetType.FOLD_GUTTER:
        this.eventBus.publish(new FoldToggleEvent(
          ht.line, ht.type === HitTargetType.FOLD_GUTTER, screenPoint));
        break;
    }
  }

  private dispatchTextChanged(action: TextChangeAction, editResult: TextEditResult): void {
    const textChanges: TextChange[] = [];
    if (editResult.changes && editResult.changes.length > 0) {
      for (const change of editResult.changes) {
        this.eventBus.publish(new TextChangedEvent(action, change.range, change.newText));
        textChanges.push({ range: change.range, newText: change.newText });
      }
    }

    // Notify subsystems
    if (this.decorationProviderManager && textChanges.length > 0) {
      this.decorationProviderManager.onTextChanged(textChanges);
    }
    if (this.selectionMenuController) {
      this.selectionMenuController.onTextChanged();
    }

    // Trigger character completion
    if (this.completionProviderManager && textChanges.length > 0) {
      const lastChange = textChanges[textChanges.length - 1];
      if (lastChange.newText && lastChange.newText.length === 1) {
        const ch = lastChange.newText;
        if (this.completionProviderManager.isTriggerCharacter(ch)) {
          this.completionProviderManager.triggerCompletion(CompletionTriggerKind.CHARACTER, ch);
        }
      }
    }
  }

  private dispatchKeyEventResult(result: KeyEventResult): void {
    if (result.contentChanged) {
      if (result.editResult && result.editResult.changes.length > 0) {
        for (const change of result.editResult.changes) {
          this.eventBus.publish(new TextChangedEvent(TextChangeAction.KEY, change.range, change.newText));
        }
      } else {
        this.eventBus.publish(new TextChangedEvent(TextChangeAction.KEY, null, null));
      }
    }
    if (result.cursorChanged && this.editorCore) {
      this.eventBus.publish(new CursorChangedEvent(this.editorCore.getCursorPosition()));
    }
  }

  // ==================== Rendering ====================

  private invalidateCanvas(): void {
    if (!this.canvasContext || !this.renderer || !this.editorCore) {
      return;
    }

    if (this.modelDirty) {
      this.cachedModel = this.editorCore.buildRenderModel();
      this.modelDirty = false;
    }

    const model = this.cachedModel;
    if (!model) {
      this.canvasContext.fillStyle = colorToHex(this.theme.backgroundColor);
      this.canvasContext.fillRect(0, 0, this.viewWidth, this.viewHeight);
      return;
    }

    const needsTransientRefresh = this.renderer.render(
      this.canvasContext, model, this.viewWidth, this.viewHeight, this.cursorVisible);

    // Update subsystem positions
    if (model.cursor && model.cursor.visible && model.cursor.position) {
      if (this.completionPopupController) {
        this.completionPopupController.updateCursorPosition(
          model.cursor.position.x, model.cursor.position.y, model.cursor.height);
      }
      if (this.inlineSuggestionController && this.inlineSuggestionController.isShowing()) {
        this.inlineSuggestionController.updatePosition(
          model.cursor.position.x, model.cursor.position.y, model.cursor.height);
      }
    }
    if (this.selectionMenuController && model.selectionStartHandle && model.selectionEndHandle) {
      this.selectionMenuController.updateSelectionHandles(
        {
          visible: model.selectionStartHandle.visible,
          x: model.selectionStartHandle.position.x,
          y: model.selectionStartHandle.position.y,
          height: model.selectionStartHandle.height
        },
        {
          visible: model.selectionEndHandle.visible,
          x: model.selectionEndHandle.position.x,
          y: model.selectionEndHandle.position.y,
          height: model.selectionEndHandle.height
        }
      );
    }

    if (needsTransientRefresh) {
      this.scheduleTransientScrollbarRefresh(TRANSIENT_SCROLLBAR_REFRESH_MIN_MS);
    } else {
      this.clearTransientScrollbarTimer();
    }
  }

  // ==================== Animation & Timers ====================

  private startCursorBlink(): void {
    this.stopCursorBlink();
    this.cursorBlinkTimerId = setInterval(() => {
      this.cursorVisible = !this.cursorVisible;
      this.invalidateCanvas();
    }, CURSOR_BLINK_INTERVAL_MS);
  }

  private stopCursorBlink(): void {
    if (this.cursorBlinkTimerId >= 0) {
      clearInterval(this.cursorBlinkTimerId);
      this.cursorBlinkTimerId = -1;
    }
  }

  private resetCursorBlink(): void {
    this.cursorVisible = true;
    this.startCursorBlink();
  }

  private startAnimation(): void {
    if (this.animationActive) {
      return;
    }
    this.animationActive = true;
    this.animationTimerId = setInterval(() => {
      if (!this.animationActive || !this.editorCore) {
        this.stopAnimation();
        return;
      }
      const result = this.editorCore.tickAnimations();
      this.fireGestureEvents(result, { x: 0, y: 0 });
      this.flush();
      if (!result.needsAnimation) {
        this.stopAnimation();
      }
    }, ANIMATION_FRAME_INTERVAL_MS);
  }

  private stopAnimation(): void {
    this.animationActive = false;
    if (this.animationTimerId >= 0) {
      clearInterval(this.animationTimerId);
      this.animationTimerId = -1;
    }
  }

  private scheduleTransientScrollbarRefresh(delayMs: number): void {
    this.clearTransientScrollbarTimer();
    this.transientScrollbarTimerId = setTimeout(() => {
      this.flush();
    }, Math.max(TRANSIENT_SCROLLBAR_REFRESH_MIN_MS, delayMs));
  }

  private clearTransientScrollbarTimer(): void {
    if (this.transientScrollbarTimerId >= 0) {
      clearTimeout(this.transientScrollbarTimerId);
      this.transientScrollbarTimerId = -1;
    }
  }

  private syncPlatformScale(scale: number): void {
    if (this.renderer) {
      this.renderer.syncPlatformScale(scale);
    }
    if (this.editorCore) {
      this.editorCore.onFontMetricsChanged();
    }
  }

  private resolveImeWindowId(): void {
    const uiContext = this.getUIContext();
    const hostContext = uiContext.getHostContext();
    if (!hostContext) {
      return;
    }
    window.getLastWindow(hostContext).then((win) => {
      this.imeWindowId = win.getWindowProperties().id;
      if (this.imeAttached) {
        this.inputController.setCallingWindow(this.imeWindowId).catch(() => {
        });
      }
    }).catch(() => {
    });
  }

  private registerImeCallbacks(): void {
    try {
      this.inputController.on('insertText', this.onImeInsertText);
      this.inputController.on('deleteLeft', this.onImeDeleteLeft);
      this.inputController.on('deleteRight', this.onImeDeleteRight);
      this.inputController.on('moveCursor', this.onImeMoveCursor);
      this.inputController.on('selectByMovement', this.onImeSelectByMovement);
      this.inputController.on('selectByRange', this.onImeSelectByRange);
      this.inputController.on('sendFunctionKey', this.onImeFunctionKey);
      this.inputController.on('handleExtendAction', this.onImeExtendAction);
      this.inputController.on('sendKeyboardStatus', this.onImeKeyboardStatus);
    } catch (e) {
    }
    try {
      const previewController = this.getPreviewInputController();
      previewController.on('setPreviewText', this.onImeSetPreviewText);
      previewController.on('finishTextPreview', this.onImeFinishTextPreview);
    } catch (e) {
    }
  }

  private unregisterImeCallbacks(): void {
    try {
      this.inputController.off('insertText', this.onImeInsertText);
      this.inputController.off('deleteLeft', this.onImeDeleteLeft);
      this.inputController.off('deleteRight', this.onImeDeleteRight);
      this.inputController.off('moveCursor', this.onImeMoveCursor);
      this.inputController.off('selectByMovement', this.onImeSelectByMovement);
      this.inputController.off('selectByRange', this.onImeSelectByRange);
      this.inputController.off('sendFunctionKey', this.onImeFunctionKey);
      this.inputController.off('handleExtendAction', this.onImeExtendAction);
      this.inputController.off('sendKeyboardStatus', this.onImeKeyboardStatus);
    } catch (e) {
    }
    try {
      const previewController = this.getPreviewInputController();
      previewController.off('setPreviewText', this.onImeSetPreviewText);
      previewController.off('finishTextPreview', this.onImeFinishTextPreview);
    } catch (e) {
    }
  }

  private ensureInputMethodAttached(showKeyboard: boolean): void {
    if (!this.editorCore) {
      return;
    }
    const textConfig: inputMethod.TextConfig = {
      inputAttribute: {
        textInputType: inputMethod.TextInputType.MULTILINE,
        enterKeyType: inputMethod.EnterKeyType.NONE
      },
      cursorInfo: this.buildImeCursorInfo(),
      selection: this.buildImeSelectionRange()
    };
    if (this.imeWindowId >= 0) {
      textConfig.windowId = this.imeWindowId;
    }

    let attachPromise: Promise<void>;
    try {
      attachPromise = this.imeAttached
        ? (showKeyboard ? this.inputController.showTextInput() : Promise.resolve())
        : this.inputController.attach(false, textConfig);
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'attach/showTextInput threw %{public}s', JSON.stringify(e));
      return;
    }

    attachPromise.then(() => {
      this.imeAttached = true;
      this.pendingShowKeyboard = false;
      this.unregisterImeCallbacks();
      this.registerImeCallbacks();
      if (this.imeWindowId >= 0) {
        this.inputController.setCallingWindow(this.imeWindowId).catch(() => {
        });
      }
      const showPromise = showKeyboard ? this.inputController.showTextInput() : Promise.resolve();
      showPromise.then(() => {
        this.scheduleImeSync();
      }).catch((e: Error) => {
        hilog.error(HILOG_DOMAIN, TAG, 'showTextInput failed %{public}s', JSON.stringify(e));
      });
    }).catch((e: Error) => {
      hilog.error(HILOG_DOMAIN, TAG, 'attach failed %{public}s', JSON.stringify(e));
    });
  }

  private hideInputMethod(): void {
    this.pendingShowKeyboard = false;
    if (!this.imeAttached) {
      return;
    }
    this.inputController.hideTextInput().catch(() => {
    });
    this.detachInputMethod();
  }

  private detachInputMethod(): void {
    if (!this.imeAttached) {
      return;
    }
    this.inputController.detach().catch(() => {
    });
    this.imeAttached = false;
  }

  private scheduleImeSync(): void {
    if (!this.imeAttached || this.imeSyncScheduled || !this.editorCore) {
      return;
    }
    this.imeSyncScheduled = true;
    setTimeout(() => {
      this.imeSyncScheduled = false;
      this.syncInputMethodState();
    }, 0);
  }

  private syncInputMethodState(): void {
    if (!this.imeAttached || !this.editorCore) {
      return;
    }
    const selection = this.buildImeSelectionRange();
    const selectedText = this.getSelectedText();
    const cursorInfo = this.buildImeCursorInfo();
    this.inputController.changeSelection(selectedText, selection.start, selection.end).catch(() => {
    });
    this.inputController.updateCursor(cursorInfo).catch(() => {
    });
  }

  private buildImeSelectionRange(): inputMethod.Range {
    const selection = this.getSelection();
    if (selection !== null) {
      return {
        start: this.textPositionToOffset(selection.start),
        end: this.textPositionToOffset(selection.end)
      };
    }
    const cursor = this.getCursorPosition();
    const offset = this.textPositionToOffset(cursor);
    return { start: offset, end: offset };
  }

  private buildImeCursorInfo(): inputMethod.CursorInfo {
    const rect = this.getCursorRect();
    return {
      left: this.editorGlobalX + rect.x,
      top: this.editorGlobalY + rect.y,
      width: 1,
      height: rect.height
    };
  }

  private getPreviewInputController(): PreviewCapableInputController {
    return this.inputController as PreviewCapableInputController;
  }

  private textPositionToOffset(position: TextPosition): number {
    if (!this.editorCore) {
      return 0;
    }
    const document: Document | null = this.editorCore.getDocument();
    if (document === null) {
      return 0;
    }
    let offset = 0;
    const lineCount: number = document.getLineCount();
    const targetLine = Math.max(0, Math.min(position.line, Math.max(0, lineCount - 1)));
    for (let line = 0; line < targetLine; line++) {
      offset += document.getLineText(line).length + 1;
    }
    const lineText = document.getLineText(targetLine);
    return offset + Math.max(0, Math.min(position.column, lineText.length));
  }

  private offsetToTextPosition(offset: number): TextPosition {
    if (!this.editorCore) {
      return { line: 0, column: 0 };
    }
    const document: Document | null = this.editorCore.getDocument();
    if (document === null) {
      return { line: 0, column: 0 };
    }
    let remaining = Math.max(0, offset);
    const lineCount: number = document.getLineCount();
    for (let line = 0; line < lineCount; line++) {
      const lineText = document.getLineText(line);
      if (remaining <= lineText.length) {
        return { line, column: remaining };
      }
      remaining -= lineText.length;
      if (line < lineCount - 1) {
        if (remaining === 0) {
          return { line: line + 1, column: 0 };
        }
        remaining -= 1;
      }
    }
    const lastLine = Math.max(0, lineCount - 1);
    return { line: lastLine, column: document.getLineText(lastLine).length };
  }

  private deleteLeftByLength(length: number): void {
    if (!this.editorCore || length <= 0) {
      return;
    }
    if (this.hasSelection()) {
      this.insertText('');
      return;
    }
    for (let i = 0; i < length; i++) {
      const result = this.editorCore.backspace();
      this.dispatchTextChanged(TextChangeAction.KEY, result);
    }
    this.resetCursorBlink();
    this.flush();
  }

  private deleteRightByLength(length: number): void {
    if (!this.editorCore || length <= 0) {
      return;
    }
    if (this.hasSelection()) {
      this.insertText('');
      return;
    }
    for (let i = 0; i < length; i++) {
      const result = this.editorCore.deleteForward();
      this.dispatchTextChanged(TextChangeAction.KEY, result);
    }
    this.resetCursorBlink();
    this.flush();
  }

  private moveCursorByIme(direction: inputMethod.Direction, extendSelection: boolean): void {
    if (!this.editorCore) {
      return;
    }
    switch (direction) {
      case inputMethod.Direction.CURSOR_LEFT:
        this.editorCore.moveCursorLeft(extendSelection);
        break;
      case inputMethod.Direction.CURSOR_RIGHT:
        this.editorCore.moveCursorRight(extendSelection);
        break;
      case inputMethod.Direction.CURSOR_UP:
        this.editorCore.moveCursorUp(extendSelection);
        break;
      case inputMethod.Direction.CURSOR_DOWN:
        this.editorCore.moveCursorDown(extendSelection);
        break;
      default:
        return;
    }
    this.resetCursorBlink();
    this.flush();
  }

  private selectRangeByIme(range: inputMethod.Range): void {
    const normalizedStart = Math.max(0, Math.min(range.start, range.end));
    const normalizedEnd = Math.max(normalizedStart, Math.max(range.start, range.end));
    const start = this.offsetToTextPosition(normalizedStart);
    const end = this.offsetToTextPosition(normalizedEnd);
    this.setSelection({ start, end });
  }

  private handleImePreviewText(text: string, range: inputMethod.Range): void {
    if (!this.editorCore) {
      return;
    }
    this.selectRangeByIme(range);
    this.compositionUpdate(text);
  }

  private finishImePreviewText(): void {
    if (!this.editorCore || !this.editorCore.isComposing()) {
      return;
    }
    this.editorCore.compositionCancel();
    this.resetCursorBlink();
    this.flush();
  }

  private handleImeEnterKey(): void {
    if (!this.editorCore) {
      return;
    }
    if (this.tryHandleNewLineAction()) {
      return;
    }
    const result = this.editorCore.handleKeyEvent(13, null, 0);
    this.dispatchKeyEventResult(result);
    this.resetCursorBlink();
    this.flush();
  }

  private handleImeExtendAction(action: inputMethod.ExtendAction): void {
    switch (action) {
      case inputMethod.ExtendAction.SELECT_ALL:
        this.selectAll();
        break;
      case inputMethod.ExtendAction.CUT:
        this.cutToClipboard();
        break;
      case inputMethod.ExtendAction.COPY:
        this.copyToClipboard();
        break;
      case inputMethod.ExtendAction.PASTE:
        this.pasteFromClipboard();
        break;
      default:
        break;
    }
  }

  private lengthToNumber(value?: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number.parseFloat(value);
      return Number.isFinite(parsed) ? parsed : 0;
    }
    return 0;
  }

  private tryHandleNewLineAction(): boolean {
    if (!this.editorCore || !this.newLineActionProviderManager) {
      return false;
    }
    const document: Document | null = this.editorCore.getDocument();
    if (document === null) {
      return false;
    }
    const cursor = this.getCursorPosition();
    const lineText = document.getLineText(cursor.line);
    const action = this.newLineActionProviderManager.provideNewLineAction(
      cursor.line, cursor.column, lineText,
      this.languageConfiguration, this.metadata
    );
    if (action === null) {
      return false;
    }

    const editResult = this.editorCore.insertText(action.text);
    this.dispatchTextChanged(TextChangeAction.KEY, editResult);
    this.resetCursorBlink();
    this.flush();
    return true;
  }

  private showSoftKeyboard(): void {
    this.pendingShowKeyboard = true;
    setTimeout(() => {
      if (this.pendingShowKeyboard) {
        this.ensureInputMethodAttached(true);
      }
    }, 0);
  }
}

function colorToHex(argb: number): string {
  const r = (argb >>> 16) & 0xFF;
  const g = (argb >>> 8) & 0xFF;
  const b = argb & 0xFF;
  return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
}
