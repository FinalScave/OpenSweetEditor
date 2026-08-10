package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.PointF;
import java.util.List;

public final class VisualLine {
    public int logicalLine = 0;
    public int wrapIndex = 0;
    public PointF lineNumberPosition = new PointF();
    public java.util.List<VisualRun> runs = new java.util.ArrayList<>();
    public VisualLineKind kind = VisualLineKind.CONTENT;
    public boolean ownsGutterSemantics = false;
    public FoldState foldState = FoldState.NONE;
    public int lineNumber = -1;
    public int lineBackgroundColor = 0;
    public int gutterBackgroundColor = 0;

    public VisualLine() {
    }

    public VisualLine(int logicalLine, int wrapIndex, PointF lineNumberPosition, java.util.List<VisualRun> runs, VisualLineKind kind, boolean ownsGutterSemantics, FoldState foldState, int lineNumber, int lineBackgroundColor, int gutterBackgroundColor) {
        this.logicalLine = logicalLine;
        this.wrapIndex = wrapIndex;
        this.lineNumberPosition = lineNumberPosition;
        this.runs = runs;
        this.kind = kind;
        this.ownsGutterSemantics = ownsGutterSemantics;
        this.foldState = foldState;
        this.lineNumber = lineNumber;
        this.lineBackgroundColor = lineBackgroundColor;
        this.gutterBackgroundColor = gutterBackgroundColor;
    }
}
