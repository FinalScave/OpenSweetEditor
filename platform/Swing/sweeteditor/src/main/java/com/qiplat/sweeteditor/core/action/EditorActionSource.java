package com.qiplat.sweeteditor.core.action;

public enum EditorActionSource {
    NONE(0),
    SETUP(1),
    PROGRAMMATIC(2),
    KEYBOARD(3),
    IME(4),
    GESTURE(5),
    ANIMATION(6),
    DECORATION(7),
    FOLDING(8),
    SEARCH(9),
    LINKED_EDITING(10);

    public final int value;

    EditorActionSource(int value) {
        this.value = value;
    }

    public static EditorActionSource fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return SETUP;
            case 2: return PROGRAMMATIC;
            case 3: return KEYBOARD;
            case 4: return IME;
            case 5: return GESTURE;
            case 6: return ANIMATION;
            case 7: return DECORATION;
            case 8: return FOLDING;
            case 9: return SEARCH;
            case 10: return LINKED_EDITING;
            default: throw new IllegalArgumentException("Unknown EditorActionSource value: " + value);
        }
    }
}
