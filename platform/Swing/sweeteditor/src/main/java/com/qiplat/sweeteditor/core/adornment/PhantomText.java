package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing phantom text (virtual inserted text) on a single line.
 */
public final class PhantomText {
    /** Insertion column (0-based, UTF-16 offset) */
    public final int column;
    /** Phantom text content */
    public final String text;

    public PhantomText(int column, String text) {
        this.column = column;
        this.text = text;
    }
}
