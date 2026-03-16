package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

/**
 * Lightweight inline style (color + font style only, used in rendering pipeline)
 */
public class InlineStyle {
    /** Color value (ARGB), 0 means use default color */
    @SerializedName("color")
    public int color;

    /** Background color value (ARGB), 0 means transparent/no background */
    @SerializedName("background_color")
    public int backgroundColor;

    /** Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH) */
    @SerializedName("font_style")
    public int fontStyle;
}
