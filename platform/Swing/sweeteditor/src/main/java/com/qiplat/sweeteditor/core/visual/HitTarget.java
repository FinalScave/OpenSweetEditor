package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

public class HitTarget {
    @SerializedName("type") public HitTargetType type;
    @SerializedName("line") public int line;
    @SerializedName("column") public int column;
    @SerializedName("icon_id") public int iconId;
    @SerializedName("color_value") public int colorValue;
}
