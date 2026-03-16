package com.qiplat.sweeteditor.completion;

/**
 * Completion provider interface.
 */
public interface CompletionProvider {
    boolean isTriggerCharacter(String ch);
    void provideCompletions(CompletionContext context, CompletionReceiver receiver);
}
