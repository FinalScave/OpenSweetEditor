package com.qiplat.sweeteditor.core.interaction;

public enum HitTargetType {
    NONE(0),
    INLAY_HINT_TEXT(1),
    INLAY_HINT_ICON(2),
    GUTTER_ICON(3),
    FOLD_PLACEHOLDER(4),
    FOLD_GUTTER(5),
    INLAY_HINT_COLOR(6),
    CODELENS(7),
    LINK(8);

    public final int value;

    HitTargetType(int value) {
        this.value = value;
    }

    public static HitTargetType fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return INLAY_HINT_TEXT;
            case 2: return INLAY_HINT_ICON;
            case 3: return GUTTER_ICON;
            case 4: return FOLD_PLACEHOLDER;
            case 5: return FOLD_GUTTER;
            case 6: return INLAY_HINT_COLOR;
            case 7: return CODELENS;
            case 8: return LINK;
            default: return NONE;
        }
    }
}
