package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

import java.util.List;

/**
 * Editor render model.
 */
public class EditorRenderModel {
    /** Line number split X position. */
    @SerializedName("split_x")
    public float splitX;

    /** Whether split line should be rendered. */
    @SerializedName("split_line_visible")
    public boolean splitLineVisible = true;

    /** Current horizontal scroll offset. */
    @SerializedName("scroll_x")
    public float scrollX;

    /** Current vertical scroll offset. */
    @SerializedName("scroll_y")
    public float scrollY;

    /** Viewport width. */
    @SerializedName("viewport_width")
    public float viewportWidth;

    /** Viewport height. */
    @SerializedName("viewport_height")
    public float viewportHeight;

    /** Current line background position. */
    @SerializedName("current_line")
    public PointF currentLine;

    /** Current line render mode (0=BACKGROUND, 1=BORDER, 2=NONE). */
    @SerializedName("current_line_render_mode")
    public int currentLineRenderMode;

    /** Text lines to render visually (visible region only). */
    @SerializedName("lines")
    public List<VisualLine> lines;

    /** Gutter icon render list (fully resolved geometry, visible region only). */
    @SerializedName("gutter_icons")
    public List<GutterIconRenderItem> gutterIcons;

    /** Fold marker render list (fully resolved geometry, visible region only). */
    @SerializedName("fold_markers")
    public List<FoldMarkerRenderItem> foldMarkers;

    /** Cursor. */
    @SerializedName("cursor")
    public Cursor cursor;

    /** Selection highlight rectangle list. */
    @SerializedName("selection_rects")
    public List<SelectionRect> selectionRects;

    /** Selection start handle (anchor side). */
    @SerializedName("selection_start_handle")
    public SelectionHandle selectionStartHandle;

    /** Selection end handle (active side/cursor side). */
    @SerializedName("selection_end_handle")
    public SelectionHandle selectionEndHandle;

    /** Composition decoration (underline area during IME input). */
    @SerializedName("composition_decoration")
    public CompositionDecoration compositionDecoration;

    /** Code structure guide lines. */
    @SerializedName("guide_segments")
    public List<GuideSegment> guideSegments;

    /** Maximum gutter icon count (0=overlay mode, icon overlays line number; >0=exclusive mode with reserved fixed space). */
    @SerializedName("max_gutter_icons")
    public int maxGutterIcons;

    /** Diagnostic decorations (wavy underline / underline). */
    @SerializedName("diagnostic_decorations")
    public List<DiagnosticDecoration> diagnosticDecorations;

    /** Linked editing highlight rectangle list (Tab Stop placeholders). */
    @SerializedName("linked_editing_rects")
    public List<LinkedEditingRect> linkedEditingRects;

    /** Bracket pair highlight rectangle list (bracket near cursor + matching bracket). */
    @SerializedName("bracket_highlight_rects")
    public List<BracketHighlightRect> bracketHighlightRects;

    /** Vertical scrollbar render model. */
    @SerializedName("vertical_scrollbar")
    public ScrollbarModel verticalScrollbar;

    /** Horizontal scrollbar render model. */
    @SerializedName("horizontal_scrollbar")
    public ScrollbarModel horizontalScrollbar;

    /** Whether gutter stays fixed during horizontal scroll. */
    @SerializedName("gutter_sticky")
    public boolean gutterSticky = true;

    /** Whether gutter area is visible. */
    @SerializedName("gutter_visible")
    public boolean gutterVisible = true;
}
