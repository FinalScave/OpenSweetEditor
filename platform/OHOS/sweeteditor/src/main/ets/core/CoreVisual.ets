import { TextStyle } from './CoreAdornments';
import { CurrentLineRenderMode, FoldArrowMode, RangeEffectStyle } from './CoreConfig';
import { PointF, Rect, Size, TextPosition } from './CoreFoundation';

export enum FoldState {
  NONE = 0,
  EXPANDED = 1,
  COLLAPSED = 2,
}

export function foldStateFromValue(value: number): FoldState {
  switch (value) {
    case 0: return FoldState.NONE;
    case 1: return FoldState.EXPANDED;
    case 2: return FoldState.COLLAPSED;
    default: throw new Error('Unknown FoldState value: ' + value);
  }
}

export enum GuideDirection {
  VERTICAL = 0,
  HORIZONTAL = 1,
}

export function guideDirectionFromValue(value: number): GuideDirection {
  switch (value) {
    case 0: return GuideDirection.VERTICAL;
    case 1: return GuideDirection.HORIZONTAL;
    default: throw new Error('Unknown GuideDirection value: ' + value);
  }
}

export enum GuideStyle {
  SOLID = 0,
  DASHED = 1,
  DOUBLE = 2,
}

export function guideStyleFromValue(value: number): GuideStyle {
  switch (value) {
    case 0: return GuideStyle.SOLID;
    case 1: return GuideStyle.DASHED;
    case 2: return GuideStyle.DOUBLE;
    default: throw new Error('Unknown GuideStyle value: ' + value);
  }
}

export enum GuideType {
  INDENT = 0,
  BRACKET = 1,
  FLOW = 2,
  SEPARATOR = 3,
}

export function guideTypeFromValue(value: number): GuideType {
  switch (value) {
    case 0: return GuideType.INDENT;
    case 1: return GuideType.BRACKET;
    case 2: return GuideType.FLOW;
    case 3: return GuideType.SEPARATOR;
    default: throw new Error('Unknown GuideType value: ' + value);
  }
}

export enum PointerCursorType {
  DEFAULT = 0,
  TEXT = 1,
  HAND = 2,
}

export function pointerCursorTypeFromValue(value: number): PointerCursorType {
  switch (value) {
    case 0: return PointerCursorType.DEFAULT;
    case 1: return PointerCursorType.TEXT;
    case 2: return PointerCursorType.HAND;
    default: throw new Error('Unknown PointerCursorType value: ' + value);
  }
}

export enum RangeEffectKind {
  SELECTION = 0,
  SEARCH_MATCH = 1,
  SEARCH_CURRENT = 2,
  DOCUMENT_HIGHLIGHT_TEXT = 3,
  DOCUMENT_HIGHLIGHT_READ = 4,
  DOCUMENT_HIGHLIGHT_WRITE = 5,
  LINKED_EDITING_ACTIVE = 6,
  LINKED_EDITING_INACTIVE = 7,
  IME_COMPOSITION = 8,
  BRACKET_MATCH = 9,
  DIAGNOSTIC_ERROR = 10,
  DIAGNOSTIC_WARNING = 11,
  DIAGNOSTIC_INFO = 12,
  DIAGNOSTIC_HINT = 13,
}

export function rangeEffectKindFromValue(value: number): RangeEffectKind {
  switch (value) {
    case 0: return RangeEffectKind.SELECTION;
    case 1: return RangeEffectKind.SEARCH_MATCH;
    case 2: return RangeEffectKind.SEARCH_CURRENT;
    case 3: return RangeEffectKind.DOCUMENT_HIGHLIGHT_TEXT;
    case 4: return RangeEffectKind.DOCUMENT_HIGHLIGHT_READ;
    case 5: return RangeEffectKind.DOCUMENT_HIGHLIGHT_WRITE;
    case 6: return RangeEffectKind.LINKED_EDITING_ACTIVE;
    case 7: return RangeEffectKind.LINKED_EDITING_INACTIVE;
    case 8: return RangeEffectKind.IME_COMPOSITION;
    case 9: return RangeEffectKind.BRACKET_MATCH;
    case 10: return RangeEffectKind.DIAGNOSTIC_ERROR;
    case 11: return RangeEffectKind.DIAGNOSTIC_WARNING;
    case 12: return RangeEffectKind.DIAGNOSTIC_INFO;
    case 13: return RangeEffectKind.DIAGNOSTIC_HINT;
    default: throw new Error('Unknown RangeEffectKind value: ' + value);
  }
}

export enum VisualLineKind {
  CONTENT = 0,
  PHANTOM = 1,
  CODELENS = 2,
}

