package com.qiplat.sweeteditor.core.ime;

public final class ImeCommand {
    public ImeCommandKind kind = ImeCommandKind.SET_SELECTION;
    public ImeOffsetRange targetRange = new ImeOffsetRange();
    public ImeSelection selectionAfter = new ImeSelection();
    public String text = "";
    public long deleteBefore = 0L;
    public long deleteAfter = 0L;
    public ImeTextUnit textUnit = ImeTextUnit.UTF16_CODE_UNIT;

    public ImeCommand() {
    }

    public ImeCommand(ImeCommandKind kind, ImeOffsetRange targetRange, ImeSelection selectionAfter, String text, long deleteBefore, long deleteAfter, ImeTextUnit textUnit) {
        this.kind = kind;
        this.targetRange = targetRange;
        this.selectionAfter = selectionAfter;
        this.text = text;
        this.deleteBefore = deleteBefore;
        this.deleteAfter = deleteAfter;
        this.textUnit = textUnit;
    }
}
