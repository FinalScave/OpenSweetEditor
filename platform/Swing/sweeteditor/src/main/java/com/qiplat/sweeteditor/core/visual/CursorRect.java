package com.qiplat.sweeteditor.core.visual;

/**
 * Screen coordinate rectangle for cursor/text position (used for floating panel positioning).
 * <p>
 * Coordinates are relative to the editor View's top-left corner. External callers needing
 * screen coordinates must perform view-to-screen conversion themselves.
 *
 * @param x      x coordinate relative to the editor view's top-left corner
 * @param y      y coordinate relative to the editor view's top-left corner (top of the line)
 * @param height line height (same as cursor height)
 */
public record CursorRect(float x, float y, float height) {
}
