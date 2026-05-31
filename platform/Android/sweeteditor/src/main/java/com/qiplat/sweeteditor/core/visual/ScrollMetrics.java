package com.qiplat.sweeteditor.core.visual;

public final class ScrollMetrics {
    public float scale = 1f;
    public float scrollX = 0f;
    public float scrollY = 0f;
    public float maxScrollX = 0f;
    public float maxScrollY = 0f;
    public float contentWidth = 0f;
    public float contentHeight = 0f;
    public float viewportWidth = 0f;
    public float viewportHeight = 0f;
    public float textAreaX = 0f;
    public float textAreaWidth = 0f;
    public boolean canScrollX = false;
    public boolean canScrollY = false;

    public ScrollMetrics() {
    }

    public ScrollMetrics(float scale, float scrollX, float scrollY, float maxScrollX, float maxScrollY, float contentWidth, float contentHeight, float viewportWidth, float viewportHeight, float textAreaX, float textAreaWidth, boolean canScrollX, boolean canScrollY) {
        this.scale = scale;
        this.scrollX = scrollX;
        this.scrollY = scrollY;
        this.maxScrollX = maxScrollX;
        this.maxScrollY = maxScrollY;
        this.contentWidth = contentWidth;
        this.contentHeight = contentHeight;
        this.viewportWidth = viewportWidth;
        this.viewportHeight = viewportHeight;
        this.textAreaX = textAreaX;
        this.textAreaWidth = textAreaWidth;
        this.canScrollX = canScrollX;
        this.canScrollY = canScrollY;
    }
}
