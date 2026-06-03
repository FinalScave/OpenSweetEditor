package com.qiplat.sweeteditor.core.config;

public final class RangeEffectStyle {
    public int foregroundColor = 0;
    public int backgroundColor = 0;
    public int borderColor = 0;
    public int underlineColor = 0;
    public RangeEffectUnderlineStyle underlineStyle = RangeEffectUnderlineStyle.NONE;

    public RangeEffectStyle() {
    }

    public RangeEffectStyle(int foregroundColor, int backgroundColor, int borderColor, int underlineColor, RangeEffectUnderlineStyle underlineStyle) {
        this.foregroundColor = foregroundColor;
        this.backgroundColor = backgroundColor;
        this.borderColor = borderColor;
        this.underlineColor = underlineColor;
        this.underlineStyle = underlineStyle;
    }
}
