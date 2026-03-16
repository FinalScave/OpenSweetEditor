package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;
import java.util.List;

public class EditorRenderModel {
    @SerializedName("split_x") public float splitX;
    @SerializedName("scroll_x") public float scrollX;
    @SerializedName("scroll_y") public float scrollY;
    @SerializedName("viewport_width") public float viewportWidth;
    @SerializedName("viewport_height") public float viewportHeight;
    @SerializedName("current_line") public PointF currentLine;
    @SerializedName("lines") public List<VisualLine> lines;
    @SerializedName("cursor") public Cursor cursor;
    @SerializedName("selection_rects") public List<SelectionRect> selectionRects;
    @SerializedName("selection_start_handle") public SelectionHandle selectionStartHandle;
    @SerializedName("selection_end_handle") public SelectionHandle selectionEndHandle;
    @SerializedName("composition_decoration") public CompositionDecoration compositionDecoration;
    @SerializedName("guide_segments") public List<GuideSegment> guideSegments;
    @SerializedName("diagnostic_decorations") public List<DiagnosticDecoration> diagnosticDecorations;
    @SerializedName("max_gutter_icons") public int maxGutterIcons;
    @SerializedName("fold_arrow_x") public float foldArrowX;
    @SerializedName("linked_editing_rects") public java.util.List<LinkedEditingRect> linkedEditingRects;
    @SerializedName("bracket_highlight_rects") public java.util.List<BracketHighlightRect> bracketHighlightRects;
}
