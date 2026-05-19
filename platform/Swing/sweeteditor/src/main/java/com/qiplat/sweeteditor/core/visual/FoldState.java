package com.qiplat.sweeteditor.core.visual;

public enum FoldState {
    NONE(0),
    EXPANDED(1),
    COLLAPSED(2);

    public final int value;

    FoldState(int v) { value = v; }

    public static FoldState fromValue(int v) {
        for (FoldState e : values()) if (e.value == v) return e;
        return NONE;
    }
}
