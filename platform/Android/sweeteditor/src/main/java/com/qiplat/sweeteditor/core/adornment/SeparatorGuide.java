package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a horizontal separator line.
 * <p>
 * Separator lines extend horizontally after the end column of comment text,
 * used for separating comments such as <code>// --------</code> or <code>// ========</code>.
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

    /**
     * @param line          Line number (0-based)
     * @param style         Separator style
     * @param count         Symbol count
     * @param textEndColumn End column of comment text
     */
    public SeparatorGuide(int line, int style, int count, int textEndColumn) {
        this.line = line;
        this.style = style;
        this.count = count;
        this.textEndColumn = textEndColumn;
    }
}
