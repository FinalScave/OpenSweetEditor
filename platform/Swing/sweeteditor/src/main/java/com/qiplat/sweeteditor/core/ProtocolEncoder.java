package com.qiplat.sweeteditor.core;

import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.snippet.LinkedEditingModel;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;

final class ProtocolEncoder {
    private ProtocolEncoder() {
    }

    // ==================== Highlight Spans ====================

    static byte[] packBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles) {
        if (textStyles == null || textStyles.isEmpty()) return null;
        validateBatchTextStyles(textStyles);
        int entryCount = textStyles.size();
        ByteBuffer payload = ByteBuffer.allocate(4 + entryCount * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        var sortedEntries = textStyles.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList();
        for (var entry : sortedEntries) {
            TextStyle textStyle = entry.getValue();
            payload.putInt(entry.getKey());
            payload.putInt(textStyle.color);
            payload.putInt(textStyle.backgroundColor);
            payload.putInt(textStyle.fontStyle);
        }
        return payload.array();
    }

    private static void validateBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles) {
        for (var entry : textStyles.entrySet()) {
            if (entry.getKey() == null) {
                throw new IllegalArgumentException("textStyles contains null styleId");
            }
            if (entry.getValue() == null) {
                throw new IllegalArgumentException("textStyles contains null TextStyle for styleId=" + entry.getKey());
            }
        }
    }

    static byte[] packLineSpans(int line, int layer, List<? extends StyleSpan> spans) {
        int count = spans.size();
        ByteBuffer payload = ByteBuffer.allocate(12 + count * 12).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(layer);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            StyleSpan s = spans.get(i);
            payload.putInt(s.column);
            payload.putInt(s.length);
            payload.putInt(s.styleId);
        }
        return payload.array();
    }

    static byte[] packBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine) {
        if (spansByLine == null || spansByLine.isEmpty()) return null;
        int entryCount = spansByLine.size();
        int totalSpanCount = 0;
        for (var entry : spansByLine.entrySet()) {
            if (entry.getValue() != null) totalSpanCount += entry.getValue().size();
        }
        ByteBuffer payload = ByteBuffer.allocate(8 + entryCount * 8 + totalSpanCount * 12)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(layer);
        payload.putInt(entryCount);
        // Sort by line number to ensure stable output
        var sortedEntries = spansByLine.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList();
        for (var entry : sortedEntries) {
            int line = entry.getKey();
            List<? extends StyleSpan> spans = entry.getValue();
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
        return payload.array();
    }

    // ==================== Diagnostics ====================

    static byte[] packLineDiagnostics(int line, List<? extends DiagnosticItem> items) {
        int count = items.size();
        ByteBuffer payload = ByteBuffer.allocate(8 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            DiagnosticItem item = items.get(i);
            payload.putInt(item.column);
            payload.putInt(item.length);
            payload.putInt(item.severity);
            payload.putInt(item.color);
        }
        return payload.array();
    }

    static byte[] packBatchLineDiagnostics(Map<Integer, ? extends List<? extends DiagnosticItem>> diagsByLine) {
        if (diagsByLine == null || diagsByLine.isEmpty()) return null;
        int entryCount = diagsByLine.size();
        int totalDiagCount = 0;
        for (var entry : diagsByLine.entrySet()) {
            if (entry.getValue() != null) totalDiagCount += entry.getValue().size();
        }
        ByteBuffer payload = ByteBuffer.allocate(4 + entryCount * 8 + totalDiagCount * 16)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        var sortedEntries = diagsByLine.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList();
        for (var entry : sortedEntries) {
            int line = entry.getKey();
            List<? extends DiagnosticItem> diags = entry.getValue();
            int diagCount = (diags != null) ? diags.size() : 0;
            payload.putInt(line);
            payload.putInt(diagCount);
            for (int j = 0; j < diagCount; j++) {
                DiagnosticItem item = diags.get(j);
                payload.putInt(item.column);
                payload.putInt(item.length);
                payload.putInt(item.severity);
                payload.putInt(item.color);
            }
        }
        return payload.array();
    }

    // ==================== Fold Regions ====================

    static byte[] packFoldRegions(List<? extends FoldRegion> regions) {
        int count = regions.size();
        ByteBuffer payload = ByteBuffer.allocate(4 + count * 8).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            FoldRegion r = regions.get(i);
            payload.putInt(r.startLine);
            payload.putInt(r.endLine);
        }
        return payload.array();
    }

    // ==================== InlayHint ====================

    static byte[] packLineInlayHints(int line, List<? extends InlayHint> hints) {
        int count = hints.size();
        int totalSize = 8;
        byte[][] textBytes = new byte[count][];
        for (int i = 0; i < count; i++) {
            InlayHint h = hints.get(i);
            totalSize += 16;
            if (h.type == InlayType.TEXT && h.text != null) {
                byte[] bytes = h.text.getBytes(StandardCharsets.UTF_8);
                textBytes[i] = bytes;
                totalSize += bytes.length;
            }
        }
        ByteBuffer payload = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN);
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
        return payload.array();
    }

    static byte[] packBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine) {
        if (hintsByLine == null || hintsByLine.isEmpty()) return null;
        int entryCount = hintsByLine.size();
        int totalSize = 4;
        int totalHintCount = 0;
        for (var entry : hintsByLine.entrySet()) {
            List<? extends InlayHint> hints = entry.getValue();
            int hintCount = (hints != null) ? hints.size() : 0;
            totalHintCount += hintCount;
            totalSize += 8;
        }
        byte[][] textBytesCache = new byte[totalHintCount][];
        int hintIdx = 0;
        var sortedEntries = hintsByLine.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList();
        for (var entry : sortedEntries) {
            List<? extends InlayHint> hints = entry.getValue();
            if (hints == null) continue;
            for (int j = 0; j < hints.size(); j++) {
                InlayHint h = hints.get(j);
                totalSize += 16;
                if (h.type == InlayType.TEXT && h.text != null) {
                    byte[] bytes = h.text.getBytes(StandardCharsets.UTF_8);
                    textBytesCache[hintIdx] = bytes;
                    totalSize += bytes.length;
                }
                hintIdx++;
            }
        }
        ByteBuffer payload = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        hintIdx = 0;
        for (var entry : sortedEntries) {
            int line = entry.getKey();
            List<? extends InlayHint> hints = entry.getValue();
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
        return payload.array();
    }

    // ==================== PhantomText ====================

    static byte[] packLinePhantomTexts(int line, List<? extends PhantomText> phantoms) {
        int count = phantoms.size();
        int totalSize = 8;
        byte[][] textBytes = new byte[count][];
        for (int i = 0; i < count; i++) {
            PhantomText p = phantoms.get(i);
            totalSize += 8;
            if (p.text != null) {
                byte[] bytes = p.text.getBytes(StandardCharsets.UTF_8);
                textBytes[i] = bytes;
                totalSize += bytes.length;
            }
        }
        ByteBuffer payload = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN);
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
        return payload.array();
    }

    static byte[] packBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine) {
        if (phantomsByLine == null || phantomsByLine.isEmpty()) return null;
        int entryCount = phantomsByLine.size();
        int totalSize = 4;
        int totalPhantomCount = 0;
        for (var entry : phantomsByLine.entrySet()) {
            List<? extends PhantomText> phantoms = entry.getValue();
            int phantomCount = (phantoms != null) ? phantoms.size() : 0;
            totalPhantomCount += phantomCount;
            totalSize += 8;
        }
        byte[][] textBytesCache = new byte[totalPhantomCount][];
        int phantomIdx = 0;
        var sortedEntries = phantomsByLine.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList();
        for (var entry : sortedEntries) {
            List<? extends PhantomText> phantoms = entry.getValue();
            if (phantoms == null) continue;
            for (int j = 0; j < phantoms.size(); j++) {
                PhantomText p = phantoms.get(j);
                totalSize += 8;
                if (p.text != null) {
                    byte[] bytes = p.text.getBytes(StandardCharsets.UTF_8);
                    textBytesCache[phantomIdx] = bytes;
                    totalSize += bytes.length;
                }
                phantomIdx++;
            }
        }
        ByteBuffer payload = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        phantomIdx = 0;
        for (var entry : sortedEntries) {
            int line = entry.getKey();
            List<? extends PhantomText> phantoms = entry.getValue();
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
        return payload.array();
    }

    // ==================== GutterIcon ====================

    static byte[] packLineGutterIcons(int line, List<? extends GutterIcon> icons) {
        int count = icons.size();
        ByteBuffer payload = ByteBuffer.allocate(8 + count * 4).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(line);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            payload.putInt(icons.get(i).iconId);
        }
        return payload.array();
    }

    static byte[] packBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine) {
        if (iconsByLine == null || iconsByLine.isEmpty()) return null;
        int entryCount = iconsByLine.size();
        int totalIconCount = 0;
        for (var entry : iconsByLine.entrySet()) {
            if (entry.getValue() != null) totalIconCount += entry.getValue().size();
        }
        ByteBuffer payload = ByteBuffer.allocate(4 + entryCount * 8 + totalIconCount * 4)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(entryCount);
        var sortedEntries = iconsByLine.entrySet().stream()
                .sorted(Map.Entry.comparingByKey()).toList();
        for (var entry : sortedEntries) {
            int line = entry.getKey();
            List<? extends GutterIcon> icons = entry.getValue();
            int iconCount = (icons != null) ? icons.size() : 0;
            payload.putInt(line);
            payload.putInt(iconCount);
            for (int j = 0; j < iconCount; j++) {
                payload.putInt(icons.get(j).iconId);
            }
        }
        return payload.array();
    }

    // ==================== Guide ====================

    static byte[] packIndentGuides(List<? extends IndentGuide> guides) {
        int count = guides.size();
        ByteBuffer payload = ByteBuffer.allocate(4 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            IndentGuide g = guides.get(i);
            payload.putInt(g.start.line);
            payload.putInt(g.start.column);
            payload.putInt(g.end.line);
            payload.putInt(g.end.column);
        }
        return payload.array();
    }

    static byte[] packBracketGuides(List<? extends BracketGuide> guides) {
        int count = guides.size();
        int totalSize = 4;
        for (int i = 0; i < count; i++) {
            BracketGuide g = guides.get(i);
            totalSize += 20;
            if (g.children != null) {
                totalSize += g.children.length * 8;
            }
        }
        ByteBuffer payload = ByteBuffer.allocate(totalSize).order(ByteOrder.LITTLE_ENDIAN);
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
        return payload.array();
    }

    static byte[] packFlowGuides(List<? extends FlowGuide> guides) {
        int count = guides.size();
        ByteBuffer payload = ByteBuffer.allocate(4 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            FlowGuide g = guides.get(i);
            payload.putInt(g.start.line);
            payload.putInt(g.start.column);
            payload.putInt(g.end.line);
            payload.putInt(g.end.column);
        }
        return payload.array();
    }

    static byte[] packSeparatorGuides(List<? extends SeparatorGuide> guides) {
        int count = guides.size();
        ByteBuffer payload = ByteBuffer.allocate(4 + count * 16).order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(count);
        for (int i = 0; i < count; i++) {
            SeparatorGuide g = guides.get(i);
            payload.putInt(g.line);
            payload.putInt(g.style);
            payload.putInt(g.count);
            payload.putInt(g.textEndColumn);
        }
        return payload.array();
    }

    // ==================== EditorOptions ====================

    /** Size of the EditorOptions binary payload in bytes */
    static final int EDITOR_OPTIONS_SIZE = 40; // 4 + 8 + 8 + 4 + 4 + 4 + 8

    /**
     * Pack EditorOptions directly into a MemorySegment (zero-copy path for Panama FFI).
     * <p>
     * Format (LE): f32 touch_slop, i64 double_tap_timeout, i64 long_press_ms, f32 fling_friction, f32 fling_min_velocity, f32 fling_max_velocity, u64 max_undo_stack_size
     *
     * @param options editor construction options
     * @param arena   arena to allocate the MemorySegment from
     * @return packed MemorySegment (40 bytes)
     */
    static MemorySegment packEditorOptions(EditorOptions options, Arena arena) {
        MemorySegment seg = arena.allocate(EDITOR_OPTIONS_SIZE);
        seg.set(ValueLayout.JAVA_FLOAT_UNALIGNED, 0, options.touchSlop);
        seg.set(ValueLayout.JAVA_LONG_UNALIGNED, 4, options.doubleTapTimeout);
        seg.set(ValueLayout.JAVA_LONG_UNALIGNED, 12, options.longPressMs);
        seg.set(ValueLayout.JAVA_FLOAT_UNALIGNED, 20, options.flingFriction);
        seg.set(ValueLayout.JAVA_FLOAT_UNALIGNED, 24, options.flingMinVelocity);
        seg.set(ValueLayout.JAVA_FLOAT_UNALIGNED, 28, options.flingMaxVelocity);
        seg.set(ValueLayout.JAVA_LONG_UNALIGNED, 32, options.maxUndoStackSize);
        return seg;
    }

    // ==================== LinkedEditing ====================

    static byte[] packLinkedEditingModel(LinkedEditingModel model) {
        java.util.List<LinkedEditingModel.TabStopGroup> groups = model.getGroups();
        int groupCount = groups.size();
        int rangeCount = 0;
        byte[][] groupTexts = new byte[groupCount][];
        int stringBlobSize = 0;
        for (int i = 0; i < groupCount; i++) {
            LinkedEditingModel.TabStopGroup group = groups.get(i);
            rangeCount += group.ranges.size();
            if (group.defaultText != null) {
                byte[] bytes = group.defaultText.getBytes(StandardCharsets.UTF_8);
                groupTexts[i] = bytes;
                stringBlobSize += bytes.length;
            }
        }

        ByteBuffer payload = ByteBuffer.allocate(12 + groupCount * 12 + rangeCount * 20 + stringBlobSize)
                .order(ByteOrder.LITTLE_ENDIAN);
        payload.putInt(groupCount);
        payload.putInt(rangeCount);
        payload.putInt(stringBlobSize);

        int textOffset = 0;
        for (int i = 0; i < groupCount; i++) {
            LinkedEditingModel.TabStopGroup group = groups.get(i);
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
            LinkedEditingModel.TabStopGroup group = groups.get(groupOrdinal);
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
        return payload.array();
    }
}
