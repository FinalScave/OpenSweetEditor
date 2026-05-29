package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.foundation.TextPosition;

public final class IndentGuide {
    public TextPosition start = new TextPosition();
    public TextPosition end = new TextPosition();

    public IndentGuide() {
    }

    public IndentGuide(TextPosition start, TextPosition end) {
        this.start = start;
        this.end = end;
    }
}
