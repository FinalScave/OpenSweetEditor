package com.qiplat.sweeteditor.core.ime;

import com.qiplat.sweeteditor.core.foundation.TextEditResult;

public class ImeActionResult {
    public boolean handled;
    public boolean contentChanged;
    public boolean cursorChanged;
    public boolean selectionChanged;
    public TextEditResult editResult = TextEditResult.EMPTY;
    public ImeSyncSnapshot sync = new ImeSyncSnapshot();
}
