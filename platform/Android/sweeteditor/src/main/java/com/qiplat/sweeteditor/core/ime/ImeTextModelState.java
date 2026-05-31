package com.qiplat.sweeteditor.core.ime;

public final class ImeTextModelState {
    public ImeTextModelMode mode = ImeTextModelMode.DOCUMENT_WINDOW;
    public long contextId = 0L;
    public int documentStartOffset = 0;
    public String text = "";
    public ImeTextRange selection = new ImeTextRange();
    public ImeTextRange composition = new ImeTextRange(-1, -1);
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeTextModelState() {
    }

    public ImeTextModelState(ImeTextModelMode mode, long contextId, int documentStartOffset, String text, ImeTextRange selection, ImeTextRange composition, ImeScriptClass scriptClass) {
        this.mode = mode;
        this.contextId = contextId;
        this.documentStartOffset = documentStartOffset;
        this.text = text;
        this.selection = selection;
        this.composition = composition;
        this.scriptClass = scriptClass;
    }
}
