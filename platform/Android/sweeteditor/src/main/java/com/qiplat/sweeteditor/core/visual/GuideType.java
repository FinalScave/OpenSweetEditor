package com.qiplat.sweeteditor.core.visual;

public enum GuideType {
    INDENT(0),
    BRACKET(1),
    FLOW(2),
    SEPARATOR(3);

    public final int value;

    GuideType(int value) {
        this.value = value;
    }

    public static GuideType fromValue(int value) {
        switch (value) {
            case 0: return INDENT;
            case 1: return BRACKET;
            case 2: return FLOW;
            case 3: return SEPARATOR;
            default: return INDENT;
        }
    }
}
