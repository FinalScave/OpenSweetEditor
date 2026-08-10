package com.qiplat.sweeteditor.core.visual;

public enum VisualLineKind {
    CONTENT(0),
    PHANTOM(1),
    CODELENS(2),
    REMOVED(3);

    public final int value;

    VisualLineKind(int value) {
        this.value = value;
    }

    public static VisualLineKind fromValue(int value) {
        switch (value) {
            case 0: return CONTENT;
            case 1: return PHANTOM;
            case 2: return CODELENS;
            case 3: return REMOVED;
            default: throw new IllegalArgumentException("Unknown VisualLineKind value: " + value);
        }
    }
}
