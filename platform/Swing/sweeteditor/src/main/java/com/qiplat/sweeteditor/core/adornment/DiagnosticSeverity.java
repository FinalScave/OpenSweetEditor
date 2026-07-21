package com.qiplat.sweeteditor.core.adornment;

public enum DiagnosticSeverity {
    DIAG_ERROR(0),
    DIAG_WARNING(1),
    DIAG_INFO(2),
    DIAG_HINT(3);

    public final int value;

    DiagnosticSeverity(int value) {
        this.value = value;
    }

    public static DiagnosticSeverity fromValue(int value) {
        switch (value) {
            case 0: return DIAG_ERROR;
            case 1: return DIAG_WARNING;
            case 2: return DIAG_INFO;
            case 3: return DIAG_HINT;
            default: throw new IllegalArgumentException("Unknown DiagnosticSeverity value: " + value);
        }
    }
}
