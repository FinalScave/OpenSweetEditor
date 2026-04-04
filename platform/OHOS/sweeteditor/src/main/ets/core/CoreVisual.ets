import { TextPosition } from './CoreFoundation';
import { TextStyle } from './CoreAdornments';

export interface PointF {
  x: number;
  y: number;
}

export enum VisualRunType {
  TEXT = 0,
  WHITESPACE = 1,
  NEWLINE = 2,
  INLAY_HINT = 3,
  PHANTOM_TEXT = 4,
  FOLD_PLACEHOLDER = 5,
  TAB = 6
}

export enum FoldState {
  NONE = 0,
  EXPANDED = 1,
  COLLAPSED = 2
}

export enum GuideDirection {
  HORIZONTAL = 0,
  VERTICAL = 1
}

export enum GuideType {
  INDENT = 0,
  BRACKET = 1,
  FLOW = 2,
  SEPARATOR = 3
}

export enum GuideStyle {
  SOLID = 0,
  DASHED = 1,
  DOTTED = 2,
  DOUBLE = 3
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
}

export interface VisualLine {
  logicalLine: number;
  wrapIndex: number;
  lineNumberPosition: PointF;
  runs: VisualRun[];
  isPhantomLine: boolean;
  foldState: FoldState;
}

export interface GutterIconRenderItem {
  logicalLine: number;
  iconId: number;
  origin: PointF;
  width: number;
  height: number;
}

export interface FoldMarkerRenderItem {
  logicalLine: number;
  foldState: FoldState;
  origin: PointF;
  width: number;
  height: number;
}

export interface Cursor {
  textPosition: TextPosition;
  position: PointF;
  height: number;
  visible: boolean;
  showDragger: boolean;
}

export interface SelectionRect {
  origin: PointF;
  width: number;
  height: number;
}

export interface SelectionHandle {
  position: PointF;
  height: number;
  visible: boolean;
}

export interface CompositionDecoration {
  active: boolean;
  origin: PointF;
  width: number;
  height: number;
}

export interface GuideSegment {
  direction: GuideDirection;
  type: GuideType;
  style: GuideStyle;
  start: PointF;
  end: PointF;
  arrowEnd: boolean;
}

export interface DiagnosticDecoration {
  origin: PointF;
  width: number;
  height: number;
  severity: number;
  color: number;
}

export interface LinkedEditingRect {
  origin: PointF;
  width: number;
  height: number;
  isActive: boolean;
}

export interface BracketHighlightRect {
  origin: PointF;
  width: number;
  height: number;
}

export interface ScrollbarRect {
  origin: PointF;
  width: number;
  height: number;
}

export interface ScrollbarModel {
  visible: boolean;
  alpha: number;
  thumbActive: boolean;
  track: ScrollbarRect;
  thumb: ScrollbarRect;
}

export interface CursorRect {
  x: number;
  y: number;
  height: number;
}

export interface ScrollMetrics {
  scale: number;
  scrollX: number;
  scrollY: number;
  maxScrollX: number;
  maxScrollY: number;
  contentWidth: number;
  contentHeight: number;
  viewportWidth: number;
  viewportHeight: number;
  textAreaX: number;
  textAreaWidth: number;
  canScrollX: boolean;
  canScrollY: boolean;
}

export interface EditorRenderModel {
  splitX: number;
  splitLineVisible: boolean;
  scrollX: number;
  scrollY: number;
  viewportWidth: number;
  viewportHeight: number;
  currentLine: PointF;
  currentLineRenderMode: number;
  visualLines: VisualLine[];
  gutterIcons: GutterIconRenderItem[];
  foldMarkers: FoldMarkerRenderItem[];
  cursor: Cursor;
  selectionRects: SelectionRect[];
  selectionStartHandle: SelectionHandle;
  selectionEndHandle: SelectionHandle;
  compositionDecoration: CompositionDecoration;
  guideSegments: GuideSegment[];
  diagnosticDecorations: DiagnosticDecoration[];
  maxGutterIcons: number;
  linkedEditingRects: LinkedEditingRect[];
  bracketHighlightRects: BracketHighlightRect[];
  verticalScrollbar: ScrollbarModel;
  horizontalScrollbar: ScrollbarModel;
  gutterSticky: boolean;
  gutterVisible: boolean;
}

