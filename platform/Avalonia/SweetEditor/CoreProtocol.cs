#nullable enable
using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.Text;

namespace SweetEditor {

    public static class CoreProtocol {
        private ref struct BinaryReader {
            private readonly ReadOnlySpan<byte> data;
            private int offset;

            public BinaryReader(ReadOnlySpan<byte> data) {
                this.data = data;
                offset = 0;
            }

            public int Remaining => data.Length - offset;

            public int ReadUInt8() {
                return data[offset++];
            }

            public int ReadUInt16() {
                var value = BinaryPrimitives.ReadUInt16LittleEndian(data.Slice(offset));
                offset += 2;
                return value;
            }

            public int ReadInt32() {
                var value = BinaryPrimitives.ReadInt32LittleEndian(data.Slice(offset));
                offset += 4;
                return value;
            }

            public long ReadInt64() {
                var value = BinaryPrimitives.ReadInt64LittleEndian(data.Slice(offset));
                offset += 8;
                return value;
            }

            public float ReadFloat32() {
                return BitConverter.Int32BitsToSingle(ReadInt32());
            }

            public double ReadFloat64() {
                return BitConverter.Int64BitsToDouble(ReadInt64());
            }

            public bool ReadBoolI32() {
                return ReadInt32() != 0;
            }

            public bool ReadBoolUInt8() {
                return ReadUInt8() != 0;
            }

            public ReadOnlySpan<byte> ReadBytes(int length) {
                var value = data.Slice(offset, length);
                offset += length;
                return value;
            }
        }

        private static T ReadEnum<T>(ref BinaryReader reader) where T : struct, Enum {
            var value = reader.ReadInt32();
            if (!Enum.IsDefined(typeof(T), value)) {
                throw new ArgumentOutOfRangeException(nameof(value), value, $"Unknown {typeof(T).Name} value");
            }
            return (T)Enum.ToObject(typeof(T), value);
        }

        private sealed class BinaryWriter {
            private readonly byte[] data;
            private int offset;

            public BinaryWriter(int size) {
                data = new byte[size];
                offset = 0;
            }

            public byte[] ToArray() {
                return data;
            }

            public void WriteUInt8(int value) {
                data[offset++] = unchecked((byte)value);
            }

            public void WriteUInt16(int value) {
                BinaryPrimitives.WriteUInt16LittleEndian(data.AsSpan(offset), unchecked((ushort)value));
                offset += 2;
            }

            public void WriteInt32(int value) {
                BinaryPrimitives.WriteInt32LittleEndian(data.AsSpan(offset), value);
                offset += 4;
            }

            public void WriteInt64(long value) {
                BinaryPrimitives.WriteInt64LittleEndian(data.AsSpan(offset), value);
                offset += 8;
            }

            public void WriteFloat32(float value) {
                WriteInt32(BitConverter.SingleToInt32Bits(value));
            }

            public void WriteFloat64(double value) {
                WriteInt64(BitConverter.DoubleToInt64Bits(value));
            }

            public void WriteBoolI32(bool value) {
                WriteInt32(value ? 1 : 0);
            }

            public void WriteBoolUInt8(bool value) {
                WriteUInt8(value ? 1 : 0);
            }

            public void WriteBytes(ReadOnlySpan<byte> bytes) {
                bytes.CopyTo(data.AsSpan(offset));
                offset += bytes.Length;
            }
        }

        private static string ReadUtf8String(ref BinaryReader reader) {
            var length = reader.ReadInt32();
            if (length < 0 || length > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            if (length == 0) return string.Empty;
            return Encoding.UTF8.GetString(reader.ReadBytes(length));
        }

        private static void WriteUtf8String(BinaryWriter writer, string? value) {
            var bytes = value == null ? Array.Empty<byte>() : Encoding.UTF8.GetBytes(value);
            writer.WriteInt32(bytes.Length);
            writer.WriteBytes(bytes);
        }

        private static int SizeOfUtf8String(string? value) {
            return 4 + (value == null ? 0 : Encoding.UTF8.GetByteCount(value));
        }

        public static byte[] EncodeUtf8String(string? value) {
            var writer = new BinaryWriter(SizeOfUtf8String(value));
            WriteUtf8String(writer, value);
            return writer.ToArray();
        }

        private static void WriteBracketGuideList(BinaryWriter writer, IReadOnlyList<BracketGuide>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteBracketGuide(writer, values![i]);
            }
        }

