package com.qiplat.sweeteditor.core.adornment;

public enum InlayType {
    TEXT(0),
    ICON(1),
    COLOR(2);

    public final int value;

    InlayType(int value) {
        this.value = value;
    }

    public static InlayType fromValue(int value) {
        switch (value) {
            case 0: return TEXT;
            case 1: return ICON;
            case 2: return COLOR;
            default: return TEXT;
        }
    }
}
