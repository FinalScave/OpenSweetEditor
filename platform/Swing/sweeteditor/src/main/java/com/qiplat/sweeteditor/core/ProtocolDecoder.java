package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.foundation.*;
import com.qiplat.sweeteditor.core.adornment.TextStyle;
import com.qiplat.sweeteditor.core.visual.*;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;

final class ProtocolDecoder {
    private ProtocolDecoder() {
    }

    static ScrollMetrics defaultScrollMetrics() {
        return new ScrollMetrics(1.0f, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, false, false);
    }

    static EditorRenderModel decodeRenderModel(ByteBuffer data) {
        if (data == null || data.remaining() == 0) return null;
        EditorRenderModel model = new EditorRenderModel();
        model.splitX = data.getFloat();
        model.splitLineVisible = data.getInt() != 0;
        model.scrollX = data.getFloat();
        model.scrollY = data.getFloat();
        model.viewportWidth = data.getFloat();
        model.viewportHeight = data.getFloat();
        model.currentLine = readPoint(data);
        model.currentLineRenderMode = data.getInt();
        model.lines = readVisualLines(data);
        model.gutterIcons = readGutterIconRenderItems(data);
        model.foldMarkers = readFoldMarkerRenderItems(data);
        model.cursor = readCursor(data);
        model.selectionRects = readSelectionRects(data);
        model.selectionStartHandle = readSelectionHandle(data);
        model.selectionEndHandle = readSelectionHandle(data);
        model.compositionDecoration = readCompositionDecoration(data);
        model.guideSegments = readGuideSegments(data);
        model.diagnosticDecorations = readDiagnosticDecorations(data);
        model.maxGutterIcons = data.getInt();
        model.linkedEditingRects = readLinkedEditingRects(data);
        model.bracketHighlightRects = readBracketHighlightRects(data);
        model.verticalScrollbar = defaultScrollbarModel();
        model.horizontalScrollbar = defaultScrollbarModel();
        if (data.remaining() >= 80) {
            model.verticalScrollbar = readScrollbarModel(data);
            model.horizontalScrollbar = readScrollbarModel(data);
        }
        if (data.remaining() >= 4) {
            model.gutterSticky = data.getInt() != 0;
        }
        if (data.remaining() >= 4) {
            model.gutterVisible = data.getInt() != 0;
        }
        return model;
    }

