package com.qiplat.sweeteditor.event;

import android.graphics.PointF;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/** Double tap selection event */
public final class DoubleTapEvent extends EditorEvent {
    @NonNull public final TextPosition cursorPosition;
    public final boolean hasSelection;
    @Nullable public final TextRange selection;
    @NonNull public final PointF screenPoint;

    public DoubleTapEvent(@NonNull TextPosition cursorPosition, boolean hasSelection, @Nullable TextRange selection, @NonNull PointF screenPoint) {
        this.cursorPosition = cursorPosition;
        this.hasSelection = hasSelection;
        this.selection = selection;
        this.screenPoint = screenPoint;
    }
}
