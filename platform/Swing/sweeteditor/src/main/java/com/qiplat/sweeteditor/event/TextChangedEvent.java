package com.qiplat.sweeteditor.event;

import com.qiplat.sweeteditor.core.action.EditorActionSource;
import com.qiplat.sweeteditor.core.action.TextChangeKind;
import com.qiplat.sweeteditor.core.foundation.TextChange;

import java.util.Collections;
import java.util.List;

/**
 * Text changed event.
 */
public final class TextChangedEvent extends EditorEvent {
    /** Full incremental text changes for the current edit cycle. */
    public final List<TextChange> changes;
    /** Semantic kind of document text changes. */
    public final TextChangeKind kind;
    /** Origin of the editor action that produced this change. */
    public final EditorActionSource source;

    public TextChangedEvent(List<TextChange> changes, TextChangeKind kind, EditorActionSource source) {
        this.changes = changes != null ? Collections.unmodifiableList(changes) : Collections.emptyList();
        this.kind = kind;
        this.source = source;
    }
}
