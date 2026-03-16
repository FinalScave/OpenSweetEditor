package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;
import com.qiplat.sweeteditor.core.foundation.TextEditResult;

public class KeyEventResult {
    @SerializedName("handled") public boolean handled;
    @SerializedName("content_changed") public boolean contentChanged;
    @SerializedName("cursor_changed") public boolean cursorChanged;
    @SerializedName("selection_changed") public boolean selectionChanged;
    @SerializedName("edit_result") public TextEditResult editResult;
}
