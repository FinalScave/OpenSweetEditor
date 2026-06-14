package com.qiplat.sweeteditor.core.ime;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

public final class ImeSyncSnapshot {
    public TextPosition cursor = new TextPosition();
    public TextRange selection = new TextRange();
    public boolean hasSelection = false;
    public boolean hasComposingSession = false;
    public boolean hasVisibleCompositionRange = false;
    public TextRange visibleCompositionRange = new TextRange();
    public boolean hasSystemMarkRange = false;
    public TextRange systemMarkRange = new TextRange();
    public ImePreeditStorage preeditStorage = ImePreeditStorage.NONE;
    public ImeContextPolicy contextPolicy = ImeContextPolicy.NONE;
    public boolean clearSystemMark = false;

    public ImeSyncSnapshot() {
    }

    public ImeSyncSnapshot(TextPosition cursor, TextRange selection, boolean hasSelection, boolean hasComposingSession, boolean hasVisibleCompositionRange, TextRange visibleCompositionRange, boolean hasSystemMarkRange, TextRange systemMarkRange, ImePreeditStorage preeditStorage, ImeContextPolicy contextPolicy, boolean clearSystemMark) {
        this.cursor = cursor;
        this.selection = selection;
        this.hasSelection = hasSelection;
        this.hasComposingSession = hasComposingSession;
        this.hasVisibleCompositionRange = hasVisibleCompositionRange;
        this.visibleCompositionRange = visibleCompositionRange;
        this.hasSystemMarkRange = hasSystemMarkRange;
        this.systemMarkRange = systemMarkRange;
        this.preeditStorage = preeditStorage;
        this.contextPolicy = contextPolicy;
        this.clearSystemMark = clearSystemMark;
    }
}
