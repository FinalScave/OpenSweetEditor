package com.qiplat.sweeteditor.core.adornment;

public final class Diagnostic {
    public int column = 0;
    public int length = 0;
    public DiagnosticSeverity severity = DiagnosticSeverity.DIAG_ERROR;

    public Diagnostic() {
    }

    public Diagnostic(int column, int length, DiagnosticSeverity severity) {
        this.column = column;
        this.length = length;
        this.severity = severity;
    }

    public Diagnostic(int column, int length, int severity) {
        this(column, length, DiagnosticSeverity.fromValue(severity));
    }
}
