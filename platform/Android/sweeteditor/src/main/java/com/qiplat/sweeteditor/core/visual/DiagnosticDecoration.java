package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Diagnostic decoration rendering primitive (squiggly underline)
 */
public class DiagnosticDecoration {
    /** Starting screen coordinate of the squiggly line region */
    @SerializedName("origin")
    public PointF origin;

    /** Width of the squiggly line */
    @SerializedName("width")
    public float width;

    /** Line height (used for baseline offset positioning) */
    @SerializedName("height")
    public float height;

    /** Severity level (0=ERROR, 1=WARNING, 2=INFO, 3=HINT) */
    @SerializedName("severity")
    public int severity;

    /** Color value (ARGB), 0 means use default color for severity */
    @SerializedName("color")
    public int color;
}
