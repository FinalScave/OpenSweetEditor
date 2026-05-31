package com.qiplat.sweeteditor.core.visual;

public final class CursorRect {
    public float x = 0f;
    public float y = 0f;
    public float height = 0f;

    public CursorRect() {
    }

    public CursorRect(float x, float y, float height) {
        this.x = x;
        this.y = y;
        this.height = height;
    }

    @Override
    public String toString() {
        return "CursorRect{"
                + "x=" + x
                + ", y=" + y
                + ", height=" + height
                + "}";
    }
}
