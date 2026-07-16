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
import com.qiplat.sweeteditor.core.adornment.DocumentHighlight;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.LinkSpan;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.config.EditorRangeEffectStyles;
import com.qiplat.sweeteditor.core.config.EditorRenderColors;
import com.qiplat.sweeteditor.core.config.EditorOptions;
import com.qiplat.sweeteditor.core.config.HandleConfig;
import com.qiplat.sweeteditor.core.config.ScrollbarConfig;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.ime.ImeCommandMessage;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeScriptClass;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateMessage;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateScope;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.interaction.EventType;
import com.qiplat.sweeteditor.core.interaction.GestureEvent;
import com.qiplat.sweeteditor.core.search.SearchRequest;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.visual.CursorRect;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.core.visual.LayoutMetrics;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextEdit;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.adornment.TextStyle;

import java.nio.ByteBuffer;
import java.util.ArrayList;
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
        ByteBuffer optionsBuf = CoreProtocol.encodeEditorOptions(options);
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
            return new EditorActionResult();
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
            return new EditorActionResult();
        }
        return decodeAction(nativeSetViewport(mNativeHandle, width, height));
    }

    @NonNull
    public EditorActionResult onFontMetricsChanged() {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetFoldArrowMode(mNativeHandle, mode));
    }

    /**
     * Sets the auto wrap mode.
     *
     * @param mode 0=NONE (no wrap), 1=CHAR_BREAK (character-level wrap), 2=WORD_BREAK (word-level wrap)
     */
    @NonNull
    public EditorActionResult setWrapMode(int mode) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetWrapMode(mNativeHandle, mode));
    }

    /**
     * Sets whitespace marker rendering mode.
     *
     * @param mode 0=NONE, 1=BOUNDARY, 2=SELECTION, 3=TRAILING, 4=ALL
     */
    @NonNull
    public EditorActionResult setRenderWhitespace(int mode) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetRenderWhitespace(mNativeHandle, mode));
    }

    /**
     * Sets whether source line endings should be rendered.
     *
     * @param enabled true to render line-ending markers, false to hide them
     */
    @NonNull
    public EditorActionResult setRenderLineBreaks(boolean enabled) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetRenderLineBreaks(mNativeHandle, enabled));
    }

    /**
     * Sets the tab size (number of spaces per tab stop).
     *
     * @param tabSize tab size (default 4, minimum 1)
     */
    @NonNull
    public EditorActionResult setTabSize(int tabSize) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetTabSize(mNativeHandle, tabSize));
    }

    /**
     * Sets the editor scale factor.
     *
     * @param scale scale factor (1.0 = 100%)
     */
    @NonNull
    public EditorActionResult setScale(float scale) {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetLineSpacing(mNativeHandle, add, mult));
    }

    /**
     * Sets extra horizontal padding between gutter split and text content start.
     *
     * @param padding padding in pixels (clamped to >= 0 on native side)
     */
    @NonNull
    public EditorActionResult setContentStartPadding(float padding) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetContentStartPadding(mNativeHandle, padding));
    }

    /**
     * Sets whether gutter split line should be rendered.
     *
     * @param show true to show split line, false to hide
     */
    @NonNull
    public EditorActionResult setShowSplitLine(boolean show) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetShowSplitLine(mNativeHandle, show));
    }

    /**
     * Sets whether gutter stays fixed during horizontal scroll.
     *
     * @param sticky true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style)
     */
    @NonNull
    public EditorActionResult setGutterSticky(boolean sticky) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetGutterSticky(mNativeHandle, sticky));
    }

    /**
     * Sets whether gutter area is visible.
     *
     * @param visible true=show gutter (line numbers, icons, fold arrows), false=hide entire gutter
     */
    @NonNull
    public EditorActionResult setGutterVisible(boolean visible) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetGutterVisible(mNativeHandle, visible));
    }

    /**
     * Sets current line render mode.
     *
     * @param mode 0=BACKGROUND(fill), 1=BORDER(stroke), 2=NONE(disabled)
     */
    @NonNull
    public EditorActionResult setCurrentLineRenderMode(int mode) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetCurrentLineRenderMode(mNativeHandle, mode));
    }

    // ==================== Rendering ====================

    @Nullable
    public EditorRenderModel buildRenderModel() {
        if (mNativeHandle == 0) return null;
        ByteBuffer data = nativeBuildRenderModel(mNativeHandle);
        EditorRenderModel model;
        try {
            model = CoreProtocol.decodeEditorRenderModel(data);
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
            return CoreProtocol.decodeLayoutMetrics(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    private EditorActionResult decodeAction(@Nullable ByteBuffer data) {
        if (data == null) {
            return new EditorActionResult();
        }
        try {
            return CoreProtocol.decodeEditorActionResult(data);
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
        List<com.qiplat.sweeteditor.core.foundation.PointF> points = new ArrayList<>(pointerCount);
        for (int i = 0; i < pointerCount; i++) {
            points.add(new com.qiplat.sweeteditor.core.foundation.PointF(event.getX(i), event.getY(i)));
        }
        GestureEvent gestureEvent = new GestureEvent(
                EventType.fromValue(eventType),
                points,
                getMotionEventModifiers(event),
                0f,
                0f,
                1f);
        ByteBuffer payload = CoreProtocol.encodeGestureEvent(gestureEvent);
        return decodeAction(nativeHandleGestureEvent(mNativeHandle, payload, payload.remaining()));
    }

    public EditorActionResult handleGestureEvent(int eventType,
                                                 @Nullable PointF[] points,
                                                 int modifiers,
                                                 float wheelDeltaX,
                                                 float wheelDeltaY,
                                                 float directScale) {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        int pointerCount = points != null ? points.length : 0;
        List<com.qiplat.sweeteditor.core.foundation.PointF> corePoints = new ArrayList<>(pointerCount);
        if (pointerCount > 0) {
            for (int i = 0; i < pointerCount; i++) {
                PointF point = points[i];
                corePoints.add(new com.qiplat.sweeteditor.core.foundation.PointF(
                        point != null ? point.x : 0f,
                        point != null ? point.y : 0f));
            }
        }
        GestureEvent gestureEvent = new GestureEvent(
                EventType.fromValue(eventType),
                corePoints,
                modifiers,
                wheelDeltaX,
                wheelDeltaY,
                directScale);
        ByteBuffer payload = CoreProtocol.encodeGestureEvent(gestureEvent);
        return decodeAction(nativeHandleGestureEvent(mNativeHandle, payload, payload.remaining()));
    }

    public EditorActionResult updatePointerModifiers(int modifiers) {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        return decodeAction(nativeUpdatePointerModifiers(mNativeHandle, modifiers));
    }

    /**
     * Unified animation tick for all core-managed animation flags.
     * Platform schedules the next call from animationFlags and nextAnimationDelayMs.
     */
    public EditorActionResult tickAnimations() {
        if (mNativeHandle == 0) {
            return new EditorActionResult();
        }
        ByteBuffer data = nativeTickAnimations(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
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
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult setKeyMap(@NonNull ByteBuffer data) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetKeyMap(mNativeHandle, data));
    }

    @NonNull
    public EditorActionResult setKeyMap(@NonNull List<? extends KeyBinding> bindings) {
        return setKeyMap(CoreProtocol.encodeSetKeyMapPayload(bindings));
    }

    // ==================== Text Editing ====================

    @NonNull
    public EditorActionResult insertText(String text) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeInsertText(mNativeHandle, text);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
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
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeReplaceText(mNativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column, newText);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
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
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeDeleteText(mNativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    /**
     * Applies multiple text edits as one undoable operation.
     * The first edit is the primary edit and determines the final cursor position.
     */
    @NonNull
    public EditorActionResult applyTextEdits(@NonNull List<? extends TextEdit> edits) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeApplyTextEditsPayload(edits);
        ByteBuffer data = nativeApplyTextEdits(mNativeHandle, payload);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Line Operations ====================

    @NonNull
    public EditorActionResult moveLineUp() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeMoveLineUp(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult moveLineDown() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeMoveLineDown(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult copyLineUp() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeCopyLineUp(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult copyLineDown() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeCopyLineDown(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult deleteLine() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeDeleteLine(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult insertLineAbove() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeInsertLineAbove(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult insertLineBelow() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeInsertLineBelow(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    // ==================== Undo/Redo ====================

    @NonNull
    public EditorActionResult undo() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeUndo(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public EditorActionResult redo() {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeRedo(mNativeHandle);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
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

    @NonNull
    public EditorActionResult search(@NonNull SearchRequest request) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeSearchRequest(request);
        return decodeAction(nativeSearch(mNativeHandle, payload, payload.remaining()));
    }

    @NonNull
    public EditorActionResult findNextSearchMatch() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeFindNextSearchMatch(mNativeHandle));
    }

    @NonNull
    public EditorActionResult findPreviousSearchMatch() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeFindPreviousSearchMatch(mNativeHandle));
    }

    @NonNull
    public EditorActionResult replaceCurrentSearchMatch(@NonNull String replacement) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeUtf8String(replacement);
        return decodeAction(nativeReplaceCurrentSearchMatch(mNativeHandle, payload, payload.remaining()));
    }

    @NonNull
    public EditorActionResult replaceAllSearchMatches(@NonNull String replacement) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeUtf8String(replacement);
        return decodeAction(nativeReplaceAllSearchMatches(mNativeHandle, payload, payload.remaining()));
    }

    @NonNull
    public EditorActionResult clearSearch() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearSearch(mNativeHandle));
    }

    @NonNull
    public SearchState getSearchState() {
        if (mNativeHandle == 0) return new SearchState();
        ByteBuffer data = nativeGetSearchState(mNativeHandle);
        if (data == null) return new SearchState();
        try {
            return CoreProtocol.decodeSearchState(data);
        } finally {
            nativeFreeBinaryData(data);
        }
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeMoveCursorLeft(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorRight(boolean extendSelection) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeMoveCursorRight(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorUp(boolean extendSelection) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeMoveCursorUp(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorDown(boolean extendSelection) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeMoveCursorDown(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorToLineStart(boolean extendSelection) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeMoveCursorToLineStart(mNativeHandle, extendSelection));
    }

    @NonNull
    public EditorActionResult moveCursorToLineEnd(boolean extendSelection) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeMoveCursorToLineEnd(mNativeHandle, extendSelection));
    }

    /**
     * Sets the cursor position (does not scroll viewport, only moves cursor).
     *
     * @param position Target position
     */
    @NonNull
    public EditorActionResult setCursorPosition(@NonNull TextPosition position) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetCursorPosition(mNativeHandle, position.line, position.column));
    }

    /** Selects all document content. */
    @NonNull
    public EditorActionResult selectAll() {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
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

    public boolean hasPreedit() {
        if (mNativeHandle == 0) return false;
        return nativeHasPreedit(mNativeHandle);
    }

    @NonNull
    public EditorActionResult handleImeCommandMessage(@NonNull ImeCommandMessage message) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeImeCommandMessage(message);
        return decodeAction(nativeImeHandleCommandMessage(
                mNativeHandle,
                payload,
                payload.remaining()));
    }

    @NonNull
    public EditorActionResult handleImeTextUpdateMessage(@NonNull ImeTextUpdateMessage message) {
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeImeTextUpdateMessage(message);
        return decodeAction(nativeImeHandleTextUpdateMessage(
                mNativeHandle,
                payload,
                payload.remaining()));
    }

    public int getImeKeyboardScriptClass() {
        if (mNativeHandle == 0) return ImeScriptClass.UNKNOWN.value;
        return nativeImeGetKeyboardScriptClass(mNativeHandle);
    }

    @NonNull
    public ImeSyncSnapshot getImeSyncSnapshot() {
        if (mNativeHandle == 0) return new ImeSyncSnapshot();
        ByteBuffer data = nativeGetImeSyncSnapshot(mNativeHandle);
        try {
            if (data == null) return new ImeSyncSnapshot();
            return CoreProtocol.decodeImeSyncSnapshot(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public ImeInputContext getImeCommandInputContext(long beforeLength, long afterLength) {
        if (mNativeHandle == 0) return new ImeInputContext();
        ByteBuffer data = nativeGetImeCommandInputContext(mNativeHandle, beforeLength, afterLength);
        try {
            if (data == null) return new ImeInputContext();
            return CoreProtocol.decodeImeInputContext(data);
        } finally {
            nativeFreeBinaryData(data);
        }
    }

    @NonNull
    public ImeInputContext getImeTextUpdateInputContext(@NonNull ImeTextUpdateScope scope,
                                                        long beforeLength,
                                                        long afterLength) {
        if (mNativeHandle == 0) return new ImeInputContext();
        ByteBuffer data = nativeGetImeTextUpdateInputContext(
                mNativeHandle,
                scope.value,
                beforeLength,
                afterLength);
        try {
            if (data == null) return new ImeInputContext();
            return CoreProtocol.decodeImeInputContext(data);
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetBackspaceUnindent(mNativeHandle, enabled));
    }

    /**
     * Sets whether Tab inserts spaces up to the next tab stop instead of a literal tab.
     *
     * @param enabled true=insert spaces, false=insert '\t'
     */
    @NonNull
    public EditorActionResult setInsertSpaces(boolean enabled) {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        mHandleConfig = config;
        ByteBuffer payload = CoreProtocol.encodeHandleConfig(config);
        return decodeAction(nativeSetHandleConfig(mNativeHandle, payload, payload.remaining()));
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
        if (mNativeHandle == 0) return new EditorActionResult();
        mScrollbarConfig = config;
        ByteBuffer payload = CoreProtocol.encodeScrollbarConfig(config);
        return decodeAction(nativeSetScrollbarConfig(mNativeHandle, payload, payload.remaining()));
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeGotoPosition(mNativeHandle, line, column));
    }

    /**
     * Adjusts scroll offset just enough to keep the current cursor visible in the viewport.
     */
    @NonNull
    public EditorActionResult ensureCursorVisible() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeEnsureCursorVisible(mNativeHandle));
    }

    /**
     * Manually sets the scroll position (automatically clamped to valid range).
     */
    @NonNull
    public EditorActionResult setScroll(float scrollX, float scrollY) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetScroll(mNativeHandle, scrollX, scrollY));
    }

    /**
     * Gets scrollbar metrics (used by platform to calculate thumb size and position).
     */
    @NonNull
    public ScrollMetrics getScrollMetrics() {
        if (mNativeHandle == 0) {
            return new ScrollMetrics();
        }
        ByteBuffer data = nativeGetScrollMetrics(mNativeHandle);
        try {
            if (data == null) return new ScrollMetrics();
            return CoreProtocol.decodeScrollMetrics(data);
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

    /**
     * Sets editor colors resolved by native core when building visual runs.
     */
    @NonNull
    public EditorActionResult setEditorRenderColors(@Nullable EditorRenderColors colors) {
        if (mNativeHandle == 0) return new EditorActionResult();
        if (colors == null) colors = new EditorRenderColors();
        ByteBuffer payload = CoreProtocol.encodeEditorRenderColors(colors);
        return decodeAction(nativeSetEditorRenderColors(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets range-effect styles resolved by native core when building the render model.
     */
    @NonNull
    public EditorActionResult setEditorRangeEffectStyles(@Nullable EditorRangeEffectStyles styles) {
        if (mNativeHandle == 0) return new EditorActionResult();
        if (styles == null) styles = new EditorRangeEffectStyles();
        ByteBuffer payload = CoreProtocol.encodeEditorRangeEffectStyles(styles);
        return decodeAction(nativeSetEditorRangeEffectStyles(mNativeHandle, payload, payload.remaining()));
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0 || stylesById == null || stylesById.isEmpty()) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeRegisterBatchTextStylesPayload(stylesById);
        return registerBatchTextStyles(payload);
    }

    /**
     * Registers multiple highlight styles in one JNI call (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult registerBatchTextStyles(@Nullable ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        if (mNativeHandle == 0 || styleSpans == null) return new EditorActionResult();
        return setLineSpans(CoreProtocol.encodeSetLineSpansPayload(line, SpanLayer.fromValue(layer), styleSpans));
    }



    /**
     * Sets highlight spans for the specified line (already encoded by caller).
     *
     * @param payload Packed ByteBuffer (format: line, layer, count, repeated col, len, style)
     */
    @NonNull
    public EditorActionResult setLineSpans(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineSpans(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets highlight spans for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param layer       Highlight layer (0=SYNTAX, 1=SEMANTIC)
     * @param spansByLine Sparse array of line to span list
     */
    @Nullable
    public EditorActionResult setBatchLineSpans(int layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine) {
        if (mNativeHandle == 0 || spansByLine == null || spansByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineSpansPayload(SpanLayer.fromValue(layer), spansByLine);
        return setBatchLineSpans(payload);
    }

    /**
     * Batch sets highlight spans for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineSpans(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        ByteBuffer payload = CoreProtocol.encodeSetLineInlayHintsPayload(line, hints);
        return setLineInlayHints(payload);
    }

    /**
     * Batch sets Inlay Hints for the specified lines (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setLineInlayHints(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineInlayHints(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets Inlay Hints for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param hintsByLine Sparse array of line to hint list
     */
    @Nullable
    public EditorActionResult setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine) {
        if (mNativeHandle == 0 || hintsByLine == null || hintsByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineInlayHintsPayload(hintsByLine);
        return setBatchLineInlayHints(payload);
    }

    /**
     * Batch sets Inlay Hints for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineInlayHints(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        if (mNativeHandle == 0 || phantoms == null) return new EditorActionResult();
        return setLinePhantomTexts(CoreProtocol.encodeSetLinePhantomTextsPayload(line, phantoms));
    }

    /**
     * Sets phantom text for the specified line (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setLinePhantomTexts(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLinePhantomTexts(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets phantom text for multiple lines (reduces JNI calls, marks dirty once).
     *
     * @param phantomsByLine Sparse array of line to phantom list
     */
    @Nullable
    public EditorActionResult setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        if (mNativeHandle == 0 || phantomsByLine == null || phantomsByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLinePhantomTextsPayload(phantomsByLine);
        return setBatchLinePhantomTexts(payload);
    }

    /**
     * Batch sets phantom text for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLinePhantomTexts(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        if (mNativeHandle == 0 || icons == null) return new EditorActionResult();
        return setLineGutterIcons(CoreProtocol.encodeSetLineGutterIconsPayload(line, icons));
    }

    /**
     * Sets gutter icons for the specified line (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setLineGutterIcons(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineGutterIcons(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets gutter icons for multiple lines (reduces JNI calls).
     *
     * @param iconsByLine Sparse array of line to icon list
     */
    @Nullable
    public EditorActionResult setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine) {
        if (mNativeHandle == 0 || iconsByLine == null || iconsByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineGutterIconsPayload(iconsByLine);
        return setBatchLineGutterIcons(payload);
    }

    /**
     * Batch sets gutter icons for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineGutterIcons(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0 || items == null) return new EditorActionResult();
        return setLineDiagnostics(CoreProtocol.encodeSetLineDiagnosticsPayload(line, items));
    }

    /**
     * Sets diagnostic decorations for the specified line (already encoded by caller).
     *
     * @param payload Packed ByteBuffer (format: line, count, repeated col, len, severity, color)
     */
    @NonNull
    public EditorActionResult setLineDiagnostics(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineDiagnostics(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets diagnostic decorations for multiple lines (reduces JNI calls).
     *
     * @param diagsByLine Sparse array of line to diagnostic list
     */
    @Nullable
    public EditorActionResult setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> diagsByLine) {
        if (mNativeHandle == 0 || diagsByLine == null || diagsByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineDiagnosticsPayload(diagsByLine);
        return setBatchLineDiagnostics(payload);
    }

    /**
     * Batch sets diagnostic decorations for multiple lines (already encoded as ByteBuffer by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBatchLineDiagnostics(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetBatchLineDiagnostics(mNativeHandle, payload, payload.remaining()));
    }

    @NonNull
    public EditorActionResult setLineDocumentHighlights(int line, @NonNull List<? extends DocumentHighlight> items) {
        if (mNativeHandle == 0 || items == null) return new EditorActionResult();
        return setLineDocumentHighlights(CoreProtocol.encodeSetLineDocumentHighlightsPayload(line, items));
    }

    @NonNull
    public EditorActionResult setLineDocumentHighlights(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineDocumentHighlights(mNativeHandle, payload, payload.remaining()));
    }

    @Nullable
    public EditorActionResult setBatchLineDocumentHighlights(@Nullable SparseArray<? extends List<? extends DocumentHighlight>> highlightsByLine) {
        if (mNativeHandle == 0 || highlightsByLine == null || highlightsByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineDocumentHighlightsPayload(highlightsByLine);
        return setBatchLineDocumentHighlights(payload);
    }

    @NonNull
    public EditorActionResult setBatchLineDocumentHighlights(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetBatchLineDocumentHighlights(mNativeHandle, payload, payload.remaining()));
    }

    @NonNull
    public EditorActionResult clearDocumentHighlights() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearDocumentHighlights(mNativeHandle));
    }

    // ==================== Guide (Code Structure Lines) ====================

    /**
     * Sets indent guide list (global replace).
     *
     * @param guides Indent guide list
     */
    @NonNull
    public EditorActionResult setIndentGuides(@NonNull List<? extends IndentGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return new EditorActionResult();
        return setIndentGuides(CoreProtocol.encodeSetIndentGuidesPayload(guides));
    }

    /**
     * Sets indent guide list (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setIndentGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetIndentGuides(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets bracket guide list (global replace).
     *
     * @param guides Bracket guide list
     */
    @NonNull
    public EditorActionResult setBracketGuides(@NonNull List<? extends BracketGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return new EditorActionResult();
        return setBracketGuides(CoreProtocol.encodeSetBracketGuidesPayload(guides));
    }

    /**
     * Sets bracket guide list (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setBracketGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetBracketGuides(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets flow guide list (global replace).
     *
     * @param guides Flow guide list
     */
    @NonNull
    public EditorActionResult setFlowGuides(@NonNull List<? extends FlowGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return new EditorActionResult();
        return setFlowGuides(CoreProtocol.encodeSetFlowGuidesPayload(guides));
    }

    /**
     * Sets flow guide list (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setFlowGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetFlowGuides(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Sets separator guide list (global replace).
     *
     * @param guides Separator guide list
     */
    @NonNull
    public EditorActionResult setSeparatorGuides(@NonNull List<? extends SeparatorGuide> guides) {
        if (mNativeHandle == 0 || guides == null) return new EditorActionResult();
        return setSeparatorGuides(CoreProtocol.encodeSetSeparatorGuidesPayload(guides));
    }

    /**
     * Sets separator guide list (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setSeparatorGuides(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetBracketPairs(mNativeHandle, openChars, closeChars));
    }

    /**
     * Sets auto-closing pairs for automatic bracket completion.
     * @param openChars Open bracket character code array
     * @param closeChars Close bracket character code array
     */
    @NonNull
    public EditorActionResult setAutoClosingPairs(int[] openChars, int[] closeChars) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetAutoClosingPairs(mNativeHandle, openChars, closeChars));
    }

    /**
     * Sets exact bracket match result externally (overrides built-in character scan).
     */
    @NonNull
    public EditorActionResult setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeSetMatchedBrackets(mNativeHandle, openLine, openCol, closeLine, closeCol));
    }

    /**
     * Clears externally set bracket match result (falls back to built-in character scan).
     */
    @NonNull
    public EditorActionResult clearMatchedBrackets() {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0 || regions == null) return new EditorActionResult();
        return setFoldRegions(CoreProtocol.encodeSetFoldRegionsPayload(regions));
    }

    /**
     * Sets foldable region list (already encoded by caller).
     *
     * @param payload Packed ByteBuffer
     */
    @NonNull
    public EditorActionResult setFoldRegions(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeUnfoldAt(mNativeHandle, line));
    }

    /** Folds all regions. */
    @NonNull
    public EditorActionResult foldAll() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeFoldAll(mNativeHandle));
    }

    /** Unfolds all regions. */
    @NonNull
    public EditorActionResult unfoldAll() {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer data = nativeInsertSnippet(mNativeHandle, snippetTemplate);
        try {
            return CoreProtocol.decodeEditorActionResult(data);
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
        if (mNativeHandle == 0) return new EditorActionResult();
        ByteBuffer payload = CoreProtocol.encodeStartLinkedEditingPayload(model);
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeLinkedEditingNext(mNativeHandle));
    }

    /**
     * Linked editing: jumps to the previous tab stop.
     *
     * @return false if already at first
     */
    @NonNull
    public EditorActionResult linkedEditingPrev() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeLinkedEditingPrev(mNativeHandle));
    }

    /**
     * Cancels linked editing mode.
     */
    @NonNull
    public EditorActionResult cancelLinkedEditing() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeCancelLinkedEditing(mNativeHandle));
    }

    // ==================== Clear Operations ====================

    /** Clears all highlight spans. */
    @NonNull
    public EditorActionResult clearHighlights() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearHighlights(mNativeHandle));
    }

    /**
     * Clears highlight spans for the specified layer.
     *
     * @param layer Layer 0 / 1
     */
    @NonNull
    public EditorActionResult clearHighlights(int layer) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearHighlightsLayer(mNativeHandle, layer));
    }

    @NonNull
    public EditorActionResult clearLineSpans(int line, int layer) {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearLineSpans(mNativeHandle, line, layer));
    }

    /** Clears all Inlay Hints. */
    @NonNull
    public EditorActionResult clearInlayHints() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearInlayHints(mNativeHandle));
    }

    /** Clears all phantom text. */
    @NonNull
    public EditorActionResult clearPhantomTexts() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearPhantomTexts(mNativeHandle));
    }

    /** Clears all gutter icons. */
    @NonNull
    public EditorActionResult clearGutterIcons() {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0 || items == null) return new EditorActionResult();
        return setLineCodeLens(CoreProtocol.encodeSetLineCodeLensPayload(line, items));
    }

    /**
     * Sets CodeLens items for the specified line (already encoded by caller).
     */
    @NonNull
    public EditorActionResult setLineCodeLens(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineCodeLens(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets CodeLens items for multiple lines (reduces JNI calls).
     */
    @Nullable
    public EditorActionResult setBatchLineCodeLens(@Nullable SparseArray<? extends List<? extends CodeLensItem>> itemsByLine) {
        if (mNativeHandle == 0 || itemsByLine == null || itemsByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineCodeLensPayload(itemsByLine);
        return setBatchLineCodeLens(payload);
    }

    /**
     * Batch sets CodeLens items for multiple lines (already encoded as ByteBuffer by caller).
     */
    @NonNull
    public EditorActionResult setBatchLineCodeLens(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetBatchLineCodeLens(mNativeHandle, payload, payload.remaining()));
    }

    /** Clears all CodeLens items. */
    @NonNull
    public EditorActionResult clearCodeLens() {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0 || links == null) return new EditorActionResult();
        return setLineLinks(CoreProtocol.encodeSetLineLinksPayload(line, links));
    }

    /**
     * Sets link ranges for the specified line (already encoded by caller).
     */
    @NonNull
    public EditorActionResult setLineLinks(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetLineLinks(mNativeHandle, payload, payload.remaining()));
    }

    /**
     * Batch sets link ranges for multiple lines (reduces JNI calls).
     */
    @Nullable
    public EditorActionResult setBatchLineLinks(@Nullable SparseArray<? extends List<? extends LinkSpan>> linksByLine) {
        if (mNativeHandle == 0 || linksByLine == null || linksByLine.size() == 0) return null;
        ByteBuffer payload = CoreProtocol.encodeSetBatchLineLinksPayload(linksByLine);
        return setBatchLineLinks(payload);
    }

    /**
     * Batch sets link ranges for multiple lines (already encoded as ByteBuffer by caller).
     */
    @NonNull
    public EditorActionResult setBatchLineLinks(ByteBuffer payload) {
        if (mNativeHandle == 0 || payload == null) return new EditorActionResult();
        return decodeAction(nativeSetBatchLineLinks(mNativeHandle, payload, payload.remaining()));
    }

    /** Clears all link ranges. */
    @NonNull
    public EditorActionResult clearLinks() {
        if (mNativeHandle == 0) return new EditorActionResult();
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
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearGuides(mNativeHandle));
    }

    /** Clears all diagnostic decorations. */
    @NonNull
    public EditorActionResult clearDiagnostics() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearDiagnostics(mNativeHandle));
    }

    /** Clears all decoration data (highlights, Inlay Hints, phantom text, icons, guides, diagnostics). */
    @NonNull
    public EditorActionResult clearAllDecorations() {
        if (mNativeHandle == 0) return new EditorActionResult();
        return decodeAction(nativeClearAllDecorations(mNativeHandle));
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
    private static native ByteBuffer nativeSetRenderWhitespace(long handle, int mode);

    @FastNative
    private static native ByteBuffer nativeSetRenderLineBreaks(long handle, boolean enabled);

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
    private static native ByteBuffer nativeHandleGestureEvent(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeUpdatePointerModifiers(long handle, int modifiers);

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
    private static native ByteBuffer nativeApplyTextEdits(long handle, ByteBuffer data);

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

    @FastNative
    private static native ByteBuffer nativeSearch(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeFindNextSearchMatch(long handle);

    @FastNative
    private static native ByteBuffer nativeFindPreviousSearchMatch(long handle);

    @FastNative
    private static native ByteBuffer nativeReplaceCurrentSearchMatch(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeReplaceAllSearchMatches(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeClearSearch(long handle);

    @FastNative
    private static native ByteBuffer nativeGetSearchState(long handle);

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
    private static native boolean nativeHasPreedit(long handle);

    @FastNative
    private static native ByteBuffer nativeImeHandleCommandMessage(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeImeHandleTextUpdateMessage(long handle, ByteBuffer data, int size);

    @CriticalNative
    private static native int nativeImeGetKeyboardScriptClass(long handle);

    @FastNative
    private static native ByteBuffer nativeGetImeSyncSnapshot(long handle);

    @FastNative
    private static native ByteBuffer nativeGetImeCommandInputContext(long handle, long beforeLength, long afterLength);

    @FastNative
    private static native ByteBuffer nativeGetImeTextUpdateInputContext(long handle, int scope, long beforeLength, long afterLength);

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
    private static native ByteBuffer nativeSetHandleConfig(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetScrollbarConfig(long handle, ByteBuffer data, int size);

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
    private static native ByteBuffer nativeSetEditorRenderColors(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetEditorRangeEffectStyles(long handle, ByteBuffer data, int size);

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
    private static native ByteBuffer nativeSetLineDocumentHighlights(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeSetBatchLineDocumentHighlights(long handle, ByteBuffer data, int size);

    @FastNative
    private static native ByteBuffer nativeClearDocumentHighlights(long handle);

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
