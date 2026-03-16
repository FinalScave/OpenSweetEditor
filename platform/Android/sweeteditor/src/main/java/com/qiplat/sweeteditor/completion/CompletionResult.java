package com.qiplat.sweeteditor.completion;

import androidx.annotation.NonNull;
import java.util.Collections;
import java.util.List;

/**
 * Completion result returned by a provider.
 */
public final class CompletionResult {

    public static final CompletionResult EMPTY = new CompletionResult(Collections.emptyList(), false);

    @NonNull public final List<CompletionItem> items;
    /** Whether the result is incomplete (when true, subsequent input should continue requesting) */
    public final boolean isIncomplete;

    public CompletionResult(@NonNull List<CompletionItem> items, boolean isIncomplete) {
        this.items = items;
        this.isIncomplete = isIncomplete;
    }
}
