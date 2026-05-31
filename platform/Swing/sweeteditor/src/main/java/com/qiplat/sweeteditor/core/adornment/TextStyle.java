package com.qiplat.sweeteditor.core.adornment;

public final class TextStyle {
    public static final int NORMAL = 0;
    public static final int BOLD = 1;
    public static final int ITALIC = 2;
    public static final int STRIKETHROUGH = 4;

    public int color = 0;
    public int backgroundColor = 0;
    public int fontStyle;

    public TextStyle() {
    }

    public TextStyle(int color, int backgroundColor, int fontStyle) {
        this.color = color;
        this.backgroundColor = backgroundColor;
        this.fontStyle = fontStyle;
    }

    public TextStyle(int color, int fontStyle) {
        this(color, 0, fontStyle);
    }
}
