package com.qiplat.sweeteditor.core.visual;

public enum VisualLineKind {
    CONTENT(0),
    PHANTOM(1),
    CODELENS(2);

    public final int value;

    VisualLineKind(int v) { value = v; }

    public static VisualLineKind fromValue(int v) {
        for (VisualLineKind e : values()) if (e.value == v) return e;
        return CONTENT;
    }
}
