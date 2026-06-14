package com.qiplat.sweeteditor.core.ime;

public enum ImeMarkedRangeRole {
    NONE(0),
    PREEDIT(1),
    SYSTEM_MARK(2);

    public final int value;

    ImeMarkedRangeRole(int value) {
        this.value = value;
    }

    public static ImeMarkedRangeRole fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return PREEDIT;
            case 2: return SYSTEM_MARK;
            default: return NONE;
        }
    }
}
