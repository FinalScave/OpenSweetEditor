package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class CompositionDecoration {
    @SerializedName("active") public boolean active;
    @SerializedName("origin") public PointF origin;
    @SerializedName("width") public float width;
    @SerializedName("height") public float height;
}
