package com.qiplat.sweeteditor.core.adornment;

public final class StyleSpan {
    public int column = 0;
    public int length = 0;
    public int styleId = 0;

    public StyleSpan() {
    }

    public StyleSpan(int column, int length, int styleId) {
        this.column = column;
        this.length = length;
        this.styleId = styleId;
    }
}
