import {
  Document,
  EditorCore,
  EditorOptions,
  EventType,
  GestureEvent,
  GestureResult,
  GestureType,
  HitTargetType,
  ImeActionResult,
  ImeInputContext,
  ImeInputContextKind,
  ImeScriptClass,
  ImeSyncSnapshot,
  ImeTextUnit,
  ScrollbarConfig,
  ScrollbarMode,
  ScrollbarTrackTapMode,
  KeyEventResult,
  Modifier,
  TextChange,
  TextEditResult
} from './core/EditorCore';
import {
  AutoIndentMode,
  CurrentLineRenderMode,
  FoldArrowMode,
  IntRange,
  ScrollBehavior,
  TextPosition,
  TextRange,
  WrapMode
} from './core/CoreFoundation';
import {
  EditorCommand,
  KeyBinding,
  KeyChord,
  KeyCode,
  KeyModifier
} from './core/CoreKeymap';
import { CursorRect, EditorRenderModel, PointF, ScrollMetrics } from './core/CoreVisual';
import {
  BracketGuide,
  Diagnostic,
  FlowGuide,
  FoldRegion,
  CodeLensItem,
  GutterIcon,
  IndentGuide,
  InlayHint,
  InlayType,
  LinkSpan,
  PhantomText,
  SeparatorGuide,
  TextStyle,
  SpanLayer,
  StyleSpan
} from './core/CoreAdornments';
import { LinkedEditingModel } from './core/CoreLinkedEditing';
import { EditorIconProvider, EditorMetadata, EditorTheme, LanguageConfiguration } from './EditorTypes';
import { EditorKeyMap } from './EditorKeymap';
import {
  extractPrintableKeyText,
  getNativeModifiers,
  OverlayKeyAction,
  resolveNativeKeyCode,
  resolveOverlayKeyAction
} from './EditorKeyboard';
import { EditorSettings } from './EditorSettings';
import { SweetEditorController } from './SweetEditorController';
import { EditorRenderer } from './EditorRenderer';
import { EditorEventBus } from './event/EditorEventBus';
import {
  ContextMenuEvent,
  CodeLensClickEvent,
  LinkClickEvent,
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
  TextChangeAction,
  TextChangedEvent
} from './event/EditorEvent';
import { CompletionProviderManager } from './completion/CompletionProviderManager';
import { CompletionPopupController, PopupPosition } from './completion/CompletionPopupController';
import { CompletionPopupView } from './completion/CompletionPopupView';
import {
  COMPLETION_ITEM_HEIGHT,
  COMPLETION_POPUP_MIN_WIDTH,
  COMPLETION_POPUP_SIDE_MARGIN,
  COMPLETION_POPUP_TOP_MARGIN,
  COMPLETION_POPUP_WIDTH
} from './completion/CompletionPopupLayout';
import {
  CompletionItem,
  CompletionItemViewBuilder,
  CompletionProvider,
  CompletionTriggerKind
} from './completion/CompletionTypes';
import { InlineSuggestionController } from './copilot/InlineSuggestionController';
import {
  InlineSuggestionBarView,
  INLINE_SUGGESTION_BAR_ESTIMATED_WIDTH,
  INLINE_SUGGESTION_BAR_GAP,
  INLINE_SUGGESTION_BAR_HEIGHT,
  INLINE_SUGGESTION_BAR_SIDE_MARGIN
} from './copilot/InlineSuggestionBarView';
import { InlineSuggestion, InlineSuggestionListener } from './copilot/InlineSuggestionTypes';
import { DecorationProviderManager } from './decoration/DecorationProviderManager';
import { DecorationProvider } from './decoration/DecorationTypes';
import { NewLineActionProvider } from './newline/NewLineTypes';
import { NewLineActionProviderManager } from './newline/NewLineActionProviderManager';
import { SelectionMenuController } from './selection/SelectionMenuController';
import { SelectionMenuItem, SelectionMenuItemProvider, SelectionMenuState } from './selection/SelectionMenuTypes';
import {
  getSelectionMenuPanelHeight,
  getSelectionMenuPanelWidth,
  SelectionMenuView,
  SELECTION_MENU_SIDE_MARGIN,
  SELECTION_MENU_TOP_MARGIN
} from './selection/SelectionMenuView';
import { argbToCssColor } from './ui/EditorColor';
import {
  computePopupPosition,
  insetPopupRect,
  popupPlacement,
  popupRect,
  PopupAlign,
  PopupPlacement,
  PopupRect,
  PopupSide
} from './ui/PopupPositioner';
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
const MAX_IME_TEXT_LENGTH = 32768;
const EDITOR_FOCUS_ID = 'sweeteditor-canvas';
const SELECTION_MENU_GAP = 8;
const SELECTION_MENU_HANDLE_CLEARANCE = 32;
const COMPLETION_POPUP_PLACEMENTS: PopupPlacement[] = [
  popupPlacement(PopupSide.BELOW, PopupAlign.START),
  popupPlacement(PopupSide.ABOVE, PopupAlign.START)
];
const INLINE_SUGGESTION_BAR_PLACEMENTS: PopupPlacement[] = [
  popupPlacement(PopupSide.ABOVE, PopupAlign.START),
  popupPlacement(PopupSide.BELOW, PopupAlign.START)
];
const SELECTION_MENU_PLACEMENTS: PopupPlacement[] = [
  popupPlacement(PopupSide.ABOVE, PopupAlign.CENTER),
  popupPlacement(PopupSide.BELOW, PopupAlign.CENTER)
];

interface PreviewCapableInputController {
  on(type: 'setPreviewText', callback: (text: string, range: inputMethod.Range) => void): void;

  on(type: 'finishTextPreview', callback: () => void): void;

  off(type: 'setPreviewText', callback?: (text: string, range: inputMethod.Range) => void): void;

