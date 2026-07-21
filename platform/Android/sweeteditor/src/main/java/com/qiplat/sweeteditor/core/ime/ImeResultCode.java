package com.qiplat.sweeteditor.core.ime;

public enum ImeResultCode {
    OK(0),
    SESSION_MISMATCH(1),
    REJECTED(2),
    READ_ONLY(3);

    public final int value;

    ImeResultCode(int value) {
        this.value = value;
    }

    public static ImeResultCode fromValue(int value) {
        switch (value) {
            case 0: return OK;
            case 1: return SESSION_MISMATCH;
            case 2: return REJECTED;
            case 3: return READ_ONLY;
            default: throw new IllegalArgumentException("Unknown ImeResultCode value: " + value);
        }
    }
}
