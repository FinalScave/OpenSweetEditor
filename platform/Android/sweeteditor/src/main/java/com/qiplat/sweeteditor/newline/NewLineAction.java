package com.qiplat.sweeteditor.newline;

import androidx.annotation.NonNull;

/**
 * Newline action result, describing the text to be inserted after pressing Enter.
 */
public class NewLineAction {
    /** Full text to insert (includes newline and indent) */
    @NonNull
    public final String text;

    public NewLineAction(@NonNull String text) {
        this.text = text;
    }
}
