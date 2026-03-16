package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class DiagnosticDecoration {
    @SerializedName("origin") public PointF origin;
    @SerializedName("width") public float width;
    @SerializedName("height") public float height;
    @SerializedName("severity") public int severity;
    @SerializedName("color") public int color;
}
