import {
  Document,
  EditorCore,
  EditorOptions,
  EventType,
  GestureEvent,
  GestureResult,
  GestureType,
  HitTargetType,
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
  DiagnosticItem,
  FlowGuide,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  InlayType,
  PhantomText,
  SeparatorGuide,
  TextStyle,
  SpanLayer,
  StyleSpan
} from './core/CoreAdornments';
import { LinkedEditingModel } from './core/CoreLinkedEditing';
import { EditorIconProvider, EditorMetadata, EditorTheme, LanguageConfiguration } from './EditorTypes';
import { EditorKeyMap } from './EditorKeymap';
import { EditorSettings } from './EditorSettings';
import { SweetEditorController } from './SweetEditorController';
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
  SelectionMenuItemClickEvent,
  SelectionChangedEvent,
  TextChangeAction,
  TextChangedEvent
} from './event/EditorEvent';
import { CompletionProviderManager } from './completion/CompletionProviderManager';
import { CompletionPopupController, PopupPosition } from './completion/CompletionPopupController';
import {
  CompletionItem,
  CompletionItemViewBuilder,
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
import { SelectionMenuItem, SelectionMenuItemProvider, SelectionMenuState } from './selection/SelectionMenuTypes';
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
const SELECTION_MENU_ITEM_HEIGHT = 26;
const SELECTION_MENU_ITEM_MIN_WIDTH = 40;
const SELECTION_MENU_HORIZONTAL_PADDING = 8;
const SELECTION_MENU_SIDE_MARGIN = 8;
const SELECTION_MENU_TOP_MARGIN = 8;
const COMPLETION_POPUP_SIDE_MARGIN = 8;
const COMPLETION_POPUP_TOP_MARGIN = 8;
const COMPLETION_ITEM_HEIGHT = 32;
const COMPLETION_KIND_BADGE_SIZE = 18;
const COMPLETION_KIND_BADGE_RADIUS = 4;
const COMPLETION_KIND_BADGE_GAP = 8;
const INLINE_SUGGESTION_BAR_HEIGHT = 28;
const INLINE_SUGGESTION_BAR_RADIUS = 6;
const INLINE_SUGGESTION_BAR_HORIZONTAL_PADDING = 4;
const INLINE_SUGGESTION_BAR_BUTTON_HORIZONTAL_PADDING = 10;
const INLINE_SUGGESTION_BAR_DIVIDER_WIDTH = 1;
const INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN = 6;
const INLINE_SUGGESTION_BAR_GAP = 2;
const INLINE_SUGGESTION_BAR_SIDE_MARGIN = 8;
const INLINE_SUGGESTION_BAR_ESTIMATED_WIDTH = 132;

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
  controller: SweetEditorController | null = null;
  private editorCore: EditorCore | null = null;
  private renderer: EditorRenderer | null = null;
  private settings: EditorSettings | null = null;
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
  private readonly onImeInsertText = (text: string): void => {
    if (this.editorCore && this.isCompositionEnabled() && this.editorCore.isComposing()) {
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
  @State private completionPopupVisible: boolean = false;
  @State private completionPopupItems: CompletionItem[] = [];
  @State private completionPopupSelectedIndex: number = 0;
  @State private completionPopupLeft: number = 0;
  @State private completionPopupTop: number = 0;
  @State private completionPopupWidth: number = 300;
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
    if (this.controller) {
      this.controller.unbind(this);
    }
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
    this.settings = null;
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

      if (this.selectionMenuVisible && this.selectionMenuItems.length > 0) {
        this.buildSelectionMenuOverlay()
      }

      if (this.inlineSuggestionBarVisible) {
        this.buildInlineSuggestionBarOverlay()
      }

      if (this.completionPopupVisible && this.completionPopupItems.length > 0) {
        this.buildCompletionPopupOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private buildSelectionMenuOverlay(): void {
    Row() {
      ForEach(this.selectionMenuItems, (item: SelectionMenuItem, index: number) => {
        this.buildSelectionMenuItem(item)
        if (index < this.selectionMenuItems.length - 1) {
          Blank()
            .width(1)
            .height(14)
            .backgroundColor(colorToHex(this.theme.selectionMenuDividerColor))
        }
      }, (item: SelectionMenuItem) => `${item.id}-${item.label}`)
    }
    .padding(4)
    .backgroundColor(colorToHex(this.theme.selectionMenuBgColor))
    .borderRadius(6)
    .border({
      width: 1,
      color: colorToHex(this.theme.selectionMenuBorderColor)
    })
    .position({
      x: this.selectionMenuLeft,
      y: this.selectionMenuTop
    })
    .zIndex(10)
  }

  @Builder
  private buildSelectionMenuItem(item: SelectionMenuItem): void {
    Text(item.label)
      .fontSize(11)
      .fontWeight('400')
      .fontColor(colorToHex(this.theme.selectionMenuTextColor))
      .textAlign(TextAlign.Center)
      .padding({ left: SELECTION_MENU_HORIZONTAL_PADDING, right: SELECTION_MENU_HORIZONTAL_PADDING })
      .width(this.getSelectionMenuItemWidth(item))
      .height(SELECTION_MENU_ITEM_HEIGHT)
      .opacity(item.enabled ? 1.0 : 0.45)
      .onClick(() => {
        if (!item.enabled || !this.selectionMenuController) {
          return;
        }
        this.selectionMenuController.onMenuItemClicked(item);
      })
  }

  @Builder
  private buildInlineSuggestionBarOverlay(): void {
    Row() {
      this.buildInlineSuggestionBarButton('Accept', true)

      Blank()
        .width(INLINE_SUGGESTION_BAR_DIVIDER_WIDTH)
        .height(INLINE_SUGGESTION_BAR_HEIGHT - INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN * 2)
        .backgroundColor(this.getInlineSuggestionOverlayColor())
        .margin({ top: INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN, bottom: INLINE_SUGGESTION_BAR_DIVIDER_VERTICAL_MARGIN })

      this.buildInlineSuggestionBarButton('Dismiss', false)
    }
    .height(INLINE_SUGGESTION_BAR_HEIGHT)
    .padding({ left: INLINE_SUGGESTION_BAR_HORIZONTAL_PADDING, right: INLINE_SUGGESTION_BAR_HORIZONTAL_PADDING })
    .backgroundColor(colorToHex(this.theme.inlineSuggestionBarBgColor))
    .borderRadius(INLINE_SUGGESTION_BAR_RADIUS)
    .shadow({
      radius: 8,
      color: '#22000000',
      offsetX: 0,
      offsetY: 2
    })
    .position({
      x: this.inlineSuggestionBarLeft,
      y: this.inlineSuggestionBarTop
    })
    .zIndex(8)
  }

  @Builder
  private buildInlineSuggestionBarButton(label: string, isAccept: boolean): void {
    Text(label)
      .fontSize(11)
      .fontWeight(isAccept ? '700' : '400')
      .fontColor(isAccept
        ? colorToHex(this.theme.inlineSuggestionBarAcceptColor)
        : colorToHex(this.theme.inlineSuggestionBarDismissColor))
      .height('100%')
      .textAlign(TextAlign.Center)
      .padding({ left: INLINE_SUGGESTION_BAR_BUTTON_HORIZONTAL_PADDING, right: INLINE_SUGGESTION_BAR_BUTTON_HORIZONTAL_PADDING })
      .onClick(() => {
        if (!this.inlineSuggestionController) {
          return;
        }
        if (isAccept) {
          this.inlineSuggestionController.onAcceptClicked();
        } else {
          this.inlineSuggestionController.onDismissClicked();
        }
      })
  }

  @Builder
  private buildCompletionPopupOverlay(): void {
    Column() {
      ForEach(this.completionPopupItems, (item: CompletionItem, index: number) => {
        this.buildCompletionPopupItem(item, index)
      }, (item: CompletionItem, index: number) => `${item.label}-${index}`)
    }
    .padding({ left: 4, right: 4, top: 6, bottom: 6 })
    .width(this.completionPopupWidth)
    .backgroundColor(colorToHex(this.theme.completionBgColor))
    .borderRadius(12)
    .border({
      width: 1,
      color: colorToHex(this.theme.completionBorderColor)
    })
    .shadow({
      radius: 16,
      color: '#32000000',
      offsetX: 0,
      offsetY: 4
    })
    .position({
      x: this.completionPopupLeft,
      y: this.completionPopupTop
    })
    .zIndex(9)
  }

  @Builder
  private buildCompletionPopupItem(item: CompletionItem, index: number): void {
    Row() {
      Text(this.getCompletionKindBadgeText(item.kind))
        .width(COMPLETION_KIND_BADGE_SIZE)
        .height(COMPLETION_KIND_BADGE_SIZE)
        .textAlign(TextAlign.Center)
        .fontSize(10)
        .fontWeight('700')
        .fontColor('#FFFFFFFF')
        .backgroundColor(this.getCompletionKindBadgeColor(item.kind))
        .borderRadius(COMPLETION_KIND_BADGE_RADIUS)
        .margin({ right: COMPLETION_KIND_BADGE_GAP })

      Text(item.label)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontSize(13)
        .fontWeight('400')
        .fontColor(colorToHex(this.theme.completionLabelColor))

      if (item.detail !== null && item.detail.length > 0) {
        Text(item.detail)
          .margin({ left: 8 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontSize(11)
          .fontColor(colorToHex(this.theme.completionDetailColor))
      }
    }
    .width('100%')
    .height(COMPLETION_ITEM_HEIGHT)
    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
    .backgroundColor(index === this.completionPopupSelectedIndex
      ? colorToHex(this.theme.completionSelectedBgColor)
      : '#00000000')
    .borderRadius(6)
    .onClick(() => {
      if (!this.completionPopupController) {
        return;
      }
      this.completionPopupController.confirmItem(index);
    })
  }

  private applyCompletionPopupState(items: CompletionItem[], selectedIndex: number, position: PopupPosition): void {
    if (items.length === 0) {
      this.dismissCompletionPopupState();
      return;
    }

    const popupWidth = Math.min(position.popupWidth, Math.max(220, this.viewWidth - COMPLETION_POPUP_SIDE_MARGIN * 2));
    const popupHeight = Math.min(position.popupHeight, Math.max(COMPLETION_ITEM_HEIGHT, items.length * COMPLETION_ITEM_HEIGHT));
    const belowTop = this.clampNumber(position.belowY, COMPLETION_POPUP_TOP_MARGIN,
      Math.max(COMPLETION_POPUP_TOP_MARGIN, this.viewHeight - popupHeight - COMPLETION_POPUP_TOP_MARGIN));
    const aboveTop = this.clampNumber(position.aboveY, COMPLETION_POPUP_TOP_MARGIN,
      Math.max(COMPLETION_POPUP_TOP_MARGIN, this.viewHeight - popupHeight - COMPLETION_POPUP_TOP_MARGIN));
    const preferBelow = position.belowY + popupHeight <= this.viewHeight - COMPLETION_POPUP_TOP_MARGIN ||
      position.aboveY < COMPLETION_POPUP_TOP_MARGIN;

    this.completionPopupWidth = popupWidth;
    this.completionPopupLeft = this.clampNumber(position.x, COMPLETION_POPUP_SIDE_MARGIN,
      Math.max(COMPLETION_POPUP_SIDE_MARGIN, this.viewWidth - popupWidth - COMPLETION_POPUP_SIDE_MARGIN));
    this.completionPopupTop = preferBelow ? belowTop : aboveTop;
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
    const maxLeft = Math.max(INLINE_SUGGESTION_BAR_SIDE_MARGIN,
      this.viewWidth - INLINE_SUGGESTION_BAR_ESTIMATED_WIDTH - INLINE_SUGGESTION_BAR_SIDE_MARGIN);
    const aboveTop = y - INLINE_SUGGESTION_BAR_HEIGHT - INLINE_SUGGESTION_BAR_GAP;
    const belowTop = y + cursorHeight + INLINE_SUGGESTION_BAR_GAP;
    let top = aboveTop;
    if (top < INLINE_SUGGESTION_BAR_SIDE_MARGIN) {
      top = belowTop;
    }
    this.inlineSuggestionBarLeft = this.clampNumber(x, INLINE_SUGGESTION_BAR_SIDE_MARGIN, maxLeft);
    this.inlineSuggestionBarTop = this.clampNumber(
      top,
      INLINE_SUGGESTION_BAR_SIDE_MARGIN,
      Math.max(INLINE_SUGGESTION_BAR_SIDE_MARGIN,
        this.viewHeight - INLINE_SUGGESTION_BAR_HEIGHT - INLINE_SUGGESTION_BAR_SIDE_MARGIN)
    );
    this.inlineSuggestionBarVisible = true;
  }

  private dismissInlineSuggestionBarState(): void {
    this.inlineSuggestionBarVisible = false;
  }

  private getInlineSuggestionOverlayColor(): string {
    const bgColor = this.theme.inlineSuggestionBarBgColor;
    const r = (bgColor >>> 16) & 0xFF;
    const g = (bgColor >>> 8) & 0xFF;
    const b = bgColor & 0xFF;
    const luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    return luminance > 128 ? 'rgba(0, 0, 0, 0.133)' : 'rgba(255, 255, 255, 0.133)';
  }

  private getCompletionKindBadgeText(kind: number): string {
    switch (kind) {
      case CompletionItem.KIND_KEYWORD:
        return 'K';
      case CompletionItem.KIND_FUNCTION:
        return 'F';
      case CompletionItem.KIND_VARIABLE:
        return 'V';
      case CompletionItem.KIND_CLASS:
        return 'C';
      case CompletionItem.KIND_INTERFACE:
        return 'I';
      case CompletionItem.KIND_MODULE:
        return 'M';
      case CompletionItem.KIND_PROPERTY:
        return 'P';
      case CompletionItem.KIND_SNIPPET:
        return 'S';
      default:
        return 'T';
    }
  }

  private getCompletionKindBadgeColor(kind: number): string {
    switch (kind) {
      case CompletionItem.KIND_KEYWORD:
        return '#FFC678DD';
      case CompletionItem.KIND_FUNCTION:
        return '#FF61AFEF';
      case CompletionItem.KIND_VARIABLE:
        return '#FFE5C07B';
      case CompletionItem.KIND_CLASS:
        return '#FFE06C75';
      case CompletionItem.KIND_INTERFACE:
        return '#FF56B6C2';
      case CompletionItem.KIND_MODULE:
        return '#FFD19A66';
      case CompletionItem.KIND_PROPERTY:
        return '#FF98C379';
      case CompletionItem.KIND_SNIPPET:
        return '#FFBE5046';
      default:
        return '#FF7A8494';
    }
  }

  private applySelectionMenuState(state: SelectionMenuState): void {
    if (!state.visible || state.items.length === 0) {
      this.selectionMenuVisible = false;
      this.selectionMenuItems = [];
      return;
    }

    const menuWidth = this.getSelectionMenuPanelWidth(state.items);
    const menuHeight = SELECTION_MENU_ITEM_HEIGHT + 8;
    const maxLeft = Math.max(SELECTION_MENU_SIDE_MARGIN, this.viewWidth - menuWidth - SELECTION_MENU_SIDE_MARGIN);
    const maxTop = Math.max(SELECTION_MENU_TOP_MARGIN, this.viewHeight - menuHeight - SELECTION_MENU_TOP_MARGIN);

    this.selectionMenuLeft = this.clampNumber(
      state.x - menuWidth * 0.5,
      SELECTION_MENU_SIDE_MARGIN,
      maxLeft
    );
    this.selectionMenuTop = this.clampNumber(state.y, SELECTION_MENU_TOP_MARGIN, maxTop);
    this.selectionMenuItems = [...state.items];
    this.selectionMenuVisible = true;
  }

  private getSelectionMenuPanelWidth(items: SelectionMenuItem[]): number {
    let width = 8;
    for (let i = 0; i < items.length; i++) {
      width += this.getSelectionMenuItemWidth(items[i]);
      if (i < items.length - 1) {
        width += 1;
      }
    }
    return width;
  }

  private getSelectionMenuItemWidth(item: SelectionMenuItem): number {
    return Math.max(
      SELECTION_MENU_ITEM_MIN_WIDTH,
      item.label.length * 9 + SELECTION_MENU_HORIZONTAL_PADDING * 2
    );
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

    this.settings = new EditorSettings(this);
    this.editorCore.setCompositionEnabled(this.settings.isCompositionEnabled());
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
    this.controller.bind(this);
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
    this.selectionMenuController = new SelectionMenuController(this, this.eventBus);
    this.selectionMenuController.setStateListener((state: SelectionMenuState): void => {
      this.applySelectionMenuState(state);
    });

    // NewLineActionProviderManager
    this.newLineActionProviderManager = new NewLineActionProviderManager();
  }

  // ==================== Document Loading ====================

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

  // ==================== Settings ====================

  getSettings(): EditorSettings | null {
    return this.settings;
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

  applyFoldArrowMode(mode: FoldArrowMode): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setFoldArrowMode(mode);
  }

  applyWrapMode(mode: WrapMode): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setWrapMode(mode);
    this.flush();
  }

  applyLineSpacing(add: number, mult: number): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setLineSpacing(add, mult);
    this.flush();
  }

  applyContentStartPadding(padding: number): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setContentStartPadding(padding);
    this.flush();
  }

  applyShowSplitLine(show: boolean): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setShowSplitLine(show);
    this.flush();
  }

  applyGutterSticky(sticky: boolean): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setGutterSticky(sticky);
    this.flush();
  }

  applyGutterVisible(visible: boolean): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setGutterVisible(visible);
    this.flush();
  }

  applyCurrentLineRenderMode(mode: CurrentLineRenderMode): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setCurrentLineRenderMode(mode);
    this.flush();
  }

  applyAutoIndentMode(mode: AutoIndentMode): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setAutoIndentMode(mode);
  }

  applyBackspaceUnindent(enabled: boolean): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setBackspaceUnindent(enabled);
  }

  applyReadOnly(readOnly: boolean): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setReadOnly(readOnly);
  }

  applyCompositionEnabled(enabled: boolean): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setCompositionEnabled(enabled);
    this.flush();
  }

  applyMaxGutterIcons(count: number): void {
    if (!this.editorCore) {
      return;
    }
    this.editorCore.setMaxGutterIcons(count);
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
    if (!config || !this.editorCore) return;

    if (config.brackets) {
      const opens: number[] = [];
      const closes: number[] = [];
      for (const pair of config.brackets) {
        opens.push(pair.open.length > 0 ? pair.open.codePointAt(0)! : 0);
        closes.push(pair.close.length > 0 ? pair.close.codePointAt(0)! : 0);
      }
      this.editorCore.setBracketPairs(opens, closes);
    }
    if (config.autoClosingPairs) {
      const acOpens: number[] = [];
      const acCloses: number[] = [];
      for (const pair of config.autoClosingPairs) {
        acOpens.push(pair.open.length > 0 ? pair.open.codePointAt(0)! : 0);
        acCloses.push(pair.close.length > 0 ? pair.close.codePointAt(0)! : 0);
      }
      this.editorCore.setAutoClosingPairs(acOpens, acCloses);
    }
    if (config.tabSize > 0) {
      this.editorCore.setTabSize(config.tabSize);
    }
    this.editorCore.setInsertSpaces(config.insertSpaces);
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

  isCompositionEnabled(): boolean {
    return this.settings ? this.settings.isCompositionEnabled() : this.editorCore?.isCompositionEnabled() ?? true;
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

    const nativeKeyCode = this.resolveNativeKeyCode(event, modifiers);
    if (nativeKeyCode !== 0) {
      // Enter key: check NewLineActionProvider first
      if (nativeKeyCode === 13 && this.tryHandleNewLineAction()) {
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

  private resolveNativeKeyCode(event: KeyEvent, modifiers: number): number {
    const nativeKeyCode = this.mapOhosKeyCodeToNative(event.keyCode);
    if (nativeKeyCode !== 0) {
      return nativeKeyCode;
    }

    if ((modifiers & (KeyModifier.CTRL | KeyModifier.META | KeyModifier.ALT)) === 0) {
      return 0;
    }

    const text = this.extractPrintableKeyText(event);
    if (!text) {
      return 0;
    }

    const mappedKeyCode = this.mapPrintableKeyCode(text);
    if (mappedKeyCode === KeyCode.NONE) {
      return 0;
    }
    return mappedKeyCode as number;
  }

  private mapPrintableKeyCode(text: string): KeyCode {
    const normalized = text.toUpperCase();
    switch (normalized) {
      case 'A':
        return KeyCode.A;
      case 'C':
        return KeyCode.C;
      case 'D':
        return KeyCode.D;
      case 'K':
        return KeyCode.K;
      case 'V':
        return KeyCode.V;
      case 'X':
        return KeyCode.X;
      case 'Y':
        return KeyCode.Y;
      case 'Z':
        return KeyCode.Z;
      case ' ':
        return KeyCode.SPACE;
      default:
        return KeyCode.NONE;
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
        this.eventBus.emit('longPress', new LongPressEvent(result.cursorPosition, screenPoint));
        this.eventBus.emit('cursorChanged', new CursorChangedEvent(result.cursorPosition));
        break;
      case GestureType.DOUBLE_TAP:
        this.eventBus.emit('doubleTap', new DoubleTapEvent(
          result.cursorPosition, result.hasSelection, result.selection, screenPoint));
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
          this.fireHitTargetEvent(result, screenPoint);
        }
        break;
      case GestureType.SCROLL:
      case GestureType.FAST_SCROLL:
        this.eventBus.emit('scrollChanged', new ScrollChangedEvent(result.viewScrollX, result.viewScrollY));
        if (this.decorationProviderManager) {
          this.decorationProviderManager.onScrollChanged();
        }
        if (this.completionPopupController && this.completionPopupController.isShowing() &&
          this.completionProviderManager) {
          this.completionProviderManager.dismiss();
        }
        break;
      case GestureType.SCALE:
        this.eventBus.emit('scaleChanged', new ScaleChangedEvent(result.viewScale));
        break;
      case GestureType.DRAG_SELECT:
        this.eventBus.emit('selectionChanged', new SelectionChangedEvent(
          result.hasSelection, result.selection, result.cursorPosition));
        break;
      case GestureType.CONTEXT_MENU:
        this.eventBus.emit('contextMenu', new ContextMenuEvent(result.cursorPosition, screenPoint));
        break;
    }
  }

  private fireHitTargetEvent(result: GestureResult, screenPoint: PointF): void {
    const ht = result.hitTarget;
    switch (ht.type) {
      case HitTargetType.INLAY_HINT_ICON:
        this.eventBus.emit('inlayHintClick', new InlayHintClickEvent(
          ht.line, ht.column, InlayType.Icon, ht.iconId, screenPoint));
        break;
      case HitTargetType.INLAY_HINT_TEXT:
        this.eventBus.emit('inlayHintClick', new InlayHintClickEvent(
          ht.line, ht.column, InlayType.Text, 0, screenPoint));
        break;
      case HitTargetType.INLAY_HINT_COLOR:
        this.eventBus.emit('inlayHintClick', new InlayHintClickEvent(
          ht.line, ht.column, InlayType.Color, ht.colorValue, screenPoint));
        break;
      case HitTargetType.GUTTER_ICON:
        this.eventBus.emit('gutterIconClick', new GutterIconClickEvent(ht.line, ht.iconId, screenPoint));
        break;
      case HitTargetType.FOLD_PLACEHOLDER:
      case HitTargetType.FOLD_GUTTER:
        this.eventBus.emit('foldToggle', new FoldToggleEvent(
          ht.line, ht.type === HitTargetType.FOLD_GUTTER, screenPoint));
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

  private maybeTriggerCompletionFromChanges(textChanges: TextChange[]): void {
    if (!this.completionProviderManager || !this.editorCore || this.editorCore.isInLinkedEditing()) {
      return;
    }

    const popupShowing = this.completionPopupController !== null && this.completionPopupController.isShowing();

    if (textChanges.length === 0) {
      if (popupShowing) {
        this.completionProviderManager.dismiss();
      }
      return;
    }

    const primaryChange = textChanges[0];
    const newText = primaryChange.newText;
    if (newText && newText.length === 1) {
      if (this.completionProviderManager.isTriggerCharacter(newText)) {
        this.completionProviderManager.triggerCompletion(CompletionTriggerKind.CHARACTER, newText);
      } else if (popupShowing) {
        this.completionProviderManager.dismiss();
      } else if (this.isCompletionInvokeCharacter(newText)) {
        this.completionProviderManager.triggerCompletion(CompletionTriggerKind.INVOKED, null);
      }
      return;
    }

    if (popupShowing) {
      this.completionProviderManager.dismiss();
    }
  }

  private isCompletionInvokeCharacter(ch: string): boolean {
    if (ch.length !== 1) {
      return false;
    }
    const code = ch.charCodeAt(0);
    return ch === '_' ||
      (code >= 48 && code <= 57) ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
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
      hilog.error(HILOG_DOMAIN, TAG, 'registerImeCallbacks failed %{public}s', JSON.stringify(e));
    }
    try {
      const previewController = this.getPreviewInputController();
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
    } catch (e) {
      hilog.error(HILOG_DOMAIN, TAG, 'unregisterImeCallbacks failed %{public}s', JSON.stringify(e));
    }
    try {
      const previewController = this.getPreviewInputController();
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
    if (!this.editorCore || !this.isCompositionEnabled()) {
      return;
    }
    this.selectRangeByIme(range);
    this.compositionUpdate(text);
  }

  private finishImePreviewText(): void {
    if (!this.editorCore || !this.isCompositionEnabled() || !this.editorCore.isComposing()) {
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

  private clampNumber(value: number, min: number, max: number): number {
    if (max < min) {
      return min;
    }
    return Math.min(Math.max(value, min), max);
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
  const a = ((argb >>> 24) & 0xFF) / 255;
  const r = (argb >>> 16) & 0xFF;
  const g = (argb >>> 8) & 0xFF;
  const b = argb & 0xFF;
  return `rgba(${r}, ${g}, ${b}, ${a.toFixed(3)})`;
}

