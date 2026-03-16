package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Immutable value object representing a bracket matching branch line.
 */
public final class BracketGuide {
    /** Parent position (left bracket) */
    public final TextPosition parent;
    /** End position (right bracket) */
    public final TextPosition end;
    /** Child position list (comma, semicolon, etc. branch points), may be null */
    public final TextPosition[] children;

    public BracketGuide(TextPosition parent, TextPosition end, TextPosition[] children) {
        this.parent = parent;
        this.end = end;
        this.children = children;
    }
}
