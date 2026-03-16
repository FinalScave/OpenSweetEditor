package com.qiplat.sweeteditor.core.visual;

/**
 * Scrollbar metrics (used by platform to calculate scrollbar thumb size and position).
 */
public class ScrollMetrics {
    public final float scale;
    public final float scrollX;
    public final float scrollY;
    public final float maxScrollX;
    public final float maxScrollY;
    public final float contentWidth;
    public final float contentHeight;
    public final float viewportWidth;
    public final float viewportHeight;
    public final float textAreaX;
    public final float textAreaWidth;
    public final boolean canScrollX;
    public final boolean canScrollY;

    public ScrollMetrics(
            float scale,
            float scrollX,
            float scrollY,
            float maxScrollX,
            float maxScrollY,
            float contentWidth,
            float contentHeight,
            float viewportWidth,
            float viewportHeight,
            float textAreaX,
            float textAreaWidth,
            boolean canScrollX,
            boolean canScrollY) {
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
