package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

public final class FlowGuide {
    public TextPosition start = new TextPosition();
    public TextPosition end = new TextPosition();

    public FlowGuide() {
    }

    public FlowGuide(TextPosition start, TextPosition end) {
        this.start = start;
        this.end = end;
    }
}
