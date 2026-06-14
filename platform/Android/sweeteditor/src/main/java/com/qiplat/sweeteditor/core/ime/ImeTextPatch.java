package com.qiplat.sweeteditor.core.ime;

public final class ImeTextPatch {
    public ImeOffsetRange range = new ImeOffsetRange(-1, -1);
    public String text = "";

    public ImeTextPatch() {
    }

    public ImeTextPatch(ImeOffsetRange range, String text) {
        this.range = range;
        this.text = text;
    }
}
