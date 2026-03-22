package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class FoldMarkerRenderItem {
    @SerializedName("logical_line") public int logicalLine;
    @SerializedName("fold_state") public FoldState foldState;
    @SerializedName("origin") public PointF origin;
    @SerializedName("width") public float width;
    @SerializedName("height") public float height;
}
