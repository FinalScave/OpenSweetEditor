package com.qiplat.sweeteditor.core.foundation;

public final class TextEdit {
    public TextRange range = new TextRange();
    public String newText = "";

    public TextEdit() {
    }

    public TextEdit(TextRange range, String newText) {
        this.range = range;
        this.newText = newText;
    }
}
