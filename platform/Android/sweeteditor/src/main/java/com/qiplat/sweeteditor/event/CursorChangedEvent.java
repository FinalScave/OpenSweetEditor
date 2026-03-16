package com.qiplat.sweeteditor.event;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

/** Cursor position change event */
public final class CursorChangedEvent extends EditorEvent {
    @NonNull public final TextPosition cursorPosition;

    public CursorChangedEvent(@NonNull TextPosition cursorPosition) {
        this.cursorPosition = cursorPosition;
    }
}
