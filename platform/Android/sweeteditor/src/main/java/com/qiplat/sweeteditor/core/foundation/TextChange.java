package com.qiplat.sweeteditor.core.foundation;

public final class TextChange {
    public TextRange range = new TextRange();
    public String newText = "";

    public TextChange() {
    }

    public TextChange(TextRange range, String newText) {
        this.range = range;
        this.newText = newText;
    }
}
