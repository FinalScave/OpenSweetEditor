package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing diagnostic information (error, warning, hint, etc.) on a single line.
 * <p>
 * Each Diagnostic represents a diagnostic marker on a contiguous text segment,
 * including the starting column, character length, severity, and color information.
 */
public final class Diagnostic {
    /** Starting column (0-based, UTF-16 offset) */
    public final int column;
    /** Character length */
    public final int length;
    /** Severity (0=error, 1=warning, 2=info, 3=hint) */
    public final int severity;
    /** Underline/marker color (ARGB) */
    public final int color;

    /**
     * @param column   Starting column (0-based, UTF-16 offset)
     * @param length   Character length
     * @param severity Severity level
     * @param color    Underline/marker color (ARGB)
     */
    public Diagnostic(int column, int length, int severity, int color) {
        this.column = column;
        this.length = length;
        this.severity = severity;
        this.color = color;
    }
}
