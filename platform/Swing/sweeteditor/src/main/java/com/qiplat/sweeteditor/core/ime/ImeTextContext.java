package com.qiplat.sweeteditor.core.ime;

public final class ImeTextContext {
    public ImeResultCode resultCode = ImeResultCode.OK;
    public long sliceStartUtf16 = 0L;
    public long totalLengthUtf16 = 0L;
    public String text = "";
    public ImeSelection selection = new ImeSelection();
    public ImeOffsetRange compositionRange = new ImeOffsetRange();

    public ImeTextContext() {
    }

    public ImeTextContext(ImeResultCode resultCode, long sliceStartUtf16, long totalLengthUtf16, String text, ImeSelection selection, ImeOffsetRange compositionRange) {
        this.resultCode = resultCode;
        this.sliceStartUtf16 = sliceStartUtf16;
        this.totalLengthUtf16 = totalLengthUtf16;
        this.text = text;
        this.selection = selection;
        this.compositionRange = compositionRange;
    }
}
