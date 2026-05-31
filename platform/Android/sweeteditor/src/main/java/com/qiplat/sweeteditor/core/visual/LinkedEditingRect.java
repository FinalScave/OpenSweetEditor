package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Rect;

public final class LinkedEditingRect {
    public Rect rect = new Rect();
    public boolean isActive = false;

    public LinkedEditingRect() {
    }

    public LinkedEditingRect(Rect rect, boolean isActive) {
        this.rect = rect;
        this.isActive = isActive;
    }
}
