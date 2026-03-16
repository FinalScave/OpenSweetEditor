package com.qiplat.sweeteditor.completion;

import androidx.annotation.NonNull;

/**
 * Completion provider interface.
 * <p>Host applications implement this interface to provide completion candidates.</p>
 */
public interface CompletionProvider {
    /**
     * Determine if the specified character triggers auto-completion (e.g., ".", ":", "<").
     * @param ch the input character
     * @return true if completion should be triggered
     */
    boolean isTriggerCharacter(@NonNull String ch);

    /**
     * Asynchronously provide completion candidates.
     * <p>Provider should complete computation on a background thread and submit results via receiver.accept().</p>
     * @param context completion context
     * @param receiver result callback
     */
    void provideCompletions(@NonNull CompletionContext context, @NonNull CompletionReceiver receiver);
}
