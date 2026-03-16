package com.qiplat.sweeteditor.event;

import java.awt.Point;

/**
 * InlayHint click event.
 * <p>Triggered when the user clicks on an InlayHint (text type, icon type, or color block type).</p>
 */
public final class InlayHintClickEvent extends EditorEvent {
    /** The line number where the InlayHint is located (0-based) */
    public final int line;
    /** The column number where the InlayHint is located (0-based) */
    public final int column;
    /** Icon ID (>0 indicates icon type, 0 indicates other types) */
    public final int iconId;
    /** Whether it is an icon type */
    public final boolean isIcon;
    /** Whether it is a color block type */
    public final boolean isColor;
    /** Color value (ARGB, only valid for color block type) */
    public final int colorValue;
    /** Screen coordinates at the time of click */
    public final Point screenPoint;

    /** Text/icon type constructor */
    public InlayHintClickEvent(int line, int column, int iconId, boolean isIcon, Point screenPoint) {
        this.line = line;
        this.column = column;
        this.iconId = iconId;
        this.isIcon = isIcon;
        this.isColor = false;
        this.colorValue = 0;
        this.screenPoint = screenPoint;
    }

    /** Color block type constructor */
    public InlayHintClickEvent(int line, int column, int colorValue, Point screenPoint) {
        this.line = line;
        this.column = column;
        this.iconId = 0;
        this.isIcon = false;
        this.isColor = true;
        this.colorValue = colorValue;
        this.screenPoint = screenPoint;
    }
}
