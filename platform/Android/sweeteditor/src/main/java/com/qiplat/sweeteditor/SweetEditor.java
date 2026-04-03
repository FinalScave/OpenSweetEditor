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

import java.util.Map;

import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorOptions;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.ScrollbarConfig;
import com.qiplat.sweeteditor.core.keymap.EditorCommand;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;

import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.adornment.TextStyle;

import com.qiplat.sweeteditor.core.TextMeasurer;
import com.qiplat.sweeteditor.core.foundation.ScrollBehavior;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
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
import com.qiplat.sweeteditor.event.FoldToggleEvent;
import com.qiplat.sweeteditor.event.GutterIconClickEvent;
import com.qiplat.sweeteditor.event.InlayHintClickEvent;
import com.qiplat.sweeteditor.event.LongPressEvent;
import com.qiplat.sweeteditor.selection.SelectionMenuController;
import com.qiplat.sweeteditor.selection.SelectionMenuItemProvider;
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
 * Unless otherwise noted, public APIs on this class are main-thread only.
 */
@MainThread
public class SweetEditor extends View {
    private static final String TAG = SweetEditor.class.getSimpleName();
    private static final boolean ENABLE_PERF_LOG = true;
    private static final int PERF_LOG_INTERVAL = 60;
    private static final float DEFAULT_CONTENT_START_PADDING_DP = 3.0f;

    private EditorRenderer mRenderer;
    private int mPerfLogFrameCount = 0;

    @Nullable
    private EditorRenderModel mCachedModel;
    private boolean mModelDirty = true;
    private final Rect mVisibleWindowFrame = new Rect();
    private final int[] mTmpWindowLocation = new int[2];
    private int mBottomOcclusionInset = 0;
    private int mAppliedViewportWidth = -1;
    private int mAppliedViewportHeight = -1;

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
    @Nullable
    private LanguageConfiguration mLanguageConfiguration;
    @Nullable
    private EditorMetadata mMetadata;
    /**
     * Current theme (default dark).
     */
    private EditorTheme mTheme = EditorTheme.dark();
    private static final int TRANSIENT_SCROLLBAR_REFRESH_MIN_MS = 16;

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
    private final Runnable mTransientScrollbarRefresh = new Runnable() {
        @Override
        public void run() {
            // Trigger one rebuild so C++ transient alpha/visibility can advance.
            flush();
        }
    };

