package com.qiplat.sweeteditor.core.ime;

public enum ImeCoordinateSpace {
    DOCUMENT(0),
    EDITING_BUFFER(1),
    CONTEXT_SLICE(2),
    COMPOSITION(3);

    public final int value;

    ImeCoordinateSpace(int value) {
        this.value = value;
    }

    public static ImeCoordinateSpace fromValue(int value) {
        switch (value) {
            case 0: return DOCUMENT;
            case 1: return EDITING_BUFFER;
            case 2: return CONTEXT_SLICE;
            case 3: return COMPOSITION;
            default: throw new IllegalArgumentException("Unknown ImeCoordinateSpace value: " + value);
        }
    }
}
