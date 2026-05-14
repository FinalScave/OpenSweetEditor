package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.foundation.*;
import com.qiplat.sweeteditor.core.ime.ImeActionResult;
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

    public void loadDocument(Document document) {
        if (document == null) return;
        mDocument = document;
        EditorNative.setEditorDocument(nativeHandle, document.nativeHandle);
    }

    public Document getDocument() {
        return mDocument;
    }

    // ===================== Viewport/Appearance =====================

    public void setViewport(int width, int height) {
        EditorNative.setViewport(nativeHandle, width, height);
    }

    public void onFontMetricsChanged() {
        EditorNative.onFontMetricsChanged(nativeHandle);
    }

    public void setFoldArrowMode(int mode) {
        EditorNative.setFoldArrowMode(nativeHandle, mode);
    }

    public void setWrapMode(int mode) {
        EditorNative.setWrapMode(nativeHandle, mode);
    }

    public void setTabSize(int tabSize) {
        EditorNative.setTabSize(nativeHandle, tabSize);
    }

    public void setInsertSpaces(boolean enabled) {
        EditorNative.setInsertSpaces(nativeHandle, enabled ? 1 : 0);
    }

    public void setScale(float scale) {
        EditorNative.setScale(nativeHandle, scale);
    }

    public void setLineSpacing(float add, float mult) {
        EditorNative.setLineSpacing(nativeHandle, add, mult);
    }

    public void setContentStartPadding(float padding) {
        EditorNative.setContentStartPadding(nativeHandle, padding);
    }

    public void setShowSplitLine(boolean show) {
        EditorNative.setShowSplitLine(nativeHandle, show);
    }

    public void setGutterSticky(boolean sticky) {
        EditorNative.setGutterSticky(nativeHandle, sticky);
    }

    public void setGutterVisible(boolean visible) {
        EditorNative.setGutterVisible(nativeHandle, visible);
    }

    public void setCurrentLineRenderMode(int mode) {
        EditorNative.setCurrentLineRenderMode(nativeHandle, mode);
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

    public GestureResult handleGestureEvent(int type, float[] points, int modifiers,
                                            float wheelDeltaX, float wheelDeltaY, float directScale) {
        return handleGestureEventEx(type, points, modifiers, wheelDeltaX, wheelDeltaY, directScale);
    }

    public GestureResult handleGestureEventEx(int type, float[] points, int modifiers,
                                              float wheelDeltaX, float wheelDeltaY, float directScale) {
        try (Arena tempArena = Arena.ofConfined()) {
            int pointerCount = (points != null) ? points.length / 2 : 0;
            if (points == null) points = new float[0];
            EditorNative.NativeBinaryResult result = EditorNative.handleGestureEventEx(nativeHandle, type, pointerCount,
                    tempArena, points, modifiers, wheelDeltaX, wheelDeltaY, directScale);
            try {
                return ProtocolDecoder.decodeGestureResult(result.asByteBuffer());
            } finally {
                result.free();
            }
        }
    }

    /** Advances edge-scroll by one tick and returns an updated gesture result. */
    public GestureResult tickEdgeScroll() {
        EditorNative.NativeBinaryResult result = EditorNative.tickEdgeScroll(nativeHandle);
        try {
            return ProtocolDecoder.decodeGestureResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public GestureResult tickFling() {
        EditorNative.NativeBinaryResult result = EditorNative.tickFling(nativeHandle);
        try {
            return ProtocolDecoder.decodeGestureResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    /** Unified animation tick: advances all active animations (edge-scroll, fling). */
    public GestureResult tickAnimations() {
        EditorNative.NativeBinaryResult result = EditorNative.tickAnimations(nativeHandle);
        try {
            return ProtocolDecoder.decodeGestureResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public KeyEventResult handleKeyEvent(int keyCode, String text, int modifiers) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.handleKeyEvent(nativeHandle, keyCode, text, modifiers, tempArena);
            try {
                return ProtocolDecoder.decodeKeyEventResult(result.asByteBuffer());
            } finally {
                result.free();
            }
        }
    }

    public void setKeyMap(KeyMap keyMap) {
        if (keyMap == null) return;
        byte[] payload = ProtocolEncoder.packKeyMap(keyMap);
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setKeyMap(nativeHandle, payload, tempArena);
        }
    }

    // ===================== Text Editing =====================

    public TextEditResult insertText(String text) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.insertText(nativeHandle, text, tempArena);
            try {
                return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
            } finally {
                result.free();
            }
        }
    }

    public TextEditResult replaceText(TextRange range, String newText) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.replaceText(nativeHandle,
                    range.start.line, range.start.column,
                    range.end.line, range.end.column, newText, tempArena);
            try {
                return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
            } finally {
                result.free();
            }
        }
    }

    public TextEditResult deleteText(TextRange range) {
        EditorNative.NativeBinaryResult result = EditorNative.deleteText(nativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult backspace() {
        EditorNative.NativeBinaryResult result = EditorNative.backspace(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult deleteForward() {
        EditorNative.NativeBinaryResult result = EditorNative.deleteForward(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public String getSelectedText() {
        return EditorNative.getSelectedText(nativeHandle);
    }

    // ===================== Line Operations =====================

    public TextEditResult moveLineUp() {
        EditorNative.NativeBinaryResult result = EditorNative.moveLineUp(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult moveLineDown() {
        EditorNative.NativeBinaryResult result = EditorNative.moveLineDown(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult copyLineUp() {
        EditorNative.NativeBinaryResult result = EditorNative.copyLineUp(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult copyLineDown() {
        EditorNative.NativeBinaryResult result = EditorNative.copyLineDown(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult deleteLine() {
        EditorNative.NativeBinaryResult result = EditorNative.deleteLine(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult insertLineAbove() {
        EditorNative.NativeBinaryResult result = EditorNative.insertLineAbove(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult insertLineBelow() {
        EditorNative.NativeBinaryResult result = EditorNative.insertLineBelow(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    // ===================== Undo/Redo =====================

    public TextEditResult undo() {
        EditorNative.NativeBinaryResult result = EditorNative.undo(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public TextEditResult redo() {
        EditorNative.NativeBinaryResult result = EditorNative.redo(nativeHandle);
        try {
            return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
        } finally {
            result.free();
        }
    }

    public boolean canUndo() { return EditorNative.canUndo(nativeHandle); }
    public boolean canRedo() { return EditorNative.canRedo(nativeHandle); }

    // ===================== Cursor/Selection =====================

    public void setCursorPosition(int line, int column) {
        EditorNative.setCursorPosition(nativeHandle, line, column);
    }

    public void moveCursorLeft(boolean extendSelection) {
        EditorNative.moveCursorLeft(nativeHandle, extendSelection);
    }

    public void moveCursorRight(boolean extendSelection) {
        EditorNative.moveCursorRight(nativeHandle, extendSelection);
    }

    public void moveCursorUp(boolean extendSelection) {
        EditorNative.moveCursorUp(nativeHandle, extendSelection);
    }

    public void moveCursorDown(boolean extendSelection) {
        EditorNative.moveCursorDown(nativeHandle, extendSelection);
    }

    public void moveCursorToLineStart(boolean extendSelection) {
        EditorNative.moveCursorToLineStart(nativeHandle, extendSelection);
    }

    public void moveCursorToLineEnd(boolean extendSelection) {
        EditorNative.moveCursorToLineEnd(nativeHandle, extendSelection);
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

    public void selectAll() {
        EditorNative.selectAll(nativeHandle);
    }

    public void setSelection(int startLine, int startColumn, int endLine, int endColumn) {
        EditorNative.setSelection(nativeHandle, startLine, startColumn, endLine, endColumn);
    }

    public TextRange getSelection() {
        try (Arena tempArena = Arena.ofConfined()) {
            int[] sel = EditorNative.getSelection(nativeHandle, tempArena);
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

    public ImeActionResult updateImePreedit(String text, int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.updateImePreedit(
                    nativeHandle, text != null ? text : "", scriptHint, tempArena));
        }
    }

    public ImeActionResult setImeComposingText(String text, int cursorOffset, int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.setImeComposingText(
                    nativeHandle, text != null ? text : "", cursorOffset, scriptHint, tempArena));
        }
    }

    public ImeActionResult setImeComposingTextSelection(String text,
                                                        long selectionStartOffset,
                                                        long selectionEndOffset,
                                                        int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.setImeComposingTextSelection(
                    nativeHandle,
                    text != null ? text : "",
                    Math.max(0, selectionStartOffset),
                    Math.max(0, selectionEndOffset),
                    scriptHint,
                    tempArena));
        }
    }

    public ImeActionResult commitImeText(String text, int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.commitImeText(
                    nativeHandle, text != null ? text : "", scriptHint, tempArena));
        }
    }

    public ImeActionResult finishImePreedit() {
        return decodeImeActionResult(EditorNative.finishImePreedit(nativeHandle));
    }

    public ImeActionResult cancelImePreedit() {
        return decodeImeActionResult(EditorNative.cancelImePreedit(nativeHandle));
    }

    public ImeActionResult markImeDocumentRange(TextRange range, int scriptHint) {
        if (range == null || range.start == null || range.end == null) {
            return new ImeActionResult();
        }
        return decodeImeActionResult(EditorNative.markImeDocumentRange(
                nativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column,
                scriptHint));
    }

    public ImeActionResult markImeDocumentRange(long startOffset, long endOffset, int scriptHint) {
        return decodeImeActionResult(EditorNative.markImeDocumentRangeByOffset(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset), scriptHint));
    }

    public ImeActionResult replaceImeText(TextRange range, String text, int scriptHint) {
        if (range == null || range.start == null || range.end == null) {
            return new ImeActionResult();
        }
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.replaceImeText(
                    nativeHandle,
                    range.start.line, range.start.column,
                    range.end.line, range.end.column,
                    text != null ? text : "",
                    scriptHint,
                    tempArena));
        }
    }

    public ImeActionResult replaceImeDocumentText(long startOffset,
                                                  long endOffset,
                                                  String text,
                                                  int cursorOffset,
                                                  int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.replaceImeDocumentText(
                    nativeHandle,
                    Math.max(0, startOffset),
                    Math.max(0, endOffset),
                    text != null ? text : "",
                    cursorOffset,
                    scriptHint,
                    tempArena));
        }
    }

    public ImeActionResult replaceImeInputContextText(long startOffset,
                                                      long endOffset,
                                                      String text,
                                                      int cursorOffset,
                                                      int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.replaceImeInputContextText(
                    nativeHandle,
                    Math.max(0, startOffset),
                    Math.max(0, endOffset),
                    text != null ? text : "",
                    cursorOffset,
                    scriptHint,
                    tempArena));
        }
    }

    public ImeActionResult markImeInputContextRange(long startOffset, long endOffset, int scriptHint) {
        return decodeImeActionResult(EditorNative.markImeInputContextRange(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset), scriptHint));
    }

    public ImeActionResult notifyImeDocumentSelectionChanged(long startOffset, long endOffset) {
        return decodeImeActionResult(EditorNative.notifyImeDocumentSelectionChanged(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset)));
    }

    public ImeActionResult notifyImeInputContextSelectionChanged(long startOffset, long endOffset) {
        return decodeImeActionResult(EditorNative.notifyImeInputContextSelectionChanged(
                nativeHandle, Math.max(0, startOffset), Math.max(0, endOffset)));
    }

    public ImeActionResult updateImeInputStateText(long contextId,
                                                   int documentStartOffset,
                                                   String text,
                                                   int selectionStartOffset,
                                                   int selectionEndOffset,
                                                   int composingStartOffset,
                                                   int composingEndOffset,
                                                   int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.updateImeInputStateText(
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

    public ImeActionResult updateImeInputStateSelection(long contextId,
                                                        int documentStartOffset,
                                                        int selectionStartOffset,
                                                        int selectionEndOffset) {
        return decodeImeActionResult(EditorNative.updateImeInputStateSelection(
                nativeHandle,
                contextId,
                Math.max(0, documentStartOffset),
                selectionStartOffset,
                selectionEndOffset));
    }

    public ImeActionResult replaceImeInputStateText(long contextId,
                                                    int documentStartOffset,
                                                    long startOffset,
                                                    long endOffset,
                                                    String text,
                                                    int cursorOffset,
                                                    int scriptHint) {
        try (Arena tempArena = Arena.ofConfined()) {
            return decodeImeActionResult(EditorNative.replaceImeInputStateText(
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

    public ImeActionResult deleteImeBackward(long beforeLength, int textUnit) {
        return decodeImeActionResult(EditorNative.deleteImeBackward(nativeHandle, beforeLength, textUnit));
    }

    public ImeActionResult deleteImeBackward(long beforeLength) {
        return deleteImeBackward(beforeLength, ImeTextUnit.GRAPHEME);
    }

    public ImeActionResult deleteImeForward(long afterLength, int textUnit) {
        return decodeImeActionResult(EditorNative.deleteImeForward(nativeHandle, afterLength, textUnit));
    }

    public ImeActionResult deleteImeForward(long afterLength) {
        return deleteImeForward(afterLength, ImeTextUnit.GRAPHEME);
    }

    public ImeActionResult deleteImeSurrounding(long beforeLength, long afterLength, int textUnit) {
        return decodeImeActionResult(EditorNative.deleteImeSurrounding(
                nativeHandle, beforeLength, afterLength, textUnit));
    }

    public ImeActionResult notifyImeSelectionChanged(TextRange range) {
        if (range == null || range.start == null || range.end == null) {
            return new ImeActionResult();
        }
        return decodeImeActionResult(EditorNative.notifyImeSelectionChanged(
                nativeHandle,
                range.start.line, range.start.column,
                range.end.line, range.end.column));
    }

    public ImeActionResult notifyImeCursorChanged(TextPosition cursor) {
        if (cursor == null) {
            return new ImeActionResult();
        }
        return decodeImeActionResult(EditorNative.notifyImeCursorChanged(
                nativeHandle, cursor.line, cursor.column));
    }

    private ImeActionResult decodeImeActionResult(EditorNative.NativeBinaryResult result) {
        try {
            return ProtocolDecoder.decodeImeActionResult(result.asByteBuffer());
        } finally {
            result.free();
        }
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

    public void setImeKeyboardScriptClass(int scriptClass) {
        EditorNative.setImeKeyboardScriptClass(nativeHandle, scriptClass);
    }

    public int getImeKeyboardScriptClass() {
        return EditorNative.getImeKeyboardScriptClass(nativeHandle);
    }

    // ===================== Read-only =====================

    public void setReadOnly(boolean readOnly) { EditorNative.setReadOnly(nativeHandle, readOnly); }
    public boolean isReadOnly() { return EditorNative.isReadOnly(nativeHandle); }

    // ===================== Auto-indent =====================

    public void setAutoIndentMode(int mode) { EditorNative.setAutoIndentMode(nativeHandle, mode); }
    public int getAutoIndentMode() { return EditorNative.getAutoIndentMode(nativeHandle); }

    public void setBackspaceUnindent(boolean enabled) { EditorNative.setBackspaceUnindent(nativeHandle, enabled ? 1 : 0); }

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

    public void setHandleConfig(HandleConfig config) {
        this.handleConfig = config;
        EditorNative.setHandleConfig(nativeHandle,
                config.startLeft, config.startTop, config.startRight, config.startBottom,
                config.endLeft, config.endTop, config.endRight, config.endBottom);
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

    public void setScrollbarConfig(ScrollbarConfig config) {
        this.scrollbarConfig = config;
        EditorNative.setScrollbarConfig(
                nativeHandle,
                config.thickness,
                config.minThumb,
                config.thumbHitPadding,
                config.mode.value,
                config.thumbDraggable,
                config.trackTapMode.value,
                config.fadeDelayMs,
                config.fadeDurationMs);
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

    public void scrollToLine(int line, int behavior) {
        EditorNative.scrollToLine(nativeHandle, line, behavior);
    }

    public void gotoPosition(int line, int column) {
        EditorNative.gotoLine(nativeHandle, line, column);
    }

    public void ensureCursorVisible() {
        EditorNative.ensureCursorVisible(nativeHandle);
    }

    public void setScroll(float scrollX, float scrollY) {
        EditorNative.setScroll(nativeHandle, scrollX, scrollY);
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

    public void registerTextStyle(int styleId, int color, int bgColor, int fontStyle) {
        EditorNative.registerTextStyle(nativeHandle, styleId, color, bgColor, fontStyle);
    }

    public void registerTextStyle(int styleId, int color, int fontStyle) {
        registerTextStyle(styleId, color, 0, fontStyle);
    }

    public void registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles) {
        if (textStyles == null || textStyles.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchTextStyles(textStyles);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.registerBatchTextStyles(nativeHandle, payload, tempArena);
        }
    }

    /** Set highlight spans for a specific line (model overload) */
    public void setLineSpans(int line, int layer, List<? extends StyleSpan> spans) {
        if (spans == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineSpans(line, layer, spans);
            EditorNative.setLineSpans(nativeHandle, payload, tempArena);
        }
    }

    /** Set highlight spans for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setLineSpans(MemorySegment payload, long size) {
        EditorNative.setLineSpans(nativeHandle, payload, size);
    }

    /** Batch set highlight spans for multiple lines (model overload) */
    public void setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine) {
        if (spansByLine == null || spansByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLineSpans(layer, spansByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLineSpans(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set highlight spans for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setBatchLineSpans(MemorySegment payload, long size) {
        EditorNative.setBatchLineSpans(nativeHandle, payload, size);
    }

    // ===================== InlayHint =====================

    /** Set Inlay Hints for a specific line (model overload, replaces entire line) */
    public void setLineInlayHints(int line, List<? extends InlayHint> hints) {
        if (hints == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineInlayHints(line, hints);
            EditorNative.setLineInlayHints(nativeHandle, payload, tempArena);
        }
    }

    /** Set Inlay Hints for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setLineInlayHints(MemorySegment payload, long size) {
        EditorNative.setLineInlayHints(nativeHandle, payload, size);
    }

    /** Batch set Inlay Hints for multiple lines */
    public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine) {
        if (hintsByLine == null || hintsByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLineInlayHints(hintsByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLineInlayHints(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set Inlay Hints for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setBatchLineInlayHints(MemorySegment payload, long size) {
        EditorNative.setBatchLineInlayHints(nativeHandle, payload, size);
    }

    // ===================== PhantomText =====================

    /** Set phantom texts for a specific line (model overload, replaces entire line) */
    public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms) {
        if (phantoms == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLinePhantomTexts(line, phantoms);
            EditorNative.setLinePhantomTexts(nativeHandle, payload, tempArena);
        }
    }

    /** Set phantom texts for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setLinePhantomTexts(MemorySegment payload, long size) {
        EditorNative.setLinePhantomTexts(nativeHandle, payload, size);
    }

    /** Batch set phantom texts for multiple lines */
    public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine) {
        if (phantomsByLine == null || phantomsByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLinePhantomTexts(phantomsByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLinePhantomTexts(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set phantom texts for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setBatchLinePhantomTexts(MemorySegment payload, long size) {
        EditorNative.setBatchLinePhantomTexts(nativeHandle, payload, size);
    }

    // ===================== Gutter Icons =====================

    /** Set gutter icons for a specific line (model overload, replaces entire line) */
    public void setLineGutterIcons(int line, List<? extends GutterIcon> icons) {
        if (icons == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineGutterIcons(line, icons);
            EditorNative.setLineGutterIcons(nativeHandle, payload, tempArena);
        }
    }

    /** Set gutter icons for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setLineGutterIcons(MemorySegment payload, long size) {
        EditorNative.setLineGutterIcons(nativeHandle, payload, size);
    }

    /** Batch set gutter icons for multiple lines */
    public void setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine) {
        if (iconsByLine == null || iconsByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLineGutterIcons(iconsByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLineGutterIcons(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set gutter icons for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setBatchLineGutterIcons(MemorySegment payload, long size) {
        EditorNative.setBatchLineGutterIcons(nativeHandle, payload, size);
    }

    public void setMaxGutterIcons(int count) {
        EditorNative.setMaxGutterIcons(nativeHandle, count);
    }

    // ===================== CodeLens =====================

    /** Set CodeLens items for a specific line */
    public void setLineCodeLens(int line, List<? extends CodeLensItem> items) {
        if (items == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineCodeLens(line, items);
            EditorNative.setLineCodeLens(nativeHandle, payload, tempArena);
        }
    }

    /** Set CodeLens items for a specific line (zero-copy overload) */
    public void setLineCodeLens(MemorySegment payload, long size) {
        EditorNative.setLineCodeLens(nativeHandle, payload, size);
    }

    /** Batch set CodeLens items for multiple lines */
    public void setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine) {
        if (itemsByLine == null || itemsByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLineCodeLens(itemsByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLineCodeLens(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set CodeLens items for multiple lines (zero-copy overload) */
    public void setBatchLineCodeLens(MemorySegment payload, long size) {
        EditorNative.setBatchLineCodeLens(nativeHandle, payload, size);
    }

    /** Clears all CodeLens items */
    public void clearCodeLens() {
        EditorNative.clearCodeLens(nativeHandle);
    }

    // ===================== Links =====================

    /** Set link spans for a specific line */
    public void setLineLinks(int line, List<? extends LinkSpan> links) {
        if (links == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineLinks(line, links);
            EditorNative.setLineLinks(nativeHandle, payload, tempArena);
        }
    }

    /** Set link spans for a specific line (zero-copy overload) */
    public void setLineLinks(MemorySegment payload, long size) {
        EditorNative.setLineLinks(nativeHandle, payload, size);
    }

    /** Batch set link spans for multiple lines */
    public void setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine) {
        if (linksByLine == null || linksByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLineLinks(linksByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLineLinks(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set link spans for multiple lines (zero-copy overload) */
    public void setBatchLineLinks(MemorySegment payload, long size) {
        EditorNative.setBatchLineLinks(nativeHandle, payload, size);
    }

    /** Clears all link spans */
    public void clearLinks() {
        EditorNative.clearLinks(nativeHandle);
    }

    /** Returns the link target at the given position, or null if no link exists there */
    public String getLinkTargetAt(int line, int column) {
        return EditorNative.getLinkTargetAt(nativeHandle, line, column);
    }

    // ===================== Diagnostics =====================

    /** Set diagnostic decorations for a specific line (model overload) */
    public void setLineDiagnostics(int line, List<? extends Diagnostic> items) {
        if (items == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packLineDiagnostics(line, items);
            EditorNative.setLineDiagnostics(nativeHandle, payload, tempArena);
        }
    }

    /** Set diagnostic decorations for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setLineDiagnostics(MemorySegment payload, long size) {
        EditorNative.setLineDiagnostics(nativeHandle, payload, size);
    }

    /** Batch set diagnostic decorations for multiple lines */
    public void setBatchLineDiagnostics(Map<Integer, ? extends List<? extends Diagnostic>> diagsByLine) {
        if (diagsByLine == null || diagsByLine.isEmpty()) return;
        byte[] payload = ProtocolEncoder.packBatchLineDiagnostics(diagsByLine);
        if (payload == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setBatchLineDiagnostics(nativeHandle, payload, tempArena);
        }
    }

    /** Batch set diagnostic decorations for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setBatchLineDiagnostics(MemorySegment payload, long size) {
        EditorNative.setBatchLineDiagnostics(nativeHandle, payload, size);
    }

    // ===================== Guide (Code Structure Lines) =====================

    /** Set indent guide list (global replacement) */
    public void setIndentGuides(List<? extends IndentGuide> guides) {
        if (guides == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packIndentGuides(guides);
            EditorNative.setIndentGuides(nativeHandle, payload, tempArena);
        }
    }

    /** Set indent guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setIndentGuides(MemorySegment payload, long size) {
        EditorNative.setIndentGuides(nativeHandle, payload, size);
    }

    /** Set bracket pair guide list (global replacement) */
    public void setBracketGuides(List<? extends BracketGuide> guides) {
        if (guides == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packBracketGuides(guides);
            EditorNative.setBracketGuides(nativeHandle, payload, tempArena);
        }
    }

    /** Set bracket pair guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setBracketGuides(MemorySegment payload, long size) {
        EditorNative.setBracketGuides(nativeHandle, payload, size);
    }

    /** Set control flow return arrow list (global replacement) */
    public void setFlowGuides(List<? extends FlowGuide> guides) {
        if (guides == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packFlowGuides(guides);
            EditorNative.setFlowGuides(nativeHandle, payload, tempArena);
        }
    }

    /** Set control flow return arrow list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setFlowGuides(MemorySegment payload, long size) {
        EditorNative.setFlowGuides(nativeHandle, payload, size);
    }

    /** Set separator guide list (global replacement) */
    public void setSeparatorGuides(List<? extends SeparatorGuide> guides) {
        if (guides == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            byte[] payload = ProtocolEncoder.packSeparatorGuides(guides);
            EditorNative.setSeparatorGuides(nativeHandle, payload, tempArena);
        }
    }

    /** Set separator guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setSeparatorGuides(MemorySegment payload, long size) {
        EditorNative.setSeparatorGuides(nativeHandle, payload, size);
    }

    // ===================== Bracket Pair Highlight =====================

    public void setBracketPairs(int[] openChars, int[] closeChars) {
        try (Arena arena = Arena.ofConfined()) {
            EditorNative.setBracketPairs(nativeHandle, openChars, closeChars, arena);
        }
    }

    public void setAutoClosingPairs(int[] openChars, int[] closeChars) {
        try (Arena arena = Arena.ofConfined()) {
            EditorNative.setAutoClosingPairs(nativeHandle, openChars, closeChars, arena);
        }
    }

    public void setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol) {
        EditorNative.setMatchedBrackets(nativeHandle, openLine, openCol, closeLine, closeCol);
    }

    // ===================== Fold =====================

    /** Set foldable regions using a FoldRegion list (model overload) */
    public void setFoldRegions(List<? extends FoldRegion> regions) {
        if (regions == null) return;
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.setFoldRegions(nativeHandle, ProtocolEncoder.packFoldRegions(regions), tempArena);
        }
    }

    /** Set foldable regions (zero-copy overload, accepts pre-encoded MemorySegment) */
    public void setFoldRegions(MemorySegment payload, long size) {
        EditorNative.setFoldRegions(nativeHandle, payload, size);
    }

    public boolean toggleFoldAt(int line) { return EditorNative.toggleFold(nativeHandle, line); }
    public boolean foldAt(int line) { return EditorNative.foldAt(nativeHandle, line); }
    public boolean unfoldAt(int line) { return EditorNative.unfoldAt(nativeHandle, line); }
    public void foldAll() { EditorNative.foldAll(nativeHandle); }
    public void unfoldAll() { EditorNative.unfoldAll(nativeHandle); }
    public boolean isLineVisible(int line) { return EditorNative.isLineVisible(nativeHandle, line); }

    // ===================== Linked Editing =====================

    public TextEditResult insertSnippet(String snippetTemplate) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.NativeBinaryResult result = EditorNative.insertSnippet(nativeHandle, snippetTemplate, tempArena);
            try {
                return ProtocolDecoder.decodeTextEditResult(result.asByteBuffer());
            } finally {
                result.free();
            }
        }
    }

    public void startLinkedEditing(LinkedEditingModel model) {
        try (Arena tempArena = Arena.ofConfined()) {
            EditorNative.startLinkedEditing(nativeHandle, ProtocolEncoder.packLinkedEditingModel(model), tempArena);
        }
    }

    public boolean isInLinkedEditing() { return EditorNative.isInLinkedEditing(nativeHandle); }
    public boolean linkedEditingNext() { return EditorNative.linkedEditingNext(nativeHandle); }
    public boolean linkedEditingPrev() { return EditorNative.linkedEditingPrev(nativeHandle); }
    public void cancelLinkedEditing() { EditorNative.cancelLinkedEditing(nativeHandle); }

    // ===================== Clear =====================

    public void clearHighlights() { EditorNative.clearHighlights(nativeHandle); }
    public void clearHighlightsLayer(int layer) { EditorNative.clearHighlightsLayer(nativeHandle, layer); }
    public void clearLineSpans(int line, int layer) { EditorNative.clearLineSpans(nativeHandle, line, layer); }
    public void clearHighlights(int layer) { EditorNative.clearHighlightsLayer(nativeHandle, layer); }
    public void clearInlayHints() { EditorNative.clearInlayHints(nativeHandle); }
    public void clearPhantomTexts() { EditorNative.clearPhantomTexts(nativeHandle); }
    public void clearGutterIcons() { EditorNative.clearGutterIcons(nativeHandle); }
    public void clearGuides() { EditorNative.clearGuides(nativeHandle); }
    public void clearDiagnostics() { EditorNative.clearDiagnostics(nativeHandle); }
    public void clearMatchedBrackets() { EditorNative.clearMatchedBrackets(nativeHandle); }
    public void clearAllDecorations() { EditorNative.clearAllDecorations(nativeHandle); }
}
