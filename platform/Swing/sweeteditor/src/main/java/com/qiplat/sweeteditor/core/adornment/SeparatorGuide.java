package com.qiplat.sweeteditor.core.adornment;

public final class SeparatorGuide {
    public int line;
    public SeparatorStyle style;
    public int count;
    public int textEndColumn;

    public SeparatorGuide() {
    }

    public SeparatorGuide(int line, SeparatorStyle style, int count, int textEndColumn) {
        this.line = line;
        this.style = style;
        this.count = count;
        this.textEndColumn = textEndColumn;
    }

    public SeparatorGuide(int line, int style, int count, int textEndColumn) {
        this(line, SeparatorStyle.fromValue(style), count, textEndColumn);
    }
}
