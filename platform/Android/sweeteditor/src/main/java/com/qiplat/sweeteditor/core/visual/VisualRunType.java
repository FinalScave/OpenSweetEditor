package com.qiplat.sweeteditor.core.visual;

public enum VisualRunType {
    TEXT(0),
    WHITESPACE(1),
    TAB(2),
    NEWLINE(3),
    INLAY_HINT(4),
    PHANTOM_TEXT(5),
    FOLD_PLACEHOLDER(6),
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
            case 2: return TAB;
            case 3: return NEWLINE;
            case 4: return INLAY_HINT;
            case 5: return PHANTOM_TEXT;
            case 6: return FOLD_PLACEHOLDER;
            case 7: return CODELENS;
            case 8: return LINK;
            default: throw new IllegalArgumentException("Unknown VisualRunType value: " + value);
        }
    }
}
