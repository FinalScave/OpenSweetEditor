package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class SelectionHandle {
    @SerializedName("position") public PointF position;
    @SerializedName("height") public float height;
    @SerializedName("visible") public boolean visible;
}
