package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Visual text run structure definition.
 */
public class VisualRun {
    /** Run type. */
    @SerializedName("type")
    public VisualRunType type;

    /** Starting X coordinate for drawing. */
    @SerializedName("x")
    public float x;

    /** Starting Y coordinate for drawing. */
    @SerializedName("y")
    public float y;

    /** Run text content (only used by TEXT, INLAY_HINT(TEXT), PHANTOM_TEXT). */
    @SerializedName("text")
    public String text;

    /** Style (color + font style). */
    @SerializedName("style")
    public InlineStyle style;

    /** Icon resource ID (used only by INLAY_HINT(ICON) type). */
    @SerializedName("icon_id")
    public int iconId;

    /** Color value (ARGB, used only by INLAY_HINT(COLOR) type). */
    @SerializedName("color_value")
    public int colorValue;

    /** Pre-computed width (filled during C++ layout phase). */
    @SerializedName("width")
    public float width;

    /** Horizontal background padding (InlayHint only; left and right each). */
    @SerializedName("padding")
    public float padding;

    /** Horizontal margin with previous/next run (InlayHint only; left and right each). */
    @SerializedName("margin")
    public float margin;
}
