package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Rect;

public final class DiagnosticDecoration {
    public Rect rect = new Rect();
    public int severity = 0;

    public DiagnosticDecoration() {
    }

    public DiagnosticDecoration(Rect rect, int severity) {
        this.rect = rect;
        this.severity = severity;
    }
}
