package com.qiplat.sweeteditor.core.foundation;

public final class TextPosition {
    public static final TextPosition NONE = new TextPosition();

    public int line = 0;
    public int column = 0;

    public TextPosition() {
    }

    public TextPosition(int line, int column) {
        this.line = line;
        this.column = column;
    }

    @Override
    public String toString() {
        return "TextPosition{"
                + "line=" + line
                + ", column=" + column
                + "}";
    }
}
