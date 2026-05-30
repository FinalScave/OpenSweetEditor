package com.qiplat.sweeteditor.core.interaction;

import com.qiplat.sweeteditor.core.foundation.PointF;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import java.util.List;

public final class GestureEvent {
    public EventType type = EventType.UNDEFINED;
    public java.util.List<PointF> points = new java.util.ArrayList<>();
    public int modifiers = KeyModifier.NONE;
    public float wheelDeltaX = 0f;
    public float wheelDeltaY = 0f;
    public float directScale = 1f;

    public GestureEvent() {
    }

    public GestureEvent(EventType type, java.util.List<PointF> points, int modifiers, float wheelDeltaX, float wheelDeltaY, float directScale) {
        this.type = type;
        this.points = points;
        this.modifiers = modifiers;
        this.wheelDeltaX = wheelDeltaX;
        this.wheelDeltaY = wheelDeltaY;
        this.directScale = directScale;
    }
}
