package com.qiplat.sweeteditor.core;

/**
 * Selection handle appearance and touch configuration.
 * Used by EditorCore to pass handle parameters to C++ core and platform View layer.
 */
public class HandleConfig {
    /** Water-drop circle radius */
    public final float radius;
    /** Distance from water-drop circle center to the tip */
    public final float centerDist;
    /** Cursor vertical line width */
    public final float lineWidth;
    /** Touch hot-zone expansion around the vertical line */
    public final float touchPadding;
    /** Vertical offset for drag position (moves finger up to avoid occlusion) */
    public final float dragYOffset;

    /** Default constructor with standard values */
    public HandleConfig() {
        this(22.0f, 56.0f, 3.0f, 10.0f, 50.0f);
    }

    /** Full constructor */
    public HandleConfig(float radius, float centerDist, float lineWidth, float touchPadding, float dragYOffset) {
        this.radius = radius;
        this.centerDist = centerDist;
        this.lineWidth = lineWidth;
        this.touchPadding = touchPadding;
        this.dragYOffset = dragYOffset;
    }
}
