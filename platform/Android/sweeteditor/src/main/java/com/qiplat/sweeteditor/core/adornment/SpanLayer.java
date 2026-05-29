package com.qiplat.sweeteditor.core.adornment;

public enum SpanLayer {
    SYNTAX(0),
    SEMANTIC(1);

    public final int value;

    SpanLayer(int value) {
        this.value = value;
    }

    public static SpanLayer fromValue(int value) {
        switch (value) {
            case 0: return SYNTAX;
            case 1: return SEMANTIC;
            default: return SYNTAX;
        }
    }
}
