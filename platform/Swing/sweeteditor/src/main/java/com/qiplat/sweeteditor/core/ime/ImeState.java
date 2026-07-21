package com.qiplat.sweeteditor.core.ime;

public final class ImeState {
    public ImeResultCode resultCode = ImeResultCode.OK;
    public long sessionId = 0L;
    public long stateRevision = 0L;
    public ImeSelection selection = new ImeSelection();
    public ImeOffsetRange compositionRange = new ImeOffsetRange();

    public ImeState() {
    }

    public ImeState(ImeResultCode resultCode, long sessionId, long stateRevision, ImeSelection selection, ImeOffsetRange compositionRange) {
        this.resultCode = resultCode;
        this.sessionId = sessionId;
        this.stateRevision = stateRevision;
        this.selection = selection;
        this.compositionRange = compositionRange;
    }
}
