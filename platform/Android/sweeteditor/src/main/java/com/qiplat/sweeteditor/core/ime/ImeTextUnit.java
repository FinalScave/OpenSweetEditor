package com.qiplat.sweeteditor.core.ime;

public enum ImeTextUnit {
    GRAPHEME(0),
    CODE_POINT(1);

    public final int value;

    ImeTextUnit(int value) {
        this.value = value;
    }

    public static ImeTextUnit fromValue(int value) {
        switch (value) {
            case 0: return GRAPHEME;
            case 1: return CODE_POINT;
            default: return GRAPHEME;
        }
    }
}
