package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Bracket pair highlight rectangle (cursor-side bracket + matching bracket)
 */
public class BracketHighlightRect {
    /** Top-left corner of the rectangle */
    @SerializedName("origin")
    public PointF origin;

    /** Width of the rectangle */
    @SerializedName("width")
    public float width;

    /** Height of the rectangle */
    @SerializedName("height")
    public float height;
}
