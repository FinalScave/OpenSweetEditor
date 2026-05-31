package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.PointF;
import com.qiplat.sweeteditor.core.foundation.TextPosition;

public final class Cursor {
    public TextPosition textPosition = new TextPosition();
    public PointF position = new PointF();
    public float height = 0f;
    public boolean visible = true;
    public boolean showDragger = false;

    public Cursor() {
    }

    public Cursor(TextPosition textPosition, PointF position, float height, boolean visible, boolean showDragger) {
        this.textPosition = textPosition;
        this.position = position;
        this.height = height;
        this.visible = visible;
        this.showDragger = showDragger;
    }
}
