package com.qiplat.sweeteditor;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PointF;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.os.Handler;
import android.os.Looper;
import android.util.AttributeSet;
import android.util.Log;
import android.util.SparseArray;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Map;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorOptions;
import com.qiplat.sweeteditor.core.HandleConfig;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;

import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;

import com.qiplat.sweeteditor.core.TextMeasurer;
import com.qiplat.sweeteditor.core.foundation.AutoIndentMode;
import com.qiplat.sweeteditor.core.foundation.FoldArrowMode;
import com.qiplat.sweeteditor.core.foundation.ScrollBehavior;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.foundation.WrapMode;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.perf.MeasurePerfStats;
import com.qiplat.sweeteditor.perf.PerfOverlay;
import com.qiplat.sweeteditor.perf.PerfStepRecorder;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.completion.CompletionItem;
import com.qiplat.sweeteditor.completion.CompletionItemViewFactory;
import com.qiplat.sweeteditor.completion.CompletionPopupController;
import com.qiplat.sweeteditor.completion.CompletionProvider;
import com.qiplat.sweeteditor.completion.CompletionProviderManager;
import com.qiplat.sweeteditor.completion.CompletionContext;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationProviderManager;
import com.qiplat.sweeteditor.newline.NewLineAction;
import com.qiplat.sweeteditor.newline.NewLineActionProvider;
import com.qiplat.sweeteditor.newline.NewLineActionProviderManager;
import com.qiplat.sweeteditor.newline.NewLineContext;
import com.qiplat.sweeteditor.event.ContextMenuEvent;
import com.qiplat.sweeteditor.event.CursorChangedEvent;
import com.qiplat.sweeteditor.event.DocumentLoadedEvent;
import com.qiplat.sweeteditor.event.DoubleTapEvent;
import com.qiplat.sweeteditor.event.EditorEvent;
import com.qiplat.sweeteditor.event.EditorEventBus;
import com.qiplat.sweeteditor.event.EditorEventListener;
import com.qiplat.sweeteditor.event.FoldToggleEvent;
import com.qiplat.sweeteditor.event.GutterIconClickEvent;
import com.qiplat.sweeteditor.event.InlayHintClickEvent;
import com.qiplat.sweeteditor.event.LongPressEvent;
import com.qiplat.sweeteditor.event.ScaleChangedEvent;
import com.qiplat.sweeteditor.event.ScrollChangedEvent;
import com.qiplat.sweeteditor.event.SelectionChangedEvent;
import com.qiplat.sweeteditor.event.TextChangeAction;
import com.qiplat.sweeteditor.event.TextChangedEvent;

import java.util.List;

/**
 * SweetEditor editor view, providing code editing, syntax highlighting, code folding, InlayHint and other features.
 * <p>
 * Based on C++ core ({@link EditorCore}) for text layout and editing logic,
 * this class handles Android platform rendering, gestures, input method integration and public APIs.
 */
public class SweetEditor extends View {
    private static final String TAG = SweetEditor.class.getSimpleName();
    private static final boolean ENABLE_PERF_LOG = true;
    private static final int PERF_LOG_INTERVAL = 60; // Print perf log every 60 frames to avoid Log I/O affecting frame time

    // Performance stats tools
    private final MeasurePerfStats mMeasurePerfStats = new MeasurePerfStats();
    private final PerfOverlay mPerfOverlay = new PerfOverlay();
    private int mPerfLogFrameCount = 0;

    // RenderModel cache: skip buildRenderModel for pure visual changes like cursor blink
    @Nullable
    private EditorRenderModel mCachedModel;
    private boolean mModelDirty = true;

    /**
     * Editor icon provider interface.
     * Platform implementation provides icon Drawables for gutter icons and InlayHint ICON types.
     */
    public interface EditorIconProvider {
        /**
         * Get the Drawable for a given icon ID.
         *
         * @param iconId icon ID (passed from setLineGutterIcons / InlayHint.iconId)
         * @return icon Drawable, returns null if not drawn
         */
        @Nullable
        Drawable getIconDrawable(int iconId);
    }

    // ==================== Construction/Init/Lifecycle ====================

    private EditorCore mEditorCore;
    private TextMeasurer mTextMeasurer;
    private Document mDocument;
    private EditorIconProvider mEditorIconProvider;
    private final EditorEventBus mEventBus = new EditorEventBus();
    private DecorationProviderManager mDecorationProviderManager;
    private CompletionProviderManager mCompletionProviderManager;
    private CompletionPopupController mCompletionPopupController;
    private NewLineActionProviderManager mNewLineActionProviderManager;
    @Nullable
    private LanguageConfiguration mLanguageConfiguration;
    @Nullable
    private EditorMetadata mMetadata;
    /**
     * Current theme (default dark).
     */
    private EditorTheme mTheme = EditorTheme.dark();

    // Paints for drawing
    private Paint mBackgroundPaint;
    private Paint mTextPaint;
    private Paint mInlayHintPaint;
    private Paint mInlayHintBgPaint;
    // Pre-cached Typeface (avoid Typeface.create on every draw)
    private final Typeface[] mTextTypefaces = new Typeface[4];
    private final Typeface[] mInlayHintTypefaces = new Typeface[4];
    // Reuse FontMetrics objects, avoid allocation per frame
    private final Paint.FontMetrics mInlayHintFontMetrics = new Paint.FontMetrics();
    private final Paint.FontMetrics mTextFontMetrics = new Paint.FontMetrics();
    private Paint mCursorPaint;
    private Paint mSelectionPaint;
    private Paint mLineNumberPaint;
    private Paint mCurrentLinePaint;
    private Paint mGuidePaint;
    private Paint mSeparatorLinePaint;
    private Paint mCompositionPaint;
    private Paint mSplitLinePaint;
    private Paint mHandlePaint;
    private Paint mFoldArrowPaint;
    private Paint mDiagnosticPaint;
    private DashPathEffect mDiagnosticDashEffect;
    private Paint mLinkedEditingActivePaint;
    private Paint mLinkedEditingInactivePaint;
    private Paint mBracketHighlightBorderPaint;
    private Paint mBracketHighlightBgPaint;

    // Cursor blink
    private boolean mCursorVisible = true;
    private final Handler mHandler = new Handler(Looper.getMainLooper());
    private final Runnable mCursorBlink = new Runnable() {
        @Override
        public void run() {
            mCursorVisible = !mCursorVisible;
            // Cursor blink only changes mCursorVisible, does not mark mModelDirty,
            // onDraw reuses cached EditorRenderModel, skips buildRenderModel
            postInvalidate();
            mHandler.postDelayed(this, 500);
        }
    };

    public SweetEditor(Context context) {
        super(context);
        initView(context);
    }

    public SweetEditor(Context context, AttributeSet attrs) {
        super(context, attrs);
        initView(context);
    }

    public SweetEditor(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
        initView(context);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        int width = MeasureSpec.getSize(widthMeasureSpec);
        int height = MeasureSpec.getSize(heightMeasureSpec);
        setMeasuredDimension(width, height);
        mEditorCore.setViewport(width, height);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
        EditorCore.GestureResult result = mEditorCore.handleGestureEvent(event);
        Log.d(TAG, "result: " + result);
        PointF screenPoint = new PointF(event.getX(), event.getY());
        fireGestureEvents(result, screenPoint);
        if (result.type == EditorCore.GestureType.TAP) {
            requestFocus();
            showSoftKeyboard();
            resetCursorBlink();
        } else if (result.type == EditorCore.GestureType.SCALE) {
            // C++ core already applies scale during gesture handling; only sync platform-side measurer/paints here.
            syncPlatformScale(result.viewScale);
        }
        flush();
        if (ENABLE_PERF_LOG) {
            float ms = (System.nanoTime() - t0) / 1_000_000f;
            if (ms >= PerfOverlay.WARN_INPUT_MS) {
                Log.w(TAG, String.format("[PERF][SLOW] onTouchEvent: %.2f ms", ms));
            }
            mPerfOverlay.recordInput("touch", ms);
        }
        return true;
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
        outAttrs.inputType = EditorInfo.TYPE_CLASS_TEXT | EditorInfo.TYPE_TEXT_FLAG_MULTI_LINE;
        outAttrs.imeOptions = EditorInfo.IME_FLAG_NO_EXTRACT_UI | EditorInfo.IME_ACTION_NONE;
        return new SweetEditorInputConnection(this, true);
    }

    @Override
    public boolean onCheckIsTextEditor() {
        return true;
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        handleKeyEventFromIME(event);
        return true;
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        PerfStepRecorder drawPerf = ENABLE_PERF_LOG ? PerfStepRecorder.start() : null;

        // Only rebuild when model is dirty (pure visual changes like cursor blink reuse cache)
        if (mModelDirty) {
            mMeasurePerfStats.reset();
            if (ENABLE_PERF_LOG) mTextMeasurer.setPerfStats(mMeasurePerfStats);
            mCachedModel = mEditorCore.buildRenderModel();
            if (ENABLE_PERF_LOG) mTextMeasurer.setPerfStats(null);
            mModelDirty = false;
        }
        EditorRenderModel model = mCachedModel;
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_BUILD);

