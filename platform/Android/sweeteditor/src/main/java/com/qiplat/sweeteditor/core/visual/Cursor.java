package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;
import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Cursor data.
 */
public class Cursor {
    /** Cursor logical position in text. */
    @SerializedName("text_position")
    public TextPosition textPosition;

    /** Cursor screen position. */
    @SerializedName("position")
    public PointF position;

    /** Cursor height. */
    @SerializedName("height")
    public float height;

    /** Whether cursor is visible. */
    @SerializedName("visible")
    public boolean visible;

    /** Whether drag cursor is shown. */
    @SerializedName("show_dragger")
    public boolean showDragger;
}
