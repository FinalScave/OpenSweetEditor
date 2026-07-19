package com.qiplat.sweeteditor;

import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.PointF;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.AttributeSet;
import android.util.Log;
import android.util.SparseArray;
import android.view.Choreographer;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.WindowInsets;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;

import androidx.annotation.NonNull;
import androidx.annotation.MainThread;
import androidx.annotation.Nullable;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.config.EditorRangeEffectStyles;
import com.qiplat.sweeteditor.core.config.EditorOptions;
import com.qiplat.sweeteditor.core.config.EditorRenderColors;
import com.qiplat.sweeteditor.core.config.RangeEffectStyle;
import com.qiplat.sweeteditor.core.config.RangeEffectUnderlineStyle;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.interaction.HitTargetType;
import com.qiplat.sweeteditor.core.interaction.GestureType;
import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.config.ScrollbarConfig;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.DocumentHighlight;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;

import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.CodeLensItem;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.adornment.LinkSpan;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.adornment.TextStyle;

import com.qiplat.sweeteditor.core.TextMeasurer;
import com.qiplat.sweeteditor.core.action.ScrollBehavior;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.config.ScrollbarMode;
import com.qiplat.sweeteditor.core.config.ScrollbarTrackTapMode;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextEdit;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.search.SearchRequest;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.perf.MeasurePerfStats;
import com.qiplat.sweeteditor.perf.PerfOverlay;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.completion.CompletionItem;
import com.qiplat.sweeteditor.completion.CompletionItemViewFactory;
import com.qiplat.sweeteditor.completion.CompletionPopupController;
import com.qiplat.sweeteditor.completion.CompletionProvider;
import com.qiplat.sweeteditor.completion.CompletionProviderManager;
import com.qiplat.sweeteditor.completion.CompletionContext;
import com.qiplat.sweeteditor.copilot.InlineSuggestion;
import com.qiplat.sweeteditor.copilot.InlineSuggestionController;
import com.qiplat.sweeteditor.copilot.InlineSuggestionListener;
import com.qiplat.sweeteditor.contextmenu.ContextMenuController;
import com.qiplat.sweeteditor.contextmenu.ContextMenuItemProvider;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationProviderManager;
import com.qiplat.sweeteditor.newline.NewLineAction;
import com.qiplat.sweeteditor.newline.NewLineActionProvider;
import com.qiplat.sweeteditor.newline.NewLineActionProviderManager;
import com.qiplat.sweeteditor.event.ContextMenuEvent;
import com.qiplat.sweeteditor.event.CursorChangedEvent;
import com.qiplat.sweeteditor.event.DocumentLoadedEvent;
import com.qiplat.sweeteditor.event.DoubleTapEvent;
import com.qiplat.sweeteditor.event.EditorEvent;
import com.qiplat.sweeteditor.event.EditorEventBus;
import com.qiplat.sweeteditor.event.EditorEventListener;
import com.qiplat.sweeteditor.event.CodeLensClickEvent;
import com.qiplat.sweeteditor.event.FoldToggleEvent;
import com.qiplat.sweeteditor.event.GutterIconClickEvent;
import com.qiplat.sweeteditor.event.InlayHintClickEvent;
import com.qiplat.sweeteditor.event.LinkClickEvent;
import com.qiplat.sweeteditor.event.LongPressEvent;
import com.qiplat.sweeteditor.selection.SelectionMenuController;
import com.qiplat.sweeteditor.ui.AnimationHolder;
import com.qiplat.sweeteditor.selection.SelectionMenuItemProvider;
import com.qiplat.sweeteditor.event.ScaleChangedEvent;
import com.qiplat.sweeteditor.event.ScrollChangedEvent;
import com.qiplat.sweeteditor.event.SelectionChangedEvent;
import com.qiplat.sweeteditor.event.TextChangedEvent;
import com.qiplat.sweeteditor.ui.UiDimensions;

import java.util.List;

/**
 * SweetEditor editor view, providing code editing, syntax highlighting, code folding, InlayHint and other features.
 * <p>
 * Based on C++ core ({@link EditorCore}) for text layout and editing logic,
 * this class handles Android platform rendering, gestures, input method integration and public APIs.
 * Unless otherwise noted, public APIs on this class are main-thread only.
 */
@MainThread
public class SweetEditor extends View {
    private static final String TAG = SweetEditor.class.getSimpleName();
    private static final boolean ENABLE_PERF_LOG = true;
    private static final int PERF_LOG_INTERVAL = 60;
    private static final int MAX_CLIPBOARD_SELECTION_CHARS = 100_000;

    private EditorRenderer mRenderer;
    private AnimationHolder animationHolder;
    private int mPerfLogFrameCount = 0;

    @Nullable
    private EditorRenderModel mCachedModel;
    private boolean mModelDirty = true;
    private final Rect mVisibleWindowFrame = new Rect();
    private final int[] mTmpWindowLocation = new int[2];
    private int mBottomOcclusionInset = 0;
    private int mAppliedViewportWidth = -1;
    private int mAppliedViewportHeight = -1;
    @Nullable
    private SweetEditorInputConnection mInputConnection;

    // ==================== Construction/Init/Lifecycle ====================

    private EditorCore mEditorCore;
    private EditorSettings mSettings;
    private EditorKeyMap mKeyMap;
    private TextMeasurer mTextMeasurer;
    private Document mDocument;
    private final EditorEventBus mEventBus = new EditorEventBus();
    private DecorationProviderManager mDecorationProviderManager;
    private CompletionProviderManager mCompletionProviderManager;
    private CompletionPopupController mCompletionPopupController;
    private InlineSuggestionController mInlineSuggestionController;
    private NewLineActionProviderManager mNewLineActionProviderManager;
    private SelectionMenuController mSelectionMenuController;
    private ContextMenuController mContextMenuController;
    @Nullable
    private LanguageConfiguration mLanguageConfiguration;
    @Nullable
    private EditorMetadata mMetadata;
    /**
     * Current theme (default dark).
     */
    private EditorTheme mTheme = EditorTheme.dark();

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
    // Unified visual-transition callback: cursor smooth move + gutter width transition.
    // Aligned to vsync via Choreographer, single invalidate per frame.
    private boolean mVisualTransitionActive = false;
    private final Choreographer.FrameCallback mVisualTransitionCallback = new Choreographer.FrameCallback() {
        @Override
        public void doFrame(long frameTimeNanos) {
            if (!mVisualTransitionActive) return;

            // Model not yet rebuilt — keep running so we can animate toward the new target
            // once onDraw rebuilds mCachedModel.
            if (mModelDirty) {
                postInvalidate();
                Choreographer.getInstance().postFrameCallback(this);
                return;
            }

            boolean needsNextFrame = false;

            if (mSettings.isCursorAnimationEnabled()
                    && mCachedModel != null && mCachedModel.cursor != null && mCachedModel.cursor.position != null) {
                float targetX = mCachedModel.cursor.position.x;
                float targetY = mCachedModel.cursor.position.y;

                if (animationHolder.cursorAnimatedX < 0 || animationHolder.cursorAnimatedY < 0) {
                    animationHolder.cursorAnimatedX = targetX;
                    animationHolder.cursorAnimatedY = targetY;
                }

                animationHolder.cursorAnimatedX += (targetX - animationHolder.cursorAnimatedX) * 0.35f;
                animationHolder.cursorAnimatedY += (targetY - animationHolder.cursorAnimatedY) * 0.35f;

                if (Math.abs(targetX - animationHolder.cursorAnimatedX) < 0.01f) {
                    animationHolder.cursorAnimatedX = targetX;
                } else {
                    needsNextFrame = true;
                }

                if (Math.abs(targetY - animationHolder.cursorAnimatedY) < 0.01f) {
                    animationHolder.cursorAnimatedY = targetY;
                } else {
                    needsNextFrame = true;
                }
            }

            postInvalidate();
            if (needsNextFrame) {
                Choreographer.getInstance().postFrameCallback(this);
            } else {
                mVisualTransitionActive = false;
            }
        }
    };