  off(type: 'finishTextPreview', callback?: () => void): void;
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
  controller: SweetEditorController = new SweetEditorController();
  private editorCore: EditorCore | null = null;
  private renderer: EditorRenderer | null = null;
  private settings: EditorSettings = new EditorSettings(this);
  private theme: EditorTheme = EditorTheme.dark();
  private keyMap: EditorKeyMap = EditorKeyMap.defaultKeyMap();
  private eventBus: EditorEventBus = new EditorEventBus();
  private document: Document | null = null;
  private languageConfiguration: LanguageConfiguration | null = null;
  private metadata: EditorMetadata | null = null;
  private iconProvider: EditorIconProvider | null = null;
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
  private completionItemViewBuilder: CompletionItemViewBuilder | null = null;
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
  private readonly onImeInsertText = (text: string): void => this.commitImeComposition(text);
  private readonly onImeDeleteLeft = (length: number): void => this.deleteLeftByLength(length);
  private readonly onImeDeleteRight = (length: number): void => this.deleteRightByLength(length);
  private readonly onImeMoveCursor = (direction: inputMethod.Direction): void => this.moveCursorByIme(direction, false);
  private readonly onImeSelectByMovement = (movement: inputMethod.Movement): void => this.moveCursorByIme(movement.direction, true);
  private readonly onImeSelectByRange = (range: inputMethod.Range): void => this.selectRangeByIme(range);
  private readonly onImeFunctionKey = (functionKey: inputMethod.FunctionKey): void => this.handleImeFunctionKey(functionKey);
  private readonly onImeExtendAction = (action: inputMethod.ExtendAction): void => this.handleImeExtendAction(action);
  private readonly onImeKeyboardStatus = (status: inputMethod.KeyboardStatus): void => {
    if (status === inputMethod.KeyboardStatus.HIDE) {
      this.imeAttached = false;
    }
  };
  private readonly onImeSetPreviewText = (text: string, range: inputMethod.Range): void => this.handleImePreviewText(text, range);
  private readonly onImeFinishTextPreview = (): void => this.finishImePreviewText();
  private readonly onImeGetLeftTextOfCursor = (length: number): string => this.getImeTextBeforeCursor(length);
  private readonly onImeGetRightTextOfCursor = (length: number): string => this.getImeTextAfterCursor(length);
  private readonly onImeGetTextIndexAtCursor = (): number => this.getImeTextIndexAtCursor();
  @State private canvasWidth: number = 0;
  @State private canvasHeight: number = 0;
  @State private completionPopupVisible: boolean = false;
  @State private completionPopupItems: CompletionItem[] = [];
  @State private completionPopupSelectedIndex: number = 0;
  @State private completionPopupLeft: number = 0;
  @State private completionPopupTop: number = 0;
  @State private completionPopupWidth: number = COMPLETION_POPUP_WIDTH;
  @State private inlineSuggestionBarVisible: boolean = false;
  @State private inlineSuggestionBarLeft: number = 0;
  @State private inlineSuggestionBarTop: number = 0;
  @State private selectionMenuVisible: boolean = false;
  @State private selectionMenuItems: SelectionMenuItem[] = [];
  @State private selectionMenuLeft: number = 0;
  @State private selectionMenuTop: number = 0;

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
    this.controller.unbind(this);
    if (this.selectionMenuController) {
      this.selectionMenuController.dismiss();
    }
    if (this.completionPopupController) {
      this.completionPopupController.dismiss();
    }
    if (this.inlineSuggestionController) {
      this.inlineSuggestionController.dismiss();
    }
    if (this.completionProviderManager) {
      this.completionProviderManager.teardown();
      this.completionProviderManager = null;
    }
    if (this.decorationProviderManager) {
      this.decorationProviderManager.teardown();
      this.decorationProviderManager = null;
    }
    if (this.newLineActionProviderManager) {
      this.newLineActionProviderManager.teardown();
      this.newLineActionProviderManager = null;
    }
    this.completionPopupController = null;
    this.inlineSuggestionController = null;
    this.selectionMenuController = null;
    if (this.editorCore) {
      this.editorCore.destroy();
      this.editorCore = null;
    }
    this.renderer = null;
    this.cachedModel = null;
    this.modelDirty = true;
    this.initialized = false;
    this.editorFocused = false;
    this.pendingShowKeyboard = false;
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.canvasContext = new CanvasRenderingContext2D(this.canvasSettings))
        .id(EDITOR_FOCUS_ID)
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
        .onMouse((event: MouseEvent) => {
          this.handleMouseEvent(event);
        })
        .onHover((isHover: boolean, event: HoverEvent) => {
          this.handleHoverEvent(isHover, event);
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

      if (this.selectionMenuVisible && this.selectionMenuItems.length > 0) {
        SelectionMenuView({
          items: this.selectionMenuItems,
          left: this.selectionMenuLeft,
          top: this.selectionMenuTop,
          bgColor: this.theme.selectionMenuBgColor,
          menuBorderColor: this.theme.selectionMenuBorderColor,
          dividerColor: this.theme.selectionMenuDividerColor,
          textColor: this.theme.selectionMenuTextColor,
          onItemClick: (item: SelectionMenuItem): void => {
            if (!this.selectionMenuController) {
              return;
            }
            this.selectionMenuController.onMenuItemClicked(item);
          }
        })
      }

      if (this.inlineSuggestionBarVisible) {
        InlineSuggestionBarView({
          left: this.inlineSuggestionBarLeft,
          top: this.inlineSuggestionBarTop,
          bgColor: this.theme.inlineSuggestionBarBgColor,
          acceptColor: this.theme.inlineSuggestionBarAcceptColor,
          dismissColor: this.theme.inlineSuggestionBarDismissColor,
          onAccept: (): void => {
            if (this.inlineSuggestionController) {
              this.inlineSuggestionController.onAcceptClicked();
            }
          },
          onDismiss: (): void => {
            if (this.inlineSuggestionController) {
              this.inlineSuggestionController.onDismissClicked();
            }
          }
        })
      }

      if (this.completionPopupVisible && this.completionPopupItems.length > 0) {
        if (this.completionItemViewBuilder !== null) {
          CompletionPopupView({
            items: this.completionPopupItems,
            selectedIndex: this.completionPopupSelectedIndex,
            left: this.completionPopupLeft,
            top: this.completionPopupTop,
            panelWidth: this.completionPopupWidth,
            hasCustomItemViewBuilder: true,
            theme: this.theme,
            itemViewBuilder: this.completionItemViewBuilder,
            onConfirmItem: (index: number): void => {
              if (!this.completionPopupController) {
                return;
              }
              this.completionPopupController.confirmItem(index);
            }
          })
        } else {
          CompletionPopupView({
            items: this.completionPopupItems,
            selectedIndex: this.completionPopupSelectedIndex,
            left: this.completionPopupLeft,
            top: this.completionPopupTop,
            panelWidth: this.completionPopupWidth,
            hasCustomItemViewBuilder: false,
            theme: this.theme,
            onConfirmItem: (index: number): void => {
              if (!this.completionPopupController) {
                return;
              }
              this.completionPopupController.confirmItem(index);
            }
          })
        }
      }
    }
    .width('100%')
    .height('100%')
  }

  private applyCompletionPopupState(items: CompletionItem[], selectedIndex: number, position: PopupPosition): void {
    if (items.length === 0) {
      this.dismissCompletionPopupState();
      return;
    }

    const availableFrame = this.getOverlayAvailableFrame(COMPLETION_POPUP_SIDE_MARGIN, COMPLETION_POPUP_TOP_MARGIN);
    const frameWidth = Math.max(1, availableFrame.right - availableFrame.left);
    const frameHeight = Math.max(COMPLETION_ITEM_HEIGHT, availableFrame.bottom - availableFrame.top);
    let popupWidth = Math.min(position.popupWidth, Math.max(COMPLETION_POPUP_MIN_WIDTH, frameWidth));
    if (popupWidth > frameWidth) {
      popupWidth = frameWidth;
    }
    const popupHeight = Math.min(position.popupHeight, frameHeight);
    const placement = computePopupPosition({
      availableFrame: availableFrame,
      anchorRect: position.anchorRect,
      popupWidth: popupWidth,
      popupHeight: popupHeight,
      gap: position.gap,
      clearance: 0,
      preferredPlacements: COMPLETION_POPUP_PLACEMENTS
    });

    this.completionPopupWidth = popupWidth;
    this.completionPopupLeft = placement.x;
    this.completionPopupTop = placement.y;
    this.completionPopupItems = [...items];
    this.completionPopupSelectedIndex = Math.max(0, Math.min(items.length - 1, selectedIndex));
    this.completionPopupVisible = true;
  }

  private dismissCompletionPopupState(): void {
    this.completionPopupVisible = false;
    this.completionPopupItems = [];
    this.completionPopupSelectedIndex = 0;
  }

  private applyInlineSuggestionBarState(x: number, y: number, cursorHeight: number): void {
    const availableFrame = this.getOverlayAvailableFrame(
      INLINE_SUGGESTION_BAR_SIDE_MARGIN,
      INLINE_SUGGESTION_BAR_SIDE_MARGIN
    );
    const placement = computePopupPosition({
      availableFrame: availableFrame,
      anchorRect: popupRect(x, y, x, y + cursorHeight),
      popupWidth: INLINE_SUGGESTION_BAR_ESTIMATED_WIDTH,
      popupHeight: INLINE_SUGGESTION_BAR_HEIGHT,
      gap: INLINE_SUGGESTION_BAR_GAP,
      clearance: 0,
      preferredPlacements: INLINE_SUGGESTION_BAR_PLACEMENTS
    });
    this.inlineSuggestionBarLeft = placement.x;
    this.inlineSuggestionBarTop = placement.y;
    this.inlineSuggestionBarVisible = true;
  }

  private dismissInlineSuggestionBarState(): void {
    this.inlineSuggestionBarVisible = false;
  }

  private applySelectionMenuState(state: SelectionMenuState): void {
    if (!state.visible || state.items.length === 0) {
      this.selectionMenuVisible = false;
      this.selectionMenuItems = [];
      return;
    }

    const menuWidth = getSelectionMenuPanelWidth(state.items);
    const menuHeight = getSelectionMenuPanelHeight();
    const placement = computePopupPosition({
      availableFrame: this.getOverlayAvailableFrame(SELECTION_MENU_SIDE_MARGIN, SELECTION_MENU_TOP_MARGIN),
      anchorRect: state.anchorRect,
      popupWidth: menuWidth,
      popupHeight: menuHeight,
      gap: SELECTION_MENU_GAP,
      clearance: SELECTION_MENU_HANDLE_CLEARANCE,
      preferredPlacements: SELECTION_MENU_PLACEMENTS
    });

    this.selectionMenuLeft = placement.x;
    this.selectionMenuTop = placement.y;
    this.selectionMenuItems = [...state.items];
    this.selectionMenuVisible = true;
  }

  private initEditor(): void {
    if (this.initialized) {
      return;
    }
    this.initialized = true;

    this.renderer = new EditorRenderer(this.theme, this.density);
    this.renderer.setEditorIconProvider(this.iconProvider);

    const touchSlop = 10;
    const options = new EditorOptions();
    options.touchSlop = touchSlop;
    options.doubleTapTimeout = 300;
    options.revealSelectionEndOnSelectAll = true;

    const ctx = this.canvasContext!;
    this.renderer.attachCanvasContext(ctx);

    const scrollbarConfig = new ScrollbarConfig();
    scrollbarConfig.thickness = 8.0;
    scrollbarConfig.minThumb = 40.0;
    scrollbarConfig.thumbHitPadding = 20.0;
    scrollbarConfig.mode = ScrollbarMode.TRANSIENT;
    scrollbarConfig.thumbDraggable = true;
    scrollbarConfig.trackTapMode = ScrollbarTrackTapMode.DISABLED;
    scrollbarConfig.fadeDelayMs = 700;
    scrollbarConfig.fadeDurationMs = 300;
    this.renderer.setScrollbarConfig(scrollbarConfig);

    this.editorCore = new EditorCore(this.renderer.getMeasurer(), options);
    this.editorCore.setHandleConfig(this.renderer.getHandleConfig());
    this.editorCore.setScrollbarConfig(scrollbarConfig);
    this.editorCore.setKeyMap(this.keyMap);
    this.registerImeCallbacks();

    this.editorCore.registerBatchTextStyles(this.theme.textStyles);

    this.initSubsystems();
    this.bindController();

    this.startCursorBlink();
    this.flush();
  }

  private bindController(): void {
    this.controller.bind(this);
  }

  private initSubsystems(): void {
    // DecorationProviderManager
    this.decorationProviderManager = new DecorationProviderManager(this);

    // CompletionProviderManager + CompletionPopupController
    this.completionProviderManager = new CompletionProviderManager(this);
    this.completionPopupController = new CompletionPopupController();
    this.completionProviderManager.setListener(this.completionPopupController);
    this.completionPopupController.setConfirmHandler(
      (item: CompletionItem): void => this.applyCompletionItemInternal(item));
    this.completionPopupController.setOnShowCallback(
      (items: CompletionItem[], selectedIndex: number, position: PopupPosition): void => {
        this.applyCompletionPopupState(items, selectedIndex, position);
      });
    this.completionPopupController.setOnUpdateCallback(
      (items: CompletionItem[], selectedIndex: number, position: PopupPosition): void => {
        this.applyCompletionPopupState(items, selectedIndex, position);
      });
    this.completionPopupController.setOnDismissCallback((): void => {
      this.dismissCompletionPopupState();
    });

    // InlineSuggestionController
    this.inlineSuggestionController = new InlineSuggestionController(this, this.eventBus);
    this.inlineSuggestionController.setOnShowCallback((x: number, y: number, height: number): void => {
      this.applyInlineSuggestionBarState(x, y, height);
    });
    this.inlineSuggestionController.setOnUpdatePositionCallback((x: number, y: number, height: number): void => {
      this.applyInlineSuggestionBarState(x, y, height);
    });
    this.inlineSuggestionController.setOnDismissCallback((): void => {
      this.dismissInlineSuggestionBarState();
    });

    // SelectionMenuController
    this.selectionMenuController = new SelectionMenuController(this, this.controller, this.eventBus);
    this.selectionMenuController.setStateListener((state: SelectionMenuState): void => {
      this.applySelectionMenuState(state);
    });

    // NewLineActionProviderManager
    this.newLineActionProviderManager = new NewLineActionProviderManager();
  }

  loadDocument(document: Document): void {
    this.document = document;
      if (this.editorCore) {
        this.editorCore.loadDocument(document);
        this.eventBus.emit('documentLoaded', new DocumentLoadedEvent());
        if (this.decorationProviderManager) {
          this.decorationProviderManager.onDocumentLoaded();
        }
      this.flush();
    }
  }

  getDocument(): Document | null {
    return this.document;
  }

  getSettings(): EditorSettings {
    return this.settings;
  }

  getEditorCore(): EditorCore | null {
    return this.editorCore;
  }

  applySettingsTextSize(size: number): void {
    if (this.renderer) {
      this.renderer.applyTextSize(size);
    }
    if (this.editorCore) {
      this.editorCore.onFontMetricsChanged();
    }
    this.flush();
  }

  applySettingsFontFamily(fontFamily: string): void {
    if (this.renderer) {
      this.renderer.applyFontFamily(fontFamily);
    }
    if (this.editorCore) {
      this.editorCore.onFontMetricsChanged();
    }
    this.flush();
  }

  applySettingsScale(scale: number): void {
    if (this.editorCore) {
      this.editorCore.setScale(scale);
    }
    this.syncPlatformScale(scale);
    this.flush();
  }

  getTheme(): EditorTheme {
    return this.theme;
  }

  setKeyMap(keyMap: EditorKeyMap): void {
    this.keyMap = keyMap;
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setKeyMap(keyMap);
  }

  getKeyMap(): EditorKeyMap {
    return this.keyMap;
  }

  applyTheme(theme: EditorTheme): void {
    this.theme = theme;
    if (this.renderer) {
      this.renderer.applyTheme(theme);
    }
    if (this.editorCore) {
      this.editorCore.registerBatchTextStyles(theme.textStyles);
    }
    this.flush();
  }

  getVisibleLineRange(): IntRange {
    if (!this.editorCore) {
      return { start: 0, end: -1 };
    }
    if (!this.cachedModel) {
      this.editorCore.buildRenderModel();
    }
    return this.editorCore.getVisibleLineRange();
  }

  getTotalLineCount(): number {
    return this.document ? this.document.getLineCount() : -1;
  }

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

  async copyToClipboard(): Promise<void> {
    const selected = this.getSelectedText();
    if (selected && selected.length > 0) {
      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, selected);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        await systemPasteboard.setData(pasteData);
      } catch (e) {
        hilog.error(HILOG_DOMAIN, TAG, 'copyToClipboard failed %{public}s', JSON.stringify(e));
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
      hilog.error(HILOG_DOMAIN, TAG, 'pasteFromClipboard failed %{public}s', JSON.stringify(e));
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
        hilog.error(HILOG_DOMAIN, TAG, 'cutToClipboard failed %{public}s', JSON.stringify(e));
      }
    }
  }

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

  registerTextStyle(styleId: number, color: number, backgroundColorOrFontStyle: number, fontStyle?: number): void {
    if (this.editorCore) {
      this.editorCore.registerTextStyle(styleId, color, backgroundColorOrFontStyle, fontStyle);
    }
  }

  registerBatchTextStyles(stylesById: Map<number, TextStyle>): void {
    if (this.editorCore) {
      this.editorCore.registerBatchTextStyles(stylesById);
    }
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

  setLineCodeLens(line: number, items: CodeLensItem[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineCodeLens(line, items);
  }

  setBatchLineCodeLens(itemsByLine: Map<number, CodeLensItem[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLineCodeLens(itemsByLine);
  }

  setLineLinks(line: number, links: LinkSpan[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineLinks(line, links);
  }

  setBatchLineLinks(linksByLine: Map<number, LinkSpan[]>): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBatchLineLinks(linksByLine);
  }

  getLinkTargetAt(line: number, column: number): string {
    if (!this.editorCore) {
      return '';
    }
    return this.editorCore.getLinkTargetAt(line, column);
  }

  setLineDiagnostics(line: number, items: Diagnostic[]): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineDiagnostics(line, items);
  }

  setBatchLineDiagnostics(diagsByLine: Map<number, Diagnostic[]>): void {
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

  clearCodeLens(): void {
    if (this.editorCore) {
      this.editorCore.clearCodeLens();
    }
  }

  clearLinks(): void {
    if (this.editorCore) {
      this.editorCore.clearLinks();
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

  setLanguageConfiguration(config: LanguageConfiguration | null): void {
    this.languageConfiguration = config;
    if (!this.editorCore) {
      return;
    }

    const brackets = config?.brackets ?? [];
    const opens: number[] = [];
    const closes: number[] = [];
    for (const pair of brackets) {
      opens.push(pair.open.length > 0 ? pair.open.codePointAt(0)! : 0);
      closes.push(pair.close.length > 0 ? pair.close.codePointAt(0)! : 0);
    }
    this.editorCore.setBracketPairs(opens, closes);

    const autoClosingPairs = config?.autoClosingPairs ?? [];
    const acOpens: number[] = [];
    const acCloses: number[] = [];
    for (const pair of autoClosingPairs) {
      acOpens.push(pair.open.length > 0 ? pair.open.codePointAt(0)! : 0);
      acCloses.push(pair.close.length > 0 ? pair.close.codePointAt(0)! : 0);
    }
    this.editorCore.setAutoClosingPairs(acOpens, acCloses);

    const tabSize = config && config.tabSize > 0
      ? config.tabSize
      : LanguageConfiguration.DEFAULT_TAB_SIZE;
    this.editorCore.setTabSize(tabSize);
    this.editorCore.setInsertSpaces(config ? config.insertSpaces : false);
    this.flush();
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
    this.iconProvider = provider;
    if (this.renderer) {
      this.renderer.setEditorIconProvider(provider);
      this.flush();
    }
  }

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

  setCompletionItemViewBuilder(builder: CompletionItemViewBuilder | null): void {
    this.completionItemViewBuilder = builder;
    if (this.completionPopupVisible) {
      this.completionPopupItems = [...this.completionPopupItems];
    }
  }

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

  onTextChanged(listener: EditorEventListener<TextChangedEvent>): void {
    this.eventBus.on('textChanged', listener as EditorEventListener<EditorEvent>);
  }

  offTextChanged(listener: EditorEventListener<TextChangedEvent>): void {
    this.eventBus.off('textChanged', listener as EditorEventListener<EditorEvent>);
  }

  onCursorChanged(listener: EditorEventListener<CursorChangedEvent>): void {
    this.eventBus.on('cursorChanged', listener as EditorEventListener<EditorEvent>);
  }

  offCursorChanged(listener: EditorEventListener<CursorChangedEvent>): void {
    this.eventBus.off('cursorChanged', listener as EditorEventListener<EditorEvent>);
  }

  onSelectionChanged(listener: EditorEventListener<SelectionChangedEvent>): void {
    this.eventBus.on('selectionChanged', listener as EditorEventListener<EditorEvent>);
  }

  offSelectionChanged(listener: EditorEventListener<SelectionChangedEvent>): void {
    this.eventBus.off('selectionChanged', listener as EditorEventListener<EditorEvent>);
  }

  onScrollChanged(listener: EditorEventListener<ScrollChangedEvent>): void {
    this.eventBus.on('scrollChanged', listener as EditorEventListener<EditorEvent>);
  }

  offScrollChanged(listener: EditorEventListener<ScrollChangedEvent>): void {
    this.eventBus.off('scrollChanged', listener as EditorEventListener<EditorEvent>);
  }

  onScaleChanged(listener: EditorEventListener<ScaleChangedEvent>): void {
    this.eventBus.on('scaleChanged', listener as EditorEventListener<EditorEvent>);
  }

  offScaleChanged(listener: EditorEventListener<ScaleChangedEvent>): void {
    this.eventBus.off('scaleChanged', listener as EditorEventListener<EditorEvent>);
  }

  onLongPress(listener: EditorEventListener<LongPressEvent>): void {
    this.eventBus.on('longPress', listener as EditorEventListener<EditorEvent>);
  }

  offLongPress(listener: EditorEventListener<LongPressEvent>): void {
    this.eventBus.off('longPress', listener as EditorEventListener<EditorEvent>);
  }

  onDoubleTap(listener: EditorEventListener<DoubleTapEvent>): void {
    this.eventBus.on('doubleTap', listener as EditorEventListener<EditorEvent>);
  }

  offDoubleTap(listener: EditorEventListener<DoubleTapEvent>): void {
    this.eventBus.off('doubleTap', listener as EditorEventListener<EditorEvent>);
  }

  onContextMenu(listener: EditorEventListener<ContextMenuEvent>): void {
    this.eventBus.on('contextMenu', listener as EditorEventListener<EditorEvent>);
  }

  offContextMenu(listener: EditorEventListener<ContextMenuEvent>): void {
    this.eventBus.off('contextMenu', listener as EditorEventListener<EditorEvent>);
  }

  onGutterIconClick(listener: EditorEventListener<GutterIconClickEvent>): void {
    this.eventBus.on('gutterIconClick', listener as EditorEventListener<EditorEvent>);
  }

  offGutterIconClick(listener: EditorEventListener<GutterIconClickEvent>): void {
    this.eventBus.off('gutterIconClick', listener as EditorEventListener<EditorEvent>);
  }

  onInlayHintClick(listener: EditorEventListener<InlayHintClickEvent>): void {
    this.eventBus.on('inlayHintClick', listener as EditorEventListener<EditorEvent>);
  }

  offInlayHintClick(listener: EditorEventListener<InlayHintClickEvent>): void {
    this.eventBus.off('inlayHintClick', listener as EditorEventListener<EditorEvent>);
  }

  onFoldToggle(listener: EditorEventListener<FoldToggleEvent>): void {
    this.eventBus.on('foldToggle', listener as EditorEventListener<EditorEvent>);
  }

  offFoldToggle(listener: EditorEventListener<FoldToggleEvent>): void {
    this.eventBus.off('foldToggle', listener as EditorEventListener<EditorEvent>);
  }

  onCodeLensClick(listener: EditorEventListener<CodeLensClickEvent>): void {
    this.eventBus.on('codeLensClick', listener as EditorEventListener<EditorEvent>);
  }

  offCodeLensClick(listener: EditorEventListener<CodeLensClickEvent>): void {
    this.eventBus.off('codeLensClick', listener as EditorEventListener<EditorEvent>);
  }

  onLinkClick(listener: EditorEventListener<LinkClickEvent>): void {
    this.eventBus.on('linkClick', listener as EditorEventListener<EditorEvent>);
  }

  offLinkClick(listener: EditorEventListener<LinkClickEvent>): void {
    this.eventBus.off('linkClick', listener as EditorEventListener<EditorEvent>);
  }

  onDocumentLoaded(listener: EditorEventListener<DocumentLoadedEvent>): void {
    this.eventBus.on('documentLoaded', listener as EditorEventListener<EditorEvent>);
  }

  offDocumentLoaded(listener: EditorEventListener<DocumentLoadedEvent>): void {
    this.eventBus.off('documentLoaded', listener as EditorEventListener<EditorEvent>);
  }

  onSelectionMenuItemClick(listener: EditorEventListener<SelectionMenuItemClickEvent>): void {
    this.eventBus.on('selectionMenuItemClick', listener as EditorEventListener<EditorEvent>);
  }

  offSelectionMenuItemClick(listener: EditorEventListener<SelectionMenuItemClickEvent>): void {
    this.eventBus.off('selectionMenuItemClick', listener as EditorEventListener<EditorEvent>);
  }

  setPerfOverlayEnabled(enabled: boolean): void {
    if (this.renderer) {
      this.renderer.getPerfOverlay().setEnabled(enabled);
    }
  }

  isPerfOverlayEnabled(): boolean {
    return this.renderer ? this.renderer.getPerfOverlay().isEnabled() : false;
  }

  updateImeComposition(text: string): void {
    if (!this.editorCore) {
      return;
    }
    const result = this.editorCore.setImeComposingText(text, 1, ImeScriptClass.UNKNOWN);
    this.finishImeAction(result);
  }

  commitImeComposition(text: string): void {
    if (!this.editorCore) {
      return;
    }
    const result = this.editorCore.commitImeText(text, ImeScriptClass.UNKNOWN);
    this.finishImeAction(result);
  }

  private handleKeyEvent(event: KeyEvent, allowTextFallback: boolean): void {
    if (!this.editorCore) {
      return;
    }

    const modifiers = getNativeModifiers(event);

    // Inline suggestion interception (Tab/Escape)
    if (this.inlineSuggestionController && this.inlineSuggestionController.isShowing()) {
      const overlayAction = resolveOverlayKeyAction(event);
      if (overlayAction !== OverlayKeyAction.NONE && this.inlineSuggestionController.handleKeyAction(overlayAction)) {
        return;
      }
    }

    // Completion panel interception (Enter/Escape/Up/Down)
    if (this.completionPopupController && this.completionPopupController.isShowing()) {
      const overlayAction = resolveOverlayKeyAction(event);
      if (overlayAction !== OverlayKeyAction.NONE && this.completionPopupController.handleKeyAction(overlayAction)) {
        return;
      }
    }

    const nativeKeyCode = resolveNativeKeyCode(event, modifiers);
    if (nativeKeyCode !== KeyCode.NONE) {
      if (nativeKeyCode === KeyCode.ENTER && this.tryHandleNewLineAction()) {
        return;
      }

      const result = this.editorCore.handleKeyEvent(nativeKeyCode, null, modifiers);
      if (result.handled && this.dispatchKeyMapCommand(result.command, nativeKeyCode as KeyCode, modifiers)) {
        this.resetCursorBlink();
        this.flush();
        return;
      }
      this.dispatchKeyEventResult(result);
      this.resetCursorBlink();
      this.flush();
      return;
    }

    if (!allowTextFallback || (modifiers & ~KeyModifier.SHIFT) !== KeyModifier.NONE) {
      return;
    }

    const text = extractPrintableKeyText(event);
    if (text === null) {
      return;
    }

    const result = this.editorCore.handleKeyEvent(KeyCode.NONE, text, modifiers);
    this.dispatchKeyEventResult(result);
    this.resetCursorBlink();
    this.flush();
  }

  private dispatchKeyMapCommand(command: number, keyCode: KeyCode, modifiers: number): boolean {
    if (command === EditorCommand.NONE) {
      return false;
    }
    const handler = this.keyMap.getCommand(command);
    if (handler) {
      const binding = new KeyBinding(
        new KeyChord(modifiers, keyCode as KeyCode),
        new KeyChord(),
        command
      );
      return handler(binding, this);
    }
    return false;
  }

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

  private handleTouchEvent(event: TouchEvent): void {
    if (!this.editorCore) {
      return;
    }

    const gestureEvent = this.convertTouchToGestureEvent(event);
    const locationInEditor: PointF = event.touches.length > 0
      ? { x: event.touches[0].x, y: event.touches[0].y }
      : { x: 0, y: 0 };
    const isPointerReleased = event.type === TouchType.Up || event.type === TouchType.Cancel;

    this.dispatchPointerGestureEvent(gestureEvent, locationInEditor, isPointerReleased, true);
  }

  private handleMouseEvent(event: MouseEvent): void {
    const gestureEvent = this.convertMouseToGestureEvent(event);
    if (!gestureEvent) {
      return;
    }

    const locationInEditor: PointF = { x: event.x, y: event.y };
    const isPointerReleased = gestureEvent.type === EventType.MOUSE_UP;
    this.dispatchPointerGestureEvent(gestureEvent, locationInEditor, isPointerReleased, false);
  }

  private handleHoverEvent(isHover: boolean, event: HoverEvent): void {
    if (!isHover) {
      this.dispatchPointerGestureEvent({
        type: EventType.MOUSE_MOVE,
        points: [{ x: -1, y: -1 }],
        modifiers: Modifier.NONE,
        wheelDeltaX: 0,
        wheelDeltaY: 0,
        directScale: 0
      }, { x: -1, y: -1 }, false, false);
      return;
    }

    if (typeof event.x === 'number' && typeof event.y === 'number') {
      this.dispatchPointerGestureEvent({
        type: EventType.MOUSE_MOVE,
        points: [{ x: event.x, y: event.y }],
        modifiers: Modifier.NONE,
        wheelDeltaX: 0,
        wheelDeltaY: 0,
        directScale: 0
      }, { x: event.x, y: event.y }, false, false);
    }
  }

  private dispatchPointerGestureEvent(
    gestureEvent: GestureEvent,
    locationInEditor: PointF,
    isPointerReleased: boolean,
    showSoftKeyboardOnEmptyTap: boolean
  ): void {
    if (!this.editorCore) {
      return;
    }

    const result = this.editorCore.handleGestureEvent(gestureEvent);
    this.fireGestureEvents(result, locationInEditor);

    if (this.selectionMenuController) {
      this.selectionMenuController.onGestureResult(result, isPointerReleased);
    }

    if (result.type === GestureType.TAP) {
      if (showSoftKeyboardOnEmptyTap && result.hitTarget.type === HitTargetType.NONE) {
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

  private convertMouseToGestureEvent(event: MouseEvent): GestureEvent | null {
    let eventType: EventType | null = null;
    switch (event.action) {
      case MouseAction.Press:
        if (event.button === MouseButton.Left) {
          eventType = EventType.MOUSE_DOWN;
        } else if (event.button === MouseButton.Right) {
          eventType = EventType.MOUSE_RIGHT_DOWN;
        }
        break;
      case MouseAction.Move:
      case MouseAction.Hover:
        eventType = EventType.MOUSE_MOVE;
        break;
      case MouseAction.Release:
        if (event.button === MouseButton.Left) {
          eventType = EventType.MOUSE_UP;
        }
        break;
      default:
        break;
    }

    if (eventType === null) {
      return null;
    }

    return {
      type: eventType,
      points: [{ x: event.x, y: event.y }],
      modifiers: Modifier.NONE,
      wheelDeltaX: 0,
      wheelDeltaY: 0,
      directScale: 0
    };
  }

  private fireGestureEvents(result: GestureResult, locationInEditor: PointF): void {
    switch (result.type) {
      case GestureType.LONG_PRESS:
        this.eventBus.emit('longPress', new LongPressEvent(result.cursorPosition, locationInEditor));
        this.eventBus.emit('cursorChanged', new CursorChangedEvent(result.cursorPosition));
        break;
      case GestureType.DOUBLE_TAP:
        this.eventBus.emit('doubleTap', new DoubleTapEvent(
          result.cursorPosition, result.hasSelection, result.selection, locationInEditor));
        this.eventBus.emit('cursorChanged', new CursorChangedEvent(result.cursorPosition));
        if (result.hasSelection) {
          this.eventBus.emit('selectionChanged', new SelectionChangedEvent(
            true, result.selection, result.cursorPosition));
        }
        break;
      case GestureType.TAP:
        this.eventBus.emit('cursorChanged', new CursorChangedEvent(result.cursorPosition));
        if (this.completionPopupController && this.completionPopupController.isShowing() &&
          this.completionProviderManager) {
          this.completionProviderManager.dismiss();
        }
        if (result.hitTarget && result.hitTarget.type !== HitTargetType.NONE) {
          this.fireHitTargetEvent(result, locationInEditor);
        }
        break;
      case GestureType.SCROLL:
      case GestureType.FAST_SCROLL:
        this.handleScrollChanged(result);
        break;
      case GestureType.SCALE:
        this.eventBus.emit('scaleChanged', new ScaleChangedEvent(result.viewScale));
        break;
      case GestureType.DRAG_SELECT:
        if (this.didScrollSinceLastFrame(result)) {
          this.handleScrollChanged(result);
        }
        this.eventBus.emit('selectionChanged', new SelectionChangedEvent(
          result.hasSelection, result.selection, result.cursorPosition));
        break;
      case GestureType.CONTEXT_MENU:
        this.eventBus.emit('contextMenu', new ContextMenuEvent(result.cursorPosition, locationInEditor));
        break;
    }
  }

  private handleScrollChanged(result: GestureResult): void {
    this.eventBus.emit('scrollChanged', new ScrollChangedEvent(result.viewScrollX, result.viewScrollY));
    if (this.decorationProviderManager) {
      this.decorationProviderManager.onScrollChanged();
    }
    if (this.completionPopupController && this.completionPopupController.isShowing() &&
      this.completionProviderManager) {
      this.completionProviderManager.dismiss();
    }
  }

  private didScrollSinceLastFrame(result: GestureResult): boolean {
    if (!this.cachedModel) {
      return result.viewScrollX !== 0 || result.viewScrollY !== 0;
    }
    return this.cachedModel.scrollX !== result.viewScrollX ||
      this.cachedModel.scrollY !== result.viewScrollY;
  }

  private fireHitTargetEvent(result: GestureResult, locationInEditor: PointF): void {
    const ht = result.hitTarget;
    switch (ht.type) {
      case HitTargetType.INLAY_HINT_ICON:
        this.eventBus.emit('inlayHintClick', new InlayHintClickEvent(
          ht.line, ht.column, InlayType.Icon, ht.iconId, locationInEditor));
        break;
      case HitTargetType.INLAY_HINT_TEXT:
        this.eventBus.emit('inlayHintClick', new InlayHintClickEvent(
          ht.line, ht.column, InlayType.Text, 0, locationInEditor));
        break;
      case HitTargetType.INLAY_HINT_COLOR:
        this.eventBus.emit('inlayHintClick', new InlayHintClickEvent(
          ht.line, ht.column, InlayType.Color, ht.colorValue, locationInEditor));
        break;
      case HitTargetType.GUTTER_ICON:
        this.eventBus.emit('gutterIconClick', new GutterIconClickEvent(ht.line, ht.iconId, locationInEditor));
        break;
      case HitTargetType.FOLD_PLACEHOLDER:
      case HitTargetType.FOLD_GUTTER:
        this.eventBus.emit('foldToggle', new FoldToggleEvent(
          ht.line, ht.type === HitTargetType.FOLD_GUTTER, locationInEditor));
        break;
      case HitTargetType.CODELENS:
        this.eventBus.emit('codeLensClick', new CodeLensClickEvent(
          ht.line, ht.column, ht.iconId, locationInEditor));
        break;
      case HitTargetType.LINK:
        this.eventBus.emit('linkClick', new LinkClickEvent(
          ht.line, ht.column, this.getLinkTargetAt(ht.line, ht.column), locationInEditor));
        break;
    }
  }

  private dispatchTextChanged(action: TextChangeAction, editResult: TextEditResult): void {
    const textChanges: TextChange[] = [];
    if (editResult.changes && editResult.changes.length > 0) {
      for (const change of editResult.changes) {
        textChanges.push({ range: change.range, newText: change.newText });
      }
      this.eventBus.emit('textChanged', new TextChangedEvent(textChanges, action));
    }

    // Notify subsystems
    if (this.decorationProviderManager && textChanges.length > 0) {
      this.decorationProviderManager.onTextChanged(textChanges);
    }
    if (this.selectionMenuController) {
      this.selectionMenuController.onTextChanged();
    }

    this.maybeTriggerCompletionFromChanges(textChanges);
  }

  private dispatchKeyEventResult(result: KeyEventResult): void {
    if (result.contentChanged) {
      const textChanges: TextChange[] = [];
      if (this.selectionMenuController) {
        this.selectionMenuController.onTextChanged();
      }
      if (result.editResult && result.editResult.changes.length > 0) {
        for (const change of result.editResult.changes) {
          textChanges.push({ range: change.range, newText: change.newText });
        }
        this.eventBus.emit('textChanged', new TextChangedEvent(textChanges, TextChangeAction.KEY));
        if (this.decorationProviderManager) {
          this.decorationProviderManager.onTextChanged(textChanges);
        }
      }
      this.maybeTriggerCompletionFromChanges(textChanges);
    }
    if (result.cursorChanged && this.editorCore) {
      this.eventBus.emit('cursorChanged', new CursorChangedEvent(this.editorCore.getCursorPosition()));
    }
  }

  private dispatchImeActionResult(result: ImeActionResult): void {
    if (result.contentChanged) {
      this.dispatchTextChanged(TextChangeAction.COMPOSITION, result.editResult);
    }
    if (!this.editorCore) {
      return;
    }
    if (result.cursorChanged) {
      this.eventBus.emit('cursorChanged', new CursorChangedEvent(result.sync.cursor));
    }
    if (result.selectionChanged) {
      this.eventBus.emit('selectionChanged', new SelectionChangedEvent(
        result.sync.selection !== null, result.sync.selection, result.sync.cursor));
    }
    if (result.handled) {
      this.scheduleImeSync();
    }
  }

  private finishImeAction(result: ImeActionResult): void {
    this.dispatchImeActionResult(result);
    this.resetCursorBlink();
    this.flush();
  }

  private maybeTriggerCompletionFromChanges(textChanges: TextChange[]): void {
    if (!this.completionProviderManager || !this.editorCore || this.editorCore.isInLinkedEditing()) {
      return;
    }

    const popupShowing = this.completionPopupController !== null && this.completionPopupController.isShowing();

    if (textChanges.length === 0) {
      return;
    }

    const primaryChange = textChanges[0];
    const newText = primaryChange.newText;
    if (newText && newText.length === 1) {
      if (this.completionProviderManager.isTriggerCharacter(newText)) {
        this.completionProviderManager.triggerCompletion(CompletionTriggerKind.CHARACTER, newText);
      } else if (popupShowing) {
        this.completionProviderManager.triggerCompletion(CompletionTriggerKind.RETRIGGER, null);
      }
      return;
    }

    if (popupShowing) {
      this.completionProviderManager.triggerCompletion(CompletionTriggerKind.RETRIGGER, null);
    }
  }

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
      this.canvasContext.fillStyle = argbToCssColor(this.theme.backgroundColor);
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
    const config = this.renderer ? this.renderer.getScrollbarConfig() : null;
    if (config === null || config.mode !== ScrollbarMode.TRANSIENT) {
      this.clearTransientScrollbarTimer();
      return;
    }
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
        this.inputController.setCallingWindow(this.imeWindowId).catch(() => {});
      }
    }).catch(() => {});
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
      this.inputController.on('getLeftTextOfCursor', this.onImeGetLeftTextOfCursor);
      this.inputController.on('getRightTextOfCursor', this.onImeGetRightTextOfCursor);
      this.inputController.on('getTextIndexAtCursor', this.onImeGetTextIndexAtCursor);
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'registerImeCallbacks failed %{public}s', JSON.stringify(e));
    }
    try {
      const previewController = this.inputController as PreviewCapableInputController;
      previewController.on('setPreviewText', this.onImeSetPreviewText);
      previewController.on('finishTextPreview', this.onImeFinishTextPreview);
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'registerPreviewImeCallbacks failed %{public}s', JSON.stringify(e));
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
      this.inputController.off('getLeftTextOfCursor', this.onImeGetLeftTextOfCursor);
      this.inputController.off('getRightTextOfCursor', this.onImeGetRightTextOfCursor);
      this.inputController.off('getTextIndexAtCursor', this.onImeGetTextIndexAtCursor);
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'unregisterImeCallbacks failed %{public}s', JSON.stringify(e));
    }
    try {
      const previewController = this.inputController as PreviewCapableInputController;
      previewController.off('setPreviewText', this.onImeSetPreviewText);
      previewController.off('finishTextPreview', this.onImeFinishTextPreview);
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'unregisterPreviewImeCallbacks failed %{public}s', JSON.stringify(e));
    }
  }

  private ensureInputMethodAttached(showKeyboard: boolean): void {
    if (!this.editorCore) {
      return;
    }
    const snapshot = this.editorCore.getImeSyncSnapshot();
    const textConfig: inputMethod.TextConfig = {
      inputAttribute: {
        textInputType: inputMethod.TextInputType.MULTILINE,
        enterKeyType: inputMethod.EnterKeyType.NONE
      },
      cursorInfo: this.buildImeCursorInfo(snapshot),
      selection: this.getImeSelectionRange()
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
          this.inputController.setCallingWindow(this.imeWindowId).catch(() => {});
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
    this.inputController.hideTextInput().catch(() => {});
    this.detachInputMethod();
  }

  private detachInputMethod(): void {
    if (!this.imeAttached) {
      return;
    }
    this.inputController.detach().catch(() => {});
    this.imeAttached = false;
  }

  private scheduleImeSync(): void {
    if (!this.imeAttached || this.imeSyncScheduled || !this.editorCore) {
      return;
    }
    this.imeSyncScheduled = true;
    setTimeout(() => { this.imeSyncScheduled = false; this.syncInputMethodState(); }, 0);
  }

  private syncInputMethodState(): void {
    if (!this.imeAttached || !this.editorCore) {
      return;
    }
    const snapshot = this.editorCore.getImeSyncSnapshot();
    const context = this.editorCore.getImeInputContext(0, 0);
    const selection = this.getImeSelectionRange(context);
    const selectedText = context.selection.start === context.selection.end ? '' : context.text;
    const cursorInfo = this.buildImeCursorInfo(snapshot);
    this.inputController.changeSelection(selectedText, selection.start, selection.end).catch(() => {});
    this.inputController.updateCursor(cursorInfo).catch(() => {});
  }

  private buildImeCursorInfo(snapshot?: ImeSyncSnapshot): inputMethod.CursorInfo {
    const rect = snapshot !== undefined && this.editorCore !== null
      ? this.editorCore.getPositionRect(snapshot.cursor.line, snapshot.cursor.column)
      : this.getCursorRect();
    return {
      left: this.editorGlobalX + rect.x,
      top: this.editorGlobalY + rect.y,
      width: 1,
      height: rect.height
    };
  }

  private getImeSelectionRange(context?: ImeInputContext): inputMethod.Range {
    if (!this.editorCore) {
      return { start: 0, end: 0 };
    }
    const imeContext = context ?? this.editorCore.getImeInputContext(0, 0);
    const start = imeContext.documentStartOffset + Math.max(0, imeContext.selection.start);
    const end = imeContext.documentStartOffset + Math.max(0, imeContext.selection.end);
    return start <= end ? { start: start, end: end } : { start: end, end: start };
  }

  private getImeTextBeforeCursor(length: number): string {
    if (!this.editorCore) {
      return '';
    }
    const beforeLength = Math.max(0, Math.min(length, MAX_IME_TEXT_LENGTH));
    const context: ImeInputContext = this.editorCore.getImeInputContext(beforeLength, 0);
    if (context.kind !== ImeInputContextKind.DOCUMENT_WINDOW) {
      return '';
    }
    const end = Math.max(0, Math.min(context.selection.start, context.text.length));
    return context.text.substring(0, end);
  }

  private getImeTextAfterCursor(length: number): string {
    if (!this.editorCore) {
      return '';
    }
    const afterLength = Math.max(0, Math.min(length, MAX_IME_TEXT_LENGTH));
    const context: ImeInputContext = this.editorCore.getImeInputContext(0, afterLength);
    if (context.kind !== ImeInputContextKind.DOCUMENT_WINDOW) {
      return '';
    }
    const start = Math.max(0, Math.min(context.selection.end, context.text.length));
    return context.text.substring(start);
  }

  private getImeTextIndexAtCursor(): number {
    if (!this.editorCore) {
      return 0;
    }
    const context = this.editorCore.getImeInputContext(0, 0);
    return context.documentStartOffset + context.selection.start;
  }

  private deleteLeftByLength(length: number): void {
    if (!this.editorCore || length <= 0) {
      return;
    }
    const result = this.editorCore.deleteImeBackward(length, ImeTextUnit.GRAPHEME);
    this.finishImeAction(result);
  }

  private deleteRightByLength(length: number): void {
    if (!this.editorCore || length <= 0) {
      return;
    }
    const result = this.editorCore.deleteImeForward(length, ImeTextUnit.GRAPHEME);
    this.finishImeAction(result);
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
    const selection = this.editorCore.getSelection();
    const result = selection !== null
      ? this.editorCore.notifyImeSelectionChanged(selection)
      : this.editorCore.notifyImeCursorChanged(this.editorCore.getCursorPosition());
    this.finishImeAction(result);
  }

  private selectRangeByIme(range: inputMethod.Range): void {
    if (!this.editorCore) {
      return;
    }
    const normalizedStart = Math.max(0, Math.min(range.start, range.end));
    const normalizedEnd = Math.max(normalizedStart, Math.max(range.start, range.end));
    const result = this.editorCore.notifyImeDocumentSelectionChanged(normalizedStart, normalizedEnd);
    this.finishImeAction(result);
  }

  private handleImePreviewText(text: string, range: inputMethod.Range): void {
    if (!this.editorCore) {
      return;
    }
    const normalizedStart = Math.max(0, Math.min(range.start, range.end));
    const normalizedEnd = Math.max(normalizedStart, Math.max(range.start, range.end));
    this.dispatchImeActionResult(
      this.editorCore.markImeDocumentRangeByOffset(normalizedStart, normalizedEnd, ImeScriptClass.UNKNOWN)
    );
    this.dispatchImeActionResult(
      this.editorCore.setImeComposingText(text, 1, ImeScriptClass.UNKNOWN)
    );
    this.resetCursorBlink();
    this.flush();
  }

  private finishImePreviewText(): void {
    if (!this.editorCore || !this.editorCore.isComposing()) {
      return;
    }
    const result = this.editorCore.finishImePreedit();
    this.finishImeAction(result);
  }

  private handleImeFunctionKey(functionKey: inputMethod.FunctionKey): void {
    switch (functionKey.enterKeyType) {
      case inputMethod.EnterKeyType.NONE:
      case inputMethod.EnterKeyType.UNSPECIFIED:
      case inputMethod.EnterKeyType.NEWLINE:
        if (!this.editorCore || this.tryHandleNewLineAction()) {
          return;
        }
        this.dispatchKeyEventResult(this.editorCore.handleKeyEvent(KeyCode.ENTER, null, KeyModifier.NONE));
        this.resetCursorBlink();
        this.flush();
        break;
      default:
        this.scheduleImeSync();
        break;
    }
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

  private getOverlayAvailableFrame(horizontalMargin: number, verticalMargin: number): PopupRect {
    return insetPopupRect(popupRect(0, 0, this.viewWidth, this.viewHeight), horizontalMargin, verticalMargin);
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
