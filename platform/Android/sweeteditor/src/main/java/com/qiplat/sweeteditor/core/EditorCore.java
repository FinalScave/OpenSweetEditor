package com.qiplat.sweeteditor.core;

import android.graphics.PointF;
import android.util.SparseArray;
import android.view.KeyEvent;
import android.view.MotionEvent;

import androidx.annotation.NonNull;
import androidx.annotation.MainThread;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.adornment.CodeLensItem;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.LinkSpan;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.keymap.KeyMap;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.visual.CursorRect;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.core.visual.LayoutMetrics;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.adornment.TextStyle;

import java.nio.ByteBuffer;
import java.util.List;
import java.util.Map;

import dalvik.annotation.optimization.CriticalNative;
import dalvik.annotation.optimization.FastNative;

/**
 * Core editor interface that directly bridges to the C++ layer API.
 * <p>
 * Encapsulates all low-level functionalities including text editing, cursor management,
 * selection operations, gesture/keyboard event handling, code folding, and diagnostic
 * decorations through JNI bridging.
 * Unless otherwise noted, public APIs on this class are main-thread only.
 *
 * @author Scave
 */
@MainThread
public class EditorCore {

    public static final int EVENT_TYPE_UNDEFINED = 0;
    public static final int EVENT_TYPE_TOUCH_DOWN = 1;
    public static final int EVENT_TYPE_TOUCH_POINTER_DOWN = 2;
    public static final int EVENT_TYPE_TOUCH_MOVE = 3;
    public static final int EVENT_TYPE_TOUCH_POINTER_UP = 4;
    public static final int EVENT_TYPE_TOUCH_UP = 5;
    public static final int EVENT_TYPE_TOUCH_CANCEL = 6;
    public static final int EVENT_TYPE_MOUSE_DOWN = 7;
    public static final int EVENT_TYPE_MOUSE_MOVE = 8;
    public static final int EVENT_TYPE_MOUSE_UP = 9;
    public static final int EVENT_TYPE_MOUSE_WHEEL = 10;
    public static final int EVENT_TYPE_MOUSE_RIGHT_DOWN = 11;
    public static final int EVENT_TYPE_DIRECT_SCALE = 12;
    public static final int EVENT_TYPE_DIRECT_SCROLL = 13;

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

    @NonNull
    public EditorActionResult loadDocument(Document document) {
        if (mNativeHandle == 0) {
            return EditorActionResult.EMPTY;
        }
        mDocument = document;
        return decodeAction(nativeLoadDocument(mNativeHandle, document.mNativeHandle));
    }

    /**
     * Gets the currently loaded document instance.
     */
    @Nullable
    public Document getDocument() {
        return mDocument;
    }

    // ==================== Viewport/Font/Appearance Configuration ====================

    @NonNull
    public EditorActionResult setViewport(int width, int height) {
        if (mNativeHandle == 0) {
            return EditorActionResult.EMPTY;
        }
        return decodeAction(nativeSetViewport(mNativeHandle, width, height));
    }

    @NonNull
    public EditorActionResult onFontMetricsChanged() {
        if (mNativeHandle == 0) {
            return EditorActionResult.EMPTY;
        }
        return decodeAction(nativeOnFontMetricsChanged(mNativeHandle));
    }

