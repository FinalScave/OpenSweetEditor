package com.qiplat.sweeteditor.core.config;

public final class ScrollbarConfig {
    public float thickness = 10.0f;
    public float minThumb = 24.0f;
    public float thumbHitPadding = 0.0f;
    public ScrollbarMode mode = ScrollbarMode.ALWAYS;
    public boolean thumbDraggable = true;
    public ScrollbarTrackTapMode trackTapMode = ScrollbarTrackTapMode.JUMP;
    public int fadeDelayMs = 700;
    public int fadeDurationMs = 300;

    public ScrollbarConfig() {
    }

    public ScrollbarConfig(float thickness, float minThumb, float thumbHitPadding, ScrollbarMode mode, boolean thumbDraggable, ScrollbarTrackTapMode trackTapMode, int fadeDelayMs, int fadeDurationMs) {
        this.thickness = thickness;
        this.minThumb = minThumb;
        this.thumbHitPadding = thumbHitPadding;
        this.mode = mode;
        this.thumbDraggable = thumbDraggable;
        this.trackTapMode = trackTapMode;
        this.fadeDelayMs = fadeDelayMs;
        this.fadeDurationMs = fadeDurationMs;
    }
}
