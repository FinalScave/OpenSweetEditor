package com.qiplat.sweeteditor.core.visual;

public enum GuideType {
    INDENT(0),
    BRACKET(1),
    FLOW(2),
    SEPARATOR(3);

    public final int value;

    GuideType(int v) { value = v; }

    public static GuideType fromValue(int v) {
        for (GuideType e : values()) if (e.value == v) return e;
        return INDENT;
    }
}
