package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a foldable region.
 */
public final class FoldRegion {
    /** Start line (0-based, this line remains visible and shows the fold placeholder) */
    public final int startLine;
    /** End line (0-based, inclusive) */
    public final int endLine;
    /** Whether the region is currently collapsed (folded) */
    public final boolean collapsed;

    public FoldRegion(int startLine, int endLine, boolean collapsed) {
        this.startLine = startLine;
        this.endLine = endLine;
        this.collapsed = collapsed;
    }
}
