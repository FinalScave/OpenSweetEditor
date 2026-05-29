package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Rect;

public final class GutterIconRenderItem {
    public int logicalLine = 0;
    public int iconId = 0;
    public Rect rect = new Rect();

    public GutterIconRenderItem() {
    }

    public GutterIconRenderItem(int logicalLine, int iconId, Rect rect) {
        this.logicalLine = logicalLine;
        this.iconId = iconId;
        this.rect = rect;
    }
}
