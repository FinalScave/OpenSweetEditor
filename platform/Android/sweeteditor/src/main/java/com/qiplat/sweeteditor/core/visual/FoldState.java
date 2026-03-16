package com.qiplat.sweeteditor.core.visual;

/**
 * Fold state enum (corresponds to C++ FoldState)
 */
public enum FoldState {
    /** First line of non-folded region */
    NONE,
    /** Expandable (expanded state, click to collapse) */
    EXPANDED,
    /** Collapsed (click to expand) */
    COLLAPSED,
}
