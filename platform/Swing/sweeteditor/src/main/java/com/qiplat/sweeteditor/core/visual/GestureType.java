package com.qiplat.sweeteditor.core.visual;

/**
 * Gesture result type (aligned with C++ GestureType).
 * <p>Gson deserializes JSON strings directly by enum name.</p>
 */
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

    GestureType(int v) { value = v; }

    public static GestureType fromValue(int v) {
        for (GestureType e : values()) if (e.value == v) return e;
        return UNDEFINED;
    }
}
