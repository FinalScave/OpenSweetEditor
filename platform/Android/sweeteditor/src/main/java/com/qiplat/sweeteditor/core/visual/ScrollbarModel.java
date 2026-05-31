package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Rect;

public final class ScrollbarModel {
    public boolean visible = false;
    public float alpha = 0f;
    public boolean thumbActive = false;
    public Rect track = new Rect();
    public Rect thumb = new Rect();

    public ScrollbarModel() {
    }

    public ScrollbarModel(boolean visible, float alpha, boolean thumbActive, Rect track, Rect thumb) {
        this.visible = visible;
        this.alpha = alpha;
        this.thumbActive = thumbActive;
        this.track = track;
        this.thumb = thumb;
    }
}
