package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Selection changed event.
 */
public final class SelectionChangedEvent extends EditorEvent {
    public final boolean hasSelection;
    public final TextRange selection;
    public final TextPosition cursorPosition;

    public SelectionChangedEvent(boolean hasSelection, TextRange selection, TextPosition cursorPosition) {
        this.hasSelection = hasSelection;
        this.selection = selection;
        this.cursorPosition = cursorPosition;
    }
}
