package com.qiplat.sweeteditor.core.ime;

public enum ImeCommandKind {
    SET_SELECTION(0),
    BEGIN_COMPOSITION(1),
    UPDATE_COMPOSITION(2),
    COMMIT_TEXT(3),
    FINISH_COMPOSITION(4),
    CANCEL_COMPOSITION(5),
    DELETE_SURROUNDING(6);

    public final int value;

    ImeCommandKind(int value) {
        this.value = value;
    }

    public static ImeCommandKind fromValue(int value) {
        switch (value) {
            case 0: return SET_SELECTION;
            case 1: return BEGIN_COMPOSITION;
            case 2: return UPDATE_COMPOSITION;
            case 3: return COMMIT_TEXT;
            case 4: return FINISH_COMPOSITION;
            case 5: return CANCEL_COMPOSITION;
            case 6: return DELETE_SURROUNDING;
            default: throw new IllegalArgumentException("Unknown ImeCommandKind value: " + value);
        }
    }
}
