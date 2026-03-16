package com.qiplat.sweeteditor.event;

import java.awt.Point;

/**
 * Gutter icon click event.
 */
public final class GutterIconClickEvent extends EditorEvent {
    /** Line number where the icon is located (0-based) */
    public final int line;
    /** Icon ID */
    public final int iconId;
    /** Screen coordinates at the time of click */
    public final Point screenPoint;

    public GutterIconClickEvent(int line, int iconId, Point screenPoint) {
        this.line = line;
        this.iconId = iconId;
        this.screenPoint = screenPoint;
    }
}
