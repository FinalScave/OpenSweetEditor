package com.qiplat.sweeteditor.core.ime;

import java.util.List;

public final class ImeCommandBatch {
    public long sessionId = 0L;
    public java.util.List<ImeCommand> commands = new java.util.ArrayList<>();

    public ImeCommandBatch() {
    }

    public ImeCommandBatch(long sessionId, java.util.List<ImeCommand> commands) {
        this.sessionId = sessionId;
        this.commands = commands;
    }
}
