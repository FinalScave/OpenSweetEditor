package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Rendering decoration for composition input region (underline)
 */
public class CompositionDecoration {
    /** Whether there is composition input decoration to draw */
    @SerializedName("active")
    public boolean active;

    /** Starting screen coordinate of the composition text region */
    @SerializedName("origin")
    public PointF origin;

    /** Width of the composition text region */
    @SerializedName("width")
    public float width;

    /** Line height */
    @SerializedName("height")
    public float height;
}
