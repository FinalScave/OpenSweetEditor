package com.qiplat.sweeteditor.core.ime;

import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

public class ImeSyncSnapshot {
    public TextPosition cursor = new TextPosition(0, 0);
    public TextRange selection;
    public boolean hasComposingSession;
    public TextRange visibleCompositionRange;
    public TextRange platformMarkedRange;
    public int preeditStorage = ImePreeditStorage.NONE;
    public int contextPolicy = ImeContextPolicy.NONE;
    public boolean clearPlatformPreedit;
}
