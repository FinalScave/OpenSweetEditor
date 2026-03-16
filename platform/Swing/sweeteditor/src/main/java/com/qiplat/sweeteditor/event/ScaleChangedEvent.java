package com.qiplat.sweeteditor.event;

/**
 * Scale ratio changed event.
 */
public final class ScaleChangedEvent extends EditorEvent {
    public final float scale;

    public ScaleChangedEvent(float scale) {
        this.scale = scale;
    }
}