    /**
     * Sets the fold arrow display mode (affects gutter width reservation).
     *
     * @param mode 0=AUTO (auto show when fold regions exist), 1=ALWAYS (always reserve), 2=HIDDEN (always hide)
     */
    @NonNull
    public EditorActionResult setFoldArrowMode(int mode) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetFoldArrowMode(mNativeHandle, mode));
    }

    /**
     * Sets the auto wrap mode.
     *
     * @param mode 0=NONE (no wrap), 1=CHAR_BREAK (character-level wrap), 2=WORD_BREAK (word-level wrap)
     */
    @NonNull
    public EditorActionResult setWrapMode(int mode) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetWrapMode(mNativeHandle, mode));
    }

    /**
     * Sets the tab size (number of spaces per tab stop).
     *
     * @param tabSize tab size (default 4, minimum 1)
     */
    @NonNull
    public EditorActionResult setTabSize(int tabSize) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetTabSize(mNativeHandle, tabSize));
    }

    /**
     * Sets the editor scale factor.
     *
     * @param scale scale factor (1.0 = 100%)
     */
    @NonNull
    public EditorActionResult setScale(float scale) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetScale(mNativeHandle, scale));
    }

    /**
     * Sets line spacing parameters (formula: line_height = font_height * mult + add).
     *
     * @param add  Extra line spacing in pixels (default 0)
     * @param mult Line spacing multiplier (default 1.0)
     */
    @NonNull
    public EditorActionResult setLineSpacing(float add, float mult) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineSpacing(mNativeHandle, add, mult));
    }

    /**
     * Sets extra horizontal padding between gutter split and text content start.
     *
     * @param padding padding in pixels (clamped to >= 0 on native side)
     */
    @NonNull
    public EditorActionResult setContentStartPadding(float padding) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetContentStartPadding(mNativeHandle, padding));
    }

    /**
     * Sets whether gutter split line should be rendered.
     *
     * @param show true to show split line, false to hide
     */
    @NonNull
    public EditorActionResult setShowSplitLine(boolean show) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetShowSplitLine(mNativeHandle, show));
    }

    /**
     * Sets whether gutter stays fixed during horizontal scroll.
     *
     * @param sticky true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style)
     */
    @NonNull
    public EditorActionResult setGutterSticky(boolean sticky) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetGutterSticky(mNativeHandle, sticky));
    }

    /**
     * Sets whether gutter area is visible.
     *
     * @param visible true=show gutter (line numbers, icons, fold arrows), false=hide entire gutter
     */
    @NonNull
    public EditorActionResult setGutterVisible(boolean visible) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetGutterVisible(mNativeHandle, visible));
    }

    /**
     * Sets current line render mode.
     *
     * @param mode 0=BACKGROUND(fill), 1=BORDER(stroke), 2=NONE(disabled)
     */
    @NonNull
    public EditorActionResult setCurrentLineRenderMode(int mode) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetCurrentLineRenderMode(mNativeHandle, mode));
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

    @Nullable
    public LayoutMetrics getLayoutMetrics() {
        if (mNativeHandle == 0) return null;
        ByteBuffer data = nativeGetLayoutMetrics(mNativeHandle);
        try {
            return ProtocolDecoder.decodeLayoutMetrics(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    private EditorActionResult decodeAction(@Nullable ByteBuffer data) {
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Gesture/Keyboard Event Handling ====================

    public EditorActionResult handleGestureEvent(MotionEvent event) {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        int eventType = getEventTypeInt(event);
        int pointerCount = event.getPointerCount();
        float[] points = new float[pointerCount * 2];
        for (int i = 0; i < pointerCount; i++) {
            points[i * 2] = event.getX(i);
            points[i * 2 + 1] = event.getY(i);
        }
        ByteBuffer data = nativeHandleGestureEventEx(
                mNativeHandle,
                eventType,
                pointerCount,
                points,
                getMotionEventModifiers(event),
                0f,
                0f,
                1f);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    public EditorActionResult handleGestureEventEx(int eventType,
                                              @Nullable PointF[] points,
                                              int modifiers,
                                              float wheelDeltaX,
                                              float wheelDeltaY,
                                              float directScale) {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        int pointerCount = points != null ? points.length : 0;
        float[] packedPoints = null;
        if (pointerCount > 0) {
            packedPoints = new float[pointerCount * 2];
            for (int i = 0; i < pointerCount; i++) {
                PointF point = points[i];
                packedPoints[i * 2] = point != null ? point.x : 0f;
                packedPoints[i * 2 + 1] = point != null ? point.y : 0f;
            }
        }
        ByteBuffer data = nativeHandleGestureEventEx(
                mNativeHandle,
                eventType,
                pointerCount,
                packedPoints,
                modifiers,
                wheelDeltaX,
                wheelDeltaY,
                directScale);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    public EditorActionResult updatePointerModifiers(int modifiers) {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        return decodeAction(nativeUpdatePointerModifiers(mNativeHandle, modifiers));
    }

    /**
     * Tick edge-scroll during drag selection / handle drag.
     * Call at ~16ms intervals while the previous EditorActionResult.needsEdgeScroll was true.
     */
    public EditorActionResult tickEdgeScroll() {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        ByteBuffer data = nativeTickEdgeScroll(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Tick fling (inertial scroll) animation.
     * Call at ~16ms intervals while the previous EditorActionResult.needsFling was true.
     */
    public EditorActionResult tickFling() {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        ByteBuffer data = nativeTickFling(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Unified animation tick: advances all active animations (edge-scroll, fling).
     * Platform can use a single frame callback driven by EditorActionResult.needsAnimation.
     */
    public EditorActionResult tickAnimations() {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        ByteBuffer data = nativeTickAnimations(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    public EditorActionResult handleKeyEvent(int keyCode, String text, int modifiers) {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        ByteBuffer data = nativeHandleKeyEvent(mNativeHandle, keyCode, text, modifiers);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult setKeyMap(@NonNull ByteBuffer data) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetKeyMap(mNativeHandle, data));
    }

    @NonNull
    public EditorActionResult setKeyMap(@NonNull KeyMap keyMap) {
        return setKeyMap(ProtocolEncoder.packKeyMap(keyMap));
    }

    // ==================== Text Editing ====================

    @NonNull
    public EditorActionResult insertText(String text) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeInsertText(mNativeHandle, text);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
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
    public EditorActionResult replaceText(@NonNull TextRange range, @NonNull String newText) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeReplaceText(mNativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column, newText);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
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
    public EditorActionResult deleteText(@NonNull TextRange range) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeDeleteText(mNativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Line Operations ====================

    @NonNull
    public EditorActionResult moveLineUp() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeMoveLineUp(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult moveLineDown() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeMoveLineDown(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult copyLineUp() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeCopyLineUp(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult copyLineDown() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeCopyLineDown(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult deleteLine() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeDeleteLine(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult insertLineAbove() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeInsertLineAbove(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult insertLineBelow() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeInsertLineBelow(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Undo/Redo ====================

    @NonNull
    public EditorActionResult undo() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeUndo(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult redo() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeRedo(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
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

    @NonNull
    public EditorActionResult moveCursorLeft(boolean extendSelection) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeMoveCursorLeft(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorRight(boolean extendSelection) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeMoveCursorRight(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorUp(boolean extendSelection) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeMoveCursorUp(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorDown(boolean extendSelection) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeMoveCursorDown(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorToLineStart(boolean extendSelection) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeMoveCursorToLineStart(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorToLineEnd(boolean extendSelection) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeMoveCursorToLineEnd(mNativeHandle, extendSelection));
    }

    /**
     * Sets the cursor position (does not scroll viewport, only moves cursor).
     *
     * @param position Target position
     */
    @NonNull
    public EditorActionResult setCursorPosition(@NonNull TextPosition position) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetCursorPosition(mNativeHandle, position.line, position.column));
    }

    /** Selects all document content. */
    @NonNull
    public EditorActionResult selectAll() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSelectAll(mNativeHandle));
    }

    /**
     * Sets the selection range.
     *
     * @param startLine   Selection start line (0-based)
     * @param startColumn Selection start column (0-based)
     * @param endLine     Selection end line (0-based)
     * @param endColumn   Selection end column (0-based)
     */
    @NonNull
    public EditorActionResult setSelection(int startLine, int startColumn, int endLine, int endColumn) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetSelection(mNativeHandle, startLine, startColumn, endLine, endColumn));
    }

    /**
     * Sets the selection range.
     *
     * @param range Selection range
     */
    @NonNull
    public EditorActionResult setSelection(@NonNull TextRange range) {
        return setSelection(range.start.line, range.start.column, range.end.line, range.end.column);
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

    public boolean isComposing() {
        if (mNativeHandle == 0) return false;
        return nativeIsComposing(mNativeHandle);
    }

    @Nullable
    public TextRange getComposingRange() {
        if (mNativeHandle == 0) return null;
        long[] vals = nativeGetComposingRange(mNativeHandle);
        if (vals == null || vals[0] == -1) return null;
        return new TextRange(
                new TextPosition((int) vals[0], (int) vals[1]),
                new TextPosition((int) vals[2], (int) vals[3])
        );
    }

    @Nullable
    public TextRange getComposingSessionRange() {
        if (mNativeHandle == 0) return null;
        long[] vals = nativeGetComposingSessionRange(mNativeHandle);
        if (vals == null || vals[0] == -1) return null;
        return new TextRange(
                new TextPosition((int) vals[0], (int) vals[1]),
                new TextPosition((int) vals[2], (int) vals[3])
        );
    }

    @NonNull
    public EditorActionResult updateImePreedit(@Nullable String text, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeUpdatePreedit(mNativeHandle, text != null ? text : "", scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult setImeComposingText(@Nullable String text, int cursorOffset, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeSetComposingText(mNativeHandle, text != null ? text : "", cursorOffset, scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult commitImeText(@Nullable String text, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeCommitText(mNativeHandle, text != null ? text : "", scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult finishImePreedit() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeFinishPreedit(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult cancelImePreedit() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeCancelPreedit(mNativeHandle);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult markImeDocumentRange(@NonNull TextRange range, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeMarkDocumentRange(
                mNativeHandle,
                range.start.line,
                range.start.column,
                range.end.line,
                range.end.column,
                scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult markImeDocumentRange(long startOffset, long endOffset, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeMarkDocumentRangeByOffset(mNativeHandle, startOffset, endOffset, scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult replaceImeText(@NonNull TextRange range,
                                          @Nullable String text,
                                          int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeReplaceText(
                mNativeHandle,
                range.start.line,
                range.start.column,
                range.end.line,
                range.end.column,
                text != null ? text : "",
                scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult replaceImeDocumentText(long startOffset,
                                                  long endOffset,
                                                  @Nullable String text,
                                                  int cursorOffset,
                                                  int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeReplaceDocumentText(
                mNativeHandle,
                startOffset,
                endOffset,
                text != null ? text : "",
                cursorOffset,
                scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult replaceImeInputContextText(long startOffset,
                                                      long endOffset,
                                                      @Nullable String text,
                                                      int cursorOffset,
                                                      int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeReplaceInputContextText(
                mNativeHandle,
                startOffset,
                endOffset,
                text != null ? text : "",
                cursorOffset,
                scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult markImeInputContextRange(long startOffset, long endOffset, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeMarkInputContextRange(mNativeHandle, startOffset, endOffset, scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult notifyImeDocumentSelectionChanged(long startOffset, long endOffset) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeNotifyDocumentSelectionChanged(mNativeHandle, startOffset, endOffset);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult notifyImeInputContextSelectionChanged(long startOffset, long endOffset) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeNotifyInputContextSelectionChanged(mNativeHandle, startOffset, endOffset);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult updateImeInputStateText(long contextId,
                                                   int documentStartOffset,
                                                   @Nullable String text,
                                                   int selectionStartOffset,
                                                   int selectionEndOffset,
                                                   int composingStartOffset,
                                                   int composingEndOffset,
                                                   int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeUpdateInputStateText(
                mNativeHandle,
                contextId,
                documentStartOffset,
                text != null ? text : "",
                selectionStartOffset,
                selectionEndOffset,
                composingStartOffset,
                composingEndOffset,
                scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult updateImeInputStateSelection(long contextId,
                                                        int documentStartOffset,
                                                        int selectionStartOffset,
                                                        int selectionEndOffset) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeUpdateInputStateSelection(
                mNativeHandle,
                contextId,
                documentStartOffset,
                selectionStartOffset,
                selectionEndOffset);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult replaceImeInputStateText(long contextId,
                                                    int documentStartOffset,
                                                    long startOffset,
                                                    long endOffset,
                                                    @Nullable String text,
                                                    int cursorOffset,
                                                    int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeReplaceInputStateText(
                mNativeHandle,
                contextId,
                documentStartOffset,
                startOffset,
                endOffset,
                text != null ? text : "",
                cursorOffset,
                scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult deleteImeBackward(long beforeLength, int textUnit) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeDeleteBackward(mNativeHandle, beforeLength, textUnit);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult deleteImeForward(long afterLength, int textUnit) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeDeleteForward(mNativeHandle, afterLength, textUnit);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult deleteImeSurrounding(long beforeLength, long afterLength, int textUnit) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeDeleteSurrounding(mNativeHandle, beforeLength, afterLength, textUnit);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult commitImeText(@Nullable String text, int cursorOffset, int scriptHint) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeCommitTextWithCursor(mNativeHandle, text != null ? text : "", cursorOffset, scriptHint);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult notifyImeSelectionChanged(@NonNull TextRange range) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeNotifySelectionChanged(
                mNativeHandle,
                range.start.line,
                range.start.column,
                range.end.line,
                range.end.column);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult notifyImeCursorChanged(@NonNull TextPosition cursor) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeImeNotifyCursorChanged(
                mNativeHandle,
                cursor.line,
                cursor.column);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult setImeKeyboardScriptClass(int scriptClass) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeImeSetKeyboardScriptClass(mNativeHandle, scriptClass));
    }

    public int getImeKeyboardScriptClass() {
        if (mNativeHandle == 0) return ImeScriptClass.UNKNOWN;
        return nativeImeGetKeyboardScriptClass(mNativeHandle);
    }

    @NonNull
    public ImeSyncSnapshot getImeSyncSnapshot() {
        if (mNativeHandle == 0) return new ImeSyncSnapshot();
        ByteBuffer data = nativeGetImeSyncSnapshot(mNativeHandle);
        try {
            return ProtocolDecoder.decodeImeSyncSnapshot(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public ImeInputContext getImeInputContext(long beforeLength, long afterLength) {
        if (mNativeHandle == 0) return new ImeInputContext();
        ByteBuffer data = nativeGetImeInputContext(mNativeHandle, beforeLength, afterLength);
        try {
            return ProtocolDecoder.decodeImeInputContext(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Read-Only Mode ====================

    /**
     * Sets read-only mode.
     *
     * @param readOnly {@code true}=read-only (blocks all edit operations), {@code false}=editable
     */
    @NonNull
    public EditorActionResult setReadOnly(boolean readOnly) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetReadOnly(mNativeHandle, readOnly));
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
    @NonNull
    public EditorActionResult setAutoIndentMode(int mode) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetAutoIndentMode(mNativeHandle, mode));
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

    /**
     * Sets backspace unindent behavior.
     *
     * @param enabled true=enabled, false=disabled
     */
    @NonNull
    public EditorActionResult setBackspaceUnindent(boolean enabled) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBackspaceUnindent(mNativeHandle, enabled));
    }

    /**
     * Sets whether Tab inserts spaces up to the next tab stop instead of a literal tab.
     *
     * @param enabled true=insert spaces, false=insert '\t'
     */
    @NonNull
    public EditorActionResult setInsertSpaces(boolean enabled) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetInsertSpaces(mNativeHandle, enabled));
    }

    // ==================== Handle Config ==

    /**
     * Sets the selection handle appearance and touch configuration.
     * Hit offset rects are passed to C++ core for touch detection.
     *
     * @param config HandleConfig instance
     */
    @NonNull
    public EditorActionResult setHandleConfig(HandleConfig config) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        mHandleConfig = config;
        return decodeAction(nativeSetHandleConfig(mNativeHandle,
                config.startHitOffset.left, config.startHitOffset.top,
                config.startHitOffset.right, config.startHitOffset.bottom,
                config.endHitOffset.left, config.endHitOffset.top,
                config.endHitOffset.right, config.endHitOffset.bottom));
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
    @NonNull
    public EditorActionResult setScrollbarConfig(ScrollbarConfig config) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        mScrollbarConfig = config;
        return decodeAction(nativeSetScrollbarConfig(
                mNativeHandle,
                config.thickness,
                config.minThumb,
                config.thumbHitPadding,
                config.mode.value,
                config.thumbDraggable,
                config.trackTapMode.value,
                config.fadeDelayMs,
                config.fadeDurationMs));
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
    @NonNull
    public EditorActionResult scrollToLine(int line, int behavior) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeScrollToLine(mNativeHandle, line, behavior));
    }

    /**
     * Goes to the specified line and column (scroll + cursor positioning).
     *
     * @param line   Line number (0-based)
     * @param column Column number (0-based)
     */
    @NonNull
    public EditorActionResult gotoPosition(int line, int column) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeGotoPosition(mNativeHandle, line, column));
    }

    /**
     * Adjusts scroll offset just enough to keep the current cursor visible in the viewport.
     */
    @NonNull
    public EditorActionResult ensureCursorVisible() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeEnsureCursorVisible(mNativeHandle));
    }

    /**
     * Manually sets the scroll position (automatically clamped to valid range).
     */
    @NonNull
    public EditorActionResult setScroll(float scrollX, float scrollY) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetScroll(mNativeHandle, scrollX, scrollY));
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

    @NonNull
    public IntRange getVisibleLineRange() {
        if (mNativeHandle == 0) {
            return new IntRange(0, -1);
        }
        int[] visible = nativeGetVisibleLineRange(mNativeHandle);
        if (visible == null || visible.length < 2) {
            return new IntRange(0, -1);
        }
        return new IntRange(visible[0], visible[1]);
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
    @NonNull
    public EditorActionResult registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeRegisterTextStyle(mNativeHandle, styleId, color, backgroundColor, fontStyle));
    }

    /**
     * Registers a highlight style (without background color, backward compatible).
     *
     * @param styleId   Style ID
     * @param color     ARGB color value
     * @param fontStyle Font style bit flags
     */
    @NonNull
    public EditorActionResult registerTextStyle(int styleId, int color, int fontStyle) {
        return registerTextStyle(styleId, color, 0, fontStyle);
    }

    /**
     * Registers multiple highlight styles in one JNI call.
     *
     * @param stylesById style ID -> style mapping
     */
    @NonNull
    public EditorActionResult registerBatchTextStyles(@Nullable Map<Integer, TextStyle> stylesById) {
        if (mNativeHandle == 0 || stylesById == null || stylesById.isEmpty()) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchTextStyles(stylesById);
        return registerBatchTextStyles(payload);
    }

    /**
     * Registers multiple highlight styles in one JNI call (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult registerBatchTextStyles(@Nullable ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeRegisterBatchTextStyles(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets highlight spans for the specified line.
     *
     * @param line        Line number (0-based)
     * @param layer       Highlight layer (0=SYNTAX, 1=SEMANTIC)
     * @param styleSpans Span highlight sequence
     */
    @NonNull
    public EditorActionResult setLineSpans(int line, int layer, List<? extends StyleSpan> styleSpans) {
        if (mNativeHandle == 0 || styleSpans == null) return EditorActionResult.EMPTY;
        return setLineSpans(ProtocolEncoder.packLineSpans(line, layer, styleSpans));
    }



    /**
     * Sets highlight spans for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer (format: line, layer, count, repeated col, len, style)
     */
    @NonNull
    public EditorActionResult setLineSpans(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineSpans(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets highlight spans for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param layer       Highlight layer (0=SYNTAX, 1=SEMANTIC)
     * @param spansByLine Sparse array of line to span list
     */
    @NonNull
    public EditorActionResult setBatchLineSpans(int layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine) {
        if (mNativeHandle == 0 || spansByLine == null || spansByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLineSpans(layer, spansByLine);
        return setBatchLineSpans(payload);
    }

    /**
     * Batch sets highlight spans for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineSpans(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLineSpans(mNativeHandle, payload, payload.remaining()));
    }

    // ==================== InlayHint / PhantomText ====================

    /**
     * Batch sets Inlay Hints for the specified lines.
     *
     * @param line  Line number (0-based)
     * @param hints InlayHint list
     */
    @NonNull
    public EditorActionResult setLineInlayHints(int line, @NonNull List<? extends InlayHint> hints) {
        ByteBuffer payload = ProtocolEncoder.packLineInlayHints(line, hints);
        return setLineInlayHints(payload);
    }

    /**
     * Batch sets Inlay Hints for the specified lines (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setLineInlayHints(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineInlayHints(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets Inlay Hints for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param hintsByLine Sparse array of line to hint list
     */
    @NonNull
    public EditorActionResult setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine) {
        if (mNativeHandle == 0 || hintsByLine == null || hintsByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLineInlayHints(hintsByLine);
        return setBatchLineInlayHints(payload);
    }

    /**
     * Batch sets Inlay Hints for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineInlayHints(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLineInlayHints(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets phantom text for the specified line (replaces entire line).
     *
     * @param line     Line number (0-based)
     * @param phantoms Phantom text list (already sorted by column ascending)
     */
    @NonNull
    public EditorActionResult setLinePhantomTexts(int line, @NonNull List<? extends PhantomText> phantoms) {
        if (mNativeHandle == 0 || phantoms == null) return EditorActionResult.EMPTY;
        return setLinePhantomTexts(ProtocolEncoder.packLinePhantomTexts(line, phantoms));
    }

    /**
     * Sets phantom text for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setLinePhantomTexts(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLinePhantomTexts(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets phantom text for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param phantomsByLine Sparse array of line to phantom list
     */
    @NonNull
    public EditorActionResult setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        if (mNativeHandle == 0 || phantomsByLine == null || phantomsByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLinePhantomTexts(phantomsByLine);
        return setBatchLinePhantomTexts(payload);
    }

    /**
     * Batch sets phantom text for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLinePhantomTexts(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLinePhantomTexts(mNativeHandle, payload, payload.remaining()));
    }

    // ==================== Gutter Icons ====================

    /**
     * Sets gutter icons for the specified line (replaces entire line).
     *
     * @param line  Line number (0-based)
     * @param icons Icon list
     */
    @NonNull
    public EditorActionResult setLineGutterIcons(int line, @NonNull List<? extends GutterIcon> icons) {
        if (mNativeHandle == 0 || icons == null) return EditorActionResult.EMPTY;
        return setLineGutterIcons(ProtocolEncoder.packLineGutterIcons(line, icons));
    }

    /**
     * Sets gutter icons for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setLineGutterIcons(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineGutterIcons(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets gutter icons for multiple lines (reduces JNI calls).
     *
     * @param iconsByLine Sparse array of line to icon list
     */
    @NonNull
    public EditorActionResult setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine) {
        if (mNativeHandle == 0 || iconsByLine == null || iconsByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLineGutterIcons(iconsByLine);
        return setBatchLineGutterIcons(payload);
    }

    /**
     * Batch sets gutter icons for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineGutterIcons(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLineGutterIcons(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets the maximum number of gutter icons (affects gutter width reservation).
     * <p>Icon width = line height, gutter will reserve space for count icons after setting this.
     *
     * @param count Maximum icon count (0=no reservation, default 0)
     */
    @NonNull
    public EditorActionResult setMaxGutterIcons(int count) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetMaxGutterIcons(mNativeHandle, count));
    }

    // ==================== Diagnostic Decorations ====================

    /**
     * Sets diagnostic decorations for the specified line.
     *
     * @param line  Line number (0-based)
     * @param items Diagnostic item list
     */
    @NonNull
    public EditorActionResult setLineDiagnostics(int line, @NonNull List<? extends Diagnostic> items) {
        if (mNativeHandle == 0 || items == null) return EditorActionResult.EMPTY;
        return setLineDiagnostics(ProtocolEncoder.packLineDiagnostics(line, items));
    }

    /**
     * Sets diagnostic decorations for the specified line (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer (format: line, count, repeated col, len, severity, color)
     */
    @NonNull
    public EditorActionResult setLineDiagnostics(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineDiagnostics(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets diagnostic decorations for multiple lines (reduces JNI calls).
     *
     * @param diagsByLine Sparse array of line to diagnostic list
     */
    @NonNull
    public EditorActionResult setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> diagsByLine) {
        if (mNativeHandle == 0 || diagsByLine == null || diagsByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLineDiagnostics(diagsByLine);
        return setBatchLineDiagnostics(payload);
    }

    /**
     * Batch sets diagnostic decorations for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineDiagnostics(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLineDiagnostics(mNativeHandle, payload, payload.remaining()));
    }

    // ==================== Guide (Code Structure Lines) ====================

    /**
     * Sets indent guide list (global replace).
     *
     * @param guides Indent guide list
     */
    @NonNull
    public EditorActionResult setIndentGuides(@NonNull List<? extends IndentGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return EditorActionResult.EMPTY;
        return setIndentGuides(ProtocolEncoder.packIndentGuides(guides));
    }

    /**
     * Sets indent guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setIndentGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetIndentGuides(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets bracket guide list (global replace).
     *
     * @param guides Bracket guide list
     */
    @NonNull
    public EditorActionResult setBracketGuides(@NonNull List<? extends BracketGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return EditorActionResult.EMPTY;
        return setBracketGuides(ProtocolEncoder.packBracketGuides(guides));
    }

    /**
     * Sets bracket guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBracketGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBracketGuides(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets flow guide list (global replace).
     *
     * @param guides Flow guide list
     */
    @NonNull
    public EditorActionResult setFlowGuides(@NonNull List<? extends FlowGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return EditorActionResult.EMPTY;
        return setFlowGuides(ProtocolEncoder.packFlowGuides(guides));
    }

    /**
     * Sets flow guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setFlowGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetFlowGuides(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets separator guide list (global replace).
     *
     * @param guides Separator guide list
     */
    @NonNull
    public EditorActionResult setSeparatorGuides(@NonNull List<? extends SeparatorGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return EditorActionResult.EMPTY;
        return setSeparatorGuides(ProtocolEncoder.packSeparatorGuides(guides));
    }

    /**
     * Sets separator guide list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setSeparatorGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetSeparatorGuides(mNativeHandle, payload, payload.remaining()));
    }

    // ==================== Bracket Pair Highlight ====================

    /**
     * Sets bracket pair list (overrides default (){}[]).
     * @param openChars Open bracket character code array
     * @param closeChars Close bracket character code array
     */
    @NonNull
    public EditorActionResult setBracketPairs(int[] openChars, int[] closeChars) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBracketPairs(mNativeHandle, openChars, closeChars));
    }

    /**
     * Sets auto-closing pairs for automatic bracket completion.
     * @param openChars Open bracket character code array
     * @param closeChars Close bracket character code array
     */
    @NonNull
    public EditorActionResult setAutoClosingPairs(int[] openChars, int[] closeChars) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetAutoClosingPairs(mNativeHandle, openChars, closeChars));
    }

    /**
     * Sets exact bracket match result externally (overrides built-in character scan).
     */
    @NonNull
    public EditorActionResult setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetMatchedBrackets(mNativeHandle, openLine, openCol, closeLine, closeCol));
    }

    /**
     * Clears externally set bracket match result (falls back to built-in character scan).
     */
    @NonNull
    public EditorActionResult clearMatchedBrackets() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearMatchedBrackets(mNativeHandle));
    }

    // ==================== Code Folding ====================

    /**
     * Sets foldable regions using {@link FoldRegion} list (replaces existing list).
     *
     * @param regions Fold region list
     */
    @NonNull
    public EditorActionResult setFoldRegions(@NonNull List<? extends FoldRegion> regions) {
        if (mNativeHandle == 0 || regions == null) return EditorActionResult.EMPTY;
        return setFoldRegions(ProtocolEncoder.packFoldRegions(regions));
    }

    /**
     * Sets foldable region list (already packed by caller via ProtocolEncoder).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setFoldRegions(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetFoldRegions(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Toggles fold state of the region containing the specified line.
     *
     * @param line Line number (0-based, usually the fold start line)
     * @return {@code true} if region was found and state was toggled
     */
    @NonNull
    public EditorActionResult toggleFoldAt(int line) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeToggleFoldAt(mNativeHandle, line));
    }

    /**
     * Folds the region containing the specified line.
     *
     * @param line Line number (0-based)
     * @return {@code true} if successfully folded
     */
    @NonNull
    public EditorActionResult foldAt(int line) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeFoldAt(mNativeHandle, line));
    }

    /**
     * Unfolds the region containing the specified line.
     *
     * @param line Line number (0-based)
     * @return {@code true} if successfully unfolded
     */
    @NonNull
    public EditorActionResult unfoldAt(int line) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeUnfoldAt(mNativeHandle, line));
    }

    /** Folds all regions. */
    @NonNull
    public EditorActionResult foldAll() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeFoldAll(mNativeHandle));
    }

    /** Unfolds all regions. */
    @NonNull
    public EditorActionResult unfoldAll() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeUnfoldAll(mNativeHandle));
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
    public EditorActionResult insertSnippet(@NonNull String snippetTemplate) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer data = nativeInsertSnippet(mNativeHandle, snippetTemplate);
        try {
            return ProtocolDecoder.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Starts linked editing mode with generic LinkedEditingModel.
     *
     * @param model Linked editing model
     */
    @NonNull
    public EditorActionResult startLinkedEditing(@NonNull LinkedEditingModel model) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packLinkedEditingModel(model);
        return decodeAction(nativeStartLinkedEditing(mNativeHandle, payload, payload.remaining()));
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
    @NonNull
    public EditorActionResult linkedEditingNext() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeLinkedEditingNext(mNativeHandle));
    }

    /**
     * Linked editing: jumps to the previous tab stop.
     *
     * @return false if already at first
     */
    @NonNull
    public EditorActionResult linkedEditingPrev() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeLinkedEditingPrev(mNativeHandle));
    }

    /**
     * Cancels linked editing mode.
     */
    @NonNull
    public EditorActionResult cancelLinkedEditing() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeCancelLinkedEditing(mNativeHandle));
    }

    // ==================== Clear Operations ====================

    /** Clears all highlight spans. */
    @NonNull
    public EditorActionResult clearHighlights() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearHighlights(mNativeHandle));
    }

    /**
     * Clears highlight spans for the specified layer.
     *
     * @param layer Layer 0 / 1
     */
    @NonNull
    public EditorActionResult clearHighlights(int layer) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearHighlightsLayer(mNativeHandle, layer));
    }

    @NonNull
    public EditorActionResult clearLineSpans(int line, int layer) {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearLineSpans(mNativeHandle, line, layer));
    }

    /** Clears all Inlay Hints. */
    @NonNull
    public EditorActionResult clearInlayHints() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearInlayHints(mNativeHandle));
    }

    /** Clears all phantom text. */
    @NonNull
    public EditorActionResult clearPhantomTexts() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearPhantomTexts(mNativeHandle));
    }

    /** Clears all gutter icons. */
    @NonNull
    public EditorActionResult clearGutterIcons() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearGutterIcons(mNativeHandle));
    }

    // ==================== CodeLens ====================

    /**
     * Sets CodeLens items for the specified line (replaces entire line).
     *
     * @param line  Line number (0-based)
     * @param items CodeLensItem list
     */
    @NonNull
    public EditorActionResult setLineCodeLens(int line, @NonNull List<? extends CodeLensItem> items) {
        if (mNativeHandle == 0 || items == null) return EditorActionResult.EMPTY;
        return setLineCodeLens(ProtocolEncoder.packLineCodeLens(line, items));
    }

    /**
     * Sets CodeLens items for the specified line (already packed by caller via ProtocolEncoder).
     */
    @NonNull
    public EditorActionResult setLineCodeLens(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineCodeLens(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets CodeLens items for multiple lines (reduces JNI calls).
     */
    @NonNull
    public EditorActionResult setBatchLineCodeLens(@Nullable SparseArray<? extends List<? extends CodeLensItem>> itemsByLine) {
        if (mNativeHandle == 0 || itemsByLine == null || itemsByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLineCodeLens(itemsByLine);
        return setBatchLineCodeLens(payload);
    }

    /**
     * Batch sets CodeLens items for multiple lines (already encoded as ByteBuffer by caller).
     */
    @NonNull
    public EditorActionResult setBatchLineCodeLens(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLineCodeLens(mNativeHandle, payload, payload.remaining()));
    }

    /** Clears all CodeLens items. */
    @NonNull
    public EditorActionResult clearCodeLens() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearCodeLens(mNativeHandle));
    }

    // ==================== Links ====================

    /**
     * Sets link ranges for the specified line (replaces the entire line).
     *
     * @param line  Line number (0-based)
     * @param links LinkSpan list
     */
    @NonNull
    public EditorActionResult setLineLinks(int line, @NonNull List<? extends LinkSpan> links) {
        if (mNativeHandle == 0 || links == null) return EditorActionResult.EMPTY;
        return setLineLinks(ProtocolEncoder.packLineLinks(line, links));
    }

    /**
     * Sets link ranges for the specified line (already packed by caller via ProtocolEncoder).
     */
    @NonNull
    public EditorActionResult setLineLinks(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetLineLinks(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets link ranges for multiple lines (reduces JNI calls).
     */
    @NonNull
    public EditorActionResult setBatchLineLinks(@Nullable SparseArray<? extends List<? extends LinkSpan>> linksByLine) {
        if (mNativeHandle == 0 || linksByLine == null || linksByLine.size() == 0) return EditorActionResult.EMPTY;
        ByteBuffer payload = ProtocolEncoder.packBatchLineLinks(linksByLine);
        return setBatchLineLinks(payload);
    }

    /**
     * Batch sets link ranges for multiple lines (already encoded as ByteBuffer by caller).
     */
    @NonNull
    public EditorActionResult setBatchLineLinks(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return EditorActionResult.EMPTY;
        return decodeAction(nativeSetBatchLineLinks(mNativeHandle, payload, payload.remaining()));
    }

    /** Clears all link ranges. */
    @NonNull
    public EditorActionResult clearLinks() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearLinks(mNativeHandle));
    }

    /**
     * Resolves link target by logical line and column inside that link.
     */
    @NonNull
    public String getLinkTargetAt(int line, int column) {
        if (mNativeHandle == 0) return "";
        String target = nativeGetLinkTargetAt(mNativeHandle, line, column);
        return target != null ? target : "";
    }

    /** Clears all code structure guides (indent guides, bracket guides, flow arrows, separators). */
    @NonNull
    public EditorActionResult clearGuides() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearGuides(mNativeHandle));
    }

    /** Clears all diagnostic decorations. */
    @NonNull
    public EditorActionResult clearDiagnostics() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearDiagnostics(mNativeHandle));
    }

    /** Clears all decoration data (highlights, Inlay Hints, phantom text, icons, guides, diagnostics). */
    @NonNull
    public EditorActionResult clearAllDecorations() {
        if (mNativeHandle == 0) return EditorActionResult.EMPTY;
        return decodeAction(nativeClearAllDecorations(mNativeHandle));
    }

    // ==================== Inner Classes/Enums ====================

    public static class EditorActionResult {
        public final boolean handled;
        public final boolean needsRedraw;
        public final int reason;
        public final boolean contentChanged;
        public final boolean cursorChanged;
        public final boolean selectionChanged;
        public final boolean scrollChanged;
        public final boolean scaleChanged;
        public final boolean pointerCursorChanged;
        public final boolean compositionChanged;
        public final boolean decorationChanged;
        public final boolean needsImeSync;
        public final boolean needsEdgeScroll;
        public final boolean needsFling;
        public final boolean needsAnimation;
        public final boolean isHandleDrag;
        @NonNull
        public final java.util.List<TextChange> changes;
        @NonNull
        public final TextPosition cursorBefore;
        @NonNull
        public final TextPosition cursorAfter;
        public final boolean hasSelectionBefore;
        @NonNull
        public final TextRange selectionBefore;
        public final boolean hasSelectionAfter;
        @NonNull
        public final TextRange selectionAfter;
        public final float scrollXBefore;
        public final float scrollYBefore;
        public final float scrollXAfter;
        public final float scrollYAfter;
        public final float scaleBefore;
        public final float scaleAfter;
        public final int pointerCursorBefore;
        public final int pointerCursorAfter;
        @NonNull
        public final ImeSyncSnapshot imeSync;
        @NonNull
        public final GestureType gestureType;
        public final int gestureEventType;
        @NonNull
        public final PointF tapPoint;
        @NonNull
        public final HitTarget hitTarget;
        public final int modifiers;
        public final int command;

        public static final EditorActionResult EMPTY = new EditorActionResult();

        public EditorActionResult() {
            this(false, false, 0,
                    false, false, false, false, false, false, false, false, false,
                    false, false, false, false,
                    java.util.Collections.emptyList(),
                    TextPosition.NONE,
                    TextPosition.NONE,
                    false,
                    new TextRange(),
                    false,
                    new TextRange(),
                    0f,
                    0f,
                    0f,
                    0f,
                    1f,
                    1f,
                    0,
                    0,
                    new ImeSyncSnapshot(),
                    GestureType.UNDEFINED,
                    EVENT_TYPE_UNDEFINED,
                    new PointF(),
                    HitTarget.NONE,
                    0,
                    0);
        }

        public EditorActionResult(boolean handled,
                                  boolean needsRedraw,
                                  int reason,
                                  boolean contentChanged,
                                  boolean cursorChanged,
                                  boolean selectionChanged,
                                  boolean scrollChanged,
                                  boolean scaleChanged,
                                  boolean pointerCursorChanged,
                                  boolean compositionChanged,
                                  boolean decorationChanged,
                                  boolean needsImeSync,
                                  boolean needsEdgeScroll,
                                  boolean needsFling,
                                  boolean needsAnimation,
                                  boolean isHandleDrag,
                                  @NonNull java.util.List<TextChange> changes,
                                  @NonNull TextPosition cursorBefore,
                                  @NonNull TextPosition cursorAfter,
                                  boolean hasSelectionBefore,
                                  @NonNull TextRange selectionBefore,
                                  boolean hasSelectionAfter,
                                  @NonNull TextRange selectionAfter,
                                  float scrollXBefore,
                                  float scrollYBefore,
                                  float scrollXAfter,
                                  float scrollYAfter,
                                  float scaleBefore,
                                  float scaleAfter,
                                  int pointerCursorBefore,
                                  int pointerCursorAfter,
                                  @NonNull ImeSyncSnapshot imeSync,
                                  @NonNull GestureType gestureType,
                                  int gestureEventType,
                                  @NonNull PointF tapPoint,
                                  @NonNull HitTarget hitTarget,
                                  int modifiers,
                                  int command) {
            this.handled = handled;
            this.needsRedraw = needsRedraw;
            this.reason = reason;
            this.contentChanged = contentChanged;
            this.cursorChanged = cursorChanged;
            this.selectionChanged = selectionChanged;
            this.scrollChanged = scrollChanged;
            this.scaleChanged = scaleChanged;
            this.pointerCursorChanged = pointerCursorChanged;
            this.compositionChanged = compositionChanged;
            this.decorationChanged = decorationChanged;
            this.needsImeSync = needsImeSync;
            this.needsEdgeScroll = needsEdgeScroll;
            this.needsFling = needsFling;
            this.needsAnimation = needsAnimation;
            this.isHandleDrag = isHandleDrag;
            this.changes = changes;
            this.cursorBefore = cursorBefore;
            this.cursorAfter = cursorAfter;
            this.hasSelectionBefore = hasSelectionBefore;
            this.selectionBefore = selectionBefore;
            this.hasSelectionAfter = hasSelectionAfter;
            this.selectionAfter = selectionAfter;
            this.scrollXBefore = scrollXBefore;
            this.scrollYBefore = scrollYBefore;
            this.scrollXAfter = scrollXAfter;
            this.scrollYAfter = scrollYAfter;
            this.scaleBefore = scaleBefore;
            this.scaleAfter = scaleAfter;
            this.pointerCursorBefore = pointerCursorBefore;
            this.pointerCursorAfter = pointerCursorAfter;
            this.imeSync = imeSync;
            this.gestureType = gestureType;
            this.gestureEventType = gestureEventType;
            this.tapPoint = tapPoint;
            this.hitTarget = hitTarget;
            this.modifiers = modifiers;
            this.command = command;
        }

        @NonNull
        @Override
        public String toString() {
            return "EditorActionResult{handled=" + handled + ", needsRedraw=" + needsRedraw +
                    ", contentChanged=" + contentChanged +
                    ", cursorChanged=" + cursorChanged + ", selectionChanged=" + selectionChanged +
                    ", scrollChanged=" + scrollChanged + ", scaleChanged=" + scaleChanged +
                    ", gestureType=" + gestureType + ", command=" + command + '}';
        }
    }

    public static final class ImeTextUnit {
        public static final int GRAPHEME = 0;
        public static final int CODE_POINT = 1;

        private ImeTextUnit() {
        }
    }

    public static class ImeTextRange {
        public final int start;
        public final int end;

        public ImeTextRange() {
            this(0, 0);
        }

        public ImeTextRange(int start, int end) {
            this.start = start;
            this.end = end;
        }
    }

    public static final class ImeScriptClass {
        public static final int UNKNOWN = 0;
        public static final int LATIN = 1;
        public static final int CJK = 2;
        public static final int KANA = 3;
        public static final int HANGUL = 4;

        private ImeScriptClass() {
        }
    }

    public static final class ImePreeditStorage {
        public static final int NONE = 0;
        public static final int VISIBLE_DOCUMENT_COMPOSITION = 1;
        public static final int SHADOW_ONLY = 2;

        private ImePreeditStorage() {
        }
    }

    public static final class ImeContextPolicy {
        public static final int NONE = 0;
        public static final int LIMITED_FOR_CANDIDATES = 1;

        private ImeContextPolicy() {
        }
    }

    public static final class ImeInputContextKind {
        public static final int NONE = 0;
        public static final int SELECTION_ONLY = 1;
        public static final int DOCUMENT_WINDOW = 2;
        public static final int TRANSIENT_INPUT = 3;

        private ImeInputContextKind() {
        }
    }

    public static class ImeSyncSnapshot {
        @NonNull
        public final TextPosition cursor;
        @Nullable
        public final TextRange selection;
        public final boolean hasComposingSession;
        @Nullable
        public final TextRange visibleCompositionRange;
        @Nullable
        public final TextRange platformMarkedRange;
        public final int preeditStorage;
        public final int contextPolicy;
        public final boolean clearPlatformPreedit;

        public ImeSyncSnapshot() {
            this(new TextPosition(0, 0), null, false, null, null,
                    ImePreeditStorage.NONE, ImeContextPolicy.NONE, false);
        }

        public ImeSyncSnapshot(@NonNull TextPosition cursor,
                               @Nullable TextRange selection,
                               boolean hasComposingSession,
                               @Nullable TextRange visibleCompositionRange,
                               @Nullable TextRange platformMarkedRange,
                               int preeditStorage,
                               int contextPolicy,
                               boolean clearPlatformPreedit) {
            this.cursor = cursor;
            this.selection = selection;
            this.hasComposingSession = hasComposingSession;
            this.visibleCompositionRange = visibleCompositionRange;
            this.platformMarkedRange = platformMarkedRange;
            this.preeditStorage = preeditStorage;
            this.contextPolicy = contextPolicy;
            this.clearPlatformPreedit = clearPlatformPreedit;
        }
    }

    public static class ImeInputContext {
        public final long id;
        public final int revision;
        public final int documentStartOffset;
        @NonNull
        public final String text;
        @NonNull
        public final ImeTextRange selection;
        public final boolean hasComposition;
        @NonNull
        public final ImeTextRange composition;
        public final int kind;

        public ImeInputContext() {
            this(0, 0, 0, "", new ImeTextRange(), false,
                    new ImeTextRange(-1, -1), ImeInputContextKind.NONE);
        }

        public ImeInputContext(long id,
                               int revision,
                               int documentStartOffset,
                               @NonNull String text,
                               @NonNull ImeTextRange selection,
                               boolean hasComposition,
                               @NonNull ImeTextRange composition,
                               int kind) {
            this.id = id;
            this.revision = revision;
            this.documentStartOffset = documentStartOffset;
            this.text = text;
            this.selection = selection;
            this.hasComposition = hasComposition;
            this.composition = composition;
            this.kind = kind;
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
        INLAY_HINT_COLOR(6),
        /**
         * Hit a CodeLens item
         */
        CODELENS(7),
        /**
         * Hit a document link
         */
        LINK(8);

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

    /** Decoration hit target information returned by the C++ layer when applicable. */
    public static class HitTarget {
        public static final HitTarget NONE = new HitTarget(HitTargetType.NONE, 0, 0, 0, 0);

        public final HitTargetType type;
        /**
         * Hit logical line number (0-based)
         */
        public final int line;
        /**
         * Hit column number (0-based, meaningful for InlayHint, CodeLens, and Link)
         */
        public final int column;
        /**
         * Icon ID (valid for INLAY_HINT_ICON / GUTTER_ICON, or commandId for CODELENS)
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

    private static int getMotionEventModifiers(MotionEvent event) {
        int metaState = event.getMetaState();
        int modifiers = KeyModifier.NONE;
        if ((metaState & KeyEvent.META_SHIFT_ON) != 0) modifiers |= KeyModifier.SHIFT;
        if ((metaState & KeyEvent.META_CTRL_ON) != 0) modifiers |= KeyModifier.CTRL;
        if ((metaState & KeyEvent.META_ALT_ON) != 0) modifiers |= KeyModifier.ALT;
        if ((metaState & KeyEvent.META_META_ON) != 0) modifiers |= KeyModifier.META;
        return modifiers;
    }

    // ==================== Native Method Declarations ====================

    @FastNative
    private static native long nativeMakeEditorCore(TextMeasurer measurer, ByteBuffer optionsData, int optionsSize);

    @CriticalNative
    private static native void nativeFinalizeEditorCore(long handle);

    @FastNative
    private static native ByteBuffer nativeSetViewport(long handle, int width, int height);

    @FastNative
    private static native ByteBuffer nativeLoadDocument(long handle, long documentHandle);

    @FastNative
    private static native ByteBuffer nativeOnFontMetricsChanged(long handle);

    @FastNative
    private static native ByteBuffer nativeSetFoldArrowMode(long handle, int mode);

    @FastNative
    private static native ByteBuffer nativeSetWrapMode(long handle, int mode);

    @FastNative
    private static native ByteBuffer nativeSetTabSize(long handle, int tabSize);

    @FastNative
    private static native ByteBuffer nativeSetScale(long handle, float scale);

    @FastNative
    private static native ByteBuffer nativeSetLineSpacing(long handle, float add, float mult);

    @FastNative
    private static native ByteBuffer nativeSetContentStartPadding(long handle, float padding);

    @FastNative
    private static native ByteBuffer nativeSetShowSplitLine(long handle, boolean show);

    @FastNative
    private static native ByteBuffer nativeSetGutterSticky(long handle, boolean sticky);

    @FastNative
    private static native ByteBuffer nativeSetGutterVisible(long handle, boolean visible);

    @FastNative
    private static native ByteBuffer nativeSetCurrentLineRenderMode(long handle, int mode);

    @FastNative
    private static native ByteBuffer nativeBuildRenderModel(long handle);

    @FastNative
    private static native ByteBuffer nativeHandleGestureEvent(long handle, int type, int pointerCount, float[] points);

    @FastNative
    private static native ByteBuffer nativeHandleGestureEventEx(long handle, int type, int pointerCount, float[] points,
                                                                int modifiers, float wheelDeltaX, float wheelDeltaY,
                                                                float directScale);

    @FastNative
    private static native ByteBuffer nativeUpdatePointerModifiers(long handle, int modifiers);

    @FastNative
    private static native ByteBuffer nativeTickEdgeScroll(long handle);

    @FastNative
    private static native ByteBuffer nativeTickFling(long handle);

    @FastNative
    private static native ByteBuffer nativeTickAnimations(long handle);

    @FastNative
    private static native ByteBuffer nativeGetLayoutMetrics(long handle);

    @FastNative
    private static native ByteBuffer nativeHandleKeyEvent(long handle, int keyCode, String text, int modifiers);

    @FastNative
    private static native ByteBuffer nativeSetKeyMap(long handle, ByteBuffer data);

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

    @FastNative
    private static native ByteBuffer nativeMoveCursorLeft(long handle, boolean extendSelection);

    @FastNative
    private static native ByteBuffer nativeMoveCursorRight(long handle, boolean extendSelection);

    @FastNative
    private static native ByteBuffer nativeMoveCursorUp(long handle, boolean extendSelection);

    @FastNative
    private static native ByteBuffer nativeMoveCursorDown(long handle, boolean extendSelection);

    @FastNative
    private static native ByteBuffer nativeMoveCursorToLineStart(long handle, boolean extendSelection);

    @FastNative
    private static native ByteBuffer nativeMoveCursorToLineEnd(long handle, boolean extendSelection);

    @FastNative
    private static native ByteBuffer nativeSetCursorPosition(long handle, int line, int column);

    @FastNative
    private static native ByteBuffer nativeSelectAll(long handle);

    @FastNative
    private static native ByteBuffer nativeSetSelection(long handle, int startLine, int startColumn, int endLine, int endColumn);

    @FastNative
    private static native long[] nativeGetSelection(long handle);

    @FastNative
    private static native String nativeGetSelectedText(long handle);

    @CriticalNative
    private static native boolean nativeIsComposing(long handle);

    @FastNative
    private static native long[] nativeGetComposingRange(long handle);

    @FastNative
    private static native long[] nativeGetComposingSessionRange(long handle);

    @FastNative
    private static native ByteBuffer nativeImeUpdatePreedit(long handle, String text, int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeSetComposingText(long handle, String text, int cursorOffset, int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeCommitText(long handle, String text, int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeCommitTextWithCursor(long handle, String text, int cursorOffset, int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeFinishPreedit(long handle);

    @FastNative
    private static native ByteBuffer nativeImeCancelPreedit(long handle);

    @FastNative
    private static native ByteBuffer nativeImeMarkDocumentRange(long handle,
                                                                long startLine,
                                                                long startColumn,
                                                                long endLine,
                                                                long endColumn,
                                                                int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeMarkDocumentRangeByOffset(long handle,
                                                                        long startOffset,
                                                                        long endOffset,
                                                                        int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeReplaceText(long handle,
                                                          long startLine,
                                                          long startColumn,
                                                          long endLine,
                                                          long endColumn,
                                                          String text,
                                                          int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeReplaceDocumentText(long handle,
                                                                  long startOffset,
                                                                  long endOffset,
                                                                  String text,
                                                                  int cursorOffset,
                                                                  int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeReplaceInputContextText(long handle,
                                                                      long startOffset,
                                                                      long endOffset,
                                                                      String text,
                                                                      int cursorOffset,
                                                                      int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeMarkInputContextRange(long handle,
                                                                    long startOffset,
                                                                    long endOffset,
                                                                    int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeNotifyDocumentSelectionChanged(long handle,
                                                                            long startOffset,
                                                                            long endOffset);

    @FastNative
    private static native ByteBuffer nativeImeNotifyInputContextSelectionChanged(long handle,
                                                                                long startOffset,
                                                                                long endOffset);

    @FastNative
    private static native ByteBuffer nativeImeUpdateInputStateText(long handle,
                                                                   long contextId,
                                                                   int documentStartOffset,
                                                                   String text,
                                                                   int selectionStartOffset,
                                                                   int selectionEndOffset,
                                                                   int composingStartOffset,
                                                                   int composingEndOffset,
                                                                   int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeUpdateInputStateSelection(long handle,
                                                                       long contextId,
                                                                       int documentStartOffset,
                                                                       int selectionStartOffset,
                                                                       int selectionEndOffset);

    @FastNative
    private static native ByteBuffer nativeImeReplaceInputStateText(long handle,
                                                                    long contextId,
                                                                    int documentStartOffset,
                                                                    long startOffset,
                                                                    long endOffset,
                                                                    String text,
                                                                    int cursorOffset,
                                                                    int scriptHint);

    @FastNative
    private static native ByteBuffer nativeImeDeleteBackward(long handle, long beforeLength, int textUnit);

    @FastNative
    private static native ByteBuffer nativeImeDeleteForward(long handle, long afterLength, int textUnit);

    @FastNative
    private static native ByteBuffer nativeImeDeleteSurrounding(long handle,
                                                                long beforeLength,
                                                                long afterLength,
                                                                int textUnit);

    @FastNative
    private static native ByteBuffer nativeImeNotifySelectionChanged(long handle,
                                                                     long startLine,
                                                                     long startColumn,
                                                                     long endLine,
                                                                     long endColumn);

    @FastNative
    private static native ByteBuffer nativeImeNotifyCursorChanged(long handle,
                                                                  long cursorLine,
                                                                  long cursorColumn);

    @FastNative
    private static native ByteBuffer nativeImeSetKeyboardScriptClass(long handle, int scriptClass);

    @CriticalNative
    private static native int nativeImeGetKeyboardScriptClass(long handle);

    @FastNative
    private static native ByteBuffer nativeGetImeSyncSnapshot(long handle);

    @FastNative
    private static native ByteBuffer nativeGetImeInputContext(long handle, long beforeLength, long afterLength);

    @FastNative
    private static native ByteBuffer nativeSetReadOnly(long handle, boolean readOnly);

    @CriticalNative
    private static native boolean nativeIsReadOnly(long handle);

    @FastNative
    private static native ByteBuffer nativeSetAutoIndentMode(long handle, int mode);

    @CriticalNative
    private static native int nativeGetAutoIndentMode(long handle);

    @FastNative
    private static native ByteBuffer nativeSetBackspaceUnindent(long handle, boolean enabled);

    @FastNative
    private static native ByteBuffer nativeSetInsertSpaces(long handle, boolean enabled);

    @FastNative
    private static native ByteBuffer nativeSetHandleConfig(long handle,
            float startLeft, float startTop, float startRight, float startBottom,
            float endLeft, float endTop, float endRight, float endBottom);

    @FastNative
    private static native ByteBuffer nativeSetScrollbarConfig(long handle, float thickness, float minThumb, float thumbHitPadding,
                                                        int mode, boolean thumbDraggable, int trackTapMode,
                                                        int fadeDelayMs, int fadeDurationMs);

    @FastNative
    private static native float[] nativeGetPositionRect(long handle, int line, int column);

    @FastNative
    private static native float[] nativeGetCursorRect(long handle);

    @FastNative
    private static native ByteBuffer nativeScrollToLine(long handle, int line, int behavior);

    @FastNative
    private static native ByteBuffer nativeGotoPosition(long handle, int line, int column);

    @FastNative
    private static native ByteBuffer nativeEnsureCursorVisible(long handle);

    @FastNative
    private static native ByteBuffer nativeSetScroll(long handle, float scrollX, float scrollY);

    @FastNative
    private static native ByteBuffer nativeGetScrollMetrics(long handle);

    @FastNative
    private static native int[] nativeGetVisibleLineRange(long handle);

    @FastNative
    private static native ByteBuffer nativeRegisterTextStyle(long handle, int styleId, int color, int backgroundColor, int fontStyle);

    @FastNative
    private static native ByteBuffer nativeRegisterBatchTextStyles(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetLineSpans(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetLineInlayHints(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetLinePhantomTexts(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetLineGutterIcons(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetMaxGutterIcons(long handle, int count);

    @FastNative
    private static native ByteBuffer nativeSetLineDiagnostics(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineSpans(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineInlayHints(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLinePhantomTexts(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineGutterIcons(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineDiagnostics(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeClearDiagnostics(long handle);

    @FastNative
    private static native ByteBuffer nativeSetIndentGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBracketGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetFlowGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetSeparatorGuides(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBracketPairs(long handle, int[] openChars, int[] closeChars);

    @FastNative
    private static native ByteBuffer nativeSetAutoClosingPairs(long handle, int[] openChars, int[] closeChars);

    @FastNative
    private static native ByteBuffer nativeSetMatchedBrackets(long handle, int openLine, int openCol, int closeLine, int closeCol);

    @FastNative
    private static native ByteBuffer nativeClearMatchedBrackets(long handle);

    @FastNative
    private static native ByteBuffer nativeSetFoldRegions(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeToggleFoldAt(long handle, int line);

    @FastNative
    private static native ByteBuffer nativeFoldAt(long handle, int line);

    @FastNative
    private static native ByteBuffer nativeUnfoldAt(long handle, int line);

    @FastNative
    private static native ByteBuffer nativeFoldAll(long handle);

    @FastNative
    private static native ByteBuffer nativeUnfoldAll(long handle);

    @CriticalNative
    private static native boolean nativeIsLineVisible(long handle, int line);

    @FastNative
    private static native ByteBuffer nativeClearHighlights(long handle);

    @FastNative
    private static native ByteBuffer nativeClearHighlightsLayer(long handle, int layer);

    @FastNative
    private static native ByteBuffer nativeClearLineSpans(long handle, int line, int layer);

    @FastNative
    private static native ByteBuffer nativeClearInlayHints(long handle);

    @FastNative
    private static native ByteBuffer nativeClearPhantomTexts(long handle);

    @FastNative
    private static native ByteBuffer nativeClearGutterIcons(long handle);

    @FastNative
    private static native ByteBuffer nativeSetLineCodeLens(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineCodeLens(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeClearCodeLens(long handle);

    @FastNative
    private static native ByteBuffer nativeSetLineLinks(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineLinks(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeClearLinks(long handle);

    @FastNative
    private static native String nativeGetLinkTargetAt(long handle, int line, int column);

    @FastNative
    private static native ByteBuffer nativeClearGuides(long handle);

    @FastNative
    private static native ByteBuffer nativeClearAllDecorations(long handle);

    @FastNative
    private static native ByteBuffer nativeInsertSnippet(long handle, String snippetTemplate);

    @FastNative
    private static native ByteBuffer nativeStartLinkedEditing(long handle, ByteBuffer data, int size);

    @CriticalNative
    private static native boolean nativeIsInLinkedEditing(long handle);

    @FastNative
    private static native ByteBuffer nativeLinkedEditingNext(long handle);

    @FastNative
    private static native ByteBuffer nativeLinkedEditingPrev(long handle);

    @FastNative
    private static native ByteBuffer nativeCancelLinkedEditing(long handle);

    @FastNative
    private static native void nativeFreeBinaryData(@Nullable ByteBuffer data);

    static {
        System.loadLibrary("sweeteditor");
    }
}
