package com.qiplat.sweeteditor.core.config;

public enum FoldArrowMode {
    AUTO(0),
    ALWAYS(1),
    HIDDEN(2);

    public final int value;

    FoldArrowMode(int value) {
        this.value = value;
    }

    public static FoldArrowMode fromValue(int value) {
        switch (value) {
            case 0: return AUTO;
            case 1: return ALWAYS;
            case 2: return HIDDEN;
            default: return AUTO;
        }
    }
}