export function visualLineKindFromValue(value: number): VisualLineKind {
  switch (value) {
    case 0: return VisualLineKind.CONTENT;
    case 1: return VisualLineKind.PHANTOM;
    case 2: return VisualLineKind.CODELENS;
    default: throw new Error('Unknown VisualLineKind value: ' + value);
  }
}

export enum VisualRunType {
  TEXT = 0,
  WHITESPACE = 1,
  TAB = 2,
  NEWLINE = 3,
  INLAY_HINT = 4,
  PHANTOM_TEXT = 5,
  FOLD_PLACEHOLDER = 6,
  CODELENS = 7,
  LINK = 8,
}

export function visualRunTypeFromValue(value: number): VisualRunType {
  switch (value) {
    case 0: return VisualRunType.TEXT;
    case 1: return VisualRunType.WHITESPACE;
    case 2: return VisualRunType.TAB;
    case 3: return VisualRunType.NEWLINE;
    case 4: return VisualRunType.INLAY_HINT;
    case 5: return VisualRunType.PHANTOM_TEXT;
    case 6: return VisualRunType.FOLD_PLACEHOLDER;
    case 7: return VisualRunType.CODELENS;
    case 8: return VisualRunType.LINK;
    default: throw new Error('Unknown VisualRunType value: ' + value);
  }
}

export interface Cursor {
  textPosition: TextPosition;
  position: PointF;
  height: number;
  visible: boolean;
  showDragger: boolean;
}

export interface CursorRect {
  x: number;
  y: number;
  height: number;
}

export interface EditorRenderModel {
  splitX: number;
  splitLineVisible: boolean;
  scrollX: number;
  scrollY: number;
  viewportSize: Size;
  currentLine: PointF;
  currentLineRenderMode: CurrentLineRenderMode;
  lines: VisualLine[];
  cursor: Cursor;
  rangeEffects: RangeEffectRenderItem[];
  selectionStartHandle: SelectionHandle;
  selectionEndHandle: SelectionHandle;
  guideSegments: GuideSegment[];
  maxGutterIcons: number;
  gutterIcons: GutterIconRenderItem[];
  foldMarkers: FoldMarkerRenderItem[];
  verticalScrollbar: ScrollbarModel;
  horizontalScrollbar: ScrollbarModel;
  gutterSticky: boolean;
  gutterVisible: boolean;
  pointerCursorType: PointerCursorType;
}

export interface FoldMarkerRenderItem {
  logicalLine: number;
  foldState: FoldState;
  rect: Rect;
}

export interface GuideSegment {
  direction: GuideDirection;
  type: GuideType;
  style: GuideStyle;
  start: PointF;
  end: PointF;
  arrowEnd: boolean;
}

export interface GutterIconRenderItem {
  logicalLine: number;
  iconId: number;
  rect: Rect;
}

export interface LayoutMetrics {
  fontHeight: number;
  fontAscent: number;
  lineSpacingAdd: number;
  lineSpacingMult: number;
  lineNumberMargin: number;
  lineNumberWidth: number;
  contentStartPadding: number;
  maxGutterIcons: number;
  inlayHintPadding: number;
  inlayHintMargin: number;
  foldArrowMode: FoldArrowMode;
  hasFoldRegions: boolean;
  gutterSticky: boolean;
  gutterVisible: boolean;
}

export interface RangeEffectRenderItem {
  rect: Rect;
  kind: RangeEffectKind;
  style: RangeEffectStyle;
}

export interface ScrollMetrics {
  scale: number;
  scrollX: number;
  scrollY: number;
  maxScrollX: number;
  maxScrollY: number;
  contentSize: Size;
  viewportSize: Size;
  textAreaX: number;
  textAreaWidth: number;
  canScrollX: boolean;
  canScrollY: boolean;
}

export interface ScrollbarModel {
  visible: boolean;
  alpha: number;
  thumbActive: boolean;
  track: Rect;
  thumb: Rect;
}

export interface SelectionHandle {
  position: PointF;
  height: number;
  visible: boolean;
}

export interface VisualLine {
  logicalLine: number;
  wrapIndex: number;
  lineNumberPosition: PointF;
  runs: VisualRun[];
  kind: VisualLineKind;
  ownsGutterSemantics: boolean;
  foldState: FoldState;
}

export interface VisualRun {
  type: VisualRunType;
  x: number;
  y: number;
  text: string;
  style: TextStyle;
  iconId: number;
  colorValue: number;
  width: number;
  padding: number;
  margin: number;
  active: boolean;
}
