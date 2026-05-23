package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.foundation.*;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.core.ime.ImeTextUnit;
import com.qiplat.sweeteditor.core.keymap.KeyMap;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.core.snippet.*;

import java.lang.ref.Cleaner;
import java.lang.foreign.*;
import java.lang.invoke.MethodType;
import java.nio.ByteBuffer;
import java.util.List;
import java.util.Map;

/**
 * Editor core high-level API, wrapping the EditorNative FFM binding layer.
 * <p>
 * Provides upcall stub setup for text measurement callbacks, binary payload decoding,
 * and Java-friendly interfaces for all editor operations.
 */
public class EditorCore {
    private static final Cleaner CLEANER = Cleaner.create();

    private final long nativeHandle;
    private final Arena arena;
    private final Cleaner.Cleanable cleanable;
    private HandleConfig handleConfig = new HandleConfig();
    private ScrollbarConfig scrollbarConfig = new ScrollbarConfig();

    private static final class CleanupAction implements Runnable {
        private final long nativeHandle;
        private final Arena arena;
        private boolean cleaned;

        private CleanupAction(long nativeHandle, Arena arena) {
            this.nativeHandle = nativeHandle;
            this.arena = arena;
        }

        @Override
        public synchronized void run() {
            if (cleaned) return;
            cleaned = true;
            EditorNative.freeEditor(nativeHandle);
            arena.close();
        }
    }

    public interface TextMeasurer {
        float measureTextWidth(MemorySegment textPtr, int fontStyle);
        float measureInlayHintWidth(MemorySegment textPtr);
        float measureIconWidth(int iconId);
        void getFontMetrics(MemorySegment arrPtr, long length);
    }

    public EditorCore(TextMeasurer callback, EditorOptions options) {
        this.arena = Arena.ofShared();

        MemorySegment measurer = arena.allocate(EditorNative.MEASURER_LAYOUT);

        MemorySegment measureTextStub = EditorNative.createUpcallStub(arena, callback, TextMeasurer.class,
                "measureTextWidth",
                MethodType.methodType(float.class, MemorySegment.class, int.class),
                EditorNative.MEASURE_TEXT_WIDTH_DESC);

        MemorySegment measureInlayStub = EditorNative.createUpcallStub(arena, callback, TextMeasurer.class,
                "measureInlayHintWidth",
                MethodType.methodType(float.class, MemorySegment.class),
                EditorNative.MEASURE_INLAY_HINT_WIDTH_DESC);

        MemorySegment measureIconStub = EditorNative.createUpcallStub(arena, callback, TextMeasurer.class,
                "measureIconWidth",
                MethodType.methodType(float.class, int.class),
                EditorNative.MEASURE_ICON_WIDTH_DESC);

        MemorySegment fontMetricsStub = EditorNative.createUpcallStub(arena, callback, TextMeasurer.class,
                "getFontMetrics",
                MethodType.methodType(void.class, MemorySegment.class, long.class),
                EditorNative.GET_FONT_METRICS_DESC);

        measurer.set(ValueLayout.ADDRESS, 0, measureTextStub);
        measurer.set(ValueLayout.ADDRESS, ValueLayout.ADDRESS.byteSize(), measureInlayStub);
        measurer.set(ValueLayout.ADDRESS, ValueLayout.ADDRESS.byteSize() * 2, measureIconStub);
        measurer.set(ValueLayout.ADDRESS, ValueLayout.ADDRESS.byteSize() * 3, fontMetricsStub);

        MemorySegment optionsSeg = ProtocolEncoder.packEditorOptions(options, arena);
        this.nativeHandle = EditorNative.createEditor(measurer, optionsSeg, ProtocolEncoder.EDITOR_OPTIONS_SIZE);
        this.cleanable = CLEANER.register(this, new CleanupAction(nativeHandle, arena));
    }

    // ===================== Lifecycle =====================

    private Document mDocument;

    public EditorActionResult loadDocument(Document document) {
        if (document == null) return EditorActionResult.EMPTY;
        mDocument = document;
        return decodeAction(EditorNative.setEditorDocument(nativeHandle, document.nativeHandle));
    }

    public Document getDocument() {
        return mDocument;
    }

    // ===================== Viewport/Appearance =====================

    public EditorActionResult setViewport(int width, int height) {
        return decodeAction(EditorNative.setViewport(nativeHandle, width, height));
    }

    public EditorActionResult onFontMetricsChanged() {
        return decodeAction(EditorNative.onFontMetricsChanged(nativeHandle));
    }

    public EditorActionResult setFoldArrowMode(int mode) {
        return decodeAction(EditorNative.setFoldArrowMode(nativeHandle, mode));
    }

    public EditorActionResult setWrapMode(int mode) {
        return decodeAction(EditorNative.setWrapMode(nativeHandle, mode));
    }

    public EditorActionResult setTabSize(int tabSize) {
        return decodeAction(EditorNative.setTabSize(nativeHandle, tabSize));
    }

    public EditorActionResult setInsertSpaces(boolean enabled) {
        return decodeAction(EditorNative.setInsertSpaces(nativeHandle, enabled ? 1 : 0));
    }

    public EditorActionResult setScale(float scale) {
        return decodeAction(EditorNative.setScale(nativeHandle, scale));
    }

    public EditorActionResult setLineSpacing(float add, float mult) {
        return decodeAction(EditorNative.setLineSpacing(nativeHandle, add, mult));
    }

