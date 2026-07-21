package com.qiplat.sweeteditor.core.ime;

import java.util.List;

public final class ImeTextUpdateBatch {
    public long sessionId = 0L;
    public long expectedStateRevision = 0L;
    public java.util.List<ImeTextUpdateStep> steps = new java.util.ArrayList<>();

    public ImeTextUpdateBatch() {
    }

    public ImeTextUpdateBatch(long sessionId, long expectedStateRevision, java.util.List<ImeTextUpdateStep> steps) {
        this.sessionId = sessionId;
        this.expectedStateRevision = expectedStateRevision;
        this.steps = steps;
    }
}
