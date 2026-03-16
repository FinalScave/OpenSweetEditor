package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

public class GestureResult {
    @SerializedName("type") public GestureType type;
    @SerializedName("tap_point") public PointF tapPoint;
    @SerializedName("modifiers") public int modifiers;
    @SerializedName("cursor_position") public TextPosition cursorPosition;
    @SerializedName("has_selection") public boolean hasSelection;
    @SerializedName("selection") public TextRange selection;
    @SerializedName("view_scroll_x") public float viewScrollX;
    @SerializedName("view_scroll_y") public float viewScrollY;
    @SerializedName("view_scale") public float viewScale;
    @SerializedName("hit_target") public HitTarget hitTarget;
}
