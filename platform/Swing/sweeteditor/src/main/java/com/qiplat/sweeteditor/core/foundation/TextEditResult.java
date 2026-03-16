package com.qiplat.sweeteditor.core.foundation;

import com.google.gson.annotations.SerializedName;

import java.util.List;

/**
 * Result of a text edit operation, carrying precise change ranges and text.
 * <p>Aligned with the C++ layer TextEditResult, JSON-serializes the changes array (each containing range + new_text).</p>
 */
public class TextEditResult {
    @SerializedName("changes") public List<TextChange> changes;

    /** Empty result (no changes) */
    public static final TextEditResult EMPTY = new TextEditResult();
}
