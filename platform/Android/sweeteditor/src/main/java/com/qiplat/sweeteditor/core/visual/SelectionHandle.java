package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.PointF;

public final class SelectionHandle {
    public PointF position = new PointF();
    public float height = 0f;
    public boolean visible = false;

    public SelectionHandle() {
    }

    public SelectionHandle(PointF position, float height, boolean visible) {
        this.position = position;
        this.height = height;
        this.visible = visible;
    }
}
