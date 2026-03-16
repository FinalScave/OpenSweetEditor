package com.qiplat.sweeteditor.core.visual;

/**
 * Scrollbar metrics (used by platform to calculate scrollbar thumb size and position).
 */
public record ScrollMetrics(
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
        boolean canScrollY
) {
}
