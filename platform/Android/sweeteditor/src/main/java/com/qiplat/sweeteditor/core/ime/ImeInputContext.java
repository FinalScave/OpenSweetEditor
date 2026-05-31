package com.qiplat.sweeteditor.core.ime;

public final class ImeInputContext {
    public long id = 0L;
    public int revision = 0;
    public int documentStartOffset = 0;
    public String text = "";
    public ImeTextRange selection = new ImeTextRange();
    public boolean hasComposition = false;
    public ImeTextRange composition = new ImeTextRange(-1, -1);
    public ImeInputContextKind kind = ImeInputContextKind.NONE;

    public ImeInputContext() {
    }

    public ImeInputContext(long id, int revision, int documentStartOffset, String text, ImeTextRange selection, boolean hasComposition, ImeTextRange composition, ImeInputContextKind kind) {
        this.id = id;
        this.revision = revision;
        this.documentStartOffset = documentStartOffset;
        this.text = text;
        this.selection = selection;
        this.hasComposition = hasComposition;
        this.composition = composition;
        this.kind = kind;
    }
}
