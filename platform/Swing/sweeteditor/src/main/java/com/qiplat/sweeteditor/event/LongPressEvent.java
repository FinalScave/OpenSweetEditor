package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

import java.awt.Point;

/**
 * Long press event.
 */
public final class LongPressEvent extends EditorEvent {
    public final TextPosition cursorPosition;
    public final Point screenPoint;

    public LongPressEvent(TextPosition cursorPosition, Point screenPoint) {
        this.cursorPosition = cursorPosition;
        this.screenPoint = screenPoint;
    }
}
