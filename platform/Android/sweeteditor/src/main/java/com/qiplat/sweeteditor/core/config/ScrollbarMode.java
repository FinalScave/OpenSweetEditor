package com.qiplat.sweeteditor.core.config;

public enum ScrollbarMode {
    ALWAYS(0),
    TRANSIENT(1),
    NEVER(2);

    public final int value;

    ScrollbarMode(int value) {
        this.value = value;
    }

    public static ScrollbarMode fromValue(int value) {
        switch (value) {
            case 0: return ALWAYS;
            case 1: return TRANSIENT;
            case 2: return NEVER;
            default: return ALWAYS;
        }
    }
}
