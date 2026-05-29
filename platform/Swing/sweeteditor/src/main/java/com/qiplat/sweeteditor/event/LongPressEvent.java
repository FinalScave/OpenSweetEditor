package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * Long press event.
 */
public final class LongPressEvent extends EditorEvent {
    public final TextPosition cursorPosition;
    public final PointF locationInEditor;

    public LongPressEvent(TextPosition cursorPosition, PointF locationInEditor) {
        this.cursorPosition = cursorPosition;
        this.locationInEditor = locationInEditor;
    }
}
