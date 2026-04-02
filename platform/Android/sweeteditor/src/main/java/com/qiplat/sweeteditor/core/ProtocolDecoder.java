package com.qiplat.sweeteditor.core;

import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.visual.BracketHighlightRect;
import com.qiplat.sweeteditor.core.visual.CompositionDecoration;
import com.qiplat.sweeteditor.core.visual.Cursor;
import com.qiplat.sweeteditor.core.visual.DiagnosticDecoration;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.core.visual.FoldMarkerRenderItem;
import com.qiplat.sweeteditor.core.visual.FoldState;
import com.qiplat.sweeteditor.core.visual.GutterIconRenderItem;
import com.qiplat.sweeteditor.core.visual.GuideDirection;
import com.qiplat.sweeteditor.core.visual.GuideSegment;
import com.qiplat.sweeteditor.core.visual.GuideStyle;
import com.qiplat.sweeteditor.core.visual.GuideType;
import com.qiplat.sweeteditor.core.adornment.TextStyle;
import com.qiplat.sweeteditor.core.visual.LinkedEditingRect;
import com.qiplat.sweeteditor.core.visual.LayoutMetrics;
import com.qiplat.sweeteditor.core.visual.PointF;
import com.qiplat.sweeteditor.core.visual.SelectionHandle;
import com.qiplat.sweeteditor.core.visual.SelectionRect;
import com.qiplat.sweeteditor.core.visual.ScrollbarModel;
import com.qiplat.sweeteditor.core.visual.ScrollbarRect;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.visual.VisualLine;
import com.qiplat.sweeteditor.core.visual.VisualRun;
import com.qiplat.sweeteditor.core.visual.VisualRunType;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;

final class ProtocolDecoder {
    private ProtocolDecoder() {
    }

    static ScrollMetrics defaultScrollMetrics() {
        return new ScrollMetrics(1.0f, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, false, false);
    }

