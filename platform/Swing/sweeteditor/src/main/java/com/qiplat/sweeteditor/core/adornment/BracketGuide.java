package com.qiplat.sweeteditor.core.adornment;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import java.util.List;

public final class BracketGuide {
    public TextPosition parent = new TextPosition();
    public TextPosition end = new TextPosition();
    public java.util.List<TextPosition> children = new java.util.ArrayList<>();

    public BracketGuide() {
    }

    public BracketGuide(TextPosition parent, TextPosition end, java.util.List<TextPosition> children) {
        this.parent = parent;
        this.end = end;
        this.children = children;
    }
}
