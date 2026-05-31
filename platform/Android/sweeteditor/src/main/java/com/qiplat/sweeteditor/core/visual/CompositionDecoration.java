package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Rect;

public final class CompositionDecoration {
    public boolean active = false;
    public Rect rect = new Rect();

    public CompositionDecoration() {
    }

    public CompositionDecoration(boolean active, Rect rect) {
        this.active = active;
        this.rect = rect;
    }
}
