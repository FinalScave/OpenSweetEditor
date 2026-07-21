package com.qiplat.sweeteditor.core.ime;

public enum ImeTextUnit {
    UTF16_CODE_UNIT(0),
    UNICODE_CODE_POINT(1);

    public final int value;

    ImeTextUnit(int value) {
        this.value = value;
    }

    public static ImeTextUnit fromValue(int value) {
        switch (value) {
            case 0: return UTF16_CODE_UNIT;
            case 1: return UNICODE_CODE_POINT;
            default: throw new IllegalArgumentException("Unknown ImeTextUnit value: " + value);
        }
    }
}
