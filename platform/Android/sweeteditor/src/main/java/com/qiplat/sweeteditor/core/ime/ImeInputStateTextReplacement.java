package com.qiplat.sweeteditor.core.ime;

public final class ImeInputStateTextReplacement {
    public long contextId = 0L;
    public int documentStartOffset = 0;
    public int startOffset = 0;
    public int endOffset = 0;
    public String text = "";
    public int cursorOffset = 1;
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeInputStateTextReplacement() {
    }

    public ImeInputStateTextReplacement(long contextId, int documentStartOffset, int startOffset, int endOffset, String text, int cursorOffset, ImeScriptClass scriptClass) {
        this.contextId = contextId;
        this.documentStartOffset = documentStartOffset;
        this.startOffset = startOffset;
        this.endOffset = endOffset;
        this.text = text;
        this.cursorOffset = cursorOffset;
        this.scriptClass = scriptClass;
    }
}
