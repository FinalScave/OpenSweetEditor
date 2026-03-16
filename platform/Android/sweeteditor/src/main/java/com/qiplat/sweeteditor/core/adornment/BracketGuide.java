package com.qiplat.sweeteditor.core.adornment;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Immutable value object representing a bracket matching branch line.
 * <p>
 * Branch lines extend vertically from the parent position to the end position,
 * with horizontal branches drawn at each child position, used to display bracket matching relationships.
 */
public final class BracketGuide {
    /** Parent position (left bracket) */
    @NonNull
    public final TextPosition parent;
    /** End position (right bracket) */
    @NonNull
    public final TextPosition end;
    /** Child position list (comma, semicolon, etc. branch points), may be null */
    @Nullable
    public final TextPosition[] children;

    /**
     * @param parent   Parent position
     * @param end      End position
     * @param children Child position list
     */
    public BracketGuide(@NonNull TextPosition parent, @NonNull TextPosition end,
                        @Nullable TextPosition[] children) {
        this.parent = parent;
        this.end = end;
        this.children = children;
    }
}
