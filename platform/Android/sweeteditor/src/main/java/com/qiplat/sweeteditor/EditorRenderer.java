package com.qiplat.sweeteditor;

import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.List;

import com.qiplat.sweeteditor.core.HandleConfig;
import com.qiplat.sweeteditor.core.ScrollbarConfig;
import com.qiplat.sweeteditor.core.TextMeasurer;
import com.qiplat.sweeteditor.core.adornment.TextStyle;
import com.qiplat.sweeteditor.core.foundation.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.perf.MeasurePerfStats;
import com.qiplat.sweeteditor.perf.PerfOverlay;
import com.qiplat.sweeteditor.perf.PerfStepRecorder;

/**
 * Platform-independent rendering engine for the editor.
 * Owns all Paint objects, draw methods, perf overlay, icon provider, handle/scrollbar config,
 * and TextMeasurer. SweetEditor delegates all rendering to this class.
 */
final class EditorRenderer {
    private static final float HANDLE_LINE_WIDTH = 1.5f;
    private static final float HANDLE_DROP_RADIUS = 10.0f;
    private static final float HANDLE_CENTER_DIST = 24.0f;
    private static final int DEFAULT_TEXT_SIZE = 28;

    private EditorTheme mTheme;
    private final float mDensity;

    // Paints
    private final Paint mBackgroundPaint;
    private final Paint mTextPaint;
    private final Paint mInlayHintPaint;
    private final Paint mInlayHintBgPaint;
    private final Typeface[] mTextTypefaces = new Typeface[4];
    private final Typeface[] mInlayHintTypefaces = new Typeface[4];
    private final Paint.FontMetrics mInlayHintFontMetrics = new Paint.FontMetrics();
    private final Paint.FontMetrics mTextFontMetrics = new Paint.FontMetrics();
    private final Paint mCursorPaint;
    private final Paint mSelectionPaint;
    private final Paint mLineNumberPaint;
    private final Paint mCurrentLinePaint;
    private final Paint mGuidePaint;
    private final Paint mSeparatorLinePaint;
    private final Paint mCompositionPaint;
    private final Paint mSplitLinePaint;
    private final Paint mHandlePaint;
    private final Paint mFoldArrowPaint;
    private final Paint mDiagnosticPaint;
    private final DashPathEffect mDiagnosticDashEffect;
    private final Paint mLinkedEditingActivePaint;
    private final Paint mLinkedEditingInactivePaint;
    private final Paint mBracketHighlightBorderPaint;
    private final Paint mBracketHighlightBgPaint;
    private final Paint mScrollbarTrackPaint;
    private final Paint mScrollbarThumbPaint;

    private final TextMeasurer mTextMeasurer;

    @Nullable
    private EditorIconProvider mEditorIconProvider;
    @Nullable
    private HandleConfig mHandleConfig;
    @Nullable
    private ScrollbarConfig mScrollbarConfig;

    // Perf
    private final MeasurePerfStats mMeasurePerfStats = new MeasurePerfStats();
    private final PerfOverlay mPerfOverlay = new PerfOverlay();

