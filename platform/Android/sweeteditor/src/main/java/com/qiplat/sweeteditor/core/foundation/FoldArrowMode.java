package com.qiplat.sweeteditor.core.foundation;

public enum FoldArrowMode {
    AUTO(0),
    ALWAYS(1),
    HIDDEN(2);

    public final int value;

    FoldArrowMode(int value) {
        this.value = value;
    }

    public static FoldArrowMode fromValue(int value) {
        for (FoldArrowMode mode : values()) {
            if (mode.value == value) {
                return mode;
            }
        }
        return AUTO;
    }
}
