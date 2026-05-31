package com.qiplat.sweeteditor.core.foundation;

public final class IntRange {
    public int start = 0;
    public int end = -1;

    public IntRange() {
    }

    public IntRange(int start, int end) {
        this.start = start;
        this.end = end;
    }

    public boolean isEmpty() {
        return end < start;
    }

    public boolean contains(int value) {
        return !isEmpty() && value >= start && value <= end;
    }

    public int length() {
        return isEmpty() ? 0 : (end - start + 1);
    }

    @Override
    public String toString() {
        return "IntRange{"
                + "start=" + start
                + ", end=" + end
                + "}";
    }
}
