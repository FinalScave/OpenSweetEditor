package com.qiplat.sweeteditor.event;

import java.awt.Point;

/**
 * Fold toggle event (triggered when clicking the fold placeholder or fold arrow).
 */
public final class FoldToggleEvent extends EditorEvent {
    /** Line number of the fold region (0-based) */
    public final int line;
    /** Whether triggered by clicking the gutter fold arrow (false means triggered by clicking the fold placeholder) */
    public final boolean fromGutter;
    /** Screen coordinates at the time of click */
    public final Point screenPoint;

    public FoldToggleEvent(int line, boolean fromGutter, Point screenPoint) {
        this.line = line;
        this.fromGutter = fromGutter;
        this.screenPoint = screenPoint;
    }
}