    // Unified animation callback: drives edge-scroll, fling, etc. via Choreographer
    private boolean mAnimationActive = false;
    private final Choreographer.FrameCallback mAnimationFrameCallback = new Choreographer.FrameCallback() {
        @Override
        public void doFrame(long frameTimeNanos) {
            if (!mAnimationActive) return;
            EditorCore.GestureResult result = mEditorCore.tickAnimations();
            fireGestureEvents(result, null, -1);
            flush();
            if (result.needsAnimation) {
                Choreographer.getInstance().postFrameCallback(this);
            } else {
                mAnimationActive = false;
            }
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
        EditorCore.GestureResult result = mEditorCore.handleGestureEvent(event);
        Log.d(TAG, "result: " + result);
        PointF screenPoint = new PointF(event.getX(), event.getY());
        fireGestureEvents(result, screenPoint, event.getActionMasked());
        if (result.type == EditorCore.GestureType.TAP) {
            requestFocus();
            if (result.hitTarget == null || result.hitTarget.type == EditorCore.HitTargetType.NONE) {
                showSoftKeyboard();
            }
            resetCursorBlink();
        } else if (result.type == EditorCore.GestureType.SCALE) {
            // C++ core already applies scale during gesture handling; only sync platform-side measurer/paints here.
            syncPlatformScale(result.viewScale);
        }
        flush();
        if (result.needsAnimation && !mAnimationActive) {
            mAnimationActive = true;
            Choreographer.getInstance().postFrameCallback(mAnimationFrameCallback);
        } else if (!result.needsAnimation && mAnimationActive) {
            mAnimationActive = false;
            Choreographer.getInstance().removeFrameCallback(mAnimationFrameCallback);
        }
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

        boolean needsTransientRefresh = mRenderer.render(canvas, model, getWidth(), getHeight(),
                mCursorVisible, buildMs);

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

        if (needsTransientRefresh) {
            scheduleTransientScrollbarRefresh(TRANSIENT_SCROLLBAR_REFRESH_MIN_MS);
        } else {
            mHandler.removeCallbacks(mTransientScrollbarRefresh);
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
        requestApplyInsets();
        post(() -> refreshViewportForVisibleBounds(false));
    }

    @Override
    protected void onDetachedFromWindow() {
        super.onDetachedFromWindow();
        mHandler.removeCallbacks(mCursorBlink);
        mHandler.removeCallbacks(mTransientScrollbarRefresh);
        Choreographer.getInstance().removeFrameCallback(mAnimationFrameCallback);
        mAnimationActive = false;
        if (mSelectionMenuController != null) {
            mSelectionMenuController.dismiss();
        }
    }

    @Override
    public void onWindowFocusChanged(boolean hasWindowFocus) {
        super.onWindowFocusChanged(hasWindowFocus);
        if (hasWindowFocus) {
            resetCursorBlink();
        } else {
            mHandler.removeCallbacks(mCursorBlink);
            mHandler.removeCallbacks(mTransientScrollbarRefresh);
            Choreographer.getInstance().removeFrameCallback(mAnimationFrameCallback);
            mAnimationActive = false;
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
        mEditorCore.setKeyMap(keyMap);
    }

    void syncPlatformScale(float scale) {
        mRenderer.syncPlatformScale(scale);
        mEditorCore.onFontMetricsChanged();
        mModelDirty = true;
    }

    void applyTypeface(Typeface typeface) {
        mRenderer.applyTypeface(typeface);
        mEditorCore.onFontMetricsChanged();
        flush();
    }

    void applyTextSize(float textSize) {
        mRenderer.applyTextSize(textSize);
        mEditorCore.onFontMetricsChanged();
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
        mRenderer.applyTheme(theme);

        mEditorCore.registerBatchTextStyles(theme.textStyles);

        if (mInlineSuggestionController != null) {
            mInlineSuggestionController.applyTheme(theme);
        }

        if (mCompletionPopupController != null) {
            mCompletionPopupController.applyTheme(theme);
        }

        if (mSelectionMenuController != null) {
            mSelectionMenuController.applyTheme(theme);
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
        dispatchTextChanged(TextChangeAction.DELETE, result);
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
        if (mSelectionMenuController != null) {
            mSelectionMenuController.onSelectAll();
        }
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
     * @param fontStyle       font style bit flags ({@link TextStyle#NORMAL}, {@link TextStyle#BOLD},
     *                        {@link TextStyle#ITALIC}, {@link TextStyle#STRIKETHROUGH}, combinable via bitwise OR)
     */
    public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle) {
        mEditorCore.registerTextStyle(styleId, color, backgroundColor, fontStyle);
    }

    /**
     * Register a reusable highlight style (no background, backward compatible).
     *
     * @param styleId   Style ID (custom, must be unique)
     * @param color     ARGB foreground color
     * @param fontStyle Font style bit flags
     */
    public void registerTextStyle(int styleId, int color, int fontStyle) {
        mEditorCore.registerTextStyle(styleId, color, fontStyle);
    }

    /**
     * Register multiple reusable highlight styles in one batch.
     *
     * @param stylesById style ID -> style mapping; null or empty input is ignored
     */
    public void registerBatchTextStyles(@Nullable Map<Integer, TextStyle> stylesById) {
        mEditorCore.registerBatchTextStyles(stylesById);
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
     * @param spansByLine Sparse array of line number 鈫?span list
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
     * @param hintsByLine Sparse array of line number 鈫?hint list
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
     * @param phantomsByLine Sparse array of line number 鈫?phantom list
     */
    public void setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        mEditorCore.setBatchLinePhantomTexts(phantomsByLine);
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
        mEditorCore.setLineGutterIcons(line, icons);
    }

    /**
     * Batch set gutter icons for multiple lines (reduces JNI calls).
     *
     * @param iconsByLine Sparse array of line number 鈫?icon list
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
    public void setLineDiagnostics(int line, @NonNull List<? extends Diagnostic> items) {
        mEditorCore.setLineDiagnostics(line, items);
    }

    /**
     * Batch set diagnostic decorations for multiple lines (reduces JNI calls).
     *
     * @param diagsByLine Sparse array of line number 鈫?diagnostic list
     */
    public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> diagsByLine) {
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
        flush();
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
            mEditorCore.setBracketPairs(opens, closes);
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
            mEditorCore.setAutoClosingPairs(acOpens, acCloses);
        }

        if (config.getTabSize() > 0) {
            mEditorCore.setTabSize(config.getTabSize());
        }

        mEditorCore.setInsertSpaces(config.getInsertSpaces());
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

    // ==================== IME Internal Methods (package-private) ====================

    boolean isCompositionEnabled() {
        return mSettings != null ? mSettings.isCompositionEnabled() : mEditorCore.isCompositionEnabled();
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
            // Hide selection menu on text change
            if (mSelectionMenuController != null) {
                mSelectionMenuController.onTextChanged();
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
        CompletionItem.TextEdit textEdit = item.textEdit;
        boolean isSnippet = item.insertTextFormat == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
        String text = item.insertText != null ? item.insertText : item.label;

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
    private void fireGestureEvents(EditorCore.GestureResult result, PointF screenPoint, int actionMasked) {
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
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    InlayType.TEXT,
                                    0,
                                    screenPoint));
                            break;
                        case INLAY_HINT_ICON:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    InlayType.ICON,
                                    result.hitTarget.iconId,
                                    screenPoint));
                            break;
                        case INLAY_HINT_COLOR:
                            mEventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    InlayType.COLOR,
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

        // Drive selection menu state machine
        if (mSelectionMenuController != null) {
            mSelectionMenuController.onGestureResult(result, actionMasked);
        }
    }

    private void dispatchKeyEventResult(@NonNull EditorCore.KeyEventResult result) {
        if (result.contentChanged) {
            if (mSelectionMenuController != null) {
                mSelectionMenuController.onTextChanged();
            }
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
        // Inline suggestion keyboard interception (Tab/Escape)
        if (mInlineSuggestionController != null && mInlineSuggestionController.isShowing()) {
            if (mInlineSuggestionController.handleAndroidKeyCode(event.getKeyCode())) {
                return;
            }
        }
        // Completion panel keyboard interception (Enter/Escape/Up/Down)
        if (mCompletionPopupController != null && mCompletionPopupController.isShowing()) {
            if (mCompletionPopupController.handleAndroidKeyCode(event.getKeyCode())) {
                return;
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
            // Give priority to NewLineActionProvider to handle Enter (Provider decides indentation),
            // if no Provider or returns null, fallback to Core layer default behavior
            if (nativeKeyCode == KeyCode.ENTER && mNewLineActionProviderManager != null) {
                NewLineAction action = mNewLineActionProviderManager.provideNewLineAction();
                if (action != null) {
                    EditorCore.TextEditResult editResult = mEditorCore.insertText(action.text);
                    dispatchTextChanged(TextChangeAction.KEY, editResult);
                    resetCursorBlink();
                    flush();
                    logInputPerf(t0, "key-enter");
                    return;
                }
            }
            int modifiers = KeyModifier.NONE;
            if (event.isShiftPressed()) modifiers |= KeyModifier.SHIFT;
            if (event.isCtrlPressed()) modifiers |= KeyModifier.CTRL;
            if (event.isAltPressed()) modifiers |= KeyModifier.ALT;
            if (event.isMetaPressed()) modifiers |= KeyModifier.META;
            EditorCore.KeyEventResult result = mEditorCore.handleKeyEvent(nativeKeyCode, null, modifiers);
            if (result.handled && dispatchKeyMapCommand(result.command, nativeKeyCode, modifiers)) {
                resetCursorBlink();
                flush();
                logInputPerf(t0, "key-cmd");
                return;
            }
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
        mRenderer.getPerfOverlay().recordInput(tag, ms);
    }

    private boolean dispatchKeyMapCommand(int command, int keyCode, int modifiers) {
        if (mKeyMap == null) return false;
        EditorCommand<SweetEditor> handler = mKeyMap.getCommand(command);
        if (handler == null) return false;
        KeyBinding binding = new KeyBinding(modifiers, keyCode, command);
        handler.onShortCut(binding, this);
        return true;
    }

    private EditorKeyMap createDefaultKeyMap() {
        return EditorKeyMap.defaultKeyMap();
    }

    // ==================== Private Helper / Internal Implementation ====================

    private void initView(Context context) {
        float density = getResources().getDisplayMetrics().density;
        mRenderer = new EditorRenderer(mTheme, density);

        mRenderer.setHandleConfig(EditorRenderer.computeHandleHitConfig(density));

        float scrollbarThicknessPx = 8.0f * density;
        float scrollbarMinThumbPx = 40.0f * density;
        float scrollbarThumbHitPaddingPx = 20.0f * density;
        mRenderer.setScrollbarConfig(new ScrollbarConfig(
                scrollbarThicknessPx,
                scrollbarMinThumbPx,
                scrollbarThumbHitPaddingPx,
                ScrollbarConfig.ScrollbarMode.TRANSIENT,
                true,
                ScrollbarConfig.ScrollbarTrackTapMode.DISABLED,
                700,
                300));

        mTextMeasurer = mRenderer.getTextMeasurer();

        int scaledTouchSlop = ViewConfiguration.get(context).getScaledTouchSlop();
        EditorOptions editorOptions = new EditorOptions(scaledTouchSlop, 300);
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

        mEditorCore.registerBatchTextStyles(mTheme.textStyles);

        mSettings = new EditorSettings(this);
        mEditorCore.setCompositionEnabled(mSettings.isCompositionEnabled());
        mKeyMap = createDefaultKeyMap();
        mSettings.setContentStartPadding(DEFAULT_CONTENT_START_PADDING_DP * density);
        mSettings.setTypeface(Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL));
        mSettings.setGutterSticky(false);
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
        mEditorCore.setViewport(width, effectiveHeight);
        mModelDirty = true;
        if ((ensureCursorVisible || viewportNarrowed || viewportShrunk) && hasWindowFocus()) {
            mEditorCore.ensureCursorVisible();
        }
        postInvalidate();
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

    private void scheduleTransientScrollbarRefresh(int requestedDelayMs) {
        ScrollbarConfig config = mRenderer.getScrollbarConfig();
        if (config == null || config.mode != ScrollbarConfig.ScrollbarMode.TRANSIENT) {
            mHandler.removeCallbacks(mTransientScrollbarRefresh);
            return;
        }
        int delayMs = Math.max(TRANSIENT_SCROLLBAR_REFRESH_MIN_MS, requestedDelayMs);
        mHandler.removeCallbacks(mTransientScrollbarRefresh);
        mHandler.postDelayed(mTransientScrollbarRefresh, delayMs);
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
        requestApplyInsets();
    }

    private static int mapAndroidKeyCode(int androidKeyCode) {
        switch (androidKeyCode) {
            case KeyEvent.KEYCODE_DEL:         return KeyCode.BACKSPACE;
            case KeyEvent.KEYCODE_TAB:         return KeyCode.TAB;
            case KeyEvent.KEYCODE_ENTER:       return KeyCode.ENTER;
            case KeyEvent.KEYCODE_ESCAPE:      return KeyCode.ESCAPE;
            case KeyEvent.KEYCODE_FORWARD_DEL: return KeyCode.DELETE_KEY;
            case KeyEvent.KEYCODE_DPAD_LEFT:   return KeyCode.LEFT;
            case KeyEvent.KEYCODE_DPAD_UP:     return KeyCode.UP;
            case KeyEvent.KEYCODE_DPAD_RIGHT:  return KeyCode.RIGHT;
            case KeyEvent.KEYCODE_DPAD_DOWN:   return KeyCode.DOWN;
            case KeyEvent.KEYCODE_MOVE_HOME:   return KeyCode.HOME;
            case KeyEvent.KEYCODE_MOVE_END:    return KeyCode.END;
            case KeyEvent.KEYCODE_PAGE_UP:     return KeyCode.PAGE_UP;
            case KeyEvent.KEYCODE_PAGE_DOWN:   return KeyCode.PAGE_DOWN;
            case KeyEvent.KEYCODE_SPACE:        return KeyCode.SPACE;
            default:                           return KeyCode.NONE;
        }
    }
}

