package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * Double-tap selection event.
 */
public final class DoubleTapEvent extends EditorEvent {
    public final TextPosition cursorPosition;
    public final boolean hasSelection;
    public final TextRange selection;
    public final PointF locationInEditor;

    public DoubleTapEvent(TextPosition cursorPosition, boolean hasSelection, TextRange selection, PointF locationInEditor) {
        this.cursorPosition = cursorPosition;
        this.hasSelection = hasSelection;
        this.selection = selection;
        this.locationInEditor = locationInEditor;
    }
}
