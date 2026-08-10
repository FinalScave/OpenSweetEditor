package com.qiplat.sweeteditor.core.config;

public final class EditorRenderColors {
    public int textForeground = 0;
    public int linkForeground = 0;
    public int activeLinkForeground = 0;
    public int codelensForeground = 0;
    public int activeCodelensForeground = 0;
    public int diffAddedLineBackground = 0;
    public int diffRemovedLineBackground = 0;
    public int diffAddedGutterBackground = 0;
    public int diffRemovedGutterBackground = 0;

    public EditorRenderColors() {
    }

    public EditorRenderColors(int textForeground, int linkForeground, int activeLinkForeground, int codelensForeground, int activeCodelensForeground, int diffAddedLineBackground, int diffRemovedLineBackground, int diffAddedGutterBackground, int diffRemovedGutterBackground) {
        this.textForeground = textForeground;
        this.linkForeground = linkForeground;
        this.activeLinkForeground = activeLinkForeground;
        this.codelensForeground = codelensForeground;
        this.activeCodelensForeground = activeCodelensForeground;
        this.diffAddedLineBackground = diffAddedLineBackground;
        this.diffRemovedLineBackground = diffRemovedLineBackground;
        this.diffAddedGutterBackground = diffAddedGutterBackground;
        this.diffRemovedGutterBackground = diffRemovedGutterBackground;
    }
}
