package com.qiplat.sweeteditor.core.adornment;

/**
 * Separator style enumeration.
 */
public enum SeparatorStyle {
    /** Single dash style (e.g. ------) */
    SINGLE(0),
    /** Double dash style (e.g. ======) */
    DOUBLE(1);

    public final int value;

    SeparatorStyle(int value) {
        this.value = value;
    }
}
