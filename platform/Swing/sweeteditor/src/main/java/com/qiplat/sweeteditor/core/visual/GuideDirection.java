package com.qiplat.sweeteditor.core.visual;

public enum GuideDirection {
    HORIZONTAL(0),
    VERTICAL(1);

    public final int value;

    GuideDirection(int v) { value = v; }

    public static GuideDirection fromValue(int v) {
        for (GuideDirection e : values()) if (e.value == v) return e;
        return HORIZONTAL;
    }
}
