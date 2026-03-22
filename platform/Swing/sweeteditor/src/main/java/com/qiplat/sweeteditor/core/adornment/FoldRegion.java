package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a foldable region.
 */
public final class FoldRegion {
    /** Start line (0-based, this line remains visible and shows the fold placeholder) */
    public final int startLine;
    /** End line (0-based, inclusive) */
    public final int endLine;

    public FoldRegion(int startLine, int endLine) {
        this.startLine = startLine;
        this.endLine = endLine;
    }
}
