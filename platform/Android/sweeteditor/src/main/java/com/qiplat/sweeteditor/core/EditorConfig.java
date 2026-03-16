package com.qiplat.sweeteditor.core;

public class EditorConfig {
    /** Threshold to determine if a gesture is a move; below this threshold, it's considered a tap */
    public final float touchSlop;
    /** Double-tap time threshold (milliseconds) */
    public final long doubleTapTimeout;
    /** Whether to enable IME composition input, disabled by default */
    public final boolean compositionEnabled;

    public EditorConfig(float touchSlop, long doubleTapTimeout) {
        this(touchSlop, doubleTapTimeout, false);
    }

    public EditorConfig(float touchSlop, long doubleTapTimeout, boolean compositionEnabled) {
        this.touchSlop = touchSlop;
        this.doubleTapTimeout = doubleTapTimeout;
        this.compositionEnabled = compositionEnabled;
    }
}
