package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a single gutter icon.
 * <p>
 * Each GutterIcon represents an icon to be displayed in the gutter area,
 * commonly used for breakpoints, bookmarks, error markers, and similar scenarios.
 */
public final class GutterIcon {
    /** Icon resource ID */
    public final int iconId;

    /**
     * @param iconId Icon resource ID
     */
    public GutterIcon(int iconId) {
        this.iconId = iconId;
    }
}
