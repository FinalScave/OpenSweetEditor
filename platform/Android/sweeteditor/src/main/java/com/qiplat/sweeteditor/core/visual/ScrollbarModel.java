package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Scrollbar render model for one axis.
 */
public class ScrollbarModel {
    /** Whether scrollbar is visible. */
    @SerializedName("visible")
    public boolean visible;

    /** Scrollbar alpha in [0, 1]. */
    @SerializedName("alpha")
    public float alpha;

    /** Track rectangle. */
    @SerializedName("track")
    public ScrollbarRect track;

    /** Thumb rectangle. */
    @SerializedName("thumb")
    public ScrollbarRect thumb;
}
