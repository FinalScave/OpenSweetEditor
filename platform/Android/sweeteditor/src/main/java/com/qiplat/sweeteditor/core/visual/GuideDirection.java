package com.qiplat.sweeteditor.core.visual;

public enum GuideDirection {
    HORIZONTAL(0),
    VERTICAL(1);

    public final int value;

    GuideDirection(int value) {
        this.value = value;
    }

    public static GuideDirection fromValue(int value) {
        switch (value) {
            case 0: return HORIZONTAL;
            case 1: return VERTICAL;
            default: return VERTICAL;
        }
    }
}
