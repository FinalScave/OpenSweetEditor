package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

import java.awt.Point;

/**
 * Right-click/context menu event.
 */
public final class ContextMenuEvent extends EditorEvent {
    public final TextPosition cursorPosition;
    public final Point screenPoint;

    public ContextMenuEvent(TextPosition cursorPosition, Point screenPoint) {
        this.cursorPosition = cursorPosition;
        this.screenPoint = screenPoint;
    }
}
