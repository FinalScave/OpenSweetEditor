package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class LinkedEditingRect {
    @SerializedName("origin") public PointF origin;
    @SerializedName("width") public float width;
    @SerializedName("height") public float height;
    @SerializedName("is_active") public boolean isActive;
}
