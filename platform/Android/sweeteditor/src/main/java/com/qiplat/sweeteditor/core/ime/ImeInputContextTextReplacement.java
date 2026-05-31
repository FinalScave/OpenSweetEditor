package com.qiplat.sweeteditor.core.ime;

public final class ImeInputContextTextReplacement {
    public int startOffset = 0;
    public int endOffset = 0;
    public String text = "";
    public int cursorOffset = 1;
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeInputContextTextReplacement() {
    }

    public ImeInputContextTextReplacement(int startOffset, int endOffset, String text, int cursorOffset, ImeScriptClass scriptClass) {
        this.startOffset = startOffset;
        this.endOffset = endOffset;
        this.text = text;
        this.cursorOffset = cursorOffset;
        this.scriptClass = scriptClass;
    }
}
