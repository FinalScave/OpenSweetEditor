package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Code structure line rendering primitive
 */
public class GuideSegment {
    @SerializedName("direction")
    public GuideDirection direction;

    @SerializedName("type")
    public GuideType type;

    @SerializedName("style")
    public GuideStyle style;

    @SerializedName("start")
    public PointF start;

    @SerializedName("end")
    public PointF end;

    @SerializedName("arrow_end")
    public boolean arrowEnd;
}
