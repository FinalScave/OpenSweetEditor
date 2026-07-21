package com.qiplat.sweeteditor.core.ime;

public final class ImeOffsetRange {
    public ImeCoordinateSpace coordinateSpace = ImeCoordinateSpace.DOCUMENT;
    public long startUtf16 = -1L;
    public long endUtf16 = -1L;

    public ImeOffsetRange() {
    }

    public ImeOffsetRange(ImeCoordinateSpace coordinateSpace, long startUtf16, long endUtf16) {
        this.coordinateSpace = coordinateSpace;
        this.startUtf16 = startUtf16;
        this.endUtf16 = endUtf16;
    }
}
