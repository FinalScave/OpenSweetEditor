package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.action.EditorActionSource;
import com.qiplat.sweeteditor.core.action.ScrollBehavior;
import com.qiplat.sweeteditor.core.action.TextChangeKind;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.CodeLensItem;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.DiagnosticSeverity;
import com.qiplat.sweeteditor.core.adornment.DocumentHighlight;
import com.qiplat.sweeteditor.core.adornment.DocumentHighlightKind;
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
import com.qiplat.sweeteditor.core.config.EditorRangeEffectStyles;
import com.qiplat.sweeteditor.core.config.EditorRenderColors;
import com.qiplat.sweeteditor.core.config.FoldArrowMode;
import com.qiplat.sweeteditor.core.config.HandleConfig;
import com.qiplat.sweeteditor.core.config.HandleHitArea;
import com.qiplat.sweeteditor.core.config.RangeEffectStyle;
import com.qiplat.sweeteditor.core.config.RangeEffectUnderlineStyle;
import com.qiplat.sweeteditor.core.config.ScrollbarConfig;
import com.qiplat.sweeteditor.core.config.ScrollbarMode;
import com.qiplat.sweeteditor.core.config.ScrollbarTrackTapMode;
import com.qiplat.sweeteditor.core.config.WhitespaceRenderMode;
import com.qiplat.sweeteditor.core.config.WrapMode;
import com.qiplat.sweeteditor.core.foundation.IntRange;
import com.qiplat.sweeteditor.core.foundation.PointF;
import com.qiplat.sweeteditor.core.foundation.Rect;
import com.qiplat.sweeteditor.core.foundation.Size;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextEdit;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.ime.ImeCommandKind;
import com.qiplat.sweeteditor.core.ime.ImeCommandMessage;
import com.qiplat.sweeteditor.core.ime.ImeContextPolicy;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeInputContextKind;
import com.qiplat.sweeteditor.core.ime.ImeMarkedRange;
import com.qiplat.sweeteditor.core.ime.ImeMarkedRangeRole;
import com.qiplat.sweeteditor.core.ime.ImeOffsetRange;
import com.qiplat.sweeteditor.core.ime.ImePreeditStorage;
import com.qiplat.sweeteditor.core.ime.ImeScriptClass;
import com.qiplat.sweeteditor.core.ime.ImeSyncSnapshot;
import com.qiplat.sweeteditor.core.ime.ImeTextPatch;
import com.qiplat.sweeteditor.core.ime.ImeTextUnit;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateKind;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateMessage;
import com.qiplat.sweeteditor.core.ime.ImeTextUpdateScope;
import com.qiplat.sweeteditor.core.interaction.EventType;
import com.qiplat.sweeteditor.core.interaction.GestureEvent;
import com.qiplat.sweeteditor.core.interaction.GestureType;
import com.qiplat.sweeteditor.core.interaction.HitTarget;
import com.qiplat.sweeteditor.core.interaction.HitTargetType;
import com.qiplat.sweeteditor.core.keymap.EditorBuiltinCommand;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyChord;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.keymap.KeyModifier;
import com.qiplat.sweeteditor.core.search.SearchOptions;
import com.qiplat.sweeteditor.core.search.SearchRequest;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.search.SearchStatus;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.snippet.TabStopGroup;
import com.qiplat.sweeteditor.core.visual.Cursor;
import com.qiplat.sweeteditor.core.visual.CursorRect;
import com.qiplat.sweeteditor.core.visual.EditorRenderModel;
import com.qiplat.sweeteditor.core.visual.FoldMarkerRenderItem;
import com.qiplat.sweeteditor.core.visual.FoldState;
import com.qiplat.sweeteditor.core.visual.GuideDirection;
import com.qiplat.sweeteditor.core.visual.GuideSegment;
import com.qiplat.sweeteditor.core.visual.GuideStyle;
import com.qiplat.sweeteditor.core.visual.GuideType;
import com.qiplat.sweeteditor.core.visual.GutterIconRenderItem;
import com.qiplat.sweeteditor.core.visual.LayoutMetrics;
import com.qiplat.sweeteditor.core.visual.PointerCursorType;
import com.qiplat.sweeteditor.core.visual.RangeEffectKind;
import com.qiplat.sweeteditor.core.visual.RangeEffectRenderItem;
import com.qiplat.sweeteditor.core.visual.ScrollMetrics;
import com.qiplat.sweeteditor.core.visual.ScrollbarModel;
import com.qiplat.sweeteditor.core.visual.SelectionHandle;
import com.qiplat.sweeteditor.core.visual.VisualLine;
import com.qiplat.sweeteditor.core.visual.VisualLineKind;
import com.qiplat.sweeteditor.core.visual.VisualRun;
import com.qiplat.sweeteditor.core.visual.VisualRunType;
import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;

public final class CoreProtocol {
    private CoreProtocol() {
    }

