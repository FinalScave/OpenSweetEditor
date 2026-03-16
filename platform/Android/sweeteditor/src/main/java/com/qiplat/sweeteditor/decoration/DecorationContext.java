package com.qiplat.sweeteditor.decoration;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.LanguageConfiguration;
import com.qiplat.sweeteditor.core.EditorCore;

import java.util.Collections;
import java.util.List;

public final class DecorationContext {
    public final int visibleStartLine;
    public final int visibleEndLine;
    public final int totalLineCount;
    /** All text changes accumulated during this refresh cycle (immutable view), empty list indicates non-text-change trigger */
    @NonNull
    public final List<EditorCore.TextChange> textChanges;
    /** Current language configuration (from LanguageConfiguration) */
    @Nullable
    public final LanguageConfiguration languageConfiguration;

    public DecorationContext(int visibleStartLine, int visibleEndLine, int totalLineCount,
                             @NonNull List<EditorCore.TextChange> textChanges,
                             @Nullable LanguageConfiguration languageConfiguration) {
        this.visibleStartLine = visibleStartLine;
        this.visibleEndLine = visibleEndLine;
        this.totalLineCount = totalLineCount;
        this.textChanges = Collections.unmodifiableList(textChanges);
        this.languageConfiguration = languageConfiguration;
    }
}
