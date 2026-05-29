package com.qiplat.sweeteditor.core.ime;

public enum ImeScriptClass {
    UNKNOWN(0),
    LATIN(1),
    CJK(2),
    KANA(3),
    HANGUL(4);

    public final int value;

    ImeScriptClass(int value) {
        this.value = value;
    }

    public static ImeScriptClass fromValue(int value) {
        switch (value) {
            case 0: return UNKNOWN;
            case 1: return LATIN;
            case 2: return CJK;
            case 3: return KANA;
            case 4: return HANGUL;
            default: return UNKNOWN;
        }
    }
}
