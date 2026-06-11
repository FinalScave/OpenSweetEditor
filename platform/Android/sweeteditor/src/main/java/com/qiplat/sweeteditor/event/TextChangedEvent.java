package com.qiplat.sweeteditor.event;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.core.action.EditorActionSource;
import com.qiplat.sweeteditor.core.action.TextChangeKind;
import com.qiplat.sweeteditor.core.foundation.TextChange;

import java.util.Collections;
import java.util.List;

/**
 * Text content change event.
 */
public final class TextChangedEvent extends EditorEvent {
    @NonNull public final List<TextChange> changes;
    @NonNull public final TextChangeKind kind;
    @NonNull public final EditorActionSource source;

    public TextChangedEvent(@NonNull List<TextChange> changes,
                            @NonNull TextChangeKind kind,
                            @NonNull EditorActionSource source) {
        this.changes = Collections.unmodifiableList(changes);
        this.kind = kind;
        this.source = source;
    }
}
