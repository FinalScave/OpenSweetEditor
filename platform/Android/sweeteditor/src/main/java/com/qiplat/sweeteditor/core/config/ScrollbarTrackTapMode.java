package com.qiplat.sweeteditor.core.config;

public enum ScrollbarTrackTapMode {
    JUMP(0),
    DISABLED(1);

    public final int value;

    ScrollbarTrackTapMode(int value) {
        this.value = value;
    }

    public static ScrollbarTrackTapMode fromValue(int value) {
        switch (value) {
            case 0: return JUMP;
            case 1: return DISABLED;
            default: throw new IllegalArgumentException("Unknown ScrollbarTrackTapMode value: " + value);
        }
    }
}
