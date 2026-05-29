package com.qiplat.sweeteditor.core.visual;

public enum FoldState {
    NONE(0),
    EXPANDED(1),
    COLLAPSED(2);

    public final int value;

    FoldState(int value) {
        this.value = value;
    }

    public static FoldState fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return EXPANDED;
            case 2: return COLLAPSED;
            default: return NONE;
        }
    }
}
