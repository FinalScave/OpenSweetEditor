package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class GutterIconRenderItem {
    @SerializedName("logical_line") public int logicalLine;
    @SerializedName("icon_id") public int iconId;
    @SerializedName("origin") public PointF origin;
    @SerializedName("width") public float width;
    @SerializedName("height") public float height;
}
