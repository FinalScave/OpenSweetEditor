package com.qiplat.sweeteditor.core.ime;

public enum ImePreeditStorage {
    NONE(0),
    VISIBLE_DOCUMENT_PREEDIT(1),
    SHADOW_ONLY(2);

    public final int value;

    ImePreeditStorage(int value) {
        this.value = value;
    }

    public static ImePreeditStorage fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return VISIBLE_DOCUMENT_PREEDIT;
            case 2: return SHADOW_ONLY;
            default: return NONE;
        }
    }
}
