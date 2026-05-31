package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * Gutter icon click event.
 */
public final class GutterIconClickEvent extends EditorEvent {
    /** Line number where the icon is located (0-based) */
    public final int line;
    /** Icon ID */
    public final int iconId;
    public final PointF locationInEditor;

    public GutterIconClickEvent(int line, int iconId, PointF locationInEditor) {
        this.line = line;
        this.iconId = iconId;
        this.locationInEditor = locationInEditor;
    }
}
