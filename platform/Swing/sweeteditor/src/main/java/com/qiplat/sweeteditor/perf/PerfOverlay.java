package com.qiplat.sweeteditor.perf;

import java.awt.*;
import java.util.ArrayList;
import java.util.List;

public final class PerfOverlay {
    public static final float WARN_BUILD_MS = 8.0f;
    public static final float WARN_PAINT_MS = 8.0f;
    public static final float WARN_INPUT_MS = 3.0f;
    public static final float WARN_PAINT_STEP_MS = 2.0f;

    private static final int MARGIN = 8;
    private static final int PADDING_H = 10;
    private static final int PADDING_V = 8;
    private static final int LINE_SPACING = 4;

    private final Font overlayFont = new Font(Font.MONOSPACED, Font.PLAIN, 20);
    private final Color backgroundColor = new Color(0, 0, 0, 180);
    private final Color okTextColor = new Color(0, 255, 0);
    private final Color warnTextColor = new Color(255, 96, 96);

    private boolean enabled;
    private float currentFps;
    private float lastBuildMs;
    private float lastDrawMs;
    private float lastTotalMs;
    private PerfStepRecorder lastBuildPerf;
    private PerfStepRecorder lastDrawPerf;
    private String lastMeasureSummary = "";
    private String lastInputTag = "";
    private float lastInputMs;

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public void recordBuild(PerfStepRecorder buildPerf, String measureSummary) {
        lastBuildPerf = buildPerf;
        lastBuildMs = buildPerf != null ? buildPerf.getTotalMs() : 0f;
        lastMeasureSummary = measureSummary != null ? measureSummary : "";
        updateFrameStats();
    }

    public void recordDraw(PerfStepRecorder drawPerf) {
        lastDrawPerf = drawPerf;
        lastDrawMs = drawPerf != null ? drawPerf.getTotalMs() : 0f;
        updateFrameStats();
    }

    public void recordInput(String tag, float inputMs) {
        lastInputTag = tag != null ? tag : "";
        lastInputMs = inputMs;
    }

    public void draw(Graphics2D g2, int viewWidth) {
        if (!enabled || viewWidth <= MARGIN * 2) {
            return;
        }

        Font oldFont = g2.getFont();
        Color oldColor = g2.getColor();
        g2.setFont(overlayFont);
        FontMetrics metrics = g2.getFontMetrics(overlayFont);

        int maxWidth = Math.max(0, viewWidth - MARGIN * 2 - PADDING_H * 2);
        if (maxWidth <= 0) {
            g2.setFont(oldFont);
            g2.setColor(oldColor);
            return;
        }

        List<String> lines = buildOverlayLines(metrics, maxWidth);
        if (lines.isEmpty()) {
            g2.setFont(oldFont);
            g2.setColor(oldColor);
            return;
        }

        int lineHeight = metrics.getHeight() + LINE_SPACING;
        int contentWidth = 0;
        for (String line : lines) {
            contentWidth = Math.max(contentWidth, metrics.stringWidth(line));
        }

        int panelWidth = Math.min(contentWidth + PADDING_H * 2, viewWidth - MARGIN * 2);
        int panelHeight = lines.size() * lineHeight + PADDING_V * 2;
        int left = MARGIN;
        int top = MARGIN;

        g2.setColor(backgroundColor);
        g2.fillRect(left, top, panelWidth, panelHeight);

        int x = left + PADDING_H;
        int y = top + PADDING_V + metrics.getAscent();
        for (String line : lines) {
            g2.setColor(isWarnLine(line) ? warnTextColor : okTextColor);
            g2.drawString(line, x, y);
            y += lineHeight;
        }

        g2.setFont(oldFont);
        g2.setColor(oldColor);
    }

    private void updateFrameStats() {
        lastTotalMs = lastBuildMs + lastDrawMs;
        currentFps = lastTotalMs > 0f ? 1000f / lastTotalMs : 0f;
    }

    private List<String> buildOverlayLines(FontMetrics metrics, int maxWidth) {
        List<String> lines = new ArrayList<>();
        lines.add(String.format("FPS: %.0f", currentFps));

        String frameSuffix = lastTotalMs >= 16.6f || lastBuildMs >= WARN_BUILD_MS || lastDrawMs >= WARN_PAINT_MS
                ? " SLOW"
                : "";
        lines.add(String.format("Frame: %.2fms (build=%.2f draw=%.2f)%s",
                lastTotalMs, lastBuildMs, lastDrawMs, frameSuffix));

        appendStepLines(lines, metrics, maxWidth, "Build: ", lastBuildPerf);
        appendStepLines(lines, metrics, maxWidth, "Draw: ", lastDrawPerf);

        if (!lastMeasureSummary.isEmpty()) {
            appendWrappedText(lines, metrics, maxWidth, lastMeasureSummary);
        }

        if (!lastInputTag.isEmpty()) {
            String inputSuffix = lastInputMs >= WARN_INPUT_MS ? " SLOW" : "";
            lines.add(String.format("Input[%s]: %.2fms%s", lastInputTag, lastInputMs, inputSuffix));
        }

        return lines;
    }

    private void appendStepLines(List<String> lines, FontMetrics metrics, int maxWidth, String prefix, PerfStepRecorder perf) {
        if (perf == null || perf.getStepCount() == 0) {
            return;
        }

        final String continuationPrefix = "  ";
        StringBuilder builder = new StringBuilder(prefix);
        for (int i = 0; i < perf.getStepCount(); i++) {
            float stepMs = perf.getStepMsByIndex(i);
            String entry = String.format("%s=%.1f", perf.getStepName(i), stepMs);
            if (stepMs >= WARN_PAINT_STEP_MS) {
                entry += "!";
            }

            String candidate = builder.length() <= prefix.length()
                    ? builder + entry
                    : builder + " " + entry;
            if (metrics.stringWidth(candidate) > maxWidth && builder.length() > prefix.length()) {
                lines.add(builder.toString());
                builder = new StringBuilder(continuationPrefix);
                builder.append(entry);
            } else {
                if (builder.length() > prefix.length() && builder.length() > continuationPrefix.length()) {
                    builder.append(' ');
                }
                builder.append(entry);
            }
        }

        if (!builder.isEmpty()) {
            lines.add(builder.toString());
        }
    }

    private void appendWrappedText(List<String> lines, FontMetrics metrics, int maxWidth, String text) {
        if (metrics.stringWidth(text) <= maxWidth) {
            lines.add(text);
            return;
        }

        String[] words = text.split(" ");
        StringBuilder builder = new StringBuilder();
        for (String word : words) {
            String candidate = builder.isEmpty() ? word : builder + " " + word;
            if (metrics.stringWidth(candidate) > maxWidth && !builder.isEmpty()) {
                lines.add(builder.toString());
                builder = new StringBuilder("  ").append(word);
            } else {
                if (!builder.isEmpty()) {
                    builder.append(' ');
                }
                builder.append(word);
            }
        }
        if (!builder.isEmpty()) {
            lines.add(builder.toString());
        }
    }

    private static boolean isWarnLine(String line) {
        return line.contains("SLOW") || line.contains("!");
    }
}
