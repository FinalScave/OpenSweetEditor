package com.qiplat.sweeteditor.core.foundation;

public final class Rect {
    public PointF origin = new PointF();
    public float width = 0f;
    public float height = 0f;

    public Rect() {
    }

    public Rect(PointF origin, float width, float height) {
        this.origin = origin;
        this.width = width;
        this.height = height;
    }
}
