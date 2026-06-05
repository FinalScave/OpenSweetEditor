package com.qiplat.sweeteditor.core.action;

public enum EditorActionReason {
    NONE(0),
    SETUP(1),
    TEXT_EDIT(2),
    KEY_INPUT(3),
    IME(4),
    GESTURE(5),
    ANIMATION(6),
    PROGRAMMATIC(7),
    DECORATION(8),
    FOLDING(9),
    LINKED_EDITING(10),
    TEXT_INSERT(11),
    TEXT_REPLACE(12),
    TEXT_DELETE(13),
    TEXT_UNDO(14),
    TEXT_REDO(15),
    SEARCH(16);

    public final int value;

    EditorActionReason(int value) {
        this.value = value;
    }

    public static EditorActionReason fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return SETUP;
            case 2: return TEXT_EDIT;
            case 3: return KEY_INPUT;
            case 4: return IME;
            case 5: return GESTURE;
            case 6: return ANIMATION;
            case 7: return PROGRAMMATIC;
            case 8: return DECORATION;
            case 9: return FOLDING;
            case 10: return LINKED_EDITING;
            case 11: return TEXT_INSERT;
            case 12: return TEXT_REPLACE;
            case 13: return TEXT_DELETE;
            case 14: return TEXT_UNDO;
            case 15: return TEXT_REDO;
            case 16: return SEARCH;
            default: return NONE;
        }
    }
}