    // Unified core animation callback.
    private boolean mCoreAnimationActive = false;
    private final Choreographer.FrameCallback mCoreAnimationCallback = new Choreographer.FrameCallback() {
        @Override
        public void doFrame(long frameTimeNanos) {
            if (!mCoreAnimationActive) return;
            EditorActionResult result = mEditorCore.tickAnimations();
            dispatchEditorActionResult(result);
        }
    };
    private final Runnable mDelayedCoreAnimationCallback = new Runnable() {
        @Override
        public void run() {
            if (!mCoreAnimationActive) return;
            Choreographer.getInstance().postFrameCallback(mCoreAnimationCallback);
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
        updateViewport(width, height, false);
    }

    @Override
    public WindowInsets onApplyWindowInsets(WindowInsets insets) {
        WindowInsets appliedInsets = super.onApplyWindowInsets(insets);
        refreshViewportForVisibleBounds(true);
        return appliedInsets;
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
        EditorActionResult result = mEditorCore.handleGestureEvent(event);
        Log.d(TAG, "result: " + result);
        dispatchEditorActionResult(result);
        if (ENABLE_PERF_LOG) {
            float ms = (System.nanoTime() - t0) / 1_000_000f;
            if (ms >= PerfOverlay.WARN_INPUT_MS) {
                Log.w(TAG, String.format("[PERF][SLOW] onTouchEvent: %.2f ms", ms));
            }
            mRenderer.getPerfOverlay().recordInput("touch", ms);
        }
        return true;
    }

    @Override
    public boolean onGenericMotionEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_BUTTON_PRESS
                && (event.getButtonState() & MotionEvent.BUTTON_SECONDARY) != 0) {
            long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
            PointF locationInView = new PointF(event.getX(), event.getY());
            EditorActionResult result = mEditorCore.handleGestureEvent(
                    EditorCore.EVENT_TYPE_MOUSE_RIGHT_DOWN,
                    new PointF[]{locationInView},
                    getMotionEventModifiers(event),
                    0,
                    0,
                    1
            );
            dispatchEditorActionResult(result);
            if (ENABLE_PERF_LOG) {
                float ms = (System.nanoTime() - t0) / 1_000_000f;
                if (ms >= PerfOverlay.WARN_INPUT_MS) {
                    Log.w(TAG, String.format("[PERF][SLOW] onGenericMotionEvent: %.2f ms", ms));
                }
                mRenderer.getPerfOverlay().recordInput("mouse", ms);
            }
            return true;
        }
        return super.onGenericMotionEvent(event);
    }

    @Override
    public boolean onHoverEvent(MotionEvent event) {
        int action = event.getActionMasked();
        if (action != MotionEvent.ACTION_HOVER_ENTER
                && action != MotionEvent.ACTION_HOVER_MOVE
                && action != MotionEvent.ACTION_HOVER_EXIT) {
            return super.onHoverEvent(event);
        }

        PointF point = action == MotionEvent.ACTION_HOVER_EXIT ? null : new PointF(event.getX(), event.getY());
        updateHoverGesture(point, getMotionEventModifiers(event));
        return true;
    }

    @Override
    public InputConnection onCreateInputConnection(EditorInfo outAttrs) {
        if (mInputConnection != null) {
            mInputConnection.closeConnection();
        }
        SweetEditorInputConnection inputConnection = new SweetEditorInputConnection(this, true);
        inputConnection.configureEditorInfo(outAttrs);
        mInputConnection = inputConnection;
        return inputConnection;
    }

    @Override
    public boolean onCheckIsTextEditor() {
        return true;
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        boolean handled = handleKeyEventFromIME(event);
        refreshPointerModifiers(event);
        return handled || super.onKeyDown(keyCode, event);
    }

    @Override
    public boolean onKeyUp(int keyCode, KeyEvent event) {
        if (isPointerModifierKey(keyCode)) {
            refreshPointerModifiers(event);
            return true;
        }
        return super.onKeyUp(keyCode, event);
    }

    @Override
    protected void onDraw(@NonNull Canvas canvas) {
        float buildMs = 0f;

        if (mModelDirty) {
            long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
            MeasurePerfStats measStats = mRenderer.getMeasurePerfStats();
            measStats.reset();
            if (ENABLE_PERF_LOG) mTextMeasurer.setPerfStats(measStats);
            mCachedModel = mEditorCore.buildRenderModel();
            if (ENABLE_PERF_LOG) mTextMeasurer.setPerfStats(null);
            mModelDirty = false;
            if (ENABLE_PERF_LOG) buildMs = (System.nanoTime() - t0) / 1_000_000f;
        }
        EditorRenderModel model = mCachedModel;

        if (model == null) {
            canvas.drawColor(mTheme.backgroundColor);
            return;
        }

        mRenderer.render(canvas, model, getWidth(), getHeight(),
                mCursorVisible, animationHolder, buildMs);

        if (mCompletionPopupController != null && model.cursor != null && model.cursor.position != null) {
            mCompletionPopupController.updateCursorPosition(
                    model.cursor.position.x, model.cursor.position.y, model.cursor.height);
        }

        if (mInlineSuggestionController != null && mInlineSuggestionController.isShowing()
                && model.cursor != null && model.cursor.position != null) {
            mInlineSuggestionController.updatePosition(
                    model.cursor.position.x, model.cursor.position.y, model.cursor.height);
        }

        if (mSelectionMenuController != null
                && model.selectionStartHandle != null
                && model.selectionEndHandle != null) {
            mSelectionMenuController.updateSelectionHandles(model.selectionStartHandle, model.selectionEndHandle);
        }

        if (ENABLE_PERF_LOG) {
            MeasurePerfStats measStats = mRenderer.getMeasurePerfStats();
            mPerfLogFrameCount++;
            if (mPerfLogFrameCount >= PERF_LOG_INTERVAL) {
                mPerfLogFrameCount = 0;
                if (buildMs >= PerfOverlay.WARN_BUILD_MS || measStats.shouldLog()) {
                    Log.w(TAG, "[PERF][Build] build=" + String.format("%.2fms", buildMs)
                            + " | " + measStats.buildSummary());
                }
            }
        }
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        mHandler.postDelayed(mCursorBlink, 500);
        startVisualTransition();
        requestApplyInsets();
        post(() -> refreshViewportForVisibleBounds(false));
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        mHandler.removeCallbacks(mCursorBlink);
        stopVisualTransition();
        mHandler.removeCallbacks(mDelayedCoreAnimationCallback);
        Choreographer.getInstance().removeFrameCallback(mCoreAnimationCallback);
        mCoreAnimationActive = false;
        if (mSelectionMenuController != null) {
            mSelectionMenuController.dismiss();
        }
        if (mContextMenuController != null) {
            mContextMenuController.onHostDetached();
        }
        if (mInputConnection != null) {
            mInputConnection.closeConnection();
            mInputConnection = null;
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasWindowFocus) {
        super.onWindowFocusChanged(hasWindowFocus);
        if (hasWindowFocus) {
            resetCursorBlink();
            startVisualTransition();
        } else {
            mHandler.removeCallbacks(mCursorBlink);
            stopVisualTransition();
            mHandler.removeCallbacks(mDelayedCoreAnimationCallback);
            Choreographer.getInstance().removeFrameCallback(mCoreAnimationCallback);
            mCoreAnimationActive = false;
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
        EditorActionResult result = mEditorCore.loadDocument(document);
        mCachedModel = null;
        animationHolder.cursorAnimatedX = -1f;
        animationHolder.cursorAnimatedY = -1f;
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.onDocumentLoaded();
        }
        mEventBus.publish(new DocumentLoadedEvent());
        restartInputConnection();
        dispatchEditorActionResult(result);
    }

    @Nullable
    public Document getDocument() {
        return mDocument;
    }

    // ==================== Settings ====================

    @NonNull
    public EditorSettings getSettings() {
        return mSettings;
    }

    @NonNull
    public EditorKeyMap getKeyMap() {
        return mKeyMap;
    }

    /**
     * Replace the current key map and sync all bindings to the C++ core.
     */
    public void setKeyMap(@NonNull EditorKeyMap keyMap) {
        mKeyMap = keyMap;
        EditorActionResult result = mEditorCore.setKeyMap(keyMap.getBindings());
        dispatchEditorActionResult(result);
    }

    void syncPlatformScale(float scale) {
        mRenderer.syncPlatformScale(scale);
        EditorActionResult result = mEditorCore.onFontMetricsChanged();
        dispatchEditorActionResult(result);
    }

    void applyTypeface(Typeface typeface) {
        mRenderer.applyTypeface(typeface);
        EditorActionResult result = mEditorCore.onFontMetricsChanged();
        dispatchEditorActionResult(result);
    }

    void applyTextSize(float textSize) {
        mRenderer.applyTextSize(textSize);
        EditorActionResult result = mEditorCore.onFontMetricsChanged();
        dispatchEditorActionResult(result);
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
        mRenderer.applyTheme(theme);

        dispatchEditorActionResult(mEditorCore.setEditorRenderColors(buildEditorRenderColors(theme)));
        dispatchEditorActionResult(mEditorCore.setEditorRangeEffectStyles(buildEditorRangeEffectStyles(theme)));
        EditorActionResult result = mEditorCore.registerBatchTextStyles(theme.textStyles);

        if (mInlineSuggestionController != null) {
            mInlineSuggestionController.applyTheme(theme);
        }

        if (mCompletionPopupController != null) {
            mCompletionPopupController.applyTheme(theme);
        }

        if (mSelectionMenuController != null) {
            mSelectionMenuController.applyTheme(theme);
        }

        if (mContextMenuController != null) {
            mContextMenuController.applyTheme(theme);
        }

        dispatchEditorActionResult(result);
    }

    private EditorRenderColors buildEditorRenderColors(@NonNull EditorTheme theme) {
        int codeLensForeground = theme.codeLensColor != 0 ? theme.codeLensColor : theme.inlayHintTextColor;
        int activeCodeLensForeground = theme.codeLensActiveColor != 0
                ? theme.codeLensActiveColor
                : (theme.currentLineNumberColor != 0 ? theme.currentLineNumberColor : theme.lineNumberColor);
        int linkForeground = theme.linkColor != 0 ? theme.linkColor : codeLensForeground;
        int activeLinkForeground = theme.linkActiveColor != 0
                ? theme.linkActiveColor
                : (theme.linkColor != 0 ? theme.linkColor : activeCodeLensForeground);
        return new EditorRenderColors(
                theme.textColor,
                linkForeground,
                activeLinkForeground,
                codeLensForeground,
                activeCodeLensForeground);
    }

    private EditorRangeEffectStyles buildEditorRangeEffectStyles(@NonNull EditorTheme theme) {
        EditorRangeEffectStyles styles = new EditorRangeEffectStyles();
        styles.selection = new RangeEffectStyle(
                theme.selectionTextColor,
                theme.selectionColor,
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.imeComposition = new RangeEffectStyle(
                0,
                0,
                0,
                theme.compositionUnderlineColor,
                RangeEffectUnderlineStyle.SOLID);
        styles.diagnosticError = diagnosticStyle(theme.diagnosticErrorColor, RangeEffectUnderlineStyle.WAVY);
        styles.diagnosticWarning = diagnosticStyle(theme.diagnosticWarningColor, RangeEffectUnderlineStyle.WAVY);
        styles.diagnosticInfo = diagnosticStyle(theme.diagnosticInfoColor, RangeEffectUnderlineStyle.WAVY);
        styles.diagnosticHint = diagnosticStyle(theme.diagnosticHintColor, RangeEffectUnderlineStyle.DASHED);
        styles.linkedEditingActive = new RangeEffectStyle(
                0,
                withAlpha(theme.linkedEditingActiveColor, 0x20),
                theme.linkedEditingActiveColor,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.linkedEditingInactive = new RangeEffectStyle(
                0,
                0,
                theme.linkedEditingInactiveColor,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.bracketMatch = new RangeEffectStyle(
                0,
                theme.bracketHighlightBgColor,
                theme.bracketHighlightBorderColor,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.searchMatch = new RangeEffectStyle(
                0,
                theme.searchMatchBgColor,
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.searchCurrent = new RangeEffectStyle(
                0,
                theme.searchCurrentBgColor,
                theme.searchCurrentBorderColor,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.documentHighlightText = new RangeEffectStyle(
                0,
                theme.documentHighlightTextBgColor,
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.documentHighlightRead = new RangeEffectStyle(
                0,
                theme.documentHighlightReadBgColor,
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.documentHighlightWrite = new RangeEffectStyle(
                0,
                theme.documentHighlightWriteBgColor,
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        return styles;
    }

    private RangeEffectStyle diagnosticStyle(int color, RangeEffectUnderlineStyle underlineStyle) {
        return new RangeEffectStyle(0, 0, 0, color, underlineStyle);
    }

    private int withAlpha(int color, int alpha) {
        return color == 0 ? 0 : (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
    }

    @NonNull
    EditorCore getEditorCore() {
        return mEditorCore;
    }

    public IntRange getVisibleLineRange() {
        // Keep the core visible-line range current before decoration providers query it.
        if (mCachedModel == null || mModelDirty) {
            mCachedModel = mEditorCore.buildRenderModel();
            mModelDirty = false;
        }
        return mEditorCore.getVisibleLineRange();
    }

    public int getTotalLineCount() {
        return mDocument == null ? -1 : mDocument.getLineCount();
    }

    // ==================== Text Editing ====================

    /**
     * Insert text at current cursor position (replaces selection if exists). Triggers {@link TextChangedEvent} automatically.
     *
     * @param text text to insert (supports multiple lines, use {@code \n} for newlines)
     */
    public void insertText(@NonNull String text) {
        EditorActionResult result = mEditorCore.insertText(text);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Insert text at the specified document position.
     *
     * @param position insertion position
     * @param text     text to insert
     */
    public void insertTextAt(@NonNull TextPosition position, @NonNull String text) {
        replaceText(new TextRange(position, position), text);
    }

    /**
     * Replace specified text range (atomic operation). Triggers {@link TextChangedEvent} automatically.
     *
     * @param range   text range to replace (when start == end, equivalent to insert)
     * @param newText new text after replacement (empty string is equivalent to delete)
     */
    public void replaceText(@NonNull TextRange range, @NonNull String newText) {
        EditorActionResult result = mEditorCore.replaceText(range, newText);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Delete specified text range (atomic operation). Triggers {@link TextChangedEvent} automatically.
     *
     * @param range text range to delete
     */
    public void deleteText(@NonNull TextRange range) {
        EditorActionResult result = mEditorCore.deleteText(range);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Apply multiple text edits as one undoable operation.
     *
     * @param edits text edits using the original document coordinates. The first edit is the primary edit.
     */
    public void applyTextEdits(@NonNull List<? extends TextEdit> edits) {
        EditorActionResult result = mEditorCore.applyTextEdits(edits);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    // ==================== Line Operations ====================

    /**
     * Move current line (or lines covered by selection) up by one.
     */
    public void moveLineUp() {
        EditorActionResult result = mEditorCore.moveLineUp();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Move current line (or lines covered by selection) down by one.
     */
    public void moveLineDown() {
        EditorActionResult result = mEditorCore.moveLineDown();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Duplicate current line (or lines covered by selection) above.
     */
    public void copyLineUp() {
        EditorActionResult result = mEditorCore.copyLineUp();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Duplicate current line (or lines covered by selection) below.
     */
    public void copyLineDown() {
        EditorActionResult result = mEditorCore.copyLineDown();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Delete current line (or all lines covered by selection).
     */
    public void deleteLine() {
        EditorActionResult result = mEditorCore.deleteLine();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Insert empty line above current line.
     */
    public void insertLineAbove() {
        EditorActionResult result = mEditorCore.insertLineAbove();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Insert empty line below current line.
     */
    public void insertLineBelow() {
        EditorActionResult result = mEditorCore.insertLineBelow();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    // ==================== Undo/Redo ====================

    /**
     * Undo last edit operation. Triggers {@link TextChangedEvent} automatically.
     *
     */
    public void undo() {
        EditorActionResult result = mEditorCore.undo();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Redo last undone operation. Triggers {@link TextChangedEvent} automatically.
     *
     */
    public void redo() {
        EditorActionResult result = mEditorCore.redo();
        resetCursorBlink();
        dispatchEditorActionResult(result);
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

    /**
     * Search the current document and highlight all visible matches.
     *
     * @param request search pattern and options
     */
    public void search(@NonNull SearchRequest request) {
        EditorActionResult result = mEditorCore.search(request);
        dispatchEditorActionResult(result);
    }

    /**
     * Move the current search match to the next result.
     */
    public void findNextSearchMatch() {
        EditorActionResult result = mEditorCore.findNextSearchMatch();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Move the current search match to the previous result.
     */
    public void findPreviousSearchMatch() {
        EditorActionResult result = mEditorCore.findPreviousSearchMatch();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Replace the current search match.
     *
     * @param replacement replacement text
     */
    public void replaceCurrentSearchMatch(@NonNull String replacement) {
        EditorActionResult result = mEditorCore.replaceCurrentSearchMatch(replacement);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Replace every current search match.
     *
     * @param replacement replacement text
     */
    public void replaceAllSearchMatches(@NonNull String replacement) {
        EditorActionResult result = mEditorCore.replaceAllSearchMatches(replacement);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear the active document search and its current selection.
     */
    public void clearSearch() {
        EditorActionResult result = mEditorCore.clearSearch();
        dispatchEditorActionResult(result);
    }

    /**
     * Get the current search state.
     *
     * @return search state snapshot
     */
    @NonNull
    public SearchState getSearchState() {
        return mEditorCore.getSearchState();
    }

    // ==================== Cursor/Selection Management ====================

    /**
     * Select all document content.
     */
    public void selectAll() {
        EditorActionResult result = mEditorCore.selectAll();
        dispatchEditorActionResult(result);
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
        EditorActionResult result = mEditorCore.setSelection(startLine, startColumn, endLine, endColumn);
        dispatchEditorActionResult(result);
    }

    /**
     * @see #setSelection(int, int, int, int)
     */
    public void setSelection(@NonNull TextRange range) {
        EditorActionResult result = mEditorCore.setSelection(range);
        dispatchEditorActionResult(result);
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
     * Check whether the editor currently has an active selection.
     *
     * @return true if text is selected
     */
    public boolean hasSelection() {
        return mEditorCore.getSelection() != null;
    }

    /**
     * Set a custom provider for selection menu items.
     * <p>
     * The provider is called each time the menu is about to show,
     * allowing dynamic items based on editor state.
     * Pass {@code null} to restore the default menu (Cut/Copy/Paste/Select All).
     *
     * @param provider custom menu item provider, or null for default
     */
    public void setSelectionMenuItemProvider(@Nullable SelectionMenuItemProvider provider) {
        if (mSelectionMenuController != null) {
            mSelectionMenuController.setItemProvider(provider);
        }
    }

    /**
     * Set a custom provider for context menu sections.
     * <p>
     * The provider is called each time the context menu is about to show.
     * Pass {@code null} to restore the default menu sections.
     *
     * @param provider custom provider, or null for the default menu
     */
    public void setContextMenuItemProvider(@Nullable ContextMenuItemProvider provider) {
        if (mContextMenuController != null) {
            mContextMenuController.setItemProvider(provider);
        }
    }

    /**
     * Dismiss the context menu if it is currently visible.
     */
    public void dismissContextMenu() {
        if (mContextMenuController != null) {
            mContextMenuController.dismiss();
        }
    }

    /**
     * Check whether the context menu is currently visible.
     */
    public boolean isContextMenuShowing() {
        return mContextMenuController != null && mContextMenuController.isShowing();
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
     * To scroll viewport simultaneously, use {@link #gotoPosition(int, int)}.
     *
     * @param position target position
     */
    public void setCursorPosition(@NonNull TextPosition position) {
        EditorActionResult result = mEditorCore.setCursorPosition(position);
        dispatchEditorActionResult(result);
    }

    // ==================== Clipboard Operations ====================

    /**
     * Copy current selection text to system clipboard.
     *
     * @return true if text was copied, false otherwise
     */
    public boolean copyToClipboard() {
        if (isSelectionTooLargeForClipboard()) {
            Log.w(TAG, "Skip copy: selection exceeds clipboard safety threshold");
            return false;
        }
        String selected = getSelectedText();
        if (selected != null && !selected.isEmpty()) {
            ClipboardManager clipboard = (ClipboardManager) getContext()
                    .getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(ClipData.newPlainText("SweetEditor", selected));
                return true;
            }
        }
        return false;
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
     *
     * @return true if text was cut, false otherwise
     */
    public boolean cutToClipboard() {
        if (isSelectionTooLargeForClipboard()) {
            Log.w(TAG, "Skip cut: selection exceeds clipboard safety threshold");
            return false;
        }
        String selected = getSelectedText();
        if (selected != null && !selected.isEmpty()) {
            ClipboardManager clipboard = (ClipboardManager) getContext()
                    .getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(ClipData.newPlainText("SweetEditor", selected));
                insertText("");
                return true;
            }
        }
        return false;
    }

    private boolean isSelectionTooLargeForClipboard() {
        if (mDocument == null) {
            return false;
        }
        TextRange selection = getSelection();
        if (selection == null) {
            return false;
        }
        int start = mDocument.getCharIndexFromPosition(selection.start);
        int end = mDocument.getCharIndexFromPosition(selection.end);
        if (end < start) {
            int tmp = start;
            start = end;
            end = tmp;
        }
        return end - start > MAX_CLIPBOARD_SELECTION_CHARS;
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
        EditorActionResult result = mEditorCore.gotoPosition(line, column);
        dispatchEditorActionResult(result);
    }

    /**
     * Scroll viewport to make specified line visible (does not move cursor).
     *
     * @param line     target line number (0-based)
     * @param behavior scroll behavior
     */
    public void scrollToLine(int line, @NonNull ScrollBehavior behavior) {
        EditorActionResult result = mEditorCore.scrollToLine(line, behavior.value);
        dispatchEditorActionResult(result);
    }

    /**
     * Manually set scroll position (automatically clamped to valid range).
     */
    public void setScroll(float scrollX, float scrollY) {
        EditorActionResult result = mEditorCore.setScroll(scrollX, scrollY);
        dispatchEditorActionResult(result);
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
     * @param fontStyle       font style bit flags ({@link TextStyle#NORMAL}, {@link TextStyle#BOLD},
     *                        {@link TextStyle#ITALIC}, {@link TextStyle#STRIKETHROUGH}, combinable via bitwise OR)
     */
    public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle) {
        EditorActionResult result = mEditorCore.registerTextStyle(styleId, color, backgroundColor, fontStyle);
        dispatchEditorActionResult(result);
    }

    /**
     * Register a reusable highlight style (no background, backward compatible).
     *
     * @param styleId   Style ID (custom, must be unique)
     * @param color     ARGB foreground color
     * @param fontStyle Font style bit flags
     */
    public void registerTextStyle(int styleId, int color, int fontStyle) {
        EditorActionResult result = mEditorCore.registerTextStyle(styleId, color, fontStyle);
        dispatchEditorActionResult(result);
    }

    /**
     * Register multiple reusable highlight styles in one batch.
     *
     * @param stylesById style ID -> style mapping; null or empty input is ignored
     */
    public void registerBatchTextStyles(@Nullable Map<Integer, TextStyle> stylesById) {
        EditorActionResult result = mEditorCore.registerBatchTextStyles(stylesById);
        dispatchEditorActionResult(result);
    }

    /**
     * Set highlight spans for a specified line and layer using a list of {@link StyleSpan}.
     *
     * @param line  Line number (0-based)
     * @param layer Layer index
     * @param spans Span list (accepts {@link StyleSpan} and its subclasses)
     */
    public void setLineSpans(int line, @NonNull SpanLayer layer, @NonNull List<? extends StyleSpan> spans) {
        EditorActionResult result = mEditorCore.setLineSpans(line, layer.value, spans);
        dispatchEditorActionResult(result);
    }


    /**
     * Batch set highlight spans for multiple lines (reduces JNI calls, single dirty mark).
     *
     * @param layer       Highlight layer
     * @param spansByLine Sparse array of line number 鈫?span list
     */
    public void setBatchLineSpans(SpanLayer layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine) {
        EditorActionResult result = mEditorCore.setBatchLineSpans(layer.value, spansByLine);
        dispatchEditorActionResult(result);
    }

    // -------------------- InlayHint / PhantomText --------------------

    /**
     * Batch set Inlay Hints for a specified line (replaces entire line, efficient binary protocol).
     *
     * @param line  Line number (0-based)
     * @param hints InlayHint list
     */
    public void setLineInlayHints(int line, @NonNull List<? extends InlayHint> hints) {
        EditorActionResult result = mEditorCore.setLineInlayHints(line, hints);
        dispatchEditorActionResult(result);
    }

    /**
     * Batch set Inlay Hints for multiple lines (reduces JNI calls, single dirty mark).
     *
     * @param hintsByLine Sparse array of line number 鈫?hint list
     */
    public void setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine) {
        EditorActionResult result = mEditorCore.setBatchLineInlayHints(hintsByLine);
        dispatchEditorActionResult(result);
    }

    /**
     * Set phantom text for a specified line (replaces entire line), rendered in semi-transparent style.
     * <p>Does not affect actual document content.
     *
     * @param line     Line number (0-based)
     * @param phantoms Phantom text list (sorted by column ascending)
     */
    public void setLinePhantomTexts(int line, @NonNull List<? extends PhantomText> phantoms) {
        EditorActionResult result = mEditorCore.setLinePhantomTexts(line, phantoms);
        dispatchEditorActionResult(result);
    }

    /**
     * Batch set phantom text for multiple lines (reduces JNI calls, single dirty mark).
     *
     * @param phantomsByLine Sparse array of line number 鈫?phantom list
     */
    public void setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        EditorActionResult result = mEditorCore.setBatchLinePhantomTexts(phantomsByLine);
        dispatchEditorActionResult(result);
    }

    // -------------------- Gutter Icons --------------------


    /**
     * Set gutter icons for a specified line (replaces entire line).
     * <p>Icon Drawables are provided by {@link EditorIconProvider}.
     *
     * @param line  Line number (0-based)
     * @param icons Icon list
     */
    public void setLineGutterIcons(int line, @NonNull List<? extends GutterIcon> icons) {
        EditorActionResult result = mEditorCore.setLineGutterIcons(line, icons);
        dispatchEditorActionResult(result);
    }

    /**
     * Batch set gutter icons for multiple lines (reduces JNI calls).
     *
     * @param iconsByLine Sparse array of line number 鈫?icon list
     */
    public void setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine) {
        EditorActionResult result = mEditorCore.setBatchLineGutterIcons(iconsByLine);
        dispatchEditorActionResult(result);
    }

    // -------------------- CodeLens --------------------

    /**
     * Set CodeLens items for a specified line (replaces entire line).
     *
     * @param line  Line number (0-based)
     * @param items CodeLens item list
     */
    public void setLineCodeLens(int line, @NonNull List<? extends CodeLensItem> items) {
        EditorActionResult result = mEditorCore.setLineCodeLens(line, items);
        dispatchEditorActionResult(result);
    }

    /**
     * Batch set CodeLens items for multiple lines (reduces JNI calls).
     *
     * @param itemsByLine Sparse array of line number → CodeLens item list
     */
    public void setBatchLineCodeLens(@Nullable SparseArray<? extends List<? extends CodeLensItem>> itemsByLine) {
        EditorActionResult result = mEditorCore.setBatchLineCodeLens(itemsByLine);
        dispatchEditorActionResult(result);
    }

    // -------------------- Links --------------------

    /**
     * Set link ranges for a specified line.
     *
     * @param line  Line number (0-based)
     * @param links Link range list
     */
    public void setLineLinks(int line, @NonNull List<? extends LinkSpan> links) {
        EditorActionResult result = mEditorCore.setLineLinks(line, links);
        dispatchEditorActionResult(result);
    }

    /**
     * Batch set link ranges for multiple lines (reduces JNI calls).
     *
     * @param linksByLine Sparse array of line number to link list
     */
    public void setBatchLineLinks(@Nullable SparseArray<? extends List<? extends LinkSpan>> linksByLine) {
        EditorActionResult result = mEditorCore.setBatchLineLinks(linksByLine);
        dispatchEditorActionResult(result);
    }

    /**
     * Resolve link target by line and column inside that link.
     */
    @NonNull
    public String getLinkTargetAt(int line, int column) {
        return mEditorCore.getLinkTargetAt(line, column);
    }

    // -------------------- Diagnostic Decorations --------------------

    /**
     * Set diagnostic decorations for a specified line.
     *
     * @param line  Line number (0-based)
     * @param items Diagnostic item list
     */
    public void setLineDiagnostics(int line, @NonNull List<? extends Diagnostic> items) {
        EditorActionResult result = mEditorCore.setLineDiagnostics(line, items);
        dispatchEditorActionResult(result);
    }

    /**
     * Batch set diagnostic decorations for multiple lines (reduces JNI calls).
     *
     * @param diagsByLine Sparse array of line number 鈫?diagnostic list
     */
    public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> diagsByLine) {
        EditorActionResult result = mEditorCore.setBatchLineDiagnostics(diagsByLine);
        dispatchEditorActionResult(result);
    }

    public void setLineDocumentHighlights(int line, @NonNull List<? extends DocumentHighlight> items) {
        EditorActionResult result = mEditorCore.setLineDocumentHighlights(line, items);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineDocumentHighlights(@Nullable SparseArray<? extends List<? extends DocumentHighlight>> highlightsByLine) {
        EditorActionResult result = mEditorCore.setBatchLineDocumentHighlights(highlightsByLine);
        dispatchEditorActionResult(result);
    }

    // -------------------- Guides (Code Structure Lines) --------------------

    /**
     * Set indent guide list (global replacement).
     *
     * @param guides Indent guide list
     */
    public void setIndentGuides(@NonNull List<IndentGuide> guides) {
        EditorActionResult result = mEditorCore.setIndentGuides(guides);
        dispatchEditorActionResult(result);
    }

    /**
     * Set bracket matching branch line list (global replacement).
     *
     * @param guides Bracket matching branch line list
     */
    public void setBracketGuides(@NonNull List<BracketGuide> guides) {
        EditorActionResult result = mEditorCore.setBracketGuides(guides);
        dispatchEditorActionResult(result);
    }

    /**
     * Set control flow return arrow list (global replacement).
     *
     * @param guides Control flow return arrow list
     */
    public void setFlowGuides(@NonNull List<FlowGuide> guides) {
        EditorActionResult result = mEditorCore.setFlowGuides(guides);
        dispatchEditorActionResult(result);
    }

    /**
     * Set horizontal separator line list (global replacement).
     *
     * @param guides Horizontal separator line list
     */
    public void setSeparatorGuides(@NonNull List<SeparatorGuide> guides) {
        EditorActionResult result = mEditorCore.setSeparatorGuides(guides);
        dispatchEditorActionResult(result);
    }

    // -------------------- Fold (Code Folding) --------------------

    /**
     * Set foldable regions using a list of {@link FoldRegion} (replaces existing list).
     *
     * @param regions Fold region list
     */
    public void setFoldRegions(@Nullable List<? extends FoldRegion> regions) {
        EditorActionResult result = mEditorCore.setFoldRegions(regions);
        dispatchEditorActionResult(result);
    }


    /**
     * Toggle fold/expand state of the region containing the specified line.
     *
     * @param line Line number (0-based, usually the first line of fold)
     */
    public void toggleFoldAt(int line) {
        EditorActionResult result = mEditorCore.toggleFoldAt(line);
        dispatchEditorActionResult(result);
    }

    /**
     * Fold the region containing the specified line.
     *
     * @param line Line number (0-based)
     */
    public void foldAt(int line) {
        EditorActionResult result = mEditorCore.foldAt(line);
        dispatchEditorActionResult(result);
    }

    /**
     * Unfold the region containing the specified line.
     *
     * @param line Line number (0-based)
     */
    public void unfoldAt(int line) {
        EditorActionResult result = mEditorCore.unfoldAt(line);
        dispatchEditorActionResult(result);
    }

    /**
     * Fold all regions.
     */
    public void foldAll() {
        EditorActionResult result = mEditorCore.foldAll();
        dispatchEditorActionResult(result);
    }

    /**
     * Unfold all regions.
     */
    public void unfoldAll() {
        EditorActionResult result = mEditorCore.unfoldAll();
        dispatchEditorActionResult(result);
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
     */
    public void insertSnippet(@NonNull String snippetTemplate) {
        EditorActionResult result = mEditorCore.insertSnippet(snippetTemplate);
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Start linked editing mode with a generic LinkedEditingModel.
     *
     * @param model Linked editing model
     */
    public void startLinkedEditing(@NonNull LinkedEditingModel model) {
        EditorActionResult result = mEditorCore.startLinkedEditing(model);
        resetCursorBlink();
        dispatchEditorActionResult(result);
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
     */
    public void linkedEditingNext() {
        EditorActionResult result = mEditorCore.linkedEditingNext();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Linked editing: jump to previous tab stop.
     *
     */
    public void linkedEditingPrev() {
        EditorActionResult result = mEditorCore.linkedEditingPrev();
        resetCursorBlink();
        dispatchEditorActionResult(result);
    }

    /**
     * Cancel linked editing mode.
     */
    public void cancelLinkedEditing() {
        EditorActionResult result = mEditorCore.cancelLinkedEditing();
        dispatchEditorActionResult(result);
    }

    // -------------------- Clear Decorations --------------------

    /**
     * Clear all highlight spans.
     */
    public void clearHighlights() {
        EditorActionResult result = mEditorCore.clearHighlights();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear highlight spans for specified layer.
     *
     * @param layer Layer index
     */
    public void clearHighlights(@NonNull SpanLayer layer) {
        EditorActionResult result = mEditorCore.clearHighlights(layer.value);
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all Inlay Hints.
     */
    public void clearInlayHints() {
        EditorActionResult result = mEditorCore.clearInlayHints();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all Phantom Texts.
     */
    public void clearPhantomTexts() {
        EditorActionResult result = mEditorCore.clearPhantomTexts();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all gutter icons.
     */
    public void clearGutterIcons() {
        EditorActionResult result = mEditorCore.clearGutterIcons();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all CodeLens items.
     */
    public void clearCodeLens() {
        EditorActionResult result = mEditorCore.clearCodeLens();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all link ranges.
     */
    public void clearLinks() {
        EditorActionResult result = mEditorCore.clearLinks();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all code structure guides (indent vertical lines, bracket matching lines, flow arrows, separator lines).
     */
    public void clearGuides() {
        EditorActionResult result = mEditorCore.clearGuides();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all diagnostic decorations.
     */
    public void clearDiagnostics() {
        EditorActionResult result = mEditorCore.clearDiagnostics();
        dispatchEditorActionResult(result);
    }

    public void clearDocumentHighlights() {
        EditorActionResult result = mEditorCore.clearDocumentHighlights();
        dispatchEditorActionResult(result);
    }

    /**
     * Clear all decoration data (highlights, Inlay Hints, Phantom Texts, icons, Guide lines, diagnostics).
     */
    public void clearAllDecorations() {
        EditorActionResult result = mEditorCore.clearAllDecorations();
        dispatchEditorActionResult(result);
    }

    /**
     * Flush all pending changes and trigger a redraw.
     */
    public void flush() {
        mModelDirty = true;
        startVisualTransition();
        postInvalidate();
    }

    // ==================== View Layer Extension Configuration ====================

    /**
     * Set language configuration (automatically syncs brackets to Core layer).
     */
    public void setLanguageConfiguration(@Nullable LanguageConfiguration config) {
        mLanguageConfiguration = config;
        syncLanguageConfigurationToCore(config);
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.requestRefresh();
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

    private void syncLanguageConfigurationToCore(@Nullable LanguageConfiguration config) {
        if (config == null) return;

        List<LanguageConfiguration.BracketPair> brackets = config.getBrackets();
        if (brackets != null) {
            int size = brackets.size();
            int[] opens = new int[size];
            int[] closes = new int[size];
            for (int i = 0; i < size; i++) {
                LanguageConfiguration.BracketPair pair = brackets.get(i);
                opens[i] = pair.open.isEmpty() ? 0 : pair.open.codePointAt(0);
                closes[i] = pair.close.isEmpty() ? 0 : pair.close.codePointAt(0);
            }
            dispatchEditorActionResult(mEditorCore.setBracketPairs(opens, closes));
        }

        List<LanguageConfiguration.BracketPair> acPairs = config.getAutoClosingPairs();
        if (acPairs != null) {
            int acSize = acPairs.size();
            int[] acOpens = new int[acSize];
            int[] acCloses = new int[acSize];
            for (int i = 0; i < acSize; i++) {
                LanguageConfiguration.BracketPair pair = acPairs.get(i);
                acOpens[i] = pair.open.isEmpty() ? 0 : pair.open.codePointAt(0);
                acCloses[i] = pair.close.isEmpty() ? 0 : pair.close.codePointAt(0);
            }
            dispatchEditorActionResult(mEditorCore.setAutoClosingPairs(acOpens, acCloses));
        }

        if (config.getTabSize() > 0) {
            dispatchEditorActionResult(mEditorCore.setTabSize(config.getTabSize()));
        }

        dispatchEditorActionResult(mEditorCore.setInsertSpaces(config.getInsertSpaces()));
    }

    /**
     * Set editor icon provider.
     *
     * @param provider Icon provider, pass null to remove
     */
    public void setEditorIconProvider(@Nullable EditorIconProvider provider) {
        mRenderer.setEditorIconProvider(provider);
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

    // ==================== Inline Suggestion (Copilot) API ====================

    /**
     * Show an inline suggestion: inject phantom text and display accept/dismiss action bar.
     *
     * @param suggestion the inline suggestion to display
     */
    public void showInlineSuggestion(@NonNull InlineSuggestion suggestion) {
        if (mInlineSuggestionController != null) {
            mInlineSuggestionController.show(suggestion);
        }
    }

    /**
     * Dismiss current inline suggestion (clear phantom text and hide action bar).
     */
    public void dismissInlineSuggestion() {
        if (mInlineSuggestionController != null) {
            mInlineSuggestionController.dismiss();
        }
    }

    /**
     * Check if an inline suggestion action bar is currently showing.
     */
    public boolean isInlineSuggestionShowing() {
        return mInlineSuggestionController != null && mInlineSuggestionController.isShowing();
    }

    /**
     * Set listener for inline suggestion accept/dismiss callbacks.
     */
    public void setInlineSuggestionListener(@Nullable InlineSuggestionListener listener) {
        if (mInlineSuggestionController != null) {
            mInlineSuggestionController.setListener(listener);
        }
    }

    public void addNewLineActionProvider(@NonNull NewLineActionProvider provider) {
        if (mNewLineActionProviderManager == null) {
            mNewLineActionProviderManager = new NewLineActionProviderManager(this);
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
     * editor.subscribe(TextChangedEvent.class, e -> Log.d(TAG, "changes=" + e.changes.size()));
     * editor.subscribe(CursorChangedEvent.class, e -> updateStatusBar(e.cursorPosition));
     * editor.subscribe(LongPressEvent.class, e -> showPopup(e.locationInEditor));
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
        mRenderer.setPerfOverlayEnabled(enabled);
        postInvalidate();
    }

    /**
     * Check if performance overlay is enabled.
     *
     * @return {@code true} if performance overlay is currently enabled
     */
    public boolean isPerfOverlayEnabled() {
        return mRenderer.isPerfOverlayEnabled();
    }

    void restartInputConnection() {
        if (mInputConnection != null) {
            mInputConnection.closeConnection();
            mInputConnection = null;
        }
        InputMethodManager imm = getInputMethodManager();
        if (imm != null && isFocused()) {
            imm.restartInput(this);
        }
    }

    @SuppressWarnings("deprecation")
    private void notifyImeViewClicked() {
        InputMethodManager imm = getInputMethodManager();
        if (imm != null) {
            imm.viewClicked(this);
        }
    }

    // ==================== Event Dispatch (Internal) ====================

    private void dispatchTextChanged(@NonNull EditorActionResult editResult) {
        if (editResult.contentChanged && !editResult.changes.isEmpty()) {
            mEventBus.publish(new TextChangedEvent(editResult.changes, editResult.textChangeKind, editResult.source));
            if (mDecorationProviderManager != null) {
                mDecorationProviderManager.onTextChanged(editResult.changes);
            }
            if (mContextMenuController != null) {
                mContextMenuController.onTextChanged();
            }
            // Suppress completion trigger during linked editing to avoid conflict with Enter/Tab keys
            if (!mEditorCore.isInLinkedEditing()) {
                // Completion trigger: based on first change (primary change)
                TextChange primaryChange = editResult.changes.get(0);
                if (mCompletionProviderManager != null && primaryChange.newText.length() == 1) {
                    String ch = primaryChange.newText;
                    if (mCompletionProviderManager.isTriggerCharacter(ch)) {
                        mCompletionProviderManager.triggerCompletion(
                                CompletionContext.TriggerKind.CHARACTER, ch);
                    } else if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
                        mCompletionProviderManager.triggerCompletion(
                                CompletionContext.TriggerKind.RETRIGGER, null);
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
     * Completion commit callback: textEdit is the only source of replacement range semantics.
     */
    private void applyCompletionItem(@NonNull CompletionItem item) {
        boolean isSnippet = item.insertTextFormat == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
        String text = item.insertText != null ? item.insertText : item.label;

        if (item.textEdit != null) {
            text = item.textEdit.newText;
            List<TextEdit> edits = new ArrayList<>(item.additionalTextEdits.size() + 1);
            edits.add(isSnippet ? new TextEdit(item.textEdit.range, "") : item.textEdit);
            edits.addAll(item.additionalTextEdits);
            applyTextEdits(edits);
            if (isSnippet) {
                insertSnippet(text);
            }
        } else if (item.additionalTextEdits.isEmpty()) {
            if (isSnippet) {
                insertSnippet(text);
            } else {
                insertText(text);
            }
        } else {
            TextPosition cursor = getCursorPosition();
            TextEdit primaryEdit = new TextEdit(new TextRange(cursor, cursor), isSnippet ? "" : text);
            List<TextEdit> edits = new ArrayList<>(item.additionalTextEdits.size() + 1);
            edits.add(primaryEdit);
            edits.addAll(item.additionalTextEdits);
            applyTextEdits(edits);
            if (isSnippet) {
                insertSnippet(text);
            }
        }
    }

    /**
     * Dispatch corresponding editor events based on gesture result.
     *
     * @param result           Gesture processing result
     * @param locationInEditor Pointer location relative to the editor
     */
    private void fireGestureEvents(EditorActionResult result, PointF locationInEditor) {
        switch (result.gestureType) {
            case LONG_PRESS:
                mEventBus.publish(new LongPressEvent(result.cursorAfter, locationInEditor));
                break;
            case DOUBLE_TAP:
                mEventBus.publish(new DoubleTapEvent(result.cursorAfter, result.hasSelectionAfter, result.selectionAfter, locationInEditor));
                break;
            case TAP:
                // Dismiss completion panel on tap
                if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
                    mCompletionProviderManager.dismiss();
                }
                // Check if hit InlayHint or GutterIcon
                if (result.hitTarget != null && result.hitTarget.type != HitTargetType.NONE) {
                    switch (result.hitTarget.type) {
                        case INLAY_HINT_TEXT:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    InlayType.TEXT,
                                    0,
                                    locationInEditor));
                            break;
                        case INLAY_HINT_ICON:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    InlayType.ICON,
                                    result.hitTarget.iconId,
                                    locationInEditor));
                            break;
                        case INLAY_HINT_COLOR:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    InlayType.COLOR,
                                    result.hitTarget.colorValue,
                                    locationInEditor));
                            break;
                        case GUTTER_ICON:
                            mEventBus.publish(new GutterIconClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.iconId,
                                    locationInEditor));
                            break;
                        case FOLD_PLACEHOLDER:
                        case FOLD_GUTTER:
                            mEventBus.publish(new FoldToggleEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.type == HitTargetType.FOLD_GUTTER,
                                    locationInEditor));
                            break;
                        case CODELENS:
                            mEventBus.publish(new CodeLensClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    result.hitTarget.iconId,
                                    locationInEditor));
                            break;
                        case LINK:
                            mEventBus.publish(new LinkClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    getLinkTargetAt(result.hitTarget.line, result.hitTarget.column),
                                    locationInEditor));
                            break;
                    }
                }
                break;
            case SCROLL:
            case FAST_SCROLL:
                break;
            case SCALE:
                break;
            case DRAG_SELECT:
                break;
            case CONTEXT_MENU:
                mEventBus.publish(new ContextMenuEvent(result.cursorAfter, locationInEditor));
                break;
        }

        if (mContextMenuController != null) {
            mContextMenuController.onEditorActionResult(result, locationInEditor);
        }
    }

    private void dispatchStateEvents(@NonNull EditorActionResult result) {
        if (result.contentChanged) {
            dispatchTextChanged(result);
        }
        if (result.cursorChanged) {
            mEventBus.publish(new CursorChangedEvent(result.cursorAfter));
        }
        if (result.selectionChanged) {
            mEventBus.publish(new SelectionChangedEvent(result.hasSelectionAfter, result.selectionAfter, result.cursorAfter));
        }
        if (result.scrollChanged) {
            handleScrollChanged(result);
        }
        if (result.scaleChanged) {
            syncPlatformScale(result.scaleAfter);
            mEventBus.publish(new ScaleChangedEvent(result.scaleAfter));
        }
    }

    private void handleScrollChanged(@NonNull EditorActionResult result) {
        mEventBus.publish(new ScrollChangedEvent(result.scrollXAfter, result.scrollYAfter));
        if (mDecorationProviderManager != null) {
            mDecorationProviderManager.onScrollChanged();
        }
        if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
            mCompletionProviderManager.dismiss();
        }
        if (mSettings.isCursorAnimationEnabled()) {
            animationHolder.cursorAnimatedX = -1f;
            animationHolder.cursorAnimatedY = -1f;
        }
    }

    void dispatchEditorActionResult(@Nullable EditorActionResult result) {
        if (result == null) {
            return;
        }
        if (result.gestureType != GestureType.UNDEFINED) {
            if (result.gestureType == GestureType.TAP) {
                requestFocus();
                if (result.hitTarget == null || result.hitTarget.type == HitTargetType.NONE) {
                    showSoftKeyboard();
                }
                resetCursorBlink();
            }
            PointF tapPoint = new PointF(result.tapPoint.x, result.tapPoint.y);
            fireGestureEvents(result, tapPoint);
        }
        if (mSelectionMenuController != null) {
            if (mContextMenuController != null && mContextMenuController.isShowing()) {
                mSelectionMenuController.dismiss();
            } else {
                mSelectionMenuController.onEditorActionResult(result);
            }
        }
        updateAnimationSchedule(result);
        dispatchStateEvents(result);
        if (mInputConnection != null) {
            mInputConnection.onEditorActionResult(result);
        }
        if (result.needsRedraw) {
            flush();
        }
        if (result.gestureType == GestureType.TAP) {
            notifyImeViewClicked();
        }
    }

    boolean handleKeyEventFromIME(KeyEvent event) {
        long t0 = ENABLE_PERF_LOG ? System.nanoTime() : 0;
        // Inline suggestion keyboard interception (Tab/Escape)
        if (mInlineSuggestionController != null && mInlineSuggestionController.isShowing()) {
            if (mInlineSuggestionController.handleAndroidKeyCode(event.getKeyCode())) {
                return true;
            }
        }
        // Completion panel keyboard interception (Enter/Escape/Up/Down)
        if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
            if (mCompletionPopupController.handleAndroidKeyCode(event.getKeyCode())) {
                return true;
            }
        }
        int nativeKeyCode = mapAndroidKeyCode(event.getKeyCode());
        if (nativeKeyCode == KeyCode.NONE && (event.isCtrlPressed() || event.isMetaPressed() || event.isAltPressed())) {
            int unicode = event.getUnicodeChar(0);
            if (unicode >= 'a' && unicode <= 'z') {
                nativeKeyCode = unicode - 32;
            }
        }
        if (nativeKeyCode != KeyCode.NONE) {
            int modifiers = getKeyEventModifiers(event);
            // Give priority to NewLineActionProvider to handle Enter (Provider decides indentation),
            // if no Provider or returns null, fallback to Core layer default behavior
            if (nativeKeyCode == KeyCode.ENTER && mNewLineActionProviderManager != null) {
                NewLineAction action = mNewLineActionProviderManager.provideNewLineAction();
                if (action != null) {
                    EditorActionResult editResult = mEditorCore.handleKeyEvent(KeyCode.NONE, action.text, modifiers);
                    resetCursorBlink();
                    dispatchEditorActionResult(editResult);
                    logInputPerf(t0, "key-enter");
                    return true;
                }
            }
            EditorActionResult result = mEditorCore.handleKeyEvent(nativeKeyCode, null, modifiers);
            if (result.handled && dispatchKeyMapCommand(result.command, nativeKeyCode, modifiers)) {
                resetCursorBlink();
                dispatchEditorActionResult(result);
                logInputPerf(t0, "key-cmd");
                return true;
            }
            resetCursorBlink();
            dispatchEditorActionResult(result);
            logInputPerf(t0, "key");
            return true;
        }
        if (!event.isCtrlPressed() && !event.isAltPressed() && !event.isMetaPressed()) {
            int unicode = event.getUnicodeChar();
            if (unicode > 0 && !Character.isISOControl(unicode)) {
                EditorActionResult result = mEditorCore.handleKeyEvent(KeyCode.NONE,
                        new String(Character.toChars(unicode)),
                        KeyModifier.NONE);
                resetCursorBlink();
                dispatchEditorActionResult(result);
                logInputPerf(t0, "key-text");
                return true;
            }
        }
        return false;
    }

    void logInputPerf(long startNanos, String tag) {
        if (!ENABLE_PERF_LOG || startNanos == 0) return;
        float ms = (System.nanoTime() - startNanos) / 1_000_000f;
        if (ms >= PerfOverlay.WARN_INPUT_MS) {
            Log.w(TAG, String.format("[PERF][SLOW] %s: %.2f ms", tag, ms));
        }
        mRenderer.getPerfOverlay().recordInput(tag, ms);
    }

    private boolean dispatchKeyMapCommand(int command, int keyCode, int modifiers) {
        if (mKeyMap == null) return false;
        EditorKeyMap.ShortcutHandler handler = mKeyMap.getCommand(command);
        if (handler == null) return false;
        KeyBinding binding = new KeyBinding(modifiers, keyCode, command);
        handler.onShortcut(binding, this);
        return true;
    }

    private EditorKeyMap createDefaultKeyMap() {
        return EditorKeyMap.defaultKeyMap();
    }

    private void updateHoverGesture(@Nullable PointF point, int modifiers) {
        PointF probePoint = point != null ? point : new PointF(-1f, -1f);
        EditorActionResult result = mEditorCore.handleGestureEvent(
                EditorCore.EVENT_TYPE_MOUSE_MOVE,
                new PointF[]{probePoint},
                modifiers,
                0,
                0,
                1
        );
        dispatchEditorActionResult(result);
    }

    private void updateAnimationSchedule(@NonNull EditorActionResult result) {
        mHandler.removeCallbacks(mDelayedCoreAnimationCallback);
        Choreographer.getInstance().removeFrameCallback(mCoreAnimationCallback);
        if (!result.needsAnimation()) {
            mCoreAnimationActive = false;
            return;
        }
        mCoreAnimationActive = true;
        int delayMs = Math.max(0, result.nextAnimationDelayMs);
        if (delayMs == 0) {
            Choreographer.getInstance().postFrameCallback(mCoreAnimationCallback);
        } else {
            mHandler.postDelayed(mDelayedCoreAnimationCallback, delayMs);
        }
    }

    private void refreshPointerModifiers(@NonNull KeyEvent event) {
        if (!isPointerModifierKey(event.getKeyCode())) {
            return;
        }
        EditorActionResult result = mEditorCore.updatePointerModifiers(getKeyEventModifiers(event));
        dispatchEditorActionResult(result);
    }

    private static boolean isPointerModifierKey(int keyCode) {
        return keyCode == KeyEvent.KEYCODE_CTRL_LEFT
                || keyCode == KeyEvent.KEYCODE_CTRL_RIGHT
                || keyCode == KeyEvent.KEYCODE_META_LEFT
                || keyCode == KeyEvent.KEYCODE_META_RIGHT
                || keyCode == KeyEvent.KEYCODE_SHIFT_LEFT
                || keyCode == KeyEvent.KEYCODE_SHIFT_RIGHT
                || keyCode == KeyEvent.KEYCODE_ALT_LEFT
                || keyCode == KeyEvent.KEYCODE_ALT_RIGHT;
    }

    private static int getMotionEventModifiers(@NonNull MotionEvent event) {
        int metaState = event.getMetaState();
        int modifiers = KeyModifier.NONE;
        if ((metaState & KeyEvent.META_SHIFT_ON) != 0) modifiers |= KeyModifier.SHIFT;
        if ((metaState & KeyEvent.META_CTRL_ON) != 0) modifiers |= KeyModifier.CTRL;
        if ((metaState & KeyEvent.META_ALT_ON) != 0) modifiers |= KeyModifier.ALT;
        if ((metaState & KeyEvent.META_META_ON) != 0) modifiers |= KeyModifier.META;
        return modifiers;
    }

    private static int getKeyEventModifiers(@NonNull KeyEvent event) {
        int modifiers = KeyModifier.NONE;
        if (event.isShiftPressed()) modifiers |= KeyModifier.SHIFT;
        if (event.isCtrlPressed()) modifiers |= KeyModifier.CTRL;
        if (event.isAltPressed()) modifiers |= KeyModifier.ALT;
        if (event.isMetaPressed()) modifiers |= KeyModifier.META;
        return modifiers;
    }

    // ==================== Private Helper / Internal Implementation ====================

    private void initView(Context context) {
        float density = UiDimensions.density(context);
        mRenderer = new EditorRenderer(mTheme, density);
        animationHolder = new AnimationHolder();

        mRenderer.setHandleConfig(EditorRenderer.computeHandleHitConfig(density));

        float scrollbarThicknessPx = UiDimensions.dpToPxFloat(context, 5.0f);
        float scrollbarMinThumbPx = UiDimensions.dpToPxFloat(context, 40.0f);
        float scrollbarThumbHitPaddingPx = UiDimensions.dpToPxFloat(context, 20.0f);
        mRenderer.setScrollbarConfig(new ScrollbarConfig(
                scrollbarThicknessPx,
                scrollbarMinThumbPx,
                scrollbarThumbHitPaddingPx,
                ScrollbarMode.TRANSIENT,
                true,
                ScrollbarTrackTapMode.DISABLED,
                700,
                300));

        mTextMeasurer = mRenderer.getTextMeasurer();

        int scaledTouchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
        EditorOptions editorOptions = new EditorOptions(scaledTouchSlop, 300L, 500L, 2.0f, 30.0f, 12000.0f, 512L, 2000L, true);
        mEditorCore = new EditorCore(mTextMeasurer, editorOptions);
        mEditorCore.setHandleConfig(mRenderer.getHandleConfig());
        mEditorCore.setScrollbarConfig(mRenderer.getScrollbarConfig());

        mDecorationProviderManager = new DecorationProviderManager(this);

        mCompletionProviderManager = new CompletionProviderManager(this);
        mCompletionPopupController = new CompletionPopupController(context, this, mTheme);
        mCompletionProviderManager.setListener(mCompletionPopupController);
        mCompletionPopupController.setConfirmListener(this::applyCompletionItem);

        mInlineSuggestionController = new InlineSuggestionController(context, this);

        mSelectionMenuController = new SelectionMenuController(this, mEventBus, mTheme);
        mContextMenuController = new ContextMenuController(this, mEventBus, mTheme);

        mEditorCore.setEditorRenderColors(buildEditorRenderColors(mTheme));
        mEditorCore.setEditorRangeEffectStyles(buildEditorRangeEffectStyles(mTheme));
        mEditorCore.registerBatchTextStyles(mTheme.textStyles);

        mSettings = new EditorSettings(this);
        mSettings.setContentStartPadding(UiDimensions.dpToPxFloat(context, 3.0f));
        mKeyMap = createDefaultKeyMap();
        mEditorCore.setGutterSticky(mSettings.isGutterSticky());
        setFocusable(true);
        setFocusableInTouchMode(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            setImportantForAutofill(IMPORTANT_FOR_AUTOFILL_NO);
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            setImportantForContentCapture(IMPORTANT_FOR_CONTENT_CAPTURE_NO);
        }
    }

    private void updateViewport(int width, int height, boolean ensureCursorVisible) {
        if (width < 0 || height < 0) {
            return;
        }
        int effectiveHeight = Math.max(0, height - mBottomOcclusionInset);
        if (width == mAppliedViewportWidth && effectiveHeight == mAppliedViewportHeight) {
            return;
        }
        boolean viewportNarrowed = mAppliedViewportWidth >= 0 && width < mAppliedViewportWidth;
        boolean viewportShrunk = mAppliedViewportHeight >= 0 && effectiveHeight < mAppliedViewportHeight;
        mAppliedViewportWidth = width;
        mAppliedViewportHeight = effectiveHeight;
        EditorActionResult viewportResult = mEditorCore.setViewport(width, effectiveHeight);
        dispatchEditorActionResult(viewportResult);
        if ((ensureCursorVisible || viewportNarrowed || viewportShrunk) && hasWindowFocus()) {
            EditorActionResult cursorResult = mEditorCore.ensureCursorVisible();
            dispatchEditorActionResult(cursorResult);
        }
    }

    private void refreshViewportForVisibleBounds(boolean ensureCursorVisible) {
        int occlusionInset = computeBottomOcclusionInset();
        if (occlusionInset != mBottomOcclusionInset) {
            mBottomOcclusionInset = occlusionInset;
        }
        updateViewport(getWidth(), getHeight(), ensureCursorVisible);
    }

    private int computeBottomOcclusionInset() {
        if (getWindowToken() == null || getHeight() <= 0) {
            return 0;
        }
        getWindowVisibleDisplayFrame(mVisibleWindowFrame);
        getLocationOnScreen(mTmpWindowLocation);
        int viewBottom = mTmpWindowLocation[1] + getHeight();
        return Math.max(0, viewBottom - mVisibleWindowFrame.bottom);
    }

    private void resetCursorBlink() {
        mCursorVisible = true;
        mHandler.removeCallbacks(mCursorBlink);
        mHandler.postDelayed(mCursorBlink, 500);
    }

    public void requestCursorAnimationRefresh() {
        if (mSettings.isCursorAnimationEnabled()) {
            startVisualTransition();
        } else {
            animationHolder.cursorAnimatedX = -1;
            animationHolder.cursorAnimatedY = -1;
            postInvalidate();
        }
    }

    private void startVisualTransition() {
        if (!mVisualTransitionActive && mSettings.isCursorAnimationEnabled()) {
            mVisualTransitionActive = true;
            Choreographer.getInstance().postFrameCallback(mVisualTransitionCallback);
        }
    }

    private void stopVisualTransition() {
        mVisualTransitionActive = false;
        Choreographer.getInstance().removeFrameCallback(mVisualTransitionCallback);
    }

    private void showSoftKeyboard() {
        InputMethodManager imm = getInputMethodManager();
        if (imm != null) {
            imm.showSoftInput(this, InputMethodManager.SHOW_IMPLICIT);
        }
        requestApplyInsets();
    }

    @Nullable
    private InputMethodManager getInputMethodManager() {
        return (InputMethodManager) getContext().getSystemService(Context.INPUT_METHOD_SERVICE);
    }

    private static int mapAndroidKeyCode(int androidKeyCode) {
        switch (androidKeyCode) {
            case KeyEvent.KEYCODE_DEL:
                return KeyCode.BACKSPACE;
            case KeyEvent.KEYCODE_TAB:
                return KeyCode.TAB;
            case KeyEvent.KEYCODE_ENTER:
                return KeyCode.ENTER;
            case KeyEvent.KEYCODE_ESCAPE:
                return KeyCode.ESCAPE;
            case KeyEvent.KEYCODE_FORWARD_DEL:
                return KeyCode.DELETE_KEY;
            case KeyEvent.KEYCODE_DPAD_LEFT:
                return KeyCode.LEFT;
            case KeyEvent.KEYCODE_DPAD_UP:
                return KeyCode.UP;
            case KeyEvent.KEYCODE_DPAD_RIGHT:
                return KeyCode.RIGHT;
            case KeyEvent.KEYCODE_DPAD_DOWN:
                return KeyCode.DOWN;
            case KeyEvent.KEYCODE_MOVE_HOME:
                return KeyCode.HOME;
            case KeyEvent.KEYCODE_MOVE_END:
                return KeyCode.END;
            case KeyEvent.KEYCODE_PAGE_UP:
                return KeyCode.PAGE_UP;
            case KeyEvent.KEYCODE_PAGE_DOWN:
                return KeyCode.PAGE_DOWN;
            case KeyEvent.KEYCODE_SPACE:
                return KeyCode.SPACE;
            default:
                return KeyCode.NONE;
        }
    }
}
