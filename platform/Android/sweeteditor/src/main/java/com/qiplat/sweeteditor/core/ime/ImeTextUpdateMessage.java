package com.qiplat.sweeteditor.core.ime;

public final class ImeTextUpdateMessage {
    public ImeTextUpdateKind kind = ImeTextUpdateKind.SNAPSHOT;
    public ImeTextUpdateScope scope = ImeTextUpdateScope.DOCUMENT_WINDOW;
    public long contextId = 0L;
    public int contextRevision = 0;
    public int documentStartOffset = 0;
    public String text = "";
    public ImeTextPatch patch = new ImeTextPatch();
    public ImeOffsetRange selection = new ImeOffsetRange(-1, -1);
    public ImeMarkedRange markedRange = new ImeMarkedRange();
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeTextUpdateMessage() {
    }

    public ImeTextUpdateMessage(ImeTextUpdateKind kind, ImeTextUpdateScope scope, long contextId, int contextRevision, int documentStartOffset, String text, ImeTextPatch patch, ImeOffsetRange selection, ImeMarkedRange markedRange, ImeScriptClass scriptClass) {
        this.kind = kind;
        this.scope = scope;
        this.contextId = contextId;
        this.contextRevision = contextRevision;
        this.documentStartOffset = documentStartOffset;
        this.text = text;
        this.patch = patch;
        this.selection = selection;
        this.markedRange = markedRange;
        this.scriptClass = scriptClass;
    }
}
