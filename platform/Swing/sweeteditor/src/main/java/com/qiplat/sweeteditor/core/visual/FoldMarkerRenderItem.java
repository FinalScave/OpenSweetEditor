package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Rect;

public final class FoldMarkerRenderItem {
    public int logicalLine = 0;
    public FoldState foldState = FoldState.NONE;
    public Rect rect = new Rect();

    public FoldMarkerRenderItem() {
    }

    public FoldMarkerRenderItem(int logicalLine, FoldState foldState, Rect rect) {
        this.logicalLine = logicalLine;
        this.foldState = foldState;
        this.rect = rect;
    }
}
