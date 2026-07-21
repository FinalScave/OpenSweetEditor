package com.qiplat.sweeteditor.core.action;

public enum TextChangeKind {
    NONE(0),
    INSERTION(1),
    REPLACEMENT(2),
    DELETION(3),
    MOVE(4),
    UNDO(5),
    REDO(6),
    MIXED(7);

    public final int value;

    TextChangeKind(int value) {
        this.value = value;
    }

    public static TextChangeKind fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return INSERTION;
            case 2: return REPLACEMENT;
            case 3: return DELETION;
            case 4: return MOVE;
            case 5: return UNDO;
            case 6: return REDO;
            case 7: return MIXED;
            default: throw new IllegalArgumentException("Unknown TextChangeKind value: " + value);
        }
    }
}