    public EditorActionResult setContentStartPadding(float padding) {
        return decodeAction(EditorNative.setContentStartPadding(nativeHandle, padding));
    }

    public EditorActionResult setShowSplitLine(boolean show) {
        return decodeAction(EditorNative.setShowSplitLine(nativeHandle, show));
    }

    public EditorActionResult setGutterSticky(boolean sticky) {
        return decodeAction(EditorNative.setGutterSticky(nativeHandle, sticky));
    }

    public EditorActionResult setGutterVisible(boolean visible) {
        return decodeAction(EditorNative.setGutterVisible(nativeHandle, visible));
    }

    public EditorActionResult setCurrentLineRenderMode(int mode) {
        return decodeAction(EditorNative.setCurrentLineRenderMode(nativeHandle, mode));
    }

    // ===================== Rendering =====================

    public EditorRenderModel buildRenderModel() {
        EditorNative.NativeBinaryResult result = EditorNative.buildRenderModel(nativeHandle);
        try {
            return ProtocolDecoder.decodeRenderModel(result.asByteBuffer());
        } catch (RuntimeException ignored) {
            return null;
        } finally {
            result.free();
        }
    }

    public LayoutMetrics getLayoutMetrics() {
        EditorNative.NativeBinaryResult result = EditorNative.getLayoutMetrics(nativeHandle);
        try {
            return ProtocolDecoder.decodeLayoutMetrics(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public IntRange getVisibleLineRange() {
        try (Arena tempArena = Arena.ofConfined()) {
            return EditorNative.getVisibleLineRange(nativeHandle, tempArena);
        }
    }

    // ===================== Gesture/Keyboard =====================

    public EditorActionResult handleGestureEvent(int type, float[] points, int modifiers,
                                                 float wheelDeltaX, float wheelDeltaY, float directScale) {
        return handleGestureEventEx(type, points, modifiers, wheelDeltaX, wheelDeltaY, directScale);
    }

    public EditorActionResult handleGestureEventEx(int type, float[] points, int modifiers,
                                                   float wheelDeltaX, float wheelDeltaY, float directScale) {
        try (Arena tempArena = Arena.ofConfined()) {
            int pointerCount = (points != null) ? points.length / 2 : 0;
            if (points == null) points = new float[0];
            EditorNative.NativeBinaryResult result = EditorNative.handleGestureEventEx(nativeHandle, type, pointerCount,
                    tempArena, points, modifiers, wheelDeltaX, wheelDeltaY, directScale);
            return decodeAction(result);
        }
    }

    public EditorActionResult updatePointerModifiers(int modifiers) {
        return decodeAction(EditorNative.updatePointerModifiers(nativeHandle, modifiers));
    }

    /** Advances edge-scroll by one tick and returns an updated gesture result. */
    public EditorActionResult tickEdgeScroll() {
        return decodeAction(EditorNative.tickEdgeScroll(nativeHandle));
    }

    public EditorActionResult tickFling() {
        return decodeAction(EditorNative.tickFling(nativeHandle));
    }

    /** Unified animation tick: advances all active animations (edge-scroll, fling). */
    public EditorActionResult tickAnimations() {
        return decodeAction(EditorNative.tickAnimations(nativeHandle));
    }

    public EditorActionResult handleKeyEvent(int keyCode, String text, int modifiers) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.handleKeyEvent(nativeHandle, keyCode, text, modifiers, tempArena);
            return decodeAction(result);
        }
    }

    public EditorActionResult setKeyMap(KeyMap keyMap) {
        if (keyMap == null) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packKeyMap(keyMap);
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setKeyMap(nativeHandle, payload, tempArena));
        }
    }

    // ===================== Text Editing =====================

    public EditorActionResult insertText(String text) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.insertText(nativeHandle, text, tempArena);
            return decodeAction(result);
        }
    }

    public EditorActionResult replaceText(TextRange range, String newText) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.replaceText(nativeHandle,
                    range.start.line, range.start.column,
                    range.end.line, range.end.column, newText, tempArena);
            return decodeAction(result);
        }
    }

    public EditorActionResult deleteText(TextRange range) {
        EditorNative.NativeBinaryResult result = EditorNative.deleteText(nativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column);
        return decodeAction(result);
    }

    public EditorActionResult backspace() {
        return decodeAction(EditorNative.backspace(nativeHandle));
    }

    public EditorActionResult deleteForward() {
        return decodeAction(EditorNative.deleteForward(nativeHandle));
    }

    public String getSelectedText() {
        return EditorNative.getSelectedText(nativeHandle);
    }

    // ===================== Line Operations =====================

    public EditorActionResult moveLineUp() {
        return decodeAction(EditorNative.moveLineUp(nativeHandle));
    }

    public EditorActionResult moveLineDown() {
        return decodeAction(EditorNative.moveLineDown(nativeHandle));
    }

    public EditorActionResult copyLineUp() {
        return decodeAction(EditorNative.copyLineUp(nativeHandle));
    }

    public EditorActionResult copyLineDown() {
        return decodeAction(EditorNative.copyLineDown(nativeHandle));
    }

    public EditorActionResult deleteLine() {
        return decodeAction(EditorNative.deleteLine(nativeHandle));
    }

    public EditorActionResult insertLineAbove() {
        return decodeAction(EditorNative.insertLineAbove(nativeHandle));
    }

    public EditorActionResult insertLineBelow() {
        return decodeAction(EditorNative.insertLineBelow(nativeHandle));
    }

    // ===================== Undo/Redo =====================

    public EditorActionResult undo() {
        return decodeAction(EditorNative.undo(nativeHandle));
    }

    public EditorActionResult redo() {
        return decodeAction(EditorNative.redo(nativeHandle));
    }

    public boolean canUndo() { return EditorNative.canUndo(nativeHandle); }
    public boolean canRedo() { return EditorNative.canRedo(nativeHandle); }

    // ===================== Cursor/Selection =====================

    public EditorActionResult setCursorPosition(int line, int column) {
        return decodeAction(EditorNative.setCursorPosition(nativeHandle, line, column));
    }

    public EditorActionResult moveCursorLeft(boolean extendSelection) {
        return decodeAction(EditorNative.moveCursorLeft(nativeHandle, extendSelection));
    }

    public EditorActionResult moveCursorRight(boolean extendSelection) {
        return decodeAction(EditorNative.moveCursorRight(nativeHandle, extendSelection));
    }

    public EditorActionResult moveCursorUp(boolean extendSelection) {
        return decodeAction(EditorNative.moveCursorUp(nativeHandle, extendSelection));
    }

    public EditorActionResult moveCursorDown(boolean extendSelection) {
        return decodeAction(EditorNative.moveCursorDown(nativeHandle, extendSelection));
    }

    public EditorActionResult moveCursorToLineStart(boolean extendSelection) {
        return decodeAction(EditorNative.moveCursorToLineStart(nativeHandle, extendSelection));
    }

    public EditorActionResult moveCursorToLineEnd(boolean extendSelection) {
        return decodeAction(EditorNative.moveCursorToLineEnd(nativeHandle, extendSelection));
    }

    public TextPosition getCursorPosition() {
        try (Arena tempArena = Arena.ofConfined()) {
            int[] pos = EditorNative.getCursorPosition(nativeHandle, tempArena);
            return new TextPosition(pos[0], pos[1]);
        }
    }

    public TextRange getWordRangeAtCursor() {
        try (Arena tempArena = Arena.ofConfined()) {
            int[] range = EditorNative.getWordRangeAtCursor(nativeHandle, tempArena);
            return new TextRange(
                    new TextPosition(range[0], range[1]),
                    new TextPosition(range[2], range[3]));
        }
    }

    public String getWordAtCursor() {
        return EditorNative.getWordAtCursor(nativeHandle);
    }

    public EditorActionResult selectAll() {
        return decodeAction(EditorNative.selectAll(nativeHandle));
    }

    public EditorActionResult setSelection(int startLine, int startColumn, int endLine, int endColumn) {
        return decodeAction(EditorNative.setSelection(nativeHandle, startLine, startColumn, endLine, endColumn));
    }

    public TextRange getSelection() {
        try (Arena tempArena = Arena.ofConfined()) {
            int[] sel = EditorNative.getSelection(nativeHandle, tempArena);
            if (sel == null) {
                return null;
            }
            return new TextRange(
                    new TextPosition(sel[0], sel[1]),
                    new TextPosition(sel[2], sel[3]));
        }
    }

    // ===================== IME =====================

    public boolean isComposing() {
        return EditorNative.isComposing(nativeHandle);
    }

    public TextRange getComposingRange() {
        try (Arena tempArena = Arena.ofConfined()) {
            return rangeFromNative(EditorNative.getComposingRange(nativeHandle, tempArena));
        }
    }

    public TextRange getComposingSessionRange() {
        try (Arena tempArena = Arena.ofConfined()) {
            return rangeFromNative(EditorNative.getComposingSessionRange(nativeHandle, tempArena));
        }
    }

    private TextRange rangeFromNative(int[] values) {
        if (values == null || values.length < 4 || values[0] < 0) {
            return null;
        }
        return new TextRange(
                new TextPosition(values[0], values[1]),
                new TextPosition(values[2], values[3]));
    }

    private EditorActionResult decodeAction(EditorNative.NativeBinaryResult result) {
        try {
            return ProtocolDecoder.decodeEditorActionResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public EditorActionResult updateImePreedit(String text, int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.updateImePreedit(
                    nativeHandle, text != null ? text : "", scriptHint, tempArena));
        }
    }

    public EditorActionResult setImeComposingText(String text, int cursorOffset, int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setImeComposingText(
                    nativeHandle, text != null ? text : "", cursorOffset, scriptHint, tempArena));
        }
    }

    public EditorActionResult setImeComposingTextSelection(String text,
                                                           long selectionStartOffset,
                                                           long selectionEndOffset,
                                                           int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setImeComposingTextSelection(
                    nativeHandle,
                    text != null ? text : "",
                    Math.max(0, selectionStartOffset),
                    Math.max(0, selectionEndOffset),
                    scriptHint,
                    tempArena));
        }
    }

    public EditorActionResult commitImeText(String text, int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.commitImeText(
                    nativeHandle, text != null ? text : "", scriptHint, tempArena));
        }
    }

    public EditorActionResult finishImePreedit() {
        return decodeAction(EditorNative.finishImePreedit(nativeHandle));
    }

    public EditorActionResult cancelImePreedit() {
        return decodeAction(EditorNative.cancelImePreedit(nativeHandle));
    }

    public EditorActionResult markImeDocumentRange(TextRange range, int scriptHint) {
        if (range == null || range.start == null || range.end == null) {
            return EditorActionResult.EMPTY;
        }
        return decodeAction(EditorNative.markImeDocumentRange(
                nativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column,
                scriptHint));
    }

    public EditorActionResult markImeDocumentRange(long startOffset, long endOffset, int scriptHint) {
        return decodeAction(EditorNative.markImeDocumentRangeByOffset(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset), scriptHint));
    }

    public EditorActionResult replaceImeText(TextRange range, String text, int scriptHint) {
        if (range == null || range.start == null || range.end == null) {
            return EditorActionResult.EMPTY;
        }
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.replaceImeText(
                    nativeHandle,
                    range.start.line, range.start.column,
                    range.end.line, range.end.column,
                    text != null ? text : "",
                    scriptHint,
                    tempArena));
        }
    }

    public EditorActionResult replaceImeDocumentText(long startOffset,
                                                     long endOffset,
                                                     String text,
                                                     int cursorOffset,
                                                     int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.replaceImeDocumentText(
                    nativeHandle,
                    Math.max(0, startOffset),
                    Math.max(0, endOffset),
                    text != null ? text : "",
                    cursorOffset,
                    scriptHint,
                    tempArena));
        }
    }

    public EditorActionResult replaceImeInputContextText(long startOffset,
                                                         long endOffset,
                                                         String text,
                                                         int cursorOffset,
                                                         int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.replaceImeInputContextText(
                    nativeHandle,
                    Math.max(0, startOffset),
                    Math.max(0, endOffset),
                    text != null ? text : "",
                    cursorOffset,
                    scriptHint,
                    tempArena));
        }
    }

    public EditorActionResult markImeInputContextRange(long startOffset, long endOffset, int scriptHint) {
        return decodeAction(EditorNative.markImeInputContextRange(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset), scriptHint));
    }

    public EditorActionResult notifyImeDocumentSelectionChanged(long startOffset, long endOffset) {
        return decodeAction(EditorNative.notifyImeDocumentSelectionChanged(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset)));
    }

    public EditorActionResult notifyImeInputContextSelectionChanged(long startOffset, long endOffset) {
        return decodeAction(EditorNative.notifyImeInputContextSelectionChanged(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset)));
    }

    public EditorActionResult updateImeInputStateText(long contextId,
                                                      int documentStartOffset,
                                                      String text,
                                                      int selectionStartOffset,
                                                      int selectionEndOffset,
                                                      int composingStartOffset,
                                                      int composingEndOffset,
                                                      int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.updateImeInputStateText(
                    nativeHandle,
                    contextId,
                    Math.max(0, documentStartOffset),
                    text != null ? text : "",
                    selectionStartOffset,
                    selectionEndOffset,
                    composingStartOffset,
                    composingEndOffset,
                    scriptHint,
                    tempArena));
        }
    }

    public EditorActionResult updateImeInputStateSelection(long contextId,
                                                           int documentStartOffset,
                                                           int selectionStartOffset,
                                                           int selectionEndOffset) {
        return decodeAction(EditorNative.updateImeInputStateSelection(
                nativeHandle,
                contextId,
                Math.max(0, documentStartOffset),
                selectionStartOffset,
                selectionEndOffset));
    }

    public EditorActionResult replaceImeInputStateText(long contextId,
                                                       int documentStartOffset,
                                                       long startOffset,
                                                       long endOffset,
                                                       String text,
                                                       int cursorOffset,
                                                       int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.replaceImeInputStateText(
                    nativeHandle,
                    contextId,
                    Math.max(0, documentStartOffset),
                    Math.max(0, startOffset),
                    Math.max(0, endOffset),
                    text != null ? text : "",
                    cursorOffset,
                    scriptHint,
                    tempArena));
        }
    }

    public EditorActionResult deleteImeBackward(long beforeLength, int textUnit) {
        return decodeAction(EditorNative.deleteImeBackward(nativeHandle, beforeLength, textUnit));
    }

    public EditorActionResult deleteImeBackward(long beforeLength) {
        return deleteImeBackward(beforeLength, ImeTextUnit.GRAPHEME);
    }

    public EditorActionResult deleteImeForward(long afterLength, int textUnit) {
        return decodeAction(EditorNative.deleteImeForward(nativeHandle, afterLength, textUnit));
    }

    public EditorActionResult deleteImeForward(long afterLength) {
        return deleteImeForward(afterLength, ImeTextUnit.GRAPHEME);
    }

    public EditorActionResult deleteImeSurrounding(long beforeLength, long afterLength, int textUnit) {
        return decodeAction(EditorNative.deleteImeSurrounding(
                nativeHandle, beforeLength, afterLength, textUnit));
    }

    public EditorActionResult notifyImeSelectionChanged(TextRange range) {
        if (range == null || range.start == null || range.end == null) {
            return EditorActionResult.EMPTY;
        }
        return decodeAction(EditorNative.notifyImeSelectionChanged(
                nativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column));
    }

    public EditorActionResult notifyImeCursorChanged(TextPosition cursor) {
        if (cursor == null) {
            return EditorActionResult.EMPTY;
        }
        return decodeAction(EditorNative.notifyImeCursorChanged(
                nativeHandle, cursor.line, cursor.column));
    }

    public ImeSyncSnapshot getImeSyncSnapshot() {
        EditorNative.NativeBinaryResult result = EditorNative.getImeSyncSnapshot(nativeHandle);
        try {
            return ProtocolDecoder.decodeImeSyncSnapshot(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public ImeInputContext getImeInputContext(long beforeLength, long afterLength) {
        EditorNative.NativeBinaryResult result = EditorNative.getImeInputContext(
                nativeHandle, Math.max(0, beforeLength), Math.max(0, afterLength));
        try {
            return ProtocolDecoder.decodeImeInputContext(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public EditorActionResult setImeKeyboardScriptClass(int scriptClass) {
        return decodeAction(EditorNative.setImeKeyboardScriptClass(nativeHandle, scriptClass));
    }

    public int getImeKeyboardScriptClass() {
        return EditorNative.getImeKeyboardScriptClass(nativeHandle);
    }

    // ===================== Read-only =====================

    public EditorActionResult setReadOnly(boolean readOnly) { return decodeAction(EditorNative.setReadOnly(nativeHandle, readOnly)); }
    public boolean isReadOnly() { return EditorNative.isReadOnly(nativeHandle); }

    // ===================== Auto-indent =====================

    public EditorActionResult setAutoIndentMode(int mode) { return decodeAction(EditorNative.setAutoIndentMode(nativeHandle, mode)); }
    public int getAutoIndentMode() { return EditorNative.getAutoIndentMode(nativeHandle); }

    public EditorActionResult setBackspaceUnindent(boolean enabled) {
        return decodeAction(EditorNative.setBackspaceUnindent(nativeHandle, enabled ? 1 : 0));
    }

    // ===================== Handle Config =====================

    /** Selection handle hit-test configuration */
    public static class HandleConfig {
        public final float startLeft, startTop, startRight, startBottom;
        public final float endLeft, endTop, endRight, endBottom;

        public HandleConfig() {
            this(-32.1f, -8f, 8f, 32.1f, -8f, -8f, 32.1f, 32.1f);
        }

        public HandleConfig(float startLeft, float startTop, float startRight, float startBottom,
                            float endLeft, float endTop, float endRight, float endBottom) {
            this.startLeft = startLeft;
            this.startTop = startTop;
            this.startRight = startRight;
            this.startBottom = startBottom;
            this.endLeft = endLeft;
            this.endTop = endTop;
            this.endRight = endRight;
            this.endBottom = endBottom;
        }
    }

    public EditorActionResult setHandleConfig(HandleConfig config) {
        if (config == null) return EditorActionResult.EMPTY;
        this.handleConfig = config;
        return decodeAction(EditorNative.setHandleConfig(nativeHandle,
                config.startLeft, config.startTop, config.startRight, config.startBottom,
                config.endLeft, config.endTop, config.endRight, config.endBottom));
    }

    public HandleConfig getHandleConfig() {
        return handleConfig;
    }

    // ===================== Scrollbar Config =====================

    /** Scrollbar geometry configuration */
    public static class ScrollbarConfig {
        public enum ScrollbarMode {
            ALWAYS(0),
            TRANSIENT(1),
            NEVER(2);

            public final int value;

            ScrollbarMode(int value) {
                this.value = value;
            }
        }

        public enum ScrollbarTrackTapMode {
            JUMP(0),
            DISABLED(1);

            public final int value;

            ScrollbarTrackTapMode(int value) {
                this.value = value;
            }
        }

        public final float thickness;
        public final float minThumb;
        public final float thumbHitPadding;
        public final ScrollbarMode mode;
        public final boolean thumbDraggable;
        public final ScrollbarTrackTapMode trackTapMode;
        public final int fadeDelayMs;
        public final int fadeDurationMs;

        public ScrollbarConfig() {
            this(10.0f, 24.0f, 0.0f, ScrollbarMode.ALWAYS, true, ScrollbarTrackTapMode.JUMP, 700, 300);
        }

        public ScrollbarConfig(float thickness, float minThumb) {
            this(thickness, minThumb, 0.0f, ScrollbarMode.ALWAYS, true, ScrollbarTrackTapMode.JUMP, 700, 300);
        }

        public ScrollbarConfig(float thickness, float minThumb, float thumbHitPadding,
                               ScrollbarMode mode, boolean thumbDraggable, ScrollbarTrackTapMode trackTapMode,
                               int fadeDelayMs, int fadeDurationMs) {
            this.thickness = thickness;
            this.minThumb = minThumb;
            this.thumbHitPadding = thumbHitPadding;
            this.mode = mode;
            this.thumbDraggable = thumbDraggable;
            this.trackTapMode = trackTapMode;
            this.fadeDelayMs = fadeDelayMs;
            this.fadeDurationMs = fadeDurationMs;
        }
    }

    public EditorActionResult setScrollbarConfig(ScrollbarConfig config) {
        if (config == null) return EditorActionResult.EMPTY;
        this.scrollbarConfig = config;
        return decodeAction(EditorNative.setScrollbarConfig(
                nativeHandle,
                config.thickness,
                config.minThumb,
                config.thumbHitPadding,
                config.mode.value,
                config.thumbDraggable,
                config.trackTapMode.value,
                config.fadeDelayMs,
                config.fadeDurationMs));
    }

    public ScrollbarConfig getScrollbarConfig() {
        return scrollbarConfig;
    }

    // ===================== Position/Coordinate Query =====================

    public CursorRect getPositionRect(int line, int column) {
        try (Arena arena = Arena.ofConfined()) {
            float[] data = EditorNative.getPositionRect(nativeHandle, line, column, arena);
            return new CursorRect(data[0], data[1], data[2]);
        }
    }

    public CursorRect getCursorRect() {
        try (Arena arena = Arena.ofConfined()) {
            float[] data = EditorNative.getCursorRect(nativeHandle, arena);
            return new CursorRect(data[0], data[1], data[2]);
        }
    }

    // ===================== Scroll/Navigation =====================

    public EditorActionResult scrollToLine(int line, int behavior) {
        return decodeAction(EditorNative.scrollToLine(nativeHandle, line, behavior));
    }

    public EditorActionResult gotoPosition(int line, int column) {
        return decodeAction(EditorNative.gotoLine(nativeHandle, line, column));
    }

    public EditorActionResult ensureCursorVisible() {
        return decodeAction(EditorNative.ensureCursorVisible(nativeHandle));
    }

    public EditorActionResult setScroll(float scrollX, float scrollY) {
        return decodeAction(EditorNative.setScroll(nativeHandle, scrollX, scrollY));
    }

    public ScrollMetrics getScrollMetrics() {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.getScrollMetrics(nativeHandle, tempArena);
            try {
                return ProtocolDecoder.decodeScrollMetrics(result.asByteBuffer());
            } finally {
                result.free();
            }
        }
    }

    // ===================== Style Registration + Highlight Spans =====================

    public EditorActionResult registerTextStyle(int styleId, int color, int bgColor, int fontStyle) {
        return decodeAction(EditorNative.registerTextStyle(nativeHandle, styleId, color, bgColor, fontStyle));
    }

    public EditorActionResult registerTextStyle(int styleId, int color, int fontStyle) {
        return registerTextStyle(styleId, color, 0, fontStyle);
    }

    public EditorActionResult registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles) {
        if (textStyles == null || textStyles.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchTextStyles(textStyles);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.registerBatchTextStyles(nativeHandle, payload, tempArena));
        }
    }

    /** Set highlight spans for a specific line (model overload) */
    public EditorActionResult setLineSpans(int line, int layer, List<? extends StyleSpan> spans) {
        if (spans == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineSpans(line, layer, spans);
            return decodeAction(EditorNative.setLineSpans(nativeHandle, payload, tempArena));
        }
    }

    /** Set highlight spans for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineSpans(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineSpans(nativeHandle, payload, size));
    }

    /** Batch set highlight spans for multiple lines (model overload) */
    public EditorActionResult setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine) {
        if (spansByLine == null || spansByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLineSpans(layer, spansByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLineSpans(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set highlight spans for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineSpans(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineSpans(nativeHandle, payload, size));
    }

    // ===================== InlayHint =====================

    /** Set Inlay Hints for a specific line (model overload, replaces entire line) */
    public EditorActionResult setLineInlayHints(int line, List<? extends InlayHint> hints) {
        if (hints == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineInlayHints(line, hints);
            return decodeAction(EditorNative.setLineInlayHints(nativeHandle, payload, tempArena));
        }
    }

    /** Set Inlay Hints for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineInlayHints(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineInlayHints(nativeHandle, payload, size));
    }

    /** Batch set Inlay Hints for multiple lines */
    public EditorActionResult setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine) {
        if (hintsByLine == null || hintsByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLineInlayHints(hintsByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLineInlayHints(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set Inlay Hints for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineInlayHints(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineInlayHints(nativeHandle, payload, size));
    }

    // ===================== PhantomText =====================

    /** Set phantom texts for a specific line (model overload, replaces entire line) */
    public EditorActionResult setLinePhantomTexts(int line, List<? extends PhantomText> phantoms) {
        if (phantoms == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLinePhantomTexts(line, phantoms);
            return decodeAction(EditorNative.setLinePhantomTexts(nativeHandle, payload, tempArena));
        }
    }

    /** Set phantom texts for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLinePhantomTexts(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLinePhantomTexts(nativeHandle, payload, size));
    }

    /** Batch set phantom texts for multiple lines */
    public EditorActionResult setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine) {
        if (phantomsByLine == null || phantomsByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLinePhantomTexts(phantomsByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLinePhantomTexts(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set phantom texts for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLinePhantomTexts(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLinePhantomTexts(nativeHandle, payload, size));
    }

    // ===================== Gutter Icons =====================

    /** Set gutter icons for a specific line (model overload, replaces entire line) */
    public EditorActionResult setLineGutterIcons(int line, List<? extends GutterIcon> icons) {
        if (icons == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineGutterIcons(line, icons);
            return decodeAction(EditorNative.setLineGutterIcons(nativeHandle, payload, tempArena));
        }
    }

    /** Set gutter icons for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineGutterIcons(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineGutterIcons(nativeHandle, payload, size));
    }

    /** Batch set gutter icons for multiple lines */
    public EditorActionResult setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine) {
        if (iconsByLine == null || iconsByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLineGutterIcons(iconsByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLineGutterIcons(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set gutter icons for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineGutterIcons(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineGutterIcons(nativeHandle, payload, size));
    }

    public EditorActionResult setMaxGutterIcons(int count) {
        return decodeAction(EditorNative.setMaxGutterIcons(nativeHandle, count));
    }

    // ===================== CodeLens =====================

    /** Set CodeLens items for a specific line */
    public EditorActionResult setLineCodeLens(int line, List<? extends CodeLensItem> items) {
        if (items == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineCodeLens(line, items);
            return decodeAction(EditorNative.setLineCodeLens(nativeHandle, payload, tempArena));
        }
    }

    /** Set CodeLens items for a specific line (zero-copy overload) */
    public EditorActionResult setLineCodeLens(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineCodeLens(nativeHandle, payload, size));
    }

    /** Batch set CodeLens items for multiple lines */
    public EditorActionResult setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine) {
        if (itemsByLine == null || itemsByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLineCodeLens(itemsByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLineCodeLens(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set CodeLens items for multiple lines (zero-copy overload) */
    public EditorActionResult setBatchLineCodeLens(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineCodeLens(nativeHandle, payload, size));
    }

    /** Clears all CodeLens items */
    public EditorActionResult clearCodeLens() {
        return decodeAction(EditorNative.clearCodeLens(nativeHandle));
    }

    // ===================== Links =====================

    /** Set link spans for a specific line */
    public EditorActionResult setLineLinks(int line, List<? extends LinkSpan> links) {
        if (links == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineLinks(line, links);
            return decodeAction(EditorNative.setLineLinks(nativeHandle, payload, tempArena));
        }
    }

    /** Set link spans for a specific line (zero-copy overload) */
    public EditorActionResult setLineLinks(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineLinks(nativeHandle, payload, size));
    }

    /** Batch set link spans for multiple lines */
    public EditorActionResult setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine) {
        if (linksByLine == null || linksByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLineLinks(linksByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLineLinks(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set link spans for multiple lines (zero-copy overload) */
    public EditorActionResult setBatchLineLinks(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineLinks(nativeHandle, payload, size));
    }

    /** Clears all link spans */
    public EditorActionResult clearLinks() {
        return decodeAction(EditorNative.clearLinks(nativeHandle));
    }

    /** Returns the link target at the given position, or null if no link exists there */
    public String getLinkTargetAt(int line, int column) {
        return EditorNative.getLinkTargetAt(nativeHandle, line, column);
    }

    // ===================== Diagnostics =====================

    /** Set diagnostic decorations for a specific line (model overload) */
    public EditorActionResult setLineDiagnostics(int line, List<? extends Diagnostic> items) {
        if (items == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineDiagnostics(line, items);
            return decodeAction(EditorNative.setLineDiagnostics(nativeHandle, payload, tempArena));
        }
    }

    /** Set diagnostic decorations for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineDiagnostics(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineDiagnostics(nativeHandle, payload, size));
    }

    /** Batch set diagnostic decorations for multiple lines */
    public EditorActionResult setBatchLineDiagnostics(Map<Integer, ? extends List<? extends Diagnostic>> diagsByLine) {
        if (diagsByLine == null || diagsByLine.isEmpty()) return EditorActionResult.EMPTY;
        byte[] payload = ProtocolEncoder.packBatchLineDiagnostics(diagsByLine);
        if (payload == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBatchLineDiagnostics(nativeHandle, payload, tempArena));
        }
    }

    /** Batch set diagnostic decorations for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineDiagnostics(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineDiagnostics(nativeHandle, payload, size));
    }

    // ===================== Guide (Code Structure Lines) =====================

    /** Set indent guide list (global replacement) */
    public EditorActionResult setIndentGuides(List<? extends IndentGuide> guides) {
        if (guides == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packIndentGuides(guides);
            return decodeAction(EditorNative.setIndentGuides(nativeHandle, payload, tempArena));
        }
    }

    /** Set indent guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setIndentGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setIndentGuides(nativeHandle, payload, size));
    }

    /** Set bracket pair guide list (global replacement) */
    public EditorActionResult setBracketGuides(List<? extends BracketGuide> guides) {
        if (guides == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packBracketGuides(guides);
            return decodeAction(EditorNative.setBracketGuides(nativeHandle, payload, tempArena));
        }
    }

    /** Set bracket pair guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBracketGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBracketGuides(nativeHandle, payload, size));
    }

    /** Set control flow return arrow list (global replacement) */
    public EditorActionResult setFlowGuides(List<? extends FlowGuide> guides) {
        if (guides == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packFlowGuides(guides);
            return decodeAction(EditorNative.setFlowGuides(nativeHandle, payload, tempArena));
        }
    }

    /** Set control flow return arrow list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setFlowGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setFlowGuides(nativeHandle, payload, size));
    }

    /** Set separator guide list (global replacement) */
    public EditorActionResult setSeparatorGuides(List<? extends SeparatorGuide> guides) {
        if (guides == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packSeparatorGuides(guides);
            return decodeAction(EditorNative.setSeparatorGuides(nativeHandle, payload, tempArena));
        }
    }

    /** Set separator guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setSeparatorGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setSeparatorGuides(nativeHandle, payload, size));
    }

    // ===================== Bracket Pair Highlight =====================

    public EditorActionResult setBracketPairs(int[] openChars, int[] closeChars) {
        try (Arena arena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setBracketPairs(nativeHandle, openChars, closeChars, arena));
        }
    }

    public EditorActionResult setAutoClosingPairs(int[] openChars, int[] closeChars) {
        try (Arena arena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setAutoClosingPairs(nativeHandle, openChars, closeChars, arena));
        }
    }

    public EditorActionResult setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol) {
        return decodeAction(EditorNative.setMatchedBrackets(nativeHandle, openLine, openCol, closeLine, closeCol));
    }

    // ===================== Fold =====================

    /** Set foldable regions using a FoldRegion list (model overload) */
    public EditorActionResult setFoldRegions(List<? extends FoldRegion> regions) {
        if (regions == null) return EditorActionResult.EMPTY;
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.setFoldRegions(nativeHandle, ProtocolEncoder.packFoldRegions(regions), tempArena));
        }
    }

    /** Set foldable regions (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setFoldRegions(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setFoldRegions(nativeHandle, payload, size));
    }

    public EditorActionResult toggleFoldAt(int line) { return decodeAction(EditorNative.toggleFold(nativeHandle, line)); }
    public EditorActionResult foldAt(int line) { return decodeAction(EditorNative.foldAt(nativeHandle, line)); }
    public EditorActionResult unfoldAt(int line) { return decodeAction(EditorNative.unfoldAt(nativeHandle, line)); }
    public EditorActionResult foldAll() { return decodeAction(EditorNative.foldAll(nativeHandle)); }
    public EditorActionResult unfoldAll() { return decodeAction(EditorNative.unfoldAll(nativeHandle)); }
    public boolean isLineVisible(int line) { return EditorNative.isLineVisible(nativeHandle, line); }

    // ===================== Linked Editing =====================

    public EditorActionResult insertSnippet(String snippetTemplate) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.insertSnippet(nativeHandle, snippetTemplate, tempArena);
            return decodeAction(result);
        }
    }

    public EditorActionResult startLinkedEditing(LinkedEditingModel model) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeAction(EditorNative.startLinkedEditing(nativeHandle, ProtocolEncoder.packLinkedEditingModel(model), tempArena));
        }
    }

    public boolean isInLinkedEditing() { return EditorNative.isInLinkedEditing(nativeHandle); }
    public EditorActionResult linkedEditingNext() { return decodeAction(EditorNative.linkedEditingNext(nativeHandle)); }
    public EditorActionResult linkedEditingPrev() { return decodeAction(EditorNative.linkedEditingPrev(nativeHandle)); }
    public EditorActionResult cancelLinkedEditing() { return decodeAction(EditorNative.cancelLinkedEditing(nativeHandle)); }

    // ===================== Clear =====================

    public EditorActionResult clearHighlights() { return decodeAction(EditorNative.clearHighlights(nativeHandle)); }
    public EditorActionResult clearHighlightsLayer(int layer) { return decodeAction(EditorNative.clearHighlightsLayer(nativeHandle, layer)); }
    public EditorActionResult clearLineSpans(int line, int layer) { return decodeAction(EditorNative.clearLineSpans(nativeHandle, line, layer)); }
    public EditorActionResult clearHighlights(int layer) { return decodeAction(EditorNative.clearHighlightsLayer(nativeHandle, layer)); }
    public EditorActionResult clearInlayHints() { return decodeAction(EditorNative.clearInlayHints(nativeHandle)); }
    public EditorActionResult clearPhantomTexts() { return decodeAction(EditorNative.clearPhantomTexts(nativeHandle)); }
    public EditorActionResult clearGutterIcons() { return decodeAction(EditorNative.clearGutterIcons(nativeHandle)); }
    public EditorActionResult clearGuides() { return decodeAction(EditorNative.clearGuides(nativeHandle)); }
    public EditorActionResult clearDiagnostics() { return decodeAction(EditorNative.clearDiagnostics(nativeHandle)); }
    public EditorActionResult clearMatchedBrackets() { return decodeAction(EditorNative.clearMatchedBrackets(nativeHandle)); }
    public EditorActionResult clearAllDecorations() { return decodeAction(EditorNative.clearAllDecorations(nativeHandle)); }

    public static final class EditorActionResult {
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
        public final List<TextChange> changes;
        public final TextPosition cursorBefore;
        public final TextPosition cursorAfter;
        public final boolean hasSelectionBefore;
        public final TextRange selectionBefore;
        public final boolean hasSelectionAfter;
        public final TextRange selectionAfter;
        public final float scrollXBefore;
        public final float scrollYBefore;
        public final float scrollXAfter;
        public final float scrollYAfter;
        public final float scaleBefore;
        public final float scaleAfter;
        public final int pointerCursorBefore;
        public final int pointerCursorAfter;
        public final ImeSyncSnapshot imeSync;
        public final GestureType gestureType;
        public final int gestureEventType;
        public final PointF tapPoint;
        public final HitTarget hitTarget;
        public final int modifiers;
        public final int command;

        public static final EditorActionResult EMPTY = new EditorActionResult();

        public EditorActionResult() {
            this(false, false, 0,
                    false, false, false, false, false, false, false, false, false,
                    false, false, false, false,
                    java.util.Collections.emptyList(),
                    new TextPosition(-1, -1),
                    new TextPosition(-1, -1),
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
                    0,
                    new PointF(),
                    defaultHitTarget(),
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
                                  List<TextChange> changes,
                                  TextPosition cursorBefore,
                                  TextPosition cursorAfter,
                                  boolean hasSelectionBefore,
                                  TextRange selectionBefore,
                                  boolean hasSelectionAfter,
                                  TextRange selectionAfter,
                                  float scrollXBefore,
                                  float scrollYBefore,
                                  float scrollXAfter,
                                  float scrollYAfter,
                                  float scaleBefore,
                                  float scaleAfter,
                                  int pointerCursorBefore,
                                  int pointerCursorAfter,
                                  ImeSyncSnapshot imeSync,
                                  GestureType gestureType,
                                  int gestureEventType,
                                  PointF tapPoint,
                                  HitTarget hitTarget,
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

        private static HitTarget defaultHitTarget() {
            HitTarget target = new HitTarget();
            target.type = HitTargetType.NONE;
            return target;
        }
    }
}
