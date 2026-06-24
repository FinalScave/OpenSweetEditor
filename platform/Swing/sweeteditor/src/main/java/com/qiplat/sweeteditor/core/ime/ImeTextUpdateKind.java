package com.qiplat.sweeteditor.core.ime;

public enum ImeTextUpdateKind {
    SNAPSHOT(0),
    PATCH(1);

    public final int value;

    ImeTextUpdateKind(int value) {
        this.value = value;
    }

    public static ImeTextUpdateKind fromValue(int value) {
        switch (value) {
            case 0: return SNAPSHOT;
            case 1: return PATCH;
            default: return SNAPSHOT;
        }
    }
}
