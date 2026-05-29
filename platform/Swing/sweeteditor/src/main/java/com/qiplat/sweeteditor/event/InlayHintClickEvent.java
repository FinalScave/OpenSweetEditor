package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * InlayHint click event.
 * <p>Triggered when the user clicks on an InlayHint.</p>
 */
public final class InlayHintClickEvent extends EditorEvent {
    public final int line;
    public final int column;
    public final InlayType type;
    public final int intValue;
    public final PointF locationInEditor;

    public InlayHintClickEvent(int line, int column, InlayType type, int intValue, PointF locationInEditor) {
        this.line = line;
        this.column = column;
        this.type = type;
        this.intValue = intValue;
        this.locationInEditor = locationInEditor;
    }
}
