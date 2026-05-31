package com.qiplat.sweeteditor.core.adornment;

public enum SeparatorStyle {
    SINGLE(0),
    DOUBLE(1);

    public final int value;

    SeparatorStyle(int value) {
        this.value = value;
    }

    public static SeparatorStyle fromValue(int value) {
        switch (value) {
            case 0: return SINGLE;
            case 1: return DOUBLE;
            default: return SINGLE;
        }
    }
}
