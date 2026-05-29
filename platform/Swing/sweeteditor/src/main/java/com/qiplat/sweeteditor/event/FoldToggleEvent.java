package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.PointF;

/**
 * Fold toggle event (triggered when clicking the fold placeholder or fold arrow).
 */
public final class FoldToggleEvent extends EditorEvent {
    public final int line;
    public final boolean isGutter;
    public final PointF locationInEditor;

    public FoldToggleEvent(int line, boolean isGutter, PointF locationInEditor) {
        this.line = line;
        this.isGutter = isGutter;
        this.locationInEditor = locationInEditor;
    }
}
