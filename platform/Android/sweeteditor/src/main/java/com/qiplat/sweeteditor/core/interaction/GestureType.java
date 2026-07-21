package com.qiplat.sweeteditor.core.interaction;

public enum GestureType {
    UNDEFINED(0),
    TAP(1),
    DOUBLE_TAP(2),
    LONG_PRESS(3),
    SCALE(4),
    SCROLL(5),
    FAST_SCROLL(6),
    DRAG_SELECT(7),
    CONTEXT_MENU(8);

    public final int value;

    GestureType(int value) {
        this.value = value;
    }

    public static GestureType fromValue(int value) {
        switch (value) {
            case 0: return UNDEFINED;
            case 1: return TAP;
            case 2: return DOUBLE_TAP;
            case 3: return LONG_PRESS;
            case 4: return SCALE;
            case 5: return SCROLL;
            case 6: return FAST_SCROLL;
            case 7: return DRAG_SELECT;
            case 8: return CONTEXT_MENU;
            default: throw new IllegalArgumentException("Unknown GestureType value: " + value);
        }
    }
}