    static EditorCore.TextEditResult decodeTextEditResult(@Nullable ByteBuffer data) {
        if (data == null) return EditorCore.TextEditResult.EMPTY;
        data.order(ByteOrder.nativeOrder());
        boolean changed = data.getInt() != 0;
        if (!changed) return EditorCore.TextEditResult.EMPTY;
        int count = data.getInt();
        java.util.List<EditorCore.TextChange> changes = new java.util.ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            TextRange range = new TextRange(
                    new TextPosition(data.getInt(), data.getInt()),
                    new TextPosition(data.getInt(), data.getInt()));
            String newText = readBufferString(data);
            changes.add(new EditorCore.TextChange(range, newText));
        }
        return new EditorCore.TextEditResult(true, changes);
    }

    static EditorCore.KeyEventResult decodeKeyEventResult(@Nullable ByteBuffer data) {
        if (data == null) return new EditorCore.KeyEventResult();
        data.order(ByteOrder.nativeOrder());
        boolean handled = data.getInt() != 0;
        boolean contentChanged = data.getInt() != 0;
        boolean cursorChanged = data.getInt() != 0;
        boolean selectionChanged = data.getInt() != 0;
        boolean hasEdit = data.getInt() != 0;
        EditorCore.TextEditResult editResult = EditorCore.TextEditResult.EMPTY;
        if (hasEdit) {
            int count = data.getInt();
            java.util.List<EditorCore.TextChange> changes = new java.util.ArrayList<>(count);
            for (int i = 0; i < count; i++) {
                TextRange range = new TextRange(
                        new TextPosition(data.getInt(), data.getInt()),
                        new TextPosition(data.getInt(), data.getInt()));
                String newText = readBufferString(data);
                changes.add(new EditorCore.TextChange(range, newText));
            }
            editResult = new EditorCore.TextEditResult(true, changes);
        }
        int command = data.remaining() >= 4 ? data.getInt() : 0;
        return new EditorCore.KeyEventResult(handled, contentChanged, cursorChanged, selectionChanged, editResult, command);
    }

    static EditorCore.GestureResult decodeGestureResult(@Nullable ByteBuffer data) {
        if (data == null) return new EditorCore.GestureResult();
        data.order(ByteOrder.nativeOrder());
        EditorCore.GestureType gestureType = EditorCore.GestureType.fromValue(data.getInt());
        android.graphics.PointF tapPoint = new android.graphics.PointF();

        switch (gestureType) {
            case TAP:
            case DOUBLE_TAP:
            case LONG_PRESS:
            case DRAG_SELECT:
            case CONTEXT_MENU:
                tapPoint = new android.graphics.PointF(data.getFloat(), data.getFloat());
                break;
            default:
                break;
        }

        TextPosition cursorPosition = new TextPosition(data.getInt(), data.getInt());
        boolean hasSelection = data.getInt() != 0;
        TextRange selection = new TextRange(
                new TextPosition(data.getInt(), data.getInt()),
                new TextPosition(data.getInt(), data.getInt())
        );
        float viewScrollX = data.getFloat();
        float viewScrollY = data.getFloat();
        float viewScale = data.getFloat();

        EditorCore.HitTarget hitTarget = EditorCore.HitTarget.NONE;
        if (data.remaining() >= 20) {
            int hitTypeInt = data.getInt();
            int hitLine = data.getInt();
            int hitColumn = data.getInt();
            int hitIconId = data.getInt();
            int hitColorValue = data.getInt();
            EditorCore.HitTargetType hitType = EditorCore.HitTargetType.fromValue(hitTypeInt);
            if (hitType != EditorCore.HitTargetType.NONE) {
                hitTarget = new EditorCore.HitTarget(hitType, hitLine, hitColumn, hitIconId, hitColorValue);
            }
        }

        boolean needsEdgeScroll = false;
        if (data.remaining() >= 4) {
            needsEdgeScroll = data.getInt() != 0;
        }

        boolean needsFling = false;
        if (data.remaining() >= 4) {
            needsFling = data.getInt() != 0;
        }

        boolean needsAnimation = false;
        if (data.remaining() >= 4) {
            needsAnimation = data.getInt() != 0;
        }

        boolean isHandleDrag = false;
        if (data.remaining() >= 4) {
            isHandleDrag = data.getInt() != 0;
        }

        return new EditorCore.GestureResult(gestureType, tapPoint,
                cursorPosition, hasSelection, selection, viewScrollX, viewScrollY, viewScale, hitTarget, needsEdgeScroll, needsFling, needsAnimation, isHandleDrag);
    }

    static ScrollMetrics decodeScrollMetrics(@Nullable ByteBuffer data) {
        if (data == null) return defaultScrollMetrics();
        data.order(ByteOrder.nativeOrder());
        if (data.remaining() < 52) return defaultScrollMetrics();
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

    @Nullable
    static LayoutMetrics decodeLayoutMetrics(@Nullable ByteBuffer data) {
        if (data == null) return null;
        data.order(ByteOrder.nativeOrder());
        if (data.remaining() < 40) return null;
        float fontHeight = data.getFloat();
        float fontAscent = data.getFloat();
        float lineSpacingAdd = data.getFloat();
        float lineSpacingMult = data.getFloat();
        float lineNumberMargin = data.getFloat();
        float lineNumberWidth = data.getFloat();
        int maxGutterIcons = data.getInt();
        float inlayHintPadding = data.getFloat();
        float inlayHintMargin = data.getFloat();
        int foldArrowModeValue = data.getInt();
        boolean hasFoldRegions = data.getInt() != 0;
        return new LayoutMetrics(
                fontHeight,
                fontAscent,
                lineSpacingAdd,
                lineSpacingMult,
                lineNumberMargin,
                lineNumberWidth,
                maxGutterIcons,
                inlayHintPadding,
                inlayHintMargin,
                com.qiplat.sweeteditor.core.foundation.FoldArrowMode.fromValue(foldArrowModeValue),
                hasFoldRegions
        );
    }

    @Nullable
    static EditorRenderModel decodeRenderModel(@Nullable ByteBuffer data) {
        if (data == null) return null;
        data.order(ByteOrder.nativeOrder());
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

    private static String readBufferString(ByteBuffer data) {
        int len = data.getInt();
        if (len <= 0) return "";
        byte[] bytes = new byte[len];
        data.get(bytes);
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static PointF readPoint(ByteBuffer data) {
        PointF point = new PointF();
        point.x = data.getFloat();
        point.y = data.getFloat();
        return point;
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
        return enumByOrdinal(data.getInt(), GuideDirection.values(), GuideDirection.VERTICAL);
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
        rect.origin = new PointF();
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
        ScrollbarModel scrollbar = new ScrollbarModel();
        scrollbar.visible = data.getInt() != 0;
        scrollbar.alpha = data.getFloat();
        scrollbar.thumbActive = data.getInt() != 0;
        scrollbar.track = readScrollbarRect(data);
        scrollbar.thumb = readScrollbarRect(data);
        return scrollbar;
    }
}
