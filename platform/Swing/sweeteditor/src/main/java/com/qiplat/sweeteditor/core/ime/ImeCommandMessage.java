package com.qiplat.sweeteditor.core.ime;

public final class ImeCommandMessage {
    public ImeCommandKind kind = ImeCommandKind.SET_SELECTION;
    public long contextId = 0L;
    public int contextRevision = 0;
    public int documentStartOffset = 0;
    public ImeOffsetRange range = new ImeOffsetRange(-1, -1);
    public ImeOffsetRange selection = new ImeOffsetRange(-1, -1);
    public String text = "";
    public int cursorOffset = 1;
    public int deleteBefore = 0;
    public int deleteAfter = 0;
    public ImeTextUnit textUnit = ImeTextUnit.GRAPHEME;
    public ImeMarkedRangeRole markedRole = ImeMarkedRangeRole.NONE;
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeCommandMessage() {
    }

    public ImeCommandMessage(ImeCommandKind kind, long contextId, int contextRevision, int documentStartOffset, ImeOffsetRange range, ImeOffsetRange selection, String text, int cursorOffset, int deleteBefore, int deleteAfter, ImeTextUnit textUnit, ImeMarkedRangeRole markedRole, ImeScriptClass scriptClass) {
        this.kind = kind;
        this.contextId = contextId;
        this.contextRevision = contextRevision;
        this.documentStartOffset = documentStartOffset;
        this.range = range;
        this.selection = selection;
        this.text = text;
        this.cursorOffset = cursorOffset;
        this.deleteBefore = deleteBefore;
        this.deleteAfter = deleteAfter;
        this.textUnit = textUnit;
        this.markedRole = markedRole;
        this.scriptClass = scriptClass;
    }
}
