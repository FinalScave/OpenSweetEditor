package com.qiplat.sweeteditor.core.adornment;

import androidx.annotation.Nullable;

public class InlayHint {
    public final InlayType type;
    public final int column;
    @Nullable
    public final String text;
    public final int intValue;

    public InlayHint(InlayType type, int column, @Nullable String text, int intValue) {
        this.type = type;
        this.column = column;
        this.text = text;
        this.intValue = intValue;
    }

    public static InlayHint text(int column, String text) {
        return new InlayHint(InlayType.TEXT, column, text, 0);
    }

    public static InlayHint icon(int column, int iconId) {
        return new InlayHint(InlayType.ICON, column, null, iconId);
    }

    public static InlayHint color(int column, int color) {
        return new InlayHint(InlayType.COLOR, column, null, color);
    }
}