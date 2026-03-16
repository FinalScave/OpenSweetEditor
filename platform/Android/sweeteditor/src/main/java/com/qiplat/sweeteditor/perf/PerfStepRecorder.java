package com.qiplat.sweeteditor.perf;

/**
 * Step-by-step performance timer for recording the duration of each sub-phase in an operation.
 * <p>
 * Usage:
 * <pre>
 * PerfStepRecorder perf = PerfStepRecorder.start();
 * // ... step 1 ...
 * perf.mark("build");
 * // ... step 2 ...
 * perf.mark("draw");
 * perf.getTotalMs(); // total duration
 * perf.getStepMs("build"); // duration of a specific step
 * </pre>
 */
public final class PerfStepRecorder {
    private static final int MAX_STEPS = 32;

    // Render phase name constants
    public static final String STEP_BUILD = "build";
    public static final String STEP_CLEAR = "clear";
    public static final String STEP_CURRENT = "current";
    public static final String STEP_SELECTION = "selection";
    public static final String STEP_LINES = "lines";
    public static final String STEP_GUIDES = "guides";
    public static final String STEP_COMPOSITION = "comp";
    public static final String STEP_DIAGNOSTICS = "diag";
    public static final String STEP_LINKED = "linked";
    public static final String STEP_BRACKET = "bracket";
    public static final String STEP_CURSOR = "cursor";
    public static final String STEP_GUTTER = "gutter";
    public static final String STEP_LINE_NO = "lineNo";
    public static final String STEP_HANDLES = "handles";

    private final String[] stepNames = new String[MAX_STEPS];
    private final long[] stepNanos = new long[MAX_STEPS];
    private int stepCount = 0;
    private final long startNanos;
    private long lastNanos;
    private long endNanos = 0; // 0 means not yet finished

    private PerfStepRecorder() {
        startNanos = System.nanoTime();
        lastNanos = startNanos;
    }

    public static PerfStepRecorder start() {
        return new PerfStepRecorder();
    }

    /** Mark the end of a step, record the time difference from the previous mark */
    public void mark(String stepName) {
        long now = System.nanoTime();
        if (stepCount < MAX_STEPS) {
            stepNames[stepCount] = stepName;
            stepNanos[stepCount] = now - lastNanos;
            stepCount++;
        }
        lastNanos = now;
    }

    /**
     * Lock the end time. After calling, getTotalMs() returns a fixed value,
     * no longer changing with System.nanoTime(). Should be called immediately after the last mark().
     */
    public void finish() {
        if (endNanos == 0) {
            endNanos = System.nanoTime();
        }
    }

    /** Get total duration (milliseconds). If finished, returns locked value, otherwise returns duration up to current time */
    public float getTotalMs() {
        long end = endNanos != 0 ? endNanos : System.nanoTime();
        return (end - startNanos) / 1_000_000f;
    }

    /** Get duration of a specific step (milliseconds) */
    public float getStepMs(String stepName) {
        for (int i = 0; i < stepCount; i++) {
            if (stepNames[i].equals(stepName)) {
                return stepNanos[i] / 1_000_000f;
            }
        }
        return 0f;
    }

    /** Check if any step exceeds the threshold */
    public boolean anyStepOver(float thresholdMs) {
        for (int i = 0; i < stepCount; i++) {
            if (stepNanos[i] / 1_000_000f >= thresholdMs) return true;
        }
        return false;
    }

    /** Build a summary string of all steps (single line) */
    public String buildSummary() {
        StringBuilder sb = new StringBuilder();
        sb.append(String.format("total=%.2fms", getTotalMs()));
        for (int i = 0; i < stepCount; i++) {
            sb.append(String.format(" %s=%.2fms", stepNames[i], stepNanos[i] / 1_000_000f));
        }
        return sb.toString();
    }

    /** Get the number of steps */
    public int getStepCount() {
        return stepCount;
    }

    /** Get the name of the step at index */
    public String getStepName(int index) {
        return (index >= 0 && index < stepCount) ? stepNames[index] : "";
    }

    /** Get the duration of the step at index (milliseconds) */
    public float getStepMsByIndex(int index) {
        return (index >= 0 && index < stepCount) ? stepNanos[index] / 1_000_000f : 0f;
    }
}
