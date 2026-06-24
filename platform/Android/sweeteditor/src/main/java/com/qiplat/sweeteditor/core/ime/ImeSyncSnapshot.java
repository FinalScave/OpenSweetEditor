package com.qiplat.sweeteditor.core.ime;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

public final class ImeSyncSnapshot {
    public TextPosition cursor = new TextPosition();
    public TextRange selection = new TextRange();
    public boolean hasSelection = false;
    public boolean hasPreeditRange = false;
    public TextRange preeditRange = new TextRange();
    public boolean hasSystemMarkRange = false;
    public TextRange systemMarkRange = new TextRange();
    public ImeContextPolicy contextPolicy = ImeContextPolicy.NONE;
    public boolean clearSystemMark = false;

    public ImeSyncSnapshot() {
    }

    public ImeSyncSnapshot(TextPosition cursor, TextRange selection, boolean hasSelection, boolean hasPreeditRange, TextRange preeditRange, boolean hasSystemMarkRange, TextRange systemMarkRange, ImeContextPolicy contextPolicy, boolean clearSystemMark) {
        this.cursor = cursor;
        this.selection = selection;
        this.hasSelection = hasSelection;
        this.hasPreeditRange = hasPreeditRange;
        this.preeditRange = preeditRange;
        this.hasSystemMarkRange = hasSystemMarkRange;
        this.systemMarkRange = systemMarkRange;
        this.contextPolicy = contextPolicy;
        this.clearSystemMark = clearSystemMark;
    }
}
