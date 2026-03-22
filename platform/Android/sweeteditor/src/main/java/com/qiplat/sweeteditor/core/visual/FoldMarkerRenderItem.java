package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * One fold marker render item with fully resolved geometry.
 */
public class FoldMarkerRenderItem {
    /** Logical line number. */
    @SerializedName("logical_line")
    public int logicalLine;

    /** Fold state on this line. */
    @SerializedName("fold_state")
    public FoldState foldState;

    /** Marker top-left origin. */
    @SerializedName("origin")
    public PointF origin;

    /** Marker width. */
    @SerializedName("width")
    public float width;

    /** Marker height. */
    @SerializedName("height")
    public float height;
}
