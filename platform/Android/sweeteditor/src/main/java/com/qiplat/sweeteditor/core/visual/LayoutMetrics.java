package com.qiplat.sweeteditor.core.visual;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;

/**
 * Layout metrics snapshot produced by the core.
 */
public final class LayoutMetrics {
    public final float fontHeight;
    public final float fontAscent;
    public final float lineSpacingAdd;
    public final float lineSpacingMult;
    public final float lineNumberMargin;
    public final float lineNumberWidth;
    public final int maxGutterIcons;
    public final float inlayHintPadding;
    public final float inlayHintMargin;
    @NonNull public final FoldArrowMode foldArrowMode;
    public final boolean hasFoldRegions;

    public LayoutMetrics(float fontHeight,
                         float fontAscent,
                         float lineSpacingAdd,
                         float lineSpacingMult,
                         float lineNumberMargin,
                         float lineNumberWidth,
                         int maxGutterIcons,
                         float inlayHintPadding,
                         float inlayHintMargin,
                         @NonNull FoldArrowMode foldArrowMode,
                         boolean hasFoldRegions) {
        this.fontHeight = fontHeight;
        this.fontAscent = fontAscent;
        this.lineSpacingAdd = lineSpacingAdd;
        this.lineSpacingMult = lineSpacingMult;
        this.lineNumberMargin = lineNumberMargin;
        this.lineNumberWidth = lineNumberWidth;
        this.maxGutterIcons = maxGutterIcons;
        this.inlayHintPadding = inlayHintPadding;
        this.inlayHintMargin = inlayHintMargin;
        this.foldArrowMode = foldArrowMode;
        this.hasFoldRegions = hasFoldRegions;
    }
}
