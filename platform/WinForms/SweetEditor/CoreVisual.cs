#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum FoldState {
        NONE = 0,
        EXPANDED = 1,
        COLLAPSED = 2
    }

    public enum GuideDirection {
        VERTICAL = 0,
        HORIZONTAL = 1
    }

    public enum GuideStyle {
        SOLID = 0,
        DASHED = 1,
        DOUBLE = 2
    }

    public enum GuideType {
        INDENT = 0,
        BRACKET = 1,
        FLOW = 2,
        SEPARATOR = 3
    }

    public enum PointerCursorType {
        DEFAULT = 0,
        TEXT = 1,
        HAND = 2
    }

    public enum RangeEffectKind {
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
        DIAGNOSTIC_HINT = 13
    }

    public enum VisualLineKind {
        CONTENT = 0,
        PHANTOM = 1,
        CODELENS = 2,
        REMOVED = 3
    }

    public enum VisualRunType {
        TEXT = 0,
        WHITESPACE = 1,
        TAB = 2,
        NEWLINE = 3,
        INLAY_HINT = 4,
        PHANTOM_TEXT = 5,
        FOLD_PLACEHOLDER = 6,
        CODELENS = 7,
        LINK = 8
    }

    public sealed partial class Cursor {
        public TextPosition TextPosition { get; set; } = new TextPosition();
        public PointF Position { get; set; } = new PointF();
        public float Height { get; set; } = 0f;
        public bool Visible { get; set; } = true;
        public bool ShowDragger { get; set; } = false;
    }

    public sealed partial class CursorRect {
        public float X { get; set; } = 0f;
        public float Y { get; set; } = 0f;
        public float Height { get; set; } = 0f;
    }

    public sealed partial class EditorRenderModel {
        public float SplitX { get; set; } = 0f;
        public bool SplitLineVisible { get; set; } = true;
        public float ScrollX { get; set; } = 0f;
        public float ScrollY { get; set; } = 0f;
        public Size ViewportSize { get; set; } = new Size();
        public PointF CurrentLine { get; set; } = new PointF();
        public CurrentLineRenderMode CurrentLineRenderMode { get; set; } = CurrentLineRenderMode.BACKGROUND;
        public List<VisualLine> Lines { get; set; } = new();
        public Cursor Cursor { get; set; } = new Cursor();
        public List<RangeEffectRenderItem> RangeEffects { get; set; } = new();
        public SelectionHandle SelectionStartHandle { get; set; } = new SelectionHandle();
        public SelectionHandle SelectionEndHandle { get; set; } = new SelectionHandle();
        public List<GuideSegment> GuideSegments { get; set; } = new();
        public int MaxGutterIcons { get; set; } = 0;
        public List<GutterIconRenderItem> GutterIcons { get; set; } = new();
        public List<FoldMarkerRenderItem> FoldMarkers { get; set; } = new();
        public ScrollbarModel VerticalScrollbar { get; set; } = new ScrollbarModel();
        public ScrollbarModel HorizontalScrollbar { get; set; } = new ScrollbarModel();
        public bool GutterSticky { get; set; } = true;
        public bool GutterVisible { get; set; } = true;
        public PointerCursorType PointerCursorType { get; set; } = PointerCursorType.TEXT;
    }

    public sealed partial class FoldMarkerRenderItem {
        public int LogicalLine { get; set; } = 0;
        public FoldState FoldState { get; set; } = FoldState.NONE;
        public Rect Rect { get; set; } = new Rect();
    }

    public sealed partial class GuideSegment {
        public GuideDirection Direction { get; set; } = GuideDirection.VERTICAL;
        public GuideType Type { get; set; } = GuideType.INDENT;
        public GuideStyle Style { get; set; } = GuideStyle.SOLID;
        public PointF Start { get; set; } = new PointF();
        public PointF End { get; set; } = new PointF();
        public bool ArrowEnd { get; set; } = false;
    }

    public sealed partial class GutterIconRenderItem {
        public int LogicalLine { get; set; } = 0;
        public int IconId { get; set; } = 0;
        public Rect Rect { get; set; } = new Rect();
    }

    public sealed partial class LayoutMetrics {
        public float FontHeight { get; set; } = 20f;
        public float FontAscent { get; set; } = 0f;
        public float LineSpacingAdd { get; set; } = 0f;
        public float LineSpacingMult { get; set; } = 1.2f;
        public float LineNumberMargin { get; set; } = 10f;
        public float LineNumberWidth { get; set; } = 10f;
        public float ContentStartPadding { get; set; } = 0f;
        public int MaxGutterIcons { get; set; } = 0;
        public float InlayHintPadding { get; set; } = 0f;
        public float InlayHintMargin { get; set; } = 0f;
        public FoldArrowMode FoldArrowMode { get; set; } = FoldArrowMode.AUTO;
        public bool HasFoldRegions { get; set; } = false;
        public bool GutterSticky { get; set; } = true;
        public bool GutterVisible { get; set; } = true;
    }

    public sealed partial class RangeEffectRenderItem {
        public Rect Rect { get; set; } = new Rect();
        public RangeEffectKind Kind { get; set; } = RangeEffectKind.SELECTION;
        public RangeEffectStyle Style { get; set; } = new RangeEffectStyle();
    }

    public sealed partial class ScrollMetrics {
        public float Scale { get; set; } = 1f;
        public float ScrollX { get; set; } = 0f;
        public float ScrollY { get; set; } = 0f;
        public float MaxScrollX { get; set; } = 0f;
        public float MaxScrollY { get; set; } = 0f;
        public Size ContentSize { get; set; } = new Size();
        public Size ViewportSize { get; set; } = new Size();
        public float TextAreaX { get; set; } = 0f;
        public float TextAreaWidth { get; set; } = 0f;
        public bool CanScrollX { get; set; } = false;
        public bool CanScrollY { get; set; } = false;
    }

    public sealed partial class ScrollbarModel {
        public bool Visible { get; set; } = false;
        public float Alpha { get; set; } = 0f;
        public bool ThumbActive { get; set; } = false;
        public Rect Track { get; set; } = new Rect();
        public Rect Thumb { get; set; } = new Rect();
    }

    public sealed partial class SelectionHandle {
        public PointF Position { get; set; } = new PointF();
        public float Height { get; set; } = 0f;
        public bool Visible { get; set; } = false;
    }

    public sealed partial class VisualLine {
        public int LogicalLine { get; set; } = 0;
        public int WrapIndex { get; set; } = 0;
        public PointF LineNumberPosition { get; set; } = new PointF();
        public List<VisualRun> Runs { get; set; } = new();
        public VisualLineKind Kind { get; set; } = VisualLineKind.CONTENT;
        public bool OwnsGutterSemantics { get; set; } = false;
        public FoldState FoldState { get; set; } = FoldState.NONE;
        public int LineNumber { get; set; } = -1;
        public int LineBackgroundColor { get; set; } = 0;
        public int GutterBackgroundColor { get; set; } = 0;
    }

    public sealed partial class VisualRun {
        public VisualRunType Type { get; set; } = VisualRunType.TEXT;
        public float X { get; set; } = 0f;
        public float Y { get; set; } = 0f;
        public string Text { get; set; } = string.Empty;
        public TextStyle Style { get; set; } = new TextStyle();
        public int IconId { get; set; } = 0;
        public int ColorValue { get; set; } = 0;
        public float Width { get; set; } = 0f;
        public float Padding { get; set; } = 0f;
        public float Margin { get; set; } = 0f;
        public bool Active { get; set; } = false;
    }
}
