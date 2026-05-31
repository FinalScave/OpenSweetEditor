package com.qiplat.sweeteditor.core.ime;

public enum ImeInputContextKind {
    NONE(0),
    SELECTION_ONLY(1),
    DOCUMENT_WINDOW(2),
    TRANSIENT_INPUT(3);

    public final int value;

    ImeInputContextKind(int value) {
        this.value = value;
    }

    public static ImeInputContextKind fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return SELECTION_ONLY;
            case 2: return DOCUMENT_WINDOW;
            case 3: return TRANSIENT_INPUT;
            default: return NONE;
        }
    }
}
