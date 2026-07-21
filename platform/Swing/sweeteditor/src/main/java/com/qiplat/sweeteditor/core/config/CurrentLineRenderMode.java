package com.qiplat.sweeteditor.core.config;

public enum CurrentLineRenderMode {
    BACKGROUND(0),
    BORDER(1),
    NONE(2);

    public final int value;

    CurrentLineRenderMode(int value) {
        this.value = value;
    }

    public static CurrentLineRenderMode fromValue(int value) {
        switch (value) {
            case 0: return BACKGROUND;
            case 1: return BORDER;
            case 2: return NONE;
            default: throw new IllegalArgumentException("Unknown CurrentLineRenderMode value: " + value);
        }
    }
}
