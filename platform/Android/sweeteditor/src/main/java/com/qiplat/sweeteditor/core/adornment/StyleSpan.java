package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.EditorCore;

/**
 * Immutable value object representing a highlight span on a single line.
 * <p>
 * Each StyleSpan represents the style information for a contiguous text segment,
 * including the starting column, character length, and style ID.
 * Can be used with {@link com.qiplat.sweeteditor.SweetEditor} public API
 * and {@link com.qiplat.sweeteditor.decoration.DecorationResult} decoration results.
 */
public final class StyleSpan {
    /** Starting column (0-based, UTF-16 offset) */
    public final int column;
    /** Character length */
    public final int length;
    /** Style ID registered via {@link EditorCore#registerStyle} */
    public final int styleId;

    /**
     * @param column  Starting column (0-based, UTF-16 offset)
     * @param length  Character length
     * @param styleId Style ID
     */
    public StyleSpan(int column, int length, int styleId) {
        this.column = column;
        this.length = length;
        this.styleId = styleId;
    }
}
