package com.qiplat.sweeteditor.event;

/**
 * Editor event listener (functional interface, supports Lambda).
 * <p>
 * Used with {@link EditorEventBus}, subscribe by event type:
 * <pre>
 * editor.subscribe(TextChangedEvent.class, e -> Log.d(TAG, "action: " + e.action));
 * editor.subscribe(CursorChangedEvent.class, e -> updateStatusBar(e.cursorPosition));
 * </pre>
 *
 * @param <T> the event type, must be a subclass of {@link EditorEvent}
 */
@FunctionalInterface
public interface EditorEventListener<T extends EditorEvent> {
    void onEvent(T event);
}
