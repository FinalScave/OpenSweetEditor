package com.qiplat.sweeteditor.core.foundation;

import com.google.gson.annotations.SerializedName;

public class TextPosition {
    @SerializedName("line") public int line;
    @SerializedName("column") public int column;

    public TextPosition() {}
    public TextPosition(int line, int column) { this.line = line; this.column = column; }
}
