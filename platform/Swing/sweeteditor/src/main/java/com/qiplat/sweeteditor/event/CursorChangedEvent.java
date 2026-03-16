package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/**
 * Cursor position changed event.
 */
public final class CursorChangedEvent extends EditorEvent {
    public final TextPosition cursorPosition;

    public CursorChangedEvent(TextPosition cursorPosition) {
        this.cursorPosition = cursorPosition;
    }
}
