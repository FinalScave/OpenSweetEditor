package com.qiplat.sweeteditor.completion;

import androidx.annotation.NonNull;
import androidx.annotation.MainThread;

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
     * <p>This method is invoked on the main/UI thread. Providers MAY offload heavy computation
     * to a background thread and later submit results via {@code receiver.accept()}.</p>
     * @param context completion context
     * @param receiver result callback
     */
    @MainThread
    void provideCompletions(@NonNull CompletionContext context, @NonNull CompletionReceiver receiver);
}
