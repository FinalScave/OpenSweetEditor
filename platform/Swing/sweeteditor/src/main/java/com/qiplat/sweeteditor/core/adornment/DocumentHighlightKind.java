package com.qiplat.sweeteditor.core.adornment;

public enum DocumentHighlightKind {
    TEXT(0),
    READ(1),
    WRITE(2);

    public final int value;

    DocumentHighlightKind(int value) {
        this.value = value;
    }

    public static DocumentHighlightKind fromValue(int value) {
        switch (value) {
            case 0: return TEXT;
            case 1: return READ;
            case 2: return WRITE;
            default: throw new IllegalArgumentException("Unknown DocumentHighlightKind value: " + value);
        }
    }
}
