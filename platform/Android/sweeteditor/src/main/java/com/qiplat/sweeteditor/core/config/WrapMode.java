package com.qiplat.sweeteditor.core.config;

public enum WrapMode {
    NONE(0),
    CHAR_BREAK(1),
    WORD_BREAK(2);

    public final int value;

    WrapMode(int value) {
        this.value = value;
    }

    public static WrapMode fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return CHAR_BREAK;
            case 2: return WORD_BREAK;
            default: throw new IllegalArgumentException("Unknown WrapMode value: " + value);
        }
    }
}
