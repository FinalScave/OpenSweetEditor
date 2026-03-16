package com.qiplat.sweeteditor.core.visual;

/**
 * Gesture result type (aligned with C++ GestureType).
 * <p>Gson deserializes JSON strings directly by enum name.</p>
 */
public enum GestureType {
    UNDEFINED,
    TAP,
    DOUBLE_TAP,
    LONG_PRESS,
    SCALE,
    SCROLL,
    FAST_SCROLL,
    DRAG_SELECT,
    CONTEXT_MENU
}