    private static final ValueLayout.OfByte I8 = ValueLayout.JAVA_BYTE;
    private static final ValueLayout.OfShort I16 = ValueLayout.JAVA_SHORT_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);
    private static final ValueLayout.OfInt I32 = ValueLayout.JAVA_INT_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);
    private static final ValueLayout.OfLong I64 = ValueLayout.JAVA_LONG_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);
    private static final ValueLayout.OfFloat F32 = ValueLayout.JAVA_FLOAT_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);
    private static final ValueLayout.OfDouble F64 = ValueLayout.JAVA_DOUBLE_UNALIGNED.withOrder(ByteOrder.LITTLE_ENDIAN);

    private static final byte[] EMPTY_BYTES = new byte[0];

    private static byte[] utf8Bytes(String value) {
        return value == null || value.isEmpty() ? EMPTY_BYTES : value.getBytes(StandardCharsets.UTF_8);
    }

    private static final class BinaryReader {
        private final MemorySegment data;
        private long offset;

        BinaryReader(MemorySegment data, long size) {
            this.data = data.asSlice(0, size);
        }

        int readUint8() {
            int value = data.get(I8, offset) & 0xFF;
            offset += 1;
            return value;
        }

        int readUint16() {
            int value = data.get(I16, offset) & 0xFFFF;
            offset += 2;
            return value;
        }

        int readInt32() {
            int value = data.get(I32, offset);
            offset += 4;
            return value;
        }

        long readInt64() {
            long value = data.get(I64, offset);
            offset += 8;
            return value;
        }

        float readFloat32() {
            float value = data.get(F32, offset);
            offset += 4;
            return value;
        }

        double readFloat64() {
            double value = data.get(F64, offset);
            offset += 8;
            return value;
        }

        String readUtf8String() {
            int length = readInt32();
            if (length < 0 || length > remaining()) {
                throw new IllegalArgumentException("Invalid protocol length.");
            }
            if (length == 0) return "";
            byte[] bytes = data.asSlice(offset, length).toArray(ValueLayout.JAVA_BYTE);
            offset += length;
            return new String(bytes, StandardCharsets.UTF_8);
        }

        long remaining() {
            return data.byteSize() - offset;
        }
    }

    private static final class BinaryWriter {
        private final MemorySegment data;
        private long offset;

        BinaryWriter(Arena arena, int size) {
            this.data = arena.allocate(size);
        }

        MemorySegment segment() {
            return data;
        }

        void writeUint8(int value) {
            data.set(I8, offset, (byte) value);
            offset += 1;
        }

        void writeUint16(int value) {
            data.set(I16, offset, (short) value);
            offset += 2;
        }

        void writeInt32(int value) {
            data.set(I32, offset, value);
            offset += 4;
        }

        void writeInt64(long value) {
            data.set(I64, offset, value);
            offset += 8;
        }

        void writeFloat32(float value) {
            data.set(F32, offset, value);
            offset += 4;
        }

        void writeFloat64(double value) {
            data.set(F64, offset, value);
            offset += 8;
        }

        void writeUtf8String(String value) {
            writeUtf8Bytes(utf8Bytes(value));
        }

        void writeUtf8Bytes(byte[] bytes) {
            writeInt32(bytes.length);
            MemorySegment.copy(MemorySegment.ofArray(bytes), 0, data, offset, bytes.length);
            offset += bytes.length;
        }
    }

    private static int sizeOfUtf8String(String value) {
        return 4 + utf8Bytes(value).length;
    }

    public static MemorySegment encodeUtf8String(Arena arena, String value) {
        byte[] bytes = utf8Bytes(value);
        BinaryWriter writer = new BinaryWriter(arena, 4 + bytes.length);
        writer.writeUtf8Bytes(bytes);
        return writer.segment();
    }

    private static void writeBracketGuideList(BinaryWriter writer, java.util.List<? extends BracketGuide> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeBracketGuide(writer, values.get(i));
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

    private static void writeCodeLensItemList(BinaryWriter writer, java.util.List<? extends CodeLensItem> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeCodeLensItem(writer, values.get(i));
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

    private static void writeDiagnosticList(BinaryWriter writer, java.util.List<? extends Diagnostic> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeDiagnostic(writer, values.get(i));
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

    private static void writeDocumentHighlightList(BinaryWriter writer, java.util.List<? extends DocumentHighlight> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeDocumentHighlight(writer, values.get(i));
        }
    }

    private static int sizeOfDocumentHighlightList(java.util.List<? extends DocumentHighlight> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfDocumentHighlight(values.get(i));
            }
        }
        return size;
    }

    private static void writeFlowGuideList(BinaryWriter writer, java.util.List<? extends FlowGuide> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeFlowGuide(writer, values.get(i));
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

    private static ArrayList<FoldMarkerRenderItem> readFoldMarkerRenderItemList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<FoldMarkerRenderItem> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readFoldMarkerRenderItem(reader));
        }
        return values;
    }

    private static void writeFoldRegionList(BinaryWriter writer, java.util.List<? extends FoldRegion> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeFoldRegion(writer, values.get(i));
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

    private static ArrayList<GuideSegment> readGuideSegmentList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<GuideSegment> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readGuideSegment(reader));
        }
        return values;
    }

    private static void writeGutterIconList(BinaryWriter writer, java.util.List<? extends GutterIcon> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeGutterIcon(writer, values.get(i));
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

    private static ArrayList<GutterIconRenderItem> readGutterIconRenderItemList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<GutterIconRenderItem> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readGutterIconRenderItem(reader));
        }
        return values;
    }

    private static void writeIndentGuideList(BinaryWriter writer, java.util.List<? extends IndentGuide> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeIndentGuide(writer, values.get(i));
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

    private static void writeInlayHintList(BinaryWriter writer, java.util.List<? extends InlayHint> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeInlayHint(writer, values.get(i));
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

    private static ArrayList<KeyBinding> readKeyBindingList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<KeyBinding> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readKeyBinding(reader));
        }
        return values;
    }

    private static void writeKeyBindingList(BinaryWriter writer, java.util.List<? extends KeyBinding> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeKeyBinding(writer, values.get(i));
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

    private static void writeLinkSpanList(BinaryWriter writer, java.util.List<? extends LinkSpan> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeLinkSpan(writer, values.get(i));
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

    private static void writePhantomTextList(BinaryWriter writer, java.util.List<? extends PhantomText> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writePhantomText(writer, values.get(i));
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

    private static ArrayList<PointF> readPointFList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<PointF> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readPointF(reader));
        }
        return values;
    }

    private static void writePointFList(BinaryWriter writer, java.util.List<? extends PointF> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writePointF(writer, values.get(i));
        }
    }

    private static int sizeOfPointFList(java.util.List<? extends PointF> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfPointF(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<RangeEffectRenderItem> readRangeEffectRenderItemList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<RangeEffectRenderItem> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readRangeEffectRenderItem(reader));
        }
        return values;
    }

    private static void writeSeparatorGuideList(BinaryWriter writer, java.util.List<? extends SeparatorGuide> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeSeparatorGuide(writer, values.get(i));
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

    private static ArrayList<StyleSpan> readStyleSpanList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<StyleSpan> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readStyleSpan(reader));
        }
        return values;
    }

    private static void writeStyleSpanList(BinaryWriter writer, java.util.List<? extends StyleSpan> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeStyleSpan(writer, values.get(i));
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

    private static void writeTabStopGroupList(BinaryWriter writer, java.util.List<? extends TabStopGroup> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeTabStopGroup(writer, values.get(i));
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

    private static ArrayList<TextChange> readTextChangeList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextChange> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextChange(reader));
        }
        return values;
    }

    private static ArrayList<TextEdit> readTextEditList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextEdit> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextEdit(reader));
        }
        return values;
    }

    private static void writeTextEditList(BinaryWriter writer, java.util.List<? extends TextEdit> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeTextEdit(writer, values.get(i));
        }
    }

    private static int sizeOfTextEditList(java.util.List<? extends TextEdit> values) {
        int size = 4;
        if (values != null) {
            for (int i = 0; i < values.size(); i++) {
                size += sizeOfTextEdit(values.get(i));
            }
        }
        return size;
    }

    private static ArrayList<TextPosition> readTextPositionList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextPosition> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextPosition(reader));
        }
        return values;
    }

    private static void writeTextPositionList(BinaryWriter writer, java.util.List<? extends TextPosition> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeTextPosition(writer, values.get(i));
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

    private static ArrayList<TextRange> readTextRangeList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<TextRange> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readTextRange(reader));
        }
        return values;
    }

    private static void writeTextRangeList(BinaryWriter writer, java.util.List<? extends TextRange> values) {
        int count = values == null ? 0 : values.size();
        writer.writeInt32(count);
        for (int i = 0; i < count; i++) {
            writeTextRange(writer, values.get(i));
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

    private static ArrayList<VisualLine> readVisualLineList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<VisualLine> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readVisualLine(reader));
        }
        return values;
    }

    private static ArrayList<VisualRun> readVisualRunList(BinaryReader reader) {
        int count = reader.readInt32();
        if (count < 0 || count > reader.remaining()) {
            throw new IllegalArgumentException("Invalid protocol length.");
        }
        ArrayList<VisualRun> values = new ArrayList<>(count);
        for (int i = 0; i < count; i++) {
            values.add(readVisualRun(reader));
        }
        return values;
    }

    private static EditorActionResult readEditorActionResult(BinaryReader reader) {
        EditorActionResult value = new EditorActionResult();
        value.handled = reader.readInt32() != 0;
        value.needsRedraw = reader.readInt32() != 0;
        value.source = EditorActionSource.fromValue(reader.readInt32());
        value.textChangeKind = TextChangeKind.fromValue(reader.readInt32());
        value.contentChanged = reader.readInt32() != 0;
        value.cursorChanged = reader.readInt32() != 0;
        value.selectionChanged = reader.readInt32() != 0;
        value.scrollChanged = reader.readInt32() != 0;
        value.scaleChanged = reader.readInt32() != 0;
        value.pointerCursorChanged = reader.readInt32() != 0;
        value.compositionChanged = reader.readInt32() != 0;
        value.decorationChanged = reader.readInt32() != 0;
        value.needsImeSync = reader.readInt32() != 0;
        value.needsEdgeScroll = reader.readInt32() != 0;
        value.needsFling = reader.readInt32() != 0;
        value.needsAnimation = reader.readInt32() != 0;
        value.isHandleDrag = reader.readInt32() != 0;
        value.changes = readTextChangeList(reader);
        value.cursorBefore = readTextPosition(reader);
        value.cursorAfter = readTextPosition(reader);
        value.hasSelectionBefore = reader.readInt32() != 0;
        value.hasSelectionAfter = reader.readInt32() != 0;
        value.selectionBefore = readTextRange(reader);
        value.selectionAfter = readTextRange(reader);
        value.scrollXBefore = reader.readFloat32();
        value.scrollYBefore = reader.readFloat32();
        value.scrollXAfter = reader.readFloat32();
        value.scrollYAfter = reader.readFloat32();
        value.scaleBefore = reader.readFloat32();
        value.scaleAfter = reader.readFloat32();
        value.pointerCursorBefore = PointerCursorType.fromValue(reader.readInt32());
        value.pointerCursorAfter = PointerCursorType.fromValue(reader.readInt32());
        value.imeSync = readImeSyncSnapshot(reader);
        value.gestureType = GestureType.fromValue(reader.readInt32());
        value.gestureEventType = EventType.fromValue(reader.readInt32());
        value.tapPoint = readPointF(reader);
        value.hitTarget = readHitTarget(reader);
        value.modifiers = reader.readInt32();
        value.command = reader.readInt32();
        return value;
    }

    public static EditorActionResult decodeEditorActionResult(MemorySegment data, long size) {
        return readEditorActionResult(new BinaryReader(data, size));
    }

    private static void writeBracketGuide(BinaryWriter writer, BracketGuide value) {
        writeTextPosition(writer, value.parent);
        writeTextPosition(writer, value.end);
        writeTextPositionList(writer, value.children);
    }

    public static int sizeOfBracketGuide(BracketGuide value) {
        int size = 0;
        size += sizeOfTextPosition(value.parent);
        size += sizeOfTextPosition(value.end);
        size += sizeOfTextPositionList(value.children);
        return size;
    }

    private static void writeCodeLensItem(BinaryWriter writer, CodeLensItem value) {
        writer.writeInt32(value.column);
        writer.writeInt32(value.commandId);
        writer.writeUtf8String(value.text);
    }

    public static int sizeOfCodeLensItem(CodeLensItem value) {
        int size = 0;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeDiagnostic(BinaryWriter writer, Diagnostic value) {
        writer.writeInt32(value.column);
        writer.writeInt32(value.length);
        writer.writeInt32(value.severity.value);
    }

    public static int sizeOfDiagnostic(Diagnostic value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeDocumentHighlight(BinaryWriter writer, DocumentHighlight value) {
        writer.writeInt32(value.column);
        writer.writeInt32(value.length);
        writer.writeInt32(value.kind.value);
    }

    public static int sizeOfDocumentHighlight(DocumentHighlight value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeFlowGuide(BinaryWriter writer, FlowGuide value) {
        writeTextPosition(writer, value.start);
        writeTextPosition(writer, value.end);
    }

    public static int sizeOfFlowGuide(FlowGuide value) {
        int size = 0;
        size += sizeOfTextPosition(value.start);
        size += sizeOfTextPosition(value.end);
        return size;
    }

    private static void writeFoldRegion(BinaryWriter writer, FoldRegion value) {
        writer.writeInt32(value.startLine);
        writer.writeInt32(value.endLine);
        writer.writeUint8(value.collapsed ? 1 : 0);
    }

    public static int sizeOfFoldRegion(FoldRegion value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 1;
        return size;
    }

    private static void writeGutterIcon(BinaryWriter writer, GutterIcon value) {
        writer.writeInt32(value.iconId);
    }

    public static int sizeOfGutterIcon(GutterIcon value) {
        int size = 0;
        size += 4;
        return size;
    }

    private static void writeIndentGuide(BinaryWriter writer, IndentGuide value) {
        writeTextPosition(writer, value.start);
        writeTextPosition(writer, value.end);
    }

    public static int sizeOfIndentGuide(IndentGuide value) {
        int size = 0;
        size += sizeOfTextPosition(value.start);
        size += sizeOfTextPosition(value.end);
        return size;
    }

    private static void writeInlayHint(BinaryWriter writer, InlayHint value) {
        writer.writeInt32(value.type.value);
        writer.writeInt32(value.column);
        writer.writeInt32(value.intValue);
        writer.writeUtf8String(value.text);
    }

    public static int sizeOfInlayHint(InlayHint value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeLinkSpan(BinaryWriter writer, LinkSpan value) {
        writer.writeInt32(value.column);
        writer.writeInt32(value.length);
        writer.writeUtf8String(value.target);
    }

    public static int sizeOfLinkSpan(LinkSpan value) {
        int size = 0;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.target);
        return size;
    }

    private static void writePhantomText(BinaryWriter writer, PhantomText value) {
        writer.writeInt32(value.column);
        writer.writeUtf8String(value.text);
    }

    public static int sizeOfPhantomText(PhantomText value) {
        int size = 0;
        size += 4;
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeSeparatorGuide(BinaryWriter writer, SeparatorGuide value) {
        writer.writeInt32(value.line);
        writer.writeInt32(value.style.value);
        writer.writeInt32(value.count);
        writer.writeInt32(value.textEndColumn);
    }

    public static int sizeOfSeparatorGuide(SeparatorGuide value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static StyleSpan readStyleSpan(BinaryReader reader) {
        StyleSpan value = new StyleSpan();
        value.column = reader.readInt32();
        value.length = reader.readInt32();
        value.styleId = reader.readInt32();
        return value;
    }

    public static StyleSpan decodeStyleSpan(MemorySegment data, long size) {
        return readStyleSpan(new BinaryReader(data, size));
    }

    private static void writeStyleSpan(BinaryWriter writer, StyleSpan value) {
        writer.writeInt32(value.column);
        writer.writeInt32(value.length);
        writer.writeInt32(value.styleId);
    }

    public static int sizeOfStyleSpan(StyleSpan value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static TextStyle readTextStyle(BinaryReader reader) {
        TextStyle value = new TextStyle();
        value.color = reader.readInt32();
        value.backgroundColor = reader.readInt32();
        value.fontStyle = reader.readInt32();
        return value;
    }

    public static TextStyle decodeTextStyle(MemorySegment data, long size) {
        return readTextStyle(new BinaryReader(data, size));
    }

    private static void writeTextStyle(BinaryWriter writer, TextStyle value) {
        writer.writeInt32(value.color);
        writer.writeInt32(value.backgroundColor);
        writer.writeInt32(value.fontStyle);
    }

    public static int sizeOfTextStyle(TextStyle value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeEditorOptions(BinaryWriter writer, EditorOptions value) {
        writer.writeFloat32(value.touchSlop);
        writer.writeInt64(value.doubleTapTimeout);
        writer.writeInt64(value.longPressMs);
        writer.writeFloat32(value.flingFriction);
        writer.writeFloat32(value.flingMinVelocity);
        writer.writeFloat32(value.flingMaxVelocity);
        writer.writeInt64(value.maxUndoStackSize);
        writer.writeInt64(value.keyChordTimeoutMs);
        writer.writeUint8(value.revealSelectionEndOnSelectAll ? 1 : 0);
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

    private static void writeEditorRangeEffectStyles(BinaryWriter writer, EditorRangeEffectStyles value) {
        writeRangeEffectStyle(writer, value.selection);
        writeRangeEffectStyle(writer, value.searchMatch);
        writeRangeEffectStyle(writer, value.searchCurrent);
        writeRangeEffectStyle(writer, value.documentHighlightText);
        writeRangeEffectStyle(writer, value.documentHighlightRead);
        writeRangeEffectStyle(writer, value.documentHighlightWrite);
        writeRangeEffectStyle(writer, value.linkedEditingActive);
        writeRangeEffectStyle(writer, value.linkedEditingInactive);
        writeRangeEffectStyle(writer, value.imeComposition);
        writeRangeEffectStyle(writer, value.bracketMatch);
        writeRangeEffectStyle(writer, value.diagnosticError);
        writeRangeEffectStyle(writer, value.diagnosticWarning);
        writeRangeEffectStyle(writer, value.diagnosticInfo);
        writeRangeEffectStyle(writer, value.diagnosticHint);
    }

    public static int sizeOfEditorRangeEffectStyles(EditorRangeEffectStyles value) {
        int size = 0;
        size += sizeOfRangeEffectStyle(value.selection);
        size += sizeOfRangeEffectStyle(value.searchMatch);
        size += sizeOfRangeEffectStyle(value.searchCurrent);
        size += sizeOfRangeEffectStyle(value.documentHighlightText);
        size += sizeOfRangeEffectStyle(value.documentHighlightRead);
        size += sizeOfRangeEffectStyle(value.documentHighlightWrite);
        size += sizeOfRangeEffectStyle(value.linkedEditingActive);
        size += sizeOfRangeEffectStyle(value.linkedEditingInactive);
        size += sizeOfRangeEffectStyle(value.imeComposition);
        size += sizeOfRangeEffectStyle(value.bracketMatch);
        size += sizeOfRangeEffectStyle(value.diagnosticError);
        size += sizeOfRangeEffectStyle(value.diagnosticWarning);
        size += sizeOfRangeEffectStyle(value.diagnosticInfo);
        size += sizeOfRangeEffectStyle(value.diagnosticHint);
        return size;
    }

    private static void writeEditorRenderColors(BinaryWriter writer, EditorRenderColors value) {
        writer.writeInt32(value.textForeground);
        writer.writeInt32(value.linkForeground);
        writer.writeInt32(value.activeLinkForeground);
        writer.writeInt32(value.codelensForeground);
        writer.writeInt32(value.activeCodelensForeground);
    }

    public static int sizeOfEditorRenderColors(EditorRenderColors value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeHandleConfig(BinaryWriter writer, HandleConfig value) {
        writeHandleHitArea(writer, value.startHitArea);
        writeHandleHitArea(writer, value.endHitArea);
    }

    public static int sizeOfHandleConfig(HandleConfig value) {
        int size = 0;
        size += sizeOfHandleHitArea(value.startHitArea);
        size += sizeOfHandleHitArea(value.endHitArea);
        return size;
    }

    private static HandleHitArea readHandleHitArea(BinaryReader reader) {
        HandleHitArea value = new HandleHitArea();
        value.left = reader.readFloat32();
        value.top = reader.readFloat32();
        value.right = reader.readFloat32();
        value.bottom = reader.readFloat32();
        return value;
    }

    public static HandleHitArea decodeHandleHitArea(MemorySegment data, long size) {
        return readHandleHitArea(new BinaryReader(data, size));
    }

    private static void writeHandleHitArea(BinaryWriter writer, HandleHitArea value) {
        writer.writeFloat32(value.left);
        writer.writeFloat32(value.top);
        writer.writeFloat32(value.right);
        writer.writeFloat32(value.bottom);
    }

    public static int sizeOfHandleHitArea(HandleHitArea value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static RangeEffectStyle readRangeEffectStyle(BinaryReader reader) {
        RangeEffectStyle value = new RangeEffectStyle();
        value.foregroundColor = reader.readInt32();
        value.backgroundColor = reader.readInt32();
        value.borderColor = reader.readInt32();
        value.underlineColor = reader.readInt32();
        value.underlineStyle = RangeEffectUnderlineStyle.fromValue(reader.readInt32());
        return value;
    }

    public static RangeEffectStyle decodeRangeEffectStyle(MemorySegment data, long size) {
        return readRangeEffectStyle(new BinaryReader(data, size));
    }

    private static void writeRangeEffectStyle(BinaryWriter writer, RangeEffectStyle value) {
        writer.writeInt32(value.foregroundColor);
        writer.writeInt32(value.backgroundColor);
        writer.writeInt32(value.borderColor);
        writer.writeInt32(value.underlineColor);
        writer.writeInt32(value.underlineStyle.value);
    }

    public static int sizeOfRangeEffectStyle(RangeEffectStyle value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeScrollbarConfig(BinaryWriter writer, ScrollbarConfig value) {
        writer.writeFloat32(value.thickness);
        writer.writeFloat32(value.minThumb);
        writer.writeFloat32(value.thumbHitPadding);
        writer.writeInt32(value.mode.value);
        writer.writeUint8(value.thumbDraggable ? 1 : 0);
        writer.writeInt32(value.trackTapMode.value);
        writer.writeUint16(value.fadeDelayMs);
        writer.writeUint16(value.fadeDurationMs);
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

    private static IntRange readIntRange(BinaryReader reader) {
        IntRange value = new IntRange();
        value.start = reader.readInt32();
        value.end = reader.readInt32();
        return value;
    }

    public static IntRange decodeIntRange(MemorySegment data, long size) {
        return readIntRange(new BinaryReader(data, size));
    }

    private static void writeIntRange(BinaryWriter writer, IntRange value) {
        writer.writeInt32(value.start);
        writer.writeInt32(value.end);
    }

    public static int sizeOfIntRange(IntRange value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static PointF readPointF(BinaryReader reader) {
        PointF value = new PointF();
        value.x = reader.readFloat32();
        value.y = reader.readFloat32();
        return value;
    }

    public static PointF decodePointF(MemorySegment data, long size) {
        return readPointF(new BinaryReader(data, size));
    }

    private static void writePointF(BinaryWriter writer, PointF value) {
        writer.writeFloat32(value.x);
        writer.writeFloat32(value.y);
    }

    public static int sizeOfPointF(PointF value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static Rect readRect(BinaryReader reader) {
        Rect value = new Rect();
        value.origin = readPointF(reader);
        value.width = reader.readFloat32();
        value.height = reader.readFloat32();
        return value;
    }

    public static Rect decodeRect(MemorySegment data, long size) {
        return readRect(new BinaryReader(data, size));
    }

    private static void writeRect(BinaryWriter writer, Rect value) {
        writePointF(writer, value.origin);
        writer.writeFloat32(value.width);
        writer.writeFloat32(value.height);
    }

    public static int sizeOfRect(Rect value) {
        int size = 0;
        size += sizeOfPointF(value.origin);
        size += 4;
        size += 4;
        return size;
    }

    private static Size readSize(BinaryReader reader) {
        Size value = new Size();
        value.width = reader.readFloat32();
        value.height = reader.readFloat32();
        return value;
    }

    public static Size decodeSize(MemorySegment data, long size) {
        return readSize(new BinaryReader(data, size));
    }

    private static void writeSize(BinaryWriter writer, Size value) {
        writer.writeFloat32(value.width);
        writer.writeFloat32(value.height);
    }

    public static int sizeOfSize(Size value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static TextChange readTextChange(BinaryReader reader) {
        TextChange value = new TextChange();
        value.range = readTextRange(reader);
        value.newText = reader.readUtf8String();
        return value;
    }

    public static TextChange decodeTextChange(MemorySegment data, long size) {
        return readTextChange(new BinaryReader(data, size));
    }

    private static TextEdit readTextEdit(BinaryReader reader) {
        TextEdit value = new TextEdit();
        value.range = readTextRange(reader);
        value.newText = reader.readUtf8String();
        return value;
    }

    public static TextEdit decodeTextEdit(MemorySegment data, long size) {
        return readTextEdit(new BinaryReader(data, size));
    }

    private static void writeTextEdit(BinaryWriter writer, TextEdit value) {
        writeTextRange(writer, value.range);
        writer.writeUtf8String(value.newText);
    }

    public static int sizeOfTextEdit(TextEdit value) {
        int size = 0;
        size += sizeOfTextRange(value.range);
        size += sizeOfUtf8String(value.newText);
        return size;
    }

    private static TextPosition readTextPosition(BinaryReader reader) {
        TextPosition value = new TextPosition();
        value.line = reader.readInt32();
        value.column = reader.readInt32();
        return value;
    }

    public static TextPosition decodeTextPosition(MemorySegment data, long size) {
        return readTextPosition(new BinaryReader(data, size));
    }

    private static void writeTextPosition(BinaryWriter writer, TextPosition value) {
        writer.writeInt32(value.line);
        writer.writeInt32(value.column);
    }

    public static int sizeOfTextPosition(TextPosition value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static TextRange readTextRange(BinaryReader reader) {
        TextRange value = new TextRange();
        value.start = readTextPosition(reader);
        value.end = readTextPosition(reader);
        return value;
    }

    public static TextRange decodeTextRange(MemorySegment data, long size) {
        return readTextRange(new BinaryReader(data, size));
    }

    private static void writeTextRange(BinaryWriter writer, TextRange value) {
        writeTextPosition(writer, value.start);
        writeTextPosition(writer, value.end);
    }

    public static int sizeOfTextRange(TextRange value) {
        int size = 0;
        size += sizeOfTextPosition(value.start);
        size += sizeOfTextPosition(value.end);
        return size;
    }

    private static void writeImeCommandMessage(BinaryWriter writer, ImeCommandMessage value) {
        writer.writeInt32(value.kind.value);
        writer.writeInt64(value.contextId);
        writer.writeInt32(value.contextRevision);
        writer.writeInt32(value.documentStartOffset);
        writeImeOffsetRange(writer, value.range);
        writeImeOffsetRange(writer, value.selection);
        writer.writeUtf8String(value.text);
        writer.writeInt32(value.cursorOffset);
        writer.writeInt32(value.deleteBefore);
        writer.writeInt32(value.deleteAfter);
        writer.writeInt32(value.textUnit.value);
        writer.writeInt32(value.markedRole.value);
        writer.writeInt32(value.scriptClass.value);
    }

    public static int sizeOfImeCommandMessage(ImeCommandMessage value) {
        int size = 0;
        size += 4;
        size += 8;
        size += 4;
        size += 4;
        size += sizeOfImeOffsetRange(value.range);
        size += sizeOfImeOffsetRange(value.selection);
        size += sizeOfUtf8String(value.text);
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static ImeInputContext readImeInputContext(BinaryReader reader) {
        ImeInputContext value = new ImeInputContext();
        value.id = reader.readInt64();
        value.revision = reader.readInt32();
        value.documentStartOffset = reader.readInt32();
        value.text = reader.readUtf8String();
        value.selection = readImeOffsetRange(reader);
        value.hasComposition = reader.readInt32() != 0;
        value.composition = readImeOffsetRange(reader);
        value.hasSystemMarkRange = reader.readInt32() != 0;
        value.systemMarkRange = readImeOffsetRange(reader);
        value.kind = ImeInputContextKind.fromValue(reader.readInt32());
        return value;
    }

    public static ImeInputContext decodeImeInputContext(MemorySegment data, long size) {
        return readImeInputContext(new BinaryReader(data, size));
    }

    private static ImeMarkedRange readImeMarkedRange(BinaryReader reader) {
        ImeMarkedRange value = new ImeMarkedRange();
        value.role = ImeMarkedRangeRole.fromValue(reader.readInt32());
        value.range = readImeOffsetRange(reader);
        return value;
    }

    public static ImeMarkedRange decodeImeMarkedRange(MemorySegment data, long size) {
        return readImeMarkedRange(new BinaryReader(data, size));
    }

    private static void writeImeMarkedRange(BinaryWriter writer, ImeMarkedRange value) {
        writer.writeInt32(value.role.value);
        writeImeOffsetRange(writer, value.range);
    }

    public static int sizeOfImeMarkedRange(ImeMarkedRange value) {
        int size = 0;
        size += 4;
        size += sizeOfImeOffsetRange(value.range);
        return size;
    }

    private static ImeOffsetRange readImeOffsetRange(BinaryReader reader) {
        ImeOffsetRange value = new ImeOffsetRange();
        value.start = reader.readInt32();
        value.end = reader.readInt32();
        return value;
    }

    public static ImeOffsetRange decodeImeOffsetRange(MemorySegment data, long size) {
        return readImeOffsetRange(new BinaryReader(data, size));
    }

    private static void writeImeOffsetRange(BinaryWriter writer, ImeOffsetRange value) {
        writer.writeInt32(value.start);
        writer.writeInt32(value.end);
    }

    public static int sizeOfImeOffsetRange(ImeOffsetRange value) {
        int size = 0;
        size += 4;
        size += 4;
        return size;
    }

    private static ImeSyncSnapshot readImeSyncSnapshot(BinaryReader reader) {
        ImeSyncSnapshot value = new ImeSyncSnapshot();
        value.cursor = readTextPosition(reader);
        value.selection = readTextRange(reader);
        value.hasSelection = reader.readInt32() != 0;
        value.hasComposingSession = reader.readInt32() != 0;
        value.hasVisibleCompositionRange = reader.readInt32() != 0;
        value.visibleCompositionRange = readTextRange(reader);
        value.hasSystemMarkRange = reader.readInt32() != 0;
        value.systemMarkRange = readTextRange(reader);
        value.preeditStorage = ImePreeditStorage.fromValue(reader.readInt32());
        value.contextPolicy = ImeContextPolicy.fromValue(reader.readInt32());
        value.clearSystemMark = reader.readInt32() != 0;
        return value;
    }

    public static ImeSyncSnapshot decodeImeSyncSnapshot(MemorySegment data, long size) {
        return readImeSyncSnapshot(new BinaryReader(data, size));
    }

    private static ImeTextPatch readImeTextPatch(BinaryReader reader) {
        ImeTextPatch value = new ImeTextPatch();
        value.range = readImeOffsetRange(reader);
        value.text = reader.readUtf8String();
        return value;
    }

    public static ImeTextPatch decodeImeTextPatch(MemorySegment data, long size) {
        return readImeTextPatch(new BinaryReader(data, size));
    }

    private static void writeImeTextPatch(BinaryWriter writer, ImeTextPatch value) {
        writeImeOffsetRange(writer, value.range);
        writer.writeUtf8String(value.text);
    }

    public static int sizeOfImeTextPatch(ImeTextPatch value) {
        int size = 0;
        size += sizeOfImeOffsetRange(value.range);
        size += sizeOfUtf8String(value.text);
        return size;
    }

    private static void writeImeTextUpdateMessage(BinaryWriter writer, ImeTextUpdateMessage value) {
        writer.writeInt32(value.kind.value);
        writer.writeInt32(value.scope.value);
        writer.writeInt64(value.contextId);
        writer.writeInt32(value.contextRevision);
        writer.writeInt32(value.documentStartOffset);
        writer.writeUtf8String(value.text);
        writeImeTextPatch(writer, value.patch);
        writeImeOffsetRange(writer, value.selection);
        writeImeMarkedRange(writer, value.markedRange);
        writer.writeInt32(value.scriptClass.value);
    }

    public static int sizeOfImeTextUpdateMessage(ImeTextUpdateMessage value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 8;
        size += 4;
        size += 4;
        size += sizeOfUtf8String(value.text);
        size += sizeOfImeTextPatch(value.patch);
        size += sizeOfImeOffsetRange(value.selection);
        size += sizeOfImeMarkedRange(value.markedRange);
        size += 4;
        return size;
    }

    private static void writeGestureEvent(BinaryWriter writer, GestureEvent value) {
        writer.writeInt32(value.type.value);
        writePointFList(writer, value.points);
        writer.writeInt32(value.modifiers);
        writer.writeFloat32(value.wheelDeltaX);
        writer.writeFloat32(value.wheelDeltaY);
        writer.writeFloat32(value.directScale);
    }

    public static int sizeOfGestureEvent(GestureEvent value) {
        int size = 0;
        size += 4;
        size += sizeOfPointFList(value.points);
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static HitTarget readHitTarget(BinaryReader reader) {
        HitTarget value = new HitTarget();
        value.type = HitTargetType.fromValue(reader.readInt32());
        value.line = reader.readInt32();
        value.column = reader.readInt32();
        value.iconId = reader.readInt32();
        value.colorValue = reader.readInt32();
        return value;
    }

    public static HitTarget decodeHitTarget(MemorySegment data, long size) {
        return readHitTarget(new BinaryReader(data, size));
    }

    private static KeyBinding readKeyBinding(BinaryReader reader) {
        KeyBinding value = new KeyBinding();
        value.first = readKeyChord(reader);
        value.second = readKeyChord(reader);
        value.command = reader.readInt32();
        return value;
    }

    public static KeyBinding decodeKeyBinding(MemorySegment data, long size) {
        return readKeyBinding(new BinaryReader(data, size));
    }

    private static void writeKeyBinding(BinaryWriter writer, KeyBinding value) {
        writeKeyChord(writer, value.first);
        writeKeyChord(writer, value.second);
        writer.writeInt32(value.command);
    }

    public static int sizeOfKeyBinding(KeyBinding value) {
        int size = 0;
        size += sizeOfKeyChord(value.first);
        size += sizeOfKeyChord(value.second);
        size += 4;
        return size;
    }

    private static KeyChord readKeyChord(BinaryReader reader) {
        KeyChord value = new KeyChord();
        value.modifiers = reader.readUint8();
        value.keyCode = reader.readUint16();
        return value;
    }

    public static KeyChord decodeKeyChord(MemorySegment data, long size) {
        return readKeyChord(new BinaryReader(data, size));
    }

    private static void writeKeyChord(BinaryWriter writer, KeyChord value) {
        writer.writeUint8(value.modifiers);
        writer.writeUint16(value.keyCode);
    }

    public static int sizeOfKeyChord(KeyChord value) {
        int size = 0;
        size += 1;
        size += 2;
        return size;
    }

    private static void writeLinkedEditingModel(BinaryWriter writer, LinkedEditingModel value) {
        writeTabStopGroupList(writer, value.groups);
    }

    public static int sizeOfLinkedEditingModel(LinkedEditingModel value) {
        int size = 0;
        size += sizeOfTabStopGroupList(value.groups);
        return size;
    }

    private static void writeTabStopGroup(BinaryWriter writer, TabStopGroup value) {
        writer.writeInt32(value.index);
        writeTextRangeList(writer, value.ranges);
        writer.writeUtf8String(value.defaultText);
    }

    public static int sizeOfTabStopGroup(TabStopGroup value) {
        int size = 0;
        size += 4;
        size += sizeOfTextRangeList(value.ranges);
        size += sizeOfUtf8String(value.defaultText);
        return size;
    }

    private static SearchOptions readSearchOptions(BinaryReader reader) {
        SearchOptions value = new SearchOptions();
        value.caseSensitive = reader.readInt32() != 0;
        value.wholeWord = reader.readInt32() != 0;
        value.useRegex = reader.readInt32() != 0;
        value.wrapAround = reader.readInt32() != 0;
        value.maxMatches = reader.readInt32();
        return value;
    }

    public static SearchOptions decodeSearchOptions(MemorySegment data, long size) {
        return readSearchOptions(new BinaryReader(data, size));
    }

    private static void writeSearchOptions(BinaryWriter writer, SearchOptions value) {
        writer.writeInt32(value.caseSensitive ? 1 : 0);
        writer.writeInt32(value.wholeWord ? 1 : 0);
        writer.writeInt32(value.useRegex ? 1 : 0);
        writer.writeInt32(value.wrapAround ? 1 : 0);
        writer.writeInt32(value.maxMatches);
    }

    public static int sizeOfSearchOptions(SearchOptions value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static void writeSearchRequest(BinaryWriter writer, SearchRequest value) {
        writer.writeUtf8String(value.pattern);
        writeSearchOptions(writer, value.options);
    }

    public static int sizeOfSearchRequest(SearchRequest value) {
        int size = 0;
        size += sizeOfUtf8String(value.pattern);
        size += sizeOfSearchOptions(value.options);
        return size;
    }

    private static SearchState readSearchState(BinaryReader reader) {
        SearchState value = new SearchState();
        value.status = SearchStatus.fromValue(reader.readInt32());
        value.pattern = reader.readUtf8String();
        value.options = readSearchOptions(reader);
        value.generation = reader.readInt64();
        value.matchCount = reader.readInt32();
        value.currentIndex = reader.readInt32();
        value.hasCurrentMatch = reader.readInt32() != 0;
        value.currentRange = readTextRange(reader);
        value.errorMessage = reader.readUtf8String();
        return value;
    }

    public static SearchState decodeSearchState(MemorySegment data, long size) {
        return readSearchState(new BinaryReader(data, size));
    }

    private static Cursor readCursor(BinaryReader reader) {
        Cursor value = new Cursor();
        value.textPosition = readTextPosition(reader);
        value.position = readPointF(reader);
        value.height = reader.readFloat32();
        value.visible = reader.readInt32() != 0;
        value.showDragger = reader.readInt32() != 0;
        return value;
    }

    public static Cursor decodeCursor(MemorySegment data, long size) {
        return readCursor(new BinaryReader(data, size));
    }

    private static CursorRect readCursorRect(BinaryReader reader) {
        CursorRect value = new CursorRect();
        value.x = reader.readFloat32();
        value.y = reader.readFloat32();
        value.height = reader.readFloat32();
        return value;
    }

    public static CursorRect decodeCursorRect(MemorySegment data, long size) {
        return readCursorRect(new BinaryReader(data, size));
    }

    private static void writeCursorRect(BinaryWriter writer, CursorRect value) {
        writer.writeFloat32(value.x);
        writer.writeFloat32(value.y);
        writer.writeFloat32(value.height);
    }

    public static int sizeOfCursorRect(CursorRect value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        return size;
    }

    private static EditorRenderModel readEditorRenderModel(BinaryReader reader) {
        EditorRenderModel value = new EditorRenderModel();
        value.splitX = reader.readFloat32();
        value.splitLineVisible = reader.readInt32() != 0;
        value.scrollX = reader.readFloat32();
        value.scrollY = reader.readFloat32();
        value.viewportSize = readSize(reader);
        value.currentLine = readPointF(reader);
        value.currentLineRenderMode = CurrentLineRenderMode.fromValue(reader.readInt32());
        value.lines = readVisualLineList(reader);
        value.cursor = readCursor(reader);
        value.rangeEffects = readRangeEffectRenderItemList(reader);
        value.selectionStartHandle = readSelectionHandle(reader);
        value.selectionEndHandle = readSelectionHandle(reader);
        value.guideSegments = readGuideSegmentList(reader);
        value.maxGutterIcons = reader.readInt32();
        value.gutterIcons = readGutterIconRenderItemList(reader);
        value.foldMarkers = readFoldMarkerRenderItemList(reader);
        value.verticalScrollbar = readScrollbarModel(reader);
        value.horizontalScrollbar = readScrollbarModel(reader);
        value.gutterSticky = reader.readInt32() != 0;
        value.gutterVisible = reader.readInt32() != 0;
        value.pointerCursorType = PointerCursorType.fromValue(reader.readInt32());
        return value;
    }

    public static EditorRenderModel decodeEditorRenderModel(MemorySegment data, long size) {
        return readEditorRenderModel(new BinaryReader(data, size));
    }

    private static FoldMarkerRenderItem readFoldMarkerRenderItem(BinaryReader reader) {
        FoldMarkerRenderItem value = new FoldMarkerRenderItem();
        value.logicalLine = reader.readInt32();
        value.foldState = FoldState.fromValue(reader.readInt32());
        value.rect = readRect(reader);
        return value;
    }

    public static FoldMarkerRenderItem decodeFoldMarkerRenderItem(MemorySegment data, long size) {
        return readFoldMarkerRenderItem(new BinaryReader(data, size));
    }

    private static GuideSegment readGuideSegment(BinaryReader reader) {
        GuideSegment value = new GuideSegment();
        value.direction = GuideDirection.fromValue(reader.readInt32());
        value.type = GuideType.fromValue(reader.readInt32());
        value.style = GuideStyle.fromValue(reader.readInt32());
        value.start = readPointF(reader);
        value.end = readPointF(reader);
        value.arrowEnd = reader.readInt32() != 0;
        return value;
    }

    public static GuideSegment decodeGuideSegment(MemorySegment data, long size) {
        return readGuideSegment(new BinaryReader(data, size));
    }

    private static GutterIconRenderItem readGutterIconRenderItem(BinaryReader reader) {
        GutterIconRenderItem value = new GutterIconRenderItem();
        value.logicalLine = reader.readInt32();
        value.iconId = reader.readInt32();
        value.rect = readRect(reader);
        return value;
    }

    public static GutterIconRenderItem decodeGutterIconRenderItem(MemorySegment data, long size) {
        return readGutterIconRenderItem(new BinaryReader(data, size));
    }

    private static LayoutMetrics readLayoutMetrics(BinaryReader reader) {
        LayoutMetrics value = new LayoutMetrics();
        value.fontHeight = reader.readFloat32();
        value.fontAscent = reader.readFloat32();
        value.lineSpacingAdd = reader.readFloat32();
        value.lineSpacingMult = reader.readFloat32();
        value.lineNumberMargin = reader.readFloat32();
        value.lineNumberWidth = reader.readFloat32();
        value.contentStartPadding = reader.readFloat32();
        value.maxGutterIcons = reader.readInt32();
        value.inlayHintPadding = reader.readFloat32();
        value.inlayHintMargin = reader.readFloat32();
        value.foldArrowMode = FoldArrowMode.fromValue(reader.readInt32());
        value.hasFoldRegions = reader.readInt32() != 0;
        value.gutterSticky = reader.readInt32() != 0;
        value.gutterVisible = reader.readInt32() != 0;
        return value;
    }

    public static LayoutMetrics decodeLayoutMetrics(MemorySegment data, long size) {
        return readLayoutMetrics(new BinaryReader(data, size));
    }

    private static RangeEffectRenderItem readRangeEffectRenderItem(BinaryReader reader) {
        RangeEffectRenderItem value = new RangeEffectRenderItem();
        value.rect = readRect(reader);
        value.kind = RangeEffectKind.fromValue(reader.readInt32());
        value.style = readRangeEffectStyle(reader);
        return value;
    }

    public static RangeEffectRenderItem decodeRangeEffectRenderItem(MemorySegment data, long size) {
        return readRangeEffectRenderItem(new BinaryReader(data, size));
    }

    private static ScrollMetrics readScrollMetrics(BinaryReader reader) {
        ScrollMetrics value = new ScrollMetrics();
        value.scale = reader.readFloat32();
        value.scrollX = reader.readFloat32();
        value.scrollY = reader.readFloat32();
        value.maxScrollX = reader.readFloat32();
        value.maxScrollY = reader.readFloat32();
        value.contentSize = readSize(reader);
        value.viewportSize = readSize(reader);
        value.textAreaX = reader.readFloat32();
        value.textAreaWidth = reader.readFloat32();
        value.canScrollX = reader.readInt32() != 0;
        value.canScrollY = reader.readInt32() != 0;
        return value;
    }

    public static ScrollMetrics decodeScrollMetrics(MemorySegment data, long size) {
        return readScrollMetrics(new BinaryReader(data, size));
    }

    private static ScrollbarModel readScrollbarModel(BinaryReader reader) {
        ScrollbarModel value = new ScrollbarModel();
        value.visible = reader.readInt32() != 0;
        value.alpha = reader.readFloat32();
        value.thumbActive = reader.readInt32() != 0;
        value.track = readRect(reader);
        value.thumb = readRect(reader);
        return value;
    }

    public static ScrollbarModel decodeScrollbarModel(MemorySegment data, long size) {
        return readScrollbarModel(new BinaryReader(data, size));
    }

    private static SelectionHandle readSelectionHandle(BinaryReader reader) {
        SelectionHandle value = new SelectionHandle();
        value.position = readPointF(reader);
        value.height = reader.readFloat32();
        value.visible = reader.readInt32() != 0;
        return value;
    }

    public static SelectionHandle decodeSelectionHandle(MemorySegment data, long size) {
        return readSelectionHandle(new BinaryReader(data, size));
    }

    private static VisualLine readVisualLine(BinaryReader reader) {
        VisualLine value = new VisualLine();
        value.logicalLine = reader.readInt32();
        value.wrapIndex = reader.readInt32();
        value.lineNumberPosition = readPointF(reader);
        value.runs = readVisualRunList(reader);
        value.kind = VisualLineKind.fromValue(reader.readInt32());
        value.ownsGutterSemantics = reader.readInt32() != 0;
        value.foldState = FoldState.fromValue(reader.readInt32());
        return value;
    }

    public static VisualLine decodeVisualLine(MemorySegment data, long size) {
        return readVisualLine(new BinaryReader(data, size));
    }

    private static VisualRun readVisualRun(BinaryReader reader) {
        VisualRun value = new VisualRun();
        value.type = VisualRunType.fromValue(reader.readInt32());
        value.x = reader.readFloat32();
        value.y = reader.readFloat32();
        value.text = reader.readUtf8String();
        value.style = readTextStyle(reader);
        value.iconId = reader.readInt32();
        value.colorValue = reader.readInt32();
        value.width = reader.readFloat32();
        value.padding = reader.readFloat32();
        value.margin = reader.readFloat32();
        value.active = reader.readInt32() != 0;
        return value;
    }

    public static VisualRun decodeVisualRun(MemorySegment data, long size) {
        return readVisualRun(new BinaryReader(data, size));
    }

    public static MemorySegment encodeBracketGuide(Arena arena, BracketGuide value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfBracketGuide(value));
        writeBracketGuide(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeCodeLensItem(Arena arena, CodeLensItem value) {
        int size = 0;
        size += 4;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.column);
        writer.writeInt32(value.commandId);
        writer.writeUtf8Bytes(textUtf8);
        return writer.segment();
    }

    public static MemorySegment encodeDiagnostic(Arena arena, Diagnostic value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfDiagnostic(value));
        writeDiagnostic(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeDocumentHighlight(Arena arena, DocumentHighlight value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfDocumentHighlight(value));
        writeDocumentHighlight(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeFlowGuide(Arena arena, FlowGuide value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfFlowGuide(value));
        writeFlowGuide(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeFoldRegion(Arena arena, FoldRegion value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfFoldRegion(value));
        writeFoldRegion(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeGutterIcon(Arena arena, GutterIcon value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfGutterIcon(value));
        writeGutterIcon(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeIndentGuide(Arena arena, IndentGuide value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfIndentGuide(value));
        writeIndentGuide(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeInlayHint(Arena arena, InlayHint value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.type.value);
        writer.writeInt32(value.column);
        writer.writeInt32(value.intValue);
        writer.writeUtf8Bytes(textUtf8);
        return writer.segment();
    }

    public static MemorySegment encodeLinkSpan(Arena arena, LinkSpan value) {
        int size = 0;
        size += 4;
        size += 4;
        byte[] targetUtf8 = utf8Bytes(value.target);
        size += 4 + targetUtf8.length;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.column);
        writer.writeInt32(value.length);
        writer.writeUtf8Bytes(targetUtf8);
        return writer.segment();
    }

    public static MemorySegment encodePhantomText(Arena arena, PhantomText value) {
        int size = 0;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.column);
        writer.writeUtf8Bytes(textUtf8);
        return writer.segment();
    }

    private static void writeRegisterBatchTextStylesPayloadWire(BinaryWriter writer, java.util.Map<Integer, ? extends TextStyle> styleByStyleId) {
        java.util.TreeMap<Integer, TextStyle> sortedStyleByStyleId = new java.util.TreeMap<>();
        if (styleByStyleId != null) {
            for (java.util.Map.Entry<Integer, ? extends TextStyle> entry : styleByStyleId.entrySet()) {
                sortedStyleByStyleId.put(entry.getKey(), entry.getValue());
            }
        }
        writer.writeInt32(sortedStyleByStyleId.size());
        for (java.util.Map.Entry<Integer, TextStyle> entry : sortedStyleByStyleId.entrySet()) {
            writer.writeInt32(entry.getKey());
            writeTextStyle(writer, entry.getValue());
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

    public static MemorySegment encodeRegisterBatchTextStylesPayload(Arena arena, java.util.Map<Integer, ? extends TextStyle> styleByStyleId) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId));
        writeRegisterBatchTextStylesPayloadWire(writer, styleByStyleId);
        return writer.segment();
    }

    public static MemorySegment encodeSeparatorGuide(Arena arena, SeparatorGuide value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSeparatorGuide(value));
        writeSeparatorGuide(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeSetBatchLineCodeLensPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends CodeLensItem>> itemsByLine) {
        int size = 0;
        java.util.TreeMap<Integer, java.util.List<? extends CodeLensItem>> sortedItemsByLine = new java.util.TreeMap<>();
        if (itemsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends CodeLensItem>> entry : itemsByLine.entrySet()) {
                sortedItemsByLine.put(entry.getKey(), entry.getValue());
            }
        }
        int itemsByLineCount = sortedItemsByLine.size();
        int itemsByLineItemCount = 0;
        size += 4;
        for (java.util.Map.Entry<Integer, java.util.List<? extends CodeLensItem>> entry : sortedItemsByLine.entrySet()) {
            size += 4;
            java.util.List<? extends CodeLensItem> itemsByLineItems = entry.getValue();
            int itemsByLineItemsCount = itemsByLineItems == null ? 0 : itemsByLineItems.size();
            itemsByLineItemCount += itemsByLineItemsCount;
            size += 4;
        }
        byte[][] itemsByLineTextUtf8 = new byte[itemsByLineItemCount][];
        int itemsByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends CodeLensItem>> entry : sortedItemsByLine.entrySet()) {
            java.util.List<? extends CodeLensItem> itemsByLineItems = entry.getValue();
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(itemsByLineCount);
        itemsByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends CodeLensItem>> entry : sortedItemsByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            java.util.List<? extends CodeLensItem> itemsByLineItems = entry.getValue();
            int itemsByLineItemsCount = itemsByLineItems == null ? 0 : itemsByLineItems.size();
            writer.writeInt32(itemsByLineItemsCount);
            for (int itemsByLineItemsIndex = 0; itemsByLineItemsIndex < itemsByLineItemsCount; itemsByLineItemsIndex++) {
                CodeLensItem itemsByLineItem = itemsByLineItems.get(itemsByLineItemsIndex);
                writer.writeInt32(itemsByLineItem.column);
                writer.writeInt32(itemsByLineItem.commandId);
                writer.writeUtf8Bytes(itemsByLineTextUtf8[itemsByLineItemIndex]);
                itemsByLineItemIndex++;
            }
        }
        return writer.segment();
    }

    private static void writeSetBatchLineDiagnosticsPayloadWire(BinaryWriter writer, java.util.Map<Integer, ? extends java.util.List<? extends Diagnostic>> diagnosticsByLine) {
        java.util.TreeMap<Integer, java.util.List<? extends Diagnostic>> sortedDiagnosticsByLine = new java.util.TreeMap<>();
        if (diagnosticsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends Diagnostic>> entry : diagnosticsByLine.entrySet()) {
                sortedDiagnosticsByLine.put(entry.getKey(), entry.getValue());
            }
        }
        writer.writeInt32(sortedDiagnosticsByLine.size());
        for (java.util.Map.Entry<Integer, java.util.List<? extends Diagnostic>> entry : sortedDiagnosticsByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            writeDiagnosticList(writer, entry.getValue());
        }
    }

    private static int sizeOfSetBatchLineDiagnosticsPayloadWire(java.util.Map<Integer, ? extends java.util.List<? extends Diagnostic>> diagnosticsByLine) {
        int size = 0;
        size += 4;
        if (diagnosticsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends Diagnostic>> entry : diagnosticsByLine.entrySet()) {
                size += 4;
                size += sizeOfDiagnosticList(entry.getValue());
            }
        }
        return size;
    }

    public static MemorySegment encodeSetBatchLineDiagnosticsPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends Diagnostic>> diagnosticsByLine) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine));
        writeSetBatchLineDiagnosticsPayloadWire(writer, diagnosticsByLine);
        return writer.segment();
    }

    private static void writeSetBatchLineDocumentHighlightsPayloadWire(BinaryWriter writer, java.util.Map<Integer, ? extends java.util.List<? extends DocumentHighlight>> highlightsByLine) {
        java.util.TreeMap<Integer, java.util.List<? extends DocumentHighlight>> sortedHighlightsByLine = new java.util.TreeMap<>();
        if (highlightsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends DocumentHighlight>> entry : highlightsByLine.entrySet()) {
                sortedHighlightsByLine.put(entry.getKey(), entry.getValue());
            }
        }
        writer.writeInt32(sortedHighlightsByLine.size());
        for (java.util.Map.Entry<Integer, java.util.List<? extends DocumentHighlight>> entry : sortedHighlightsByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            writeDocumentHighlightList(writer, entry.getValue());
        }
    }

    private static int sizeOfSetBatchLineDocumentHighlightsPayloadWire(java.util.Map<Integer, ? extends java.util.List<? extends DocumentHighlight>> highlightsByLine) {
        int size = 0;
        size += 4;
        if (highlightsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends DocumentHighlight>> entry : highlightsByLine.entrySet()) {
                size += 4;
                size += sizeOfDocumentHighlightList(entry.getValue());
            }
        }
        return size;
    }

    public static MemorySegment encodeSetBatchLineDocumentHighlightsPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends DocumentHighlight>> highlightsByLine) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetBatchLineDocumentHighlightsPayloadWire(highlightsByLine));
        writeSetBatchLineDocumentHighlightsPayloadWire(writer, highlightsByLine);
        return writer.segment();
    }

    private static void writeSetBatchLineGutterIconsPayloadWire(BinaryWriter writer, java.util.Map<Integer, ? extends java.util.List<? extends GutterIcon>> iconsByLine) {
        java.util.TreeMap<Integer, java.util.List<? extends GutterIcon>> sortedIconsByLine = new java.util.TreeMap<>();
        if (iconsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends GutterIcon>> entry : iconsByLine.entrySet()) {
                sortedIconsByLine.put(entry.getKey(), entry.getValue());
            }
        }
        writer.writeInt32(sortedIconsByLine.size());
        for (java.util.Map.Entry<Integer, java.util.List<? extends GutterIcon>> entry : sortedIconsByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            writeGutterIconList(writer, entry.getValue());
        }
    }

    private static int sizeOfSetBatchLineGutterIconsPayloadWire(java.util.Map<Integer, ? extends java.util.List<? extends GutterIcon>> iconsByLine) {
        int size = 0;
        size += 4;
        if (iconsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends GutterIcon>> entry : iconsByLine.entrySet()) {
                size += 4;
                size += sizeOfGutterIconList(entry.getValue());
            }
        }
        return size;
    }

    public static MemorySegment encodeSetBatchLineGutterIconsPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends GutterIcon>> iconsByLine) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine));
        writeSetBatchLineGutterIconsPayloadWire(writer, iconsByLine);
        return writer.segment();
    }

    public static MemorySegment encodeSetBatchLineInlayHintsPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends InlayHint>> hintsByLine) {
        int size = 0;
        java.util.TreeMap<Integer, java.util.List<? extends InlayHint>> sortedHintsByLine = new java.util.TreeMap<>();
        if (hintsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends InlayHint>> entry : hintsByLine.entrySet()) {
                sortedHintsByLine.put(entry.getKey(), entry.getValue());
            }
        }
        int hintsByLineCount = sortedHintsByLine.size();
        int hintsByLineItemCount = 0;
        size += 4;
        for (java.util.Map.Entry<Integer, java.util.List<? extends InlayHint>> entry : sortedHintsByLine.entrySet()) {
            size += 4;
            java.util.List<? extends InlayHint> hintsByLineHints = entry.getValue();
            int hintsByLineHintsCount = hintsByLineHints == null ? 0 : hintsByLineHints.size();
            hintsByLineItemCount += hintsByLineHintsCount;
            size += 4;
        }
        byte[][] hintsByLineTextUtf8 = new byte[hintsByLineItemCount][];
        int hintsByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends InlayHint>> entry : sortedHintsByLine.entrySet()) {
            java.util.List<? extends InlayHint> hintsByLineHints = entry.getValue();
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(hintsByLineCount);
        hintsByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends InlayHint>> entry : sortedHintsByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            java.util.List<? extends InlayHint> hintsByLineHints = entry.getValue();
            int hintsByLineHintsCount = hintsByLineHints == null ? 0 : hintsByLineHints.size();
            writer.writeInt32(hintsByLineHintsCount);
            for (int hintsByLineHintsIndex = 0; hintsByLineHintsIndex < hintsByLineHintsCount; hintsByLineHintsIndex++) {
                InlayHint hintsByLineItem = hintsByLineHints.get(hintsByLineHintsIndex);
                writer.writeInt32(hintsByLineItem.type.value);
                writer.writeInt32(hintsByLineItem.column);
                writer.writeInt32(hintsByLineItem.intValue);
                writer.writeUtf8Bytes(hintsByLineTextUtf8[hintsByLineItemIndex]);
                hintsByLineItemIndex++;
            }
        }
        return writer.segment();
    }

    public static MemorySegment encodeSetBatchLineLinksPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends LinkSpan>> linksByLine) {
        int size = 0;
        java.util.TreeMap<Integer, java.util.List<? extends LinkSpan>> sortedLinksByLine = new java.util.TreeMap<>();
        if (linksByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends LinkSpan>> entry : linksByLine.entrySet()) {
                sortedLinksByLine.put(entry.getKey(), entry.getValue());
            }
        }
        int linksByLineCount = sortedLinksByLine.size();
        int linksByLineItemCount = 0;
        size += 4;
        for (java.util.Map.Entry<Integer, java.util.List<? extends LinkSpan>> entry : sortedLinksByLine.entrySet()) {
            size += 4;
            java.util.List<? extends LinkSpan> linksByLineLinks = entry.getValue();
            int linksByLineLinksCount = linksByLineLinks == null ? 0 : linksByLineLinks.size();
            linksByLineItemCount += linksByLineLinksCount;
            size += 4;
        }
        byte[][] linksByLineTargetUtf8 = new byte[linksByLineItemCount][];
        int linksByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends LinkSpan>> entry : sortedLinksByLine.entrySet()) {
            java.util.List<? extends LinkSpan> linksByLineLinks = entry.getValue();
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(linksByLineCount);
        linksByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends LinkSpan>> entry : sortedLinksByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            java.util.List<? extends LinkSpan> linksByLineLinks = entry.getValue();
            int linksByLineLinksCount = linksByLineLinks == null ? 0 : linksByLineLinks.size();
            writer.writeInt32(linksByLineLinksCount);
            for (int linksByLineLinksIndex = 0; linksByLineLinksIndex < linksByLineLinksCount; linksByLineLinksIndex++) {
                LinkSpan linksByLineItem = linksByLineLinks.get(linksByLineLinksIndex);
                writer.writeInt32(linksByLineItem.column);
                writer.writeInt32(linksByLineItem.length);
                writer.writeUtf8Bytes(linksByLineTargetUtf8[linksByLineItemIndex]);
                linksByLineItemIndex++;
            }
        }
        return writer.segment();
    }

    public static MemorySegment encodeSetBatchLinePhantomTextsPayload(Arena arena, java.util.Map<Integer, ? extends java.util.List<? extends PhantomText>> phantomsByLine) {
        int size = 0;
        java.util.TreeMap<Integer, java.util.List<? extends PhantomText>> sortedPhantomsByLine = new java.util.TreeMap<>();
        if (phantomsByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends PhantomText>> entry : phantomsByLine.entrySet()) {
                sortedPhantomsByLine.put(entry.getKey(), entry.getValue());
            }
        }
        int phantomsByLineCount = sortedPhantomsByLine.size();
        int phantomsByLineItemCount = 0;
        size += 4;
        for (java.util.Map.Entry<Integer, java.util.List<? extends PhantomText>> entry : sortedPhantomsByLine.entrySet()) {
            size += 4;
            java.util.List<? extends PhantomText> phantomsByLinePhantoms = entry.getValue();
            int phantomsByLinePhantomsCount = phantomsByLinePhantoms == null ? 0 : phantomsByLinePhantoms.size();
            phantomsByLineItemCount += phantomsByLinePhantomsCount;
            size += 4;
        }
        byte[][] phantomsByLineTextUtf8 = new byte[phantomsByLineItemCount][];
        int phantomsByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends PhantomText>> entry : sortedPhantomsByLine.entrySet()) {
            java.util.List<? extends PhantomText> phantomsByLinePhantoms = entry.getValue();
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(phantomsByLineCount);
        phantomsByLineItemIndex = 0;
        for (java.util.Map.Entry<Integer, java.util.List<? extends PhantomText>> entry : sortedPhantomsByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            java.util.List<? extends PhantomText> phantomsByLinePhantoms = entry.getValue();
            int phantomsByLinePhantomsCount = phantomsByLinePhantoms == null ? 0 : phantomsByLinePhantoms.size();
            writer.writeInt32(phantomsByLinePhantomsCount);
            for (int phantomsByLinePhantomsIndex = 0; phantomsByLinePhantomsIndex < phantomsByLinePhantomsCount; phantomsByLinePhantomsIndex++) {
                PhantomText phantomsByLineItem = phantomsByLinePhantoms.get(phantomsByLinePhantomsIndex);
                writer.writeInt32(phantomsByLineItem.column);
                writer.writeUtf8Bytes(phantomsByLineTextUtf8[phantomsByLineItemIndex]);
                phantomsByLineItemIndex++;
            }
        }
        return writer.segment();
    }

    private static void writeSetBatchLineSpansPayloadWire(BinaryWriter writer, SpanLayer layer, java.util.Map<Integer, ? extends java.util.List<? extends StyleSpan>> spansByLine) {
        writer.writeInt32(layer.value);
        java.util.TreeMap<Integer, java.util.List<? extends StyleSpan>> sortedSpansByLine = new java.util.TreeMap<>();
        if (spansByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends StyleSpan>> entry : spansByLine.entrySet()) {
                sortedSpansByLine.put(entry.getKey(), entry.getValue());
            }
        }
        writer.writeInt32(sortedSpansByLine.size());
        for (java.util.Map.Entry<Integer, java.util.List<? extends StyleSpan>> entry : sortedSpansByLine.entrySet()) {
            writer.writeInt32(entry.getKey());
            writeStyleSpanList(writer, entry.getValue());
        }
    }

    private static int sizeOfSetBatchLineSpansPayloadWire(SpanLayer layer, java.util.Map<Integer, ? extends java.util.List<? extends StyleSpan>> spansByLine) {
        int size = 0;
        size += 4;
        size += 4;
        if (spansByLine != null) {
            for (java.util.Map.Entry<Integer, ? extends java.util.List<? extends StyleSpan>> entry : spansByLine.entrySet()) {
                size += 4;
                size += sizeOfStyleSpanList(entry.getValue());
            }
        }
        return size;
    }

    public static MemorySegment encodeSetBatchLineSpansPayload(Arena arena, SpanLayer layer, java.util.Map<Integer, ? extends java.util.List<? extends StyleSpan>> spansByLine) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetBatchLineSpansPayloadWire(layer, spansByLine));
        writeSetBatchLineSpansPayloadWire(writer, layer, spansByLine);
        return writer.segment();
    }

    private static void writeSetBracketGuidesPayloadWire(BinaryWriter writer, java.util.List<? extends BracketGuide> guides) {
        writeBracketGuideList(writer, guides);
    }

    private static int sizeOfSetBracketGuidesPayloadWire(java.util.List<? extends BracketGuide> guides) {
        int size = 0;
        size += sizeOfBracketGuideList(guides);
        return size;
    }

    public static MemorySegment encodeSetBracketGuidesPayload(Arena arena, java.util.List<? extends BracketGuide> guides) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetBracketGuidesPayloadWire(guides));
        writeSetBracketGuidesPayloadWire(writer, guides);
        return writer.segment();
    }

    private static void writeSetFlowGuidesPayloadWire(BinaryWriter writer, java.util.List<? extends FlowGuide> guides) {
        writeFlowGuideList(writer, guides);
    }

    private static int sizeOfSetFlowGuidesPayloadWire(java.util.List<? extends FlowGuide> guides) {
        int size = 0;
        size += sizeOfFlowGuideList(guides);
        return size;
    }

    public static MemorySegment encodeSetFlowGuidesPayload(Arena arena, java.util.List<? extends FlowGuide> guides) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetFlowGuidesPayloadWire(guides));
        writeSetFlowGuidesPayloadWire(writer, guides);
        return writer.segment();
    }

    private static void writeSetFoldRegionsPayloadWire(BinaryWriter writer, java.util.List<? extends FoldRegion> regions) {
        writeFoldRegionList(writer, regions);
    }

    private static int sizeOfSetFoldRegionsPayloadWire(java.util.List<? extends FoldRegion> regions) {
        int size = 0;
        size += sizeOfFoldRegionList(regions);
        return size;
    }

    public static MemorySegment encodeSetFoldRegionsPayload(Arena arena, java.util.List<? extends FoldRegion> regions) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetFoldRegionsPayloadWire(regions));
        writeSetFoldRegionsPayloadWire(writer, regions);
        return writer.segment();
    }

    private static void writeSetIndentGuidesPayloadWire(BinaryWriter writer, java.util.List<? extends IndentGuide> guides) {
        writeIndentGuideList(writer, guides);
    }

    private static int sizeOfSetIndentGuidesPayloadWire(java.util.List<? extends IndentGuide> guides) {
        int size = 0;
        size += sizeOfIndentGuideList(guides);
        return size;
    }

    public static MemorySegment encodeSetIndentGuidesPayload(Arena arena, java.util.List<? extends IndentGuide> guides) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetIndentGuidesPayloadWire(guides));
        writeSetIndentGuidesPayloadWire(writer, guides);
        return writer.segment();
    }

    public static MemorySegment encodeSetLineCodeLensPayload(Arena arena, int line, java.util.List<? extends CodeLensItem> items) {
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(line);
        writer.writeInt32(itemsCount);
        for (int itemsIndex = 0; itemsIndex < itemsCount; itemsIndex++) {
            CodeLensItem itemsItem = items.get(itemsIndex);
            writer.writeInt32(itemsItem.column);
            writer.writeInt32(itemsItem.commandId);
            writer.writeUtf8Bytes(itemsTextUtf8[itemsIndex]);
        }
        return writer.segment();
    }

    private static void writeSetLineDiagnosticsPayloadWire(BinaryWriter writer, int line, java.util.List<? extends Diagnostic> diagnostics) {
        writer.writeInt32(line);
        writeDiagnosticList(writer, diagnostics);
    }

    private static int sizeOfSetLineDiagnosticsPayloadWire(int line, java.util.List<? extends Diagnostic> diagnostics) {
        int size = 0;
        size += 4;
        size += sizeOfDiagnosticList(diagnostics);
        return size;
    }

    public static MemorySegment encodeSetLineDiagnosticsPayload(Arena arena, int line, java.util.List<? extends Diagnostic> diagnostics) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetLineDiagnosticsPayloadWire(line, diagnostics));
        writeSetLineDiagnosticsPayloadWire(writer, line, diagnostics);
        return writer.segment();
    }

    private static void writeSetLineDocumentHighlightsPayloadWire(BinaryWriter writer, int line, java.util.List<? extends DocumentHighlight> highlights) {
        writer.writeInt32(line);
        writeDocumentHighlightList(writer, highlights);
    }

    private static int sizeOfSetLineDocumentHighlightsPayloadWire(int line, java.util.List<? extends DocumentHighlight> highlights) {
        int size = 0;
        size += 4;
        size += sizeOfDocumentHighlightList(highlights);
        return size;
    }

    public static MemorySegment encodeSetLineDocumentHighlightsPayload(Arena arena, int line, java.util.List<? extends DocumentHighlight> highlights) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetLineDocumentHighlightsPayloadWire(line, highlights));
        writeSetLineDocumentHighlightsPayloadWire(writer, line, highlights);
        return writer.segment();
    }

    private static void writeSetLineGutterIconsPayloadWire(BinaryWriter writer, int line, java.util.List<? extends GutterIcon> icons) {
        writer.writeInt32(line);
        writeGutterIconList(writer, icons);
    }

    private static int sizeOfSetLineGutterIconsPayloadWire(int line, java.util.List<? extends GutterIcon> icons) {
        int size = 0;
        size += 4;
        size += sizeOfGutterIconList(icons);
        return size;
    }

    public static MemorySegment encodeSetLineGutterIconsPayload(Arena arena, int line, java.util.List<? extends GutterIcon> icons) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetLineGutterIconsPayloadWire(line, icons));
        writeSetLineGutterIconsPayloadWire(writer, line, icons);
        return writer.segment();
    }

    public static MemorySegment encodeSetLineInlayHintsPayload(Arena arena, int line, java.util.List<? extends InlayHint> hints) {
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(line);
        writer.writeInt32(hintsCount);
        for (int hintsIndex = 0; hintsIndex < hintsCount; hintsIndex++) {
            InlayHint hintsItem = hints.get(hintsIndex);
            writer.writeInt32(hintsItem.type.value);
            writer.writeInt32(hintsItem.column);
            writer.writeInt32(hintsItem.intValue);
            writer.writeUtf8Bytes(hintsTextUtf8[hintsIndex]);
        }
        return writer.segment();
    }

    public static MemorySegment encodeSetLineLinksPayload(Arena arena, int line, java.util.List<? extends LinkSpan> links) {
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(line);
        writer.writeInt32(linksCount);
        for (int linksIndex = 0; linksIndex < linksCount; linksIndex++) {
            LinkSpan linksItem = links.get(linksIndex);
            writer.writeInt32(linksItem.column);
            writer.writeInt32(linksItem.length);
            writer.writeUtf8Bytes(linksTargetUtf8[linksIndex]);
        }
        return writer.segment();
    }

    public static MemorySegment encodeSetLinePhantomTextsPayload(Arena arena, int line, java.util.List<? extends PhantomText> phantoms) {
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(line);
        writer.writeInt32(phantomsCount);
        for (int phantomsIndex = 0; phantomsIndex < phantomsCount; phantomsIndex++) {
            PhantomText phantomsItem = phantoms.get(phantomsIndex);
            writer.writeInt32(phantomsItem.column);
            writer.writeUtf8Bytes(phantomsTextUtf8[phantomsIndex]);
        }
        return writer.segment();
    }

    private static void writeSetLineSpansPayloadWire(BinaryWriter writer, int line, SpanLayer layer, java.util.List<? extends StyleSpan> spans) {
        writer.writeInt32(line);
        writer.writeInt32(layer.value);
        writeStyleSpanList(writer, spans);
    }

    private static int sizeOfSetLineSpansPayloadWire(int line, SpanLayer layer, java.util.List<? extends StyleSpan> spans) {
        int size = 0;
        size += 4;
        size += 4;
        size += sizeOfStyleSpanList(spans);
        return size;
    }

    public static MemorySegment encodeSetLineSpansPayload(Arena arena, int line, SpanLayer layer, java.util.List<? extends StyleSpan> spans) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetLineSpansPayloadWire(line, layer, spans));
        writeSetLineSpansPayloadWire(writer, line, layer, spans);
        return writer.segment();
    }

    private static void writeSetSeparatorGuidesPayloadWire(BinaryWriter writer, java.util.List<? extends SeparatorGuide> guides) {
        writeSeparatorGuideList(writer, guides);
    }

    private static int sizeOfSetSeparatorGuidesPayloadWire(java.util.List<? extends SeparatorGuide> guides) {
        int size = 0;
        size += sizeOfSeparatorGuideList(guides);
        return size;
    }

    public static MemorySegment encodeSetSeparatorGuidesPayload(Arena arena, java.util.List<? extends SeparatorGuide> guides) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetSeparatorGuidesPayloadWire(guides));
        writeSetSeparatorGuidesPayloadWire(writer, guides);
        return writer.segment();
    }

    public static MemorySegment encodeEditorOptions(Arena arena, EditorOptions value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfEditorOptions(value));
        writeEditorOptions(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeEditorRangeEffectStyles(Arena arena, EditorRangeEffectStyles value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfEditorRangeEffectStyles(value));
        writeEditorRangeEffectStyles(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeEditorRenderColors(Arena arena, EditorRenderColors value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfEditorRenderColors(value));
        writeEditorRenderColors(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeHandleConfig(Arena arena, HandleConfig value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfHandleConfig(value));
        writeHandleConfig(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeScrollbarConfig(Arena arena, ScrollbarConfig value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfScrollbarConfig(value));
        writeScrollbarConfig(writer, value);
        return writer.segment();
    }

    public static MemorySegment encodeApplyTextEditsPayload(Arena arena, java.util.List<? extends TextEdit> edits) {
        int size = 0;
        int editsCount = edits == null ? 0 : edits.size();
        byte[][] editsNewTextUtf8 = new byte[editsCount][];
        size += 4;
        for (int editsIndex = 0; editsIndex < editsCount; editsIndex++) {
            TextEdit editsItem = edits.get(editsIndex);
            size += sizeOfTextRange(editsItem.range);
            byte[] editsNewTextBytes = utf8Bytes(editsItem.newText);
            editsNewTextUtf8[editsIndex] = editsNewTextBytes;
            size += 4 + editsNewTextBytes.length;
        }
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(editsCount);
        for (int editsIndex = 0; editsIndex < editsCount; editsIndex++) {
            TextEdit editsItem = edits.get(editsIndex);
            writeTextRange(writer, editsItem.range);
            writer.writeUtf8Bytes(editsNewTextUtf8[editsIndex]);
        }
        return writer.segment();
    }

    public static MemorySegment encodeImeCommandMessage(Arena arena, ImeCommandMessage value) {
        int size = 0;
        size += 4;
        size += 8;
        size += 4;
        size += 4;
        size += sizeOfImeOffsetRange(value.range);
        size += sizeOfImeOffsetRange(value.selection);
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        size += 4;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.kind.value);
        writer.writeInt64(value.contextId);
        writer.writeInt32(value.contextRevision);
        writer.writeInt32(value.documentStartOffset);
        writeImeOffsetRange(writer, value.range);
        writeImeOffsetRange(writer, value.selection);
        writer.writeUtf8Bytes(textUtf8);
        writer.writeInt32(value.cursorOffset);
        writer.writeInt32(value.deleteBefore);
        writer.writeInt32(value.deleteAfter);
        writer.writeInt32(value.textUnit.value);
        writer.writeInt32(value.markedRole.value);
        writer.writeInt32(value.scriptClass.value);
        return writer.segment();
    }

    public static MemorySegment encodeImeTextUpdateMessage(Arena arena, ImeTextUpdateMessage value) {
        int size = 0;
        size += 4;
        size += 4;
        size += 8;
        size += 4;
        size += 4;
        byte[] textUtf8 = utf8Bytes(value.text);
        size += 4 + textUtf8.length;
        size += sizeOfImeOffsetRange(value.patch.range);
        byte[] patchTextUtf8 = utf8Bytes(value.patch.text);
        size += 4 + patchTextUtf8.length;
        size += sizeOfImeOffsetRange(value.selection);
        size += sizeOfImeMarkedRange(value.markedRange);
        size += 4;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.kind.value);
        writer.writeInt32(value.scope.value);
        writer.writeInt64(value.contextId);
        writer.writeInt32(value.contextRevision);
        writer.writeInt32(value.documentStartOffset);
        writer.writeUtf8Bytes(textUtf8);
        writeImeOffsetRange(writer, value.patch.range);
        writer.writeUtf8Bytes(patchTextUtf8);
        writeImeOffsetRange(writer, value.selection);
        writeImeMarkedRange(writer, value.markedRange);
        writer.writeInt32(value.scriptClass.value);
        return writer.segment();
    }

    public static MemorySegment encodeGestureEvent(Arena arena, GestureEvent value) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfGestureEvent(value));
        writeGestureEvent(writer, value);
        return writer.segment();
    }

    private static void writeSetKeyMapPayloadWire(BinaryWriter writer, java.util.List<? extends KeyBinding> bindings) {
        writeKeyBindingList(writer, bindings);
    }

    private static int sizeOfSetKeyMapPayloadWire(java.util.List<? extends KeyBinding> bindings) {
        int size = 0;
        size += sizeOfKeyBindingList(bindings);
        return size;
    }

    public static MemorySegment encodeSetKeyMapPayload(Arena arena, java.util.List<? extends KeyBinding> bindings) {
        BinaryWriter writer = new BinaryWriter(arena, sizeOfSetKeyMapPayloadWire(bindings));
        writeSetKeyMapPayloadWire(writer, bindings);
        return writer.segment();
    }

    public static MemorySegment encodeLinkedEditingModel(Arena arena, LinkedEditingModel value) {
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(groupsCount);
        for (int groupsIndex = 0; groupsIndex < groupsCount; groupsIndex++) {
            TabStopGroup groupsItem = value.groups.get(groupsIndex);
            writer.writeInt32(groupsItem.index);
            writeTextRangeList(writer, groupsItem.ranges);
            writer.writeUtf8Bytes(groupsDefaultTextUtf8[groupsIndex]);
        }
        return writer.segment();
    }

    public static MemorySegment encodeStartLinkedEditingPayload(Arena arena, LinkedEditingModel model) {
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
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(modelGroupsCount);
        for (int modelGroupsIndex = 0; modelGroupsIndex < modelGroupsCount; modelGroupsIndex++) {
            TabStopGroup modelGroupsItem = model.groups.get(modelGroupsIndex);
            writer.writeInt32(modelGroupsItem.index);
            writeTextRangeList(writer, modelGroupsItem.ranges);
            writer.writeUtf8Bytes(modelGroupsDefaultTextUtf8[modelGroupsIndex]);
        }
        return writer.segment();
    }

    public static MemorySegment encodeTabStopGroup(Arena arena, TabStopGroup value) {
        int size = 0;
        size += 4;
        size += sizeOfTextRangeList(value.ranges);
        byte[] defaultTextUtf8 = utf8Bytes(value.defaultText);
        size += 4 + defaultTextUtf8.length;
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeInt32(value.index);
        writeTextRangeList(writer, value.ranges);
        writer.writeUtf8Bytes(defaultTextUtf8);
        return writer.segment();
    }

    public static MemorySegment encodeSearchRequest(Arena arena, SearchRequest value) {
        int size = 0;
        byte[] patternUtf8 = utf8Bytes(value.pattern);
        size += 4 + patternUtf8.length;
        size += sizeOfSearchOptions(value.options);
        BinaryWriter writer = new BinaryWriter(arena, size);
        writer.writeUtf8Bytes(patternUtf8);
        writeSearchOptions(writer, value.options);
        return writer.segment();
    }
}
