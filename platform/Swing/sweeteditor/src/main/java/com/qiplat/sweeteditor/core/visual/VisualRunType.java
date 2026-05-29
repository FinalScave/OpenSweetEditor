package com.qiplat.sweeteditor.core.visual;

public enum VisualRunType {
    TEXT(0),
    WHITESPACE(1),
    NEWLINE(2),
    INLAY_HINT(3),
    PHANTOM_TEXT(4),
    FOLD_PLACEHOLDER(5),
    TAB(6),
    CODELENS(7),
    LINK(8);

    public final int value;

    VisualRunType(int value) {
        this.value = value;
    }

    public static VisualRunType fromValue(int value) {
        switch (value) {
            case 0: return TEXT;
            case 1: return WHITESPACE;
            case 2: return NEWLINE;
            case 3: return INLAY_HINT;
            case 4: return PHANTOM_TEXT;
            case 5: return FOLD_PLACEHOLDER;
            case 6: return TAB;
            case 7: return CODELENS;
            case 8: return LINK;
            default: return TEXT;
        }
    }
}
