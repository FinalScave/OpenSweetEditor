package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class PointF {
    @SerializedName("x") public float x;
    @SerializedName("y") public float y;

    public PointF() {}
    public PointF(float x, float y) { this.x = x; this.y = y; }
}
