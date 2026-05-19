package com.qiplat.sweeteditor.core.visual;

public enum GuideStyle {
    SOLID(0),
    DASHED(1),
    DOUBLE(2);

    public final int value;

    GuideStyle(int v) { value = v; }

    public static GuideStyle fromValue(int v) {
        for (GuideStyle e : values()) if (e.value == v) return e;
        return SOLID;
    }
}
