package com.qiplat.sweeteditor.core.adornment;

/**
 * Inlay hint type enumeration.
 */
public enum InlayType {
    TEXT(0),
    ICON(1),
    COLOR(2);

    public final int value;

    InlayType(int value) {
        this.value = value;
    }

    public static InlayType fromValue(int value) {
        for (InlayType type : values()) {
            if (type.value == value) {
                return type;
            }
        }
        return TEXT;
    }
}
