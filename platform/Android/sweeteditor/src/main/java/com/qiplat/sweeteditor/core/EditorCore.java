package com.qiplat.sweeteditor.core;

import android.graphics.PointF;
import android.util.SparseArray;
import android.view.MotionEvent;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.visual.CursorRect;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.adornment.TextStyle;

import java.nio.ByteBuffer;
import java.util.List;

import dalvik.annotation.optimization.CriticalNative;
import dalvik.annotation.optimization.FastNative;

/**
 * Core editor interface that directly bridges to the C++ layer API.
 * <p>
 * Encapsulates all low-level functionalities including text editing, cursor management,
 * selection operations, gesture/keyboard event handling, code folding, and diagnostic
 * decorations through JNI bridging.
 *
 * @author Scave
 */
public class EditorCore {

    private static final int EVENT_TYPE_UNDEFINED = 0;
    private static final int EVENT_TYPE_TOUCH_DOWN = 1;
    private static final int EVENT_TYPE_TOUCH_POINTER_DOWN = 2;
    private static final int EVENT_TYPE_TOUCH_MOVE = 3;
    private static final int EVENT_TYPE_TOUCH_POINTER_UP = 4;
    private static final int EVENT_TYPE_TOUCH_UP = 5;
    private static final int EVENT_TYPE_TOUCH_CANCEL = 6;
    private static final int EVENT_TYPE_MOUSE_DOWN = 7;
    private static final int EVENT_TYPE_MOUSE_MOVE = 8;
    private static final int EVENT_TYPE_MOUSE_UP = 9;
    private static final int EVENT_TYPE_MOUSE_WHEEL = 10;
    private static final int EVENT_TYPE_MOUSE_RIGHT_DOWN = 11;
    private static final int EVENT_TYPE_DIRECT_SCALE = 12;
    private static final int EVENT_TYPE_DIRECT_SCROLL = 13;

    // ==================== Construction/Initialization/Lifecycle ====================

    private long mNativeHandle;
    @Nullable private Document mDocument;
    private HandleConfig mHandleConfig = new HandleConfig();
    private ScrollbarConfig mScrollbarConfig = new ScrollbarConfig();

    public EditorCore(TextMeasurer measurer, EditorOptions options) {
        ByteBuffer optionsBuf = ProtocolEncoder.packEditorOptions(options);
        this.mNativeHandle = nativeMakeEditorCore(measurer, optionsBuf, optionsBuf.remaining());
    }

    @Override
    protected void finalize() throws Throwable {
        super.finalize();
        if (mNativeHandle == 0) {
            return;
        }
        nativeFinalizeEditorCore(mNativeHandle);
        mNativeHandle = 0;
    }

    public void loadDocument(Document document) {
        if (mNativeHandle == 0) {
            return;
        }
        mDocument = document;
        nativeLoadDocument(mNativeHandle, document.mNativeHandle);
    }

    /**
     * Gets the currently loaded document instance.
     */
    @Nullable
    public Document getDocument() {
        return mDocument;
    }

    // ==================== Viewport/Font/Appearance Configuration ====================

    public void setViewport(int width, int height) {
        if (mNativeHandle == 0) {
            return;
        }
        nativeSetViewport(mNativeHandle, width, height);
    }

    public void resetMeasurer() {
        if (mNativeHandle == 0) {
            return;
        }
        nativeResetMeasurer(mNativeHandle);
    }

    /**
     * Sets the fold arrow display mode (affects gutter width reservation).
     *
     * @param mode 0=AUTO (auto show when fold regions exist), 1=ALWAYS (always reserve), 2=HIDDEN (always hide)
     */
    public void setFoldArrowMode(int mode) {
        if (mNativeHandle == 0) return;
        nativeSetFoldArrowMode(mNativeHandle, mode);
    }

    /**
     * Sets the auto wrap mode.
     *
     * @param mode 0=NONE (no wrap), 1=CHAR_BREAK (character-level wrap), 2=WORD_BREAK (word-level wrap)
     */
    public void setWrapMode(int mode) {
        if (mNativeHandle == 0) return;
        nativeSetWrapMode(mNativeHandle, mode);
    }

    /**
     * Sets the editor scale factor.
     *
     * @param scale scale factor (1.0 = 100%)
     */
    public void setScale(float scale) {
        if (mNativeHandle == 0) return;
        nativeSetScale(mNativeHandle, scale);
    }

    /**
     * Sets line spacing parameters (formula: line_height = font_height * mult + add).
     *
     * @param add  Extra line spacing in pixels (default 0)
     * @param mult Line spacing multiplier (default 1.0)
     */
    public void setLineSpacing(float add, float mult) {
        if (mNativeHandle == 0) return;
        nativeSetLineSpacing(mNativeHandle, add, mult);
    }

    /**
     * Sets extra horizontal padding between gutter split and text content start.
     *
     * @param padding padding in pixels (clamped to >= 0 on native side)
     */
    public void setContentStartPadding(float padding) {
        if (mNativeHandle == 0) return;
        nativeSetContentStartPadding(mNativeHandle, padding);
    }

    /**
     * Sets whether gutter split line should be rendered.
     *
     * @param show true to show split line, false to hide
     */
    public void setShowSplitLine(boolean show) {
        if (mNativeHandle == 0) return;
        nativeSetShowSplitLine(mNativeHandle, show);
    }

    /**
     * Sets current line render mode.
     *
     * @param mode 0=BACKGROUND(fill), 1=BORDER(stroke), 2=NONE(disabled)
     */
    public void setCurrentLineRenderMode(int mode) {
        if (mNativeHandle == 0) return;
        nativeSetCurrentLineRenderMode(mNativeHandle, mode);
    }

    // ==================== Rendering ====================

    @Nullable
    public EditorRenderModel buildRenderModel() {
        if (mNativeHandle == 0) return null;
        ByteBuffer data = nativeBuildRenderModel(mNativeHandle);
        EditorRenderModel model;
        try {
            model = ProtocolDecoder.decodeRenderModel(data);
        } catch (RuntimeException ignored) {
            model = null;
        } finally {
            nativeFreeBinaryData(data);
        }
        return model;
    }

    // ==================== Gesture/Keyboard Event Handling ====================

