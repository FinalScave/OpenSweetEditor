package com.qiplat.sweeteditor.core.interaction;

public enum EventType {
    UNDEFINED(0),
    TOUCH_DOWN(1),
    TOUCH_POINTER_DOWN(2),
    TOUCH_MOVE(3),
    TOUCH_POINTER_UP(4),
    TOUCH_UP(5),
    TOUCH_CANCEL(6),
    MOUSE_DOWN(7),
    MOUSE_MOVE(8),
    MOUSE_UP(9),
    MOUSE_WHEEL(10),
    MOUSE_RIGHT_DOWN(11),
    DIRECT_SCALE(12),
    DIRECT_SCROLL(13),
    DIRECT_GESTURE_BEGIN(14),
    DIRECT_GESTURE_END(15);

    public final int value;

    EventType(int value) {
        this.value = value;
    }

    public static EventType fromValue(int value) {
        switch (value) {
            case 0: return UNDEFINED;
            case 1: return TOUCH_DOWN;
            case 2: return TOUCH_POINTER_DOWN;
            case 3: return TOUCH_MOVE;
            case 4: return TOUCH_POINTER_UP;
            case 5: return TOUCH_UP;
            case 6: return TOUCH_CANCEL;
            case 7: return MOUSE_DOWN;
            case 8: return MOUSE_MOVE;
            case 9: return MOUSE_UP;
            case 10: return MOUSE_WHEEL;
            case 11: return MOUSE_RIGHT_DOWN;
            case 12: return DIRECT_SCALE;
            case 13: return DIRECT_SCROLL;
            case 14: return DIRECT_GESTURE_BEGIN;
            case 15: return DIRECT_GESTURE_END;
            default: throw new IllegalArgumentException("Unknown EventType value: " + value);
        }
    }
}
