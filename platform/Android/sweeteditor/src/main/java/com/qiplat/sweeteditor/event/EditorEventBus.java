package com.qiplat.sweeteditor.event;

import androidx.annotation.NonNull;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Generic editor event bus (platform layer event system).
 * <p>
 * Dispatches by event Class, each event type has its own subscriber list.
 * Thread-safe, supports multiple subscribers.
 *
 * <pre>
 * bus.subscribe(TextChangedEvent.class, e -> { ... });
 * bus.publish(new TextChangedEvent("insert"));
 * </pre>
 */
public final class EditorEventBus {

    private final Map<Class<? extends EditorEvent>, CopyOnWriteArrayList<EditorEventListener<?>>> mListeners
            = new ConcurrentHashMap<>();

    /**
     * Subscribe to a specific type of event.
     *
     * @param eventType the event Class
     * @param listener  Lambda or method reference
     * @param <T>       the event type
     */
    public <T extends EditorEvent> void subscribe(@NonNull Class<T> eventType, @NonNull EditorEventListener<T> listener) {
        CopyOnWriteArrayList<EditorEventListener<?>> list = mListeners.get(eventType);
        if (list == null) {
            list = new CopyOnWriteArrayList<>();
            mListeners.put(eventType, list);
        }
        list.addIfAbsent(listener);
    }

    /**
     * Unsubscribe from a specific type of event.
     */
    public <T extends EditorEvent> void unsubscribe(@NonNull Class<T> eventType, @NonNull EditorEventListener<T> listener) {
        CopyOnWriteArrayList<EditorEventListener<?>> list = mListeners.get(eventType);
        if (list != null) {
            list.remove(listener);
        }
    }

    /**
     * Publish an event, notifying all subscribers of that type.
     */
    @SuppressWarnings("unchecked")
    public <T extends EditorEvent> void publish(@NonNull T event) {
        CopyOnWriteArrayList<EditorEventListener<?>> list = mListeners.get(event.getClass());
        if (list == null || list.isEmpty()) return;
        for (EditorEventListener<?> listener : list) {
            ((EditorEventListener<T>) listener).onEvent(event);
        }
    }

    /**
     * Clear all subscriptions.
     */
    public void clear() {
        mListeners.clear();
    }
}
