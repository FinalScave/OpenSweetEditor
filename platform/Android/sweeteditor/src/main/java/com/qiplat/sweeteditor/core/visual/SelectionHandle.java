package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Selection handle (drag handle for text selection)
 */
public class SelectionHandle {
    /** Cursor position (top coordinate of cursor vertical line) */
    @SerializedName("position")
    public PointF position;

    /** Cursor height (line height) */
    @SerializedName("height")
    public float height;

    /** Whether the handle is visible */
    @SerializedName("visible")
    public boolean visible;
}
