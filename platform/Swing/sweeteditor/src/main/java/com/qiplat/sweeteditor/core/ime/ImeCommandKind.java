package com.qiplat.sweeteditor.core.ime;

public enum ImeCommandKind {
    SET_SELECTION(0),
    SET_PREEDIT_TEXT(1),
    COMMIT_TEXT(2),
    FINISH_PREEDIT(3),
    CANCEL_PREEDIT(4),
    SET_MARKED_RANGE(5),
    CLEAR_MARKED_RANGE(6),
    REPLACE_TEXT(7),
    DELETE_SURROUNDING_TEXT(8),
    SET_KEYBOARD_SCRIPT(9);

    public final int value;

    ImeCommandKind(int value) {
        this.value = value;
    }

    public static ImeCommandKind fromValue(int value) {
        switch (value) {
            case 0: return SET_SELECTION;
            case 1: return SET_PREEDIT_TEXT;
            case 2: return COMMIT_TEXT;
            case 3: return FINISH_PREEDIT;
            case 4: return CANCEL_PREEDIT;
            case 5: return SET_MARKED_RANGE;
            case 6: return CLEAR_MARKED_RANGE;
            case 7: return REPLACE_TEXT;
            case 8: return DELETE_SURROUNDING_TEXT;
            case 9: return SET_KEYBOARD_SCRIPT;
            default: return SET_SELECTION;
        }
    }
}
