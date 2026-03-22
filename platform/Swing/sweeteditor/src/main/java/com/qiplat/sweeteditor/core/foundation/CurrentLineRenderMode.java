package com.qiplat.sweeteditor.core.foundation;

public enum CurrentLineRenderMode {
    BACKGROUND(0),
    BORDER(1),
    NONE(2);

    public final int value;

    CurrentLineRenderMode(int value) {
        this.value = value;
    }
}

