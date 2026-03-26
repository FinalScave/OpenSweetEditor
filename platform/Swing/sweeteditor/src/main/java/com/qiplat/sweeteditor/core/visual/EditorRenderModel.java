package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;
import java.util.List;

public class EditorRenderModel {
    @SerializedName("split_x") public float splitX;
    @SerializedName("split_line_visible") public boolean splitLineVisible = true;
    @SerializedName("scroll_x") public float scrollX;
    @SerializedName("scroll_y") public float scrollY;
    @SerializedName("viewport_width") public float viewportWidth;
    @SerializedName("viewport_height") public float viewportHeight;
    @SerializedName("current_line") public PointF currentLine;
    @SerializedName("current_line_render_mode") public int currentLineRenderMode;
    @SerializedName("lines") public List<VisualLine> lines;
    @SerializedName("gutter_icons") public List<GutterIconRenderItem> gutterIcons;
    @SerializedName("fold_markers") public List<FoldMarkerRenderItem> foldMarkers;
    @SerializedName("cursor") public Cursor cursor;
    @SerializedName("selection_rects") public List<SelectionRect> selectionRects;
    @SerializedName("selection_start_handle") public SelectionHandle selectionStartHandle;
    @SerializedName("selection_end_handle") public SelectionHandle selectionEndHandle;
    @SerializedName("composition_decoration") public CompositionDecoration compositionDecoration;
    @SerializedName("guide_segments") public List<GuideSegment> guideSegments;
    @SerializedName("diagnostic_decorations") public List<DiagnosticDecoration> diagnosticDecorations;
    @SerializedName("max_gutter_icons") public int maxGutterIcons;
    @SerializedName("linked_editing_rects") public java.util.List<LinkedEditingRect> linkedEditingRects;
    @SerializedName("bracket_highlight_rects") public java.util.List<BracketHighlightRect> bracketHighlightRects;
    @SerializedName("vertical_scrollbar") public ScrollbarModel verticalScrollbar;
    @SerializedName("horizontal_scrollbar") public ScrollbarModel horizontalScrollbar;
    @SerializedName("gutter_sticky") public boolean gutterSticky = true;
    @SerializedName("gutter_visible") public boolean gutterVisible = true;
}
