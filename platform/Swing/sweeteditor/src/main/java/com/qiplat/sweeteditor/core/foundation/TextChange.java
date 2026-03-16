package com.qiplat.sweeteditor.core.foundation;

import com.google.gson.annotations.SerializedName;

/**
 * Single text change (exact change info at one edit location).
 * <p>Platform layer only contains range + new_text.</p>
 */
public class TextChange {
    @SerializedName("range") public TextRange range;
    @SerializedName("new_text") public String newText;
}
