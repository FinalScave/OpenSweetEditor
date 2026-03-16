package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Text changed event.
 */
public final class TextChangedEvent extends EditorEvent {
    /** Action type */
    public final TextChangeAction action;
    /** Replaced/deleted text range (coordinates before the operation), may be null */
    public final TextRange changeRange;
    /** New text after the change (inserted/replaced content), may be null */
    public final String text;

    public TextChangedEvent(TextChangeAction action, TextRange changeRange, String text) {
        this.action = action;
        this.changeRange = changeRange;
        this.text = text;
    }
}
