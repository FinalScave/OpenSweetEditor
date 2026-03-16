package com.qiplat.sweeteditor.event;

/**
 * Editor event listener (functional interface).
 *
 * @param <T> Event type
 */
@FunctionalInterface
public interface EditorEventListener<T extends EditorEvent> {
    void onEvent(T event);
}
