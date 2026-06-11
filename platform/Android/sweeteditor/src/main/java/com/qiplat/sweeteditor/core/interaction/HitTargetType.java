package com.qiplat.sweeteditor.core.interaction;

public enum HitTargetType {
    NONE(0),
    INLAY_HINT_TEXT(1),
    INLAY_HINT_ICON(2),
    INLAY_HINT_COLOR(3),
    CODELENS(4),
    LINK(5),
    GUTTER_ICON(6),
    FOLD_GUTTER(7),
    FOLD_PLACEHOLDER(8);

    public final int value;

    HitTargetType(int value) {
        this.value = value;
    }

    public static HitTargetType fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return INLAY_HINT_TEXT;
            case 2: return INLAY_HINT_ICON;
            case 3: return INLAY_HINT_COLOR;
            case 4: return CODELENS;
            case 5: return LINK;
            case 6: return GUTTER_ICON;
            case 7: return FOLD_GUTTER;
            case 8: return FOLD_PLACEHOLDER;
            default: return NONE;
        }
    }
}
