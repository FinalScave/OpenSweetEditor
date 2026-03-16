package com.qiplat.sweeteditor.event;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/** Selection change event */
public final class SelectionChangedEvent extends EditorEvent {
    public final boolean hasSelection;
    @Nullable public final TextRange selection;
    @NonNull public final TextPosition cursorPosition;

    public SelectionChangedEvent(boolean hasSelection, @Nullable TextRange selection, @NonNull TextPosition cursorPosition) {
        this.hasSelection = hasSelection;
        this.selection = selection;
        this.cursorPosition = cursorPosition;
    }
}
