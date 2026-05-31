package com.qiplat.sweeteditor.core.adornment;

public final class InlayHint {
    public InlayType type = InlayType.TEXT;
    public int column = 0;
    public int intValue = 0;
    public String text = "";

    public InlayHint() {
    }

    public InlayHint(InlayType type, int column, int intValue, String text) {
        this.type = type;
        this.column = column;
        this.intValue = intValue;
        this.text = text;
    }

    public static InlayHint text(int column, String text) {
        return new InlayHint(InlayType.TEXT, column, 0, text != null ? text : "");
    }

    public static InlayHint icon(int column, int iconId) {
        return new InlayHint(InlayType.ICON, column, iconId, "");
    }

    public static InlayHint color(int column, int color) {
        return new InlayHint(InlayType.COLOR, column, color, "");
    }
}