    static TextEditResult decodeTextEditResult(ByteBuffer data) {
        if (data == null || data.remaining() < 4) return TextEditResult.EMPTY;
        boolean changed = data.getInt() != 0;
        if (!changed || data.remaining() < 4) return TextEditResult.EMPTY;
        int count = data.getInt();
        if (count <= 0) return TextEditResult.EMPTY;
        ArrayList<TextChange> changes = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            if (data.remaining() < 20) break;
            changes.add(readTextChange(data));
        }
        if (changes.isEmpty()) return TextEditResult.EMPTY;
        TextEditResult result = new TextEditResult();
        result.changes = changes;
        return result;
    }

    static KeyEventResult decodeKeyEventResult(ByteBuffer data) {
        KeyEventResult result = new KeyEventResult();
        if (data == null || data.remaining() < 20) return result;
        result.handled = data.getInt() != 0;
        result.contentChanged = data.getInt() != 0;
        result.cursorChanged = data.getInt() != 0;
        result.selectionChanged = data.getInt() != 0;
        boolean hasEdit = data.getInt() != 0;
        if (hasEdit && data.remaining() >= 4) {
            int count = data.getInt();
            if (count > 0) {
                ArrayList<TextChange> changes = new ArrayList<>(count);
                for (int i = 0; i < count; i++) {
                    if (data.remaining() < 20) break;
                    changes.add(readTextChange(data));
                }
                if (!changes.isEmpty()) {
                    TextEditResult editResult = new TextEditResult();
                    editResult.changes = changes;
                    result.editResult = editResult;
                }
            }
        }
        return result;
    }

    static GestureResult decodeGestureResult(ByteBuffer data) {
        if (data == null || data.remaining() < 4) return null;
        GestureResult result = new GestureResult();
        result.type = gestureTypeFromValue(data.getInt());
        result.tapPoint = new PointF();
        result.modifiers = 0;

        switch (result.type) {
            case TAP, DOUBLE_TAP, LONG_PRESS, DRAG_SELECT, CONTEXT_MENU -> {
                if (data.remaining() < 8) return result;
                result.tapPoint = new PointF(data.getFloat(), data.getFloat());
            }
            default -> {
            }
        }

        if (data.remaining() < 40) return result;
        result.cursorPosition = new TextPosition(data.getInt(), data.getInt());
        result.hasSelection = data.getInt() != 0;
        result.selection = new TextRange(
                new TextPosition(data.getInt(), data.getInt()),
                new TextPosition(data.getInt(), data.getInt())
        );
        result.viewScrollX = data.getFloat();
        result.viewScrollY = data.getFloat();
        result.viewScale = data.getFloat();

        HitTarget hitTarget = new HitTarget();
        hitTarget.type = HitTargetType.NONE;
        if (data.remaining() >= 20) {
            hitTarget.type = hitTargetTypeFromValue(data.getInt());
            hitTarget.line = data.getInt();
            hitTarget.column = data.getInt();
            hitTarget.iconId = data.getInt();
            hitTarget.colorValue = data.getInt();
        }
        result.hitTarget = hitTarget;
        if (data.remaining() >= 4) {
            result.needsEdgeScroll = data.getInt() != 0;
        }
        if (data.remaining() >= 4) {
            result.needsFling = data.getInt() != 0;
        }
        if (data.remaining() >= 4) {
            result.needsAnimation = data.getInt() != 0;
        }
        return result;
    }

    static ScrollMetrics decodeScrollMetrics(ByteBuffer data) {
        if (data == null || data.remaining() < 52) return defaultScrollMetrics();
        return new ScrollMetrics(
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getFloat(),
                data.getInt() != 0,
                data.getInt() != 0
        );
    }

    private static String readBufferString(ByteBuffer data) {
        int len = data.getInt();
        if (len <= 0 || len > data.remaining()) return "";
        byte[] bytes = new byte[len];
        data.get(bytes);
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static PointF readPoint(ByteBuffer data) {
        return new PointF(data.getFloat(), data.getFloat());
    }

    private static TextPosition readTextPosition(ByteBuffer data) {
        return new TextPosition(data.getInt(), data.getInt());
    }

    private static TextStyle readTextStyle(ByteBuffer data) {
        int color = data.getInt();
        int backgroundColor = data.getInt();
        int fontStyle = data.getInt();
        return new TextStyle(color, backgroundColor, fontStyle);
    }

    private static <T extends Enum<T>> T enumByOrdinal(int value, T[] values, T fallback) {
        return value >= 0 && value < values.length ? values[value] : fallback;
    }

    private static VisualRunType readVisualRunType(ByteBuffer data) {
        return enumByOrdinal(data.getInt(), VisualRunType.values(), VisualRunType.TEXT);
    }

    private static FoldState readFoldState(ByteBuffer data) {
        return enumByOrdinal(data.getInt(), FoldState.values(), FoldState.NONE);
    }

    private static GuideDirection readGuideDirection(ByteBuffer data) {
        return enumByOrdinal(data.getInt(), GuideDirection.values(), GuideDirection.HORIZONTAL);
    }

    private static GuideType readGuideType(ByteBuffer data) {
        return enumByOrdinal(data.getInt(), GuideType.values(), GuideType.INDENT);
    }

    private static GuideStyle readGuideStyle(ByteBuffer data) {
        return enumByOrdinal(data.getInt(), GuideStyle.values(), GuideStyle.SOLID);
    }

    private static VisualRun readVisualRun(ByteBuffer data) {
        VisualRun run = new VisualRun();
        run.type = readVisualRunType(data);
        run.x = data.getFloat();
        run.y = data.getFloat();
        run.text = readBufferString(data);
        run.style = readTextStyle(data);
        run.iconId = data.getInt();
        run.colorValue = data.getInt();
        run.width = data.getFloat();
        run.padding = data.getFloat();
        run.margin = data.getFloat();
        return run;
    }

    private static ArrayList<VisualRun> readVisualRuns(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<VisualRun> runs = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            runs.add(readVisualRun(data));
        }
        return runs;
    }

    private static VisualLine readVisualLine(ByteBuffer data) {
        VisualLine line = new VisualLine();
        line.logicalLine = data.getInt();
        line.wrapIndex = data.getInt();
        line.lineNumberPosition = readPoint(data);
        line.isPhantomLine = data.getInt() != 0;
        line.foldState = readFoldState(data);
        line.runs = readVisualRuns(data);
        return line;
    }

    private static ArrayList<VisualLine> readVisualLines(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<VisualLine> lines = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            lines.add(readVisualLine(data));
        }
        return lines;
    }

    private static GutterIconRenderItem readGutterIconRenderItem(ByteBuffer data) {
        GutterIconRenderItem item = new GutterIconRenderItem();
        item.logicalLine = data.getInt();
        item.iconId = data.getInt();
        item.origin = readPoint(data);
        item.width = data.getFloat();
        item.height = data.getFloat();
        return item;
    }

    private static ArrayList<GutterIconRenderItem> readGutterIconRenderItems(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<GutterIconRenderItem> items = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            items.add(readGutterIconRenderItem(data));
        }
        return items;
    }

    private static FoldMarkerRenderItem readFoldMarkerRenderItem(ByteBuffer data) {
        FoldMarkerRenderItem item = new FoldMarkerRenderItem();
        item.logicalLine = data.getInt();
        item.foldState = readFoldState(data);
        item.origin = readPoint(data);
        item.width = data.getFloat();
        item.height = data.getFloat();
        return item;
    }

    private static ArrayList<FoldMarkerRenderItem> readFoldMarkerRenderItems(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<FoldMarkerRenderItem> items = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            items.add(readFoldMarkerRenderItem(data));
        }
        return items;
    }

    private static Cursor readCursor(ByteBuffer data) {
        Cursor cursor = new Cursor();
        cursor.textPosition = readTextPosition(data);
        cursor.position = readPoint(data);
        cursor.height = data.getFloat();
        cursor.visible = data.getInt() != 0;
        cursor.showDragger = data.getInt() != 0;
        return cursor;
    }

    private static SelectionRect readSelectionRect(ByteBuffer data) {
        SelectionRect rect = new SelectionRect();
        rect.origin = readPoint(data);
        rect.width = data.getFloat();
        rect.height = data.getFloat();
        return rect;
    }

    private static ArrayList<SelectionRect> readSelectionRects(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<SelectionRect> rects = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            rects.add(readSelectionRect(data));
        }
        return rects;
    }

    private static SelectionHandle readSelectionHandle(ByteBuffer data) {
        SelectionHandle handle = new SelectionHandle();
        handle.position = readPoint(data);
        handle.height = data.getFloat();
        handle.visible = data.getInt() != 0;
        return handle;
    }

    private static CompositionDecoration readCompositionDecoration(ByteBuffer data) {
        CompositionDecoration decoration = new CompositionDecoration();
        decoration.active = data.getInt() != 0;
        decoration.origin = readPoint(data);
        decoration.width = data.getFloat();
        decoration.height = data.getFloat();
        return decoration;
    }

    private static GuideSegment readGuideSegment(ByteBuffer data) {
        GuideSegment segment = new GuideSegment();
        segment.direction = readGuideDirection(data);
        segment.type = readGuideType(data);
        segment.style = readGuideStyle(data);
        segment.start = readPoint(data);
        segment.end = readPoint(data);
        segment.arrowEnd = data.getInt() != 0;
        return segment;
    }

    private static ArrayList<GuideSegment> readGuideSegments(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<GuideSegment> segments = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            segments.add(readGuideSegment(data));
        }
        return segments;
    }

    private static DiagnosticDecoration readDiagnosticDecoration(ByteBuffer data) {
        DiagnosticDecoration decoration = new DiagnosticDecoration();
        decoration.origin = readPoint(data);
        decoration.width = data.getFloat();
        decoration.height = data.getFloat();
        decoration.severity = data.getInt();
        decoration.color = data.getInt();
        return decoration;
    }

    private static ArrayList<DiagnosticDecoration> readDiagnosticDecorations(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<DiagnosticDecoration> decorations = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            decorations.add(readDiagnosticDecoration(data));
        }
        return decorations;
    }

    private static LinkedEditingRect readLinkedEditingRect(ByteBuffer data) {
        LinkedEditingRect rect = new LinkedEditingRect();
        rect.origin = readPoint(data);
        rect.width = data.getFloat();
        rect.height = data.getFloat();
        rect.isActive = data.getInt() != 0;
        return rect;
    }

    private static ArrayList<LinkedEditingRect> readLinkedEditingRects(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<LinkedEditingRect> rects = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            rects.add(readLinkedEditingRect(data));
        }
        return rects;
    }

    private static BracketHighlightRect readBracketHighlightRect(ByteBuffer data) {
        BracketHighlightRect rect = new BracketHighlightRect();
        rect.origin = readPoint(data);
        rect.width = data.getFloat();
        rect.height = data.getFloat();
        return rect;
    }

    private static ArrayList<BracketHighlightRect> readBracketHighlightRects(ByteBuffer data) {
        int count = data.getInt();
        ArrayList<BracketHighlightRect> rects = new ArrayList<>(Math.max(count, 0));
        for (int i = 0; i < count; i++) {
            rects.add(readBracketHighlightRect(data));
        }
        return rects;
    }

    private static ScrollbarRect defaultScrollbarRect() {
        ScrollbarRect rect = new ScrollbarRect();
        rect.origin = new PointF(0f, 0f);
        rect.width = 0f;
        rect.height = 0f;
        return rect;
    }

    private static ScrollbarModel defaultScrollbarModel() {
        ScrollbarModel model = new ScrollbarModel();
        model.visible = false;
        model.alpha = 0f;
        model.track = defaultScrollbarRect();
        model.thumb = defaultScrollbarRect();
        return model;
    }

    private static ScrollbarRect readScrollbarRect(ByteBuffer data) {
        ScrollbarRect rect = new ScrollbarRect();
        rect.origin = readPoint(data);
        rect.width = data.getFloat();
        rect.height = data.getFloat();
        return rect;
    }

    private static ScrollbarModel readScrollbarModel(ByteBuffer data) {
        ScrollbarModel model = new ScrollbarModel();
        model.visible = data.getInt() != 0;
        model.alpha = data.getFloat();
        model.thumbActive = data.getInt() != 0;
        model.track = readScrollbarRect(data);
        model.thumb = readScrollbarRect(data);
        return model;
    }

    private static TextChange readTextChange(ByteBuffer data) {
        TextRange range = new TextRange(
                new TextPosition(data.getInt(), data.getInt()),
                new TextPosition(data.getInt(), data.getInt())
        );
        TextChange change = new TextChange();
        change.range = range;
        change.newText = readBufferString(data);
        return change;
    }

    private static GestureType gestureTypeFromValue(int value) {
        GestureType[] values = GestureType.values();
        if (value >= 0 && value < values.length) {
            return values[value];
        }
        return GestureType.UNDEFINED;
    }

    private static HitTargetType hitTargetTypeFromValue(int value) {
        HitTargetType[] values = HitTargetType.values();
        if (value >= 0 && value < values.length) {
            return values[value];
        }
        return HitTargetType.NONE;
    }
}
