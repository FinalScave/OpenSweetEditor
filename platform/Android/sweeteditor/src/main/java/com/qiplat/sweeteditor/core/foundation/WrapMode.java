package com.qiplat.sweeteditor.core.foundation;

public enum WrapMode {
    NONE(0),
    CHAR_BREAK(1),
    WORD_BREAK(2);

    public final int value;

    WrapMode(int value) {
        this.value = value;
    }
}
