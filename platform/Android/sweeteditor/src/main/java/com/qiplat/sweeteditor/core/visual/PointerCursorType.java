package com.qiplat.sweeteditor.core.visual;

public enum PointerCursorType {
    DEFAULT(0),
    TEXT(1),
    HAND(2);

    public final int value;

    PointerCursorType(int value) {
        this.value = value;
    }

    public static PointerCursorType fromValue(int value) {
        switch (value) {
            case 0: return DEFAULT;
            case 1: return TEXT;
            case 2: return HAND;
            default: return DEFAULT;
        }
    }
}
