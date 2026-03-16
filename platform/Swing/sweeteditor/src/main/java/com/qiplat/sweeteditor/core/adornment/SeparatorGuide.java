package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a horizontal separator line.
 */
public final class SeparatorGuide {
    /** Line number (0-based) */
    public final int line;
    /** Separator style (0=single dash, 1=double dash) */
    public final int style;
    /** Symbol count (controls line length) */
    public final int count;
    /** End column of comment text (line starts drawing from here) */
    public final int textEndColumn;

    public SeparatorGuide(int line, int style, int count, int textEndColumn) {
        this.line = line;
        this.style = style;
        this.count = count;
        this.textEndColumn = textEndColumn;
    }
}
