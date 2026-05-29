package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.action.EditorActionReason;
import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.action.ScrollBehavior;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.CodeLensItem;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.DiagnosticSeverity;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.adornment.LinkSpan;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorStyle;
import com.qiplat.sweeteditor.core.adornment.SpanLayer;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.adornment.TextStyle;
import com.qiplat.sweeteditor.core.config.AutoIndentMode;
import com.qiplat.sweeteditor.core.config.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.config.EditorOptions;
import com.qiplat.sweeteditor.core.config.FoldArrowMode;
import com.qiplat.sweeteditor.core.config.HandleConfig;
import com.qiplat.sweeteditor.core.config.ScrollbarConfig;
import com.qiplat.sweeteditor.core.config.ScrollbarMode;
import com.qiplat.sweeteditor.core.config.ScrollbarTrackTapMode;
import com.qiplat.sweeteditor.core.config.WrapMode;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.OffsetRect;
import com.qiplat.sweeteditor.core.foundation.PointF;
import com.qiplat.sweeteditor.core.foundation.Rect;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.ime.ImeContextPolicy;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeInputContextKind;
import com.qiplat.sweeteditor.core.ime.ImePreeditStorage;
import com.qiplat.sweeteditor.core.ime.ImeScriptClass;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.core.ime.ImeTextModelMode;
import com.qiplat.sweeteditor.core.ime.ImeTextRange;
import com.qiplat.sweeteditor.core.ime.ImeTextUnit;
import com.qiplat.sweeteditor.core.interaction.EventType;
import com.qiplat.sweeteditor.core.interaction.GestureType;
import com.qiplat.sweeteditor.core.interaction.HitTarget;
import com.qiplat.sweeteditor.core.interaction.HitTargetType;
import com.qiplat.sweeteditor.core.keymap.EditorBuiltinCommand;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyChord;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.snippet.TabStopGroup;
import com.qiplat.sweeteditor.core.visual.CompositionDecoration;
import com.qiplat.sweeteditor.core.visual.Cursor;
import com.qiplat.sweeteditor.core.visual.CursorRect;
import com.qiplat.sweeteditor.core.visual.DiagnosticDecoration;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.core.visual.FoldMarkerRenderItem;
import com.qiplat.sweeteditor.core.visual.FoldState;
import com.qiplat.sweeteditor.core.visual.GuideDirection;
import com.qiplat.sweeteditor.core.visual.GuideSegment;
import com.qiplat.sweeteditor.core.visual.GuideStyle;
import com.qiplat.sweeteditor.core.visual.GuideType;
import com.qiplat.sweeteditor.core.visual.GutterIconRenderItem;
import com.qiplat.sweeteditor.core.visual.LayoutMetrics;
import com.qiplat.sweeteditor.core.visual.LinkedEditingRect;
import com.qiplat.sweeteditor.core.visual.PointerCursorType;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;
import com.qiplat.sweeteditor.core.visual.ScrollbarModel;
import com.qiplat.sweeteditor.core.visual.SelectionHandle;
import com.qiplat.sweeteditor.core.visual.VisualLine;
import com.qiplat.sweeteditor.core.visual.VisualLineKind;
import com.qiplat.sweeteditor.core.visual.VisualRun;
import com.qiplat.sweeteditor.core.visual.VisualRunType;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;

public final class CoreProtocol {
    private CoreProtocol() {
    }

    private static void prepare(ByteBuffer data) {
        data.order(ByteOrder.LITTLE_ENDIAN);
    }

    private static final byte[] EMPTY_BYTES = new byte[0];

    private static byte[] utf8Bytes(String value) {
        return value == null || value.isEmpty() ? EMPTY_BYTES : value.getBytes(StandardCharsets.UTF_8);
    }

    private static String readUtf8String(ByteBuffer data) {
        int length = data.getInt();
        if (length < 0 || length > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        if (length == 0) return "";
        byte[] bytes = new byte[length];
        data.get(bytes);
        return new String(bytes, StandardCharsets.UTF_8);
    }

    private static void writeUtf8String(ByteBuffer data, String value) {
        writeUtf8Bytes(data, utf8Bytes(value));
    }

    private static void writeUtf8Bytes(ByteBuffer data, byte[] bytes) {
        data.putInt(bytes.length);
        data.put(bytes);
    }

    private static int sizeOfUtf8String(String value) {
        return 4 + utf8Bytes(value).length;
    }

    private static void writeBracketGuideList(ByteBuffer data, java.util.List<? extends BracketGuide> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeBracketGuideFields(data, values.get(i));
        }
    }

