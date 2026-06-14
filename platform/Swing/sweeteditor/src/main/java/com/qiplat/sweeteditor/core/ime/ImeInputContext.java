package com.qiplat.sweeteditor.core.ime;

public final class ImeInputContext {
    public long id = 0L;
    public int revision = 0;
    public int documentStartOffset = 0;
    public String text = "";
    public ImeOffsetRange selection = new ImeOffsetRange();
    public boolean hasComposition = false;
    public ImeOffsetRange composition = new ImeOffsetRange(-1, -1);
    public boolean hasSystemMarkRange = false;
    public ImeOffsetRange systemMarkRange = new ImeOffsetRange(-1, -1);
    public ImeInputContextKind kind = ImeInputContextKind.NONE;

    public ImeInputContext() {
    }

    public ImeInputContext(long id, int revision, int documentStartOffset, String text, ImeOffsetRange selection, boolean hasComposition, ImeOffsetRange composition, boolean hasSystemMarkRange, ImeOffsetRange systemMarkRange, ImeInputContextKind kind) {
        this.id = id;
        this.revision = revision;
        this.documentStartOffset = documentStartOffset;
        this.text = text;
        this.selection = selection;
        this.hasComposition = hasComposition;
        this.composition = composition;
        this.hasSystemMarkRange = hasSystemMarkRange;
        this.systemMarkRange = systemMarkRange;
        this.kind = kind;
    }
}
