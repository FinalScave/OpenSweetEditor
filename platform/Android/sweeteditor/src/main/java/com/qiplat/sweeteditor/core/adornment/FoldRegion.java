package com.qiplat.sweeteditor.core.adornment;

/**
 * Immutable value object representing a foldable region.
 * <p>
 * A fold region defines a code segment that can be collapsed (folded).
 * When collapsed, lines from startLine+1 to endLine will be hidden.
 */
public final class FoldRegion {
    /** Start line (0-based, this line remains visible and shows the fold placeholder) */
    public final int startLine;
    /** End line (0-based, inclusive) */
    public final int endLine;
    /** Whether the region is currently collapsed (folded) */
    public final boolean collapsed;

    /**
     * @param startLine Start line (0-based)
     * @param endLine   End line (0-based, inclusive)
     * @param collapsed Whether the region is collapsed
     */
    public FoldRegion(int startLine, int endLine, boolean collapsed) {
        this.startLine = startLine;
        this.endLine = endLine;
        this.collapsed = collapsed;
    }
}
