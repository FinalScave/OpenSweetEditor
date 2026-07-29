package com.qiplat.sweeteditor.core.ime;

public enum ImeHostAction {
    NONE(0),
    CLOSE_SESSION(1),
    RESTART_SESSION(2),
    SYNC_EDITING_STATE(3);

    public final int value;

    ImeHostAction(int value) {
        this.value = value;
    }

    public static ImeHostAction fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return CLOSE_SESSION;
            case 2: return RESTART_SESSION;
            case 3: return SYNC_EDITING_STATE;
            default: throw new IllegalArgumentException("Unknown ImeHostAction value: " + value);
        }
    }
}
