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

    VisualRunType(int v) { value = v; }

    public static VisualRunType fromValue(int v) {
        for (VisualRunType e : values()) if (e.value == v) return e;
        return TEXT;
    }
}
