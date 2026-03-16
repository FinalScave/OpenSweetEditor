package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Linked editing highlight rectangle (visual marker for Tab Stop placeholder)
 */
public class LinkedEditingRect {
    /** Top-left corner of the rectangle */
    @SerializedName("origin")
    public PointF origin;

    /** Width of the rectangle */
    @SerializedName("width")
    public float width;

    /** Height of the rectangle */
    @SerializedName("height")
    public float height;

    /** Whether this is the currently active tab stop */
    @SerializedName("is_active")
    public boolean isActive;
}
