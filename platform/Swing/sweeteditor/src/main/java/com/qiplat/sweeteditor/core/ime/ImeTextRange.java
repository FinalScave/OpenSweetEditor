package com.qiplat.sweeteditor.core.ime;

public class ImeTextRange {
    public int start;
    public int end;

    public ImeTextRange() {
        this(0, 0);
    }

    public ImeTextRange(int start, int end) {
        this.start = start;
        this.end = end;
    }
}
