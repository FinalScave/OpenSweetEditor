package com.qiplat.sweeteditor.core.ime;

public final class ImeInputContext {
    public long id = 0L;
    public int revision = 0;
    public int documentStartOffset = 0;
    public String text = "";
    public ImeOffsetRange selection = new ImeOffsetRange();
    public boolean hasPreeditRange = false;
    public ImeOffsetRange preeditRange = new ImeOffsetRange(-1, -1);
    public boolean hasSystemMarkRange = false;
    public ImeOffsetRange systemMarkRange = new ImeOffsetRange(-1, -1);
    public ImeInputContextKind kind = ImeInputContextKind.NONE;

    public ImeInputContext() {
    }

    public ImeInputContext(long id, int revision, int documentStartOffset, String text, ImeOffsetRange selection, boolean hasPreeditRange, ImeOffsetRange preeditRange, boolean hasSystemMarkRange, ImeOffsetRange systemMarkRange, ImeInputContextKind kind) {
        this.id = id;
        this.revision = revision;
        this.documentStartOffset = documentStartOffset;
        this.text = text;
        this.selection = selection;
        this.hasPreeditRange = hasPreeditRange;
        this.preeditRange = preeditRange;
        this.hasSystemMarkRange = hasSystemMarkRange;
        this.systemMarkRange = systemMarkRange;
        this.kind = kind;
    }
}
