package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * CodeLens click event.
 * <p>Triggered when the user clicks on a CodeLens item.</p>
 */
public final class CodeLensClickEvent extends EditorEvent {
    /** Line number where the CodeLens is located (0-based) */
    public final int line;
    /** Column anchor of the clicked CodeLens (0-based, UTF-16 offset) */
    public final int column;
    /** Command ID */
    public final int commandId;
    public final PointF locationInEditor;

    public CodeLensClickEvent(int line, int column, int commandId, PointF locationInEditor) {
        this.line = line;
        this.column = column;
        this.commandId = commandId;
        this.locationInEditor = locationInEditor;
    }
}
