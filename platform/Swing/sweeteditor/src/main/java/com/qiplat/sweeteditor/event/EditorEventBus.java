package com.qiplat.sweeteditor.event;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Generic editor event bus (platform layer event system).
 * <p>Dispatches by event Class, each event type has an independent subscriber list. Thread-safe, supports multiple subscribers.</p>
 */
public final class EditorEventBus {

    private final Map<Class<? extends EditorEvent>, CopyOnWriteArrayList<EditorEventListener<?>>> listeners
            = new ConcurrentHashMap<>();

    public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener) {
        listeners.computeIfAbsent(eventType, k -> new CopyOnWriteArrayList<>()).addIfAbsent(listener);
    }

    public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener) {
        CopyOnWriteArrayList<EditorEventListener<?>> list = listeners.get(eventType);
        if (list != null) {
            list.remove(listener);
        }
    }

    @SuppressWarnings("unchecked")
    public <T extends EditorEvent> void publish(T event) {
        CopyOnWriteArrayList<EditorEventListener<?>> list = listeners.get(event.getClass());
        if (list == null || list.isEmpty()) return;
        for (EditorEventListener<?> listener : list) {
            ((EditorEventListener<T>) listener).onEvent(event);
        }
    }

    public void clear() {
        listeners.clear();
    }
}
