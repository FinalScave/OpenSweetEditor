package com.qiplat.sweeteditor.core.visual;

/**
 * Screen coordinate rectangle for cursor/text position (used for floating panel positioning).
 * <p>
 * Coordinates are relative to the editor View's top-left corner. External callers needing
 * screen coordinates must perform view-to-screen conversion themselves.
 */
public class CursorRect {
    /** X coordinate relative to the editor view's top-left corner */
    public final float x;
    /** Y coordinate relative to the editor view's top-left corner (top of the line) */
    public final float y;
    /** Line height (same as cursor height) */
    public final float height;

    public CursorRect(float x, float y, float height) {
        this.x = x;
        this.y = y;
        this.height = height;
    }

    @Override
    public String toString() {
        return "CursorRect{x=" + x + ", y=" + y + ", height=" + height + '}';
    }
}
