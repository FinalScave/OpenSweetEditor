package com.qiplat.sweeteditor.core.adornment;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Immutable value object representing a control flow return arrow.
 * <p>
 * Return arrows point from the end of a loop (end) to the loop header (start),
 * used to display the control flow direction of loop structures such as for/while/do-while.
 */
public final class FlowGuide {
    /** Loop header position */
    @NonNull
    public final TextPosition start;
    /** Loop tail position */
    @NonNull
    public final TextPosition end;

    /**
     * @param start Loop header position
     * @param end   Loop tail position
     */
    public FlowGuide(@NonNull TextPosition start, @NonNull TextPosition end) {
        this.start = start;
        this.end = end;
    }

    /**
     * @param startLine   Start line (0-based)
     * @param startColumn Start column (0-based)
     * @param endLine     End line (0-based)
     * @param endColumn   End column (0-based)
     */
    public FlowGuide(int startLine, int startColumn, int endLine, int endColumn) {
        this(new TextPosition(startLine, startColumn), new TextPosition(endLine, endColumn));
    }
}
