package com.qiplat.sweeteditor.contextmenu;

import android.graphics.PointF;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.interaction.HitTarget;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Immutable request snapshot used to build a context menu.
 */
public final class ContextMenuRequest {
    @NonNull public final ContextMenuTriggerKind triggerKind;
    @NonNull public final TextPosition cursorPosition;
    @NonNull public final PointF locationInEditor;
    public final boolean hasSelection;
    @Nullable public final TextRange selection;
    @NonNull public final HitTarget hitTarget;
    @NonNull public final String linkTarget;

    public ContextMenuRequest(@NonNull ContextMenuTriggerKind triggerKind,
                              @NonNull TextPosition cursorPosition,
                              @NonNull PointF locationInEditor,
                              boolean hasSelection,
                              @Nullable TextRange selection,
                              @NonNull HitTarget hitTarget,
                              @NonNull String linkTarget) {
        this.triggerKind = triggerKind;
        this.cursorPosition = new TextPosition(cursorPosition.line, cursorPosition.column);
        this.locationInEditor = new PointF(locationInEditor.x, locationInEditor.y);
        this.hasSelection = hasSelection;
        this.selection = selection != null
                ? new TextRange(
                new TextPosition(selection.start.line, selection.start.column),
                new TextPosition(selection.end.line, selection.end.column))
                : null;
        this.hitTarget = hitTarget;
        this.linkTarget = linkTarget;
    }
}
