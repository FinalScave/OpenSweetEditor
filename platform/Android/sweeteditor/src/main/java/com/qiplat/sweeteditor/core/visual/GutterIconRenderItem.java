package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * One gutter icon render item with fully resolved geometry.
 */
public class GutterIconRenderItem {
    /** Logical line number. */
    @SerializedName("logical_line")
    public int logicalLine;

    /** Icon resource ID. */
    @SerializedName("icon_id")
    public int iconId;

    /** Icon top-left origin. */
    @SerializedName("origin")
    public PointF origin;

    /** Icon width. */
    @SerializedName("width")
    public float width;

    /** Icon height. */
    @SerializedName("height")
    public float height;
}
