package com.qiplat.sweeteditor.event;

/**
 * Scroll position changed event.
 */
public final class ScrollChangedEvent extends EditorEvent {
    public final float scrollX;
    public final float scrollY;

    public ScrollChangedEvent(float scrollX, float scrollY) {
        this.scrollX = scrollX;
        this.scrollY = scrollY;
    }
}
