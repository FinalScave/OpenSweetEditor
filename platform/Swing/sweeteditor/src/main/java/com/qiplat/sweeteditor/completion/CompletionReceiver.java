package com.qiplat.sweeteditor.completion;

/**
 * Async callback interface, aligned with DecorationReceiver.
 */
public interface CompletionReceiver {
    boolean accept(CompletionResult result);
    boolean isCancelled();
}
