package com.qiplat.sweeteditor.core.config;

public enum WhitespaceRenderMode {
    NONE(0),
    BOUNDARY(1),
    SELECTION(2),
    TRAILING(3),
    ALL(4);

    public final int value;

    WhitespaceRenderMode(int value) {
        this.value = value;
    }

    public static WhitespaceRenderMode fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return BOUNDARY;
            case 2: return SELECTION;
            case 3: return TRAILING;
            case 4: return ALL;
            default: throw new IllegalArgumentException("Unknown WhitespaceRenderMode value: " + value);
        }
    }
}
