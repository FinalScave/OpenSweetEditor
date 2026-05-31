package com.qiplat.sweeteditor.core.ime;

import com.qiplat.sweeteditor.core.foundation.TextRange;

public final class ImeTextReplacement {
    public TextRange range = new TextRange();
    public String text = "";
    public ImeScriptClass scriptClass = ImeScriptClass.UNKNOWN;

    public ImeTextReplacement() {
    }

    public ImeTextReplacement(TextRange range, String text, ImeScriptClass scriptClass) {
        this.range = range;
        this.text = text;
        this.scriptClass = scriptClass;
    }
}
