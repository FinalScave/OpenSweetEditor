package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.config.FoldArrowMode;

public final class LayoutMetrics {
    public float fontHeight = 20f;
    public float fontAscent = 0f;
    public float lineSpacingAdd = 0f;
    public float lineSpacingMult = 1.2f;
    public float lineNumberMargin = 10f;
    public float lineNumberWidth = 10f;
    public float contentStartPadding = 0f;
    public int maxGutterIcons = 0;
    public float inlayHintPadding = 0f;
    public float inlayHintMargin = 0f;
    public FoldArrowMode foldArrowMode = FoldArrowMode.AUTO;
    public boolean hasFoldRegions = false;
    public boolean gutterSticky = true;
    public boolean gutterVisible = true;

    public LayoutMetrics() {
    }

    public LayoutMetrics(float fontHeight, float fontAscent, float lineSpacingAdd, float lineSpacingMult, float lineNumberMargin, float lineNumberWidth, float contentStartPadding, int maxGutterIcons, float inlayHintPadding, float inlayHintMargin, FoldArrowMode foldArrowMode, boolean hasFoldRegions, boolean gutterSticky, boolean gutterVisible) {
        this.fontHeight = fontHeight;
        this.fontAscent = fontAscent;
        this.lineSpacingAdd = lineSpacingAdd;
        this.lineSpacingMult = lineSpacingMult;
        this.lineNumberMargin = lineNumberMargin;
        this.lineNumberWidth = lineNumberWidth;
        this.contentStartPadding = contentStartPadding;
        this.maxGutterIcons = maxGutterIcons;
        this.inlayHintPadding = inlayHintPadding;
        this.inlayHintMargin = inlayHintMargin;
        this.foldArrowMode = foldArrowMode;
        this.hasFoldRegions = hasFoldRegions;
        this.gutterSticky = gutterSticky;
        this.gutterVisible = gutterVisible;
    }
}
