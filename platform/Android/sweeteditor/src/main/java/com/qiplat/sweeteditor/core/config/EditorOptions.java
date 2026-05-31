package com.qiplat.sweeteditor.core.config;

public final class EditorOptions {
    public float touchSlop = 10f;
    public long doubleTapTimeout = 300L;
    public long longPressMs = 500L;
    public float flingFriction = 3.5f;
    public float flingMinVelocity = 50.0f;
    public float flingMaxVelocity = 8000.0f;
    public long maxUndoStackSize = 512L;
    public long keyChordTimeoutMs = 2000L;
    public boolean revealSelectionEndOnSelectAll = false;

    public EditorOptions() {
    }

    public EditorOptions(float touchSlop, long doubleTapTimeout, long longPressMs, float flingFriction, float flingMinVelocity, float flingMaxVelocity, long maxUndoStackSize, long keyChordTimeoutMs, boolean revealSelectionEndOnSelectAll) {
        this.touchSlop = touchSlop;
        this.doubleTapTimeout = doubleTapTimeout;
        this.longPressMs = longPressMs;
        this.flingFriction = flingFriction;
        this.flingMinVelocity = flingMinVelocity;
        this.flingMaxVelocity = flingMaxVelocity;
        this.maxUndoStackSize = maxUndoStackSize;
        this.keyChordTimeoutMs = keyChordTimeoutMs;
        this.revealSelectionEndOnSelectAll = revealSelectionEndOnSelectAll;
    }
}
