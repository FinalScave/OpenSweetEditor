package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing diagnostic information (error, warning, hint, etc.) on a single line.
 */
public final class DiagnosticItem {
    /** Starting column (0-based, UTF-16 offset) */
    public final int column;
    /** Character length */
    public final int length;
    /** Severity (0=error, 1=warning, 2=info, 3=hint) */
    public final int severity;
    /** Underline/marker color (ARGB) */
    public final int color;

    public DiagnosticItem(int column, int length, int severity, int color) {
        this.column = column;
        this.length = length;
        this.severity = severity;
        this.color = color;
    }
}
