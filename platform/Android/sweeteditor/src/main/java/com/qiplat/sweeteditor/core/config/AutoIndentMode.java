package com.qiplat.sweeteditor.core.config;

public enum AutoIndentMode {
    NONE(0),
    KEEP_INDENT(1);

    public final int value;

    AutoIndentMode(int value) {
        this.value = value;
    }

    public static AutoIndentMode fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return KEEP_INDENT;
            default: throw new IllegalArgumentException("Unknown AutoIndentMode value: " + value);
        }
    }
}
