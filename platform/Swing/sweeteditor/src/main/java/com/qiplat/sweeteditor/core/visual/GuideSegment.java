package com.qiplat.sweeteditor.core.visual;

import com.qiplat.sweeteditor.core.foundation.PointF;

public final class GuideSegment {
    public GuideDirection direction = GuideDirection.VERTICAL;
    public GuideType type = GuideType.INDENT;
    public GuideStyle style = GuideStyle.SOLID;
    public PointF start = new PointF();
    public PointF end = new PointF();
    public boolean arrowEnd = false;

    public GuideSegment() {
    }

    public GuideSegment(GuideDirection direction, GuideType type, GuideStyle style, PointF start, PointF end, boolean arrowEnd) {
        this.direction = direction;
        this.type = type;
        this.style = style;
        this.start = start;
        this.end = end;
        this.arrowEnd = arrowEnd;
    }
}
