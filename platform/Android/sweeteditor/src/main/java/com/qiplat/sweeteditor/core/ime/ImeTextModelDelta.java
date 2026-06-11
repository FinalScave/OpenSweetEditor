package com.qiplat.sweeteditor.core.ime;

public final class ImeTextModelDelta {
    public ImeTextModelMode mode = ImeTextModelMode.DOCUMENT_WINDOW;
    public long contextId = 0L;
    public int documentStartOffset = 0;
    public String oldText = "";
    public ImeOffsetRange delta = new ImeOffsetRange(-1, -1);
    public String deltaText = "";
    public ImeOffsetRange selection = new ImeOffsetRange();
    public ImeOffsetRange composition = new ImeOffsetRange(-1, -1);
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeTextModelDelta() {
    }

    public ImeTextModelDelta(ImeTextModelMode mode, long contextId, int documentStartOffset, String oldText, ImeOffsetRange delta, String deltaText, ImeOffsetRange selection, ImeOffsetRange composition, ImeScriptClass scriptClass) {
        this.mode = mode;
        this.contextId = contextId;
        this.documentStartOffset = documentStartOffset;
        this.oldText = oldText;
        this.delta = delta;
        this.deltaText = deltaText;
        this.selection = selection;
        this.composition = composition;
        this.scriptClass = scriptClass;
    }
}
