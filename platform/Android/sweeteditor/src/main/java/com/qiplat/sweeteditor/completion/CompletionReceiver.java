package com.qiplat.sweeteditor.completion;

import androidx.annotation.NonNull;

/**
 * Async callback interface for providers to submit completion results.
 * <p>Aligned with DecorationReceiver design.</p>
 */
public interface CompletionReceiver {
    /**
     * Submit completion result.
     * @param result completion result
     * @return true if result was accepted, false if stale/cancelled
     */
    boolean accept(@NonNull CompletionResult result);

    /**
     * Providers can poll this during long-running computations for early cancellation.
     */
    boolean isCancelled();
}
