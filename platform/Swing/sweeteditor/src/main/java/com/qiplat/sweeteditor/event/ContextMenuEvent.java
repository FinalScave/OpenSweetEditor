package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * Right-click/context menu event.
 */
public final class ContextMenuEvent extends EditorEvent {
    public final TextPosition cursorPosition;
    public final PointF locationInEditor;

    public ContextMenuEvent(TextPosition cursorPosition, PointF locationInEditor) {
        this.cursorPosition = cursorPosition;
        this.locationInEditor = locationInEditor;
    }
}
