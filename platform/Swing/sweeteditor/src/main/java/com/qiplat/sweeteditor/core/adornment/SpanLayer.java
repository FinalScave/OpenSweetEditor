package com.qiplat.sweeteditor.core.adornment;

public enum SpanLayer {
    SYNTAX(0),
    SEMANTIC(1),
    OVERLAY(2);

    public final int value;

    SpanLayer(int value) {
        this.value = value;
    }

    public static SpanLayer fromValue(int value) {
        switch (value) {
            case 0: return SYNTAX;
            case 1: return SEMANTIC;
            case 2: return OVERLAY;
            default: throw new IllegalArgumentException("Unknown SpanLayer value: " + value);
        }
    }
}
