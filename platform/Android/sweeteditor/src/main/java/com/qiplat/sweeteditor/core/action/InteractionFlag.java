package com.qiplat.sweeteditor.core.action;

public final class InteractionFlag {
    private InteractionFlag() {
    }
    public static final int NONE = 0;
    public static final int PRIMARY_POINTER = 1;
    public static final int SELECTION_DRAG = 2;
    public static final int VIEWPORT_GESTURE = 4;
}
