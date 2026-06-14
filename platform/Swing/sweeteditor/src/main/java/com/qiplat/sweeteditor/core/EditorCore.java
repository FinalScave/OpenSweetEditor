package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.config.EditorRangeEffectStyles;
import com.qiplat.sweeteditor.core.config.EditorRenderColors;
import com.qiplat.sweeteditor.core.config.EditorOptions;
import com.qiplat.sweeteditor.core.config.HandleConfig;
import com.qiplat.sweeteditor.core.config.ScrollbarConfig;
import com.qiplat.sweeteditor.core.foundation.*;
import com.qiplat.sweeteditor.core.ime.ImeCommandMessage;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateMessage;
import com.qiplat.sweeteditor.core.interaction.EventType;
import com.qiplat.sweeteditor.core.interaction.GestureEvent;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.search.*;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.core.snippet.*;

import java.lang.ref.Cleaner;
import java.lang.foreign.*;
import java.lang.invoke.MethodType;
import java.util.ArrayList;
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

        MemorySegment optionsSeg = CoreProtocol.encodeEditorOptions(arena, options);
        this.nativeHandle = EditorNative.createEditor(measurer, optionsSeg, optionsSeg.byteSize());
        this.cleanable = CLEANER.register(this, new CleanupAction(nativeHandle, arena));
    }

    // ===================== Lifecycle =====================

    private Document mDocument;

    public EditorActionResult loadDocument(Document document) {
        if (document == null) return null;
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

    public EditorActionResult setRenderWhitespace(int mode) {
        return decodeAction(EditorNative.setRenderWhitespace(nativeHandle, mode));
    }

    public EditorActionResult setRenderLineBreaks(boolean enabled) {
        return decodeAction(EditorNative.setRenderLineBreaks(nativeHandle, enabled));
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
            if (result == null || !result.hasData()) return null;
            return CoreProtocol.decodeEditorRenderModel(result.segment(), result.size());
        } catch (RuntimeException ignored) {
            return null;
        } finally {
            if (result != null) result.free();
        }
    }

    public LayoutMetrics getLayoutMetrics() {
        EditorNative.NativeBinaryResult result = EditorNative.getLayoutMetrics(nativeHandle);
        try {
            if (result == null || !result.hasData()) return new LayoutMetrics();
            return CoreProtocol.decodeLayoutMetrics(result.segment(), result.size());
        } finally {
            if (result != null) result.free();
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
        try (Arena tempArena = Arena.ofConfined()) {
            int pointerCount = (points != null) ? points.length / 2 : 0;
            List<PointF> gesturePoints = new ArrayList<>(pointerCount);
            for (int i = 0; i < pointerCount; i++) {
                gesturePoints.add(new PointF(points[i * 2], points[i * 2 + 1]));
            }
            GestureEvent event = new GestureEvent(
                    EventType.fromValue(type),
                    gesturePoints,
                    modifiers,
                    wheelDeltaX,
                    wheelDeltaY,
                    directScale);
            MemorySegment payload = CoreProtocol.encodeGestureEvent(tempArena, event);
            EditorNative.NativeBinaryResult result = EditorNative.handleGestureEvent(nativeHandle, payload, payload.byteSize());
            return decodeAction(result);
        }
    }

    public EditorActionResult updatePointerModifiers(int modifiers) {
        return decodeAction(EditorNative.updatePointerModifiers(nativeHandle, modifiers));
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

    public EditorActionResult setKeyMap(List<? extends KeyBinding> bindings) {
        if (bindings == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetKeyMapPayload(tempArena, bindings);
            return decodeAction(EditorNative.setKeyMap(nativeHandle, payload, payload.byteSize()));
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

    public EditorActionResult applyTextEdits(List<? extends TextEdit> edits) {
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeApplyTextEditsPayload(tempArena, edits);
            return decodeAction(EditorNative.applyTextEdits(nativeHandle, payload, payload.byteSize()));
        }
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

    public EditorActionResult search(SearchRequest request) {
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSearchRequest(tempArena, request);
            return decodeAction(EditorNative.search(nativeHandle, payload, payload.byteSize()));
        }
    }

    public EditorActionResult findNextSearchMatch() {
        return decodeAction(EditorNative.findNextSearchMatch(nativeHandle));
    }

    public EditorActionResult findPreviousSearchMatch() {
        return decodeAction(EditorNative.findPreviousSearchMatch(nativeHandle));
    }

    public EditorActionResult replaceCurrentSearchMatch(String replacement) {
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeUtf8String(tempArena, replacement);
            return decodeAction(EditorNative.replaceCurrentSearchMatch(nativeHandle, payload, payload.byteSize()));
        }
    }

    public EditorActionResult replaceAllSearchMatches(String replacement) {
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeUtf8String(tempArena, replacement);
            return decodeAction(EditorNative.replaceAllSearchMatches(nativeHandle, payload, payload.byteSize()));
        }
    }

    public EditorActionResult clearSearch() {
        return decodeAction(EditorNative.clearSearch(nativeHandle));
    }

    public SearchState getSearchState() {
        EditorNative.NativeBinaryResult result = EditorNative.getSearchState(nativeHandle);
        try {
            if (result == null || !result.hasData()) return new SearchState();
            return CoreProtocol.decodeSearchState(result.segment(), result.size());
        } finally {
            if (result != null) result.free();
        }
    }

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
            if (result == null || !result.hasData()) return null;
            return CoreProtocol.decodeEditorActionResult(result.segment(), result.size());
        } finally {
            if (result != null) result.free();
        }
    }

    public EditorActionResult handleImeCommandMessage(ImeCommandMessage message) {
        if (message == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeImeCommandMessage(tempArena, message);
            return decodeAction(EditorNative.handleImeCommandMessage(
                    nativeHandle,
                    payload,
                    payload.byteSize()));
        }
    }

    public EditorActionResult handleImeTextUpdateMessage(ImeTextUpdateMessage message) {
        if (message == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeImeTextUpdateMessage(tempArena, message);
            return decodeAction(EditorNative.handleImeTextUpdateMessage(
                    nativeHandle,
                    payload,
                    payload.byteSize()));
        }
    }

    public ImeSyncSnapshot getImeSyncSnapshot() {
        EditorNative.NativeBinaryResult result = EditorNative.getImeSyncSnapshot(nativeHandle);
        try {
            if (result == null || !result.hasData()) return new ImeSyncSnapshot();
            return CoreProtocol.decodeImeSyncSnapshot(result.segment(), result.size());
        } finally {
            if (result != null) result.free();
        }
    }

    public ImeInputContext getImeCommandInputContext(long beforeLength, long afterLength) {
        EditorNative.NativeBinaryResult result = EditorNative.getImeCommandInputContext(
                nativeHandle, Math.max(0, beforeLength), Math.max(0, afterLength));
        try {
            if (result == null || !result.hasData()) return new ImeInputContext();
            return CoreProtocol.decodeImeInputContext(result.segment(), result.size());
        } finally {
            if (result != null) result.free();
        }
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

    public EditorActionResult setHandleConfig(HandleConfig config) {
        if (config == null) return null;
        this.handleConfig = config;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeHandleConfig(tempArena, config);
            return decodeAction(EditorNative.setHandleConfig(nativeHandle, payload, payload.byteSize()));
        }
    }

    public HandleConfig getHandleConfig() {
        return handleConfig;
    }

    public EditorActionResult setScrollbarConfig(ScrollbarConfig config) {
        if (config == null) return null;
        this.scrollbarConfig = config;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeScrollbarConfig(tempArena, config);
            return decodeAction(EditorNative.setScrollbarConfig(nativeHandle, payload, payload.byteSize()));
        }
    }

    public ScrollbarConfig getScrollbarConfig() {
        return scrollbarConfig;
    }

    public EditorActionResult setEditorRenderColors(EditorRenderColors colors) {
        if (colors == null) colors = new EditorRenderColors();
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeEditorRenderColors(tempArena, colors);
            return decodeAction(EditorNative.setEditorRenderColors(nativeHandle, payload, payload.byteSize()));
        }
    }

    public EditorActionResult setEditorRangeEffectStyles(EditorRangeEffectStyles styles) {
        if (styles == null) styles = new EditorRangeEffectStyles();
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeEditorRangeEffectStyles(tempArena, styles);
            return decodeAction(EditorNative.setEditorRangeEffectStyles(nativeHandle, payload, payload.byteSize()));
        }
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
                if (result == null || !result.hasData()) return new ScrollMetrics();
                return CoreProtocol.decodeScrollMetrics(result.segment(), result.size());
            } finally {
                if (result != null) result.free();
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
        if (textStyles == null || textStyles.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeRegisterBatchTextStylesPayload(tempArena, textStyles);
            return decodeAction(EditorNative.registerBatchTextStyles(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set highlight spans for a specific line (model overload) */
    public EditorActionResult setLineSpans(int line, int layer, List<? extends StyleSpan> spans) {
        if (spans == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineSpansPayload(tempArena, line, SpanLayer.fromValue(layer), spans);
            return decodeAction(EditorNative.setLineSpans(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set highlight spans for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineSpans(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineSpans(nativeHandle, payload, size));
    }

    /** Batch set highlight spans for multiple lines (model overload) */
    public EditorActionResult setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine) {
        if (spansByLine == null || spansByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineSpansPayload(tempArena, SpanLayer.fromValue(layer), spansByLine);
            return decodeAction(EditorNative.setBatchLineSpans(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Batch set highlight spans for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineSpans(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineSpans(nativeHandle, payload, size));
    }

    // ===================== InlayHint =====================

    /** Set Inlay Hints for a specific line (model overload, replaces entire line) */
    public EditorActionResult setLineInlayHints(int line, List<? extends InlayHint> hints) {
        if (hints == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineInlayHintsPayload(tempArena, line, hints);
            return decodeAction(EditorNative.setLineInlayHints(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set Inlay Hints for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineInlayHints(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineInlayHints(nativeHandle, payload, size));
    }

    /** Batch set Inlay Hints for multiple lines */
    public EditorActionResult setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine) {
        if (hintsByLine == null || hintsByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineInlayHintsPayload(tempArena, hintsByLine);
            return decodeAction(EditorNative.setBatchLineInlayHints(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Batch set Inlay Hints for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineInlayHints(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineInlayHints(nativeHandle, payload, size));
    }

    // ===================== PhantomText =====================

    /** Set phantom texts for a specific line (model overload, replaces entire line) */
    public EditorActionResult setLinePhantomTexts(int line, List<? extends PhantomText> phantoms) {
        if (phantoms == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLinePhantomTextsPayload(tempArena, line, phantoms);
            return decodeAction(EditorNative.setLinePhantomTexts(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set phantom texts for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLinePhantomTexts(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLinePhantomTexts(nativeHandle, payload, size));
    }

    /** Batch set phantom texts for multiple lines */
    public EditorActionResult setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine) {
        if (phantomsByLine == null || phantomsByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLinePhantomTextsPayload(tempArena, phantomsByLine);
            return decodeAction(EditorNative.setBatchLinePhantomTexts(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Batch set phantom texts for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLinePhantomTexts(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLinePhantomTexts(nativeHandle, payload, size));
    }

    // ===================== Gutter Icons =====================

    /** Set gutter icons for a specific line (model overload, replaces entire line) */
    public EditorActionResult setLineGutterIcons(int line, List<? extends GutterIcon> icons) {
        if (icons == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineGutterIconsPayload(tempArena, line, icons);
            return decodeAction(EditorNative.setLineGutterIcons(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set gutter icons for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineGutterIcons(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineGutterIcons(nativeHandle, payload, size));
    }

    /** Batch set gutter icons for multiple lines */
    public EditorActionResult setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine) {
        if (iconsByLine == null || iconsByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineGutterIconsPayload(tempArena, iconsByLine);
            return decodeAction(EditorNative.setBatchLineGutterIcons(nativeHandle, payload, payload.byteSize()));
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
        if (items == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineCodeLensPayload(tempArena, line, items);
            return decodeAction(EditorNative.setLineCodeLens(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set CodeLens items for a specific line (zero-copy overload) */
    public EditorActionResult setLineCodeLens(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineCodeLens(nativeHandle, payload, size));
    }

    /** Batch set CodeLens items for multiple lines */
    public EditorActionResult setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine) {
        if (itemsByLine == null || itemsByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineCodeLensPayload(tempArena, itemsByLine);
            return decodeAction(EditorNative.setBatchLineCodeLens(nativeHandle, payload, payload.byteSize()));
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
        if (links == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineLinksPayload(tempArena, line, links);
            return decodeAction(EditorNative.setLineLinks(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set link spans for a specific line (zero-copy overload) */
    public EditorActionResult setLineLinks(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineLinks(nativeHandle, payload, size));
    }

    /** Batch set link spans for multiple lines */
    public EditorActionResult setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine) {
        if (linksByLine == null || linksByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineLinksPayload(tempArena, linksByLine);
            return decodeAction(EditorNative.setBatchLineLinks(nativeHandle, payload, payload.byteSize()));
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
        if (items == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineDiagnosticsPayload(tempArena, line, items);
            return decodeAction(EditorNative.setLineDiagnostics(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set diagnostic decorations for a specific line (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setLineDiagnostics(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineDiagnostics(nativeHandle, payload, size));
    }

    /** Batch set diagnostic decorations for multiple lines */
    public EditorActionResult setBatchLineDiagnostics(Map<Integer, ? extends List<? extends Diagnostic>> diagsByLine) {
        if (diagsByLine == null || diagsByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineDiagnosticsPayload(tempArena, diagsByLine);
            return decodeAction(EditorNative.setBatchLineDiagnostics(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Batch set diagnostic decorations for multiple lines (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBatchLineDiagnostics(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineDiagnostics(nativeHandle, payload, size));
    }

    public EditorActionResult setLineDocumentHighlights(int line, List<? extends DocumentHighlight> items) {
        if (items == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetLineDocumentHighlightsPayload(tempArena, line, items);
            return decodeAction(EditorNative.setLineDocumentHighlights(nativeHandle, payload, payload.byteSize()));
        }
    }

    public EditorActionResult setLineDocumentHighlights(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setLineDocumentHighlights(nativeHandle, payload, size));
    }

    public EditorActionResult setBatchLineDocumentHighlights(Map<Integer, ? extends List<? extends DocumentHighlight>> highlightsByLine) {
        if (highlightsByLine == null || highlightsByLine.isEmpty()) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBatchLineDocumentHighlightsPayload(tempArena, highlightsByLine);
            return decodeAction(EditorNative.setBatchLineDocumentHighlights(nativeHandle, payload, payload.byteSize()));
        }
    }

    public EditorActionResult setBatchLineDocumentHighlights(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBatchLineDocumentHighlights(nativeHandle, payload, size));
    }

    // ===================== Guide (Code Structure Lines) =====================

    /** Set indent guide list (global replacement) */
    public EditorActionResult setIndentGuides(List<? extends IndentGuide> guides) {
        if (guides == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetIndentGuidesPayload(tempArena, guides);
            return decodeAction(EditorNative.setIndentGuides(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set indent guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setIndentGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setIndentGuides(nativeHandle, payload, size));
    }

    /** Set bracket pair guide list (global replacement) */
    public EditorActionResult setBracketGuides(List<? extends BracketGuide> guides) {
        if (guides == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetBracketGuidesPayload(tempArena, guides);
            return decodeAction(EditorNative.setBracketGuides(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set bracket pair guide list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setBracketGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setBracketGuides(nativeHandle, payload, size));
    }

    /** Set control flow return arrow list (global replacement) */
    public EditorActionResult setFlowGuides(List<? extends FlowGuide> guides) {
        if (guides == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetFlowGuidesPayload(tempArena, guides);
            return decodeAction(EditorNative.setFlowGuides(nativeHandle, payload, payload.byteSize()));
        }
    }

    /** Set control flow return arrow list (zero-copy overload, accepts pre-encoded MemorySegment) */
    public EditorActionResult setFlowGuides(MemorySegment payload, long size) {
        return decodeAction(EditorNative.setFlowGuides(nativeHandle, payload, size));
    }

    /** Set separator guide list (global replacement) */
    public EditorActionResult setSeparatorGuides(List<? extends SeparatorGuide> guides) {
        if (guides == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetSeparatorGuidesPayload(tempArena, guides);
            return decodeAction(EditorNative.setSeparatorGuides(nativeHandle, payload, payload.byteSize()));
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
        if (regions == null) return null;
        try (Arena tempArena = Arena.ofConfined()) {
            MemorySegment payload = CoreProtocol.encodeSetFoldRegionsPayload(tempArena, regions);
            return decodeAction(EditorNative.setFoldRegions(nativeHandle, payload, payload.byteSize()));
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
            MemorySegment payload = CoreProtocol.encodeStartLinkedEditingPayload(tempArena, model);
            return decodeAction(EditorNative.startLinkedEditing(nativeHandle, payload, payload.byteSize()));
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
    public EditorActionResult clearDocumentHighlights() { return decodeAction(EditorNative.clearDocumentHighlights(nativeHandle)); }
    public EditorActionResult clearMatchedBrackets() { return decodeAction(EditorNative.clearMatchedBrackets(nativeHandle)); }
    public EditorActionResult clearAllDecorations() { return decodeAction(EditorNative.clearAllDecorations(nativeHandle)); }

}
