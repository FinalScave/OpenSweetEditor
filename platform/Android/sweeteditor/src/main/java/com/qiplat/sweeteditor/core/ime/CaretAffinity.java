package com.qiplat.sweeteditor.core.ime;

public enum CaretAffinity {
    DOWNSTREAM(0),
    UPSTREAM(1);

    public final int value;

    CaretAffinity(int value) {
        this.value = value;
    }

    public static CaretAffinity fromValue(int value) {
        switch (value) {
            case 0: return DOWNSTREAM;
            case 1: return UPSTREAM;
            default: throw new IllegalArgumentException("Unknown CaretAffinity value: " + value);
        }
    }
}
