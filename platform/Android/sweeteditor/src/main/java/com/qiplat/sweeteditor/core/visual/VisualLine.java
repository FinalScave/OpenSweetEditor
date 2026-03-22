package com.qiplat.sweeteditor.core.visual;

import com.google.gson.annotations.SerializedName;

import java.util.List;

/**
 * Visual rendered line data definition.
 */
public class VisualLine {
    /** Logical line number. */
    @SerializedName("logical_line")
    public int logicalLine;

    /** Wrap index in auto-wrap mode (0 = first line, 1,2,... = continuation). */
    @SerializedName("wrap_index")
    public int wrapIndex;

    /** Line number position. */
    @SerializedName("line_number_position")
    public PointF lineNumberPosition;

    /** Text runs contained in this visual line. */
    @SerializedName("runs")
    public List<VisualRun> runs;

    /** Whether this is a phantom text continuation line (2nd/3rd... line of cross-line phantom text). */
    @SerializedName("is_phantom_line")
    public boolean isPhantomLine;

    /** Fold state: NONE=not a fold line, EXPANDED=foldable (expanded), COLLAPSED=folded. */
    @SerializedName("fold_state")
    public FoldState foldState;
}
