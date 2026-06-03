package com.qiplat.sweeteditor.perf;

public final class PerfStepRecorder {
    private static final int MAX_STEPS = 32;

    public static final String STEP_PREP = "prep";
    public static final String STEP_BUILD = "build";
    public static final String STEP_CLEAR = "clear";
    public static final String STEP_CURRENT = "current";
    public static final String STEP_RANGE_EFFECT_BACKGROUNDS = "rangeBg";
    public static final String STEP_LINES = "lines";
    public static final String STEP_GUIDES = "guides";
    public static final String STEP_RANGE_EFFECT_OVERLAYS = "rangeFx";
    public static final String STEP_CURSOR = "cursor";
    public static final String STEP_GUTTER = "gutter";
    public static final String STEP_LINE_NO = "lineNo";
    public static final String STEP_SCROLLBARS = "scrollbars";

    private final String[] stepNames = new String[MAX_STEPS];
    private final long[] stepNanos = new long[MAX_STEPS];
    private final long startNanos;
    private long lastNanos;
    private long endNanos;
    private int stepCount;

    private PerfStepRecorder() {
        startNanos = System.nanoTime();
        lastNanos = startNanos;
    }

    public static PerfStepRecorder start() {
        return new PerfStepRecorder();
    }

    public void mark(String stepName) {
        long now = System.nanoTime();
        if (stepCount < MAX_STEPS) {
            stepNames[stepCount] = stepName;
            stepNanos[stepCount] = now - lastNanos;
            stepCount++;
        }
        lastNanos = now;
    }

    public void finish() {
        if (endNanos == 0L) {
            endNanos = System.nanoTime();
        }
    }

    public float getTotalMs() {
        long end = endNanos != 0L ? endNanos : System.nanoTime();
        return (end - startNanos) / 1_000_000f;
    }

    public float getStepMs(String stepName) {
        for (int i = 0; i < stepCount; i++) {
            if (stepName.equals(stepNames[i])) {
                return stepNanos[i] / 1_000_000f;
            }
        }
        return 0f;
    }

    public boolean anyStepOver(float thresholdMs) {
        for (int i = 0; i < stepCount; i++) {
            if (stepNanos[i] / 1_000_000f >= thresholdMs) {
                return true;
            }
        }
        return false;
    }

    public int getStepCount() {
        return stepCount;
    }

    public String getStepName(int index) {
        return index >= 0 && index < stepCount ? stepNames[index] : "";
    }

    public float getStepMsByIndex(int index) {
        return index >= 0 && index < stepCount ? stepNanos[index] / 1_000_000f : 0f;
    }
}
