package com.qiplat.sweeteditor.core.config;

public final class EditorRenderColors {
    public int textForeground = 0;
    public int selectionForeground = 0;
    public int linkForeground = 0;
    public int activeLinkForeground = 0;
    public int codelensForeground = 0;
    public int activeCodelensForeground = 0;

    public EditorRenderColors() {
    }

    public EditorRenderColors(int textForeground, int selectionForeground, int linkForeground, int activeLinkForeground, int codelensForeground, int activeCodelensForeground) {
        this.textForeground = textForeground;
        this.selectionForeground = selectionForeground;
        this.linkForeground = linkForeground;
        this.activeLinkForeground = activeLinkForeground;
        this.codelensForeground = codelensForeground;
        this.activeCodelensForeground = activeCodelensForeground;
    }
}
