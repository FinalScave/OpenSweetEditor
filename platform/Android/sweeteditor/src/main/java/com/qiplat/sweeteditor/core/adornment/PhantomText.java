package com.qiplat.sweeteditor.core.adornment;

import androidx.annotation.NonNull;

/**
 * Immutable value object representing phantom text (virtual inserted text) on a single line.
 * <p>
 * Phantom text virtually inserts text content at a specified column position
 * without modifying the actual document data. Commonly used for AI completion previews,
 * type hints, and similar scenarios.
 */
public final class PhantomText {
    /** Insertion column (0-based, UTF-16 offset) */
    public final int column;
    /** Phantom text content */
    @NonNull
    public final String text;

    /**
     * @param column Insertion column (0-based, UTF-16 offset)
     * @param text   Phantom text content
     */
    public PhantomText(int column, @NonNull String text) {
        this.column = column;
        this.text = text;
    }
}
