package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a highlight span on a single line.
 * <p>
 * Each StyleSpan represents the style information for a contiguous text segment,
 * including the starting column, character length, and style ID.
 */
public class StyleSpan {
    /** Starting column (0-based, UTF-16 offset) */
    public final int column;
    /** Character length */
    public final int length;
    /** Style ID registered via registerStyle */
    public final int styleId;

    public StyleSpan(int column, int length, int styleId) {
        this.column = column;
        this.length = length;
        this.styleId = styleId;
    }
}
