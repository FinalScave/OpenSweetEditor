package com.qiplat.sweeteditor.core.visual;

/**
 * Hit target type (aligned with C++ HitTargetType).
 * <p>Gson deserializes JSON strings directly by enum name.</p>
 */
public enum HitTargetType {
    /** Did not hit any special target */
    NONE(0),
    /** Hit an InlayHint (text type) */
    INLAY_HINT_TEXT(1),
    /** Hit an InlayHint (icon type) */
    INLAY_HINT_ICON(2),
    /** Hit a gutter icon in the line number area */
    GUTTER_ICON(3),
    /** Hit a fold placeholder (click to expand the folded region) */
    FOLD_PLACEHOLDER(4),
    /** Hit a fold arrow in the gutter (click to toggle fold/unfold) */
    FOLD_GUTTER(5),
    /** Hit an InlayHint (color block type) */
    INLAY_HINT_COLOR(6),
    /** Hit a CodeLens item */
    CODELENS(7),
    /** Hit an embedded clickable link */
    LINK(8);

    public final int value;

    HitTargetType(int v) { value = v; }

    public static HitTargetType fromValue(int v) {
        for (HitTargetType e : values()) if (e.value == v) return e;
        return NONE;
    }
}
