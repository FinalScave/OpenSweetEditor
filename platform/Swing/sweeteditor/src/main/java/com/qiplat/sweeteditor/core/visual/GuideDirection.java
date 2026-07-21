package com.qiplat.sweeteditor.core.visual;

public enum GuideDirection {
    VERTICAL(0),
    HORIZONTAL(1);

    public final int value;

    GuideDirection(int value) {
        this.value = value;
    }

    public static GuideDirection fromValue(int value) {
        switch (value) {
            case 0: return VERTICAL;
            case 1: return HORIZONTAL;
            default: throw new IllegalArgumentException("Unknown GuideDirection value: " + value);
        }
    }
}
