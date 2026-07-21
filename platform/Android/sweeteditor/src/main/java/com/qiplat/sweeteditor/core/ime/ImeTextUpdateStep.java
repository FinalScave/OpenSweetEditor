package com.qiplat.sweeteditor.core.ime;

public final class ImeTextUpdateStep {
    public String oldText = "";
    public ImeOffsetRange patchRange = new ImeOffsetRange();
    public String replacementText = "";
    public ImeSelection selectionAfter = new ImeSelection();
    public ImeOffsetRange compositionAfter = new ImeOffsetRange();

    public ImeTextUpdateStep() {
    }

    public ImeTextUpdateStep(String oldText, ImeOffsetRange patchRange, String replacementText, ImeSelection selectionAfter, ImeOffsetRange compositionAfter) {
        this.oldText = oldText;
        this.patchRange = patchRange;
        this.replacementText = replacementText;
        this.selectionAfter = selectionAfter;
        this.compositionAfter = compositionAfter;
    }
}
