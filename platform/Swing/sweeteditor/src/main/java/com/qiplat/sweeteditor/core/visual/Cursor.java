package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;
import com.qiplat.sweeteditor.core.foundation.TextPosition;

public class Cursor {
    @SerializedName("text_position") public TextPosition textPosition;
    @SerializedName("position") public PointF position;
    @SerializedName("height") public float height;
    @SerializedName("visible") public boolean visible;
    @SerializedName("show_dragger") public boolean showDragger;
}