    private static int sizeOfBracketGuideList(java.util.List<? extends BracketGuide> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfBracketGuide(values.get(i));
            }
        }
        return size;
    }

    private static void writeCodeLensItemList(ByteBuffer data, java.util.List<? extends CodeLensItem> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeCodeLensItemFields(data, values.get(i));
        }
    }

    private static int sizeOfCodeLensItemList(java.util.List<? extends CodeLensItem> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfCodeLensItem(values.get(i));
            }
        }
        return size;
    }

    private static void writeDiagnosticList(ByteBuffer data, java.util.List<? extends Diagnostic> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeDiagnosticFields(data, values.get(i));
        }
    }

    private static int sizeOfDiagnosticList(java.util.List<? extends Diagnostic> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfDiagnostic(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<DiagnosticDecoration> readDiagnosticDecorationList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<DiagnosticDecoration> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readDiagnosticDecoration(data));
        }
        return values;
    }

    private static void writeFlowGuideList(ByteBuffer data, java.util.List<? extends FlowGuide> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeFlowGuideFields(data, values.get(i));
        }
    }

    private static int sizeOfFlowGuideList(java.util.List<? extends FlowGuide> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfFlowGuide(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<FoldMarkerRenderItem> readFoldMarkerRenderItemList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<FoldMarkerRenderItem> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readFoldMarkerRenderItem(data));
        }
        return values;
    }

    private static void writeFoldRegionList(ByteBuffer data, java.util.List<? extends FoldRegion> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeFoldRegionFields(data, values.get(i));
        }
    }

    private static int sizeOfFoldRegionList(java.util.List<? extends FoldRegion> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfFoldRegion(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<GuideSegment> readGuideSegmentList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<GuideSegment> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readGuideSegment(data));
        }
        return values;
    }

    private static void writeGutterIconList(ByteBuffer data, java.util.List<? extends GutterIcon> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeGutterIconFields(data, values.get(i));
        }
    }

    private static int sizeOfGutterIconList(java.util.List<? extends GutterIcon> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfGutterIcon(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<GutterIconRenderItem> readGutterIconRenderItemList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<GutterIconRenderItem> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readGutterIconRenderItem(data));
        }
        return values;
    }

    private static void writeIndentGuideList(ByteBuffer data, java.util.List<? extends IndentGuide> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeIndentGuideFields(data, values.get(i));
        }
    }

    private static int sizeOfIndentGuideList(java.util.List<? extends IndentGuide> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfIndentGuide(values.get(i));
            }
        }
        return size;
    }

    private static void writeInlayHintList(ByteBuffer data, java.util.List<? extends InlayHint> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeInlayHintFields(data, values.get(i));
        }
    }

    private static int sizeOfInlayHintList(java.util.List<? extends InlayHint> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfInlayHint(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<KeyBinding> readKeyBindingList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<KeyBinding> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readKeyBinding(data));
        }
        return values;
    }

    private static void writeKeyBindingList(ByteBuffer data, java.util.List<? extends KeyBinding> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeKeyBindingFields(data, values.get(i));
        }
    }

    private static int sizeOfKeyBindingList(java.util.List<? extends KeyBinding> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfKeyBinding(values.get(i));
            }
        }
        return size;
    }

    private static void writeLinkSpanList(ByteBuffer data, java.util.List<? extends LinkSpan> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeLinkSpanFields(data, values.get(i));
        }
    }

    private static int sizeOfLinkSpanList(java.util.List<? extends LinkSpan> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfLinkSpan(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<LinkedEditingRect> readLinkedEditingRectList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<LinkedEditingRect> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readLinkedEditingRect(data));
        }
        return values;
    }

    private static void writePhantomTextList(ByteBuffer data, java.util.List<? extends PhantomText> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writePhantomTextFields(data, values.get(i));
        }
    }

    private static int sizeOfPhantomTextList(java.util.List<? extends PhantomText> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfPhantomText(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<Rect> readRectList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<Rect> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readRect(data));
        }
        return values;
    }

    private static void writeRectList(ByteBuffer data, java.util.List<? extends Rect> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeRectFields(data, values.get(i));
        }
    }

    private static int sizeOfRectList(java.util.List<? extends Rect> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfRect(values.get(i));
            }
        }
        return size;
    }

    private static void writeSeparatorGuideList(ByteBuffer data, java.util.List<? extends SeparatorGuide> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeSeparatorGuideFields(data, values.get(i));
        }
    }

    private static int sizeOfSeparatorGuideList(java.util.List<? extends SeparatorGuide> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfSeparatorGuide(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<StyleSpan> readStyleSpanList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<StyleSpan> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readStyleSpan(data));
        }
        return values;
    }

    private static void writeStyleSpanList(ByteBuffer data, java.util.List<? extends StyleSpan> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeStyleSpanFields(data, values.get(i));
        }
    }

    private static int sizeOfStyleSpanList(java.util.List<? extends StyleSpan> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfStyleSpan(values.get(i));
            }
        }
        return size;
    }

    private static void writeTabStopGroupList(ByteBuffer data, java.util.List<? extends TabStopGroup> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeTabStopGroupFields(data, values.get(i));
        }
    }

    private static int sizeOfTabStopGroupList(java.util.List<? extends TabStopGroup> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfTabStopGroup(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<TextChange> readTextChangeList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextChange> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextChange(data));
        }
        return values;
    }

    private static ArrayList<TextPosition> readTextPositionList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextPosition> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextPosition(data));
        }
        return values;
    }

    private static void writeTextPositionList(ByteBuffer data, java.util.List<? extends TextPosition> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeTextPositionFields(data, values.get(i));
        }
    }

    private static int sizeOfTextPositionList(java.util.List<? extends TextPosition> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfTextPosition(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<TextRange> readTextRangeList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextRange> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextRange(data));
        }
        return values;
    }

    private static void writeTextRangeList(ByteBuffer data, java.util.List<? extends TextRange> values) {
        int count = values == null ? 0 : values.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            writeTextRangeFields(data, values.get(i));
        }
    }

    private static int sizeOfTextRangeList(java.util.List<? extends TextRange> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfTextRange(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<VisualLine> readVisualLineList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<VisualLine> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readVisualLine(data));
        }
        return values;
    }

    private static ArrayList<VisualRun> readVisualRunList(ByteBuffer data) {
        int count = data.getInt();
        if (count < 0 || count > data.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<VisualRun> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readVisualRun(data));
        }
        return values;
    }

    private static EditorActionResult readEditorActionResult(ByteBuffer data) {
        EditorActionResult value = new EditorActionResult();
        value.handled = data.getInt() != 0;
        value.needsRedraw = data.getInt() != 0;
        value.reason = EditorActionReason.fromValue(data.getInt());
        value.contentChanged = data.getInt() != 0;
        value.cursorChanged = data.getInt() != 0;
        value.selectionChanged = data.getInt() != 0;
        value.scrollChanged = data.getInt() != 0;
        value.scaleChanged = data.getInt() != 0;
        value.pointerCursorChanged = data.getInt() != 0;
        value.compositionChanged = data.getInt() != 0;
        value.decorationChanged = data.getInt() != 0;
        value.needsImeSync = data.getInt() != 0;
        value.needsEdgeScroll = data.getInt() != 0;
        value.needsFling = data.getInt() != 0;
        value.needsAnimation = data.getInt() != 0;
        value.isHandleDrag = data.getInt() != 0;
        value.changes = readTextChangeList(data);
        value.cursorBefore = readTextPosition(data);
        value.cursorAfter = readTextPosition(data);
        value.hasSelectionBefore = data.getInt() != 0;
        value.hasSelectionAfter = data.getInt() != 0;
        value.selectionBefore = readTextRange(data);
        value.selectionAfter = readTextRange(data);
        value.scrollXBefore = data.getFloat();
        value.scrollYBefore = data.getFloat();
        value.scrollXAfter = data.getFloat();
        value.scrollYAfter = data.getFloat();
        value.scaleBefore = data.getFloat();
        value.scaleAfter = data.getFloat();
        value.pointerCursorBefore = PointerCursorType.fromValue(data.getInt());
        value.pointerCursorAfter = PointerCursorType.fromValue(data.getInt());
        value.imeSync = readImeSyncSnapshot(data);
        value.gestureType = GestureType.fromValue(data.getInt());
        value.gestureEventType = EventType.fromValue(data.getInt());
        value.tapPoint = readPointF(data);
        value.hitTarget = readHitTarget(data);
        value.modifiers = data.getInt();
        value.command = data.getInt();
        return value;
    }

    public static EditorActionResult decodeEditorActionResult(ByteBuffer data) {
        prepare(data);
        return readEditorActionResult(data);
    }

    private static void writeBracketGuideFields(ByteBuffer data, BracketGuide value) {
        writeTextPositionFields(data, value.parent);
        writeTextPositionFields(data, value.end);
        writeTextPositionList(data, value.children);
    }

    public static void writeBracketGuide(ByteBuffer data, BracketGuide value) {
        prepare(data);
        writeBracketGuideFields(data, value);
    }

    public static int sizeOfBracketGuide(BracketGuide value) {
        int size = 0;
        size += sizeOfTextPosition(value.parent);
        size += sizeOfTextPosition(value.end);
        size += sizeOfTextPositionList(value.children);
        return size;
    }

    private static void writeCodeLensItemFields(ByteBuffer data, CodeLensItem value) {
        data.putInt(value.column);
        data.putInt(value.commandId);
        writeUtf8String(data, value.text);
    }

    public static void writeCodeLensItem(ByteBuffer data, CodeLensItem value) {
        prepare(data);
        writeCodeLensItemFields(data, value);
    }

    public static int sizeOfCodeLensItem(CodeLensItem value) {
        int size = 0;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeDiagnosticFields(ByteBuffer data, Diagnostic value) {
        data.putInt(value.column);
        data.putInt(value.length);
        data.putInt(value.severity.value);
    }

    public static void writeDiagnostic(ByteBuffer data, Diagnostic value) {
        prepare(data);
        writeDiagnosticFields(data, value);
    }

    public static int sizeOfDiagnostic(Diagnostic value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeFlowGuideFields(ByteBuffer data, FlowGuide value) {
        writeTextPositionFields(data, value.start);
        writeTextPositionFields(data, value.end);
    }

    public static void writeFlowGuide(ByteBuffer data, FlowGuide value) {
        prepare(data);
        writeFlowGuideFields(data, value);
    }

    public static int sizeOfFlowGuide(FlowGuide value) {
        int size = 0;
        size += sizeOfTextPosition(value.start);
        size += sizeOfTextPosition(value.end);
        return size;
    }

    private static void writeFoldRegionFields(ByteBuffer data, FoldRegion value) {
        data.putInt(value.startLine);
        data.putInt(value.endLine);
        data.put((byte) (value.collapsed ? 1 : 0));
    }

    public static void writeFoldRegion(ByteBuffer data, FoldRegion value) {
        prepare(data);
        writeFoldRegionFields(data, value);
    }

    public static int sizeOfFoldRegion(FoldRegion value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 1;
        return size;
    }

    private static void writeGutterIconFields(ByteBuffer data, GutterIcon value) {
        data.putInt(value.iconId);
    }

    public static void writeGutterIcon(ByteBuffer data, GutterIcon value) {
        prepare(data);
        writeGutterIconFields(data, value);
    }

    public static int sizeOfGutterIcon(GutterIcon value) {
        int size = 0;
        size += 4;
        return size;
    }

    private static void writeIndentGuideFields(ByteBuffer data, IndentGuide value) {
        writeTextPositionFields(data, value.start);
        writeTextPositionFields(data, value.end);
    }

    public static void writeIndentGuide(ByteBuffer data, IndentGuide value) {
        prepare(data);
        writeIndentGuideFields(data, value);
    }

    public static int sizeOfIndentGuide(IndentGuide value) {
        int size = 0;
        size += sizeOfTextPosition(value.start);
        size += sizeOfTextPosition(value.end);
        return size;
    }

    private static void writeInlayHintFields(ByteBuffer data, InlayHint value) {
        data.putInt(value.type.value);
        data.putInt(value.column);
        data.putInt(value.intValue);
        writeUtf8String(data, value.text);
    }

    public static void writeInlayHint(ByteBuffer data, InlayHint value) {
        prepare(data);
        writeInlayHintFields(data, value);
    }

    public static int sizeOfInlayHint(InlayHint value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeLinkSpanFields(ByteBuffer data, LinkSpan value) {
        data.putInt(value.column);
        data.putInt(value.length);
        writeUtf8String(data, value.target);
    }

    public static void writeLinkSpan(ByteBuffer data, LinkSpan value) {
        prepare(data);
        writeLinkSpanFields(data, value);
    }

    public static int sizeOfLinkSpan(LinkSpan value) {
        int size = 0;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.target);
        return size;
    }

    private static void writePhantomTextFields(ByteBuffer data, PhantomText value) {
        data.putInt(value.column);
        writeUtf8String(data, value.text);
    }

    public static void writePhantomText(ByteBuffer data, PhantomText value) {
        prepare(data);
        writePhantomTextFields(data, value);
    }

    public static int sizeOfPhantomText(PhantomText value) {
        int size = 0;
        size += 4;
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeSeparatorGuideFields(ByteBuffer data, SeparatorGuide value) {
        data.putInt(value.line);
        data.putInt(value.style.value);
        data.putInt(value.count);
        data.putInt(value.textEndColumn);
    }

    public static void writeSeparatorGuide(ByteBuffer data, SeparatorGuide value) {
        prepare(data);
        writeSeparatorGuideFields(data, value);
    }

    public static int sizeOfSeparatorGuide(SeparatorGuide value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static StyleSpan readStyleSpan(ByteBuffer data) {
        StyleSpan value = new StyleSpan();
        value.column = data.getInt();
        value.length = data.getInt();
        value.styleId = data.getInt();
        return value;
    }

    public static StyleSpan decodeStyleSpan(ByteBuffer data) {
        prepare(data);
        return readStyleSpan(data);
    }

    private static void writeStyleSpanFields(ByteBuffer data, StyleSpan value) {
        data.putInt(value.column);
        data.putInt(value.length);
        data.putInt(value.styleId);
    }

    public static void writeStyleSpan(ByteBuffer data, StyleSpan value) {
        prepare(data);
        writeStyleSpanFields(data, value);
    }

    public static int sizeOfStyleSpan(StyleSpan value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static TextStyle readTextStyle(ByteBuffer data) {
        TextStyle value = new TextStyle();
        value.color = data.getInt();
        value.backgroundColor = data.getInt();
        value.fontStyle = data.getInt();
        return value;
    }

    public static TextStyle decodeTextStyle(ByteBuffer data) {
        prepare(data);
        return readTextStyle(data);
    }

    private static void writeTextStyleFields(ByteBuffer data, TextStyle value) {
        data.putInt(value.color);
        data.putInt(value.backgroundColor);
        data.putInt(value.fontStyle);
    }

    public static void writeTextStyle(ByteBuffer data, TextStyle value) {
        prepare(data);
        writeTextStyleFields(data, value);
    }

    public static int sizeOfTextStyle(TextStyle value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeEditorOptionsFields(ByteBuffer data, EditorOptions value) {
        data.putFloat(value.touchSlop);
        data.putLong(value.doubleTapTimeout);
        data.putLong(value.longPressMs);
        data.putFloat(value.flingFriction);
        data.putFloat(value.flingMinVelocity);
        data.putFloat(value.flingMaxVelocity);
        data.putLong(value.maxUndoStackSize);
        data.putLong(value.keyChordTimeoutMs);
        data.put((byte) (value.revealSelectionEndOnSelectAll ? 1 : 0));
    }

    public static void writeEditorOptions(ByteBuffer data, EditorOptions value) {
        prepare(data);
        writeEditorOptionsFields(data, value);
    }

    public static int sizeOfEditorOptions(EditorOptions value) {
        int size = 0;
        size += 4;
        size += 8;
        size += 8;
        size += 4;
        size += 4;
        size += 4;
        size += 8;
        size += 8;
        size += 1;
        return size;
    }

    private static void writeHandleConfigFields(ByteBuffer data, HandleConfig value) {
        writeOffsetRectFields(data, value.startHitOffset);
        writeOffsetRectFields(data, value.endHitOffset);
    }

    public static void writeHandleConfig(ByteBuffer data, HandleConfig value) {
        prepare(data);
        writeHandleConfigFields(data, value);
    }

    public static int sizeOfHandleConfig(HandleConfig value) {
        int size = 0;
        size += sizeOfOffsetRect(value.startHitOffset);
        size += sizeOfOffsetRect(value.endHitOffset);
        return size;
    }

    private static void writeScrollbarConfigFields(ByteBuffer data, ScrollbarConfig value) {
        data.putFloat(value.thickness);
        data.putFloat(value.minThumb);
        data.putFloat(value.thumbHitPadding);
        data.putInt(value.mode.value);
        data.put((byte) (value.thumbDraggable ? 1 : 0));
        data.putInt(value.trackTapMode.value);
        data.putShort((short) value.fadeDelayMs);
        data.putShort((short) value.fadeDurationMs);
    }

    public static void writeScrollbarConfig(ByteBuffer data, ScrollbarConfig value) {
        prepare(data);
        writeScrollbarConfigFields(data, value);
    }

    public static int sizeOfScrollbarConfig(ScrollbarConfig value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 1;
        size += 4;
        size += 2;
        size += 2;
        return size;
    }

    private static IntRange readIntRange(ByteBuffer data) {
        IntRange value = new IntRange();
        value.start = data.getInt();
        value.end = data.getInt();
        return value;
    }

    public static IntRange decodeIntRange(ByteBuffer data) {
        prepare(data);
        return readIntRange(data);
    }

    private static void writeIntRangeFields(ByteBuffer data, IntRange value) {
        data.putInt(value.start);
        data.putInt(value.end);
    }

    public static void writeIntRange(ByteBuffer data, IntRange value) {
        prepare(data);
        writeIntRangeFields(data, value);
    }

    public static int sizeOfIntRange(IntRange value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static OffsetRect readOffsetRect(ByteBuffer data) {
        OffsetRect value = new OffsetRect();
        value.left = data.getFloat();
        value.top = data.getFloat();
        value.right = data.getFloat();
        value.bottom = data.getFloat();
        return value;
    }

    public static OffsetRect decodeOffsetRect(ByteBuffer data) {
        prepare(data);
        return readOffsetRect(data);
    }

    private static void writeOffsetRectFields(ByteBuffer data, OffsetRect value) {
        data.putFloat(value.left);
        data.putFloat(value.top);
        data.putFloat(value.right);
        data.putFloat(value.bottom);
    }

    public static void writeOffsetRect(ByteBuffer data, OffsetRect value) {
        prepare(data);
        writeOffsetRectFields(data, value);
    }

    public static int sizeOfOffsetRect(OffsetRect value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static PointF readPointF(ByteBuffer data) {
        PointF value = new PointF();
        value.x = data.getFloat();
        value.y = data.getFloat();
        return value;
    }

    public static PointF decodePointF(ByteBuffer data) {
        prepare(data);
        return readPointF(data);
    }

    private static void writePointFFields(ByteBuffer data, PointF value) {
        data.putFloat(value.x);
        data.putFloat(value.y);
    }

    public static void writePointF(ByteBuffer data, PointF value) {
        prepare(data);
        writePointFFields(data, value);
    }

    public static int sizeOfPointF(PointF value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static Rect readRect(ByteBuffer data) {
        Rect value = new Rect();
        value.origin = readPointF(data);
        value.width = data.getFloat();
        value.height = data.getFloat();
        return value;
    }

    public static Rect decodeRect(ByteBuffer data) {
        prepare(data);
        return readRect(data);
    }

    private static void writeRectFields(ByteBuffer data, Rect value) {
        writePointFFields(data, value.origin);
        data.putFloat(value.width);
        data.putFloat(value.height);
    }

    public static void writeRect(ByteBuffer data, Rect value) {
        prepare(data);
        writeRectFields(data, value);
    }

    public static int sizeOfRect(Rect value) {
        int size = 0;
        size += sizeOfPointF(value.origin);
        size += 4;
        size += 4;
        return size;
    }

    private static TextChange readTextChange(ByteBuffer data) {
        TextChange value = new TextChange();
        value.range = readTextRange(data);
        value.newText = readUtf8String(data);
        return value;
    }

    public static TextChange decodeTextChange(ByteBuffer data) {
        prepare(data);
        return readTextChange(data);
    }

    private static TextPosition readTextPosition(ByteBuffer data) {
        TextPosition value = new TextPosition();
        value.line = data.getInt();
        value.column = data.getInt();
        return value;
    }

    public static TextPosition decodeTextPosition(ByteBuffer data) {
        prepare(data);
        return readTextPosition(data);
    }

    private static void writeTextPositionFields(ByteBuffer data, TextPosition value) {
        data.putInt(value.line);
        data.putInt(value.column);
    }

    public static void writeTextPosition(ByteBuffer data, TextPosition value) {
        prepare(data);
        writeTextPositionFields(data, value);
    }

    public static int sizeOfTextPosition(TextPosition value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static TextRange readTextRange(ByteBuffer data) {
        TextRange value = new TextRange();
        value.start = readTextPosition(data);
        value.end = readTextPosition(data);
        return value;
    }

    public static TextRange decodeTextRange(ByteBuffer data) {
        prepare(data);
        return readTextRange(data);
    }

    private static void writeTextRangeFields(ByteBuffer data, TextRange value) {
        writeTextPositionFields(data, value.start);
        writeTextPositionFields(data, value.end);
    }

    public static void writeTextRange(ByteBuffer data, TextRange value) {
        prepare(data);
        writeTextRangeFields(data, value);
    }

    public static int sizeOfTextRange(TextRange value) {
        int size = 0;
        size += sizeOfTextPosition(value.start);
        size += sizeOfTextPosition(value.end);
        return size;
    }

    private static ImeInputContext readImeInputContext(ByteBuffer data) {
        ImeInputContext value = new ImeInputContext();
        value.id = data.getLong();
        value.revision = data.getInt();
        value.documentStartOffset = data.getInt();
        value.text = readUtf8String(data);
        value.selection = readImeTextRange(data);
        value.hasComposition = data.getInt() != 0;
        value.composition = readImeTextRange(data);
        value.kind = ImeInputContextKind.fromValue(data.getInt());
        return value;
    }

    public static ImeInputContext decodeImeInputContext(ByteBuffer data) {
        prepare(data);
        return readImeInputContext(data);
    }

    private static ImeSyncSnapshot readImeSyncSnapshot(ByteBuffer data) {
        ImeSyncSnapshot value = new ImeSyncSnapshot();
        value.cursor = readTextPosition(data);
        value.selection = readTextRange(data);
        value.hasSelection = data.getInt() != 0;
        value.hasComposingSession = data.getInt() != 0;
        value.hasVisibleCompositionRange = data.getInt() != 0;
        value.visibleCompositionRange = readTextRange(data);
        value.hasPlatformMarkedRange = data.getInt() != 0;
        value.platformMarkedRange = readTextRange(data);
        value.preeditStorage = ImePreeditStorage.fromValue(data.getInt());
        value.contextPolicy = ImeContextPolicy.fromValue(data.getInt());
        value.clearPlatformPreedit = data.getInt() != 0;
        return value;
    }

    public static ImeSyncSnapshot decodeImeSyncSnapshot(ByteBuffer data) {
        prepare(data);
        return readImeSyncSnapshot(data);
    }

    private static ImeTextRange readImeTextRange(ByteBuffer data) {
        ImeTextRange value = new ImeTextRange();
        value.start = data.getInt();
        value.end = data.getInt();
        return value;
    }

    public static ImeTextRange decodeImeTextRange(ByteBuffer data) {
        prepare(data);
        return readImeTextRange(data);
    }

    private static void writeImeTextRangeFields(ByteBuffer data, ImeTextRange value) {
        data.putInt(value.start);
        data.putInt(value.end);
    }

    public static void writeImeTextRange(ByteBuffer data, ImeTextRange value) {
        prepare(data);
        writeImeTextRangeFields(data, value);
    }

    public static int sizeOfImeTextRange(ImeTextRange value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static HitTarget readHitTarget(ByteBuffer data) {
        HitTarget value = new HitTarget();
        value.type = HitTargetType.fromValue(data.getInt());
        value.line = data.getInt();
        value.column = data.getInt();
        value.iconId = data.getInt();
        value.colorValue = data.getInt();
        return value;
    }

    public static HitTarget decodeHitTarget(ByteBuffer data) {
        prepare(data);
        return readHitTarget(data);
    }

    private static KeyBinding readKeyBinding(ByteBuffer data) {
        KeyBinding value = new KeyBinding();
        value.first = readKeyChord(data);
        value.second = readKeyChord(data);
        value.command = data.getInt();
        return value;
    }

    public static KeyBinding decodeKeyBinding(ByteBuffer data) {
        prepare(data);
        return readKeyBinding(data);
    }

    private static void writeKeyBindingFields(ByteBuffer data, KeyBinding value) {
        writeKeyChordFields(data, value.first);
        writeKeyChordFields(data, value.second);
        data.putInt(value.command);
    }

    public static void writeKeyBinding(ByteBuffer data, KeyBinding value) {
        prepare(data);
        writeKeyBindingFields(data, value);
    }

    public static int sizeOfKeyBinding(KeyBinding value) {
        int size = 0;
        size += sizeOfKeyChord(value.first);
        size += sizeOfKeyChord(value.second);
        size += 4;
        return size;
    }

    private static KeyChord readKeyChord(ByteBuffer data) {
        KeyChord value = new KeyChord();
        value.modifiers = data.get() & 0xFF;
        value.keyCode = data.getShort() & 0xFFFF;
        return value;
    }

    public static KeyChord decodeKeyChord(ByteBuffer data) {
        prepare(data);
        return readKeyChord(data);
    }

    private static void writeKeyChordFields(ByteBuffer data, KeyChord value) {
        data.put((byte) value.modifiers);
        data.putShort((short) value.keyCode);
    }

    public static void writeKeyChord(ByteBuffer data, KeyChord value) {
        prepare(data);
        writeKeyChordFields(data, value);
    }

    public static int sizeOfKeyChord(KeyChord value) {
        int size = 0;
        size += 1;
        size += 2;
        return size;
    }

    private static void writeLinkedEditingModelFields(ByteBuffer data, LinkedEditingModel value) {
        writeTabStopGroupList(data, value.groups);
    }

    public static void writeLinkedEditingModel(ByteBuffer data, LinkedEditingModel value) {
        prepare(data);
        writeLinkedEditingModelFields(data, value);
    }

    public static int sizeOfLinkedEditingModel(LinkedEditingModel value) {
        int size = 0;
        size += sizeOfTabStopGroupList(value.groups);
        return size;
    }

    private static void writeTabStopGroupFields(ByteBuffer data, TabStopGroup value) {
        data.putInt(value.index);
        writeTextRangeList(data, value.ranges);
        writeUtf8String(data, value.defaultText);
    }

    public static void writeTabStopGroup(ByteBuffer data, TabStopGroup value) {
        prepare(data);
        writeTabStopGroupFields(data, value);
    }

    public static int sizeOfTabStopGroup(TabStopGroup value) {
        int size = 0;
        size += 4;
        size += sizeOfTextRangeList(value.ranges);
        size += sizeOfUtf8String(value.defaultText);
        return size;
    }

    private static CompositionDecoration readCompositionDecoration(ByteBuffer data) {
        CompositionDecoration value = new CompositionDecoration();
        value.active = data.getInt() != 0;
        value.rect = readRect(data);
        return value;
    }

    public static CompositionDecoration decodeCompositionDecoration(ByteBuffer data) {
        prepare(data);
        return readCompositionDecoration(data);
    }

    private static Cursor readCursor(ByteBuffer data) {
        Cursor value = new Cursor();
        value.textPosition = readTextPosition(data);
        value.position = readPointF(data);
        value.height = data.getFloat();
        value.visible = data.getInt() != 0;
        value.showDragger = data.getInt() != 0;
        return value;
    }

    public static Cursor decodeCursor(ByteBuffer data) {
        prepare(data);
        return readCursor(data);
    }

    private static CursorRect readCursorRect(ByteBuffer data) {
        CursorRect value = new CursorRect();
        value.x = data.getFloat();
        value.y = data.getFloat();
        value.height = data.getFloat();
        return value;
    }

    public static CursorRect decodeCursorRect(ByteBuffer data) {
        prepare(data);
        return readCursorRect(data);
    }

    private static void writeCursorRectFields(ByteBuffer data, CursorRect value) {
        data.putFloat(value.x);
        data.putFloat(value.y);
        data.putFloat(value.height);
    }

    public static void writeCursorRect(ByteBuffer data, CursorRect value) {
        prepare(data);
        writeCursorRectFields(data, value);
    }

    public static int sizeOfCursorRect(CursorRect value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static DiagnosticDecoration readDiagnosticDecoration(ByteBuffer data) {
        DiagnosticDecoration value = new DiagnosticDecoration();
        value.rect = readRect(data);
        value.severity = data.getInt();
        return value;
    }

    public static DiagnosticDecoration decodeDiagnosticDecoration(ByteBuffer data) {
        prepare(data);
        return readDiagnosticDecoration(data);
    }

    private static EditorRenderModel readEditorRenderModel(ByteBuffer data) {
        EditorRenderModel value = new EditorRenderModel();
        value.splitX = data.getFloat();
        value.splitLineVisible = data.getInt() != 0;
        value.scrollX = data.getFloat();
        value.scrollY = data.getFloat();
        value.viewportWidth = data.getFloat();
        value.viewportHeight = data.getFloat();
        value.currentLine = readPointF(data);
        value.currentLineRenderMode = CurrentLineRenderMode.fromValue(data.getInt());
        value.lines = readVisualLineList(data);
        value.cursor = readCursor(data);
        value.selectionRects = readRectList(data);
        value.selectionStartHandle = readSelectionHandle(data);
        value.selectionEndHandle = readSelectionHandle(data);
        value.compositionDecoration = readCompositionDecoration(data);
        value.guideSegments = readGuideSegmentList(data);
        value.diagnosticDecorations = readDiagnosticDecorationList(data);
        value.maxGutterIcons = data.getInt();
        value.linkedEditingRects = readLinkedEditingRectList(data);
        value.bracketHighlightRects = readRectList(data);
        value.gutterIcons = readGutterIconRenderItemList(data);
        value.foldMarkers = readFoldMarkerRenderItemList(data);
        value.verticalScrollbar = readScrollbarModel(data);
        value.horizontalScrollbar = readScrollbarModel(data);
        value.gutterSticky = data.getInt() != 0;
        value.gutterVisible = data.getInt() != 0;
        value.pointerCursorType = PointerCursorType.fromValue(data.getInt());
        return value;
    }

    public static EditorRenderModel decodeEditorRenderModel(ByteBuffer data) {
        prepare(data);
        return readEditorRenderModel(data);
    }

    private static FoldMarkerRenderItem readFoldMarkerRenderItem(ByteBuffer data) {
        FoldMarkerRenderItem value = new FoldMarkerRenderItem();
        value.logicalLine = data.getInt();
        value.foldState = FoldState.fromValue(data.getInt());
        value.rect = readRect(data);
        return value;
    }

    public static FoldMarkerRenderItem decodeFoldMarkerRenderItem(ByteBuffer data) {
        prepare(data);
        return readFoldMarkerRenderItem(data);
    }

    private static GuideSegment readGuideSegment(ByteBuffer data) {
        GuideSegment value = new GuideSegment();
        value.direction = GuideDirection.fromValue(data.getInt());
        value.type = GuideType.fromValue(data.getInt());
        value.style = GuideStyle.fromValue(data.getInt());
        value.start = readPointF(data);
        value.end = readPointF(data);
        value.arrowEnd = data.getInt() != 0;
        return value;
    }

    public static GuideSegment decodeGuideSegment(ByteBuffer data) {
        prepare(data);
        return readGuideSegment(data);
    }

    private static GutterIconRenderItem readGutterIconRenderItem(ByteBuffer data) {
        GutterIconRenderItem value = new GutterIconRenderItem();
        value.logicalLine = data.getInt();
        value.iconId = data.getInt();
        value.rect = readRect(data);
        return value;
    }

    public static GutterIconRenderItem decodeGutterIconRenderItem(ByteBuffer data) {
        prepare(data);
        return readGutterIconRenderItem(data);
    }

    private static LayoutMetrics readLayoutMetrics(ByteBuffer data) {
        LayoutMetrics value = new LayoutMetrics();
        value.fontHeight = data.getFloat();
        value.fontAscent = data.getFloat();
        value.lineSpacingAdd = data.getFloat();
        value.lineSpacingMult = data.getFloat();
        value.lineNumberMargin = data.getFloat();
        value.lineNumberWidth = data.getFloat();
        value.contentStartPadding = data.getFloat();
        value.maxGutterIcons = data.getInt();
        value.inlayHintPadding = data.getFloat();
        value.inlayHintMargin = data.getFloat();
        value.foldArrowMode = FoldArrowMode.fromValue(data.getInt());
        value.hasFoldRegions = data.getInt() != 0;
        value.gutterSticky = data.getInt() != 0;
        value.gutterVisible = data.getInt() != 0;
        return value;
    }

    public static LayoutMetrics decodeLayoutMetrics(ByteBuffer data) {
        prepare(data);
        return readLayoutMetrics(data);
    }

    private static LinkedEditingRect readLinkedEditingRect(ByteBuffer data) {
        LinkedEditingRect value = new LinkedEditingRect();
        value.rect = readRect(data);
        value.isActive = data.getInt() != 0;
        return value;
    }

    public static LinkedEditingRect decodeLinkedEditingRect(ByteBuffer data) {
        prepare(data);
        return readLinkedEditingRect(data);
    }

    private static ScrollMetrics readScrollMetrics(ByteBuffer data) {
        ScrollMetrics value = new ScrollMetrics();
        value.scale = data.getFloat();
        value.scrollX = data.getFloat();
        value.scrollY = data.getFloat();
        value.maxScrollX = data.getFloat();
        value.maxScrollY = data.getFloat();
        value.contentWidth = data.getFloat();
        value.contentHeight = data.getFloat();
        value.viewportWidth = data.getFloat();
        value.viewportHeight = data.getFloat();
        value.textAreaX = data.getFloat();
        value.textAreaWidth = data.getFloat();
        value.canScrollX = data.getInt() != 0;
        value.canScrollY = data.getInt() != 0;
        return value;
    }

    public static ScrollMetrics decodeScrollMetrics(ByteBuffer data) {
        prepare(data);
        return readScrollMetrics(data);
    }

    private static ScrollbarModel readScrollbarModel(ByteBuffer data) {
        ScrollbarModel value = new ScrollbarModel();
        value.visible = data.getInt() != 0;
        value.alpha = data.getFloat();
        value.thumbActive = data.getInt() != 0;
        value.track = readRect(data);
        value.thumb = readRect(data);
        return value;
    }

    public static ScrollbarModel decodeScrollbarModel(ByteBuffer data) {
        prepare(data);
        return readScrollbarModel(data);
    }

    private static SelectionHandle readSelectionHandle(ByteBuffer data) {
        SelectionHandle value = new SelectionHandle();
        value.position = readPointF(data);
        value.height = data.getFloat();
        value.visible = data.getInt() != 0;
        return value;
    }

    public static SelectionHandle decodeSelectionHandle(ByteBuffer data) {
        prepare(data);
        return readSelectionHandle(data);
    }

    private static VisualLine readVisualLine(ByteBuffer data) {
        VisualLine value = new VisualLine();
        value.logicalLine = data.getInt();
        value.wrapIndex = data.getInt();
        value.lineNumberPosition = readPointF(data);
        value.runs = readVisualRunList(data);
        value.kind = VisualLineKind.fromValue(data.getInt());
        value.ownsGutterSemantics = data.getInt() != 0;
        value.foldState = FoldState.fromValue(data.getInt());
        return value;
    }

    public static VisualLine decodeVisualLine(ByteBuffer data) {
        prepare(data);
        return readVisualLine(data);
    }

    private static VisualRun readVisualRun(ByteBuffer data) {
        VisualRun value = new VisualRun();
        value.type = VisualRunType.fromValue(data.getInt());
        value.x = data.getFloat();
        value.y = data.getFloat();
        value.text = readUtf8String(data);
        value.style = readTextStyle(data);
        value.iconId = data.getInt();
        value.colorValue = data.getInt();
        value.width = data.getFloat();
        value.padding = data.getFloat();
        value.margin = data.getFloat();
        value.active = data.getInt() != 0;
        return value;
    }

    public static VisualRun decodeVisualRun(ByteBuffer data) {
        prepare(data);
        return readVisualRun(data);
    }

    public static ByteBuffer encodeBracketGuide(BracketGuide value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfBracketGuide(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeBracketGuideFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeCodeLensItem(CodeLensItem value) {
        int size = 0;
        size += 4;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(value.column);
        data.putInt(value.commandId);
        writeUtf8Bytes(data, textUtf8);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeDiagnostic(Diagnostic value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfDiagnostic(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeDiagnosticFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeFlowGuide(FlowGuide value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfFlowGuide(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeFlowGuideFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeFoldRegion(FoldRegion value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfFoldRegion(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeFoldRegionFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeGutterIcon(GutterIcon value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfGutterIcon(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeGutterIconFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeIndentGuide(IndentGuide value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfIndentGuide(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeIndentGuideFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeInlayHint(InlayHint value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(value.type.value);
        data.putInt(value.column);
        data.putInt(value.intValue);
        writeUtf8Bytes(data, textUtf8);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeLinkSpan(LinkSpan value) {
        int size = 0;
        size += 4;
        size += 4;
        byte[] targetUtf8 = utf8Bytes(value.target);
        size += 4 + targetUtf8.length;
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(value.column);
        data.putInt(value.length);
        writeUtf8Bytes(data, targetUtf8);
        data.flip();
        return data;
    }

    public static ByteBuffer encodePhantomText(PhantomText value) {
        int size = 0;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(value.column);
        writeUtf8Bytes(data, textUtf8);
        data.flip();
        return data;
    }

    private static void writeRegisterBatchTextStylesPayloadWire(ByteBuffer data, java.util.Map<Integer, ? extends TextStyle> styleByStyleId) {
        java.util.TreeMap<Integer, TextStyle> sortedStyleByStyleId = new java.util.TreeMap<>();
        if (styleByStyleId != null) {
            for (java.util.Map.Entry<Integer, ? extends TextStyle> entry : styleByStyleId.entrySet()) {
                sortedStyleByStyleId.put(entry.getKey(), entry.getValue());
            }
        }
        data.putInt(sortedStyleByStyleId.size());
        for (java.util.Map.Entry<Integer, TextStyle> entry : sortedStyleByStyleId.entrySet()) {
            data.putInt(entry.getKey());
            writeTextStyleFields(data, entry.getValue());
        }
    }

    private static int sizeOfRegisterBatchTextStylesPayloadWire(java.util.Map<Integer, ? extends TextStyle> styleByStyleId) {
        int size = 0;
        size += 4;
        if (styleByStyleId != null) {
            for (java.util.Map.Entry<Integer, ? extends TextStyle> entry : styleByStyleId.entrySet()) {
                size += 4;
                size += sizeOfTextStyle(entry.getValue());
            }
        }
        return size;
    }

    public static ByteBuffer encodeRegisterBatchTextStylesPayload(java.util.Map<Integer, ? extends TextStyle> styleByStyleId) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId)).order(ByteOrder.LITTLE_ENDIAN);
        writeRegisterBatchTextStylesPayloadWire(data, styleByStyleId);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSeparatorGuide(SeparatorGuide value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSeparatorGuide(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeSeparatorGuideFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetBatchLineCodeLensPayload(android.util.SparseArray<? extends java.util.List<? extends CodeLensItem>> itemsByLine) {
        int size = 0;
        int itemsByLineCount = itemsByLine == null ? 0 : itemsByLine.size();
        int itemsByLineItemCount = 0;
        size += 4;
        for (int itemsByLineIndex = 0; itemsByLineIndex < itemsByLineCount; itemsByLineIndex++) {
            size += 4;
            java.util.List<? extends CodeLensItem> itemsByLineItems = itemsByLine.valueAt(itemsByLineIndex);
            int itemsByLineItemsCount = itemsByLineItems == null ? 0 : itemsByLineItems.size();
            itemsByLineItemCount += itemsByLineItemsCount;
            size += 4;
        }
        byte[][] itemsByLineTextUtf8 = new byte[itemsByLineItemCount][];
        int itemsByLineItemIndex = 0;
        for (int itemsByLineIndex = 0; itemsByLineIndex < itemsByLineCount; itemsByLineIndex++) {
            java.util.List<? extends CodeLensItem> itemsByLineItems = itemsByLine.valueAt(itemsByLineIndex);
            int itemsByLineItemsCount = itemsByLineItems == null ? 0 : itemsByLineItems.size();
            for (int itemsByLineItemsIndex = 0; itemsByLineItemsIndex < itemsByLineItemsCount; itemsByLineItemsIndex++) {
                CodeLensItem itemsByLineItem = itemsByLineItems.get(itemsByLineItemsIndex);
                size += 4;
                size += 4;
                byte[] itemsByLineTextBytes = utf8Bytes(itemsByLineItem.text);
                itemsByLineTextUtf8[itemsByLineItemIndex] = itemsByLineTextBytes;
                size += 4 + itemsByLineTextBytes.length;
                itemsByLineItemIndex++;
            }
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(itemsByLineCount);
        itemsByLineItemIndex = 0;
        for (int itemsByLineIndex = 0; itemsByLineIndex < itemsByLineCount; itemsByLineIndex++) {
            data.putInt(itemsByLine.keyAt(itemsByLineIndex));
            java.util.List<? extends CodeLensItem> itemsByLineItems = itemsByLine.valueAt(itemsByLineIndex);
            int itemsByLineItemsCount = itemsByLineItems == null ? 0 : itemsByLineItems.size();
            data.putInt(itemsByLineItemsCount);
            for (int itemsByLineItemsIndex = 0; itemsByLineItemsIndex < itemsByLineItemsCount; itemsByLineItemsIndex++) {
                CodeLensItem itemsByLineItem = itemsByLineItems.get(itemsByLineItemsIndex);
                data.putInt(itemsByLineItem.column);
                data.putInt(itemsByLineItem.commandId);
                writeUtf8Bytes(data, itemsByLineTextUtf8[itemsByLineItemIndex]);
                itemsByLineItemIndex++;
            }
        }
        data.flip();
        return data;
    }

    private static void writeSetBatchLineDiagnosticsPayloadWire(ByteBuffer data, android.util.SparseArray<? extends java.util.List<? extends Diagnostic>> diagnosticsByLine) {
        int count = diagnosticsByLine == null ? 0 : diagnosticsByLine.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            data.putInt(diagnosticsByLine.keyAt(i));
            writeDiagnosticList(data, diagnosticsByLine.valueAt(i));
        }
    }

    private static int sizeOfSetBatchLineDiagnosticsPayloadWire(android.util.SparseArray<? extends java.util.List<? extends Diagnostic>> diagnosticsByLine) {
        int size = 0;
        size += 4;
        if (diagnosticsByLine != null) {
            for (int i = 0; i < diagnosticsByLine.size(); i++) {
                size += 4;
                size += sizeOfDiagnosticList(diagnosticsByLine.valueAt(i));
            }
        }
        return size;
    }

    public static ByteBuffer encodeSetBatchLineDiagnosticsPayload(android.util.SparseArray<? extends java.util.List<? extends Diagnostic>> diagnosticsByLine) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetBatchLineDiagnosticsPayloadWire(data, diagnosticsByLine);
        data.flip();
        return data;
    }

    private static void writeSetBatchLineGutterIconsPayloadWire(ByteBuffer data, android.util.SparseArray<? extends java.util.List<? extends GutterIcon>> iconsByLine) {
        int count = iconsByLine == null ? 0 : iconsByLine.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            data.putInt(iconsByLine.keyAt(i));
            writeGutterIconList(data, iconsByLine.valueAt(i));
        }
    }

    private static int sizeOfSetBatchLineGutterIconsPayloadWire(android.util.SparseArray<? extends java.util.List<? extends GutterIcon>> iconsByLine) {
        int size = 0;
        size += 4;
        if (iconsByLine != null) {
            for (int i = 0; i < iconsByLine.size(); i++) {
                size += 4;
                size += sizeOfGutterIconList(iconsByLine.valueAt(i));
            }
        }
        return size;
    }

    public static ByteBuffer encodeSetBatchLineGutterIconsPayload(android.util.SparseArray<? extends java.util.List<? extends GutterIcon>> iconsByLine) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetBatchLineGutterIconsPayloadWire(data, iconsByLine);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetBatchLineInlayHintsPayload(android.util.SparseArray<? extends java.util.List<? extends InlayHint>> hintsByLine) {
        int size = 0;
        int hintsByLineCount = hintsByLine == null ? 0 : hintsByLine.size();
        int hintsByLineItemCount = 0;
        size += 4;
        for (int hintsByLineIndex = 0; hintsByLineIndex < hintsByLineCount; hintsByLineIndex++) {
            size += 4;
            java.util.List<? extends InlayHint> hintsByLineHints = hintsByLine.valueAt(hintsByLineIndex);
            int hintsByLineHintsCount = hintsByLineHints == null ? 0 : hintsByLineHints.size();
            hintsByLineItemCount += hintsByLineHintsCount;
            size += 4;
        }
        byte[][] hintsByLineTextUtf8 = new byte[hintsByLineItemCount][];
        int hintsByLineItemIndex = 0;
        for (int hintsByLineIndex = 0; hintsByLineIndex < hintsByLineCount; hintsByLineIndex++) {
            java.util.List<? extends InlayHint> hintsByLineHints = hintsByLine.valueAt(hintsByLineIndex);
            int hintsByLineHintsCount = hintsByLineHints == null ? 0 : hintsByLineHints.size();
            for (int hintsByLineHintsIndex = 0; hintsByLineHintsIndex < hintsByLineHintsCount; hintsByLineHintsIndex++) {
                InlayHint hintsByLineItem = hintsByLineHints.get(hintsByLineHintsIndex);
                size += 4;
                size += 4;
                size += 4;
                byte[] hintsByLineTextBytes = utf8Bytes(hintsByLineItem.text);
                hintsByLineTextUtf8[hintsByLineItemIndex] = hintsByLineTextBytes;
                size += 4 + hintsByLineTextBytes.length;
                hintsByLineItemIndex++;
            }
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(hintsByLineCount);
        hintsByLineItemIndex = 0;
        for (int hintsByLineIndex = 0; hintsByLineIndex < hintsByLineCount; hintsByLineIndex++) {
            data.putInt(hintsByLine.keyAt(hintsByLineIndex));
            java.util.List<? extends InlayHint> hintsByLineHints = hintsByLine.valueAt(hintsByLineIndex);
            int hintsByLineHintsCount = hintsByLineHints == null ? 0 : hintsByLineHints.size();
            data.putInt(hintsByLineHintsCount);
            for (int hintsByLineHintsIndex = 0; hintsByLineHintsIndex < hintsByLineHintsCount; hintsByLineHintsIndex++) {
                InlayHint hintsByLineItem = hintsByLineHints.get(hintsByLineHintsIndex);
                data.putInt(hintsByLineItem.type.value);
                data.putInt(hintsByLineItem.column);
                data.putInt(hintsByLineItem.intValue);
                writeUtf8Bytes(data, hintsByLineTextUtf8[hintsByLineItemIndex]);
                hintsByLineItemIndex++;
            }
        }
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetBatchLineLinksPayload(android.util.SparseArray<? extends java.util.List<? extends LinkSpan>> linksByLine) {
        int size = 0;
        int linksByLineCount = linksByLine == null ? 0 : linksByLine.size();
        int linksByLineItemCount = 0;
        size += 4;
        for (int linksByLineIndex = 0; linksByLineIndex < linksByLineCount; linksByLineIndex++) {
            size += 4;
            java.util.List<? extends LinkSpan> linksByLineLinks = linksByLine.valueAt(linksByLineIndex);
            int linksByLineLinksCount = linksByLineLinks == null ? 0 : linksByLineLinks.size();
            linksByLineItemCount += linksByLineLinksCount;
            size += 4;
        }
        byte[][] linksByLineTargetUtf8 = new byte[linksByLineItemCount][];
        int linksByLineItemIndex = 0;
        for (int linksByLineIndex = 0; linksByLineIndex < linksByLineCount; linksByLineIndex++) {
            java.util.List<? extends LinkSpan> linksByLineLinks = linksByLine.valueAt(linksByLineIndex);
            int linksByLineLinksCount = linksByLineLinks == null ? 0 : linksByLineLinks.size();
            for (int linksByLineLinksIndex = 0; linksByLineLinksIndex < linksByLineLinksCount; linksByLineLinksIndex++) {
                LinkSpan linksByLineItem = linksByLineLinks.get(linksByLineLinksIndex);
                size += 4;
                size += 4;
                byte[] linksByLineTargetBytes = utf8Bytes(linksByLineItem.target);
                linksByLineTargetUtf8[linksByLineItemIndex] = linksByLineTargetBytes;
                size += 4 + linksByLineTargetBytes.length;
                linksByLineItemIndex++;
            }
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(linksByLineCount);
        linksByLineItemIndex = 0;
        for (int linksByLineIndex = 0; linksByLineIndex < linksByLineCount; linksByLineIndex++) {
            data.putInt(linksByLine.keyAt(linksByLineIndex));
            java.util.List<? extends LinkSpan> linksByLineLinks = linksByLine.valueAt(linksByLineIndex);
            int linksByLineLinksCount = linksByLineLinks == null ? 0 : linksByLineLinks.size();
            data.putInt(linksByLineLinksCount);
            for (int linksByLineLinksIndex = 0; linksByLineLinksIndex < linksByLineLinksCount; linksByLineLinksIndex++) {
                LinkSpan linksByLineItem = linksByLineLinks.get(linksByLineLinksIndex);
                data.putInt(linksByLineItem.column);
                data.putInt(linksByLineItem.length);
                writeUtf8Bytes(data, linksByLineTargetUtf8[linksByLineItemIndex]);
                linksByLineItemIndex++;
            }
        }
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetBatchLinePhantomTextsPayload(android.util.SparseArray<? extends java.util.List<? extends PhantomText>> phantomsByLine) {
        int size = 0;
        int phantomsByLineCount = phantomsByLine == null ? 0 : phantomsByLine.size();
        int phantomsByLineItemCount = 0;
        size += 4;
        for (int phantomsByLineIndex = 0; phantomsByLineIndex < phantomsByLineCount; phantomsByLineIndex++) {
            size += 4;
            java.util.List<? extends PhantomText> phantomsByLinePhantoms = phantomsByLine.valueAt(phantomsByLineIndex);
            int phantomsByLinePhantomsCount = phantomsByLinePhantoms == null ? 0 : phantomsByLinePhantoms.size();
            phantomsByLineItemCount += phantomsByLinePhantomsCount;
            size += 4;
        }
        byte[][] phantomsByLineTextUtf8 = new byte[phantomsByLineItemCount][];
        int phantomsByLineItemIndex = 0;
        for (int phantomsByLineIndex = 0; phantomsByLineIndex < phantomsByLineCount; phantomsByLineIndex++) {
            java.util.List<? extends PhantomText> phantomsByLinePhantoms = phantomsByLine.valueAt(phantomsByLineIndex);
            int phantomsByLinePhantomsCount = phantomsByLinePhantoms == null ? 0 : phantomsByLinePhantoms.size();
            for (int phantomsByLinePhantomsIndex = 0; phantomsByLinePhantomsIndex < phantomsByLinePhantomsCount; phantomsByLinePhantomsIndex++) {
                PhantomText phantomsByLineItem = phantomsByLinePhantoms.get(phantomsByLinePhantomsIndex);
                size += 4;
                byte[] phantomsByLineTextBytes = utf8Bytes(phantomsByLineItem.text);
                phantomsByLineTextUtf8[phantomsByLineItemIndex] = phantomsByLineTextBytes;
                size += 4 + phantomsByLineTextBytes.length;
                phantomsByLineItemIndex++;
            }
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(phantomsByLineCount);
        phantomsByLineItemIndex = 0;
        for (int phantomsByLineIndex = 0; phantomsByLineIndex < phantomsByLineCount; phantomsByLineIndex++) {
            data.putInt(phantomsByLine.keyAt(phantomsByLineIndex));
            java.util.List<? extends PhantomText> phantomsByLinePhantoms = phantomsByLine.valueAt(phantomsByLineIndex);
            int phantomsByLinePhantomsCount = phantomsByLinePhantoms == null ? 0 : phantomsByLinePhantoms.size();
            data.putInt(phantomsByLinePhantomsCount);
            for (int phantomsByLinePhantomsIndex = 0; phantomsByLinePhantomsIndex < phantomsByLinePhantomsCount; phantomsByLinePhantomsIndex++) {
                PhantomText phantomsByLineItem = phantomsByLinePhantoms.get(phantomsByLinePhantomsIndex);
                data.putInt(phantomsByLineItem.column);
                writeUtf8Bytes(data, phantomsByLineTextUtf8[phantomsByLineItemIndex]);
                phantomsByLineItemIndex++;
            }
        }
        data.flip();
        return data;
    }

    private static void writeSetBatchLineSpansPayloadWire(ByteBuffer data, SpanLayer layer, android.util.SparseArray<? extends java.util.List<? extends StyleSpan>> spansByLine) {
        data.putInt(layer.value);
        int count = spansByLine == null ? 0 : spansByLine.size();
        data.putInt(count);
        for (int i = 0; i < count; i++) {
            data.putInt(spansByLine.keyAt(i));
            writeStyleSpanList(data, spansByLine.valueAt(i));
        }
    }

    private static int sizeOfSetBatchLineSpansPayloadWire(SpanLayer layer, android.util.SparseArray<? extends java.util.List<? extends StyleSpan>> spansByLine) {
        int size = 0;
        size += 4;
        size += 4;
        if (spansByLine != null) {
            for (int i = 0; i < spansByLine.size(); i++) {
                size += 4;
                size += sizeOfStyleSpanList(spansByLine.valueAt(i));
            }
        }
        return size;
    }

    public static ByteBuffer encodeSetBatchLineSpansPayload(SpanLayer layer, android.util.SparseArray<? extends java.util.List<? extends StyleSpan>> spansByLine) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetBatchLineSpansPayloadWire(layer, spansByLine)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetBatchLineSpansPayloadWire(data, layer, spansByLine);
        data.flip();
        return data;
    }

    private static void writeSetBracketGuidesPayloadWire(ByteBuffer data, java.util.List<? extends BracketGuide> guides) {
        writeBracketGuideList(data, guides);
    }

    private static int sizeOfSetBracketGuidesPayloadWire(java.util.List<? extends BracketGuide> guides) {
        int size = 0;
        size += sizeOfBracketGuideList(guides);
        return size;
    }

    public static ByteBuffer encodeSetBracketGuidesPayload(java.util.List<? extends BracketGuide> guides) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetBracketGuidesPayloadWire(guides)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetBracketGuidesPayloadWire(data, guides);
        data.flip();
        return data;
    }

    private static void writeSetFlowGuidesPayloadWire(ByteBuffer data, java.util.List<? extends FlowGuide> guides) {
        writeFlowGuideList(data, guides);
    }

    private static int sizeOfSetFlowGuidesPayloadWire(java.util.List<? extends FlowGuide> guides) {
        int size = 0;
        size += sizeOfFlowGuideList(guides);
        return size;
    }

    public static ByteBuffer encodeSetFlowGuidesPayload(java.util.List<? extends FlowGuide> guides) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetFlowGuidesPayloadWire(guides)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetFlowGuidesPayloadWire(data, guides);
        data.flip();
        return data;
    }

    private static void writeSetFoldRegionsPayloadWire(ByteBuffer data, java.util.List<? extends FoldRegion> regions) {
        writeFoldRegionList(data, regions);
    }

    private static int sizeOfSetFoldRegionsPayloadWire(java.util.List<? extends FoldRegion> regions) {
        int size = 0;
        size += sizeOfFoldRegionList(regions);
        return size;
    }

    public static ByteBuffer encodeSetFoldRegionsPayload(java.util.List<? extends FoldRegion> regions) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetFoldRegionsPayloadWire(regions)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetFoldRegionsPayloadWire(data, regions);
        data.flip();
        return data;
    }

    private static void writeSetIndentGuidesPayloadWire(ByteBuffer data, java.util.List<? extends IndentGuide> guides) {
        writeIndentGuideList(data, guides);
    }

    private static int sizeOfSetIndentGuidesPayloadWire(java.util.List<? extends IndentGuide> guides) {
        int size = 0;
        size += sizeOfIndentGuideList(guides);
        return size;
    }

    public static ByteBuffer encodeSetIndentGuidesPayload(java.util.List<? extends IndentGuide> guides) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetIndentGuidesPayloadWire(guides)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetIndentGuidesPayloadWire(data, guides);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetLineCodeLensPayload(int line, java.util.List<? extends CodeLensItem> items) {
        int size = 0;
        size += 4;
        int itemsCount = items == null ? 0 : items.size();
        byte[][] itemsTextUtf8 = new byte[itemsCount][];
        size += 4;
        for (int itemsIndex = 0; itemsIndex < itemsCount; itemsIndex++) {
            CodeLensItem itemsItem = items.get(itemsIndex);
            size += 4;
            size += 4;
            byte[] itemsTextBytes = utf8Bytes(itemsItem.text);
            itemsTextUtf8[itemsIndex] = itemsTextBytes;
            size += 4 + itemsTextBytes.length;
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(line);
        data.putInt(itemsCount);
        for (int itemsIndex = 0; itemsIndex < itemsCount; itemsIndex++) {
            CodeLensItem itemsItem = items.get(itemsIndex);
            data.putInt(itemsItem.column);
            data.putInt(itemsItem.commandId);
            writeUtf8Bytes(data, itemsTextUtf8[itemsIndex]);
        }
        data.flip();
        return data;
    }

    private static void writeSetLineDiagnosticsPayloadWire(ByteBuffer data, int line, java.util.List<? extends Diagnostic> diagnostics) {
        data.putInt(line);
        writeDiagnosticList(data, diagnostics);
    }

    private static int sizeOfSetLineDiagnosticsPayloadWire(int line, java.util.List<? extends Diagnostic> diagnostics) {
        int size = 0;
        size += 4;
        size += sizeOfDiagnosticList(diagnostics);
        return size;
    }

    public static ByteBuffer encodeSetLineDiagnosticsPayload(int line, java.util.List<? extends Diagnostic> diagnostics) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetLineDiagnosticsPayloadWire(line, diagnostics)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetLineDiagnosticsPayloadWire(data, line, diagnostics);
        data.flip();
        return data;
    }

    private static void writeSetLineGutterIconsPayloadWire(ByteBuffer data, int line, java.util.List<? extends GutterIcon> icons) {
        data.putInt(line);
        writeGutterIconList(data, icons);
    }

    private static int sizeOfSetLineGutterIconsPayloadWire(int line, java.util.List<? extends GutterIcon> icons) {
        int size = 0;
        size += 4;
        size += sizeOfGutterIconList(icons);
        return size;
    }

    public static ByteBuffer encodeSetLineGutterIconsPayload(int line, java.util.List<? extends GutterIcon> icons) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetLineGutterIconsPayloadWire(line, icons)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetLineGutterIconsPayloadWire(data, line, icons);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetLineInlayHintsPayload(int line, java.util.List<? extends InlayHint> hints) {
        int size = 0;
        size += 4;
        int hintsCount = hints == null ? 0 : hints.size();
        byte[][] hintsTextUtf8 = new byte[hintsCount][];
        size += 4;
        for (int hintsIndex = 0; hintsIndex < hintsCount; hintsIndex++) {
            InlayHint hintsItem = hints.get(hintsIndex);
            size += 4;
            size += 4;
            size += 4;
            byte[] hintsTextBytes = utf8Bytes(hintsItem.text);
            hintsTextUtf8[hintsIndex] = hintsTextBytes;
            size += 4 + hintsTextBytes.length;
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(line);
        data.putInt(hintsCount);
        for (int hintsIndex = 0; hintsIndex < hintsCount; hintsIndex++) {
            InlayHint hintsItem = hints.get(hintsIndex);
            data.putInt(hintsItem.type.value);
            data.putInt(hintsItem.column);
            data.putInt(hintsItem.intValue);
            writeUtf8Bytes(data, hintsTextUtf8[hintsIndex]);
        }
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetLineLinksPayload(int line, java.util.List<? extends LinkSpan> links) {
        int size = 0;
        size += 4;
        int linksCount = links == null ? 0 : links.size();
        byte[][] linksTargetUtf8 = new byte[linksCount][];
        size += 4;
        for (int linksIndex = 0; linksIndex < linksCount; linksIndex++) {
            LinkSpan linksItem = links.get(linksIndex);
            size += 4;
            size += 4;
            byte[] linksTargetBytes = utf8Bytes(linksItem.target);
            linksTargetUtf8[linksIndex] = linksTargetBytes;
            size += 4 + linksTargetBytes.length;
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(line);
        data.putInt(linksCount);
        for (int linksIndex = 0; linksIndex < linksCount; linksIndex++) {
            LinkSpan linksItem = links.get(linksIndex);
            data.putInt(linksItem.column);
            data.putInt(linksItem.length);
            writeUtf8Bytes(data, linksTargetUtf8[linksIndex]);
        }
        data.flip();
        return data;
    }

    public static ByteBuffer encodeSetLinePhantomTextsPayload(int line, java.util.List<? extends PhantomText> phantoms) {
        int size = 0;
        size += 4;
        int phantomsCount = phantoms == null ? 0 : phantoms.size();
        byte[][] phantomsTextUtf8 = new byte[phantomsCount][];
        size += 4;
        for (int phantomsIndex = 0; phantomsIndex < phantomsCount; phantomsIndex++) {
            PhantomText phantomsItem = phantoms.get(phantomsIndex);
            size += 4;
            byte[] phantomsTextBytes = utf8Bytes(phantomsItem.text);
            phantomsTextUtf8[phantomsIndex] = phantomsTextBytes;
            size += 4 + phantomsTextBytes.length;
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(line);
        data.putInt(phantomsCount);
        for (int phantomsIndex = 0; phantomsIndex < phantomsCount; phantomsIndex++) {
            PhantomText phantomsItem = phantoms.get(phantomsIndex);
            data.putInt(phantomsItem.column);
            writeUtf8Bytes(data, phantomsTextUtf8[phantomsIndex]);
        }
        data.flip();
        return data;
    }

    private static void writeSetLineSpansPayloadWire(ByteBuffer data, int line, SpanLayer layer, java.util.List<? extends StyleSpan> spans) {
        data.putInt(line);
        data.putInt(layer.value);
        writeStyleSpanList(data, spans);
    }

    private static int sizeOfSetLineSpansPayloadWire(int line, SpanLayer layer, java.util.List<? extends StyleSpan> spans) {
        int size = 0;
        size += 4;
        size += 4;
        size += sizeOfStyleSpanList(spans);
        return size;
    }

    public static ByteBuffer encodeSetLineSpansPayload(int line, SpanLayer layer, java.util.List<? extends StyleSpan> spans) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetLineSpansPayloadWire(line, layer, spans)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetLineSpansPayloadWire(data, line, layer, spans);
        data.flip();
        return data;
    }

    private static void writeSetSeparatorGuidesPayloadWire(ByteBuffer data, java.util.List<? extends SeparatorGuide> guides) {
        writeSeparatorGuideList(data, guides);
    }

    private static int sizeOfSetSeparatorGuidesPayloadWire(java.util.List<? extends SeparatorGuide> guides) {
        int size = 0;
        size += sizeOfSeparatorGuideList(guides);
        return size;
    }

    public static ByteBuffer encodeSetSeparatorGuidesPayload(java.util.List<? extends SeparatorGuide> guides) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetSeparatorGuidesPayloadWire(guides)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetSeparatorGuidesPayloadWire(data, guides);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeEditorOptions(EditorOptions value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfEditorOptions(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeEditorOptionsFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeHandleConfig(HandleConfig value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfHandleConfig(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeHandleConfigFields(data, value);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeScrollbarConfig(ScrollbarConfig value) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfScrollbarConfig(value)).order(ByteOrder.LITTLE_ENDIAN);
        writeScrollbarConfigFields(data, value);
        data.flip();
        return data;
    }

    private static void writeSetKeyMapPayloadWire(ByteBuffer data, java.util.List<? extends KeyBinding> bindings) {
        writeKeyBindingList(data, bindings);
    }

    private static int sizeOfSetKeyMapPayloadWire(java.util.List<? extends KeyBinding> bindings) {
        int size = 0;
        size += sizeOfKeyBindingList(bindings);
        return size;
    }

    public static ByteBuffer encodeSetKeyMapPayload(java.util.List<? extends KeyBinding> bindings) {
        ByteBuffer data = ByteBuffer.allocateDirect(sizeOfSetKeyMapPayloadWire(bindings)).order(ByteOrder.LITTLE_ENDIAN);
        writeSetKeyMapPayloadWire(data, bindings);
        data.flip();
        return data;
    }

    public static ByteBuffer encodeLinkedEditingModel(LinkedEditingModel value) {
        int size = 0;
        int groupsCount = value.groups == null ? 0 : value.groups.size();
        byte[][] groupsDefaultTextUtf8 = new byte[groupsCount][];
        size += 4;
        for (int groupsIndex = 0; groupsIndex < groupsCount; groupsIndex++) {
            TabStopGroup groupsItem = value.groups.get(groupsIndex);
            size += 4;
            size += sizeOfTextRangeList(groupsItem.ranges);
            byte[] groupsDefaultTextBytes = utf8Bytes(groupsItem.defaultText);
            groupsDefaultTextUtf8[groupsIndex] = groupsDefaultTextBytes;
            size += 4 + groupsDefaultTextBytes.length;
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(groupsCount);
        for (int groupsIndex = 0; groupsIndex < groupsCount; groupsIndex++) {
            TabStopGroup groupsItem = value.groups.get(groupsIndex);
            data.putInt(groupsItem.index);
            writeTextRangeList(data, groupsItem.ranges);
            writeUtf8Bytes(data, groupsDefaultTextUtf8[groupsIndex]);
        }
        data.flip();
        return data;
    }

    public static ByteBuffer encodeStartLinkedEditingPayload(LinkedEditingModel model) {
        int size = 0;
        int modelGroupsCount = model.groups == null ? 0 : model.groups.size();
        byte[][] modelGroupsDefaultTextUtf8 = new byte[modelGroupsCount][];
        size += 4;
        for (int modelGroupsIndex = 0; modelGroupsIndex < modelGroupsCount; modelGroupsIndex++) {
            TabStopGroup modelGroupsItem = model.groups.get(modelGroupsIndex);
            size += 4;
            size += sizeOfTextRangeList(modelGroupsItem.ranges);
            byte[] modelGroupsDefaultTextBytes = utf8Bytes(modelGroupsItem.defaultText);
            modelGroupsDefaultTextUtf8[modelGroupsIndex] = modelGroupsDefaultTextBytes;
            size += 4 + modelGroupsDefaultTextBytes.length;
        }
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(modelGroupsCount);
        for (int modelGroupsIndex = 0; modelGroupsIndex < modelGroupsCount; modelGroupsIndex++) {
            TabStopGroup modelGroupsItem = model.groups.get(modelGroupsIndex);
            data.putInt(modelGroupsItem.index);
            writeTextRangeList(data, modelGroupsItem.ranges);
            writeUtf8Bytes(data, modelGroupsDefaultTextUtf8[modelGroupsIndex]);
        }
        data.flip();
        return data;
    }

    public static ByteBuffer encodeTabStopGroup(TabStopGroup value) {
        int size = 0;
        size += 4;
        size += sizeOfTextRangeList(value.ranges);
        byte[] defaultTextUtf8 = utf8Bytes(value.defaultText);
        size += 4 + defaultTextUtf8.length;
        ByteBuffer data = ByteBuffer.allocateDirect(size).order(ByteOrder.LITTLE_ENDIAN);
        data.putInt(value.index);
        writeTextRangeList(data, value.ranges);
        writeUtf8Bytes(data, defaultTextUtf8);
        data.flip();
        return data;
    }
}
