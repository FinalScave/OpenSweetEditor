package com.qiplat.sweeteditor.core.adornment;

public final class LinkSpan {
    public int column = 0;
    public int length = 0;
    public String target = "";

    public LinkSpan() {
    }

    public LinkSpan(int column, int length, String target) {
        this.column = column;
        this.length = length;
        this.target = target;
    }
}
