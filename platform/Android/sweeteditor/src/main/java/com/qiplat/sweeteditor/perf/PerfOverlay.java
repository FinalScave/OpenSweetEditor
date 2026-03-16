package com.qiplat.sweeteditor.perf;

import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;

import java.util.ArrayList;
import java.util.List;

/**
 * Debug performance info overlay, draws real-time performance data at the top-left of the editor screen.
 * <p>
 * Displays: FPS, buildModel duration, each render phase duration (auto-wrapped), text measurement stats, input event duration.
 * <p>
 * Toggle with {@link #setEnabled(boolean)}.
 */
public final class PerfOverlay {
    // Performance warning thresholds (milliseconds)
    public static final float WARN_BUILD_MS = 8.0f;
    public static final float WARN_PAINT_MS = 8.0f;
    public static final float WARN_INPUT_MS = 3.0f;
    public static final float WARN_PAINT_STEP_MS = 2.0f;

    private static final float TEXT_SIZE = 24f;
    private static final float LINE_SPACING = 4f;
    private static final float PADDING_H = 10f;
    private static final float PADDING_V = 8f;
    private static final float MARGIN = 8f;

    private boolean enabled = false;
    private final Paint bgPaint = new Paint();
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    // FPS = 1000 / totalMs
    private float currentFps = 0f;

    // Recent frame data
    private float lastBuildMs;
    private float lastDrawMs;
    private float lastTotalMs;
    private PerfStepRecorder lastDrawPerf;
    private MeasurePerfStats lastMeasureStats;
    private String lastInputTag = "";
    private float lastInputMs;

    public PerfOverlay() {
        bgPaint.setColor(Color.argb(180, 0, 0, 0));
        bgPaint.setStyle(Paint.Style.FILL);
        textPaint.setColor(Color.GREEN);
        textPaint.setTextSize(TEXT_SIZE);
        textPaint.setTypeface(android.graphics.Typeface.MONOSPACE);
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public void recordFrame(float buildMs, float drawMs, float totalMs,
                            PerfStepRecorder drawPerf, MeasurePerfStats measureStats) {
        lastBuildMs = buildMs;
        lastDrawMs = drawMs;
        lastTotalMs = totalMs;
        lastDrawPerf = drawPerf;
        lastMeasureStats = measureStats;

        // FPS = max frame rate supported by this frame's duration
        currentFps = totalMs > 0 ? 1000f / totalMs : 0f;
    }

    public void recordInput(String tag, float inputMs) {
        lastInputTag = tag;
        lastInputMs = inputMs;
    }

    /**
     * Draw performance info panel at top-left of Canvas.
     * Should be called at the end of onDraw.
     */
    public void draw(Canvas canvas, int viewWidth) {
        if (!enabled) return;

        float maxContentWidth = viewWidth - MARGIN * 2 - PADDING_H * 2;
        List<String> lines = buildOverlayLines(maxContentWidth);

        float lineHeight = TEXT_SIZE + LINE_SPACING;
        float panelHeight = lines.size() * lineHeight + PADDING_V * 2;

        // Panel width is the smaller of content width and screen width
        float contentWidth = 0f;
        for (String line : lines) {
            contentWidth = Math.max(contentWidth, textPaint.measureText(line));
        }
        float panelWidth = Math.min(contentWidth + PADDING_H * 2, viewWidth - MARGIN * 2);

        float left = MARGIN;
        float top = MARGIN;

        // Background
        canvas.drawRect(left, top, left + panelWidth, top + panelHeight, bgPaint);

        // Text
        float x = left + PADDING_H;
        float y = top + PADDING_V + TEXT_SIZE;
        for (String line : lines) {
            if (line.contains("SLOW") || line.contains("!")) {
                textPaint.setColor(Color.RED);
            } else {
                textPaint.setColor(Color.GREEN);
            }
            canvas.drawText(line, x, y, textPaint);
            y += lineHeight;
        }
        textPaint.setColor(Color.GREEN);
    }

    private List<String> buildOverlayLines(float maxWidth) {
        List<String> lines = new ArrayList<>();

        // FPS
        lines.add(String.format("FPS: %.0f", currentFps));

        // Frame overview
        String frameSuffix = lastTotalMs > 16.6f ? " SLOW" : "";
        lines.add(String.format("Frame: %.2fms (build=%.2f draw=%.2f)%s",
                lastTotalMs, lastBuildMs, lastDrawMs, frameSuffix));

        // Render phase breakdown - auto-wrap
        if (lastDrawPerf != null) {
            buildStepLines(lines, maxWidth);
        }

        // Measurement stats - split into two lines
        if (lastMeasureStats != null) {
            String summary = lastMeasureStats.buildSummary();
            if (!summary.isEmpty()) {
                wrapText(lines, summary, maxWidth);
            }
        }

        // Input events
        if (!lastInputTag.isEmpty()) {
            String suffix = lastInputMs > WARN_INPUT_MS ? " SLOW" : "";
            lines.add(String.format("Input[%s]: %.2fms%s", lastInputTag, lastInputMs, suffix));
        }

        return lines;
    }

    /**
     * Auto-wrap render phases by max width, each line starts with "Step:" or "    "
     */
    private void buildStepLines(List<String> lines, float maxWidth) {
        int count = lastDrawPerf.getStepCount();
        if (count == 0) return;

        String prefix = "Step: ";
        String contPrefix = "  ";
        StringBuilder sb = new StringBuilder(prefix);

        for (int i = 0; i < count; i++) {
            String entry = String.format("%s=%.1f", lastDrawPerf.getStepName(i),
                    lastDrawPerf.getStepMsByIndex(i));
            // Mark steps exceeding threshold with !
            if (lastDrawPerf.getStepMsByIndex(i) >= WARN_PAINT_STEP_MS) {
                entry += "!";
            }

            String candidate = sb.length() <= prefix.length()
                    ? sb.toString() + entry
                    : sb.toString() + " " + entry;

            if (textPaint.measureText(candidate) > maxWidth && sb.length() > prefix.length()) {
                // Current line can't fit, submit current line first
                lines.add(sb.toString());
                sb = new StringBuilder(contPrefix);
                sb.append(entry);
            } else {
                if (sb.length() > prefix.length() && sb.length() > contPrefix.length()) {
                    sb.append(" ");
                }
                sb.append(entry);
            }
        }
        if (sb.length() > 0) {
            lines.add(sb.toString());
        }
    }

    /**
     * Wrap long text by splitting on spaces
     */
    private void wrapText(List<String> lines, String text, float maxWidth) {
        if (textPaint.measureText(text) <= maxWidth) {
            lines.add(text);
            return;
        }

        String[] words = text.split(" ");
        StringBuilder sb = new StringBuilder();
        for (String word : words) {
            String candidate = sb.length() == 0 ? word : sb.toString() + " " + word;
            if (textPaint.measureText(candidate) > maxWidth && sb.length() > 0) {
                lines.add(sb.toString());
                sb = new StringBuilder("  " + word);
            } else {
                if (sb.length() > 0) sb.append(" ");
                sb.append(word);
            }
        }
        if (sb.length() > 0) {
            lines.add(sb.toString());
        }
    }
}
