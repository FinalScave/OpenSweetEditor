package com.qiplat.sweeteditor.completion;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import com.qiplat.sweeteditor.LanguageConfiguration;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

/**
 * Completion request context, built by Manager and passed to Provider.
 */
public final class CompletionContext {

    public enum TriggerKind {
        /** User manually triggered (Ctrl+Space, etc.) */
        INVOKED,
        /** Trigger character entered (e.g., '.') */
        CHARACTER,
        /** Re-trigger (refresh after content change) */
        RETRIGGER
    }

    @NonNull public final TriggerKind triggerKind;
    @Nullable public final String triggerCharacter;
    @NonNull public final TextPosition cursorPosition;
    @NonNull public final String lineText;
    @NonNull public final TextRange wordRange;
    @Nullable public final LanguageConfiguration languageConfiguration;

    public CompletionContext(@NonNull TriggerKind triggerKind,
                             @Nullable String triggerCharacter,
                             @NonNull TextPosition cursorPosition,
                             @NonNull String lineText,
                             @NonNull TextRange wordRange,
                             @Nullable LanguageConfiguration languageConfiguration) {
        this.triggerKind = triggerKind;
        this.triggerCharacter = triggerCharacter;
        this.cursorPosition = cursorPosition;
        this.lineText = lineText;
        this.wordRange = wordRange;
        this.languageConfiguration = languageConfiguration;
    }
}
