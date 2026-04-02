package com.qiplat.sweeteditor.event;

import android.graphics.PointF;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.adornment.InlayType;

/**
 * Inlay Hint click event.
 * <p>Triggered when the user clicks on an InlayHint.</p>
 */
public final class InlayHintClickEvent extends EditorEvent {
    /** The line number where the InlayHint is located (0-based). */
    public final int line;
    /** The column number where the InlayHint is located (0-based). */
    public final int column;
    /** The clicked inlay type. */
    @NonNull public final InlayType type;
    /** Type-specific integer value: iconId for ICON, ARGB for COLOR, 0 for TEXT. */
    public final int intValue;
    /** Screen coordinates at the time of click. */
    @NonNull public final PointF screenPoint;

    public InlayHintClickEvent(int line, int column, @NonNull InlayType type, int intValue, @NonNull PointF screenPoint) {
        this.line = line;
        this.column = column;
        this.type = type;
        this.intValue = intValue;
        this.screenPoint = screenPoint;
    }
}