    public GestureResult handleGestureEvent(MotionEvent event) {
        if (mNativeHandle == 0) {
            return new GestureResult();
        }
        int eventType = getEventTypeInt(event);
        int pointerCount = event.getPointerCount();
        float[] points = new float[pointerCount * 2];
        for (int i = 0; i < pointerCount; i++) {
            points[i * 2] = event.getX(i);
            points[i * 2 + 1] = event.getY(i);
        }
        ByteBuffer data = nativeHandleGestureEvent(mNativeHandle, eventType, pointerCount, points);
        try {
            return ProtocolDecoder.decodeGestureResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Tick edge-scroll during drag selection / handle drag.
     * Call at ~16ms intervals while the previous GestureResult.needsEdgeScroll was true.
     */
    public GestureResult tickEdgeScroll() {
        if (mNativeHandle == 0) {
            return new GestureResult();
        }
        ByteBuffer data = nativeTickEdgeScroll(mNativeHandle);
        try {
            return ProtocolDecoder.decodeGestureResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    public KeyEventResult handleKeyEvent(int keyCode, String text, int modifiers) {
        if (mNativeHandle == 0) {
            return new KeyEventResult();
        }
        ByteBuffer data = nativeHandleKeyEvent(mNativeHandle, keyCode, text, modifiers);
        try {
            return ProtocolDecoder.decodeKeyEventResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Text Editing ====================

    @NonNull
    public TextEditResult insertText(String text) {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeInsertText(mNativeHandle, text);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Replaces text in the specified range (atomic operation).
     * @param range Text range to replace
     * @param newText New text after replacement
     * @return Exact change information
     */
    @NonNull
    public TextEditResult replaceText(@NonNull TextRange range, @NonNull String newText) {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeReplaceText(mNativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column, newText);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Deletes text in the specified range (atomic operation).
     * @param range Text range to delete
     * @return Exact change information
     */
    @NonNull
    public TextEditResult deleteText(@NonNull TextRange range) {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeDeleteText(mNativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Line Operations ====================

    @NonNull
    public TextEditResult moveLineUp() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeMoveLineUp(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult moveLineDown() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeMoveLineDown(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult copyLineUp() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeCopyLineUp(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult copyLineDown() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeCopyLineDown(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult deleteLine() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeDeleteLine(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult insertLineAbove() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeInsertLineAbove(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult insertLineBelow() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeInsertLineBelow(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Undo/Redo ====================

    @NonNull
    public TextEditResult undo() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeUndo(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public TextEditResult redo() {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeRedo(mNativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Checks if undo is available.
     *
     * @return {@code true} if there are operations to undo
     */
    public boolean canUndo() {
        if (mNativeHandle == 0) return false;
        return nativeCanUndo(mNativeHandle);
    }

    /**
     * Checks if redo is available.
     *
     * @return {@code true} if there are operations to redo
     */
    public boolean canRedo() {
        if (mNativeHandle == 0) return false;
        return nativeCanRedo(mNativeHandle);
    }

    // ==================== Cursor/Selection Management ====================

    /**
     * Gets the current cursor position.
     *
     * @return Cursor {@link TextPosition} (line, column)
     */
    public TextPosition getCursorPosition() {
        if (mNativeHandle == 0) return new TextPosition();
        long value = nativeGetCursorPosition(mNativeHandle);
        int line = (int) (value >> 32);
        int column = (int) (value & 0XFFFFFFFFL);
        return new TextPosition(line, column);
    }

    /**
     * Gets the text range of the word at the cursor.
     *
     * @return Word {@link TextRange} (start = word start, end = cursor position)
     */
    @NonNull
    public TextRange getWordRangeAtCursor() {
        if (mNativeHandle == 0) return new TextRange(new TextPosition(), new TextPosition());
        long[] vals = nativeGetWordRangeAtCursor(mNativeHandle);
        return new TextRange(
                new TextPosition((int) vals[0], (int) vals[1]),
                new TextPosition((int) vals[2], (int) vals[3]));
    }

    /**
     * Gets the text content of the word at the cursor.
     *
     * @return Word text, returns empty string if cursor is not on a word
     */
    @NonNull
    public String getWordAtCursor() {
        if (mNativeHandle == 0) return "";
        String word = nativeGetWordAtCursor(mNativeHandle);
        return word != null ? word : "";
    }

    /**
     * Sets the cursor position (does not scroll viewport, only moves cursor).
     *
     * @param position Target position
     */
    public void setCursorPosition(@NonNull TextPosition position) {
        if (mNativeHandle == 0) return;
        nativeSetCursorPosition(mNativeHandle, position.line, position.column);
    }

    /** Selects all document content. */
    public void selectAll() {
        if (mNativeHandle == 0) return;
        nativeSelectAll(mNativeHandle);
    }

    /**
     * Sets the selection range.
     *
     * @param startLine   Selection start line (0-based)
     * @param startColumn Selection start column (0-based)
     * @param endLine     Selection end line (0-based)
     * @param endColumn   Selection end column (0-based)
     */
    public void setSelection(int startLine, int startColumn, int endLine, int endColumn) {
        if (mNativeHandle == 0) return;
        nativeSetSelection(mNativeHandle, startLine, startColumn, endLine, endColumn);
    }

    /**
     * Sets the selection range.
     *
     * @param range Selection range
     */
    public void setSelection(@NonNull TextRange range) {
        setSelection(range.start.line, range.start.column, range.end.line, range.end.column);
    }

    /**
     * Gets the current selection range.
     *
     * @return Selection range; returns {@code null} if no selection
     */
    @Nullable
    public TextRange getSelection() {
        if (mNativeHandle == 0) return null;
        long[] vals = nativeGetSelection(mNativeHandle);
        if (vals == null || vals[0] == -1) return null;
        return new TextRange(
                new TextPosition((int) vals[0], (int) vals[1]),
                new TextPosition((int) vals[2], (int) vals[3])
        );
    }

    public String getSelectedText() {
        if (mNativeHandle == 0) return "";
        return nativeGetSelectedText(mNativeHandle);
    }

    // ==================== IME Composition Input ====================

    public void compositionStart() {
        if (mNativeHandle == 0) return;
        nativeCompositionStart(mNativeHandle);
    }

    public void compositionUpdate(String text) {
        if (mNativeHandle == 0) return;
        nativeCompositionUpdate(mNativeHandle, text);
    }

    @NonNull
    public TextEditResult compositionEnd(String committedText) {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeCompositionEnd(mNativeHandle, committedText);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    public void compositionCancel() {
        if (mNativeHandle == 0) return;
        nativeCompositionCancel(mNativeHandle);
    }

    public boolean isComposing() {
        if (mNativeHandle == 0) return false;
        return nativeIsComposing(mNativeHandle);
    }

    /**
     * Sets whether IME composition is enabled.
     * <p>When disabled, setComposingText falls back to direct commitText.
     *
     * @param enabled {@code true}=enable, {@code false}=disable
     */
    public void setCompositionEnabled(boolean enabled) {
        if (mNativeHandle == 0) return;
        nativeSetCompositionEnabled(mNativeHandle, enabled);
    }

    /**
     * Gets whether IME composition is enabled.
     *
     * @return {@code true} if enabled
     */
    public boolean isCompositionEnabled() {
        if (mNativeHandle == 0) return false;
        return nativeIsCompositionEnabled(mNativeHandle);
    }

    // ==================== Read-Only Mode ====================

    /**
     * Sets read-only mode.
     *
     * @param readOnly {@code true}=read-only (blocks all edit operations), {@code false}=editable
     */
    public void setReadOnly(boolean readOnly) {
        if (mNativeHandle == 0) return;
        nativeSetReadOnly(mNativeHandle, readOnly);
    }

    /**
     * Gets whether read-only mode is active.
     *
     * @return {@code true} if currently in read-only mode
     */
    public boolean isReadOnly() {
        if (mNativeHandle == 0) return false;
        return nativeIsReadOnly(mNativeHandle);
    }

    // ==================== Auto Indent ====================

    /**
     * Sets the auto indent mode.
     *
     * @param mode Auto indent mode
     */
    public void setAutoIndentMode(int mode) {
        if (mNativeHandle == 0) return;
        nativeSetAutoIndentMode(mNativeHandle, mode);
    }

    /**
     * Gets the current auto indent mode.
     *
     * @return Auto indent mode value (0=NONE, 1=KEEP_INDENT)
     */
    public int getAutoIndentMode() {
        if (mNativeHandle == 0) return 0;
        return nativeGetAutoIndentMode(mNativeHandle);
    }

    // ==================== Handle Config ====================

    /**
     * Sets the selection handle appearance and touch configuration.
     * Parameters are passed to C++ core (for hit-test) and cached in Java (for drawing).
     *
     * @param config HandleConfig instance
     */
    public void setHandleConfig(HandleConfig config) {
        if (mNativeHandle == 0) return;
        mHandleConfig = config;
        nativeSetHandleConfig(mNativeHandle, config.radius, config.centerDist, config.lineWidth, config.touchPadding, config.dragYOffset);
    }

    /**
     * Gets the current handle configuration (cached in Java side).
     *
     * @return Current HandleConfig
     */
    public HandleConfig getHandleConfig() {
        return mHandleConfig;
    }

    // ==================== Scrollbar Config ====================

    /**
     * Sets the scrollbar geometry configuration.
     *
     * @param config ScrollbarConfig instance
     */
    public void setScrollbarConfig(ScrollbarConfig config) {
        if (mNativeHandle == 0) return;
        mScrollbarConfig = config;
        nativeSetScrollbarConfig(
                mNativeHandle,
                config.thickness,
                config.minThumb,
                config.thumbHitPadding,
                config.mode.value,
                config.thumbDraggable,
                config.trackTapMode.value,
                config.fadeDelayMs,
                config.fadeDurationMs);
    }

    /**
     * Gets the current scrollbar configuration (cached in Java side).
     *
     * @return Current ScrollbarConfig
     */
    public ScrollbarConfig getScrollbarConfig() {
        return mScrollbarConfig;
    }

    // ==================== Position Coordinate Query ====================

    /**
     * Gets the screen coordinate rectangle for any text position (for floating panel positioning).
     *
     * @param line   Line number (0-based)
     * @param column Column number (0-based)
     * @return CursorRect (x, y, height), coordinates relative to editor view top-left
     */
    public CursorRect getPositionRect(int line, int column) {
        if (mNativeHandle == 0) return new CursorRect(0, 0, 0);
        float[] data = nativeGetPositionRect(mNativeHandle, line, column);
        return new CursorRect(data[0], data[1], data[2]);
    }

    /**
     * Gets the screen coordinate rectangle at the current cursor position (shortcut method).
     *
     * @return CursorRect (x, y, height), coordinates relative to editor view top-left
     */
    public CursorRect getCursorRect() {
        if (mNativeHandle == 0) return new CursorRect(0, 0, 0);
        float[] data = nativeGetCursorRect(mNativeHandle);
        return new CursorRect(data[0], data[1], data[2]);
    }

    // ==================== Scroll/Navigation ====================

    /**
     * Scrolls to the specified line.
     *
     * @param line     Line number (0-based)
     * @param behavior Scroll behavior (0=GOTO_TOP, 1=GOTO_CENTER, 2=GOTO_BOTTOM)
     */
    public void scrollToLine(int line, int behavior) {
        if (mNativeHandle == 0) return;
        nativeScrollToLine(mNativeHandle, line, behavior);
    }

    /**
     * Goes to the specified line and column (scroll + cursor positioning).
     *
     * @param line   Line number (0-based)
     * @param column Column number (0-based)
     */
    public void gotoPosition(int line, int column) {
        if (mNativeHandle == 0) return;
        nativeGotoPosition(mNativeHandle, line, column);
    }

    /**
     * Manually sets the scroll position (automatically clamped to valid range).
     */
    public void setScroll(float scrollX, float scrollY) {
        if (mNativeHandle == 0) return;
        nativeSetScroll(mNativeHandle, scrollX, scrollY);
    }

    /**
     * Gets scrollbar metrics (used by platform to calculate thumb size and position).
     */
    @NonNull
    public ScrollMetrics getScrollMetrics() {
        if (mNativeHandle == 0) {
            return ProtocolDecoder.defaultScrollMetrics();
        }
        ByteBuffer data = nativeGetScrollMetrics(mNativeHandle);
        try {
            return ProtocolDecoder.decodeScrollMetrics(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Style Registration + Highlight Spans ====================

    /**
     * Registers a highlight style.
     *
     * @param styleId         Style ID (referenced in subsequent setLineSpans)
     * @param color           ARGB color value
     * @param backgroundColor ARGB background color value (0=transparent)
     * @param fontStyle       Font style bit flags ({@link TextStyle#NORMAL}, {@link TextStyle#BOLD},
     *                        {@link TextStyle#ITALIC}, {@link TextStyle#STRIKETHROUGH}, combinable via bitwise OR)
     */
    public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle) {
        if (mNativeHandle == 0) return;
        nativeRegisterTextStyle(mNativeHandle, styleId, color, backgroundColor, fontStyle);
    }

    /**
     * Registers a highlight style (without background color, backward compatible).
     *
     * @param styleId   Style ID
     * @param color     ARGB color value
     * @param fontStyle Font style bit flags
     */
    public void registerTextStyle(int styleId, int color, int fontStyle) {
        registerTextStyle(styleId, color, 0, fontStyle);
    }

    /**
     * Sets highlight spans for the specified line.
     *
     * @param line        Line number (0-based)
     * @param layer       Highlight layer (0=SYNTAX, 1=SEMANTIC)
     * @param styleSpans Span highlight sequence
     */
    public void setLineSpans(int line, int layer, List<? extends StyleSpan> styleSpans) {
        if (mNativeHandle == 0 || styleSpans == null) return;
        setLineSpans(ProtocolEncoder.packLineSpans(line, layer, styleSpans));
    }



    /**
     * Sets highlight spans for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer (format: line, layer, count, [col, len, style]脳N)
     */
    public void setLineSpans(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetLineSpans(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Batch sets highlight spans for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param layer       Highlight layer (0=SYNTAX, 1=SEMANTIC)
     * @param spansByLine Sparse array of line鈫抯pan list
     */
    public void setBatchLineSpans(int layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine) {
        if (mNativeHandle == 0 || spansByLine == null || spansByLine.size() == 0) return;
        ByteBuffer payload = ProtocolEncoder.packBatchLineSpans(layer, spansByLine);
        setBatchLineSpans(payload);
    }

    /**
     * Batch sets highlight spans for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    public void setBatchLineSpans(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetBatchLineSpans(mNativeHandle, payload, payload.remaining());
    }

    // ==================== InlayHint / PhantomText ====================

    /**
     * Batch sets Inlay Hints for the specified lines.
     *
     * @param line  Line number (0-based)
     * @param hints InlayHint list
     */
    public void setLineInlayHints(int line, @NonNull List<? extends InlayHint> hints) {
        ByteBuffer payload = ProtocolEncoder.packLineInlayHints(line, hints);
        setLineInlayHints(payload);
    }

    /**
     * Batch sets Inlay Hints for the specified lines (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setLineInlayHints(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetLineInlayHints(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Batch sets Inlay Hints for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param hintsByLine Sparse array of line鈫抙int list
     */
    public void setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine) {
        if (mNativeHandle == 0 || hintsByLine == null || hintsByLine.size() == 0) return;
        ByteBuffer payload = ProtocolEncoder.packBatchLineInlayHints(hintsByLine);
        setBatchLineInlayHints(payload);
    }

    /**
     * Batch sets Inlay Hints for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    public void setBatchLineInlayHints(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetBatchLineInlayHints(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Sets phantom text for the specified line (replaces entire line).
     *
     * @param line     Line number (0-based)
     * @param phantoms Phantom text list (already sorted by column ascending)
     */
    public void setLinePhantomTexts(int line, @NonNull List<? extends PhantomText> phantoms) {
        if (mNativeHandle == 0 || phantoms == null) return;
        setLinePhantomTexts(ProtocolEncoder.packLinePhantomTexts(line, phantoms));
    }

    /**
     * Sets phantom text for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setLinePhantomTexts(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetLinePhantomTexts(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Batch sets phantom text for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param phantomsByLine Sparse array of line鈫抪hantom list
     */
    public void setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        if (mNativeHandle == 0 || phantomsByLine == null || phantomsByLine.size() == 0) return;
        ByteBuffer payload = ProtocolEncoder.packBatchLinePhantomTexts(phantomsByLine);
        setBatchLinePhantomTexts(payload);
    }

    /**
     * Batch sets phantom text for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    public void setBatchLinePhantomTexts(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetBatchLinePhantomTexts(mNativeHandle, payload, payload.remaining());
    }

    // ==================== Gutter Icons ====================

    /**
     * Sets gutter icons for the specified line (replaces entire line).
     *
     * @param line  Line number (0-based)
     * @param icons Icon list
     */
    public void setLineGutterIcons(int line, @NonNull List<? extends GutterIcon> icons) {
        if (mNativeHandle == 0 || icons == null) return;
        setLineGutterIcons(ProtocolEncoder.packLineGutterIcons(line, icons));
    }

    /**
     * Sets gutter icons for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setLineGutterIcons(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetLineGutterIcons(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Batch sets gutter icons for multiple lines (reduces JNI calls).
     *
     * @param iconsByLine Sparse array of line鈫抜con list
     */
    public void setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine) {
        if (mNativeHandle == 0 || iconsByLine == null || iconsByLine.size() == 0) return;
        ByteBuffer payload = ProtocolEncoder.packBatchLineGutterIcons(iconsByLine);
        setBatchLineGutterIcons(payload);
    }

    /**
     * Batch sets gutter icons for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    public void setBatchLineGutterIcons(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetBatchLineGutterIcons(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Sets the maximum number of gutter icons (affects gutter width reservation).
     * <p>Icon width = line height, gutter will reserve space for count icons after setting this.
     *
     * @param count Maximum icon count (0=no reservation, default 0)
     */
    public void setMaxGutterIcons(int count) {
        if (mNativeHandle == 0) return;
        nativeSetMaxGutterIcons(mNativeHandle, count);
    }

    // ==================== Diagnostic Decorations ====================

    /**
     * Sets diagnostic decorations for the specified line.
     *
     * @param line  Line number (0-based)
     * @param items Diagnostic item list
     */
    public void setLineDiagnostics(int line, @NonNull List<? extends DiagnosticItem> items) {
        if (mNativeHandle == 0 || items == null) return;
        setLineDiagnostics(ProtocolEncoder.packLineDiagnostics(line, items));
    }

    /**
     * Sets diagnostic decorations for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer (format: line, count, [col, len, severity, color]脳N)
     */
    public void setLineDiagnostics(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetLineDiagnostics(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Batch sets diagnostic decorations for multiple lines (reduces JNI calls).
     *
     * @param diagsByLine Sparse array of line鈫抎iagnostic list
     */
    public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends DiagnosticItem>> diagsByLine) {
        if (mNativeHandle == 0 || diagsByLine == null || diagsByLine.size() == 0) return;
        ByteBuffer payload = ProtocolEncoder.packBatchLineDiagnostics(diagsByLine);
        setBatchLineDiagnostics(payload);
    }

    /**
     * Batch sets diagnostic decorations for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    public void setBatchLineDiagnostics(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetBatchLineDiagnostics(mNativeHandle, payload, payload.remaining());
    }

    // ==================== Guide (Code Structure Lines) ====================

    /**
     * Sets indent guide list (global replace).
     *
     * @param guides Indent guide list
     */
    public void setIndentGuides(@NonNull List<? extends IndentGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return;
        setIndentGuides(ProtocolEncoder.packIndentGuides(guides));
    }

    /**
     * Sets indent guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setIndentGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetIndentGuides(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Sets bracket guide list (global replace).
     *
     * @param guides Bracket guide list
     */
    public void setBracketGuides(@NonNull List<? extends BracketGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return;
        setBracketGuides(ProtocolEncoder.packBracketGuides(guides));
    }

    /**
     * Sets bracket guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setBracketGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetBracketGuides(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Sets flow guide list (global replace).
     *
     * @param guides Flow guide list
     */
    public void setFlowGuides(@NonNull List<? extends FlowGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return;
        setFlowGuides(ProtocolEncoder.packFlowGuides(guides));
    }

    /**
     * Sets flow guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setFlowGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetFlowGuides(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Sets separator guide list (global replace).
     *
     * @param guides Separator guide list
     */
    public void setSeparatorGuides(@NonNull List<? extends SeparatorGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return;
        setSeparatorGuides(ProtocolEncoder.packSeparatorGuides(guides));
    }

    /**
     * Sets separator guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setSeparatorGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetSeparatorGuides(mNativeHandle, payload, payload.remaining());
    }

    // ==================== Bracket Pair Highlight ====================

    /**
     * Sets bracket pair list (overrides default (){}[]).
     * @param openChars Open bracket character code array
     * @param closeChars Close bracket character code array
     */
    public void setBracketPairs(int[] openChars, int[] closeChars) {
        if (mNativeHandle == 0) return;
        nativeSetBracketPairs(mNativeHandle, openChars, closeChars);
    }

    /**
     * Sets exact bracket match result externally (overrides built-in character scan).
     */
    public void setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol) {
        if (mNativeHandle == 0) return;
        nativeSetMatchedBrackets(mNativeHandle, openLine, openCol, closeLine, closeCol);
    }

    /**
     * Clears externally set bracket match result (falls back to built-in character scan).
     */
    public void clearMatchedBrackets() {
        if (mNativeHandle == 0) return;
        nativeClearMatchedBrackets(mNativeHandle);
    }

    // ==================== Code Folding ====================

    /**
     * Sets foldable regions using {@link FoldRegion} list (replaces existing list).
     *
     * @param regions Fold region list
     */
    public void setFoldRegions(@NonNull List<? extends FoldRegion> regions) {
        if (mNativeHandle == 0 || regions == null) return;
        setFoldRegions(ProtocolEncoder.packFoldRegions(regions));
    }

    /**
     * Sets foldable region list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    public void setFoldRegions(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return;
        nativeSetFoldRegions(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Toggles fold state of the region containing the specified line.
     *
     * @param line Line number (0-based, usually the fold start line)
     * @return {@code true} if region was found and state was toggled
     */
    public boolean toggleFoldAt(int line) {
        if (mNativeHandle == 0) return false;
        return nativeToggleFoldAt(mNativeHandle, line);
    }

    /**
     * Folds the region containing the specified line.
     *
     * @param line Line number (0-based)
     * @return {@code true} if successfully folded
     */
    public boolean foldAt(int line) {
        if (mNativeHandle == 0) return false;
        return nativeFoldAt(mNativeHandle, line);
    }

    /**
     * Unfolds the region containing the specified line.
     *
     * @param line Line number (0-based)
     * @return {@code true} if successfully unfolded
     */
    public boolean unfoldAt(int line) {
        if (mNativeHandle == 0) return false;
        return nativeUnfoldAt(mNativeHandle, line);
    }

    /** Folds all regions. */
    public void foldAll() {
        if (mNativeHandle == 0) return;
        nativeFoldAll(mNativeHandle);
    }

    /** Unfolds all regions. */
    public void unfoldAll() {
        if (mNativeHandle == 0) return;
        nativeUnfoldAll(mNativeHandle);
    }

    /**
     * Checks if the specified line is visible (not hidden by folding).
     *
     * @param line Line number (0-based)
     * @return {@code true} if visible
     */
    public boolean isLineVisible(int line) {
        if (mNativeHandle == 0) return true;
        return nativeIsLineVisible(mNativeHandle, line);
    }

    // ==================== Linked Editing ====================

    /**
     * Inserts VSCode snippet template and enters linked editing mode.
     *
     * @param snippetTemplate VSCode snippet template (e.g., "for (${1:i}) {\n\t$0\n}")
     * @return Exact change information
     */
    @NonNull
    public TextEditResult insertSnippet(@NonNull String snippetTemplate) {
        if (mNativeHandle == 0) return TextEditResult.EMPTY;
        ByteBuffer data = nativeInsertSnippet(mNativeHandle, snippetTemplate);
        try {
            return ProtocolDecoder.decodeTextEditResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Starts linked editing mode with generic LinkedEditingModel.
     *
     * @param model Linked editing model
     */
    public void startLinkedEditing(@NonNull LinkedEditingModel model) {
        if (mNativeHandle == 0) return;
        ByteBuffer payload = ProtocolEncoder.packLinkedEditingModel(model);
        nativeStartLinkedEditing(mNativeHandle, payload, payload.remaining());
    }

    /**
     * Checks if currently in linked editing mode.
     */
    public boolean isInLinkedEditing() {
        if (mNativeHandle == 0) return false;
        return nativeIsInLinkedEditing(mNativeHandle);
    }

    /**
     * Linked editing: jumps to the next tab stop.
     *
     * @return false if already at end, session ends automatically
     */
    public boolean linkedEditingNext() {
        if (mNativeHandle == 0) return false;
        return nativeLinkedEditingNext(mNativeHandle);
    }

    /**
     * Linked editing: jumps to the previous tab stop.
     *
     * @return false if already at first
     */
    public boolean linkedEditingPrev() {
        if (mNativeHandle == 0) return false;
        return nativeLinkedEditingPrev(mNativeHandle);
    }

    /**
     * Cancels linked editing mode.
     */
    public void cancelLinkedEditing() {
        if (mNativeHandle == 0) return;
        nativeCancelLinkedEditing(mNativeHandle);
    }

    // ==================== Clear Operations ====================

    /** Clears all highlight spans. */
    public void clearHighlights() {
        if (mNativeHandle == 0) return;
        nativeClearHighlights(mNativeHandle);
    }

    /**
     * Clears highlight spans for the specified layer.
     *
     * @param layer Layer 0 / 1
     */
    public void clearHighlights(int layer) {
        if (mNativeHandle == 0) return;
        nativeClearHighlightsLayer(mNativeHandle, layer);
    }

    /** Clears all Inlay Hints. */
    public void clearInlayHints() {
        if (mNativeHandle == 0) return;
        nativeClearInlayHints(mNativeHandle);
    }

    /** Clears all phantom text. */
    public void clearPhantomTexts() {
        if (mNativeHandle == 0) return;
        nativeClearPhantomTexts(mNativeHandle);
    }

    /** Clears all gutter icons. */
    public void clearGutterIcons() {
        if (mNativeHandle == 0) return;
        nativeClearGutterIcons(mNativeHandle);
    }

    /** Clears all code structure guides (indent guides, bracket guides, flow arrows, separators). */
    public void clearGuides() {
        if (mNativeHandle == 0) return;
        nativeClearGuides(mNativeHandle);
    }

    /** Clears all diagnostic decorations. */
    public void clearDiagnostics() {
        if (mNativeHandle == 0) return;
        nativeClearDiagnostics(mNativeHandle);
    }

    /** Clears all decoration data (highlights, Inlay Hints, phantom text, icons, guides, diagnostics). */
    public void clearAllDecorations() {
        if (mNativeHandle == 0) return;
        nativeClearAllDecorations(mNativeHandle);
    }

    // ==================== Inner Classes/Enums ====================

    /** Single text change (exact change info at one edit location, contains only range + newText). */
    public static class TextChange {
        @NonNull
        public final TextRange range;
        @NonNull
        public final String newText;

        public TextChange(@NonNull TextRange range, @NonNull String newText) {
            this.range = range;
            this.newText = newText;
        }

        @NonNull
        @Override
        public String toString() {
            return "TextChange{range=" + range + ", newText=" + newText + '}';
        }
    }

    public static class TextEditResult {
        public final boolean changed;
        @NonNull
        public final java.util.List<TextChange> changes;

        public static final TextEditResult EMPTY = new TextEditResult(false, java.util.Collections.emptyList());

        public TextEditResult(boolean changed, @NonNull java.util.List<TextChange> changes) {
            this.changed = changed;
            this.changes = changes;
        }

        @NonNull
        @Override
        public String toString() {
            return "TextEditResult{changed=" + changed + ", changes=" + changes + '}';
        }
    }

    public static class KeyEventResult {
        public final boolean handled;
        public final boolean contentChanged;
        public final boolean cursorChanged;
        public final boolean selectionChanged;
        @NonNull
        public final TextEditResult editResult;

        public KeyEventResult() {
            this.handled = false;
            this.contentChanged = false;
            this.cursorChanged = false;
            this.selectionChanged = false;
            this.editResult = TextEditResult.EMPTY;
        }

        public KeyEventResult(boolean handled, boolean contentChanged, boolean cursorChanged,
                              boolean selectionChanged, @NonNull TextEditResult editResult) {
            this.handled = handled;
            this.contentChanged = contentChanged;
            this.cursorChanged = cursorChanged;
            this.selectionChanged = selectionChanged;
            this.editResult = editResult;
        }

        @NonNull
        @Override
        public String toString() {
            return "KeyEventResult{handled=" + handled + ", contentChanged=" + contentChanged +
                    ", cursorChanged=" + cursorChanged + ", selectionChanged=" + selectionChanged +
                    ", editResult=" + editResult + '}';
        }
    }

    /** Click hit target types. */
    public enum HitTargetType {
        /**
         * Did not hit any special target
         */
        NONE(0),
        /**
         * Hit InlayHint (text type)
         */
        INLAY_HINT_TEXT(1),
        /**
         * Hit InlayHint (icon type)
         */
        INLAY_HINT_ICON(2),
        /**
         * Hit gutter icon
         */
        GUTTER_ICON(3),
        /**
         * Hit fold placeholder (click to expand fold region)
         */
        FOLD_PLACEHOLDER(4),
        /**
         * Hit fold arrow in gutter (click to toggle fold/expand)
         */
        FOLD_GUTTER(5),
        /**
         * Hit InlayHint (color block type)
         */
        INLAY_HINT_COLOR(6);

        public final int value;

        HitTargetType(int value) {
            this.value = value;
        }

        static HitTargetType fromValue(int value) {
            for (HitTargetType t : values()) {
                if (t.value == value) return t;
            }
            return NONE;
        }
    }

    /** Click hit target information (filled by C++ layer during TAP gestures). */
    public static class HitTarget {
        public static final HitTarget NONE = new HitTarget(HitTargetType.NONE, 0, 0, 0, 0);

        public final HitTargetType type;
        /**
         * Hit logical line number (0-based)
         */
        public final int line;
        /**
         * Hit column number (0-based, only meaningful for InlayHint)
         */
        public final int column;
        /**
         * Icon ID (valid for INLAY_HINT_ICON / GUTTER_ICON)
         */
        public final int iconId;
        /**
         * Color value (ARGB, valid for INLAY_HINT_COLOR)
         */
        public final int colorValue;

        public HitTarget(HitTargetType type, int line, int column, int iconId, int colorValue) {
            this.type = type;
            this.line = line;
            this.column = column;
            this.iconId = iconId;
            this.colorValue = colorValue;
        }

        @NonNull
        @Override
        public String toString() {
            return "HitTarget{type=" + type + ", line=" + line + ", column=" + column + ", iconId=" + iconId + ", colorValue=" + colorValue + '}';
        }
    }

    public enum GestureType {
        UNDEFINED(0),
        TAP(1),
        DOUBLE_TAP(2),
        LONG_PRESS(3),
        SCALE(4),
        SCROLL(5),
        FAST_SCROLL(6),
        DRAG_SELECT(7),
        CONTEXT_MENU(8);

        public final int value;

        GestureType(int value) {
            this.value = value;
        }

        @NonNull
        public static GestureType fromValue(int value) {
            switch (value) {
                case 1:
                    return TAP;
                case 2:
                    return DOUBLE_TAP;
                case 3:
                    return LONG_PRESS;
                case 4:
                    return SCALE;
                case 5:
                    return SCROLL;
                case 6:
                    return FAST_SCROLL;
                case 7:
                    return DRAG_SELECT;
                case 8:
                    return CONTEXT_MENU;
                default:
                    return UNDEFINED;
            }
        }
    }

    public static class GestureResult {
        public final GestureType type;
        public final PointF tapPoint;
        // Editor state after the operation (filled by C++ EditorCore)
        public final TextPosition cursorPosition;
        public final boolean hasSelection;
        public final TextRange selection;
        public final float viewScrollX;
        public final float viewScrollY;
        public final float viewScale;
        /**
         * Click hit target during TAP (InlayHint / GutterIcon)
         */
        public final HitTarget hitTarget;
        /**
         * Whether the platform should start/continue a ~16ms timer calling tickEdgeScroll().
         */
        public final boolean needsEdgeScroll;

        public GestureResult() {
            this.type = GestureType.UNDEFINED;
            this.tapPoint = new PointF();
            this.cursorPosition = TextPosition.NONE;
            this.hasSelection = false;
            this.selection = new TextRange();
            this.viewScrollX = 0;
            this.viewScrollY = 0;
            this.viewScale = 1;
            this.hitTarget = HitTarget.NONE;
            this.needsEdgeScroll = false;
        }

        public GestureResult(GestureType type, PointF tapPoint,
                             TextPosition cursorPosition, boolean hasSelection, TextRange selection,
                             float viewScrollX, float viewScrollY, float viewScale,
                             HitTarget hitTarget, boolean needsEdgeScroll) {
            this.type = type;
            this.tapPoint = tapPoint;
            this.cursorPosition = cursorPosition;
            this.hasSelection = hasSelection;
            this.selection = selection;
            this.viewScrollX = viewScrollX;
            this.viewScrollY = viewScrollY;
            this.viewScale = viewScale;
            this.hitTarget = hitTarget;
            this.needsEdgeScroll = needsEdgeScroll;
        }

        @NonNull
        @Override
        public String toString() {
            return "GestureResult{" +
                    "type=" + type +
                    ", tapPoint=" + tapPoint +
                    ", cursor=" + cursorPosition +
                    ", hasSelection=" + hasSelection +
                    ", viewScroll=(" + viewScrollX + "," + viewScrollY + ")" +
                    ", viewScale=" + viewScale +
                    ", hitTarget=" + hitTarget +
                    '}';
        }
    }

    // ==================== Private Helpers/Internal Implementation ====================

    private static int getEventTypeInt(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                return EVENT_TYPE_TOUCH_DOWN;
            case MotionEvent.ACTION_POINTER_DOWN:
                return EVENT_TYPE_TOUCH_POINTER_DOWN;
            case MotionEvent.ACTION_MOVE:
                return EVENT_TYPE_TOUCH_MOVE;
            case MotionEvent.ACTION_POINTER_UP:
                return EVENT_TYPE_TOUCH_POINTER_UP;
            case MotionEvent.ACTION_UP:
                return EVENT_TYPE_TOUCH_UP;
            case MotionEvent.ACTION_CANCEL:
                return EVENT_TYPE_TOUCH_CANCEL;
            default:
                return EVENT_TYPE_UNDEFINED;
        }
    }

    // ==================== Native Method Declarations ====================

    @FastNative
    private static native long nativeMakeEditorCore(TextMeasurer measurer, ByteBuffer optionsData, int optionsSize);

    @CriticalNative
    private static native void nativeFinalizeEditorCore(long handle);

    @CriticalNative
    private static native void nativeSetViewport(long handle, int width, int height);

    @CriticalNative
    private static native void nativeLoadDocument(long handle, long documentHandle);

    @CriticalNative
    private static native void nativeResetMeasurer(long handle);

    @CriticalNative
    private static native void nativeSetFoldArrowMode(long handle, int mode);

    @CriticalNative
    private static native void nativeSetWrapMode(long handle, int mode);

    @CriticalNative
    private static native void nativeSetScale(long handle, float scale);

    @CriticalNative
    private static native void nativeSetLineSpacing(long handle, float add, float mult);

    @CriticalNative
    private static native void nativeSetContentStartPadding(long handle, float padding);

    @CriticalNative
    private static native void nativeSetShowSplitLine(long handle, boolean show);

    @CriticalNative
    private static native void nativeSetCurrentLineRenderMode(long handle, int mode);

    @FastNative
    private static native ByteBuffer nativeBuildRenderModel(long handle);

    @FastNative
    private static native ByteBuffer nativeHandleGestureEvent(long handle, int type, int pointerCount, float[] points);

    @FastNative
    private static native ByteBuffer nativeTickEdgeScroll(long handle);

    @FastNative
    private static native ByteBuffer nativeHandleKeyEvent(long handle, int keyCode, String text, int modifiers);

    @FastNative
    private static native ByteBuffer nativeInsertText(long handle, String text);

    @FastNative
    private static native ByteBuffer nativeReplaceText(long handle,
            int startLine, int startColumn, int endLine, int endColumn, String text);

    @FastNative
    private static native ByteBuffer nativeDeleteText(long handle,
            int startLine, int startColumn, int endLine, int endColumn);

    @FastNative
    private static native ByteBuffer nativeMoveLineUp(long handle);

    @FastNative
    private static native ByteBuffer nativeMoveLineDown(long handle);

    @FastNative
    private static native ByteBuffer nativeCopyLineUp(long handle);

    @FastNative
    private static native ByteBuffer nativeCopyLineDown(long handle);

    @FastNative
    private static native ByteBuffer nativeDeleteLine(long handle);

    @FastNative
    private static native ByteBuffer nativeInsertLineAbove(long handle);

    @FastNative
    private static native ByteBuffer nativeInsertLineBelow(long handle);

    @FastNative
    private static native ByteBuffer nativeUndo(long handle);

    @FastNative
    private static native ByteBuffer nativeRedo(long handle);

    @CriticalNative
    private static native boolean nativeCanUndo(long handle);

    @CriticalNative
    private static native boolean nativeCanRedo(long handle);

    @CriticalNative
    private static native long nativeGetCursorPosition(long handle);

    @FastNative
    private static native long[] nativeGetWordRangeAtCursor(long handle);

    @FastNative
    private static native String nativeGetWordAtCursor(long handle);

    @CriticalNative
    private static native void nativeSetCursorPosition(long handle, int line, int column);

    @CriticalNative
    private static native void nativeSelectAll(long handle);

    @CriticalNative
    private static native void nativeSetSelection(long handle, int startLine, int startColumn, int endLine, int endColumn);

    @FastNative
    private static native long[] nativeGetSelection(long handle);

    @FastNative
    private static native String nativeGetSelectedText(long handle);

    @CriticalNative
    private static native void nativeCompositionStart(long handle);

    @FastNative
    private static native void nativeCompositionUpdate(long handle, String text);

    @FastNative
    private static native ByteBuffer nativeCompositionEnd(long handle, String committedText);

    @CriticalNative
    private static native void nativeCompositionCancel(long handle);

    @CriticalNative
    private static native boolean nativeIsComposing(long handle);

    @CriticalNative
    private static native void nativeSetCompositionEnabled(long handle, boolean enabled);

    @CriticalNative
    private static native boolean nativeIsCompositionEnabled(long handle);

    @CriticalNative
    private static native void nativeSetReadOnly(long handle, boolean readOnly);

    @CriticalNative
    private static native boolean nativeIsReadOnly(long handle);

    @CriticalNative
    private static native void nativeSetAutoIndentMode(long handle, int mode);

    @CriticalNative
    private static native int nativeGetAutoIndentMode(long handle);

    @CriticalNative
    private static native void nativeSetHandleConfig(long handle, float radius, float centerDist, float lineWidth, float touchPadding, float dragYOffset);

    @CriticalNative
    private static native void nativeSetScrollbarConfig(long handle, float thickness, float minThumb, float thumbHitPadding,
                                                        int mode, boolean thumbDraggable, int trackTapMode,
                                                        int fadeDelayMs, int fadeDurationMs);

    @FastNative
    private static native float[] nativeGetPositionRect(long handle, int line, int column);

    @FastNative
    private static native float[] nativeGetCursorRect(long handle);

    @CriticalNative
    private static native void nativeScrollToLine(long handle, int line, int behavior);

    @CriticalNative
    private static native void nativeGotoPosition(long handle, int line, int column);

    @CriticalNative
    private static native void nativeSetScroll(long handle, float scrollX, float scrollY);

    @FastNative
    private static native ByteBuffer nativeGetScrollMetrics(long handle);

    @CriticalNative
    private static native void nativeRegisterTextStyle(long handle, int styleId, int color, int backgroundColor, int fontStyle);

    @FastNative
    private static native void nativeSetLineSpans(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetLineInlayHints(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetLinePhantomTexts(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetLineGutterIcons(long handle, ByteBuffer data, int size);

    @CriticalNative
    private static native void nativeSetMaxGutterIcons(long handle, int count);

    @FastNative
    private static native void nativeSetLineDiagnostics(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBatchLineSpans(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBatchLineInlayHints(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBatchLinePhantomTexts(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBatchLineGutterIcons(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBatchLineDiagnostics(long handle, ByteBuffer data, int size);

    @CriticalNative
    private static native void nativeClearDiagnostics(long handle);

    @FastNative
    private static native void nativeSetIndentGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBracketGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetFlowGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetSeparatorGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native void nativeSetBracketPairs(long handle, int[] openChars, int[] closeChars);

    @CriticalNative
    private static native void nativeSetMatchedBrackets(long handle, int openLine, int openCol, int closeLine, int closeCol);

    @CriticalNative
    private static native void nativeClearMatchedBrackets(long handle);

    @FastNative
    private static native void nativeSetFoldRegions(long handle, ByteBuffer data, int size);

    @CriticalNative
    private static native boolean nativeToggleFoldAt(long handle, int line);

    @CriticalNative
    private static native boolean nativeFoldAt(long handle, int line);

    @CriticalNative
    private static native boolean nativeUnfoldAt(long handle, int line);

    @CriticalNative
    private static native void nativeFoldAll(long handle);

    @CriticalNative
    private static native void nativeUnfoldAll(long handle);

    @CriticalNative
    private static native boolean nativeIsLineVisible(long handle, int line);

    @CriticalNative
    private static native void nativeClearHighlights(long handle);

    @CriticalNative
    private static native void nativeClearHighlightsLayer(long handle, int layer);

    @CriticalNative
    private static native void nativeClearInlayHints(long handle);

    @CriticalNative
    private static native void nativeClearPhantomTexts(long handle);

    @CriticalNative
    private static native void nativeClearGutterIcons(long handle);

    @CriticalNative
    private static native void nativeClearGuides(long handle);

    @CriticalNative
    private static native void nativeClearAllDecorations(long handle);

    @FastNative
    private static native ByteBuffer nativeInsertSnippet(long handle, String snippetTemplate);

    @FastNative
    private static native void nativeStartLinkedEditing(long handle, ByteBuffer data, int size);

    @CriticalNative
    private static native boolean nativeIsInLinkedEditing(long handle);

    @CriticalNative
    private static native boolean nativeLinkedEditingNext(long handle);

    @CriticalNative
    private static native boolean nativeLinkedEditingPrev(long handle);

    @CriticalNative
    private static native void nativeCancelLinkedEditing(long handle);

    @FastNative
    private static native void nativeFreeBinaryData(@Nullable ByteBuffer data);

    static {
        System.loadLibrary("sweeteditor");
    }
}

