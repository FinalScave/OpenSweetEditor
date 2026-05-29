package com.qiplat.sweeteditor.core.foundation;

public final class TextRange {
    public TextPosition start = new TextPosition();
    public TextPosition end = new TextPosition();

    public TextRange() {
    }

    public TextRange(TextPosition start, TextPosition end) {
        this.start = start;
        this.end = end;
    }

    public boolean isCollapsed() {
        return start.line == end.line && start.column == end.column;
    }

    @Override
    public String toString() {
        return "TextRange{"
                + "start=" + start
                + ", end=" + end
                + "}";
    }
}
