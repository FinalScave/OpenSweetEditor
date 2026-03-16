package com.qiplat.sweeteditor.event;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Text content change event.
 * <p>
 * Carries the changed range and new text, allowing subscribers to perform incremental
 * processing (e.g., syntax highlighting, synchronization, etc.).
 */
public final class TextChangedEvent extends EditorEvent {
    @NonNull public final TextChangeAction action;
    /** The replaced/deleted text range (coordinates before the operation), null if information is unavailable */
    @Nullable public final TextRange changeRange;
    /** The new text after the change (inserted/replaced content), null if unavailable; empty string indicates pure deletion */
    @Nullable public final String text;

    public TextChangedEvent(@NonNull TextChangeAction action, @Nullable TextRange changeRange, @Nullable String text) {
        this.action = action;
        this.changeRange = changeRange;
        this.text = text;
    }
}
