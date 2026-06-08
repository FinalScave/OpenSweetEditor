package com.qiplat.sweeteditor.core.adornment;

public final class DocumentHighlight {
    public int column = 0;
    public int length = 0;
    public DocumentHighlightKind kind = DocumentHighlightKind.TEXT;

    public DocumentHighlight() {
    }

    public DocumentHighlight(int column, int length, DocumentHighlightKind kind) {
        this.column = column;
        this.length = length;
        this.kind = kind;
    }
}
