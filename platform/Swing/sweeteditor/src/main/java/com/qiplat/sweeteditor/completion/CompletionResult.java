package com.qiplat.sweeteditor.completion;

import java.util.List;

/**
 * Completion result returned by a provider: candidate list + whether there are more.
 */
public class CompletionResult {
    public final List<CompletionItem> items;
    public final boolean isIncomplete;

    public CompletionResult(List<CompletionItem> items, boolean isIncomplete) {
        this.items = items;
        this.isIncomplete = isIncomplete;
    }

    public CompletionResult(List<CompletionItem> items) {
        this(items, false);
    }
}
