package com.qiplat.sweeteditor.core.adornment;

public enum SpanLayer {
    SYNTAX(0),
    SEMANTIC(1);

    public final int value;

    SpanLayer(int value) {
        this.value = value;
    }
}
