package com.qiplat.sweeteditor.core.config;

public enum RangeEffectUnderlineStyle {
    NONE(0),
    SOLID(1),
    DASHED(2),
    WAVY(3);

    public final int value;

    RangeEffectUnderlineStyle(int value) {
        this.value = value;
    }

    public static RangeEffectUnderlineStyle fromValue(int value) {
        switch (value) {
            case 0: return NONE;
            case 1: return SOLID;
            case 2: return DASHED;
            case 3: return WAVY;
            default: throw new IllegalArgumentException("Unknown RangeEffectUnderlineStyle value: " + value);
        }
    }
}
