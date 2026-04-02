package com.qiplat.sweeteditor.core;

import android.util.SparseArray;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyMap;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.BracketGuide;
import com.qiplat.sweeteditor.core.adornment.FlowGuide;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.InlayType;
import com.qiplat.sweeteditor.core.adornment.TextStyle;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.snippet.TabStopGroup;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

public final class ProtocolEncoder {
    private ProtocolEncoder() {
    }

    /**
     * Pack EditorOptions into a direct ByteBuffer for zero-copy JNI transfer.
     * <p>
     * Format (LE): f32 touch_slop, i64 double_tap_timeout, i64 long_press_ms, f32 fling_friction, f32 fling_min_velocity, f32 fling_max_velocity, u64 max_undo_stack_size, i64 key_chord_timeout_ms
     *
     * @param options editor construction options
     * @return packed direct ByteBuffer (48 bytes, flipped)
     */
    public static ByteBuffer packEditorOptions(@NonNull EditorOptions options) {
        // 4 + 8 + 8 + 4 + 4 + 4 + 8 + 8 = 48 bytes
        ByteBuffer payload = ByteBuffer.allocateDirect(48).order(ByteOrder.LITTLE_ENDIAN);
        payload.putFloat(options.touchSlop);
        payload.putLong(options.doubleTapTimeout);
        payload.putLong(options.longPressMs);
        payload.putFloat(options.flingFriction);
        payload.putFloat(options.flingMinVelocity);
        payload.putFloat(options.flingMaxVelocity);
        payload.putLong(options.maxUndoStackSize);
        payload.putLong(options.keyChordTimeoutMs);
        payload.flip();
        return payload;
    }

