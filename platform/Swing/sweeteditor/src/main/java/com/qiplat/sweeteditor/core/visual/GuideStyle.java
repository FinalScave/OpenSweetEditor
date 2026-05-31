package com.qiplat.sweeteditor.core.visual;

public enum GuideStyle {
    SOLID(0),
    DASHED(1),
    DOUBLE(2);

    public final int value;

    GuideStyle(int value) {
        this.value = value;
    }

    public static GuideStyle fromValue(int value) {
        switch (value) {
            case 0: return SOLID;
            case 1: return DASHED;
            case 2: return DOUBLE;
            default: return SOLID;
        }
    }
}
