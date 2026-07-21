package com.qiplat.sweeteditor.core.search;

public enum SearchStatus {
    INACTIVE(0),
    SEARCHING(1),
    READY(2),
    STALE(3),
    FAILED(4);

    public final int value;

    SearchStatus(int value) {
        this.value = value;
    }

    public static SearchStatus fromValue(int value) {
        switch (value) {
            case 0: return INACTIVE;
            case 1: return SEARCHING;
            case 2: return READY;
            case 3: return STALE;
            case 4: return FAILED;
            default: throw new IllegalArgumentException("Unknown SearchStatus value: " + value);
        }
    }
}
