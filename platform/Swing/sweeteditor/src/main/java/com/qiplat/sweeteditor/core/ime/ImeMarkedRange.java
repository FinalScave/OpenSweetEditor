package com.qiplat.sweeteditor.core.ime;

public final class ImeMarkedRange {
    public ImeMarkedRangeRole role = ImeMarkedRangeRole.NONE;
    public ImeOffsetRange range = new ImeOffsetRange(-1, -1);

    public ImeMarkedRange() {
    }

    public ImeMarkedRange(ImeMarkedRangeRole role, ImeOffsetRange range) {
        this.role = role;
        this.range = range;
    }
}
