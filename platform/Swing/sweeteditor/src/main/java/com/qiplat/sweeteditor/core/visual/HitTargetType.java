package com.qiplat.sweeteditor.core.visual;

/**
 * Hit target type (aligned with C++ HitTargetType).
 * <p>Gson deserializes JSON strings directly by enum name.</p>
 */
public enum HitTargetType {
    /** Did not hit any special target */
    NONE,
    /** Hit an InlayHint (text type) */
    INLAY_HINT_TEXT,
    /** Hit an InlayHint (icon type) */
    INLAY_HINT_ICON,
    /** Hit a gutter icon in the line number area */
    GUTTER_ICON,
    /** Hit a fold placeholder (click to expand the folded region) */
    FOLD_PLACEHOLDER,
    /** Hit a fold arrow in the gutter (click to toggle fold/unfold) */
    FOLD_GUTTER,
    /** Hit an InlayHint (color block type) */
    INLAY_HINT_COLOR
}
