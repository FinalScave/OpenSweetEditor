package com.qiplat.sweeteditor.core.adornment;

import java.util.List;

public final class DiffChange {
    public int currentStartLine = 0;
    public int currentLineCount = 0;
    public int originalStartLine = 0;
    public java.util.List<String> removedLines = new java.util.ArrayList<>();

    public DiffChange() {
    }

    public DiffChange(int currentStartLine, int currentLineCount, int originalStartLine, java.util.List<String> removedLines) {
        this.currentStartLine = currentStartLine;
        this.currentLineCount = currentLineCount;
        this.originalStartLine = originalStartLine;
        this.removedLines = removedLines;
    }
}
