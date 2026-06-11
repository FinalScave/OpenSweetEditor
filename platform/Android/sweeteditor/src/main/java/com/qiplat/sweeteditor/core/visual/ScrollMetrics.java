package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.Size;

public final class ScrollMetrics {
    public float scale = 1f;
    public float scrollX = 0f;
    public float scrollY = 0f;
    public float maxScrollX = 0f;
    public float maxScrollY = 0f;
    public Size contentSize = new Size();
    public Size viewportSize = new Size();
    public float textAreaX = 0f;
    public float textAreaWidth = 0f;
    public boolean canScrollX = false;
    public boolean canScrollY = false;

    public ScrollMetrics() {
    }

    public ScrollMetrics(float scale, float scrollX, float scrollY, float maxScrollX, float maxScrollY, Size contentSize, Size viewportSize, float textAreaX, float textAreaWidth, boolean canScrollX, boolean canScrollY) {
        this.scale = scale;
        this.scrollX = scrollX;
        this.scrollY = scrollY;
        this.maxScrollX = maxScrollX;
        this.maxScrollY = maxScrollY;
        this.contentSize = contentSize;
        this.viewportSize = viewportSize;
        this.textAreaX = textAreaX;
        this.textAreaWidth = textAreaWidth;
        this.canScrollX = canScrollX;
        this.canScrollY = canScrollY;
    }
}