    public EditorRenderer(@NonNull EditorTheme theme, float density) {
        mTheme = theme;
        mDensity = density;

        mTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mTextPaint.setColor(theme.textColor);
        mTextPaint.setTextSize(DEFAULT_TEXT_SIZE);

        mTextTypefaces[Typeface.NORMAL] = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL);
        mTextTypefaces[Typeface.BOLD] = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD);
        mTextTypefaces[Typeface.ITALIC] = Typeface.create(Typeface.MONOSPACE, Typeface.ITALIC);
        mTextTypefaces[Typeface.BOLD_ITALIC] = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD_ITALIC);
        mTextPaint.setTypeface(mTextTypefaces[Typeface.NORMAL]);

        mInlayHintPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mInlayHintTypefaces[Typeface.NORMAL] = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL);
        mInlayHintTypefaces[Typeface.BOLD] = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD);
        mInlayHintTypefaces[Typeface.ITALIC] = Typeface.create(Typeface.SANS_SERIF, Typeface.ITALIC);
        mInlayHintTypefaces[Typeface.BOLD_ITALIC] = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD_ITALIC);
        mInlayHintPaint.setTypeface(mInlayHintTypefaces[Typeface.NORMAL]);
        mInlayHintPaint.setTextSize(DEFAULT_TEXT_SIZE * 0.9f);
        mInlayHintPaint.setColor(theme.inlayHintTextColor);

        mInlayHintBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mInlayHintBgPaint.setStyle(Paint.Style.FILL);
        mInlayHintBgPaint.setColor(theme.inlayHintBgColor);

        mBackgroundPaint = new Paint();
        mBackgroundPaint.setColor(theme.backgroundColor);

        mCursorPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mCursorPaint.setColor(theme.cursorColor);
        mCursorPaint.setStrokeWidth(2f);

        mSelectionPaint = new Paint();
        mSelectionPaint.setColor(theme.selectionColor);
        mSelectionPaint.setStyle(Paint.Style.FILL);

        mLineNumberPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLineNumberPaint.setColor(theme.lineNumberColor);
        mLineNumberPaint.setTextSize(DEFAULT_TEXT_SIZE * 0.8f);

        mCurrentLinePaint = new Paint();
        mCurrentLinePaint.setColor(theme.currentLineColor);
        mCurrentLinePaint.setStyle(Paint.Style.FILL);

        mGuidePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mGuidePaint.setStyle(Paint.Style.STROKE);
        mGuidePaint.setColor(theme.guideColor);
        mGuidePaint.setStrokeWidth(1f);

        mSeparatorLinePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mSeparatorLinePaint.setColor(theme.separatorLineColor);
        mSeparatorLinePaint.setStrokeWidth(1f);

        mCompositionPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mCompositionPaint.setColor(theme.compositionUnderlineColor);
        mCompositionPaint.setStrokeWidth(2f);
        mCompositionPaint.setStyle(Paint.Style.STROKE);

        mDiagnosticPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mDiagnosticPaint.setStyle(Paint.Style.STROKE);
        mDiagnosticPaint.setStrokeWidth(3.0f);
        mDiagnosticDashEffect = new DashPathEffect(new float[]{3, 2}, 0);

        mLinkedEditingActivePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLinkedEditingActivePaint.setColor(theme.linkedEditingActiveColor);
        mLinkedEditingActivePaint.setStyle(Paint.Style.STROKE);
        mLinkedEditingActivePaint.setStrokeWidth(2f);

        mLinkedEditingInactivePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLinkedEditingInactivePaint.setColor(theme.linkedEditingInactiveColor);
        mLinkedEditingInactivePaint.setStyle(Paint.Style.STROKE);
        mLinkedEditingInactivePaint.setStrokeWidth(1f);

        mBracketHighlightBorderPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mBracketHighlightBorderPaint.setColor(theme.bracketHighlightBorderColor);
        mBracketHighlightBorderPaint.setStyle(Paint.Style.STROKE);
        mBracketHighlightBorderPaint.setStrokeWidth(1.5f);

        mBracketHighlightBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mBracketHighlightBgPaint.setColor(theme.bracketHighlightBgColor);
        mBracketHighlightBgPaint.setStyle(Paint.Style.FILL);

        mScrollbarTrackPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mScrollbarTrackPaint.setStyle(Paint.Style.FILL);
        mScrollbarThumbPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mScrollbarThumbPaint.setStyle(Paint.Style.FILL);

        mSplitLinePaint = new Paint();
        mSplitLinePaint.setColor(theme.splitLineColor);
        mSplitLinePaint.setStrokeWidth(1f);

        mHandlePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mHandlePaint.setColor(theme.cursorColor);
        mHandlePaint.setStyle(Paint.Style.FILL);

        mFoldArrowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mFoldArrowPaint.setColor(theme.lineNumberColor);
        mFoldArrowPaint.setStyle(Paint.Style.STROKE);
        mFoldArrowPaint.setStrokeCap(Paint.Cap.ROUND);
        mFoldArrowPaint.setStrokeJoin(Paint.Join.ROUND);

        mTextMeasurer = new TextMeasurer(mTextPaint, mInlayHintPaint);
    }

    @NonNull
    public TextMeasurer getTextMeasurer() {
        return mTextMeasurer;
    }

    @NonNull
    public EditorTheme getTheme() {
        return mTheme;
    }

    public void setEditorIconProvider(@Nullable EditorIconProvider provider) {
        mEditorIconProvider = provider;
    }

    @Nullable
    public EditorIconProvider getEditorIconProvider() {
        return mEditorIconProvider;
    }

    public void setHandleConfig(@Nullable HandleConfig config) {
        mHandleConfig = config;
    }

    @Nullable
    public HandleConfig getHandleConfig() {
        return mHandleConfig;
    }

    /**
     * Compute handle hit-test rects from the actual teardrop drawing parameters
     * (radius, center distance, 45° rotation). The returned HandleConfig automatically
     * stays in sync with the visual handle shape.
     */
    public static HandleConfig computeHandleHitConfig(float density) {
        float angle = (float) Math.toRadians(45.0);
        float cos = (float) Math.cos(angle);
        float sin = (float) Math.sin(angle);

        float r = HANDLE_DROP_RADIUS;
        float d = HANDLE_CENTER_DIST;

        // Key points of the teardrop shape before rotation (relative to tip at origin)
        float[][] points = {
                {0, 0},
                {-r, d},
                {r, d},
                {0, d + r},
                {0, d - r * 0.8f}
        };

        // Rotate +45° (start handle) and compute bounding box
        float minX = Float.MAX_VALUE, minY = Float.MAX_VALUE;
        float maxX = -Float.MAX_VALUE, maxY = -Float.MAX_VALUE;
        for (float[] p : points) {
            float rx = p[0] * cos - p[1] * sin;
            float ry = p[0] * sin + p[1] * cos;
            minX = Math.min(minX, rx);
            minY = Math.min(minY, ry);
            maxX = Math.max(maxX, rx);
            maxY = Math.max(maxY, ry);
        }

        float pad = 8f;

        RectF startHit = new RectF(
                (minX - pad) * density,
                (minY - pad) * density,
                (maxX + pad) * density,
                (maxY + pad) * density);

        // End handle rotates -45°, which mirrors the x-axis of the start handle
        RectF endHit = new RectF(
                (-maxX - pad) * density,
                (minY - pad) * density,
                (-minX + pad) * density,
                (maxY + pad) * density);

        return new HandleConfig(startHit, endHit);
    }

    public void setScrollbarConfig(@Nullable ScrollbarConfig config) {
        mScrollbarConfig = config;
    }

    @Nullable
    public ScrollbarConfig getScrollbarConfig() {
        return mScrollbarConfig;
    }

    @NonNull
    public MeasurePerfStats getMeasurePerfStats() {
        return mMeasurePerfStats;
    }

    @NonNull
    public PerfOverlay getPerfOverlay() {
        return mPerfOverlay;
    }

    public void setPerfOverlayEnabled(boolean enabled) {
        mPerfOverlay.setEnabled(enabled);
    }

    public boolean isPerfOverlayEnabled() {
        return mPerfOverlay.isEnabled();
    }

    public void syncPlatformScale(float scale) {
        mTextMeasurer.setScale(scale);
        mInlayHintPaint.setTextSize(mTextPaint.getTextSize() * 0.9f);
        mLineNumberPaint.setTextSize(mTextPaint.getTextSize() * 0.85f);
    }

    public void applyTypeface(Typeface typeface) {
        mTextMeasurer.setTypeface(typeface);
        mTextTypefaces[Typeface.NORMAL] = Typeface.create(typeface, Typeface.NORMAL);
        mTextTypefaces[Typeface.BOLD] = Typeface.create(typeface, Typeface.BOLD);
        mTextTypefaces[Typeface.ITALIC] = Typeface.create(typeface, Typeface.ITALIC);
        mTextTypefaces[Typeface.BOLD_ITALIC] = Typeface.create(typeface, Typeface.BOLD_ITALIC);
        mTextPaint.setTypeface(mTextTypefaces[Typeface.NORMAL]);
    }

    public void applyTextSize(float textSize) {
        mTextMeasurer.setTextSize(textSize);
        mInlayHintPaint.setTextSize(textSize * 0.9f);
        mLineNumberPaint.setTextSize(textSize * 0.85f);
    }

    public void applyTheme(@NonNull EditorTheme theme) {
        mTheme = theme;
        mBackgroundPaint.setColor(theme.backgroundColor);
        mTextPaint.setColor(theme.textColor);
        mInlayHintPaint.setColor(theme.inlayHintTextColor);
        mInlayHintBgPaint.setColor(theme.inlayHintBgColor);
        mCursorPaint.setColor(theme.cursorColor);
        mSelectionPaint.setColor(theme.selectionColor);
        mLineNumberPaint.setColor(theme.lineNumberColor);
        mCurrentLinePaint.setColor(theme.currentLineColor);
        mGuidePaint.setColor(theme.guideColor);
        mSeparatorLinePaint.setColor(theme.separatorLineColor);
        mCompositionPaint.setColor(theme.compositionUnderlineColor);
        mSplitLinePaint.setColor(theme.splitLineColor);
        mHandlePaint.setColor(theme.cursorColor);
        mFoldArrowPaint.setColor(theme.lineNumberColor);
        mLinkedEditingActivePaint.setColor(theme.linkedEditingActiveColor);
        mLinkedEditingInactivePaint.setColor(theme.linkedEditingInactiveColor);
        mBracketHighlightBorderPaint.setColor(theme.bracketHighlightBorderColor);
        mBracketHighlightBgPaint.setColor(theme.bracketHighlightBgColor);
    }

    /**
     * Render the editor content onto the canvas.
     *
     * @return true if transient scrollbar refresh should be scheduled
     */
    public boolean render(@NonNull Canvas canvas, @NonNull EditorRenderModel model,
                          int viewWidth, int viewHeight,
                          boolean cursorVisible, float buildMs) {
        PerfStepRecorder drawPerf = mPerfOverlay.isEnabled() ? PerfStepRecorder.start() : null;

        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_BUILD);

        canvas.drawColor(mTheme.backgroundColor);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_CLEAR);

        drawCurrentLineDecoration(canvas, model, 0f, viewWidth);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_CURRENT);

        drawSelectionRects(canvas, model.selectionRects);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_SELECTION);

        drawLines(canvas, model);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_LINES);

        drawGuideSegments(canvas, model.guideSegments);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_GUIDES);

        drawCompositionDecoration(canvas, model.compositionDecoration);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_COMPOSITION);

        drawDiagnosticDecorations(canvas, model.diagnosticDecorations);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_DIAGNOSTICS);

        drawLinkedEditingRects(canvas, model.linkedEditingRects);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_LINKED);

        drawBracketHighlightRects(canvas, model.bracketHighlightRects);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_BRACKET);

        drawCursor(canvas, model.cursor, cursorVisible);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_CURSOR);

        if (model.splitX > 0) {
            canvas.drawRect(0, 0, model.splitX, viewHeight, mBackgroundPaint);
            drawCurrentLineDecoration(canvas, model, 0f, model.splitX);
            if (model.splitLineVisible) {
                canvas.drawLine(model.splitX, 0, model.splitX, viewHeight, mSplitLinePaint);
            }
        }

        drawLineNumbers(canvas, model);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_GUTTER);

        drawSelectionHandles(canvas, model.selectionStartHandle, model.selectionEndHandle);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_HANDLES);

        boolean needsTransientRefresh = drawScrollbars(canvas, model);
        if (drawPerf != null) {
            drawPerf.mark(PerfStepRecorder.STEP_SCROLLBARS);
            drawPerf.finish();
        }

        if (drawPerf != null) {
            float totalMs = drawPerf.getTotalMs();
            float drawMs = totalMs - buildMs;
            mPerfOverlay.recordFrame(buildMs, drawMs, totalMs, drawPerf, mMeasurePerfStats);
            mPerfOverlay.draw(canvas, viewWidth);
        }

        return needsTransientRefresh;
    }

    private void drawLines(Canvas canvas, EditorRenderModel model) {
        if (model.lines == null) return;
        for (VisualLine line : model.lines) {
            if (line.runs == null) continue;
            int lastFontStyle = -1;
            int lastColor = 0;
            for (VisualRun run : line.runs) {
                if (run.type == VisualRunType.TEXT || run.type == VisualRunType.WHITESPACE
                        || run.type == VisualRunType.INLAY_HINT || run.type == VisualRunType.PHANTOM_TEXT
                        || run.type == VisualRunType.FOLD_PLACEHOLDER) {

                    if (run.type == VisualRunType.FOLD_PLACEHOLDER) {
                        if (run.text != null && !run.text.isEmpty()) {
                            float mgn = run.margin;
                            mTextPaint.getFontMetrics(mTextFontMetrics);
                            float bgTop = run.y + mTextFontMetrics.ascent;
                            float bgBottom = run.y + mTextFontMetrics.descent;
                            float bgLeft = run.x + mgn;
                            float bgRight = run.x + run.width - mgn;
                            float radius = (bgBottom - bgTop) * 0.2f;
                            mInlayHintBgPaint.setColor(mTheme.foldPlaceholderBgColor);
                            canvas.drawRoundRect(bgLeft, bgTop, bgRight, bgBottom, radius, radius, mInlayHintBgPaint);
                            mInlayHintBgPaint.setColor(mTheme.inlayHintBgColor);
                            mTextPaint.setColor(mTheme.foldPlaceholderTextColor);
                            canvas.drawText(run.text, run.x + mgn + run.padding, run.y, mTextPaint);
                            mTextPaint.setColor(mTheme.textColor);
                        }
                        lastFontStyle = -1;
                        continue;
                    }

                    if (run.type == VisualRunType.INLAY_HINT) {
                        float mgn = run.margin;
                        mInlayHintPaint.getFontMetrics(mInlayHintFontMetrics);
                        float bgTop = run.y + mInlayHintFontMetrics.ascent;
                        float bgBottom = run.y + mInlayHintFontMetrics.descent;
                        float bgLeft = run.x + mgn;
                        float bgRight = run.x + run.width - mgn;

                        if (run.colorValue != 0) {
                            float blockSize = bgBottom - bgTop;
                            float colorLeft = run.x + mgn;
                            float colorTop = bgTop;
                            mInlayHintBgPaint.setColor(run.colorValue);
                            mInlayHintBgPaint.setAlpha(255);
                            canvas.drawRect(colorLeft, colorTop,
                                    colorLeft + blockSize, colorTop + blockSize,
                                    mInlayHintBgPaint);
                            mInlayHintBgPaint.setColor(mTheme.inlayHintBgColor);
                        } else {
                            float radius = (bgBottom - bgTop) * 0.2f;
                            canvas.drawRoundRect(bgLeft, bgTop, bgRight, bgBottom, radius, radius, mInlayHintBgPaint);

                            if (run.iconId > 0 && mEditorIconProvider != null) {
                                float bgW = bgRight - bgLeft;
                                float bgH = bgBottom - bgTop;
                                float iconSize = Math.min(bgW, bgH);
                                float iconLeft = bgLeft + (bgW - iconSize) * 0.5f;
                                float iconTop = bgTop + (bgH - iconSize) * 0.5f;
                                Drawable drawable = mEditorIconProvider.getIconDrawable(run.iconId);
                                if (drawable != null) {
                                    drawable.setColorFilter(mTheme.inlayHintIconColor, android.graphics.PorterDuff.Mode.SRC_IN);
                                    drawable.setBounds((int) iconLeft, (int) iconTop,
                                            (int) (iconLeft + iconSize), (int) (iconTop + iconSize));
                                    drawable.draw(canvas);
                                    drawable.clearColorFilter();
                                }
                            } else if (run.text != null && !run.text.isEmpty()) {
                                int fontStyle = run.style != null ? run.style.fontStyle : 0;
                                int color;
                                if (run.style != null && run.style.color != 0) {
                                    int alpha = (mTheme.inlayHintTextColor >>> 24) & 0xFF;
                                    color = (alpha << 24) | (run.style.color & 0x00FFFFFF);
                                } else {
                                    color = mTheme.inlayHintTextColor;
                                }
                                boolean bold = (fontStyle & TextStyle.BOLD) != 0;
                                boolean italic = (fontStyle & TextStyle.ITALIC) != 0;
                                int tfStyle = Typeface.NORMAL;
                                if (bold && italic) tfStyle = Typeface.BOLD_ITALIC;
                                else if (bold) tfStyle = Typeface.BOLD;
                                else if (italic) tfStyle = Typeface.ITALIC;
                                mInlayHintPaint.setTypeface(mInlayHintTypefaces[tfStyle]);
                                mInlayHintPaint.setStrikeThruText((fontStyle & TextStyle.STRIKETHROUGH) != 0);
                                mInlayHintPaint.setColor(color);
                                canvas.drawText(run.text, run.x + mgn + run.padding, run.y, mInlayHintPaint);
                            }
                        }
                        lastFontStyle = -1;
                        continue;
                    }

                    if (run.text == null || run.text.isEmpty()) continue;

                    int fontStyle = run.style != null ? run.style.fontStyle : 0;
                    int color = (run.style != null && run.style.color != 0) ? run.style.color : mTheme.textColor;

                    if (fontStyle != lastFontStyle) {
                        applyFontStyle(fontStyle);
                        lastFontStyle = fontStyle;
                    }
                    if (color != lastColor) {
                        mTextPaint.setColor(color);
                        lastColor = color;
                    }

                    if (run.style != null && run.style.backgroundColor != 0) {
                        Paint.FontMetrics fm = mTextPaint.getFontMetrics();
                        float bgTop = run.y + fm.ascent;
                        float bgBottom = run.y + fm.descent;
                        mTextPaint.setColor(run.style.backgroundColor);
                        canvas.drawRect(run.x, bgTop, run.x + run.width, bgBottom, mTextPaint);
                        mTextPaint.setColor(color);
                    }

                    if (run.type == VisualRunType.PHANTOM_TEXT) {
                        mTextPaint.setColor(mTheme.phantomTextColor);
                        canvas.drawText(run.text, run.x, run.y, mTextPaint);
                        mTextPaint.setColor(color);
                        continue;
                    }

                    canvas.drawText(run.text, run.x, run.y, mTextPaint);
                }
            }
        }
    }

    private void drawLineNumbers(Canvas canvas, EditorRenderModel model) {
        if (!model.gutterVisible) return;
        if (model.lines == null) return;
        List<GutterIconRenderItem> gutterIcons = model.gutterIcons;
        List<FoldMarkerRenderItem> foldMarkers = model.foldMarkers;
        int iconCount = gutterIcons != null ? gutterIcons.size() : 0;
        int markerCount = foldMarkers != null ? foldMarkers.size() : 0;
        int iconCursor = 0;
        int markerCursor = 0;
        boolean overlayMode = (model.maxGutterIcons == 0);
        final int activeLogicalLine = getActiveLogicalLine(model);
        final int normalLineNumberColor = mTheme.lineNumberColor;
        final int activeLineNumberColor = getActiveLineNumberColor();
        Path arrowPath = new Path();
        for (VisualLine line : model.lines) {
            if (line.wrapIndex == 0 && !line.isPhantomLine && line.lineNumberPosition != null) {
                final int logicalLine = line.logicalLine;
                final boolean isCurrentLine = logicalLine == activeLogicalLine;

                while (iconCursor < iconCount && gutterIcons.get(iconCursor).logicalLine < logicalLine) {
                    iconCursor++;
                }
                int iconStart = iconCursor;
                while (iconCursor < iconCount && gutterIcons.get(iconCursor).logicalLine == logicalLine) {
                    iconCursor++;
                }
                int iconEnd = iconCursor;
                boolean hasIcons = mEditorIconProvider != null && iconEnd > iconStart;

                if (overlayMode && hasIcons) {
                    drawGutterIconItem(canvas, gutterIcons.get(iconStart));
                } else {
                    mLineNumberPaint.setColor(isCurrentLine ? activeLineNumberColor : normalLineNumberColor);
                    String lineNumStr = String.valueOf(line.logicalLine + 1);
                    canvas.drawText(lineNumStr,
                            line.lineNumberPosition.x, line.lineNumberPosition.y,
                            mLineNumberPaint);

                    if (hasIcons && !overlayMode) {
                        for (int i = iconStart; i < iconEnd; i++) {
                            drawGutterIconItem(canvas, gutterIcons.get(i));
                        }
                    }
                }

                while (markerCursor < markerCount && foldMarkers.get(markerCursor).logicalLine < logicalLine) {
                    markerCursor++;
                }
                FoldMarkerRenderItem foldMarker = null;
                while (markerCursor < markerCount && foldMarkers.get(markerCursor).logicalLine == logicalLine) {
                    if (foldMarker == null) foldMarker = foldMarkers.get(markerCursor);
                    markerCursor++;
                }
                if (foldMarker != null) {
                    drawFoldMarkerItem(
                            canvas,
                            foldMarker,
                            arrowPath,
                            isCurrentLine ? activeLineNumberColor : normalLineNumberColor);
                }
            }
        }
    }

    private void drawGutterIconItem(@NonNull Canvas canvas, @NonNull GutterIconRenderItem item) {
        if (mEditorIconProvider == null || item.origin == null || item.width <= 0f || item.height <= 0f) return;
        Drawable drawable = mEditorIconProvider.getIconDrawable(item.iconId);
        if (drawable == null) return;
        int left = Math.round(item.origin.x);
        int top = Math.round(item.origin.y);
        int right = Math.round(item.origin.x + item.width);
        int bottom = Math.round(item.origin.y + item.height);
        drawable.setBounds(left, top, right, bottom);
        drawable.draw(canvas);
    }

    private void drawFoldMarkerItem(@NonNull Canvas canvas, @NonNull FoldMarkerRenderItem item,
                                    @NonNull Path arrowPath, int color) {
        if (item.origin == null || item.width <= 0f || item.height <= 0f) return;
        if (item.foldState == null || item.foldState == FoldState.NONE) return;

        float centerX = item.origin.x + item.width * 0.5f;
        float centerY = item.origin.y + item.height * 0.5f;
        float halfSize = Math.min(item.width, item.height) * 0.28f;
        mFoldArrowPaint.setColor(color);
        mFoldArrowPaint.setStrokeWidth(Math.max(1f, item.height * 0.1f));

        arrowPath.reset();
        if (item.foldState == FoldState.COLLAPSED) {
            arrowPath.moveTo(centerX - halfSize * 0.5f, centerY - halfSize);
            arrowPath.lineTo(centerX + halfSize * 0.5f, centerY);
            arrowPath.lineTo(centerX - halfSize * 0.5f, centerY + halfSize);
        } else {
            arrowPath.moveTo(centerX - halfSize, centerY - halfSize * 0.5f);
            arrowPath.lineTo(centerX, centerY + halfSize * 0.5f);
            arrowPath.lineTo(centerX + halfSize, centerY - halfSize * 0.5f);
        }
        canvas.drawPath(arrowPath, mFoldArrowPaint);
    }

    private void drawCurrentLineDecoration(@NonNull Canvas canvas, @NonNull EditorRenderModel model,
                                           float left, float right) {
        if (model.currentLine == null) return;
        if (right <= left) return;
        if (model.currentLineRenderMode == CurrentLineRenderMode.NONE.value) return;
        float lineHeight = model.cursor != null ? model.cursor.height : 20f;
        float top = model.currentLine.y;
        float bottom = top + lineHeight;
        if (model.currentLineRenderMode == CurrentLineRenderMode.BORDER.value) {
            int prevColor = mCurrentLinePaint.getColor();
            Paint.Style prevStyle = mCurrentLinePaint.getStyle();
            float prevStroke = mCurrentLinePaint.getStrokeWidth();
            mCurrentLinePaint.setColor(getCurrentLineBorderColor());
            mCurrentLinePaint.setStyle(Paint.Style.STROKE);
            mCurrentLinePaint.setStrokeWidth(Math.max(1f, mDensity));
            canvas.drawRect(left, top, right, bottom, mCurrentLinePaint);
            mCurrentLinePaint.setColor(prevColor);
            mCurrentLinePaint.setStyle(prevStyle);
            mCurrentLinePaint.setStrokeWidth(prevStroke);
            return;
        }
        mCurrentLinePaint.setColor(mTheme.currentLineColor);
        mCurrentLinePaint.setStyle(Paint.Style.FILL);
        canvas.drawRect(left, top, right, bottom, mCurrentLinePaint);
    }

    private int getActiveLogicalLine(@NonNull EditorRenderModel model) {
        if (model.cursor == null || model.cursor.textPosition == null) return -1;
        return model.cursor.textPosition.line;
    }

    private int getActiveLineNumberColor() {
        int color = mTheme.currentLineNumberColor;
        if (color == 0) color = mTheme.lineNumberColor;
        return (color & 0x00FFFFFF) | 0xFF000000;
    }

    private int getCurrentLineBorderColor() {
        int color = mTheme.currentLineColor;
        if (color == 0) color = mTheme.lineNumberColor;
        int alpha = (color >>> 24) & 0xFF;
        if (alpha < 0xA0) {
            color = (color & 0x00FFFFFF) | (0xA0 << 24);
        }
        return color;
    }

    /**
     * @return true if transient scrollbar refresh should be scheduled
     */
    private boolean drawScrollbars(Canvas canvas, EditorRenderModel model) {
        ScrollbarModel vertical = model.verticalScrollbar;
        ScrollbarModel horizontal = model.horizontalScrollbar;
        float verticalAlpha = getScrollbarAlpha(vertical);
        float horizontalAlpha = getScrollbarAlpha(horizontal);
        boolean hasVertical = isDrawableScrollbar(vertical, verticalAlpha);
        boolean hasHorizontal = isDrawableScrollbar(horizontal, horizontalAlpha);
        if (!hasVertical && !hasHorizontal) {
            return false;
        }

        float verticalTrackX = 0f;
        float verticalTrackWidth = 0f;
        float horizontalTrackY = 0f;
        float horizontalTrackHeight = 0f;

        if (hasVertical) {
            mScrollbarTrackPaint.setColor(multiplyAlpha(mTheme.scrollbarTrackColor, verticalAlpha));
            int vThumbColor = vertical.thumbActive ? mTheme.scrollbarThumbActiveColor : mTheme.scrollbarThumbColor;
            mScrollbarThumbPaint.setColor(multiplyAlpha(vThumbColor, verticalAlpha));
            float trackX = vertical.track.origin != null ? vertical.track.origin.x : 0f;
            float trackY = vertical.track.origin != null ? vertical.track.origin.y : 0f;
            float thumbX = vertical.thumb.origin != null ? vertical.thumb.origin.x : 0f;
            float thumbY = vertical.thumb.origin != null ? vertical.thumb.origin.y : 0f;
            verticalTrackX = trackX;
            verticalTrackWidth = vertical.track.width;
            canvas.drawRect(trackX, trackY, trackX + vertical.track.width, trackY + vertical.track.height, mScrollbarTrackPaint);
            canvas.drawRect(thumbX, thumbY, thumbX + vertical.thumb.width, thumbY + vertical.thumb.height, mScrollbarThumbPaint);
        }

        if (hasHorizontal) {
            mScrollbarTrackPaint.setColor(multiplyAlpha(mTheme.scrollbarTrackColor, horizontalAlpha));
            int hThumbColor = horizontal.thumbActive ? mTheme.scrollbarThumbActiveColor : mTheme.scrollbarThumbColor;
            mScrollbarThumbPaint.setColor(multiplyAlpha(hThumbColor, horizontalAlpha));
            float trackX = horizontal.track.origin != null ? horizontal.track.origin.x : 0f;
            float trackY = horizontal.track.origin != null ? horizontal.track.origin.y : 0f;
            float thumbX = horizontal.thumb.origin != null ? horizontal.thumb.origin.x : 0f;
            float thumbY = horizontal.thumb.origin != null ? horizontal.thumb.origin.y : 0f;
            horizontalTrackY = trackY;
            horizontalTrackHeight = horizontal.track.height;
            canvas.drawRect(trackX, trackY, trackX + horizontal.track.width, trackY + horizontal.track.height, mScrollbarTrackPaint);
            canvas.drawRect(thumbX, thumbY, thumbX + horizontal.thumb.width, thumbY + horizontal.thumb.height, mScrollbarThumbPaint);
        }

        if (hasVertical && hasHorizontal) {
            mScrollbarTrackPaint.setColor(multiplyAlpha(mTheme.scrollbarTrackColor, Math.max(verticalAlpha, horizontalAlpha)));
            canvas.drawRect(
                    verticalTrackX,
                    horizontalTrackY,
                    verticalTrackX + verticalTrackWidth,
                    horizontalTrackY + horizontalTrackHeight,
                    mScrollbarTrackPaint);
        }

        return mScrollbarConfig != null && mScrollbarConfig.mode == ScrollbarConfig.ScrollbarMode.TRANSIENT;
    }

    private void drawCursor(Canvas canvas, @Nullable Cursor cursor, boolean cursorVisible) {
        if (cursor == null || !cursor.visible || !cursorVisible) return;
        float cursorWidth = HANDLE_LINE_WIDTH * mDensity;
        canvas.drawRect(
                cursor.position.x,
                cursor.position.y,
                cursor.position.x + cursorWidth,
                cursor.position.y + cursor.height,
                mCursorPaint
        );
    }

    private void drawSelectionRects(Canvas canvas, @Nullable List<SelectionRect> rects) {
        if (rects == null || rects.isEmpty()) return;
        for (SelectionRect rect : rects) {
            if (rect.origin == null) continue;
            canvas.drawRect(
                    rect.origin.x, rect.origin.y,
                    rect.origin.x + rect.width,
                    rect.origin.y + rect.height,
                    mSelectionPaint
            );
        }
    }

    private void drawSelectionHandles(Canvas canvas,
                                      @Nullable SelectionHandle startHandle,
                                      @Nullable SelectionHandle endHandle) {
        if (startHandle != null && startHandle.visible && startHandle.position != null) {
            drawHandle(canvas, startHandle.position.x, startHandle.position.y,
                    startHandle.height, true);
        }
        if (endHandle != null && endHandle.visible && endHandle.position != null) {
            drawHandle(canvas, endHandle.position.x, endHandle.position.y,
                    endHandle.height, false);
        }
    }

    private void drawHandle(Canvas canvas, float x, float y, float height, boolean isStart) {
        float lineWidth = HANDLE_LINE_WIDTH * mDensity;
        float dropRadius = HANDLE_DROP_RADIUS * mDensity;
        float dropLength = HANDLE_CENTER_DIST * mDensity;

        canvas.drawRect(x - lineWidth / 2, y, x + lineWidth / 2, y + height, mHandlePaint);

        float tipX = x;
        float tipY = y + height;

        float angle = isStart ? 45f : -45f;
        canvas.save();
        canvas.rotate(angle, tipX, tipY);

        float cx = tipX;
        float cy = tipY + dropLength;
        float k = dropRadius * 0.5522f;

        Path path = new Path();
        path.moveTo(tipX, tipY);
        path.cubicTo(tipX, tipY + dropLength * 0.4f,
                cx - dropRadius, cy - dropRadius * 0.8f,
                cx - dropRadius, cy);
        path.cubicTo(cx - dropRadius, cy + k, cx - k, cy + dropRadius, cx, cy + dropRadius);
        path.cubicTo(cx + k, cy + dropRadius, cx + dropRadius, cy + k, cx + dropRadius, cy);
        path.cubicTo(cx + dropRadius, cy - dropRadius * 0.8f,
                tipX, tipY + dropLength * 0.4f,
                tipX, tipY);
        path.close();
        canvas.drawPath(path, mHandlePaint);

        canvas.restore();
    }

    private void drawGuideSegments(Canvas canvas, @Nullable List<GuideSegment> segments) {
        if (segments == null || segments.isEmpty()) return;
        for (GuideSegment seg : segments) {
            if (seg.start == null || seg.end == null) continue;
            Paint paint = (seg.type == GuideType.SEPARATOR) ? mSeparatorLinePaint : mGuidePaint;
            if (seg.style == GuideStyle.DOUBLE) {
                float offset = 1.5f;
                if (seg.direction == GuideDirection.HORIZONTAL) {
                    canvas.drawLine(seg.start.x, seg.start.y - offset, seg.end.x, seg.end.y - offset, paint);
                    canvas.drawLine(seg.start.x, seg.start.y + offset, seg.end.x, seg.end.y + offset, paint);
                } else {
                    canvas.drawLine(seg.start.x - offset, seg.start.y, seg.end.x - offset, seg.end.y, paint);
                    canvas.drawLine(seg.start.x + offset, seg.start.y, seg.end.x + offset, seg.end.y, paint);
                }
            } else {
                if (seg.arrowEnd) {
                    float arrowDepth = 8f * mDensity * (float) Math.cos(Math.toRadians(28));
                    float dx = seg.end.x - seg.start.x;
                    float dy = seg.end.y - seg.start.y;
                    float len = (float) Math.sqrt(dx * dx + dy * dy);
                    if (len > arrowDepth) {
                        float ratio = (len - arrowDepth) / len;
                        float lineEndX = seg.start.x + dx * ratio;
                        float lineEndY = seg.start.y + dy * ratio;
                        canvas.drawLine(seg.start.x, seg.start.y, lineEndX, lineEndY, paint);
                    }
                    drawArrowHead(canvas, seg.start.x, seg.start.y, seg.end.x, seg.end.y, paint);
                } else {
                    canvas.drawLine(seg.start.x, seg.start.y, seg.end.x, seg.end.y, paint);
                }
            }
        }
    }

    private void drawArrowHead(Canvas canvas, float fromX, float fromY, float toX, float toY, Paint paint) {
        float arrowLen = 8f * mDensity;
        float arrowAngle = (float) Math.toRadians(28);
        float dx = toX - fromX;
        float dy = toY - fromY;
        float len = (float) Math.sqrt(dx * dx + dy * dy);
        if (len < 1f) return;
        float ux = dx / len;
        float uy = dy / len;
        float cosA = (float) Math.cos(arrowAngle);
        float sinA = (float) Math.sin(arrowAngle);
        float ax1 = toX - arrowLen * (ux * cosA - uy * sinA);
        float ay1 = toY - arrowLen * (uy * cosA + ux * sinA);
        float ax2 = toX - arrowLen * (ux * cosA + uy * sinA);
        float ay2 = toY - arrowLen * (uy * cosA - ux * sinA);
        Path arrow = new Path();
        arrow.moveTo(toX, toY);
        arrow.lineTo(ax1, ay1);
        arrow.lineTo(ax2, ay2);
        arrow.close();
        Paint.Style saved = paint.getStyle();
        paint.setStyle(Paint.Style.FILL);
        canvas.drawPath(arrow, paint);
        paint.setStyle(saved);
    }

    private void drawCompositionDecoration(Canvas canvas, @Nullable CompositionDecoration decoration) {
        if (decoration == null || !decoration.active) return;
        if (decoration.origin == null) return;
        float y = decoration.origin.y + decoration.height;
        canvas.drawLine(decoration.origin.x, y,
                decoration.origin.x + decoration.width, y,
                mCompositionPaint);
    }

    private void drawDiagnosticDecorations(Canvas canvas, @Nullable List<DiagnosticDecoration> decorations) {
        if (decorations == null || decorations.isEmpty()) return;

        for (DiagnosticDecoration diag : decorations) {
            if (diag.origin == null) continue;
            int color;
            if (diag.color != 0) {
                color = diag.color;
            } else {
                switch (diag.severity) {
                    case 0:
                        color = mTheme.diagnosticErrorColor;
                        break;
                    case 1:
                        color = mTheme.diagnosticWarningColor;
                        break;
                    case 2:
                        color = mTheme.diagnosticInfoColor;
                        break;
                    default:
                        color = mTheme.diagnosticHintColor;
                        break;
                }
            }
            mDiagnosticPaint.setColor(color);

            float startX = diag.origin.x;
            float endX = startX + diag.width;
            float baseY = diag.origin.y + diag.height - 1.0f;

            if (diag.severity == 3) {
                mDiagnosticPaint.setPathEffect(mDiagnosticDashEffect);
                canvas.drawLine(startX, baseY, endX, baseY, mDiagnosticPaint);
                mDiagnosticPaint.setPathEffect(null);
            } else {
                float halfWave = 7.0f;
                float amplitude = 3.5f;
                Path path = new Path();
                path.moveTo(startX, baseY);
                float x = startX;
                int step = 0;
                while (x < endX) {
                    float nextX = Math.min(x + halfWave, endX);
                    float midX = (x + nextX) / 2;
                    float peakY = (step % 2 == 0) ? baseY - amplitude : baseY + amplitude;
                    path.quadTo(midX, peakY, nextX, baseY);
                    x = nextX;
                    step++;
                }
                canvas.drawPath(path, mDiagnosticPaint);
            }
        }
    }

    private void drawLinkedEditingRects(Canvas canvas, @Nullable List<LinkedEditingRect> rects) {
        if (rects == null || rects.isEmpty()) return;
        for (LinkedEditingRect rect : rects) {
            if (rect.origin == null) continue;
            Paint paint = rect.isActive ? mLinkedEditingActivePaint : mLinkedEditingInactivePaint;
            if (rect.isActive) {
                int color = mTheme.linkedEditingActiveColor;
                int bgColor = (color & 0x00FFFFFF) | 0x20000000;
                Paint bgPaint = new Paint();
                bgPaint.setColor(bgColor);
                bgPaint.setStyle(Paint.Style.FILL);
                canvas.drawRect(rect.origin.x, rect.origin.y,
                        rect.origin.x + rect.width,
                        rect.origin.y + rect.height, bgPaint);
            }
            canvas.drawRect(rect.origin.x, rect.origin.y,
                    rect.origin.x + rect.width,
                    rect.origin.y + rect.height, paint);
        }
    }

    private void drawBracketHighlightRects(Canvas canvas, @Nullable List<BracketHighlightRect> rects) {
        if (rects == null || rects.isEmpty()) return;
        for (BracketHighlightRect rect : rects) {
            if (rect.origin == null) continue;
            canvas.drawRect(rect.origin.x, rect.origin.y,
                    rect.origin.x + rect.width,
                    rect.origin.y + rect.height, mBracketHighlightBgPaint);
            canvas.drawRect(rect.origin.x, rect.origin.y,
                    rect.origin.x + rect.width,
                    rect.origin.y + rect.height, mBracketHighlightBorderPaint);
        }
    }

    private void applyFontStyle(int fontStyle) {
        boolean bold = (fontStyle & TextStyle.BOLD) != 0;
        boolean italic = (fontStyle & TextStyle.ITALIC) != 0;
        int style = Typeface.NORMAL;
        if (bold && italic) style = Typeface.BOLD_ITALIC;
        else if (bold) style = Typeface.BOLD;
        else if (italic) style = Typeface.ITALIC;
        mTextPaint.setTypeface(mTextTypefaces[style]);
        mTextPaint.setStrikeThruText((fontStyle & TextStyle.STRIKETHROUGH) != 0);
    }

    private static boolean isDrawableScrollbar(@Nullable ScrollbarModel scrollbar, float alpha) {
        return scrollbar != null
                && scrollbar.visible
                && alpha > 0f
                && scrollbar.track != null
                && scrollbar.thumb != null
                && scrollbar.track.width > 0f
                && scrollbar.track.height > 0f
                && scrollbar.thumb.width > 0f
                && scrollbar.thumb.height > 0f;
    }

    private static float getScrollbarAlpha(@Nullable ScrollbarModel scrollbar) {
        if (scrollbar == null) return 0f;
        return clamp01(scrollbar.alpha);
    }

    private static float clamp01(float value) {
        return Math.max(0f, Math.min(1f, value));
    }

    private static int multiplyAlpha(int argb, float alphaMultiplier) {
        float m = clamp01(alphaMultiplier);
        int baseAlpha = (argb >>> 24) & 0xFF;
        int outAlpha = Math.round(baseAlpha * m);
        return (outAlpha << 24) | (argb & 0x00FFFFFF);
    }
}
