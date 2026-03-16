package com.qiplat.sweeteditor.perf;

/**
 * Per-frame text measurement performance statistics.
 * <p>
 * Call {@link #reset()} at the start of each frame, record in each measurement callback,
 * after frame ends, get summary via {@link #buildSummary()}.
 */
public final class MeasurePerfStats {
    // Text measurement
    private int textCount;
    private long textNanosTotal;
    private long textNanosMax;
    private int textMaxLen;
    private int textMaxStyle;
    // InlayHint measurement
    private int inlayCount;
    private long inlayNanosTotal;
    private long inlayNanosMax;
    private int inlayMaxLen;
    // Icon measurement
    private int iconCount;
    private long iconNanosTotal;
    private long iconNanosMax;

    public void reset() {
        textCount = 0;
        textNanosTotal = 0;
        textNanosMax = 0;
        textMaxLen = 0;
        textMaxStyle = 0;
        inlayCount = 0;
        inlayNanosTotal = 0;
        inlayNanosMax = 0;
        inlayMaxLen = 0;
        iconCount = 0;
        iconNanosTotal = 0;
        iconNanosMax = 0;
    }

    public void recordText(long elapsedNanos, int textLen, int fontStyle) {
        textCount++;
        textNanosTotal += elapsedNanos;
        if (elapsedNanos > textNanosMax) {
            textNanosMax = elapsedNanos;
            textMaxLen = textLen;
            textMaxStyle = fontStyle;
        }
    }

    public void recordInlay(long elapsedNanos, int textLen) {
        inlayCount++;
        inlayNanosTotal += elapsedNanos;
        if (elapsedNanos > inlayNanosMax) {
            inlayNanosMax = elapsedNanos;
            inlayMaxLen = textLen;
        }
    }

    public void recordIcon(long elapsedNanos) {
        iconCount++;
        iconNanosTotal += elapsedNanos;
        if (elapsedNanos > iconNanosMax) {
            iconNanosMax = elapsedNanos;
        }
    }

    /** Whether total measurement duration is worth logging */
    public boolean shouldLog() {
        return textNanosTotal / 1_000_000f >= 2.0f || inlayNanosTotal / 1_000_000f >= 1.0f;
    }

    public String buildSummary() {
        return String.format(
                "measure{text=%d/%.2fms max=%.2fms(len=%d,style=%d) inlay=%d/%.2fms icon=%d/%.2fms}",
                textCount, textNanosTotal / 1_000_000f, textNanosMax / 1_000_000f,
                textMaxLen, textMaxStyle,
                inlayCount, inlayNanosTotal / 1_000_000f,
                iconCount, iconNanosTotal / 1_000_000f);
    }
}
