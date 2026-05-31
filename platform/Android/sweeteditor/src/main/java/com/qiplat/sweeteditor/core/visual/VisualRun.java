package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.adornment.TextStyle;

public final class VisualRun {
    public VisualRunType type = VisualRunType.TEXT;
    public float x = 0f;
    public float y = 0f;
    public String text = "";
    public TextStyle style = new TextStyle();
    public int iconId = 0;
    public int colorValue = 0;
    public float width = 0f;
    public float padding = 0f;
    public float margin = 0f;
    public boolean active = false;

    public VisualRun() {
    }

    public VisualRun(VisualRunType type, float x, float y, String text, TextStyle style, int iconId, int colorValue, float width, float padding, float margin, boolean active) {
        this.type = type;
        this.x = x;
        this.y = y;
        this.text = text;
        this.style = style;
        this.iconId = iconId;
        this.colorValue = colorValue;
        this.width = width;
        this.padding = padding;
        this.margin = margin;
        this.active = active;
    }
}
