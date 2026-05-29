package com.qiplat.sweeteditor.core.ime;

public enum ImeTextModelMode {
    DOCUMENT_WINDOW(0),
    TRANSIENT_INPUT(1);

    public final int value;

    ImeTextModelMode(int value) {
        this.value = value;
    }

    public static ImeTextModelMode fromValue(int value) {
        switch (value) {
            case 0: return DOCUMENT_WINDOW;
            case 1: return TRANSIENT_INPUT;
            default: return DOCUMENT_WINDOW;
        }
    }
}
