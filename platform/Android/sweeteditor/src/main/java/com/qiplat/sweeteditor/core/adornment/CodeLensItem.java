package com.qiplat.sweeteditor.core.adornment;

public final class CodeLensItem {
    public int column = 0;
    public int commandId = 0;
    public String text = "";

    public CodeLensItem() {
    }

    public CodeLensItem(int column, int commandId, String text) {
        this.column = column;
        this.commandId = commandId;
        this.text = text;
    }
}
