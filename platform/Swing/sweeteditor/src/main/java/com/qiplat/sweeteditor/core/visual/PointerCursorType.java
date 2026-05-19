package com.qiplat.sweeteditor.core.visual;

/**
 * Pointer cursor type hint returned by the core.
 */
public enum PointerCursorType {
    DEFAULT(0),
    TEXT(1),
    HAND(2);

    public final int value;

    PointerCursorType(int v) { value = v; }

    public static PointerCursorType fromValue(int v) {
        for (PointerCursorType e : values()) if (e.value == v) return e;
        return TEXT;
    }
}
