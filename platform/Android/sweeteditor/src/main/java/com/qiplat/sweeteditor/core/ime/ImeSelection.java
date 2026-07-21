package com.qiplat.sweeteditor.core.ime;

public final class ImeSelection {
    public ImeCoordinateSpace coordinateSpace = ImeCoordinateSpace.DOCUMENT;
    public long anchorUtf16 = -1L;
    public long activeUtf16 = -1L;
    public CaretAffinity affinity = CaretAffinity.DOWNSTREAM;

    public ImeSelection() {
    }

    public ImeSelection(ImeCoordinateSpace coordinateSpace, long anchorUtf16, long activeUtf16, CaretAffinity affinity) {
        this.coordinateSpace = coordinateSpace;
        this.anchorUtf16 = anchorUtf16;
        this.activeUtf16 = activeUtf16;
        this.affinity = affinity;
    }
}
