package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Immutable value object representing an indentation guide line.
 */
public final class IndentGuide {
    /** Start position (line + column) */
    public final TextPosition start;
    /** End position (line + column) */
    public final TextPosition end;

    public IndentGuide(TextPosition start, TextPosition end) {
        this.start = start;
        this.end = end;
    }

    public IndentGuide(int startLine, int startColumn, int endLine, int endColumn) {
        this(new TextPosition(startLine, startColumn), new TextPosition(endLine, endColumn));
    }
}