    static ByteBuffer packLineSpans(int line, int layer, @NonNull int[] columns, @NonNull int[] lengths, @NonNull int[] styleIds) {
        int count = Math.min(columns.length, Math.min(lengths.length, styleIds.length));
        ByteBuffer payload = ByteBuffer.allocateDirect(12 + count * 12).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(layer);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            payload.putInt(columns[i]);
            payload.putInt(lengths[i]);
            payload.putInt(styleIds[i]);
        }
        payload.flip();
        return payload;
    }

    /**
     * Batch encode text style registrations.
     * <p>
     * Format (LE): u32 entry_count,
     * [u32 style_id, i32 color, i32 background_color, i32 font_style] x entry_count
     *
     * @param stylesById style ID -> text style mapping
     * @return packed ByteBuffer, returns null if input is null or empty
     */
    @Nullable
    public static ByteBuffer packBatchTextStyles(@Nullable Map<Integer, TextStyle> stylesById) {
        if (stylesById == null || stylesById.isEmpty()) return null;
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + stylesById.size() * 16)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(stylesById.size());
        for (Map.Entry<Integer, TextStyle> entry : new TreeMap<>(stylesById).entrySet()) {
            TextStyle style = entry.getValue();
            payload.putInt(entry.getKey());
            payload.putInt(style.color);
            payload.putInt(style.backgroundColor);
            payload.putInt(style.fontStyle);
        }
        payload.flip();
        return payload;
    }

    /**
     * Directly accepts List&lt;StyleSpan&gt; and packs into ByteBuffer, avoiding the caller having to unpack into parallel arrays.
     *
     * @param line  line number (0-based)
     * @param layer layer (0=SYNTAX, 1=SEMANTIC)
     * @param spans span list (accepts {@link StyleSpan} and its subclasses, such as {@link StyleSpan})
     * @return packed ByteBuffer
     */
    public static ByteBuffer packLineSpans(int line, int layer, @NonNull List<? extends StyleSpan> spans) {
        int count = spans.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(12 + count * 12).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(layer);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            StyleSpan s = spans.get(i);
            payload.putInt(s.column);
            payload.putInt(s.length);
            payload.putInt(s.styleId);
        }
        payload.flip();
        return payload;
    }

    static ByteBuffer packLineDiagnostics(int line, @NonNull int[] columns, @NonNull int[] lengths, @NonNull int[] severities, @NonNull int[] colors) {
        int count = Math.min(Math.min(columns.length, lengths.length), Math.min(severities.length, colors.length));
        ByteBuffer payload = ByteBuffer.allocateDirect(8 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            payload.putInt(columns[i]);
            payload.putInt(lengths[i]);
            payload.putInt(severities[i]);
            payload.putInt(colors[i]);
        }
        payload.flip();
        return payload;
    }

    /**
     * Directly accepts List&lt;Diagnostic&gt; and packs into ByteBuffer, avoiding the caller having to unpack into parallel arrays.
     *
     * @param line  line number (0-based)
     * @param items diagnostic item list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packLineDiagnostics(int line, @NonNull java.util.List<? extends Diagnostic> items) {
        int count = items.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(8 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            Diagnostic item = items.get(i);
            payload.putInt(item.column);
            payload.putInt(item.length);
            payload.putInt(item.severity);
            payload.putInt(item.color);
        }
        payload.flip();
        return payload;
    }

    static ByteBuffer packFoldRegions(@NonNull int[] startLines, @NonNull int[] endLines) {
        int count = Math.min(startLines.length, endLines.length);
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 8).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            payload.putInt(startLines[i]);
            payload.putInt(endLines[i]);
        }
        payload.flip();
        return payload;
    }

    /**
     * Directly accepts List&lt;FoldRegion&gt; and packs into ByteBuffer, avoiding the caller having to unpack into parallel arrays.
     *
     * @param regions fold region list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packFoldRegions(@NonNull List<? extends FoldRegion> regions) {
        int count = regions.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 8).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            FoldRegion r = regions.get(i);
            payload.putInt(r.startLine);
            payload.putInt(r.endLine);
        }
        payload.flip();
        return payload;
    }

    static ByteBuffer packLinkedEditingModel(@NonNull LinkedEditingModel model) {
        java.util.List<TabStopGroup> groups = model.getGroups();
        int groupCount = groups.size();
        int rangeCount = 0;
        byte[][] groupTexts = new byte[groupCount][];
        int stringBlobSize = 0;
        for (int i = 0; i < groupCount; i++) {
            TabStopGroup group = groups.get(i);
            rangeCount += group.ranges.size();
            if (group.defaultText != null) {
                byte[] bytes = group.defaultText.getBytes(StandardCharsets.UTF_8);
                groupTexts[i] = bytes;
                stringBlobSize += bytes.length;
            }
        }

        ByteBuffer payload = ByteBuffer.allocateDirect(12 + groupCount * 12 + rangeCount * 20 + stringBlobSize)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(groupCount);
        payload.putInt(rangeCount);
        payload.putInt(stringBlobSize);

        int textOffset = 0;
        for (int i = 0; i < groupCount; i++) {
            TabStopGroup group = groups.get(i);
            payload.putInt(group.index);
            byte[] bytes = groupTexts[i];
            if (bytes == null) {
                payload.putInt(0xFFFFFFFF);
                payload.putInt(0);
            } else {
                payload.putInt(textOffset);
                payload.putInt(bytes.length);
                textOffset += bytes.length;
            }
        }

        for (int groupOrdinal = 0; groupOrdinal < groupCount; groupOrdinal++) {
            TabStopGroup group = groups.get(groupOrdinal);
            for (TextRange range : group.ranges) {
                payload.putInt(groupOrdinal);
                payload.putInt(range.start.line);
                payload.putInt(range.start.column);
                payload.putInt(range.end.line);
                payload.putInt(range.end.column);
            }
        }

        for (byte[] bytes : groupTexts) {
            if (bytes != null && bytes.length > 0) {
                payload.put(bytes);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the InlayHint list for a given line into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 line, u32 hint_count,
     * then repeat hint_count times: [u32 type, u32 column, i32 int_value, u32 text_len, u8[text_len] text_utf8]
     *
     * @param line  line number (0-based)
     * @param hints InlayHint list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packLineInlayHints(int line, @NonNull List<? extends InlayHint> hints) {
        int count = hints.size();
        // First calculate total size: header(8) + fixed part per hint(16) + variable-length text
        int totalSize = 8; // line(4) + count(4)
        byte[][] textBytes = new byte[count][];
        for (int i = 0; i < count; i++) {
            InlayHint h = hints.get(i);
            totalSize += 16; // type(4) + column(4) + int_value(4) + text_len(4)
            if (h.type == InlayType.TEXT && h.text != null) {
                byte[] bytes = h.text.getBytes(StandardCharsets.UTF_8);
                textBytes[i] = bytes;
                totalSize += bytes.length;
            }
        }

        ByteBuffer payload = ByteBuffer.allocateDirect(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            InlayHint h = hints.get(i);
            payload.putInt(h.type.value);
            payload.putInt(h.column);
            payload.putInt(h.intValue);
            byte[] tb = textBytes[i];
            if (tb != null) {
                payload.putInt(tb.length);
                payload.put(tb);
            } else {
                payload.putInt(0);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the PhantomText list for a given line into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 line, u32 phantom_count,
     * then repeat phantom_count times: [u32 column, u32 text_len, u8[text_len] text_utf8]
     *
     * @param line     line number (0-based)
     * @param phantoms PhantomText list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packLinePhantomTexts(int line, @NonNull List<? extends PhantomText> phantoms) {
        int count = phantoms.size();
        int totalSize = 8; // line(4) + count(4)
        byte[][] textBytes = new byte[count][];
        for (int i = 0; i < count; i++) {
            PhantomText p = phantoms.get(i);
            totalSize += 8; // column(4) + text_len(4)
            if (p.text != null) {
                byte[] bytes = p.text.getBytes(StandardCharsets.UTF_8);
                textBytes[i] = bytes;
                totalSize += bytes.length;
            }
        }

        ByteBuffer payload = ByteBuffer.allocateDirect(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            PhantomText p = phantoms.get(i);
            payload.putInt(p.column);
            byte[] tb = textBytes[i];
            if (tb != null) {
                payload.putInt(tb.length);
                payload.put(tb);
            } else {
                payload.putInt(0);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the GutterIcon list for a given line into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 line, u32 icon_count,
     * then repeat icon_count times: [i32 icon_id]
     *
     * @param line  line number (0-based)
     * @param icons GutterIcon list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packLineGutterIcons(int line, @NonNull List<? extends GutterIcon> icons) {
        int count = icons.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(8 + count * 4).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            payload.putInt(icons.get(i).iconId);
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the IndentGuide list into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 count, then repeat count times:
     * [u32 start_line, u32 start_column, u32 end_line, u32 end_column]
     *
     * @param guides IndentGuide list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packIndentGuides(@NonNull List<? extends IndentGuide> guides) {
        int count = guides.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            IndentGuide g = guides.get(i);
            payload.putInt(g.start.line);
            payload.putInt(g.start.column);
            payload.putInt(g.end.line);
            payload.putInt(g.end.column);
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the BracketGuide list into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 count, then repeat count times:
     * [u32 parent_line, u32 parent_column, u32 end_line, u32 end_column,
     *  u32 child_count, then repeat child_count times: [u32 child_line, u32 child_column]]
     *
     * @param guides BracketGuide list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packBracketGuides(@NonNull List<? extends BracketGuide> guides) {
        int count = guides.size();
        // Calculate total size: header(4) + at least 20 bytes per guide + children
        int totalSize = 4;
        for (int i = 0; i < count; i++) {
            BracketGuide g = guides.get(i);
            totalSize += 20; // parent(8) + end(8) + child_count(4)
            if (g.children != null) {
                totalSize += g.children.length * 8;
            }
        }

        ByteBuffer payload = ByteBuffer.allocateDirect(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            BracketGuide g = guides.get(i);
            payload.putInt(g.parent.line);
            payload.putInt(g.parent.column);
            payload.putInt(g.end.line);
            payload.putInt(g.end.column);
            if (g.children != null) {
                payload.putInt(g.children.length);
                for (TextPosition child : g.children) {
                    payload.putInt(child.line);
                    payload.putInt(child.column);
                }
            } else {
                payload.putInt(0);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the FlowGuide list into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 count, then repeat count times:
     * [u32 start_line, u32 start_column, u32 end_line, u32 end_column]
     *
     * @param guides FlowGuide list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packFlowGuides(@NonNull List<? extends FlowGuide> guides) {
        int count = guides.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            FlowGuide g = guides.get(i);
            payload.putInt(g.start.line);
            payload.putInt(g.start.column);
            payload.putInt(g.end.line);
            payload.putInt(g.end.column);
        }
        payload.flip();
        return payload;
    }

    /**
     * Pack the SeparatorGuide list into a binary ByteBuffer.
     * <p>
     * Format (LE): u32 count, then repeat count times:
     * [i32 line, i32 style, i32 count, u32 text_end_column]
     *
     * @param guides SeparatorGuide list
     * @return packed ByteBuffer
     */
    public static ByteBuffer packSeparatorGuides(@NonNull List<? extends SeparatorGuide> guides) {
        int count = guides.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            SeparatorGuide g = guides.get(i);
            payload.putInt(g.line);
            payload.putInt(g.style);
            payload.putInt(g.count);
            payload.putInt(g.textEndColumn);
        }
        payload.flip();
        return payload;
    }

    // ==================== Batch encoding methods ====================

    /**
     * Batch encode multiple lines of highlight spans.
     * <p>
     * Format (LE): u32 layer, u32 entry_count,
     * [u32 line, u32 span_count, [u32 column, u32 length, u32 style_id] x span_count] x entry_count
     *
     * @param layer       highlight layer (0=SYNTAX, 1=SEMANTIC)
     * @param spansByLine sparse array of line number -> span list
     * @return packed ByteBuffer, returns null if input is null or empty
     */
    @Nullable
    public static ByteBuffer packBatchLineSpans(int layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine) {
        if (spansByLine == null || spansByLine.size() == 0) return null;
        int entryCount = spansByLine.size();
        int totalSpanCount = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends StyleSpan> spans = spansByLine.valueAt(i);
            if (spans != null) totalSpanCount += spans.size();
        }
        // header: layer(4) + entry_count(4) = 8
        // per entry: line(4) + span_count(4) = 8
        // per span: column(4) + length(4) + style_id(4) = 12
        ByteBuffer payload = ByteBuffer.allocateDirect(8 + entryCount * 8 + totalSpanCount * 12)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(layer);
        payload.putInt(entryCount);
        for (int i = 0; i < entryCount; i++) {
            int line = spansByLine.keyAt(i);
            List<? extends StyleSpan> spans = spansByLine.valueAt(i);
            int spanCount = (spans != null) ? spans.size() : 0;
            payload.putInt(line);
            payload.putInt(spanCount);
            for (int j = 0; j < spanCount; j++) {
                StyleSpan s = spans.get(j);
                payload.putInt(s.column);
                payload.putInt(s.length);
                payload.putInt(s.styleId);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Batch encode multiple lines of Inlay Hints (variable length, two-pass traversal).
     * <p>
     * Format (LE): u32 entry_count,
     * [u32 line, u32 hint_count,
     *  [u32 type, u32 column, i32 int_value, u32 text_len, u8[text_len] text_utf8] x hint_count] x entry_count
     *
     * @param hintsByLine sparse array of line number -> hint list
     * @return packed ByteBuffer, returns null if input is null or empty
     */
    @Nullable
    public static ByteBuffer packBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine) {
        if (hintsByLine == null || hintsByLine.size() == 0) return null;
        int entryCount = hintsByLine.size();
        // First pass: calculate total size and cache text bytes
        int totalSize = 4; // entry_count(4)
        int totalHintCount = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends InlayHint> hints = hintsByLine.valueAt(i);
            int hintCount = (hints != null) ? hints.size() : 0;
            totalHintCount += hintCount;
            totalSize += 8; // line(4) + hint_count(4)
        }
        byte[][] textBytesCache = new byte[totalHintCount][];
        int hintIdx = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends InlayHint> hints = hintsByLine.valueAt(i);
            if (hints == null) continue;
            for (int j = 0; j < hints.size(); j++) {
                InlayHint h = hints.get(j);
                totalSize += 16; // type(4) + column(4) + int_value(4) + text_len(4)
                if (h.type == InlayType.TEXT && h.text != null) {
                    byte[] bytes = h.text.getBytes(StandardCharsets.UTF_8);
                    textBytesCache[hintIdx] = bytes;
                    totalSize += bytes.length;
                }
                hintIdx++;
            }
        }
        // Second pass: single allocation and write
        ByteBuffer payload = ByteBuffer.allocateDirect(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        hintIdx = 0;
        for (int i = 0; i < entryCount; i++) {
            int line = hintsByLine.keyAt(i);
            List<? extends InlayHint> hints = hintsByLine.valueAt(i);
            int hintCount = (hints != null) ? hints.size() : 0;
            payload.putInt(line);
            payload.putInt(hintCount);
            for (int j = 0; j < hintCount; j++) {
                InlayHint h = hints.get(j);
                payload.putInt(h.type.value);
                payload.putInt(h.column);
                payload.putInt(h.intValue);
                byte[] tb = textBytesCache[hintIdx];
                if (tb != null) {
                    payload.putInt(tb.length);
                    payload.put(tb);
                } else {
                    payload.putInt(0);
                }
                hintIdx++;
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Batch encode multiple lines of phantom text (variable length, two-pass traversal).
     * <p>
     * Format (LE): u32 entry_count,
     * [u32 line, u32 phantom_count,
     *  [u32 column, u32 text_len, u8[text_len] text_utf8] x phantom_count] x entry_count
     *
     * @param phantomsByLine sparse array of line number -> phantom list
     * @return packed ByteBuffer, returns null if input is null or empty
     */
    @Nullable
    public static ByteBuffer packBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine) {
        if (phantomsByLine == null || phantomsByLine.size() == 0) return null;
        int entryCount = phantomsByLine.size();
        // First pass: calculate total size and cache text bytes
        int totalSize = 4; // entry_count(4)
        int totalPhantomCount = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends PhantomText> phantoms = phantomsByLine.valueAt(i);
            int phantomCount = (phantoms != null) ? phantoms.size() : 0;
            totalPhantomCount += phantomCount;
            totalSize += 8; // line(4) + phantom_count(4)
        }
        byte[][] textBytesCache = new byte[totalPhantomCount][];
        int phantomIdx = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends PhantomText> phantoms = phantomsByLine.valueAt(i);
            if (phantoms == null) continue;
            for (int j = 0; j < phantoms.size(); j++) {
                PhantomText p = phantoms.get(j);
                totalSize += 8; // column(4) + text_len(4)
                if (p.text != null) {
                    byte[] bytes = p.text.getBytes(StandardCharsets.UTF_8);
                    textBytesCache[phantomIdx] = bytes;
                    totalSize += bytes.length;
                }
                phantomIdx++;
            }
        }
        // Second pass: single allocation and write
        ByteBuffer payload = ByteBuffer.allocateDirect(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        phantomIdx = 0;
        for (int i = 0; i < entryCount; i++) {
            int line = phantomsByLine.keyAt(i);
            List<? extends PhantomText> phantoms = phantomsByLine.valueAt(i);
            int phantomCount = (phantoms != null) ? phantoms.size() : 0;
            payload.putInt(line);
            payload.putInt(phantomCount);
            for (int j = 0; j < phantomCount; j++) {
                PhantomText p = phantoms.get(j);
                payload.putInt(p.column);
                byte[] tb = textBytesCache[phantomIdx];
                if (tb != null) {
                    payload.putInt(tb.length);
                    payload.put(tb);
                } else {
                    payload.putInt(0);
                }
                phantomIdx++;
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Batch encode multiple lines of gutter icons (fixed length).
     * <p>
     * Format (LE): u32 entry_count,
     * [u32 line, u32 icon_count, [i32 icon_id] x icon_count] x entry_count
     *
     * @param iconsByLine sparse array of line number -> icon list
     * @return packed ByteBuffer, returns null if input is null or empty
     */
    @Nullable
    public static ByteBuffer packBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine) {
        if (iconsByLine == null || iconsByLine.size() == 0) return null;
        int entryCount = iconsByLine.size();
        int totalIconCount = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends GutterIcon> icons = iconsByLine.valueAt(i);
            if (icons != null) totalIconCount += icons.size();
        }
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + entryCount * 8 + totalIconCount * 4)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        for (int i = 0; i < entryCount; i++) {
            int line = iconsByLine.keyAt(i);
            List<? extends GutterIcon> icons = iconsByLine.valueAt(i);
            int iconCount = (icons != null) ? icons.size() : 0;
            payload.putInt(line);
            payload.putInt(iconCount);
            for (int j = 0; j < iconCount; j++) {
                payload.putInt(icons.get(j).iconId);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Batch encode multiple lines of diagnostic decorations (fixed length).
     * <p>
     * Format (LE): u32 entry_count,
     * [u32 line, u32 diag_count, [u32 column, u32 length, i32 severity, i32 color] x diag_count] x entry_count
     *
     * @param diagsByLine sparse array of line number -> diagnostic list
     * @return packed ByteBuffer, returns null if input is null or empty
     */
    @Nullable
    public static ByteBuffer packBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> diagsByLine) {
        if (diagsByLine == null || diagsByLine.size() == 0) return null;
        int entryCount = diagsByLine.size();
        int totalDiagCount = 0;
        for (int i = 0; i < entryCount; i++) {
            List<? extends Diagnostic> diags = diagsByLine.valueAt(i);
            if (diags != null) totalDiagCount += diags.size();
        }
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + entryCount * 8 + totalDiagCount * 16)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        for (int i = 0; i < entryCount; i++) {
            int line = diagsByLine.keyAt(i);
            List<? extends Diagnostic> diags = diagsByLine.valueAt(i);
            int diagCount = (diags != null) ? diags.size() : 0;
            payload.putInt(line);
            payload.putInt(diagCount);
            for (int j = 0; j < diagCount; j++) {
                Diagnostic item = diags.get(j);
                payload.putInt(item.column);
                payload.putInt(item.length);
                payload.putInt(item.severity);
                payload.putInt(item.color);
            }
        }
        payload.flip();
        return payload;
    }

    /**
     * Encode key bindings into binary payload for editor_set_keymap C API.
     * Format: u32 count + repeat [u16 firstKey, u8 firstMods, u16 secondKey, u8 secondMods, u32 command]
     */
    public static ByteBuffer packKeyMap(List<KeyBinding> bindings) {
        int count = (bindings != null) ? bindings.size() : 0;
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 10)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            KeyBinding b = bindings.get(i);
            payload.put((byte) b.first.modifiers);
            payload.putShort((short) b.first.keyCode);
            payload.put((byte) b.second.modifiers);
            payload.putShort((short) b.second.keyCode);
            payload.putInt(b.command);
        }
        payload.flip();
        return payload;
    }

    /**
     * Encode all bindings from a {@link KeyMap} into binary payload for editor_set_keymap C API.
     */
    public static ByteBuffer packKeyMap(@NonNull KeyMap keyMap) {
        Map<KeyBinding, Integer> bindings = keyMap.getBindings();
        int count = bindings.size();
        ByteBuffer payload = ByteBuffer.allocateDirect(4 + count * 10)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (Map.Entry<KeyBinding, Integer> entry : bindings.entrySet()) {
            KeyBinding b = entry.getKey();
            payload.put((byte) b.first.modifiers);
            payload.putShort((short) b.first.keyCode);
            payload.put((byte) (b.second != null ? b.second.modifiers : 0));
            payload.putShort((short) (b.second != null ? b.second.keyCode : 0));
            payload.putInt(entry.getValue());
        }
        payload.flip();
        return payload;
    }
}
