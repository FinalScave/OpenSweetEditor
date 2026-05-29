package com.qiplat.sweeteditor.core.adornment;

public final class PhantomText {
    public int column = 0;
    public String text = "";

    public PhantomText() {
    }

    public PhantomText(int column, String text) {
        this.column = column;
        this.text = text;
    }
}
