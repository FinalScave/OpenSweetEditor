package com.qiplat.sweeteditor.core;

/**
 * Scrollbar geometry configuration.
 * Used by EditorCore to pass scrollbar parameters to C++ core.
 */
public class ScrollbarConfig {
    public enum ScrollbarMode {
        ALWAYS(0),
        TRANSIENT(1),
        NEVER(2);

        public final int value;

        ScrollbarMode(int value) {
            this.value = value;
        }
    }

    public enum ScrollbarTrackTapMode {
        JUMP(0),
        DISABLED(1);

        public final int value;

        ScrollbarTrackTapMode(int value) {
            this.value = value;
        }
    }

    /** Scrollbar thickness in pixels */
    public final float thickness;
    /** Minimum scrollbar thumb length in pixels */
    public final float minThumb;
    /** Visibility mode */
    public final ScrollbarMode mode;
    /** Whether thumb dragging is enabled */
    public final boolean thumbDraggable;
    /** Track tap mode */
    public final ScrollbarTrackTapMode trackTapMode;
    /** Delay before hide in TRANSIENT mode */
    public final int fadeDelayMs;
    /** Fade duration in TRANSIENT mode (used for both fade-in and fade-out). */
    public final int fadeDurationMs;

    /** Default constructor with standard values */
    public ScrollbarConfig() {
        this(10.0f, 24.0f, ScrollbarMode.ALWAYS, true, ScrollbarTrackTapMode.JUMP, 700, 300);
    }

    /** Geometry-only constructor (behavior uses defaults). */
    public ScrollbarConfig(float thickness, float minThumb) {
        this(thickness, minThumb, ScrollbarMode.ALWAYS, true, ScrollbarTrackTapMode.JUMP, 700, 300);
    }

    /** Full constructor */
    public ScrollbarConfig(float thickness, float minThumb,
                           ScrollbarMode mode, boolean thumbDraggable, ScrollbarTrackTapMode trackTapMode,
                           int fadeDelayMs, int fadeDurationMs) {
        this.thickness = thickness;
        this.minThumb = minThumb;
        this.mode = mode;
        this.thumbDraggable = thumbDraggable;
        this.trackTapMode = trackTapMode;
        this.fadeDelayMs = fadeDelayMs;
        this.fadeDurationMs = fadeDurationMs;
    }
}
