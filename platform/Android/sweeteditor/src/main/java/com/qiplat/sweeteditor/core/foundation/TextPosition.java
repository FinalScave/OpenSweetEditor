package com.qiplat.sweeteditor.core.foundation;

import androidx.annotation.NonNull;

/**
 * Text position (line number + column number, both 0-based).
 */
public class TextPosition {
    public static final TextPosition NONE = new TextPosition();

    /** Line number */
    public int line;
    /** Column number */
    public int column;

    public TextPosition() {
    }

    public TextPosition(int line, int column) {
        this.line = line;
        this.column = column;
    }

    @NonNull
    @Override
    public String toString() {
        return "TextPosition{" +
                "line=" + line +
                ", column=" + column +
                '}';
    }
}
