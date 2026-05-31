package com.qiplat.sweeteditor.core.adornment;

public final class FoldRegion {
    public int startLine = 0;
    public int endLine = 0;
    public boolean collapsed = false;

    public FoldRegion() {
    }

    public FoldRegion(int startLine, int endLine, boolean collapsed) {
        this.startLine = startLine;
        this.endLine = endLine;
        this.collapsed = collapsed;
    }

    public FoldRegion(int startLine, int endLine) {
        this(startLine, endLine, false);
    }
}