        if (model == null) {
            canvas.drawColor(mTheme.backgroundColor);
            return;
        }
        // Background
        canvas.drawColor(mTheme.backgroundColor);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_CLEAR);
        // Current line highlight
        if (model.currentLine != null) {
            float lineHeight = model.cursor != null ? model.cursor.height : 20;
            canvas.drawRect(0, model.currentLine.y,
                    getWidth(), model.currentLine.y + lineHeight,
                    mCurrentLinePaint);
        }
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_CURRENT);
        // Selection highlight
        drawSelectionRects(canvas, model.selectionRects);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_SELECTION);
        // Draw text lines (run.x may be negative, overflow to line number area)
        drawLines(canvas, model);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_LINES);
        // Code structure lines
        drawGuideSegments(canvas, model.guideSegments);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_GUIDES);
        // Composition input underline
        drawCompositionDecoration(canvas, model.compositionDecoration);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_COMPOSITION);
        // Diagnostic decorations (wavy/dashed lines)
        drawDiagnosticDecorations(canvas, model.diagnosticDecorations);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_DIAGNOSTICS);
        // Linked editing highlight (tab stop borders)
        drawLinkedEditingRects(canvas, model.linkedEditingRects);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_LINKED);
        // Bracket pair highlight
        drawBracketHighlightRects(canvas, model.bracketHighlightRects);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_BRACKET);
        // Cursor
        drawCursor(canvas, model.cursor);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_CURSOR);
        // Cover overflow text/decoration lines/cursor with gutter background, then draw line numbers and split line
        if (model.splitX > 0) {
            canvas.drawRect(0, 0, model.splitX, getHeight(), mBackgroundPaint);
            if (model.currentLine != null) {
                float lineHeight = model.cursor != null ? model.cursor.height : 20;
                canvas.drawRect(0, model.currentLine.y,
                        model.splitX, model.currentLine.y + lineHeight,
                        mCurrentLinePaint);
            }
            canvas.drawLine(model.splitX, 0, model.splitX, getHeight(), mSplitLinePaint);
        }
        // Draw line number text
        drawLineNumbers(canvas, model);
        if (drawPerf != null) drawPerf.mark(PerfStepRecorder.STEP_GUTTER);
        // Selection handles (drag handles)
        drawSelectionHandles(canvas, model.selectionStartHandle, model.selectionEndHandle);
        if (drawPerf != null) {
            drawPerf.mark(PerfStepRecorder.STEP_HANDLES);
            drawPerf.finish(); // Lock end time immediately to avoid subsequent log/overlay code affecting stats
        }

        // Completion panel cursor follow
        if (mCompletionPopupController != null && model.cursor != null && model.cursor.position != null) {
            mCompletionPopupController.updateCursorPosition(
                    model.cursor.position.x, model.cursor.position.y, model.cursor.height);
        }

        // Perf log + debug overlay
        if (drawPerf != null) {
            float buildMs = drawPerf.getStepMs(PerfStepRecorder.STEP_BUILD);
            float totalMs = drawPerf.getTotalMs();
            float drawMs = totalMs - buildMs;

            // Log when exceeding threshold (sampled: every PERF_LOG_INTERVAL frames to avoid Log I/O affecting frame time)
            mPerfLogFrameCount++;
            if (mPerfLogFrameCount >= PERF_LOG_INTERVAL) {
                mPerfLogFrameCount = 0;
                if (totalMs >= PerfOverlay.WARN_PAINT_MS || drawPerf.anyStepOver(PerfOverlay.WARN_PAINT_STEP_MS)) {
                    Log.w(TAG, "[PERF][Paint] " + drawPerf.buildSummary());
                }
                if (buildMs >= PerfOverlay.WARN_BUILD_MS || mMeasurePerfStats.shouldLog()) {
                    Log.w(TAG, "[PERF][Build] build=" + String.format("%.2fms", buildMs)
                            + " | " + mMeasurePerfStats.buildSummary());
                }
            }

            mPerfOverlay.recordFrame(buildMs, drawMs, totalMs, drawPerf, mMeasurePerfStats);
            mPerfOverlay.draw(canvas, getWidth());
        }
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        mHandler.postDelayed(mCursorBlink, 500);
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        mHandler.removeCallbacks(mCursorBlink);
    }

    @Override
    public void onWindowFocusChanged(boolean hasWindowFocus) {
        super.onWindowFocusChanged(hasWindowFocus);
        if (hasWindowFocus) {
            resetCursorBlink();
        } else {
            mHandler.removeCallbacks(mCursorBlink);
        }
    }

    // ==================== Document Loading ====================

    /**
     * Load document into editor, replace current content and reset view state.
     *
     * @param document document to load (must not be null)
     */
    public void loadDocument(Document document) {
        mDocument = document;
        mEditorCore.loadDocument(document);
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.onDocumentLoaded();
        }
        mEventBus.publish(new DocumentLoadedEvent());
        flush();
    }

    @Nullable
    public Document getDocument() {
        return mDocument;
    }

    // ==================== Viewport/Font/Appearance Config ====================

    /**
     * Set editor font, affects text measurement and rendering.
     *
     * @param typeface target font (monospace recommended for best alignment)
     */
    public void setTypeface(Typeface typeface) {
        mTextMeasurer.setTypeface(typeface);
        mEditorCore.resetMeasurer();
        flush();
    }

    /**
     * Set base text size (sp), InlayHint and line number sizes adjust proportionally.
     *
     * @param textSize text size (in px)
     */
    public void setEditorTextSize(float textSize) {
        mTextMeasurer.setTextSize(textSize);
        mInlayHintPaint.setTextSize(textSize * 0.9f);
        mLineNumberPaint.setTextSize(textSize * 0.85f);
        mEditorCore.resetMeasurer();
        flush();
    }

    /**
     * Set global scale, triggers layout recalculation.
     *
     * @param scale scale factor (1.0 = 100%)
     */
    public void setScale(float scale) {
        mEditorCore.setScale(scale);
        syncPlatformScale(scale);
        flush();
    }

    /** Sync platform-side text measurement and paint sizes to the latest scale. */
    private void syncPlatformScale(float scale) {
        mTextMeasurer.setScale(scale);
        mInlayHintPaint.setTextSize(mTextPaint.getTextSize() * 0.9f);
        mLineNumberPaint.setTextSize(mTextPaint.getTextSize() * 0.85f);
        mEditorCore.resetMeasurer();
    }

    /**
     * Set fold arrow display mode (affects gutter area width reservation).
     *
     * @param mode fold arrow mode
     */
    public void setFoldArrowMode(@NonNull FoldArrowMode mode) {
        mEditorCore.setFoldArrowMode(mode.value);
    }

    /**
     * Set auto wrap mode.
     *
     * @param mode auto wrap mode
     */
    public void setWrapMode(@NonNull WrapMode mode) {
        mEditorCore.setWrapMode(mode.value);
        flush();
    }

    /**
     * Set line spacing parameter (formula: line_height = font_height * mult + add).
     *
     * @param add  extra line spacing in pixels (default 0)
     * @param mult line spacing multiplier (default 1.0)
     */
    public void setLineSpacing(float add, float mult) {
        mEditorCore.setLineSpacing(add, mult);
        flush();
    }

    /**
     * Get current theme.
     *
     * @return current applied {@link EditorTheme} instance
     */
    public EditorTheme getTheme() {
        return mTheme;
    }

    /**
     * Apply editor theme, update all color and opacity properties.
     *
     * @param theme theme configuration
     */
    public void applyTheme(EditorTheme theme) {
        mTheme = theme;

        // Update colors for all Paint objects
        if (mBackgroundPaint != null) mBackgroundPaint.setColor(theme.backgroundColor);
        if (mTextPaint != null) mTextPaint.setColor(theme.textColor);
        if (mInlayHintPaint != null) mInlayHintPaint.setColor(theme.inlayHintTextColor);
        if (mInlayHintBgPaint != null) mInlayHintBgPaint.setColor(theme.inlayHintBgColor);
        if (mCursorPaint != null) mCursorPaint.setColor(theme.cursorColor);
        if (mSelectionPaint != null) mSelectionPaint.setColor(theme.selectionColor);
        if (mLineNumberPaint != null) mLineNumberPaint.setColor(theme.lineNumberColor);
        if (mCurrentLinePaint != null) mCurrentLinePaint.setColor(theme.currentLineColor);
        if (mGuidePaint != null) mGuidePaint.setColor(theme.guideColor);
        if (mSeparatorLinePaint != null) mSeparatorLinePaint.setColor(theme.separatorLineColor);
        if (mCompositionPaint != null) mCompositionPaint.setColor(theme.compositionUnderlineColor);
        if (mSplitLinePaint != null) mSplitLinePaint.setColor(theme.splitLineColor);
        if (mHandlePaint != null) mHandlePaint.setColor(theme.cursorColor);
        if (mFoldArrowPaint != null) mFoldArrowPaint.setColor(theme.lineNumberColor);
        if (mLinkedEditingActivePaint != null) mLinkedEditingActivePaint.setColor(theme.linkedEditingActiveColor);
        if (mLinkedEditingInactivePaint != null) mLinkedEditingInactivePaint.setColor(theme.linkedEditingInactiveColor);
        if (mBracketHighlightBorderPaint != null) mBracketHighlightBorderPaint.setColor(theme.bracketHighlightBorderColor);
        if (mBracketHighlightBgPaint != null) mBracketHighlightBgPaint.setColor(theme.bracketHighlightBgColor);

        // Re-register syntax highlight styles from theme to C++ core
        for (Map.Entry<Integer, int[]> entry : theme.syntaxStyles.entrySet()) {
            int[] style = entry.getValue();
            mEditorCore.registerStyle(entry.getKey(), style[0], style[1]);
        }

        flush();
    }

    @NonNull
    EditorCore getEditorCore() {
        return mEditorCore;
    }

    public int[] getVisibleLineRange() {
        // Reuse cached model, build once if not exists
        EditorRenderModel model = mCachedModel;
        if (model == null) {
            model = mEditorCore.buildRenderModel();
        }
        if (model == null || model.lines == null || model.lines.isEmpty()) {
            return new int[]{0, -1};
        }
        int start = Integer.MAX_VALUE;
        int end = -1;
        for (VisualLine line : model.lines) {
            if (line == null) continue;
            if (line.logicalLine < start) start = line.logicalLine;
            if (line.logicalLine > end) end = line.logicalLine;
        }
        if (start == Integer.MAX_VALUE) start = 0;
        return new int[]{start, end};
    }

    public int getTotalLineCount() {
        return mDocument == null ? -1 : mDocument.getLineCount();
    }

    // ==================== Text Editing ====================

    /**
     * Insert text at current cursor position (replaces selection if exists). Triggers {@link TextChangedEvent} automatically.
     *
     * @param text text to insert (supports multiple lines, use {@code \n} for newlines)
     * @return edit result containing change range and old/new text
     */
    public EditorCore.TextEditResult insertText(@NonNull String text) {
        EditorCore.TextEditResult result = mEditorCore.insertText(text);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Replace specified text range (atomic operation). Triggers {@link TextChangedEvent} automatically.
     *
     * @param range   text range to replace (when start == end, equivalent to insert)
     * @param newText new text after replacement (empty string is equivalent to delete)
     * @return edit result containing change range and old/new text
     */
    public EditorCore.TextEditResult replaceText(@NonNull TextRange range, @NonNull String newText) {
        EditorCore.TextEditResult result = mEditorCore.replaceText(range, newText);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Delete specified text range (atomic operation). Triggers {@link TextChangedEvent} automatically.
     *
     * @param range text range to delete
     * @return edit result containing change range
     */
    public EditorCore.TextEditResult deleteText(@NonNull TextRange range) {
        EditorCore.TextEditResult result = mEditorCore.deleteText(range);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    // ==================== Line Operations ====================

    /** Move current line (or lines covered by selection) up by one. */
    public EditorCore.TextEditResult moveLineUp() {
        EditorCore.TextEditResult result = mEditorCore.moveLineUp();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /** Move current line (or lines covered by selection) down by one. */
    public EditorCore.TextEditResult moveLineDown() {
        EditorCore.TextEditResult result = mEditorCore.moveLineDown();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /** Duplicate current line (or lines covered by selection) above. */
    public EditorCore.TextEditResult copyLineUp() {
        EditorCore.TextEditResult result = mEditorCore.copyLineUp();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /** Duplicate current line (or lines covered by selection) below. */
    public EditorCore.TextEditResult copyLineDown() {
        EditorCore.TextEditResult result = mEditorCore.copyLineDown();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /** Delete current line (or all lines covered by selection). */
    public EditorCore.TextEditResult deleteLine() {
        EditorCore.TextEditResult result = mEditorCore.deleteLine();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /** Insert empty line above current line. */
    public EditorCore.TextEditResult insertLineAbove() {
        EditorCore.TextEditResult result = mEditorCore.insertLineAbove();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /** Insert empty line below current line. */
    public EditorCore.TextEditResult insertLineBelow() {
        EditorCore.TextEditResult result = mEditorCore.insertLineBelow();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    // ==================== Undo/Redo ====================

    /**
     * Undo last edit operation. Triggers {@link TextChangedEvent} automatically.
     *
     * @return edit result; if no operation to undo, {@code result.changed} is false
     */
    public EditorCore.TextEditResult undo() {
        EditorCore.TextEditResult result = mEditorCore.undo();
        dispatchTextChanged(TextChangeAction.UNDO, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Redo last undone operation. Triggers {@link TextChangedEvent} automatically.
     *
     * @return edit result; if no operation to redo, {@code result.changed} is false
     */
    public EditorCore.TextEditResult redo() {
        EditorCore.TextEditResult result = mEditorCore.redo();
        dispatchTextChanged(TextChangeAction.REDO, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Check if there are operations that can be undone.
     *
     * @return {@code true} if undo is available
     */
    public boolean canUndo() {
        return mEditorCore.canUndo();
    }

    /**
     * Check if there are operations that can be redone.
     *
     * @return {@code true} if redo is available
     */
    public boolean canRedo() {
        return mEditorCore.canRedo();
    }

    // ==================== Cursor/Selection Management ====================

    /**
     * Select all document content.
     */
    public void selectAll() {
        mEditorCore.selectAll();
        flush();
    }

    /**
     * Get text within current selection.
     *
     * @return selection text; returns null or empty if no selection
     */
    @Nullable
    public String getSelectedText() {
        return mEditorCore.getSelectedText();
    }

    /**
     * Programmatically set selection range.
     *
     * @param startLine   start line (0-based)
     * @param startColumn start column (0-based)
     * @param endLine     end line (0-based)
     * @param endColumn   end column (0-based)
     */
    public void setSelection(int startLine, int startColumn, int endLine, int endColumn) {
        mEditorCore.setSelection(startLine, startColumn, endLine, endColumn);
        flush();
    }

    /**
     * @see #setSelection(int, int, int, int)
     */
    public void setSelection(@NonNull TextRange range) {
        mEditorCore.setSelection(range);
        flush();
    }

    /**
     * Get current selection range.
     *
     * @return selection start/end positions; returns null if no selection
     */
    @Nullable
    public TextRange getSelection() {
        return mEditorCore.getSelection();
    }

    /**
     * Get current cursor position.
     *
     * @return cursor row/column position (0-based)
     */
    @NonNull
    public TextPosition getCursorPosition() {
        return mEditorCore.getCursorPosition();
    }

    /**
     * Get text range of word at cursor.
     *
     * @return word range (start/end row/column, 0-based)
     */
    @NonNull
    public TextRange getWordRangeAtCursor() {
        return mEditorCore.getWordRangeAtCursor();
    }

    /**
     * Get text content of word at cursor.
     *
     * @return word text, returns empty string if cursor is not on a word
     */
    @NonNull
    public String getWordAtCursor() {
        return mEditorCore.getWordAtCursor();
    }

    /**
     * Set cursor position (does not scroll viewport, only moves cursor).
     * To scroll viewport simultaneously, use {@link #gotoPosition(int,int)}.
     *
     * @param position target position
     */
    public void setCursorPosition(@NonNull TextPosition position) {
        mEditorCore.setCursorPosition(position);
        flush();
    }

    // ==================== Clipboard Operations ====================

    /**
     * Copy current selection text to system clipboard.
     */
    public void copyToClipboard() {
        String selected = getSelectedText();
        if (selected != null && !selected.isEmpty()) {
            ClipboardManager clipboard = (ClipboardManager) getContext()
                    .getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(ClipData.newPlainText("SweetEditor", selected));
            }
        }
    }

    /**
     * Paste text from system clipboard to current cursor position (replaces selection if exists).
     */
    public void pasteFromClipboard() {
        ClipboardManager clipboard = (ClipboardManager) getContext()
                .getSystemService(Context.CLIPBOARD_SERVICE);
        if (clipboard != null && clipboard.hasPrimaryClip()) {
            ClipData clip = clipboard.getPrimaryClip();
            if (clip != null && clip.getItemCount() > 0) {
                CharSequence pasteText = clip.getItemAt(0).coerceToText(getContext());
                if (pasteText != null && pasteText.length() > 0) {
                    insertText(pasteText.toString());
                }
            }
        }
    }

    /**
     * Cut current selection text to system clipboard.
     */
    public void cutToClipboard() {
        String selected = getSelectedText();
        if (selected != null && !selected.isEmpty()) {
            ClipboardManager clipboard = (ClipboardManager) getContext()
                    .getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(ClipData.newPlainText("SweetEditor", selected));
            }
            insertText("");
        }
    }

    // ==================== Read-Only Mode API ====================

    /**
     * Set read-only mode.
     *
     * @param readOnly true=read-only (disallow all edit operations), false=editable
     */
    public void setReadOnly(boolean readOnly) {
        mEditorCore.setReadOnly(readOnly);
    }

    /**
     * Get whether currently in read-only mode.
     *
     * @return {@code true} if currently read-only
     */
    public boolean isReadOnly() {
        return mEditorCore.isReadOnly();
    }

    // ==================== Auto-Indent API ====================

    /**
     * Set auto-indent mode.
     *
     * @param mode auto-indent mode
     */
    public void setAutoIndentMode(@NonNull AutoIndentMode mode) {
        mEditorCore.setAutoIndentMode(mode.value);
    }

    /**
     * Get current auto-indent mode.
     *
     * @return auto-indent mode value
     */
    public int getAutoIndentMode() {
        return mEditorCore.getAutoIndentMode();
    }

    // ==================== Position/Coordinate Query API ====================

    /**
     * Get screen coordinate rectangle for any text position (for floating panel positioning).
     * <p>
     * Returned coordinates are relative to the editor View top-left; caller needs to convert to screen coordinates if needed.
     *
     * @param line   line number (0-based)
     * @param column column number (0-based)
     * @return CursorRect (x, y, height)
     */
    @NonNull
    public CursorRect getPositionRect(int line, int column) {
        return mEditorCore.getPositionRect(line, column);
    }

    /**
     * Get screen coordinate rectangle for current cursor position (convenience method).
     * <p>
     * Returned coordinates are relative to the editor View top-left; caller needs to convert to screen coordinates if needed.
     *
     * @return CursorRect (x, y, height)
     */
    @NonNull
    public CursorRect getCursorRect() {
        return mEditorCore.getCursorRect();
    }

    // ==================== Scroll/Navigation ====================

    /**
     * Go to specified row/column and scroll viewport to make it visible, also move cursor.
     *
     * @param line   target line number (0-based)
     * @param column target column number (0-based, UTF-16 offset)
     */
    public void gotoPosition(int line, int column) {
        mEditorCore.gotoPosition(line, column);
        flush();
    }

    /**
     * Scroll viewport to make specified line visible (does not move cursor).
     *
     * @param line     target line number (0-based)
     * @param behavior scroll behavior
     */
    public void scrollToLine(int line, @NonNull ScrollBehavior behavior) {
        mEditorCore.scrollToLine(line, behavior.value);
        flush();
    }

    /**
     * Manually set scroll position (automatically clamped to valid range).
     */
    public void setScroll(float scrollX, float scrollY) {
        mEditorCore.setScroll(scrollX, scrollY);
        flush();
    }

    /**
     * Get scrollbar metrics (for platform scrollbar drawing).
     */
    @NonNull
    public ScrollMetrics getScrollMetrics() {
        return mEditorCore.getScrollMetrics();
    }

    // ==================== Decoration System ====================

    // -------------------- Style Registration + Highlight Spans --------------------

    /**
     * Register a reusable highlight style, referenced later via styleId in {@link #setLineSpans}.
     *
     * @param styleId         style ID (custom, must be unique)
     * @param color           ARGB foreground color
     * @param backgroundColor ARGB background color (0=transparent)
     * @param fontStyle       font style bit flags ({@link FontStyle#NORMAL}, {@link FontStyle#BOLD},
     *                        {@link FontStyle#ITALIC}, {@link FontStyle#STRIKETHROUGH}, combinable via bitwise OR)
     */
    public void registerStyle(int styleId, int color, int backgroundColor, int fontStyle) {
        mEditorCore.registerStyle(styleId, color, backgroundColor, fontStyle);
    }

    /**
     * Register a reusable highlight style (no background, backward compatible).
     *
     * @param styleId   Style ID (custom, must be unique)
     * @param color     ARGB foreground color
     * @param fontStyle Font style bit flags
     */
    public void registerStyle(int styleId, int color, int fontStyle) {
        mEditorCore.registerStyle(styleId, color, fontStyle);
    }

    /**
     * Set highlight spans for a specified line and layer using a list of {@link StyleSpan}.
     *
     * @param line  Line number (0-based)
     * @param layer Layer index
     * @param spans Span list (accepts {@link StyleSpan} and its subclasses)
     */
    public void setLineSpans(int line, @NonNull SpanLayer layer, @NonNull List<? extends StyleSpan> spans) {
        mEditorCore.setLineSpans(line, layer.value, spans);
    }



    /**
     * Batch set highlight spans for multiple lines (reduces JNI calls, single dirty mark).
     *
     * @param layer       Highlight layer
     * @param spansByLine Sparse array of line number → span list
     */
    public void setBatchLineSpans(SpanLayer layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine) {
        mEditorCore.setBatchLineSpans(layer.value, spansByLine);
    }

    // -------------------- InlayHint / PhantomText --------------------

    /**
     * Batch set Inlay Hints for a specified line (replaces entire line, efficient binary protocol).
     *
     * @param line  Line number (0-based)
     * @param hints InlayHint list
     */
    public void setLineInlayHints(int line, @NonNull List<? extends InlayHint> hints) {
        mEditorCore.setLineInlayHints(line, hints);
    }

    /**
     * Batch set Inlay Hints for multiple lines (reduces JNI calls, single dirty mark).
     *
     * @param hintsByLine Sparse array of line number → hint list
     */
    public void setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine) {
        mEditorCore.setBatchLineInlayHints(hintsByLine);
    }

    /**
     * Set phantom text for a specified line (replaces entire line), rendered in semi-transparent style.
     * <p>Does not affect actual document content.
     *
     * @param line     Line number (0-based)
     * @param phantoms Phantom text list (sorted by column ascending)
     */
    public void setLinePhantomTexts(int line, @NonNull List<? extends PhantomText> phantoms) {
        mEditorCore.setLinePhantomTexts(line, phantoms);
    }

    /**
     * Batch set phantom text for multiple lines (reduces JNI calls, single dirty mark).
     *
     * @param phantomsByLine Sparse array of line number → phantom list
     */
    public void setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        mEditorCore.setBatchLinePhantomTexts(phantomsByLine);
    }

    // -------------------- Gutter Icons --------------------

    /**
     * Set maximum gutter icon count, affects gutter area width reservation.
     * <p>Set to 0 to enable overlay mode (icons overlay line numbers, no extra width, suitable for mobile).
     *
     * @param count Maximum icon count (0=overlay mode, default 0)
     */
    public void setMaxGutterIcons(int count) {
        mEditorCore.setMaxGutterIcons(count);
    }

    /**
     * Set gutter icons for a specified line (replaces entire line).
     * <p>Icon Drawables are provided by {@link EditorIconProvider}.
     *
     * @param line  Line number (0-based)
     * @param icons Icon list
     */
    public void setLineGutterIcons(int line, @NonNull List<? extends GutterIcon> icons) {
        mEditorCore.setLineGutterIcons(line, icons);
    }

    /**
     * Batch set gutter icons for multiple lines (reduces JNI calls).
     *
     * @param iconsByLine Sparse array of line number → icon list
     */
    public void setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine) {
        mEditorCore.setBatchLineGutterIcons(iconsByLine);
    }

    // -------------------- Diagnostic Decorations --------------------

    /**
     * Set diagnostic decorations for a specified line.
     *
     * @param line  Line number (0-based)
     * @param items Diagnostic item list
     */
    public void setLineDiagnostics(int line, @NonNull List<? extends DiagnosticItem> items) {
        mEditorCore.setLineDiagnostics(line, items);
    }

    /**
     * Batch set diagnostic decorations for multiple lines (reduces JNI calls).
     *
     * @param diagsByLine Sparse array of line number → diagnostic list
     */
    public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends DiagnosticItem>> diagsByLine) {
        mEditorCore.setBatchLineDiagnostics(diagsByLine);
    }

    // -------------------- Guides (Code Structure Lines) --------------------

    /**
     * Set indent guide list (global replacement).
     *
     * @param guides Indent guide list
     */
    public void setIndentGuides(@NonNull List<IndentGuide> guides) {
        mEditorCore.setIndentGuides(guides);
    }

    /**
     * Set bracket matching branch line list (global replacement).
     *
     * @param guides Bracket matching branch line list
     */
    public void setBracketGuides(@NonNull List<BracketGuide> guides) {
        mEditorCore.setBracketGuides(guides);
    }

    /**
     * Set control flow return arrow list (global replacement).
     *
     * @param guides Control flow return arrow list
     */
    public void setFlowGuides(@NonNull List<FlowGuide> guides) {
        mEditorCore.setFlowGuides(guides);
    }

    /**
     * Set horizontal separator line list (global replacement).
     *
     * @param guides Horizontal separator line list
     */
    public void setSeparatorGuides(@NonNull List<SeparatorGuide> guides) {
        mEditorCore.setSeparatorGuides(guides);
    }

    // -------------------- Fold (Code Folding) --------------------

    /**
     * Set foldable regions using a list of {@link FoldRegion} (replaces existing list).
     *
     * @param regions Fold region list
     */
    public void setFoldRegions(@NonNull List<? extends FoldRegion> regions) {
        mEditorCore.setFoldRegions(regions);
    }



    /**
     * Toggle fold/expand state of the region containing the specified line.
     *
     * @param line Line number (0-based, usually the first line of fold)
     * @return true if region found and state toggled
     */
    public boolean toggleFoldAt(int line) {
        boolean result = mEditorCore.toggleFoldAt(line);
        if (result) flush();
        return result;
    }

    /**
     * Fold the region containing the specified line.
     *
     * @param line Line number (0-based)
     * @return true if successfully folded
     */
    public boolean foldAt(int line) {
        boolean result = mEditorCore.foldAt(line);
        if (result) flush();
        return result;
    }

    /**
     * Unfold the region containing the specified line.
     *
     * @param line Line number (0-based)
     * @return true if successfully unfolded
     */
    public boolean unfoldAt(int line) {
        boolean result = mEditorCore.unfoldAt(line);
        if (result) flush();
        return result;
    }

    /**
     * Fold all regions.
     */
    public void foldAll() {
        mEditorCore.foldAll();
        flush();
    }

    /**
     * Unfold all regions.
     */
    public void unfoldAll() {
        mEditorCore.unfoldAll();
        flush();
    }

    /**
     * Check if the specified line is visible (not hidden by fold).
     *
     * @param line Line number (0-based)
     * @return true if visible
     */
    public boolean isLineVisible(int line) {
        return mEditorCore.isLineVisible(line);
    }

    // -------------------- Linked Editing --------------------

    /**
     * Insert VSCode snippet template and enter linked editing mode.
     *
     * @param snippetTemplate VSCode snippet template
     * @return Exact change information
     */
    @NonNull
    public EditorCore.TextEditResult insertSnippet(@NonNull String snippetTemplate) {
        EditorCore.TextEditResult result = mEditorCore.insertSnippet(snippetTemplate);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Start linked editing mode with a generic LinkedEditingModel.
     *
     * @param model Linked editing model
     */
    public void startLinkedEditing(@NonNull LinkedEditingModel model) {
        mEditorCore.startLinkedEditing(model);
        resetCursorBlink();
        flush();
    }

    /**
     * Check if currently in linked editing mode.
     */
    public boolean isInLinkedEditing() {
        return mEditorCore.isInLinkedEditing();
    }

    /**
     * Linked editing: jump to next tab stop.
     *
     * @return false if at end, session ends automatically
     */
    public boolean linkedEditingNext() {
        boolean result = mEditorCore.linkedEditingNext();
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Linked editing: jump to previous tab stop.
     *
     * @return false if already at first
     */
    public boolean linkedEditingPrev() {
        boolean result = mEditorCore.linkedEditingPrev();
        resetCursorBlink();
        flush();
        return result;
    }

    /**
     * Cancel linked editing mode.
     */
    public void cancelLinkedEditing() {
        mEditorCore.cancelLinkedEditing();
        flush();
    }

    // -------------------- Clear Decorations --------------------

    /**
     * Clear all highlight spans.
     */
    public void clearHighlights() {
        mEditorCore.clearHighlights();
    }

    /**
     * Clear highlight spans for specified layer.
     *
     * @param layer Layer index
     */
    public void clearHighlights(@NonNull SpanLayer layer) {
        mEditorCore.clearHighlights(layer.value);
    }

    /**
     * Clear all Inlay Hints.
     */
    public void clearInlayHints() {
        mEditorCore.clearInlayHints();
    }

    /**
     * Clear all Phantom Texts.
     */
    public void clearPhantomTexts() {
        mEditorCore.clearPhantomTexts();
    }

    /**
     * Clear all gutter icons.
     */
    public void clearGutterIcons() {
        mEditorCore.clearGutterIcons();
    }

    /**
     * Clear all code structure guides (indent vertical lines, bracket matching lines, flow arrows, separator lines).
     */
    public void clearGuides() {
        mEditorCore.clearGuides();
    }

    /**
     * Clear all diagnostic decorations.
     */
    public void clearDiagnostics() {
        mEditorCore.clearDiagnostics();
    }

    /**
     * Clear all decoration data (highlights, Inlay Hints, Phantom Texts, icons, Guide lines, diagnostics).
     */
    public void clearAllDecorations() {
        mEditorCore.clearAllDecorations();
    }

    // ==================== View Layer Extension Configuration ====================

    /**
     * Set language configuration (automatically syncs brackets to Core layer).
     */
    public void setLanguageConfiguration(@Nullable LanguageConfiguration config) {
        mLanguageConfiguration = config;
        if (config != null && !config.getBrackets().isEmpty()) {
            int size = config.getBrackets().size();
            int[] opens = new int[size];
            int[] closes = new int[size];
            for (int i = 0; i < size; i++) {
                LanguageConfiguration.BracketPair pair = config.getBrackets().get(i);
                opens[i] = pair.open.isEmpty() ? 0 : pair.open.codePointAt(0);
                closes[i] = pair.close.isEmpty() ? 0 : pair.close.codePointAt(0);
            }
            mEditorCore.setBracketPairs(opens, closes);
        }
    }

    @Nullable
    public LanguageConfiguration getLanguageConfiguration() {
        return mLanguageConfiguration;
    }

    public <T extends EditorMetadata> void setMetadata(@Nullable T metadata) {
        mMetadata = metadata;
    }

    @SuppressWarnings("unchecked")
    @Nullable
    public <T extends EditorMetadata> T getMetadata() {
        return (T) mMetadata;
    }

    /**
     * Set editor icon provider.
     *
     * @param provider Icon provider, pass null to remove
     */
    public void setEditorIconProvider(@Nullable EditorIconProvider provider) {
        mEditorIconProvider = provider;
    }

    // ==================== Extension Provider API ====================

    public void addDecorationProvider(@NonNull DecorationProvider provider) {
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.addProvider(provider);
        }
    }

    public void removeDecorationProvider(@NonNull DecorationProvider provider) {
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.removeProvider(provider);
        }
    }

    public void requestDecorationRefresh() {
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.requestRefresh();
        }
    }

    /**
     * Register completion Provider.
     */
    public void addCompletionProvider(@NonNull CompletionProvider provider) {
        if (mCompletionProviderManager != null) {
            mCompletionProviderManager.addProvider(provider);
        }
    }

    /**
     * Remove completion Provider.
     */
    public void removeCompletionProvider(@NonNull CompletionProvider provider) {
        if (mCompletionProviderManager != null) {
            mCompletionProviderManager.removeProvider(provider);
        }
    }

    /**
     * Manually trigger completion (via Provider flow).
     */
    public void triggerCompletion() {
        if (mCompletionProviderManager != null) {
            mCompletionProviderManager.triggerCompletion(
                    CompletionContext.TriggerKind.INVOKED, null);
        }
    }

    /**
     * Direct push mode: external caller directly pushes candidate list to the panel,
     * bypassing the Provider/Manager request flow.
     */
    public void showCompletionItems(@NonNull List<CompletionItem> items) {
        if (mCompletionProviderManager != null) {
            mCompletionProviderManager.showItems(items);
        }
    }

    /**
     * Dismiss completion panel.
     */
    public void dismissCompletion() {
        if (mCompletionProviderManager != null) {
            mCompletionProviderManager.dismiss();
        }
    }

    /**
     * Set completion item custom layout factory.
     */
    public void setCompletionItemViewFactory(@Nullable CompletionItemViewFactory factory) {
        if (mCompletionPopupController != null) {
            mCompletionPopupController.setViewFactory(factory);
        }
    }

    public void addNewLineActionProvider(@NonNull NewLineActionProvider provider) {
        if (mNewLineActionProviderManager == null) {
            mNewLineActionProviderManager = new NewLineActionProviderManager();
        }
        mNewLineActionProviderManager.addProvider(provider);
    }

    public void removeNewLineActionProvider(@NonNull NewLineActionProvider provider) {
        if (mNewLineActionProviderManager != null) {
            mNewLineActionProviderManager.removeProvider(provider);
        }
    }

    // ==================== Event Subscription ====================

    /**
     * Subscribe to editor events of specified type (supports Lambda).
     * <pre>
     * editor.subscribe(TextChangedEvent.class, e -> Log.d(TAG, e.action));
     * editor.subscribe(CursorChangedEvent.class, e -> updateStatusBar(e.cursorPosition));
     * editor.subscribe(LongPressEvent.class, e -> showPopup(e.screenPoint));
     * </pre>
     */
    public <T extends EditorEvent> void subscribe(@NonNull Class<T> eventType, @NonNull EditorEventListener<T> listener) {
        mEventBus.subscribe(eventType, listener);
    }

    /**
     * Unsubscribe from previously registered event.
     *
     * @param eventType Event type Class
     * @param listener  Previously registered listener instance (must be the same reference as when subscribing)
     */
    public <T extends EditorEvent> void unsubscribe(@NonNull Class<T> eventType, @NonNull EditorEventListener<T> listener) {
        mEventBus.unsubscribe(eventType, listener);
    }

    // ==================== Performance Debug API ====================

    /**
     * Enable/disable performance info overlay (debug overlay).
     * <p>
     * When enabled, displays real-time performance data in the top-right corner of the editor:
     * FPS, buildModel time, each drawing stage time, text measurement stats, input event time, etc.
     * For debugging only, not recommended for production.
     *
     * @param enabled true=enable, false=disable (default off)
     */
    public void setPerfOverlayEnabled(boolean enabled) {
        mPerfOverlay.setEnabled(enabled);
        postInvalidate();
    }

    /**
     * Check if performance overlay is enabled.
     *
     * @return {@code true} if performance overlay is currently enabled
     */
    public boolean isPerfOverlayEnabled() {
        return mPerfOverlay.isEnabled();
    }

    // ==================== IME Internal Methods (package-private) ====================

    boolean isCompositionEnabled() {
        return mEditorCore.isCompositionEnabled();
    }

    boolean isComposing() {
        return mEditorCore.isComposing();
    }

    void compositionUpdate(@NonNull String text) {
        long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
        mEditorCore.compositionUpdate(text);
        flush();
        logInputPerf(t0, "ime-update");
    }

    // ==================== Event Dispatch (Internal) ====================

    private void dispatchTextChanged(@NonNull TextChangeAction action, @NonNull EditorCore.TextEditResult editResult) {
        if (editResult.changed && !editResult.changes.isEmpty()) {
            for (EditorCore.TextChange change : editResult.changes) {
                mEventBus.publish(new TextChangedEvent(action, change.range, change.newText));
            }
            if (mDecorationProviderManager != null) {
                mDecorationProviderManager.onTextChanged(editResult.changes);
            }
            // Suppress completion trigger during linked editing to avoid conflict with Enter/Tab keys
            if (!mEditorCore.isInLinkedEditing()) {
                // Completion trigger: based on first change (primary change)
                EditorCore.TextChange primaryChange = editResult.changes.get(0);
                if (mCompletionProviderManager != null && primaryChange.newText.length() == 1) {
                    String ch = primaryChange.newText;
                    if (mCompletionProviderManager.isTriggerCharacter(ch)) {
                        mCompletionProviderManager.triggerCompletion(
                                CompletionContext.TriggerKind.CHARACTER, ch);
                    } else if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
                        mCompletionProviderManager.triggerCompletion(
                                CompletionContext.TriggerKind.RETRIGGER, null);
                    } else if (Character.isLetterOrDigit(ch.charAt(0)) || ch.charAt(0) == '_') {
                        mCompletionProviderManager.triggerCompletion(
                                CompletionContext.TriggerKind.INVOKED, null);
                    }
                } else if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
                    if (mCompletionProviderManager != null) {
                        mCompletionProviderManager.triggerCompletion(
                                CompletionContext.TriggerKind.RETRIGGER, null);
                    }
                }
            }
        }
    }

    /**
     * Completion commit callback: inserts based on CompletionItem's textEdit/insertText/label.
     * Prefers textEdit's specified replacement range, otherwise falls back to wordRange to delete typed prefix.
     */
    private void applyCompletionItem(@NonNull CompletionItem item) {
        CompletionItem.TextEdit textEdit = item.getTextEdit();
        boolean isSnippet = item.getInsertTextFormat() == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
        String text = item.getInsertText() != null ? item.getInsertText() : item.getLabel();

        // Determine the range to replace: textEdit takes priority, otherwise fallback to wordRange
        TextRange replaceRange = null;
        if (textEdit != null) {
            replaceRange = textEdit.range;
            text = textEdit.newText;
        } else {
            TextRange wr = getWordRangeAtCursor();
            if (wr.start.line != wr.end.line || wr.start.column != wr.end.column) {
                replaceRange = wr;
            }
        }

        // Delete the replacement range first (typed prefix), then insert new text
        if (replaceRange != null) {
            deleteText(replaceRange);
        }
        if (isSnippet) {
            insertSnippet(text);
        } else {
            insertText(text);
        }
    }

    /**
     * Dispatch corresponding editor events based on gesture result.
     *
     * @param result      Gesture processing result
     * @param screenPoint Screen coordinates of touch point
     */
    private void fireGestureEvents(EditorCore.GestureResult result, PointF screenPoint) {
        switch (result.type) {
            case LONG_PRESS:
                mEventBus.publish(new LongPressEvent(result.cursorPosition, screenPoint));
                mEventBus.publish(new CursorChangedEvent(result.cursorPosition));
                break;
            case DOUBLE_TAP:
                mEventBus.publish(new DoubleTapEvent(result.cursorPosition, result.hasSelection, result.selection, screenPoint));
                mEventBus.publish(new CursorChangedEvent(result.cursorPosition));
                if (result.hasSelection) {
                    mEventBus.publish(new SelectionChangedEvent(true, result.selection, result.cursorPosition));
                }
                break;
            case TAP:
                mEventBus.publish(new CursorChangedEvent(result.cursorPosition));
                // Dismiss completion panel on tap
                if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
                    mCompletionProviderManager.dismiss();
                }
                // Check if hit InlayHint or GutterIcon
                if (result.hitTarget != null && result.hitTarget.type != EditorCore.HitTargetType.NONE) {
                    switch (result.hitTarget.type) {
                        case INLAY_HINT_TEXT:
                        case INLAY_HINT_ICON:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    result.hitTarget.iconId,
                                    result.hitTarget.type == EditorCore.HitTargetType.INLAY_HINT_ICON,
                                    screenPoint));
                            break;
                        case INLAY_HINT_COLOR:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    result.hitTarget.colorValue,
                                    screenPoint));
                            break;
                        case GUTTER_ICON:
                            mEventBus.publish(new GutterIconClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.iconId,
                                    screenPoint));
                            break;
                        case FOLD_PLACEHOLDER:
                        case FOLD_GUTTER:
                            mEventBus.publish(new FoldToggleEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.type == EditorCore.HitTargetType.FOLD_GUTTER,
                                    screenPoint));
                            break;
                    }
                }
                break;
            case SCROLL:
            case FAST_SCROLL:
                mEventBus.publish(new ScrollChangedEvent(result.viewScrollX, result.viewScrollY));
                if (mDecorationProviderManager != null) {
                    mDecorationProviderManager.onScrollChanged();
                }
                // Dismiss completion panel on scroll
                if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
                    mCompletionProviderManager.dismiss();
                }
                break;
            case SCALE:
                mEventBus.publish(new ScaleChangedEvent(result.viewScale));
                break;
            case DRAG_SELECT:
                mEventBus.publish(new SelectionChangedEvent(result.hasSelection, result.selection, result.cursorPosition));
                break;
            case CONTEXT_MENU:
                mEventBus.publish(new ContextMenuEvent(result.cursorPosition, screenPoint));
                break;
        }
    }

    private void dispatchKeyEventResult(@NonNull EditorCore.KeyEventResult result) {
        if (result.contentChanged) {
            if (result.editResult != null && result.editResult.changed && !result.editResult.changes.isEmpty()) {
                for (EditorCore.TextChange change : result.editResult.changes) {
                    mEventBus.publish(new TextChangedEvent(TextChangeAction.KEY, change.range, change.newText));
                }
                if (mDecorationProviderManager != null) {
                    mDecorationProviderManager.onTextChanged(result.editResult.changes);
                }
            } else {
                mEventBus.publish(new TextChangedEvent(TextChangeAction.KEY, null, null));
            }
        }
        if (result.cursorChanged) {
            mEventBus.publish(new CursorChangedEvent(mEditorCore.getCursorPosition()));
        }
    }

    /**
     * Notification when composition (composing) completes, called by {@link SweetEditorInputConnection}.
     *
     * @param text Confirmed committed text
     */
    void commitComposition(@NonNull String text) {
        long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
        EditorCore.TextEditResult result = mEditorCore.compositionEnd(text);
        dispatchTextChanged(TextChangeAction.COMPOSITION, result);
        flush();
        logInputPerf(t0, "ime-commit");
    }

    void handleKeyEventFromIME(KeyEvent event) {
        long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
        // Completion panel keyboard interception (Enter/Escape/Up/Down)
        if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
            if (mCompletionPopupController.handleAndroidKeyCode(event.getKeyCode())) {
                return;
            }
        }
        // First check for Ctrl shortcut keys (SelectAll/Copy/Paste/Cut/Undo/Redo)
        if (event.isCtrlPressed()) {
            if (handleCtrlShortcut(event)) {
                resetCursorBlink();
                flush();
                logInputPerf(t0, "key-ctrl");
                return;
            }
        }
        int nativeKeyCode = mapAndroidKeyCode(event.getKeyCode());
        if (nativeKeyCode != 0) {
            // Give priority to NewLineActionProvider to handle Enter (Provider decides indentation),
            // if no Provider or returns null, fallback to Core layer default behavior
            if (nativeKeyCode == 13 && mNewLineActionProviderManager != null) {
                TextPosition cursor = mEditorCore.getCursorPosition();
                if (cursor != null) {
                    Document doc = mEditorCore.getDocument();
                    String lineText = (doc != null) ? doc.getLineText(cursor.line) : "";
                    if (lineText == null) lineText = "";
                    NewLineContext ctx = new NewLineContext(
                            cursor.line, cursor.column, lineText,
                            mLanguageConfiguration);
                    NewLineAction action = mNewLineActionProviderManager.provideNewLineAction(ctx);
                    if (action != null) {
                        EditorCore.TextEditResult editResult = mEditorCore.insertText(action.text);
                        dispatchTextChanged(TextChangeAction.KEY, editResult);
                        resetCursorBlink();
                        flush();
                        logInputPerf(t0, "key-enter");
                        return;
                    }
                }
            }
            int modifiers = 0;
            if (event.isShiftPressed()) modifiers |= 1;
            if (event.isCtrlPressed()) modifiers |= 2;
            if (event.isAltPressed()) modifiers |= 4;
            if (event.isMetaPressed()) modifiers |= 8;
            EditorCore.KeyEventResult result = mEditorCore.handleKeyEvent(nativeKeyCode, null, modifiers);
            dispatchKeyEventResult(result);
            resetCursorBlink();
            flush();
            logInputPerf(t0, "key");
        }
    }

    private void logInputPerf(long startNanos, String tag) {
        if (!ENABLE_PERF_LOG || startNanos == 0) return;
        float ms = (System.nanoTime() - startNanos) / 1_000_000f;
        if (ms >= PerfOverlay.WARN_INPUT_MS) {
            Log.w(TAG, String.format("[PERF][SLOW] %s: %.2f ms", tag, ms));
        }
        mPerfOverlay.recordInput(tag, ms);
    }

    private boolean handleCtrlShortcut(KeyEvent event) {
        switch (event.getKeyCode()) {
            case KeyEvent.KEYCODE_A:
                selectAll();
                return true;
            case KeyEvent.KEYCODE_C:
                copyToClipboard();
                return true;
            case KeyEvent.KEYCODE_V:
                pasteFromClipboard();
                return true;
            case KeyEvent.KEYCODE_X:
                cutToClipboard();
                return true;
            case KeyEvent.KEYCODE_Z:
                if (event.isShiftPressed()) {
                    redo();
                } else {
                    undo();
                }
                return true;
            case KeyEvent.KEYCODE_Y:
                redo();
                return true;
            case KeyEvent.KEYCODE_SPACE:
                // Ctrl+Space to manually trigger completion
                triggerCompletion();
                return true;
            default:
                return false;
        }
    }

    // ==================== Private Helper / Internal Implementation ====================

    private void initView(Context context) {
        // Text Paint
        mTextPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mTextPaint.setColor(mTheme.textColor);
        mTextPaint.setTextSize(36);

        // Pre-cache text Typeface (MONOSPACE as base font)
        mTextTypefaces[Typeface.NORMAL] = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL);
        mTextTypefaces[Typeface.BOLD] = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD);
        mTextTypefaces[Typeface.ITALIC] = Typeface.create(Typeface.MONOSPACE, Typeface.ITALIC);
        mTextTypefaces[Typeface.BOLD_ITALIC] = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD_ITALIC);
        mTextPaint.setTypeface(mTextTypefaces[Typeface.NORMAL]);

        // InlayHint dedicated Paint (uses same font config as TextMeasurer)
        mInlayHintPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mInlayHintTypefaces[Typeface.NORMAL] = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL);
        mInlayHintTypefaces[Typeface.BOLD] = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD);
        mInlayHintTypefaces[Typeface.ITALIC] = Typeface.create(Typeface.SANS_SERIF, Typeface.ITALIC);
        mInlayHintTypefaces[Typeface.BOLD_ITALIC] = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD_ITALIC);
        mInlayHintPaint.setTypeface(mInlayHintTypefaces[Typeface.NORMAL]);
        mInlayHintPaint.setTextSize(36 * 0.9f);
        mInlayHintPaint.setColor(mTheme.inlayHintTextColor);

        // InlayHint background Paint
        mInlayHintBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mInlayHintBgPaint.setStyle(Paint.Style.FILL);
        mInlayHintBgPaint.setColor(mTheme.inlayHintBgColor);

        // Background Paint
        mBackgroundPaint = new Paint();
        mBackgroundPaint.setColor(mTheme.backgroundColor);

        // Cursor Paint
        mCursorPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mCursorPaint.setColor(mTheme.cursorColor);
        mCursorPaint.setStrokeWidth(2f);

        // Selection Paint
        mSelectionPaint = new Paint();
        mSelectionPaint.setColor(mTheme.selectionColor);
        mSelectionPaint.setStyle(Paint.Style.FILL);

        // Line number Paint
        mLineNumberPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLineNumberPaint.setColor(mTheme.lineNumberColor);
        mLineNumberPaint.setTextSize(30);

        // Current line Paint
        mCurrentLinePaint = new Paint();
        mCurrentLinePaint.setColor(mTheme.currentLineColor);
        mCurrentLinePaint.setStyle(Paint.Style.FILL);

        // Structure line Paint (indent/bracket/flow)
        mGuidePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mGuidePaint.setStyle(Paint.Style.STROKE);
        mGuidePaint.setColor(mTheme.guideColor);
        mGuidePaint.setStrokeWidth(1f);

        // Separator line Paint (separator uses solid line)
        mSeparatorLinePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mSeparatorLinePaint.setColor(mTheme.separatorLineColor);
        mSeparatorLinePaint.setStrokeWidth(1f);

        // Composition input underline Paint
        mCompositionPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mCompositionPaint.setColor(mTheme.compositionUnderlineColor);
        mCompositionPaint.setStrokeWidth(2f);
        mCompositionPaint.setStyle(Paint.Style.STROKE);

        // Diagnostic decoration Paint (wavy/dashed line)
        mDiagnosticPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mDiagnosticPaint.setStyle(Paint.Style.STROKE);
        mDiagnosticPaint.setStrokeWidth(3.0f);
        mDiagnosticDashEffect = new DashPathEffect(new float[]{3, 2}, 0);

        // Linked editing highlight Paint (active tab stop: semi-transparent background + border; inactive: border only)
        mLinkedEditingActivePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLinkedEditingActivePaint.setColor(mTheme.linkedEditingActiveColor);
        mLinkedEditingActivePaint.setStyle(Paint.Style.STROKE);
        mLinkedEditingActivePaint.setStrokeWidth(2f);

        mLinkedEditingInactivePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mLinkedEditingInactivePaint.setColor(mTheme.linkedEditingInactiveColor);
        mLinkedEditingInactivePaint.setStyle(Paint.Style.STROKE);
        mLinkedEditingInactivePaint.setStrokeWidth(1f);

        // Bracket match highlight Paint (golden border + semi-transparent background)
        mBracketHighlightBorderPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mBracketHighlightBorderPaint.setColor(mTheme.bracketHighlightBorderColor);
        mBracketHighlightBorderPaint.setStyle(Paint.Style.STROKE);
        mBracketHighlightBorderPaint.setStrokeWidth(1.5f);

        mBracketHighlightBgPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mBracketHighlightBgPaint.setColor(mTheme.bracketHighlightBgColor);
        mBracketHighlightBgPaint.setStyle(Paint.Style.FILL);

        // Line number split line Paint
        mSplitLinePaint = new Paint();
        mSplitLinePaint.setColor(mTheme.splitLineColor);
        mSplitLinePaint.setStrokeWidth(1f);

        // Selection cursor Paint (water drop shaped drag handle)
        mHandlePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mHandlePaint.setColor(mTheme.cursorColor);
        mHandlePaint.setStyle(Paint.Style.FILL);

        // Fold arrow Paint (VSCode style chevron, two-line stroke)
        mFoldArrowPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        mFoldArrowPaint.setColor(mTheme.lineNumberColor);
        mFoldArrowPaint.setStyle(Paint.Style.STROKE);
        mFoldArrowPaint.setStrokeCap(Paint.Cap.ROUND);
        mFoldArrowPaint.setStrokeJoin(Paint.Join.ROUND);

        // Create TextMeasurer and EditorCore (pass same Paint instance to ensure measurement and drawing consistency)
        mTextMeasurer = new TextMeasurer(mTextPaint, mInlayHintPaint);

        int scaledTouchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
        EditorOptions editorOptions = new EditorOptions(scaledTouchSlop, 300);
        mEditorCore = new EditorCore(mTextMeasurer, editorOptions);
        mEditorCore.setHandleConfig(new HandleConfig());
        mDecorationProviderManager = new DecorationProviderManager(this);

        // Completion manager and panel controller
        mCompletionProviderManager = new CompletionProviderManager(this);
        mCompletionPopupController = new CompletionPopupController(context, this);
        mCompletionProviderManager.setListener(mCompletionPopupController);
        mCompletionPopupController.setConfirmListener(this::applyCompletionItem);

        // Register syntax highlight styles from default theme
        for (Map.Entry<Integer, int[]> entry : mTheme.syntaxStyles.entrySet()) {
            int[] style = entry.getValue();
            mEditorCore.registerStyle(entry.getKey(), style[0], style[1]);
        }

        setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        setFocusable(true);
        setFocusableInTouchMode(true);
        loadDocument(new Document(""));
    }

    /**
     * Flush all pending changes (decoration / layout / scroll / selection) and trigger a redraw.
     * <p>
     * Decoration setters (setLineSpans, clearHighlights, setFoldRegions, etc.) no longer
     * trigger a redraw automatically. Call this method once after a batch of decoration
     * updates to make them take effect.
     * <p>
     * Text-editing, cursor-movement and configuration APIs still call flush() internally,
     * so callers only need to invoke this explicitly for decoration operations.
     */
    public void flush() {
        mModelDirty = true;
        postInvalidate();
    }

    private void drawLines(Canvas canvas, EditorRenderModel model) {
        if (model.lines == null) return;
        for (VisualLine line : model.lines) {
            // Draw each VisualRun
            if (line.runs == null) continue;
            int lastFontStyle = -1;
            int lastColor = 0;
            for (VisualRun run : line.runs) {
                if (run.type == VisualRunType.TEXT || run.type == VisualRunType.WHITESPACE
                        || run.type == VisualRunType.INLAY_HINT || run.type == VisualRunType.PHANTOM_TEXT
                        || run.type == VisualRunType.FOLD_PLACEHOLDER) {
                    // FoldPlaceholder: semi-transparent rounded background + " … " text (uses main text Paint)
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

                    // InlayHint uses dedicated Paint (font/size consistent with measurement), style synced from run.style
                    if (run.type == VisualRunType.INLAY_HINT) {
                        float mgn = run.margin;
                        mInlayHintPaint.getFontMetrics(mInlayHintFontMetrics);
                        float bgTop = run.y + mInlayHintFontMetrics.ascent;
                        float bgBottom = run.y + mInlayHintFontMetrics.descent;
                        float bgLeft = run.x + mgn;
                        float bgRight = run.x + run.width - mgn;

                        if (run.colorValue != 0) {
                            // COLOR type: solid color block, no background, no padding, square rectangle
                            float blockSize = bgBottom - bgTop;
                            float colorLeft = run.x + mgn;
                            float colorTop = bgTop;
                            mInlayHintBgPaint.setColor(run.colorValue);
                            mInlayHintBgPaint.setAlpha(255);
                            canvas.drawRect(colorLeft, colorTop,
                                    colorLeft + blockSize, colorTop + blockSize,
                                    mInlayHintBgPaint);
                            // Restore to inlayHint background color to avoid affecting subsequent TEXT/ICON type drawing
                            mInlayHintBgPaint.setColor(mTheme.inlayHintBgColor);
                        } else {
                            // TEXT / ICON type: rounded background + content
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
                                // Text type inlay hint
                                int fontStyle = run.style != null ? run.style.fontStyle : 0;
                                // Use custom color from run.style if available (replace alpha with theme inlayHint text alpha), otherwise use theme config
                                int color;
                                if (run.style != null && run.style.color != 0) {
                                    int alpha = (mTheme.inlayHintTextColor >>> 24) & 0xFF;
                                    color = (alpha << 24) | (run.style.color & 0x00FFFFFF);
                                } else {
                                    color = mTheme.inlayHintTextColor;
                                }
                                boolean bold = (fontStyle & FontStyle.BOLD) != 0;
                                boolean italic = (fontStyle & FontStyle.ITALIC) != 0;
                                int tfStyle = Typeface.NORMAL;
                                if (bold && italic) tfStyle = Typeface.BOLD_ITALIC;
                                else if (bold) tfStyle = Typeface.BOLD;
                                else if (italic) tfStyle = Typeface.ITALIC;
                                mInlayHintPaint.setTypeface(mInlayHintTypefaces[tfStyle]);
                                mInlayHintPaint.setStrikeThruText((fontStyle & FontStyle.STRIKETHROUGH) != 0);
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

                    // Only update Paint when style or color changes
                    if (fontStyle != lastFontStyle) {
                        applyFontStyle(fontStyle);
                        lastFontStyle = fontStyle;
                    }
                    if (color != lastColor) {
                        mTextPaint.setColor(color);
                        lastColor = color;
                    }

                    // Draw background color (semantic highlighting/search match, etc.)
                    if (run.style != null && run.style.backgroundColor != 0) {
                        Paint.FontMetrics fm = mTextPaint.getFontMetrics();
                        float bgTop = run.y + fm.ascent;
                        float bgBottom = run.y + fm.descent;
                        mTextPaint.setColor(run.style.backgroundColor);
                        canvas.drawRect(run.x, bgTop, run.x + run.width, bgBottom, mTextPaint);
                        mTextPaint.setColor(color);
                    }

                    // Phantom text uses independent color
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
        if (model.lines == null) return;
        boolean overlayMode = (model.maxGutterIcons == 0);
        Path arrowPath = new Path();
        for (VisualLine line : model.lines) {
            if (line.wrapIndex == 0 && !line.isPhantomLine && line.lineNumberPosition != null) {
                boolean hasIcons = mEditorIconProvider != null
                        && line.gutterIconIds != null && !line.gutterIconIds.isEmpty();

                if (overlayMode && hasIcons) {
                    // Overlay mode: draw only 1 icon (first in list), size matching line number text, replacing line number text
                    Paint.FontMetrics fm = mLineNumberPaint.getFontMetrics();
                    float baseline = line.lineNumberPosition.y;
                    float iconTop = baseline + fm.ascent;
                    float iconSize = fm.descent - fm.ascent;
                    float iconLeft = line.lineNumberPosition.x;
                    int iconId = line.gutterIconIds.get(0);
                    Drawable drawable = mEditorIconProvider.getIconDrawable(iconId);
                    if (drawable != null) {
                        drawable.setBounds((int) iconLeft, (int) iconTop,
                                (int) (iconLeft + iconSize), (int) (iconTop + iconSize));
                        drawable.draw(canvas);
                    }
                } else {
                    // Draw line number text
                    String lineNumStr = String.valueOf(line.logicalLine + 1);
                    canvas.drawText(lineNumStr,
                            line.lineNumberPosition.x, line.lineNumberPosition.y,
                            mLineNumberPaint);

                    // Icons are placed close to the fold arrow area on the left, arranged from right to left
                    if (hasIcons) {
                        float lineHeight = model.cursor != null ? model.cursor.height : mLineNumberPaint.getTextSize();
                        float iconSize = lineHeight;
                        Paint.FontMetrics fm = mLineNumberPaint.getFontMetrics();
                        float baseline = line.lineNumberPosition.y;
                        float iconTop = baseline + fm.ascent;
                        float iconRight = model.foldArrowX > 0
                                ? model.foldArrowX - lineHeight * 0.5f
                                : model.splitX - 2f;
                        int maxIcons = Math.min(line.gutterIconIds.size(), model.maxGutterIcons);
                        for (int i = maxIcons - 1; i >= 0; i--) {
                            int iconId = line.gutterIconIds.get(i);
                            Drawable drawable = mEditorIconProvider.getIconDrawable(iconId);
                            if (drawable != null) {
                                int left = (int) (iconRight - iconSize);
                                int top = (int) iconTop;
                                int right = (int) iconRight;
                                int bottom = (int) (iconTop + iconSize);
                                drawable.setBounds(left, top, right, bottom);
                                drawable.draw(canvas);
                                iconRight -= iconSize;
                            }
                        }
                    }
                }

                // Draw fold/expand arrow (VSCode style chevron)
                if (line.foldState != null && line.foldState != FoldState.NONE) {
                    Paint.FontMetrics fm = mLineNumberPaint.getFontMetrics();
                    float baseline = line.lineNumberPosition.y;
                    float lineTop = baseline + fm.ascent;
                    float lineHeight = fm.descent - fm.ascent;
                    float halfSize = lineHeight * 0.2f;
                    float centerX = model.foldArrowX > 0 ? model.foldArrowX : model.splitX - lineHeight * 0.5f;
                    float centerY = lineTop + lineHeight * 0.5f;
                    mFoldArrowPaint.setStrokeWidth(lineHeight * 0.1f);

                    arrowPath.reset();
                    if (line.foldState == FoldState.COLLAPSED) {
                        // > Right chevron (collapsed)
                        arrowPath.moveTo(centerX - halfSize * 0.5f, centerY - halfSize);
                        arrowPath.lineTo(centerX + halfSize * 0.5f, centerY);
                        arrowPath.lineTo(centerX - halfSize * 0.5f, centerY + halfSize);
                    } else {
                        // v Down chevron (expanded)
                        arrowPath.moveTo(centerX - halfSize, centerY - halfSize * 0.5f);
                        arrowPath.lineTo(centerX, centerY + halfSize * 0.5f);
                        arrowPath.lineTo(centerX + halfSize, centerY - halfSize * 0.5f);
                    }
                    canvas.drawPath(arrowPath, mFoldArrowPaint);
                }
            }
        }
    }

    private void drawCursor(Canvas canvas, @Nullable Cursor cursor) {
        if (cursor == null || !cursor.visible || !mCursorVisible) return;
        canvas.drawRect(
                cursor.position.x,
                cursor.position.y,
                cursor.position.x + 2f,
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
        HandleConfig hc = mEditorCore.getHandleConfig();
        float lineWidth = hc.lineWidth;
        float dropRadius = hc.radius;
        float dropLength = hc.centerDist;

        // Vertical line
        canvas.drawRect(x - lineWidth / 2, y, x + lineWidth / 2, y + height, mHandlePaint);

        // Tip and circle center
        float tipX = x;
        float tipY, cx, cy;
        if (isStart) {
            tipY = y;
            cx = x - dropRadius + lineWidth / 2;
            cy = tipY - dropLength;
        } else {
            tipY = y + height;
            cx = x + dropRadius - lineWidth / 2;
            cy = tipY + dropLength;
        }

        // Bezier approximation coefficient for circle
        float k = dropRadius * 0.5522f;
        android.graphics.Path path = new android.graphics.Path();

        if (!isStart) {
            // End: tip at top (tipY), circle at bottom (cy > tipY)
            float left = cx - dropRadius;
            float right = cx + dropRadius;
            float top = cy - dropRadius;
            float bottom = cy + dropRadius;

            path.moveTo(tipX, tipY);
            // Right curve: tip → circle right (right, cy)
            path.cubicTo(tipX, tipY + dropLength * 0.4f,
                    right, cy - dropRadius * 0.8f,
                    right, cy);
            // Circle bottom-right: (right, cy) → (cx, bottom)
            path.cubicTo(right, cy + k, cx + k, bottom, cx, bottom);
            // Circle bottom-left: (cx, bottom) → (left, cy)
            path.cubicTo(cx - k, bottom, left, cy + k, left, cy);
            // Left curve: (left, cy) → tip
            path.cubicTo(left, cy - dropRadius * 0.8f,
                    tipX, tipY + dropLength * 0.4f,
                    tipX, tipY);
        } else {
            // Start: tip at bottom (tipY), circle at top (cy < tipY)
            float left = cx - dropRadius;
            float right = cx + dropRadius;
            float top = cy - dropRadius;
            float bottom = cy + dropRadius;

            path.moveTo(tipX, tipY);
            // Left curve: tip → circle left (left, cy)
            path.cubicTo(tipX, tipY - dropLength * 0.4f,
                    left, cy + dropRadius * 0.8f,
                    left, cy);
            // Circle top-left: (left, cy) → (cx, top)
            path.cubicTo(left, cy - k, cx - k, top, cx, top);
            // Circle top-right: (cx, top) → (right, cy)
            path.cubicTo(cx + k, top, right, cy - k, right, cy);
            // Right curve: (right, cy) → tip
            path.cubicTo(right, cy + dropRadius * 0.8f,
                    tipX, tipY - dropLength * 0.4f,
                    tipX, tipY);
        }

        path.close();
        canvas.drawPath(path, mHandlePaint);
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
                    float density = getResources().getDisplayMetrics().density;
                    float arrowDepth = 8f * density * (float) Math.cos(Math.toRadians(28));
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
        float density = getResources().getDisplayMetrics().density;
        float arrowLen = 8f * density;
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
        if (decoration.origin == null) {
            Log.w(TAG, "drawCompositionDecoration: active but origin is null");
            return;
        }
        float y = decoration.origin.y + decoration.height;
        Log.d(TAG, String.format("drawCompositionDecoration: origin=(%.1f, %.1f), w=%.1f, h=%.1f, drawY=%.1f",
                decoration.origin.x, decoration.origin.y, decoration.width, decoration.height, y));
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
                // HINT: dashed straight line
                mDiagnosticPaint.setPathEffect(mDiagnosticDashEffect);
                canvas.drawLine(startX, baseY, endX, baseY, mDiagnosticPaint);
                mDiagnosticPaint.setPathEffect(null);
            } else {
                // ERROR/WARNING/INFO: smooth curved wavy line
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
            // Active tab stop draws extra semi-transparent background
            if (rect.isActive) {
                int color = mTheme.linkedEditingActiveColor;
                int bgColor = (color & 0x00FFFFFF) | 0x20000000; // 12% opacity
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
        boolean bold = (fontStyle & FontStyle.BOLD) != 0;
        boolean italic = (fontStyle & FontStyle.ITALIC) != 0;

        int style = Typeface.NORMAL;
        if (bold && italic) style = Typeface.BOLD_ITALIC;
        else if (bold) style = Typeface.BOLD;
        else if (italic) style = Typeface.ITALIC;

        mTextPaint.setTypeface(mTextTypefaces[style]);
        mTextPaint.setStrikeThruText((fontStyle & FontStyle.STRIKETHROUGH) != 0);
    }

    private void resetFontStyle() {
        mTextPaint.setTypeface(mTextTypefaces[Typeface.NORMAL]);
        mTextPaint.setStrikeThruText(false);
        mTextPaint.setAlpha(255);
        mTextPaint.setColor(mTheme.textColor);
    }

    private void resetCursorBlink() {
        mCursorVisible = true;
        mHandler.removeCallbacks(mCursorBlink);
        mHandler.postDelayed(mCursorBlink, 500);
    }

    private void showSoftKeyboard() {
        InputMethodManager imm = (InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
        if (imm != null) {
            imm.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT);
        }
    }

    private static int mapAndroidKeyCode(int androidKeyCode) {
        switch (androidKeyCode) {
            case KeyEvent.KEYCODE_DEL:
                return 8;           // BACKSPACE
            case KeyEvent.KEYCODE_TAB:
                return 9;
            case KeyEvent.KEYCODE_ENTER:
                return 13;
            case KeyEvent.KEYCODE_ESCAPE:
                return 27;
            case KeyEvent.KEYCODE_FORWARD_DEL:
                return 46;  // DELETE
            case KeyEvent.KEYCODE_DPAD_LEFT:
                return 37;
            case KeyEvent.KEYCODE_DPAD_UP:
                return 38;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                return 39;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                return 40;
            case KeyEvent.KEYCODE_MOVE_HOME:
                return 36;
            case KeyEvent.KEYCODE_MOVE_END:
                return 35;
            case KeyEvent.KEYCODE_PAGE_UP:
                return 33;
            case KeyEvent.KEYCODE_PAGE_DOWN:
                return 34;
            default:
                return 0;
        }
    }
}
