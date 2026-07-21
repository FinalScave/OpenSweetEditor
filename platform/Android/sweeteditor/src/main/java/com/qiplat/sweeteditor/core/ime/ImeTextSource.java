package com.qiplat.sweeteditor.core.ime;

public enum ImeTextSource {
    EDITING(0),
    COMMITTED(1),
    EDITING_BUFFER(2);

    public final int value;

    ImeTextSource(int value) {
        this.value = value;
    }

    public static ImeTextSource fromValue(int value) {
        switch (value) {
            case 0: return EDITING;
            case 1: return COMMITTED;
            case 2: return EDITING_BUFFER;
            default: throw new IllegalArgumentException("Unknown ImeTextSource value: " + value);
        }
    }
}
