package com.qiplat.sweeteditor.core.ime;

public enum ImeContextPolicy {
    NONE(0),
    LIMITED_FOR_CANDIDATES(1);

    public final int value;

    ImeContextPolicy(int value) {
        this.value = value;
    }

    public static ImeContextPolicy fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return LIMITED_FOR_CANDIDATES;
            default: return NONE;
        }
    }
}
