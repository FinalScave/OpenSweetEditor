package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.awt.Point;

/**
 * Double-tap selection event.
 */
public final class DoubleTapEvent extends EditorEvent {
    public final TextPosition cursorPosition;
    public final boolean hasSelection;
    public final TextRange selection;
    public final Point screenPoint;

    public DoubleTapEvent(TextPosition cursorPosition, boolean hasSelection, TextRange selection, Point screenPoint) {
        this.cursorPosition = cursorPosition;
        this.hasSelection = hasSelection;
        this.selection = selection;
        this.screenPoint = screenPoint;
    }
}
