package com.qiplat.sweeteditor.core.action;

public enum ScrollBehavior {
    GOTO_TOP(0),
    GOTO_CENTER(1),
    GOTO_BOTTOM(2);

    public final int value;

    ScrollBehavior(int value) {
        this.value = value;
    }

    public static ScrollBehavior fromValue(int value) {
        switch (value) {
            case 0: return GOTO_TOP;
            case 1: return GOTO_CENTER;
            case 2: return GOTO_BOTTOM;
            default: throw new IllegalArgumentException("Unknown ScrollBehavior value: " + value);
        }
    }
}
