package com.qiplat.sweeteditor.core.adornment;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Immutable value object representing an indentation guide line.
 * <p>
 * Indentation guides extend vertically from the start position to the end position,
 * used to display the indentation level relationships of code blocks.
 */
public final class IndentGuide {
    /** Start position (line + column) */
    @NonNull
    public final TextPosition start;
    /** End position (line + column) */
    @NonNull
    public final TextPosition end;

    /**
     * @param start Start position
     * @param end   End position
     */
    public IndentGuide(@NonNull TextPosition start, @NonNull TextPosition end) {
        this.start = start;
        this.end = end;
    }

    /**
     * @param startLine   Start line (0-based)
     * @param startColumn Start column (0-based)
     * @param endLine     End line (0-based)
     * @param endColumn   End column (0-based)
     */
    public IndentGuide(int startLine, int startColumn, int endLine, int endColumn) {
        this(new TextPosition(startLine, startColumn), new TextPosition(endLine, endColumn));
    }
}