        private static int SizeOfBracketGuideList(IReadOnlyList<BracketGuide>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfBracketGuide(values[i]);
                }
            }
            return size;
        }

        private static void WriteCodeLensItemList(BinaryWriter writer, IReadOnlyList<CodeLensItem>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteCodeLensItem(writer, values![i]);
            }
        }

        private static int SizeOfCodeLensItemList(IReadOnlyList<CodeLensItem>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfCodeLensItem(values[i]);
                }
            }
            return size;
        }

        private static void WriteDiagnosticList(BinaryWriter writer, IReadOnlyList<Diagnostic>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteDiagnostic(writer, values![i]);
            }
        }

        private static int SizeOfDiagnosticList(IReadOnlyList<Diagnostic>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfDiagnostic(values[i]);
                }
            }
            return size;
        }

        private static void WriteDocumentHighlightList(BinaryWriter writer, IReadOnlyList<DocumentHighlight>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteDocumentHighlight(writer, values![i]);
            }
        }

        private static int SizeOfDocumentHighlightList(IReadOnlyList<DocumentHighlight>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfDocumentHighlight(values[i]);
                }
            }
            return size;
        }

        private static void WriteFlowGuideList(BinaryWriter writer, IReadOnlyList<FlowGuide>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteFlowGuide(writer, values![i]);
            }
        }

        private static int SizeOfFlowGuideList(IReadOnlyList<FlowGuide>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfFlowGuide(values[i]);
                }
            }
            return size;
        }

        private static List<FoldMarkerRenderItem> ReadFoldMarkerRenderItemList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<FoldMarkerRenderItem>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadFoldMarkerRenderItem(ref reader));
            }
            return values;
        }

        private static void WriteFoldRegionList(BinaryWriter writer, IReadOnlyList<FoldRegion>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteFoldRegion(writer, values![i]);
            }
        }

        private static int SizeOfFoldRegionList(IReadOnlyList<FoldRegion>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfFoldRegion(values[i]);
                }
            }
            return size;
        }

        private static List<GuideSegment> ReadGuideSegmentList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<GuideSegment>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadGuideSegment(ref reader));
            }
            return values;
        }

        private static void WriteGutterIconList(BinaryWriter writer, IReadOnlyList<GutterIcon>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteGutterIcon(writer, values![i]);
            }
        }

        private static int SizeOfGutterIconList(IReadOnlyList<GutterIcon>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfGutterIcon(values[i]);
                }
            }
            return size;
        }

        private static List<GutterIconRenderItem> ReadGutterIconRenderItemList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<GutterIconRenderItem>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadGutterIconRenderItem(ref reader));
            }
            return values;
        }

        private static void WriteImeCommandList(BinaryWriter writer, IReadOnlyList<ImeCommand>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteImeCommand(writer, values![i]);
            }
        }

        private static int SizeOfImeCommandList(IReadOnlyList<ImeCommand>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfImeCommand(values[i]);
                }
            }
            return size;
        }

        private static void WriteImeTextUpdateStepList(BinaryWriter writer, IReadOnlyList<ImeTextUpdateStep>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteImeTextUpdateStep(writer, values![i]);
            }
        }

        private static int SizeOfImeTextUpdateStepList(IReadOnlyList<ImeTextUpdateStep>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfImeTextUpdateStep(values[i]);
                }
            }
            return size;
        }

        private static void WriteIndentGuideList(BinaryWriter writer, IReadOnlyList<IndentGuide>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteIndentGuide(writer, values![i]);
            }
        }

        private static int SizeOfIndentGuideList(IReadOnlyList<IndentGuide>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfIndentGuide(values[i]);
                }
            }
            return size;
        }

        private static void WriteInlayHintList(BinaryWriter writer, IReadOnlyList<InlayHint>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteInlayHint(writer, values![i]);
            }
        }

        private static int SizeOfInlayHintList(IReadOnlyList<InlayHint>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfInlayHint(values[i]);
                }
            }
            return size;
        }

        private static List<KeyBinding> ReadKeyBindingList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<KeyBinding>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadKeyBinding(ref reader));
            }
            return values;
        }

        private static void WriteKeyBindingList(BinaryWriter writer, IReadOnlyList<KeyBinding>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteKeyBinding(writer, values![i]);
            }
        }

        private static int SizeOfKeyBindingList(IReadOnlyList<KeyBinding>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfKeyBinding(values[i]);
                }
            }
            return size;
        }

        private static void WriteLinkSpanList(BinaryWriter writer, IReadOnlyList<LinkSpan>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteLinkSpan(writer, values![i]);
            }
        }

        private static int SizeOfLinkSpanList(IReadOnlyList<LinkSpan>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfLinkSpan(values[i]);
                }
            }
            return size;
        }

        private static void WritePhantomTextList(BinaryWriter writer, IReadOnlyList<PhantomText>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WritePhantomText(writer, values![i]);
            }
        }

        private static int SizeOfPhantomTextList(IReadOnlyList<PhantomText>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfPhantomText(values[i]);
                }
            }
            return size;
        }

        private static List<PointF> ReadPointFList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<PointF>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadPointF(ref reader));
            }
            return values;
        }

        private static void WritePointFList(BinaryWriter writer, IReadOnlyList<PointF>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WritePointF(writer, values![i]);
            }
        }

        private static int SizeOfPointFList(IReadOnlyList<PointF>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfPointF(values[i]);
                }
            }
            return size;
        }

        private static List<RangeEffectRenderItem> ReadRangeEffectRenderItemList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<RangeEffectRenderItem>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadRangeEffectRenderItem(ref reader));
            }
            return values;
        }

        private static void WriteSeparatorGuideList(BinaryWriter writer, IReadOnlyList<SeparatorGuide>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteSeparatorGuide(writer, values![i]);
            }
        }

        private static int SizeOfSeparatorGuideList(IReadOnlyList<SeparatorGuide>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfSeparatorGuide(values[i]);
                }
            }
            return size;
        }

        private static List<StyleSpan> ReadStyleSpanList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<StyleSpan>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadStyleSpan(ref reader));
            }
            return values;
        }

        private static void WriteStyleSpanList(BinaryWriter writer, IReadOnlyList<StyleSpan>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteStyleSpan(writer, values![i]);
            }
        }

        private static int SizeOfStyleSpanList(IReadOnlyList<StyleSpan>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfStyleSpan(values[i]);
                }
            }
            return size;
        }

        private static void WriteTabStopGroupList(BinaryWriter writer, IReadOnlyList<TabStopGroup>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteTabStopGroup(writer, values![i]);
            }
        }

        private static int SizeOfTabStopGroupList(IReadOnlyList<TabStopGroup>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfTabStopGroup(values[i]);
                }
            }
            return size;
        }

        private static List<TextChange> ReadTextChangeList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<TextChange>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadTextChange(ref reader));
            }
            return values;
        }

        private static List<TextEdit> ReadTextEditList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<TextEdit>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadTextEdit(ref reader));
            }
            return values;
        }

        private static void WriteTextEditList(BinaryWriter writer, IReadOnlyList<TextEdit>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteTextEdit(writer, values![i]);
            }
        }

        private static int SizeOfTextEditList(IReadOnlyList<TextEdit>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfTextEdit(values[i]);
                }
            }
            return size;
        }

        private static List<TextPosition> ReadTextPositionList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<TextPosition>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadTextPosition(ref reader));
            }
            return values;
        }

        private static void WriteTextPositionList(BinaryWriter writer, IReadOnlyList<TextPosition>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteTextPosition(writer, values![i]);
            }
        }

        private static int SizeOfTextPositionList(IReadOnlyList<TextPosition>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfTextPosition(values[i]);
                }
            }
            return size;
        }

        private static List<TextRange> ReadTextRangeList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<TextRange>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadTextRange(ref reader));
            }
            return values;
        }

        private static void WriteTextRangeList(BinaryWriter writer, IReadOnlyList<TextRange>? values) {
            var count = values == null ? 0 : values.Count;
            writer.WriteInt32(count);
            for (var i = 0; i < count; i++) {
                WriteTextRange(writer, values![i]);
            }
        }

        private static int SizeOfTextRangeList(IReadOnlyList<TextRange>? values) {
            var size = 4;
            if (values != null) {
                for (var i = 0; i < values.Count; i++) {
                    size += SizeOfTextRange(values[i]);
                }
            }
            return size;
        }

        private static List<VisualLine> ReadVisualLineList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<VisualLine>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadVisualLine(ref reader));
            }
            return values;
        }

        private static List<VisualRun> ReadVisualRunList(ref BinaryReader reader) {
            var count = reader.ReadInt32();
            if (count < 0 || count > reader.Remaining) throw new InvalidOperationException("Invalid protocol length.");
            var values = new List<VisualRun>(count);
            for (var i = 0; i < count; i++) {
                values.Add(ReadVisualRun(ref reader));
            }
            return values;
        }

        private static EditorActionResult ReadEditorActionResult(ref BinaryReader reader) {
            return new EditorActionResult {
                Handled = reader.ReadBoolI32(),
                NeedsRedraw = reader.ReadBoolI32(),
                Source = ReadEnum<EditorActionSource>(ref reader),
                TextChangeKind = ReadEnum<TextChangeKind>(ref reader),
                CursorChanged = reader.ReadBoolI32(),
                SelectionChanged = reader.ReadBoolI32(),
                ScrollChanged = reader.ReadBoolI32(),
                ScaleChanged = reader.ReadBoolI32(),
                PointerCursorChanged = reader.ReadBoolI32(),
                CompositionChanged = reader.ReadBoolI32(),
                DecorationChanged = reader.ReadBoolI32(),
                AnimationFlags = reader.ReadInt32(),
                NextAnimationDelayMs = reader.ReadInt32(),
                InteractionFlags = reader.ReadInt32(),
                TextChanges = ReadTextChangeList(ref reader),
                CursorBefore = ReadTextPosition(ref reader),
                CursorAfter = ReadTextPosition(ref reader),
                HasSelectionBefore = reader.ReadBoolI32(),
                HasSelectionAfter = reader.ReadBoolI32(),
                SelectionBefore = ReadTextRange(ref reader),
                SelectionAfter = ReadTextRange(ref reader),
                ScrollXBefore = reader.ReadFloat32(),
                ScrollYBefore = reader.ReadFloat32(),
                ScrollXAfter = reader.ReadFloat32(),
                ScrollYAfter = reader.ReadFloat32(),
                ScaleBefore = reader.ReadFloat32(),
                ScaleAfter = reader.ReadFloat32(),
                PointerCursorBefore = ReadEnum<PointerCursorType>(ref reader),
                PointerCursorAfter = ReadEnum<PointerCursorType>(ref reader),
                ImeHostAction = ReadEnum<ImeHostAction>(ref reader),
                ImeState = ReadImeState(ref reader),
                GestureType = ReadEnum<GestureType>(ref reader),
                GestureEventType = ReadEnum<EventType>(ref reader),
                TapPoint = ReadPointF(ref reader),
                HitTarget = ReadHitTarget(ref reader),
                Modifiers = reader.ReadInt32(),
                Command = reader.ReadInt32(),
            };
        }

        public static EditorActionResult DecodeEditorActionResult(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadEditorActionResult(ref reader);
        }

        private static void WriteBracketGuide(BinaryWriter writer, BracketGuide value) {
            WriteTextPosition(writer, value.Parent);
            WriteTextPosition(writer, value.End);
            WriteTextPositionList(writer, value.Children);
        }

        private static int SizeOfBracketGuide(BracketGuide value) {
            var size = 0;
            size += SizeOfTextPosition(value.Parent);
            size += SizeOfTextPosition(value.End);
            size += SizeOfTextPositionList(value.Children);
            return size;
        }

        private static void WriteCodeLensItem(BinaryWriter writer, CodeLensItem value) {
            writer.WriteInt32(value.Column);
            writer.WriteInt32(value.CommandId);
            WriteUtf8String(writer, value.Text);
        }

        private static int SizeOfCodeLensItem(CodeLensItem value) {
            var size = 0;
            size += 4;
            size += 4;
            size += SizeOfUtf8String(value.Text);
            return size;
        }

        private static void WriteDiagnostic(BinaryWriter writer, Diagnostic value) {
            writer.WriteInt32(value.Column);
            writer.WriteInt32(value.Length);
            writer.WriteInt32((int)value.Severity);
        }

        private static int SizeOfDiagnostic(Diagnostic value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteDocumentHighlight(BinaryWriter writer, DocumentHighlight value) {
            writer.WriteInt32(value.Column);
            writer.WriteInt32(value.Length);
            writer.WriteInt32((int)value.Kind);
        }

        private static int SizeOfDocumentHighlight(DocumentHighlight value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteFlowGuide(BinaryWriter writer, FlowGuide value) {
            WriteTextPosition(writer, value.Start);
            WriteTextPosition(writer, value.End);
        }

        private static int SizeOfFlowGuide(FlowGuide value) {
            var size = 0;
            size += SizeOfTextPosition(value.Start);
            size += SizeOfTextPosition(value.End);
            return size;
        }

        private static void WriteFoldRegion(BinaryWriter writer, FoldRegion value) {
            writer.WriteInt32(value.StartLine);
            writer.WriteInt32(value.EndLine);
            writer.WriteBoolUInt8(value.Collapsed);
        }

        private static int SizeOfFoldRegion(FoldRegion value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 1;
            return size;
        }

        private static void WriteGutterIcon(BinaryWriter writer, GutterIcon value) {
            writer.WriteInt32(value.IconId);
        }

        private static int SizeOfGutterIcon(GutterIcon value) {
            var size = 0;
            size += 4;
            return size;
        }

        private static void WriteIndentGuide(BinaryWriter writer, IndentGuide value) {
            WriteTextPosition(writer, value.Start);
            WriteTextPosition(writer, value.End);
        }

        private static int SizeOfIndentGuide(IndentGuide value) {
            var size = 0;
            size += SizeOfTextPosition(value.Start);
            size += SizeOfTextPosition(value.End);
            return size;
        }

        private static void WriteInlayHint(BinaryWriter writer, InlayHint value) {
            writer.WriteInt32((int)value.Type);
            writer.WriteInt32(value.Column);
            writer.WriteInt32(value.IntValue);
            WriteUtf8String(writer, value.Text);
        }

        private static int SizeOfInlayHint(InlayHint value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            size += SizeOfUtf8String(value.Text);
            return size;
        }

        private static void WriteLinkSpan(BinaryWriter writer, LinkSpan value) {
            writer.WriteInt32(value.Column);
            writer.WriteInt32(value.Length);
            WriteUtf8String(writer, value.Target);
        }

        private static int SizeOfLinkSpan(LinkSpan value) {
            var size = 0;
            size += 4;
            size += 4;
            size += SizeOfUtf8String(value.Target);
            return size;
        }

        private static void WritePhantomText(BinaryWriter writer, PhantomText value) {
            writer.WriteInt32(value.Column);
            WriteUtf8String(writer, value.Text);
        }

        private static int SizeOfPhantomText(PhantomText value) {
            var size = 0;
            size += 4;
            size += SizeOfUtf8String(value.Text);
            return size;
        }

        private static void WriteSeparatorGuide(BinaryWriter writer, SeparatorGuide value) {
            writer.WriteInt32(value.Line);
            writer.WriteInt32((int)value.Style);
            writer.WriteInt32(value.Count);
            writer.WriteInt32(value.TextEndColumn);
        }

        private static int SizeOfSeparatorGuide(SeparatorGuide value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static StyleSpan ReadStyleSpan(ref BinaryReader reader) {
            return new StyleSpan {
                Column = reader.ReadInt32(),
                Length = reader.ReadInt32(),
                StyleId = reader.ReadInt32(),
            };
        }

        public static StyleSpan DecodeStyleSpan(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadStyleSpan(ref reader);
        }

        private static void WriteStyleSpan(BinaryWriter writer, StyleSpan value) {
            writer.WriteInt32(value.Column);
            writer.WriteInt32(value.Length);
            writer.WriteInt32(value.StyleId);
        }

        private static int SizeOfStyleSpan(StyleSpan value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static TextStyle ReadTextStyle(ref BinaryReader reader) {
            return new TextStyle {
                Color = reader.ReadInt32(),
                BackgroundColor = reader.ReadInt32(),
                FontStyle = reader.ReadInt32(),
            };
        }

        public static TextStyle DecodeTextStyle(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadTextStyle(ref reader);
        }

        private static void WriteTextStyle(BinaryWriter writer, TextStyle value) {
            writer.WriteInt32(value.Color);
            writer.WriteInt32(value.BackgroundColor);
            writer.WriteInt32(value.FontStyle);
        }

        private static int SizeOfTextStyle(TextStyle value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteEditorOptions(BinaryWriter writer, EditorOptions value) {
            writer.WriteFloat32(value.TouchSlop);
            writer.WriteInt64(value.DoubleTapTimeout);
            writer.WriteInt64(value.LongPressMs);
            writer.WriteFloat32(value.FlingFriction);
            writer.WriteFloat32(value.FlingMinVelocity);
            writer.WriteFloat32(value.FlingMaxVelocity);
            writer.WriteInt64(value.MaxUndoStackSize);
            writer.WriteInt64(value.KeyChordTimeoutMs);
            writer.WriteBoolUInt8(value.RevealSelectionEndOnSelectAll);
        }

        private static int SizeOfEditorOptions(EditorOptions value) {
            var size = 0;
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

        private static void WriteEditorRangeEffectStyles(BinaryWriter writer, EditorRangeEffectStyles value) {
            WriteRangeEffectStyle(writer, value.Selection);
            WriteRangeEffectStyle(writer, value.SearchMatch);
            WriteRangeEffectStyle(writer, value.SearchCurrent);
            WriteRangeEffectStyle(writer, value.DocumentHighlightText);
            WriteRangeEffectStyle(writer, value.DocumentHighlightRead);
            WriteRangeEffectStyle(writer, value.DocumentHighlightWrite);
            WriteRangeEffectStyle(writer, value.LinkedEditingActive);
            WriteRangeEffectStyle(writer, value.LinkedEditingInactive);
            WriteRangeEffectStyle(writer, value.ImeComposition);
            WriteRangeEffectStyle(writer, value.BracketMatch);
            WriteRangeEffectStyle(writer, value.DiagnosticError);
            WriteRangeEffectStyle(writer, value.DiagnosticWarning);
            WriteRangeEffectStyle(writer, value.DiagnosticInfo);
            WriteRangeEffectStyle(writer, value.DiagnosticHint);
        }

        private static int SizeOfEditorRangeEffectStyles(EditorRangeEffectStyles value) {
            var size = 0;
            size += SizeOfRangeEffectStyle(value.Selection);
            size += SizeOfRangeEffectStyle(value.SearchMatch);
            size += SizeOfRangeEffectStyle(value.SearchCurrent);
            size += SizeOfRangeEffectStyle(value.DocumentHighlightText);
            size += SizeOfRangeEffectStyle(value.DocumentHighlightRead);
            size += SizeOfRangeEffectStyle(value.DocumentHighlightWrite);
            size += SizeOfRangeEffectStyle(value.LinkedEditingActive);
            size += SizeOfRangeEffectStyle(value.LinkedEditingInactive);
            size += SizeOfRangeEffectStyle(value.ImeComposition);
            size += SizeOfRangeEffectStyle(value.BracketMatch);
            size += SizeOfRangeEffectStyle(value.DiagnosticError);
            size += SizeOfRangeEffectStyle(value.DiagnosticWarning);
            size += SizeOfRangeEffectStyle(value.DiagnosticInfo);
            size += SizeOfRangeEffectStyle(value.DiagnosticHint);
            return size;
        }

        private static void WriteEditorRenderColors(BinaryWriter writer, EditorRenderColors value) {
            writer.WriteInt32(value.TextForeground);
            writer.WriteInt32(value.LinkForeground);
            writer.WriteInt32(value.ActiveLinkForeground);
            writer.WriteInt32(value.CodelensForeground);
            writer.WriteInt32(value.ActiveCodelensForeground);
        }

        private static int SizeOfEditorRenderColors(EditorRenderColors value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteHandleConfig(BinaryWriter writer, HandleConfig value) {
            WriteHandleHitArea(writer, value.StartHitArea);
            WriteHandleHitArea(writer, value.EndHitArea);
        }

        private static int SizeOfHandleConfig(HandleConfig value) {
            var size = 0;
            size += SizeOfHandleHitArea(value.StartHitArea);
            size += SizeOfHandleHitArea(value.EndHitArea);
            return size;
        }

        private static HandleHitArea ReadHandleHitArea(ref BinaryReader reader) {
            return new HandleHitArea {
                Left = reader.ReadFloat32(),
                Top = reader.ReadFloat32(),
                Right = reader.ReadFloat32(),
                Bottom = reader.ReadFloat32(),
            };
        }

        public static HandleHitArea DecodeHandleHitArea(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadHandleHitArea(ref reader);
        }

        private static void WriteHandleHitArea(BinaryWriter writer, HandleHitArea value) {
            writer.WriteFloat32(value.Left);
            writer.WriteFloat32(value.Top);
            writer.WriteFloat32(value.Right);
            writer.WriteFloat32(value.Bottom);
        }

        private static int SizeOfHandleHitArea(HandleHitArea value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static RangeEffectStyle ReadRangeEffectStyle(ref BinaryReader reader) {
            return new RangeEffectStyle {
                ForegroundColor = reader.ReadInt32(),
                BackgroundColor = reader.ReadInt32(),
                BorderColor = reader.ReadInt32(),
                UnderlineColor = reader.ReadInt32(),
                UnderlineStyle = ReadEnum<RangeEffectUnderlineStyle>(ref reader),
            };
        }

        public static RangeEffectStyle DecodeRangeEffectStyle(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadRangeEffectStyle(ref reader);
        }

        private static void WriteRangeEffectStyle(BinaryWriter writer, RangeEffectStyle value) {
            writer.WriteInt32(value.ForegroundColor);
            writer.WriteInt32(value.BackgroundColor);
            writer.WriteInt32(value.BorderColor);
            writer.WriteInt32(value.UnderlineColor);
            writer.WriteInt32((int)value.UnderlineStyle);
        }

        private static int SizeOfRangeEffectStyle(RangeEffectStyle value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteScrollbarConfig(BinaryWriter writer, ScrollbarConfig value) {
            writer.WriteFloat32(value.Thickness);
            writer.WriteFloat32(value.MinThumb);
            writer.WriteFloat32(value.ThumbHitPadding);
            writer.WriteInt32((int)value.Mode);
            writer.WriteBoolUInt8(value.ThumbDraggable);
            writer.WriteInt32((int)value.TrackTapMode);
            writer.WriteUInt16(value.FadeDelayMs);
            writer.WriteUInt16(value.FadeDurationMs);
        }

        private static int SizeOfScrollbarConfig(ScrollbarConfig value) {
            var size = 0;
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

        private static IntRange ReadIntRange(ref BinaryReader reader) {
            return new IntRange {
                Start = reader.ReadInt32(),
                End = reader.ReadInt32(),
            };
        }

        public static IntRange DecodeIntRange(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadIntRange(ref reader);
        }

        private static void WriteIntRange(BinaryWriter writer, IntRange value) {
            writer.WriteInt32(value.Start);
            writer.WriteInt32(value.End);
        }

        private static int SizeOfIntRange(IntRange value) {
            var size = 0;
            size += 4;
            size += 4;
            return size;
        }

        private static PointF ReadPointF(ref BinaryReader reader) {
            return new PointF {
                X = reader.ReadFloat32(),
                Y = reader.ReadFloat32(),
            };
        }

        public static PointF DecodePointF(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadPointF(ref reader);
        }

        private static void WritePointF(BinaryWriter writer, PointF value) {
            writer.WriteFloat32(value.X);
            writer.WriteFloat32(value.Y);
        }

        private static int SizeOfPointF(PointF value) {
            var size = 0;
            size += 4;
            size += 4;
            return size;
        }

        private static Rect ReadRect(ref BinaryReader reader) {
            return new Rect {
                Origin = ReadPointF(ref reader),
                Width = reader.ReadFloat32(),
                Height = reader.ReadFloat32(),
            };
        }

        public static Rect DecodeRect(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadRect(ref reader);
        }

        private static void WriteRect(BinaryWriter writer, Rect value) {
            WritePointF(writer, value.Origin);
            writer.WriteFloat32(value.Width);
            writer.WriteFloat32(value.Height);
        }

        private static int SizeOfRect(Rect value) {
            var size = 0;
            size += SizeOfPointF(value.Origin);
            size += 4;
            size += 4;
            return size;
        }

        private static Size ReadSize(ref BinaryReader reader) {
            return new Size {
                Width = reader.ReadFloat32(),
                Height = reader.ReadFloat32(),
            };
        }

        public static Size DecodeSize(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadSize(ref reader);
        }

        private static void WriteSize(BinaryWriter writer, Size value) {
            writer.WriteFloat32(value.Width);
            writer.WriteFloat32(value.Height);
        }

        private static int SizeOfSize(Size value) {
            var size = 0;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteTabStopGroup(BinaryWriter writer, TabStopGroup value) {
            writer.WriteInt32(value.Index);
            WriteTextRangeList(writer, value.Ranges);
            WriteUtf8String(writer, value.DefaultText);
        }

        private static int SizeOfTabStopGroup(TabStopGroup value) {
            var size = 0;
            size += 4;
            size += SizeOfTextRangeList(value.Ranges);
            size += SizeOfUtf8String(value.DefaultText);
            return size;
        }

        private static TextChange ReadTextChange(ref BinaryReader reader) {
            return new TextChange {
                Range = ReadTextRange(ref reader),
                NewText = ReadUtf8String(ref reader),
            };
        }

        public static TextChange DecodeTextChange(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadTextChange(ref reader);
        }

        private static TextEdit ReadTextEdit(ref BinaryReader reader) {
            return new TextEdit {
                Range = ReadTextRange(ref reader),
                NewText = ReadUtf8String(ref reader),
            };
        }

        public static TextEdit DecodeTextEdit(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadTextEdit(ref reader);
        }

        private static void WriteTextEdit(BinaryWriter writer, TextEdit value) {
            WriteTextRange(writer, value.Range);
            WriteUtf8String(writer, value.NewText);
        }

        private static int SizeOfTextEdit(TextEdit value) {
            var size = 0;
            size += SizeOfTextRange(value.Range);
            size += SizeOfUtf8String(value.NewText);
            return size;
        }

        private static TextPosition ReadTextPosition(ref BinaryReader reader) {
            return new TextPosition {
                Line = reader.ReadInt32(),
                Column = reader.ReadInt32(),
            };
        }

        public static TextPosition DecodeTextPosition(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadTextPosition(ref reader);
        }

        private static void WriteTextPosition(BinaryWriter writer, TextPosition value) {
            writer.WriteInt32(value.Line);
            writer.WriteInt32(value.Column);
        }

        private static int SizeOfTextPosition(TextPosition value) {
            var size = 0;
            size += 4;
            size += 4;
            return size;
        }

        private static TextRange ReadTextRange(ref BinaryReader reader) {
            return new TextRange {
                Start = ReadTextPosition(ref reader),
                End = ReadTextPosition(ref reader),
            };
        }

        public static TextRange DecodeTextRange(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadTextRange(ref reader);
        }

        private static void WriteTextRange(BinaryWriter writer, TextRange value) {
            WriteTextPosition(writer, value.Start);
            WriteTextPosition(writer, value.End);
        }

        private static int SizeOfTextRange(TextRange value) {
            var size = 0;
            size += SizeOfTextPosition(value.Start);
            size += SizeOfTextPosition(value.End);
            return size;
        }

        private static void WriteImeCommand(BinaryWriter writer, ImeCommand value) {
            writer.WriteInt32((int)value.Kind);
            WriteImeOffsetRange(writer, value.TargetRange);
            WriteImeSelection(writer, value.SelectionAfter);
            WriteUtf8String(writer, value.Text);
            writer.WriteInt64(value.DeleteBefore);
            writer.WriteInt64(value.DeleteAfter);
            writer.WriteInt32((int)value.TextUnit);
        }

        private static int SizeOfImeCommand(ImeCommand value) {
            var size = 0;
            size += 4;
            size += SizeOfImeOffsetRange(value.TargetRange);
            size += SizeOfImeSelection(value.SelectionAfter);
            size += SizeOfUtf8String(value.Text);
            size += 8;
            size += 8;
            size += 4;
            return size;
        }

        private static void WriteImeCommandBatch(BinaryWriter writer, ImeCommandBatch value) {
            writer.WriteInt64(value.SessionId);
            WriteImeCommandList(writer, value.Commands);
        }

        private static int SizeOfImeCommandBatch(ImeCommandBatch value) {
            var size = 0;
            size += 8;
            size += SizeOfImeCommandList(value.Commands);
            return size;
        }

        private static ImeOffsetRange ReadImeOffsetRange(ref BinaryReader reader) {
            return new ImeOffsetRange {
                CoordinateSpace = ReadEnum<ImeCoordinateSpace>(ref reader),
                StartUtf16 = reader.ReadInt64(),
                EndUtf16 = reader.ReadInt64(),
            };
        }

        public static ImeOffsetRange DecodeImeOffsetRange(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadImeOffsetRange(ref reader);
        }

        private static void WriteImeOffsetRange(BinaryWriter writer, ImeOffsetRange value) {
            writer.WriteInt32((int)value.CoordinateSpace);
            writer.WriteInt64(value.StartUtf16);
            writer.WriteInt64(value.EndUtf16);
        }

        private static int SizeOfImeOffsetRange(ImeOffsetRange value) {
            var size = 0;
            size += 4;
            size += 8;
            size += 8;
            return size;
        }

        private static ImeSelection ReadImeSelection(ref BinaryReader reader) {
            return new ImeSelection {
                CoordinateSpace = ReadEnum<ImeCoordinateSpace>(ref reader),
                AnchorUtf16 = reader.ReadInt64(),
                ActiveUtf16 = reader.ReadInt64(),
                Affinity = ReadEnum<CaretAffinity>(ref reader),
            };
        }

        public static ImeSelection DecodeImeSelection(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadImeSelection(ref reader);
        }

        private static void WriteImeSelection(BinaryWriter writer, ImeSelection value) {
            writer.WriteInt32((int)value.CoordinateSpace);
            writer.WriteInt64(value.AnchorUtf16);
            writer.WriteInt64(value.ActiveUtf16);
            writer.WriteInt32((int)value.Affinity);
        }

        private static int SizeOfImeSelection(ImeSelection value) {
            var size = 0;
            size += 4;
            size += 8;
            size += 8;
            size += 4;
            return size;
        }

        private static ImeState ReadImeState(ref BinaryReader reader) {
            return new ImeState {
                ResultCode = ReadEnum<ImeResultCode>(ref reader),
                SessionId = reader.ReadInt64(),
                StateRevision = reader.ReadInt64(),
                Selection = ReadImeSelection(ref reader),
                CompositionRange = ReadImeOffsetRange(ref reader),
            };
        }

        public static ImeState DecodeImeState(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadImeState(ref reader);
        }

        private static ImeTextContext ReadImeTextContext(ref BinaryReader reader) {
            return new ImeTextContext {
                ResultCode = ReadEnum<ImeResultCode>(ref reader),
                SliceStartUtf16 = reader.ReadInt64(),
                TotalLengthUtf16 = reader.ReadInt64(),
                Text = ReadUtf8String(ref reader),
                Selection = ReadImeSelection(ref reader),
                CompositionRange = ReadImeOffsetRange(ref reader),
            };
        }

        public static ImeTextContext DecodeImeTextContext(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadImeTextContext(ref reader);
        }

        private static void WriteImeTextUpdateBatch(BinaryWriter writer, ImeTextUpdateBatch value) {
            writer.WriteInt64(value.SessionId);
            writer.WriteInt64(value.ExpectedStateRevision);
            WriteImeTextUpdateStepList(writer, value.Steps);
        }

        private static int SizeOfImeTextUpdateBatch(ImeTextUpdateBatch value) {
            var size = 0;
            size += 8;
            size += 8;
            size += SizeOfImeTextUpdateStepList(value.Steps);
            return size;
        }

        private static void WriteImeTextUpdateStep(BinaryWriter writer, ImeTextUpdateStep value) {
            WriteUtf8String(writer, value.OldText);
            WriteImeOffsetRange(writer, value.PatchRange);
            WriteUtf8String(writer, value.ReplacementText);
            WriteImeSelection(writer, value.SelectionAfter);
            WriteImeOffsetRange(writer, value.CompositionAfter);
        }

        private static int SizeOfImeTextUpdateStep(ImeTextUpdateStep value) {
            var size = 0;
            size += SizeOfUtf8String(value.OldText);
            size += SizeOfImeOffsetRange(value.PatchRange);
            size += SizeOfUtf8String(value.ReplacementText);
            size += SizeOfImeSelection(value.SelectionAfter);
            size += SizeOfImeOffsetRange(value.CompositionAfter);
            return size;
        }

        private static void WriteGestureEvent(BinaryWriter writer, GestureEvent value) {
            writer.WriteInt32((int)value.Type);
            WritePointFList(writer, value.Points);
            writer.WriteInt32(value.Modifiers);
            writer.WriteFloat32(value.WheelDeltaX);
            writer.WriteFloat32(value.WheelDeltaY);
            writer.WriteFloat32(value.DirectScale);
        }

        private static int SizeOfGestureEvent(GestureEvent value) {
            var size = 0;
            size += 4;
            size += SizeOfPointFList(value.Points);
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static HitTarget ReadHitTarget(ref BinaryReader reader) {
            return new HitTarget {
                Type = ReadEnum<HitTargetType>(ref reader),
                Line = reader.ReadInt32(),
                Column = reader.ReadInt32(),
                IconId = reader.ReadInt32(),
                ColorValue = reader.ReadInt32(),
            };
        }

        public static HitTarget DecodeHitTarget(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadHitTarget(ref reader);
        }

        private static KeyBinding ReadKeyBinding(ref BinaryReader reader) {
            return new KeyBinding {
                First = ReadKeyChord(ref reader),
                Second = ReadKeyChord(ref reader),
                Command = reader.ReadInt32(),
            };
        }

        public static KeyBinding DecodeKeyBinding(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadKeyBinding(ref reader);
        }

        private static void WriteKeyBinding(BinaryWriter writer, KeyBinding value) {
            WriteKeyChord(writer, value.First);
            WriteKeyChord(writer, value.Second);
            writer.WriteInt32(value.Command);
        }

        private static int SizeOfKeyBinding(KeyBinding value) {
            var size = 0;
            size += SizeOfKeyChord(value.First);
            size += SizeOfKeyChord(value.Second);
            size += 4;
            return size;
        }

        private static KeyChord ReadKeyChord(ref BinaryReader reader) {
            return new KeyChord {
                Modifiers = reader.ReadUInt8(),
                KeyCode = reader.ReadUInt16(),
            };
        }

        public static KeyChord DecodeKeyChord(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadKeyChord(ref reader);
        }

        private static void WriteKeyChord(BinaryWriter writer, KeyChord value) {
            writer.WriteUInt8(value.Modifiers);
            writer.WriteUInt16(value.KeyCode);
        }

        private static int SizeOfKeyChord(KeyChord value) {
            var size = 0;
            size += 1;
            size += 2;
            return size;
        }

        private static SearchOptions ReadSearchOptions(ref BinaryReader reader) {
            return new SearchOptions {
                CaseSensitive = reader.ReadBoolI32(),
                WholeWord = reader.ReadBoolI32(),
                UseRegex = reader.ReadBoolI32(),
                WrapAround = reader.ReadBoolI32(),
                MaxMatches = reader.ReadInt32(),
            };
        }

        public static SearchOptions DecodeSearchOptions(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadSearchOptions(ref reader);
        }

        private static void WriteSearchOptions(BinaryWriter writer, SearchOptions value) {
            writer.WriteBoolI32(value.CaseSensitive);
            writer.WriteBoolI32(value.WholeWord);
            writer.WriteBoolI32(value.UseRegex);
            writer.WriteBoolI32(value.WrapAround);
            writer.WriteInt32(value.MaxMatches);
        }

        private static int SizeOfSearchOptions(SearchOptions value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static void WriteSearchRequest(BinaryWriter writer, SearchRequest value) {
            WriteUtf8String(writer, value.Pattern);
            WriteSearchOptions(writer, value.Options);
        }

        private static int SizeOfSearchRequest(SearchRequest value) {
            var size = 0;
            size += SizeOfUtf8String(value.Pattern);
            size += SizeOfSearchOptions(value.Options);
            return size;
        }

        private static SearchState ReadSearchState(ref BinaryReader reader) {
            return new SearchState {
                Status = ReadEnum<SearchStatus>(ref reader),
                Pattern = ReadUtf8String(ref reader),
                Options = ReadSearchOptions(ref reader),
                Generation = reader.ReadInt64(),
                MatchCount = reader.ReadInt32(),
                CurrentIndex = reader.ReadInt32(),
                HasCurrentMatch = reader.ReadBoolI32(),
                CurrentRange = ReadTextRange(ref reader),
                ErrorMessage = ReadUtf8String(ref reader),
            };
        }

        public static SearchState DecodeSearchState(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadSearchState(ref reader);
        }

        private static Cursor ReadCursor(ref BinaryReader reader) {
            return new Cursor {
                TextPosition = ReadTextPosition(ref reader),
                Position = ReadPointF(ref reader),
                Height = reader.ReadFloat32(),
                Visible = reader.ReadBoolI32(),
                ShowDragger = reader.ReadBoolI32(),
            };
        }

        public static Cursor DecodeCursor(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadCursor(ref reader);
        }

        private static CursorRect ReadCursorRect(ref BinaryReader reader) {
            return new CursorRect {
                X = reader.ReadFloat32(),
                Y = reader.ReadFloat32(),
                Height = reader.ReadFloat32(),
            };
        }

        public static CursorRect DecodeCursorRect(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadCursorRect(ref reader);
        }

        private static void WriteCursorRect(BinaryWriter writer, CursorRect value) {
            writer.WriteFloat32(value.X);
            writer.WriteFloat32(value.Y);
            writer.WriteFloat32(value.Height);
        }

        private static int SizeOfCursorRect(CursorRect value) {
            var size = 0;
            size += 4;
            size += 4;
            size += 4;
            return size;
        }

        private static EditorRenderModel ReadEditorRenderModel(ref BinaryReader reader) {
            return new EditorRenderModel {
                SplitX = reader.ReadFloat32(),
                SplitLineVisible = reader.ReadBoolI32(),
                ScrollX = reader.ReadFloat32(),
                ScrollY = reader.ReadFloat32(),
                ViewportSize = ReadSize(ref reader),
                CurrentLine = ReadPointF(ref reader),
                CurrentLineRenderMode = ReadEnum<CurrentLineRenderMode>(ref reader),
                Lines = ReadVisualLineList(ref reader),
                Cursor = ReadCursor(ref reader),
                RangeEffects = ReadRangeEffectRenderItemList(ref reader),
                SelectionStartHandle = ReadSelectionHandle(ref reader),
                SelectionEndHandle = ReadSelectionHandle(ref reader),
                GuideSegments = ReadGuideSegmentList(ref reader),
                MaxGutterIcons = reader.ReadInt32(),
                GutterIcons = ReadGutterIconRenderItemList(ref reader),
                FoldMarkers = ReadFoldMarkerRenderItemList(ref reader),
                VerticalScrollbar = ReadScrollbarModel(ref reader),
                HorizontalScrollbar = ReadScrollbarModel(ref reader),
                GutterSticky = reader.ReadBoolI32(),
                GutterVisible = reader.ReadBoolI32(),
                PointerCursorType = ReadEnum<PointerCursorType>(ref reader),
            };
        }

        public static EditorRenderModel DecodeEditorRenderModel(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadEditorRenderModel(ref reader);
        }

        private static FoldMarkerRenderItem ReadFoldMarkerRenderItem(ref BinaryReader reader) {
            return new FoldMarkerRenderItem {
                LogicalLine = reader.ReadInt32(),
                FoldState = ReadEnum<FoldState>(ref reader),
                Rect = ReadRect(ref reader),
            };
        }

        public static FoldMarkerRenderItem DecodeFoldMarkerRenderItem(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadFoldMarkerRenderItem(ref reader);
        }

        private static GuideSegment ReadGuideSegment(ref BinaryReader reader) {
            return new GuideSegment {
                Direction = ReadEnum<GuideDirection>(ref reader),
                Type = ReadEnum<GuideType>(ref reader),
                Style = ReadEnum<GuideStyle>(ref reader),
                Start = ReadPointF(ref reader),
                End = ReadPointF(ref reader),
                ArrowEnd = reader.ReadBoolI32(),
            };
        }

        public static GuideSegment DecodeGuideSegment(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadGuideSegment(ref reader);
        }

        private static GutterIconRenderItem ReadGutterIconRenderItem(ref BinaryReader reader) {
            return new GutterIconRenderItem {
                LogicalLine = reader.ReadInt32(),
                IconId = reader.ReadInt32(),
                Rect = ReadRect(ref reader),
            };
        }

        public static GutterIconRenderItem DecodeGutterIconRenderItem(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadGutterIconRenderItem(ref reader);
        }

        private static LayoutMetrics ReadLayoutMetrics(ref BinaryReader reader) {
            return new LayoutMetrics {
                FontHeight = reader.ReadFloat32(),
                FontAscent = reader.ReadFloat32(),
                LineSpacingAdd = reader.ReadFloat32(),
                LineSpacingMult = reader.ReadFloat32(),
                LineNumberMargin = reader.ReadFloat32(),
                LineNumberWidth = reader.ReadFloat32(),
                ContentStartPadding = reader.ReadFloat32(),
                MaxGutterIcons = reader.ReadInt32(),
                InlayHintPadding = reader.ReadFloat32(),
                InlayHintMargin = reader.ReadFloat32(),
                FoldArrowMode = ReadEnum<FoldArrowMode>(ref reader),
                HasFoldRegions = reader.ReadBoolI32(),
                GutterSticky = reader.ReadBoolI32(),
                GutterVisible = reader.ReadBoolI32(),
            };
        }

        public static LayoutMetrics DecodeLayoutMetrics(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadLayoutMetrics(ref reader);
        }

        private static RangeEffectRenderItem ReadRangeEffectRenderItem(ref BinaryReader reader) {
            return new RangeEffectRenderItem {
                Rect = ReadRect(ref reader),
                Kind = ReadEnum<RangeEffectKind>(ref reader),
                Style = ReadRangeEffectStyle(ref reader),
            };
        }

        public static RangeEffectRenderItem DecodeRangeEffectRenderItem(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadRangeEffectRenderItem(ref reader);
        }

        private static ScrollMetrics ReadScrollMetrics(ref BinaryReader reader) {
            return new ScrollMetrics {
                Scale = reader.ReadFloat32(),
                ScrollX = reader.ReadFloat32(),
                ScrollY = reader.ReadFloat32(),
                MaxScrollX = reader.ReadFloat32(),
                MaxScrollY = reader.ReadFloat32(),
                ContentSize = ReadSize(ref reader),
                ViewportSize = ReadSize(ref reader),
                TextAreaX = reader.ReadFloat32(),
                TextAreaWidth = reader.ReadFloat32(),
                CanScrollX = reader.ReadBoolI32(),
                CanScrollY = reader.ReadBoolI32(),
            };
        }

        public static ScrollMetrics DecodeScrollMetrics(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadScrollMetrics(ref reader);
        }

        private static ScrollbarModel ReadScrollbarModel(ref BinaryReader reader) {
            return new ScrollbarModel {
                Visible = reader.ReadBoolI32(),
                Alpha = reader.ReadFloat32(),
                ThumbActive = reader.ReadBoolI32(),
                Track = ReadRect(ref reader),
                Thumb = ReadRect(ref reader),
            };
        }

        public static ScrollbarModel DecodeScrollbarModel(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadScrollbarModel(ref reader);
        }

        private static SelectionHandle ReadSelectionHandle(ref BinaryReader reader) {
            return new SelectionHandle {
                Position = ReadPointF(ref reader),
                Height = reader.ReadFloat32(),
                Visible = reader.ReadBoolI32(),
            };
        }

        public static SelectionHandle DecodeSelectionHandle(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadSelectionHandle(ref reader);
        }

        private static VisualLine ReadVisualLine(ref BinaryReader reader) {
            return new VisualLine {
                LogicalLine = reader.ReadInt32(),
                WrapIndex = reader.ReadInt32(),
                LineNumberPosition = ReadPointF(ref reader),
                Runs = ReadVisualRunList(ref reader),
                Kind = ReadEnum<VisualLineKind>(ref reader),
                OwnsGutterSemantics = reader.ReadBoolI32(),
                FoldState = ReadEnum<FoldState>(ref reader),
            };
        }

        public static VisualLine DecodeVisualLine(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadVisualLine(ref reader);
        }

        private static VisualRun ReadVisualRun(ref BinaryReader reader) {
            return new VisualRun {
                Type = ReadEnum<VisualRunType>(ref reader),
                X = reader.ReadFloat32(),
                Y = reader.ReadFloat32(),
                Text = ReadUtf8String(ref reader),
                Style = ReadTextStyle(ref reader),
                IconId = reader.ReadInt32(),
                ColorValue = reader.ReadInt32(),
                Width = reader.ReadFloat32(),
                Padding = reader.ReadFloat32(),
                Margin = reader.ReadFloat32(),
                Active = reader.ReadBoolI32(),
            };
        }

        public static VisualRun DecodeVisualRun(ReadOnlySpan<byte> data) {
            var reader = new BinaryReader(data);
            return ReadVisualRun(ref reader);
        }

        public static byte[] EncodeBracketGuide(BracketGuide value) {
            var writer = new BinaryWriter(SizeOfBracketGuide(value));
            WriteBracketGuide(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeCodeLensItem(CodeLensItem value) {
            var writer = new BinaryWriter(SizeOfCodeLensItem(value));
            WriteCodeLensItem(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeDiagnostic(Diagnostic value) {
            var writer = new BinaryWriter(SizeOfDiagnostic(value));
            WriteDiagnostic(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeDocumentHighlight(DocumentHighlight value) {
            var writer = new BinaryWriter(SizeOfDocumentHighlight(value));
            WriteDocumentHighlight(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeFlowGuide(FlowGuide value) {
            var writer = new BinaryWriter(SizeOfFlowGuide(value));
            WriteFlowGuide(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeFoldRegion(FoldRegion value) {
            var writer = new BinaryWriter(SizeOfFoldRegion(value));
            WriteFoldRegion(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeGutterIcon(GutterIcon value) {
            var writer = new BinaryWriter(SizeOfGutterIcon(value));
            WriteGutterIcon(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeIndentGuide(IndentGuide value) {
            var writer = new BinaryWriter(SizeOfIndentGuide(value));
            WriteIndentGuide(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeInlayHint(InlayHint value) {
            var writer = new BinaryWriter(SizeOfInlayHint(value));
            WriteInlayHint(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeLinkSpan(LinkSpan value) {
            var writer = new BinaryWriter(SizeOfLinkSpan(value));
            WriteLinkSpan(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodePhantomText(PhantomText value) {
            var writer = new BinaryWriter(SizeOfPhantomText(value));
            WritePhantomText(writer, value);
            return writer.ToArray();
        }

        private static void WriteRegisterBatchTextStylesPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, TextStyle>? styleByStyleId) {
            var sortedStyleByStyleId = new SortedDictionary<int, TextStyle>();
            if (styleByStyleId != null) {
                foreach (var entry in styleByStyleId) {
                    sortedStyleByStyleId[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedStyleByStyleId.Count);
            foreach (var entry in sortedStyleByStyleId) {
                writer.WriteInt32(entry.Key);
                WriteTextStyle(writer, entry.Value);
            }
        }

        private static int SizeOfRegisterBatchTextStylesPayloadWire(IReadOnlyDictionary<int, TextStyle>? styleByStyleId) {
            var size = 0;
            size += 4;
            if (styleByStyleId != null) {
                foreach (var entry in styleByStyleId) {
                    size += 4;
                    size += SizeOfTextStyle(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeRegisterBatchTextStylesPayload(IReadOnlyDictionary<int, TextStyle>? styleByStyleId) {
            var writer = new BinaryWriter(SizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId));
            WriteRegisterBatchTextStylesPayloadWire(writer, styleByStyleId);
            return writer.ToArray();
        }

        public static byte[] EncodeSeparatorGuide(SeparatorGuide value) {
            var writer = new BinaryWriter(SizeOfSeparatorGuide(value));
            WriteSeparatorGuide(writer, value);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineCodeLensPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<CodeLensItem>>? itemsByLine) {
            var sortedItemsByLine = new SortedDictionary<int, IReadOnlyList<CodeLensItem>>();
            if (itemsByLine != null) {
                foreach (var entry in itemsByLine) {
                    sortedItemsByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedItemsByLine.Count);
            foreach (var entry in sortedItemsByLine) {
                writer.WriteInt32(entry.Key);
                WriteCodeLensItemList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineCodeLensPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<CodeLensItem>>? itemsByLine) {
            var size = 0;
            size += 4;
            if (itemsByLine != null) {
                foreach (var entry in itemsByLine) {
                    size += 4;
                    size += SizeOfCodeLensItemList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineCodeLensPayload(IReadOnlyDictionary<int, IReadOnlyList<CodeLensItem>>? itemsByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineCodeLensPayloadWire(itemsByLine));
            WriteSetBatchLineCodeLensPayloadWire(writer, itemsByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineDiagnosticsPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<Diagnostic>>? diagnosticsByLine) {
            var sortedDiagnosticsByLine = new SortedDictionary<int, IReadOnlyList<Diagnostic>>();
            if (diagnosticsByLine != null) {
                foreach (var entry in diagnosticsByLine) {
                    sortedDiagnosticsByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedDiagnosticsByLine.Count);
            foreach (var entry in sortedDiagnosticsByLine) {
                writer.WriteInt32(entry.Key);
                WriteDiagnosticList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineDiagnosticsPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<Diagnostic>>? diagnosticsByLine) {
            var size = 0;
            size += 4;
            if (diagnosticsByLine != null) {
                foreach (var entry in diagnosticsByLine) {
                    size += 4;
                    size += SizeOfDiagnosticList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineDiagnosticsPayload(IReadOnlyDictionary<int, IReadOnlyList<Diagnostic>>? diagnosticsByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine));
            WriteSetBatchLineDiagnosticsPayloadWire(writer, diagnosticsByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineDocumentHighlightsPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<DocumentHighlight>>? highlightsByLine) {
            var sortedHighlightsByLine = new SortedDictionary<int, IReadOnlyList<DocumentHighlight>>();
            if (highlightsByLine != null) {
                foreach (var entry in highlightsByLine) {
                    sortedHighlightsByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedHighlightsByLine.Count);
            foreach (var entry in sortedHighlightsByLine) {
                writer.WriteInt32(entry.Key);
                WriteDocumentHighlightList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineDocumentHighlightsPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<DocumentHighlight>>? highlightsByLine) {
            var size = 0;
            size += 4;
            if (highlightsByLine != null) {
                foreach (var entry in highlightsByLine) {
                    size += 4;
                    size += SizeOfDocumentHighlightList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineDocumentHighlightsPayload(IReadOnlyDictionary<int, IReadOnlyList<DocumentHighlight>>? highlightsByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineDocumentHighlightsPayloadWire(highlightsByLine));
            WriteSetBatchLineDocumentHighlightsPayloadWire(writer, highlightsByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineGutterIconsPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<GutterIcon>>? iconsByLine) {
            var sortedIconsByLine = new SortedDictionary<int, IReadOnlyList<GutterIcon>>();
            if (iconsByLine != null) {
                foreach (var entry in iconsByLine) {
                    sortedIconsByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedIconsByLine.Count);
            foreach (var entry in sortedIconsByLine) {
                writer.WriteInt32(entry.Key);
                WriteGutterIconList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineGutterIconsPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<GutterIcon>>? iconsByLine) {
            var size = 0;
            size += 4;
            if (iconsByLine != null) {
                foreach (var entry in iconsByLine) {
                    size += 4;
                    size += SizeOfGutterIconList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineGutterIconsPayload(IReadOnlyDictionary<int, IReadOnlyList<GutterIcon>>? iconsByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine));
            WriteSetBatchLineGutterIconsPayloadWire(writer, iconsByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineInlayHintsPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<InlayHint>>? hintsByLine) {
            var sortedHintsByLine = new SortedDictionary<int, IReadOnlyList<InlayHint>>();
            if (hintsByLine != null) {
                foreach (var entry in hintsByLine) {
                    sortedHintsByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedHintsByLine.Count);
            foreach (var entry in sortedHintsByLine) {
                writer.WriteInt32(entry.Key);
                WriteInlayHintList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineInlayHintsPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<InlayHint>>? hintsByLine) {
            var size = 0;
            size += 4;
            if (hintsByLine != null) {
                foreach (var entry in hintsByLine) {
                    size += 4;
                    size += SizeOfInlayHintList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineInlayHintsPayload(IReadOnlyDictionary<int, IReadOnlyList<InlayHint>>? hintsByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine));
            WriteSetBatchLineInlayHintsPayloadWire(writer, hintsByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineLinksPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<LinkSpan>>? linksByLine) {
            var sortedLinksByLine = new SortedDictionary<int, IReadOnlyList<LinkSpan>>();
            if (linksByLine != null) {
                foreach (var entry in linksByLine) {
                    sortedLinksByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedLinksByLine.Count);
            foreach (var entry in sortedLinksByLine) {
                writer.WriteInt32(entry.Key);
                WriteLinkSpanList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineLinksPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<LinkSpan>>? linksByLine) {
            var size = 0;
            size += 4;
            if (linksByLine != null) {
                foreach (var entry in linksByLine) {
                    size += 4;
                    size += SizeOfLinkSpanList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineLinksPayload(IReadOnlyDictionary<int, IReadOnlyList<LinkSpan>>? linksByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineLinksPayloadWire(linksByLine));
            WriteSetBatchLineLinksPayloadWire(writer, linksByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLinePhantomTextsPayloadWire(BinaryWriter writer, IReadOnlyDictionary<int, IReadOnlyList<PhantomText>>? phantomsByLine) {
            var sortedPhantomsByLine = new SortedDictionary<int, IReadOnlyList<PhantomText>>();
            if (phantomsByLine != null) {
                foreach (var entry in phantomsByLine) {
                    sortedPhantomsByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedPhantomsByLine.Count);
            foreach (var entry in sortedPhantomsByLine) {
                writer.WriteInt32(entry.Key);
                WritePhantomTextList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLinePhantomTextsPayloadWire(IReadOnlyDictionary<int, IReadOnlyList<PhantomText>>? phantomsByLine) {
            var size = 0;
            size += 4;
            if (phantomsByLine != null) {
                foreach (var entry in phantomsByLine) {
                    size += 4;
                    size += SizeOfPhantomTextList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLinePhantomTextsPayload(IReadOnlyDictionary<int, IReadOnlyList<PhantomText>>? phantomsByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine));
            WriteSetBatchLinePhantomTextsPayloadWire(writer, phantomsByLine);
            return writer.ToArray();
        }

        private static void WriteSetBatchLineSpansPayloadWire(BinaryWriter writer, SpanLayer layer, IReadOnlyDictionary<int, IReadOnlyList<StyleSpan>>? spansByLine) {
            writer.WriteInt32((int)layer);
            var sortedSpansByLine = new SortedDictionary<int, IReadOnlyList<StyleSpan>>();
            if (spansByLine != null) {
                foreach (var entry in spansByLine) {
                    sortedSpansByLine[entry.Key] = entry.Value;
                }
            }
            writer.WriteInt32(sortedSpansByLine.Count);
            foreach (var entry in sortedSpansByLine) {
                writer.WriteInt32(entry.Key);
                WriteStyleSpanList(writer, entry.Value);
            }
        }

        private static int SizeOfSetBatchLineSpansPayloadWire(SpanLayer layer, IReadOnlyDictionary<int, IReadOnlyList<StyleSpan>>? spansByLine) {
            var size = 0;
            size += 4;
            size += 4;
            if (spansByLine != null) {
                foreach (var entry in spansByLine) {
                    size += 4;
                    size += SizeOfStyleSpanList(entry.Value);
                }
            }
            return size;
        }

        public static byte[] EncodeSetBatchLineSpansPayload(SpanLayer layer, IReadOnlyDictionary<int, IReadOnlyList<StyleSpan>>? spansByLine) {
            var writer = new BinaryWriter(SizeOfSetBatchLineSpansPayloadWire(layer, spansByLine));
            WriteSetBatchLineSpansPayloadWire(writer, layer, spansByLine);
            return writer.ToArray();
        }

        private static void WriteSetBracketGuidesPayloadWire(BinaryWriter writer, IReadOnlyList<BracketGuide>? guides) {
            WriteBracketGuideList(writer, guides);
        }

        private static int SizeOfSetBracketGuidesPayloadWire(IReadOnlyList<BracketGuide>? guides) {
            var size = 0;
            size += SizeOfBracketGuideList(guides);
            return size;
        }

        public static byte[] EncodeSetBracketGuidesPayload(IReadOnlyList<BracketGuide>? guides) {
            var writer = new BinaryWriter(SizeOfSetBracketGuidesPayloadWire(guides));
            WriteSetBracketGuidesPayloadWire(writer, guides);
            return writer.ToArray();
        }

        private static void WriteSetFlowGuidesPayloadWire(BinaryWriter writer, IReadOnlyList<FlowGuide>? guides) {
            WriteFlowGuideList(writer, guides);
        }

        private static int SizeOfSetFlowGuidesPayloadWire(IReadOnlyList<FlowGuide>? guides) {
            var size = 0;
            size += SizeOfFlowGuideList(guides);
            return size;
        }

        public static byte[] EncodeSetFlowGuidesPayload(IReadOnlyList<FlowGuide>? guides) {
            var writer = new BinaryWriter(SizeOfSetFlowGuidesPayloadWire(guides));
            WriteSetFlowGuidesPayloadWire(writer, guides);
            return writer.ToArray();
        }

        private static void WriteSetFoldRegionsPayloadWire(BinaryWriter writer, IReadOnlyList<FoldRegion>? regions) {
            WriteFoldRegionList(writer, regions);
        }

        private static int SizeOfSetFoldRegionsPayloadWire(IReadOnlyList<FoldRegion>? regions) {
            var size = 0;
            size += SizeOfFoldRegionList(regions);
            return size;
        }

        public static byte[] EncodeSetFoldRegionsPayload(IReadOnlyList<FoldRegion>? regions) {
            var writer = new BinaryWriter(SizeOfSetFoldRegionsPayloadWire(regions));
            WriteSetFoldRegionsPayloadWire(writer, regions);
            return writer.ToArray();
        }

        private static void WriteSetIndentGuidesPayloadWire(BinaryWriter writer, IReadOnlyList<IndentGuide>? guides) {
            WriteIndentGuideList(writer, guides);
        }

        private static int SizeOfSetIndentGuidesPayloadWire(IReadOnlyList<IndentGuide>? guides) {
            var size = 0;
            size += SizeOfIndentGuideList(guides);
            return size;
        }

        public static byte[] EncodeSetIndentGuidesPayload(IReadOnlyList<IndentGuide>? guides) {
            var writer = new BinaryWriter(SizeOfSetIndentGuidesPayloadWire(guides));
            WriteSetIndentGuidesPayloadWire(writer, guides);
            return writer.ToArray();
        }

        private static void WriteSetLineCodeLensPayloadWire(BinaryWriter writer, int line, IReadOnlyList<CodeLensItem>? items) {
            writer.WriteInt32(line);
            WriteCodeLensItemList(writer, items);
        }

        private static int SizeOfSetLineCodeLensPayloadWire(int line, IReadOnlyList<CodeLensItem>? items) {
            var size = 0;
            size += 4;
            size += SizeOfCodeLensItemList(items);
            return size;
        }

        public static byte[] EncodeSetLineCodeLensPayload(int line, IReadOnlyList<CodeLensItem>? items) {
            var writer = new BinaryWriter(SizeOfSetLineCodeLensPayloadWire(line, items));
            WriteSetLineCodeLensPayloadWire(writer, line, items);
            return writer.ToArray();
        }

        private static void WriteSetLineDiagnosticsPayloadWire(BinaryWriter writer, int line, IReadOnlyList<Diagnostic>? diagnostics) {
            writer.WriteInt32(line);
            WriteDiagnosticList(writer, diagnostics);
        }

        private static int SizeOfSetLineDiagnosticsPayloadWire(int line, IReadOnlyList<Diagnostic>? diagnostics) {
            var size = 0;
            size += 4;
            size += SizeOfDiagnosticList(diagnostics);
            return size;
        }

        public static byte[] EncodeSetLineDiagnosticsPayload(int line, IReadOnlyList<Diagnostic>? diagnostics) {
            var writer = new BinaryWriter(SizeOfSetLineDiagnosticsPayloadWire(line, diagnostics));
            WriteSetLineDiagnosticsPayloadWire(writer, line, diagnostics);
            return writer.ToArray();
        }

        private static void WriteSetLineDocumentHighlightsPayloadWire(BinaryWriter writer, int line, IReadOnlyList<DocumentHighlight>? highlights) {
            writer.WriteInt32(line);
            WriteDocumentHighlightList(writer, highlights);
        }

        private static int SizeOfSetLineDocumentHighlightsPayloadWire(int line, IReadOnlyList<DocumentHighlight>? highlights) {
            var size = 0;
            size += 4;
            size += SizeOfDocumentHighlightList(highlights);
            return size;
        }

        public static byte[] EncodeSetLineDocumentHighlightsPayload(int line, IReadOnlyList<DocumentHighlight>? highlights) {
            var writer = new BinaryWriter(SizeOfSetLineDocumentHighlightsPayloadWire(line, highlights));
            WriteSetLineDocumentHighlightsPayloadWire(writer, line, highlights);
            return writer.ToArray();
        }

        private static void WriteSetLineGutterIconsPayloadWire(BinaryWriter writer, int line, IReadOnlyList<GutterIcon>? icons) {
            writer.WriteInt32(line);
            WriteGutterIconList(writer, icons);
        }

        private static int SizeOfSetLineGutterIconsPayloadWire(int line, IReadOnlyList<GutterIcon>? icons) {
            var size = 0;
            size += 4;
            size += SizeOfGutterIconList(icons);
            return size;
        }

        public static byte[] EncodeSetLineGutterIconsPayload(int line, IReadOnlyList<GutterIcon>? icons) {
            var writer = new BinaryWriter(SizeOfSetLineGutterIconsPayloadWire(line, icons));
            WriteSetLineGutterIconsPayloadWire(writer, line, icons);
            return writer.ToArray();
        }

        private static void WriteSetLineInlayHintsPayloadWire(BinaryWriter writer, int line, IReadOnlyList<InlayHint>? hints) {
            writer.WriteInt32(line);
            WriteInlayHintList(writer, hints);
        }

        private static int SizeOfSetLineInlayHintsPayloadWire(int line, IReadOnlyList<InlayHint>? hints) {
            var size = 0;
            size += 4;
            size += SizeOfInlayHintList(hints);
            return size;
        }

        public static byte[] EncodeSetLineInlayHintsPayload(int line, IReadOnlyList<InlayHint>? hints) {
            var writer = new BinaryWriter(SizeOfSetLineInlayHintsPayloadWire(line, hints));
            WriteSetLineInlayHintsPayloadWire(writer, line, hints);
            return writer.ToArray();
        }

        private static void WriteSetLineLinksPayloadWire(BinaryWriter writer, int line, IReadOnlyList<LinkSpan>? links) {
            writer.WriteInt32(line);
            WriteLinkSpanList(writer, links);
        }

        private static int SizeOfSetLineLinksPayloadWire(int line, IReadOnlyList<LinkSpan>? links) {
            var size = 0;
            size += 4;
            size += SizeOfLinkSpanList(links);
            return size;
        }

        public static byte[] EncodeSetLineLinksPayload(int line, IReadOnlyList<LinkSpan>? links) {
            var writer = new BinaryWriter(SizeOfSetLineLinksPayloadWire(line, links));
            WriteSetLineLinksPayloadWire(writer, line, links);
            return writer.ToArray();
        }

        private static void WriteSetLinePhantomTextsPayloadWire(BinaryWriter writer, int line, IReadOnlyList<PhantomText>? phantoms) {
            writer.WriteInt32(line);
            WritePhantomTextList(writer, phantoms);
        }

        private static int SizeOfSetLinePhantomTextsPayloadWire(int line, IReadOnlyList<PhantomText>? phantoms) {
            var size = 0;
            size += 4;
            size += SizeOfPhantomTextList(phantoms);
            return size;
        }

        public static byte[] EncodeSetLinePhantomTextsPayload(int line, IReadOnlyList<PhantomText>? phantoms) {
            var writer = new BinaryWriter(SizeOfSetLinePhantomTextsPayloadWire(line, phantoms));
            WriteSetLinePhantomTextsPayloadWire(writer, line, phantoms);
            return writer.ToArray();
        }

        private static void WriteSetLineSpansPayloadWire(BinaryWriter writer, int line, SpanLayer layer, IReadOnlyList<StyleSpan>? spans) {
            writer.WriteInt32(line);
            writer.WriteInt32((int)layer);
            WriteStyleSpanList(writer, spans);
        }

        private static int SizeOfSetLineSpansPayloadWire(int line, SpanLayer layer, IReadOnlyList<StyleSpan>? spans) {
            var size = 0;
            size += 4;
            size += 4;
            size += SizeOfStyleSpanList(spans);
            return size;
        }

        public static byte[] EncodeSetLineSpansPayload(int line, SpanLayer layer, IReadOnlyList<StyleSpan>? spans) {
            var writer = new BinaryWriter(SizeOfSetLineSpansPayloadWire(line, layer, spans));
            WriteSetLineSpansPayloadWire(writer, line, layer, spans);
            return writer.ToArray();
        }

        private static void WriteSetSeparatorGuidesPayloadWire(BinaryWriter writer, IReadOnlyList<SeparatorGuide>? guides) {
            WriteSeparatorGuideList(writer, guides);
        }

        private static int SizeOfSetSeparatorGuidesPayloadWire(IReadOnlyList<SeparatorGuide>? guides) {
            var size = 0;
            size += SizeOfSeparatorGuideList(guides);
            return size;
        }

        public static byte[] EncodeSetSeparatorGuidesPayload(IReadOnlyList<SeparatorGuide>? guides) {
            var writer = new BinaryWriter(SizeOfSetSeparatorGuidesPayloadWire(guides));
            WriteSetSeparatorGuidesPayloadWire(writer, guides);
            return writer.ToArray();
        }

        public static byte[] EncodeEditorOptions(EditorOptions value) {
            var writer = new BinaryWriter(SizeOfEditorOptions(value));
            WriteEditorOptions(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeEditorRangeEffectStyles(EditorRangeEffectStyles value) {
            var writer = new BinaryWriter(SizeOfEditorRangeEffectStyles(value));
            WriteEditorRangeEffectStyles(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeEditorRenderColors(EditorRenderColors value) {
            var writer = new BinaryWriter(SizeOfEditorRenderColors(value));
            WriteEditorRenderColors(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeHandleConfig(HandleConfig value) {
            var writer = new BinaryWriter(SizeOfHandleConfig(value));
            WriteHandleConfig(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeScrollbarConfig(ScrollbarConfig value) {
            var writer = new BinaryWriter(SizeOfScrollbarConfig(value));
            WriteScrollbarConfig(writer, value);
            return writer.ToArray();
        }

        private static void WriteApplyTextEditsPayloadWire(BinaryWriter writer, IReadOnlyList<TextEdit>? edits) {
            WriteTextEditList(writer, edits);
        }

        private static int SizeOfApplyTextEditsPayloadWire(IReadOnlyList<TextEdit>? edits) {
            var size = 0;
            size += SizeOfTextEditList(edits);
            return size;
        }

        public static byte[] EncodeApplyTextEditsPayload(IReadOnlyList<TextEdit>? edits) {
            var writer = new BinaryWriter(SizeOfApplyTextEditsPayloadWire(edits));
            WriteApplyTextEditsPayloadWire(writer, edits);
            return writer.ToArray();
        }

        public static byte[] EncodeTabStopGroup(TabStopGroup value) {
            var writer = new BinaryWriter(SizeOfTabStopGroup(value));
            WriteTabStopGroup(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeImeCommand(ImeCommand value) {
            var writer = new BinaryWriter(SizeOfImeCommand(value));
            WriteImeCommand(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeImeCommandBatch(ImeCommandBatch value) {
            var writer = new BinaryWriter(SizeOfImeCommandBatch(value));
            WriteImeCommandBatch(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeImeTextUpdateBatch(ImeTextUpdateBatch value) {
            var writer = new BinaryWriter(SizeOfImeTextUpdateBatch(value));
            WriteImeTextUpdateBatch(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeImeTextUpdateStep(ImeTextUpdateStep value) {
            var writer = new BinaryWriter(SizeOfImeTextUpdateStep(value));
            WriteImeTextUpdateStep(writer, value);
            return writer.ToArray();
        }

        public static byte[] EncodeGestureEvent(GestureEvent value) {
            var writer = new BinaryWriter(SizeOfGestureEvent(value));
            WriteGestureEvent(writer, value);
            return writer.ToArray();
        }

        private static void WriteSetKeyMapPayloadWire(BinaryWriter writer, IReadOnlyList<KeyBinding>? bindings) {
            WriteKeyBindingList(writer, bindings);
        }

        private static int SizeOfSetKeyMapPayloadWire(IReadOnlyList<KeyBinding>? bindings) {
            var size = 0;
            size += SizeOfKeyBindingList(bindings);
            return size;
        }

        public static byte[] EncodeSetKeyMapPayload(IReadOnlyList<KeyBinding>? bindings) {
            var writer = new BinaryWriter(SizeOfSetKeyMapPayloadWire(bindings));
            WriteSetKeyMapPayloadWire(writer, bindings);
            return writer.ToArray();
        }

        private static void WriteStartLinkedEditingPayloadWire(BinaryWriter writer, IReadOnlyList<TabStopGroup>? groups) {
            WriteTabStopGroupList(writer, groups);
        }

        private static int SizeOfStartLinkedEditingPayloadWire(IReadOnlyList<TabStopGroup>? groups) {
            var size = 0;
            size += SizeOfTabStopGroupList(groups);
            return size;
        }

        public static byte[] EncodeStartLinkedEditingPayload(IReadOnlyList<TabStopGroup>? groups) {
            var writer = new BinaryWriter(SizeOfStartLinkedEditingPayloadWire(groups));
            WriteStartLinkedEditingPayloadWire(writer, groups);
            return writer.ToArray();
        }

        public static byte[] EncodeSearchRequest(SearchRequest value) {
            var writer = new BinaryWriter(SizeOfSearchRequest(value));
            WriteSearchRequest(writer, value);
            return writer.ToArray();
        }
    }
}
