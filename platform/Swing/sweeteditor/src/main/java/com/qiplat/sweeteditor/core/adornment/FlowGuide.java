package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Immutable value object representing a control flow return arrow.
 */
public final class FlowGuide {
    /** Loop header position */
    public final TextPosition start;
    /** Loop tail position */
    public final TextPosition end;

    public FlowGuide(TextPosition start, TextPosition end) {
        this.start = start;
        this.end = end;
    }

    public FlowGuide(int startLine, int startColumn, int endLine, int endColumn) {
        this(new TextPosition(startLine, startColumn), new TextPosition(endLine, endColumn));
    }
}
