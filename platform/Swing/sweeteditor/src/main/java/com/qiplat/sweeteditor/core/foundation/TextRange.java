package com.qiplat.sweeteditor.core.foundation;

import com.google.gson.annotations.SerializedName;

public class TextRange {
    @SerializedName("start") public TextPosition start;
    @SerializedName("end") public TextPosition end;

    public TextRange() {
    }

    public TextRange(TextPosition start, TextPosition end) {
        this.start = start;
        this.end = end;
    }

    public boolean isCollapsed() {
        return start.line == end.line && start.column == end.column;
    }
}
