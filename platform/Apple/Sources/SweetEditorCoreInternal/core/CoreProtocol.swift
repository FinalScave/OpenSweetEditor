import Foundation

enum CoreProtocol {
    struct BinaryReader {
        let data: UnsafeRawBufferPointer
        var offset: Int = 0

        init(_ data: UnsafeRawBufferPointer) {
            self.data = data
        }

        var remaining: Int {
            data.count - offset
        }

        mutating func readUInt8() -> UInt8? {
            guard offset + 1 <= data.count else { return nil }
            defer { offset += 1 }
            return data[offset]
        }

        mutating func readUInt16() -> UInt16? {
            guard offset + 2 <= data.count else { return nil }
            let b0 = UInt16(data[offset])
            let b1 = UInt16(data[offset + 1]) << 8
            offset += 2
            return b0 | b1
        }

        mutating func readUInt32() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let b0 = UInt32(data[offset])
            let b1 = UInt32(data[offset + 1]) << 8
            let b2 = UInt32(data[offset + 2]) << 16
            let b3 = UInt32(data[offset + 3]) << 24
            offset += 4
            return b0 | b1 | b2 | b3
        }

        mutating func readInt32() -> Int32? {
            guard let raw = readUInt32() else { return nil }
            return Int32(bitPattern: raw)
        }

        mutating func readInt64() -> Int64? {
            guard let low = readUInt32(), let high = readUInt32() else { return nil }
            return Int64(bitPattern: UInt64(low) | (UInt64(high) << 32))
        }

        mutating func readFloat32() -> Float? {
            guard let raw = readUInt32() else { return nil }
            return Float(bitPattern: raw)
        }

        mutating func readFloat64() -> Double? {
            guard let low = readUInt32(), let high = readUInt32() else { return nil }
            return Double(bitPattern: UInt64(low) | (UInt64(high) << 32))
        }

        mutating func readBoolI32() -> Bool? {
            guard let value = readInt32() else { return nil }
            return value != 0
        }

        mutating func readBoolU8() -> Bool? {
            guard let value = readUInt8() else { return nil }
            return value != 0
        }

        mutating func readUtf8String() -> String? {
            guard let lengthValue = readInt32(), lengthValue >= 0 else { return nil }
            let length = Int(lengthValue)
            guard offset + length <= data.count else { return nil }
            defer { offset += length }
            if length == 0 { return "" }
            let bytes = data.bindMemory(to: UInt8.self)
            return String(decoding: bytes[offset..<(offset + length)], as: UTF8.self)
        }
    }

    struct BinaryWriter {
        var bytes: [UInt8] = []

        mutating func writeUInt8(_ value: UInt8) {
            bytes.append(value)
        }

        mutating func writeUInt16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
        }

        mutating func writeInt32(_ value: Int32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
        }

        mutating func writeInt64(_ value: Int64) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { bytes.append(contentsOf: $0) }
        }

        mutating func writeFloat32(_ value: Float) {
            writeInt32(Int32(bitPattern: value.bitPattern))
        }

        mutating func writeFloat64(_ value: Double) {
            writeInt64(Int64(bitPattern: value.bitPattern))
        }

        mutating func writeBoolI32(_ value: Bool) {
            writeInt32(value ? 1 : 0)
        }

        mutating func writeBoolU8(_ value: Bool) {
            writeUInt8(value ? 1 : 0)
        }

        mutating func writeUtf8String(_ value: String) {
            let encoded = value.data(using: .utf8) ?? Data()
            writeInt32(Int32(encoded.count))
            bytes.append(contentsOf: encoded)
        }

        func data() -> Data {
            Data(bytes)
        }
    }

    static func sizeOfUtf8String(_ value: String) -> Int {
        4 + (value.data(using: .utf8)?.count ?? 0)
    }

    static func encodeUtf8String(_ value: String) -> Data {
        var writer = BinaryWriter()
        writer.writeUtf8String(value)
        return writer.data()
    }

    static func readEditorActionSource(_ reader: inout BinaryReader) -> EditorActionSource? {
        guard let value = reader.readInt32() else { return nil }
        return EditorActionSource.fromValue(value)
    }

    static func readScrollBehavior(_ reader: inout BinaryReader) -> ScrollBehavior? {
        guard let value = reader.readInt32() else { return nil }
        return ScrollBehavior.fromValue(value)
    }

    static func readTextChangeKind(_ reader: inout BinaryReader) -> TextChangeKind? {
        guard let value = reader.readInt32() else { return nil }
        return TextChangeKind.fromValue(value)
    }

    static func readDiagnosticSeverity(_ reader: inout BinaryReader) -> DiagnosticSeverity? {
        guard let value = reader.readInt32() else { return nil }
        return DiagnosticSeverity.fromValue(value)
    }

    static func readDocumentHighlightKind(_ reader: inout BinaryReader) -> DocumentHighlightKind? {
        guard let value = reader.readInt32() else { return nil }
        return DocumentHighlightKind.fromValue(value)
    }

    static func readInlayType(_ reader: inout BinaryReader) -> InlayType? {
        guard let value = reader.readInt32() else { return nil }
        return InlayType.fromValue(value)
    }

    static func readSeparatorStyle(_ reader: inout BinaryReader) -> SeparatorStyle? {
        guard let value = reader.readInt32() else { return nil }
        return SeparatorStyle.fromValue(value)
    }

    static func readSpanLayer(_ reader: inout BinaryReader) -> SpanLayer? {
        guard let value = reader.readInt32() else { return nil }
        return SpanLayer.fromValue(value)
    }

    static func readAutoIndentMode(_ reader: inout BinaryReader) -> AutoIndentMode? {
        guard let value = reader.readInt32() else { return nil }
        return AutoIndentMode.fromValue(value)
    }

    static func readCurrentLineRenderMode(_ reader: inout BinaryReader) -> CurrentLineRenderMode? {
        guard let value = reader.readInt32() else { return nil }
        return CurrentLineRenderMode.fromValue(value)
    }

    static func readFoldArrowMode(_ reader: inout BinaryReader) -> FoldArrowMode? {
        guard let value = reader.readInt32() else { return nil }
        return FoldArrowMode.fromValue(value)
    }

    static func readRangeEffectUnderlineStyle(_ reader: inout BinaryReader) -> RangeEffectUnderlineStyle? {
        guard let value = reader.readInt32() else { return nil }
        return RangeEffectUnderlineStyle.fromValue(value)
    }

    static func readScrollbarMode(_ reader: inout BinaryReader) -> ScrollbarMode? {
        guard let value = reader.readInt32() else { return nil }
        return ScrollbarMode.fromValue(value)
    }

    static func readScrollbarTrackTapMode(_ reader: inout BinaryReader) -> ScrollbarTrackTapMode? {
        guard let value = reader.readInt32() else { return nil }
        return ScrollbarTrackTapMode.fromValue(value)
    }

    static func readWhitespaceRenderMode(_ reader: inout BinaryReader) -> WhitespaceRenderMode? {
        guard let value = reader.readInt32() else { return nil }
        return WhitespaceRenderMode.fromValue(value)
    }

    static func readWrapMode(_ reader: inout BinaryReader) -> WrapMode? {
        guard let value = reader.readInt32() else { return nil }
        return WrapMode.fromValue(value)
    }

    static func readImeContextPolicy(_ reader: inout BinaryReader) -> ImeContextPolicy? {
        guard let value = reader.readInt32() else { return nil }
        return ImeContextPolicy.fromValue(value)
    }

    static func readImeInputContextKind(_ reader: inout BinaryReader) -> ImeInputContextKind? {
        guard let value = reader.readInt32() else { return nil }
        return ImeInputContextKind.fromValue(value)
    }

    static func readImePreeditStorage(_ reader: inout BinaryReader) -> ImePreeditStorage? {
        guard let value = reader.readInt32() else { return nil }
        return ImePreeditStorage.fromValue(value)
    }

    static func readImeScriptClass(_ reader: inout BinaryReader) -> ImeScriptClass? {
        guard let value = reader.readInt32() else { return nil }
        return ImeScriptClass.fromValue(value)
    }

    static func readImeTextModelMode(_ reader: inout BinaryReader) -> ImeTextModelMode? {
        guard let value = reader.readInt32() else { return nil }
        return ImeTextModelMode.fromValue(value)
    }

    static func readImeTextUnit(_ reader: inout BinaryReader) -> ImeTextUnit? {
        guard let value = reader.readInt32() else { return nil }
        return ImeTextUnit.fromValue(value)
    }

    static func readEventType(_ reader: inout BinaryReader) -> EventType? {
        guard let value = reader.readInt32() else { return nil }
        return EventType.fromValue(value)
    }

    static func readGestureType(_ reader: inout BinaryReader) -> GestureType? {
        guard let value = reader.readInt32() else { return nil }
        return GestureType.fromValue(value)
    }

    static func readHitTargetType(_ reader: inout BinaryReader) -> HitTargetType? {
        guard let value = reader.readInt32() else { return nil }
        return HitTargetType.fromValue(value)
    }

    static func readEditorBuiltinCommand(_ reader: inout BinaryReader) -> EditorBuiltinCommand? {
        guard let value = reader.readInt32() else { return nil }
        return EditorBuiltinCommand.fromValue(value)
    }

    static func readSearchStatus(_ reader: inout BinaryReader) -> SearchStatus? {
        guard let value = reader.readInt32() else { return nil }
        return SearchStatus.fromValue(value)
    }

    static func readFoldState(_ reader: inout BinaryReader) -> FoldState? {
        guard let value = reader.readInt32() else { return nil }
        return FoldState.fromValue(value)
    }

    static func readGuideDirection(_ reader: inout BinaryReader) -> GuideDirection? {
        guard let value = reader.readInt32() else { return nil }
        return GuideDirection.fromValue(value)
    }

    static func readGuideStyle(_ reader: inout BinaryReader) -> GuideStyle? {
        guard let value = reader.readInt32() else { return nil }
        return GuideStyle.fromValue(value)
    }

    static func readGuideType(_ reader: inout BinaryReader) -> GuideType? {
        guard let value = reader.readInt32() else { return nil }
        return GuideType.fromValue(value)
    }

    static func readPointerCursorType(_ reader: inout BinaryReader) -> PointerCursorType? {
        guard let value = reader.readInt32() else { return nil }
        return PointerCursorType.fromValue(value)
    }

    static func readRangeEffectKind(_ reader: inout BinaryReader) -> RangeEffectKind? {
        guard let value = reader.readInt32() else { return nil }
        return RangeEffectKind.fromValue(value)
    }

    static func readVisualLineKind(_ reader: inout BinaryReader) -> VisualLineKind? {
        guard let value = reader.readInt32() else { return nil }
        return VisualLineKind.fromValue(value)
    }

    static func readVisualRunType(_ reader: inout BinaryReader) -> VisualRunType? {
        guard let value = reader.readInt32() else { return nil }
        return VisualRunType.fromValue(value)
    }

    static func writeBracketGuideList(_ writer: inout BinaryWriter, _ values: [BracketGuide]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeBracketGuide(&writer, value)
        }
    }

    static func sizeOfBracketGuideList(_ values: [BracketGuide]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfBracketGuide(value)
        }
        return size
    }

    static func writeCodeLensItemList(_ writer: inout BinaryWriter, _ values: [CodeLensItem]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeCodeLensItem(&writer, value)
        }
    }

    static func sizeOfCodeLensItemList(_ values: [CodeLensItem]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfCodeLensItem(value)
        }
        return size
    }

    static func writeDiagnosticList(_ writer: inout BinaryWriter, _ values: [Diagnostic]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeDiagnostic(&writer, value)
        }
    }

    static func sizeOfDiagnosticList(_ values: [Diagnostic]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfDiagnostic(value)
        }
        return size
    }

    static func writeDocumentHighlightList(_ writer: inout BinaryWriter, _ values: [DocumentHighlight]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeDocumentHighlight(&writer, value)
        }
    }

    static func sizeOfDocumentHighlightList(_ values: [DocumentHighlight]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfDocumentHighlight(value)
        }
        return size
    }

    static func writeFlowGuideList(_ writer: inout BinaryWriter, _ values: [FlowGuide]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeFlowGuide(&writer, value)
        }
    }

    static func sizeOfFlowGuideList(_ values: [FlowGuide]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfFlowGuide(value)
        }
        return size
    }

    static func readFoldMarkerRenderItemList(_ reader: inout BinaryReader) -> [FoldMarkerRenderItem]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [FoldMarkerRenderItem] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readFoldMarkerRenderItem(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeFoldRegionList(_ writer: inout BinaryWriter, _ values: [FoldRegion]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeFoldRegion(&writer, value)
        }
    }

    static func sizeOfFoldRegionList(_ values: [FoldRegion]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfFoldRegion(value)
        }
        return size
    }

    static func readGuideSegmentList(_ reader: inout BinaryReader) -> [GuideSegment]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [GuideSegment] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readGuideSegment(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeGutterIconList(_ writer: inout BinaryWriter, _ values: [GutterIcon]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeGutterIcon(&writer, value)
        }
    }

    static func sizeOfGutterIconList(_ values: [GutterIcon]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfGutterIcon(value)
        }
        return size
    }

    static func readGutterIconRenderItemList(_ reader: inout BinaryReader) -> [GutterIconRenderItem]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [GutterIconRenderItem] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readGutterIconRenderItem(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeIndentGuideList(_ writer: inout BinaryWriter, _ values: [IndentGuide]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeIndentGuide(&writer, value)
        }
    }

    static func sizeOfIndentGuideList(_ values: [IndentGuide]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfIndentGuide(value)
        }
        return size
    }

    static func writeInlayHintList(_ writer: inout BinaryWriter, _ values: [InlayHint]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeInlayHint(&writer, value)
        }
    }

    static func sizeOfInlayHintList(_ values: [InlayHint]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfInlayHint(value)
        }
        return size
    }

    static func readKeyBindingList(_ reader: inout BinaryReader) -> [KeyBinding]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [KeyBinding] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readKeyBinding(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeKeyBindingList(_ writer: inout BinaryWriter, _ values: [KeyBinding]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeKeyBinding(&writer, value)
        }
    }

    static func sizeOfKeyBindingList(_ values: [KeyBinding]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfKeyBinding(value)
        }
        return size
    }

    static func writeLinkSpanList(_ writer: inout BinaryWriter, _ values: [LinkSpan]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeLinkSpan(&writer, value)
        }
    }

    static func sizeOfLinkSpanList(_ values: [LinkSpan]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfLinkSpan(value)
        }
        return size
    }

    static func writePhantomTextList(_ writer: inout BinaryWriter, _ values: [PhantomText]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writePhantomText(&writer, value)
        }
    }

    static func sizeOfPhantomTextList(_ values: [PhantomText]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfPhantomText(value)
        }
        return size
    }

    static func readPointFList(_ reader: inout BinaryReader) -> [PointF]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [PointF] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readPointF(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writePointFList(_ writer: inout BinaryWriter, _ values: [PointF]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writePointF(&writer, value)
        }
    }

    static func sizeOfPointFList(_ values: [PointF]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfPointF(value)
        }
        return size
    }

    static func readRangeEffectRenderItemList(_ reader: inout BinaryReader) -> [RangeEffectRenderItem]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [RangeEffectRenderItem] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readRangeEffectRenderItem(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeSeparatorGuideList(_ writer: inout BinaryWriter, _ values: [SeparatorGuide]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeSeparatorGuide(&writer, value)
        }
    }

    static func sizeOfSeparatorGuideList(_ values: [SeparatorGuide]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfSeparatorGuide(value)
        }
        return size
    }

    static func readStyleSpanList(_ reader: inout BinaryReader) -> [StyleSpan]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [StyleSpan] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readStyleSpan(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeStyleSpanList(_ writer: inout BinaryWriter, _ values: [StyleSpan]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeStyleSpan(&writer, value)
        }
    }

    static func sizeOfStyleSpanList(_ values: [StyleSpan]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfStyleSpan(value)
        }
        return size
    }

    static func writeTabStopGroupList(_ writer: inout BinaryWriter, _ values: [TabStopGroup]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeTabStopGroup(&writer, value)
        }
    }

    static func sizeOfTabStopGroupList(_ values: [TabStopGroup]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfTabStopGroup(value)
        }
        return size
    }

    static func readTextChangeList(_ reader: inout BinaryReader) -> [TextChange]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [TextChange] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readTextChange(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func readTextEditList(_ reader: inout BinaryReader) -> [TextEdit]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [TextEdit] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readTextEdit(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeTextEditList(_ writer: inout BinaryWriter, _ values: [TextEdit]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeTextEdit(&writer, value)
        }
    }

    static func sizeOfTextEditList(_ values: [TextEdit]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfTextEdit(value)
        }
        return size
    }

    static func readTextPositionList(_ reader: inout BinaryReader) -> [TextPosition]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [TextPosition] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readTextPosition(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeTextPositionList(_ writer: inout BinaryWriter, _ values: [TextPosition]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeTextPosition(&writer, value)
        }
    }

    static func sizeOfTextPositionList(_ values: [TextPosition]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfTextPosition(value)
        }
        return size
    }

    static func readTextRangeList(_ reader: inout BinaryReader) -> [TextRange]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [TextRange] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readTextRange(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func writeTextRangeList(_ writer: inout BinaryWriter, _ values: [TextRange]) {
        writer.writeInt32(Int32(values.count))
        for value in values {
            writeTextRange(&writer, value)
        }
    }

    static func sizeOfTextRangeList(_ values: [TextRange]) -> Int {
        var size = 4
        for value in values {
            size += sizeOfTextRange(value)
        }
        return size
    }

    static func readVisualLineList(_ reader: inout BinaryReader) -> [VisualLine]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [VisualLine] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readVisualLine(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func readVisualRunList(_ reader: inout BinaryReader) -> [VisualRun]? {
        guard let countValue = reader.readInt32(), countValue >= 0, Int(countValue) <= reader.remaining else { return nil }
        var values: [VisualRun] = []
        values.reserveCapacity(Int(countValue))
        for _ in 0..<Int(countValue) {
            guard let value = readVisualRun(&reader) else { return nil }
            values.append(value)
        }
        return values
    }

    static func readEditorActionResult(_ reader: inout BinaryReader) -> EditorActionResult? {
        guard let handled = reader.readBoolI32() else { return nil }
        guard let needs_redraw = reader.readBoolI32() else { return nil }
        guard let source = readEditorActionSource(&reader) else { return nil }
        guard let text_change_kind = readTextChangeKind(&reader) else { return nil }
        guard let content_changed = reader.readBoolI32() else { return nil }
        guard let cursor_changed = reader.readBoolI32() else { return nil }
        guard let selection_changed = reader.readBoolI32() else { return nil }
        guard let scroll_changed = reader.readBoolI32() else { return nil }
        guard let scale_changed = reader.readBoolI32() else { return nil }
        guard let pointer_cursor_changed = reader.readBoolI32() else { return nil }
        guard let composition_changed = reader.readBoolI32() else { return nil }
        guard let decoration_changed = reader.readBoolI32() else { return nil }
        guard let needs_ime_sync = reader.readBoolI32() else { return nil }
        guard let needs_edge_scroll = reader.readBoolI32() else { return nil }
        guard let needs_fling = reader.readBoolI32() else { return nil }
        guard let needs_animation = reader.readBoolI32() else { return nil }
        guard let is_handle_drag = reader.readBoolI32() else { return nil }
        guard let changes = readTextChangeList(&reader) else { return nil }
        guard let cursor_before = readTextPosition(&reader) else { return nil }
        guard let cursor_after = readTextPosition(&reader) else { return nil }
        guard let has_selection_before = reader.readBoolI32() else { return nil }
        guard let has_selection_after = reader.readBoolI32() else { return nil }
        guard let selection_before = readTextRange(&reader) else { return nil }
        guard let selection_after = readTextRange(&reader) else { return nil }
        guard let scroll_x_before = reader.readFloat32() else { return nil }
        guard let scroll_y_before = reader.readFloat32() else { return nil }
        guard let scroll_x_after = reader.readFloat32() else { return nil }
        guard let scroll_y_after = reader.readFloat32() else { return nil }
        guard let scale_before = reader.readFloat32() else { return nil }
        guard let scale_after = reader.readFloat32() else { return nil }
        guard let pointer_cursor_before = readPointerCursorType(&reader) else { return nil }
        guard let pointer_cursor_after = readPointerCursorType(&reader) else { return nil }
        guard let ime_sync = readImeSyncSnapshot(&reader) else { return nil }
        guard let gesture_type = readGestureType(&reader) else { return nil }
        guard let gesture_event_type = readEventType(&reader) else { return nil }
        guard let tap_point = readPointF(&reader) else { return nil }
        guard let hit_target = readHitTarget(&reader) else { return nil }
        guard let modifiers = reader.readInt32() else { return nil }
        guard let command = reader.readInt32() else { return nil }
        return EditorActionResult(handled: handled, needs_redraw: needs_redraw, source: source, text_change_kind: text_change_kind, content_changed: content_changed, cursor_changed: cursor_changed, selection_changed: selection_changed, scroll_changed: scroll_changed, scale_changed: scale_changed, pointer_cursor_changed: pointer_cursor_changed, composition_changed: composition_changed, decoration_changed: decoration_changed, needs_ime_sync: needs_ime_sync, needs_edge_scroll: needs_edge_scroll, needs_fling: needs_fling, needs_animation: needs_animation, is_handle_drag: is_handle_drag, changes: changes, cursor_before: cursor_before, cursor_after: cursor_after, has_selection_before: has_selection_before, has_selection_after: has_selection_after, selection_before: selection_before, selection_after: selection_after, scroll_x_before: scroll_x_before, scroll_y_before: scroll_y_before, scroll_x_after: scroll_x_after, scroll_y_after: scroll_y_after, scale_before: scale_before, scale_after: scale_after, pointer_cursor_before: pointer_cursor_before, pointer_cursor_after: pointer_cursor_after, ime_sync: ime_sync, gesture_type: gesture_type, gesture_event_type: gesture_event_type, tap_point: tap_point, hit_target: hit_target, modifiers: modifiers, command: command)
    }

    static func decodeEditorActionResult(_ data: Data) -> EditorActionResult? {
        return data.withUnsafeBytes { raw in
            decodeEditorActionResult(raw)
        }
    }

    static func decodeEditorActionResult(_ data: UnsafeRawBufferPointer) -> EditorActionResult? {
        var reader = BinaryReader(data)
        return readEditorActionResult(&reader)
    }

    static func writeBracketGuide(_ writer: inout BinaryWriter, _ value: BracketGuide) {
        writeTextPosition(&writer, value.parent)
        writeTextPosition(&writer, value.end)
        writeTextPositionList(&writer, value.children)
    }

    static func sizeOfBracketGuide(_ value: BracketGuide) -> Int {
        sizeOfTextPosition(value.parent) + sizeOfTextPosition(value.end) + sizeOfTextPositionList(value.children)
    }

    static func writeCodeLensItem(_ writer: inout BinaryWriter, _ value: CodeLensItem) {
        writer.writeInt32(value.column)
        writer.writeInt32(value.command_id)
        writer.writeUtf8String(value.text)
    }

    static func sizeOfCodeLensItem(_ value: CodeLensItem) -> Int {
        4 + 4 + sizeOfUtf8String(value.text)
    }

    static func writeDiagnostic(_ writer: inout BinaryWriter, _ value: Diagnostic) {
        writer.writeInt32(value.column)
        writer.writeInt32(value.length)
        writer.writeInt32(value.severity.rawValue)
    }

    static func sizeOfDiagnostic(_ value: Diagnostic) -> Int {
        4 + 4 + 4
    }

    static func writeDocumentHighlight(_ writer: inout BinaryWriter, _ value: DocumentHighlight) {
        writer.writeInt32(value.column)
        writer.writeInt32(value.length)
        writer.writeInt32(value.kind.rawValue)
    }

    static func sizeOfDocumentHighlight(_ value: DocumentHighlight) -> Int {
        4 + 4 + 4
    }

    static func writeFlowGuide(_ writer: inout BinaryWriter, _ value: FlowGuide) {
        writeTextPosition(&writer, value.start)
        writeTextPosition(&writer, value.end)
    }

    static func sizeOfFlowGuide(_ value: FlowGuide) -> Int {
        sizeOfTextPosition(value.start) + sizeOfTextPosition(value.end)
    }

    static func writeFoldRegion(_ writer: inout BinaryWriter, _ value: FoldRegion) {
        writer.writeInt32(value.start_line)
        writer.writeInt32(value.end_line)
        writer.writeBoolU8(value.collapsed)
    }

    static func sizeOfFoldRegion(_ value: FoldRegion) -> Int {
        4 + 4 + 1
    }

    static func writeGutterIcon(_ writer: inout BinaryWriter, _ value: GutterIcon) {
        writer.writeInt32(value.icon_id)
    }

    static func sizeOfGutterIcon(_ value: GutterIcon) -> Int {
        4
    }

    static func writeIndentGuide(_ writer: inout BinaryWriter, _ value: IndentGuide) {
        writeTextPosition(&writer, value.start)
        writeTextPosition(&writer, value.end)
    }

    static func sizeOfIndentGuide(_ value: IndentGuide) -> Int {
        sizeOfTextPosition(value.start) + sizeOfTextPosition(value.end)
    }

    static func writeInlayHint(_ writer: inout BinaryWriter, _ value: InlayHint) {
        writer.writeInt32(value.type.rawValue)
        writer.writeInt32(value.column)
        writer.writeInt32(value.int_value)
        writer.writeUtf8String(value.text)
    }

    static func sizeOfInlayHint(_ value: InlayHint) -> Int {
        4 + 4 + 4 + sizeOfUtf8String(value.text)
    }

    static func writeLinkSpan(_ writer: inout BinaryWriter, _ value: LinkSpan) {
        writer.writeInt32(value.column)
        writer.writeInt32(value.length)
        writer.writeUtf8String(value.target)
    }

    static func sizeOfLinkSpan(_ value: LinkSpan) -> Int {
        4 + 4 + sizeOfUtf8String(value.target)
    }

    static func writePhantomText(_ writer: inout BinaryWriter, _ value: PhantomText) {
        writer.writeInt32(value.column)
        writer.writeUtf8String(value.text)
    }

    static func sizeOfPhantomText(_ value: PhantomText) -> Int {
        4 + sizeOfUtf8String(value.text)
    }

    static func writeSeparatorGuide(_ writer: inout BinaryWriter, _ value: SeparatorGuide) {
        writer.writeInt32(value.line)
        writer.writeInt32(value.style.rawValue)
        writer.writeInt32(value.count)
        writer.writeInt32(value.text_end_column)
    }

    static func sizeOfSeparatorGuide(_ value: SeparatorGuide) -> Int {
        4 + 4 + 4 + 4
    }

    static func readStyleSpan(_ reader: inout BinaryReader) -> StyleSpan? {
        guard let column = reader.readInt32() else { return nil }
        guard let length = reader.readInt32() else { return nil }
        guard let style_id = reader.readInt32() else { return nil }
        return StyleSpan(column: column, length: length, style_id: style_id)
    }

    static func decodeStyleSpan(_ data: Data) -> StyleSpan? {
        return data.withUnsafeBytes { raw in
            decodeStyleSpan(raw)
        }
    }

    static func decodeStyleSpan(_ data: UnsafeRawBufferPointer) -> StyleSpan? {
        var reader = BinaryReader(data)
        return readStyleSpan(&reader)
    }

    static func writeStyleSpan(_ writer: inout BinaryWriter, _ value: StyleSpan) {
        writer.writeInt32(value.column)
        writer.writeInt32(value.length)
        writer.writeInt32(value.style_id)
    }

    static func sizeOfStyleSpan(_ value: StyleSpan) -> Int {
        4 + 4 + 4
    }

    static func readTextStyle(_ reader: inout BinaryReader) -> TextStyle? {
        guard let color = reader.readInt32() else { return nil }
        guard let background_color = reader.readInt32() else { return nil }
        guard let font_style = reader.readInt32() else { return nil }
        return TextStyle(color: color, background_color: background_color, font_style: font_style)
    }

    static func decodeTextStyle(_ data: Data) -> TextStyle? {
        return data.withUnsafeBytes { raw in
            decodeTextStyle(raw)
        }
    }

    static func decodeTextStyle(_ data: UnsafeRawBufferPointer) -> TextStyle? {
        var reader = BinaryReader(data)
        return readTextStyle(&reader)
    }

    static func writeTextStyle(_ writer: inout BinaryWriter, _ value: TextStyle) {
        writer.writeInt32(value.color)
        writer.writeInt32(value.background_color)
        writer.writeInt32(value.font_style)
    }

    static func sizeOfTextStyle(_ value: TextStyle) -> Int {
        4 + 4 + 4
    }

    static func writeEditorOptions(_ writer: inout BinaryWriter, _ value: EditorOptions) {
        writer.writeFloat32(value.touch_slop)
        writer.writeInt64(value.double_tap_timeout)
        writer.writeInt64(value.long_press_ms)
        writer.writeFloat32(value.fling_friction)
        writer.writeFloat32(value.fling_min_velocity)
        writer.writeFloat32(value.fling_max_velocity)
        writer.writeInt64(value.max_undo_stack_size)
        writer.writeInt64(value.key_chord_timeout_ms)
        writer.writeBoolU8(value.reveal_selection_end_on_select_all)
    }

    static func sizeOfEditorOptions(_ value: EditorOptions) -> Int {
        4 + 8 + 8 + 4 + 4 + 4 + 8 + 8 + 1
    }

    static func writeEditorRangeEffectStyles(_ writer: inout BinaryWriter, _ value: EditorRangeEffectStyles) {
        writeRangeEffectStyle(&writer, value.selection)
        writeRangeEffectStyle(&writer, value.search_match)
        writeRangeEffectStyle(&writer, value.search_current)
        writeRangeEffectStyle(&writer, value.document_highlight_text)
        writeRangeEffectStyle(&writer, value.document_highlight_read)
        writeRangeEffectStyle(&writer, value.document_highlight_write)
        writeRangeEffectStyle(&writer, value.linked_editing_active)
        writeRangeEffectStyle(&writer, value.linked_editing_inactive)
        writeRangeEffectStyle(&writer, value.ime_composition)
        writeRangeEffectStyle(&writer, value.bracket_match)
        writeRangeEffectStyle(&writer, value.diagnostic_error)
        writeRangeEffectStyle(&writer, value.diagnostic_warning)
        writeRangeEffectStyle(&writer, value.diagnostic_info)
        writeRangeEffectStyle(&writer, value.diagnostic_hint)
    }

    static func sizeOfEditorRangeEffectStyles(_ value: EditorRangeEffectStyles) -> Int {
        sizeOfRangeEffectStyle(value.selection) + sizeOfRangeEffectStyle(value.search_match) + sizeOfRangeEffectStyle(value.search_current) + sizeOfRangeEffectStyle(value.document_highlight_text) + sizeOfRangeEffectStyle(value.document_highlight_read) + sizeOfRangeEffectStyle(value.document_highlight_write) + sizeOfRangeEffectStyle(value.linked_editing_active) + sizeOfRangeEffectStyle(value.linked_editing_inactive) + sizeOfRangeEffectStyle(value.ime_composition) + sizeOfRangeEffectStyle(value.bracket_match) + sizeOfRangeEffectStyle(value.diagnostic_error) + sizeOfRangeEffectStyle(value.diagnostic_warning) + sizeOfRangeEffectStyle(value.diagnostic_info) + sizeOfRangeEffectStyle(value.diagnostic_hint)
    }

    static func writeEditorRenderColors(_ writer: inout BinaryWriter, _ value: EditorRenderColors) {
        writer.writeInt32(value.text_foreground)
        writer.writeInt32(value.link_foreground)
        writer.writeInt32(value.active_link_foreground)
        writer.writeInt32(value.codelens_foreground)
        writer.writeInt32(value.active_codelens_foreground)
    }

    static func sizeOfEditorRenderColors(_ value: EditorRenderColors) -> Int {
        4 + 4 + 4 + 4 + 4
    }

    static func writeHandleConfig(_ writer: inout BinaryWriter, _ value: HandleConfig) {
        writeHandleHitArea(&writer, value.start_hit_area)
        writeHandleHitArea(&writer, value.end_hit_area)
    }

    static func sizeOfHandleConfig(_ value: HandleConfig) -> Int {
        sizeOfHandleHitArea(value.start_hit_area) + sizeOfHandleHitArea(value.end_hit_area)
    }

    static func readHandleHitArea(_ reader: inout BinaryReader) -> HandleHitArea? {
        guard let left = reader.readFloat32() else { return nil }
        guard let top = reader.readFloat32() else { return nil }
        guard let right = reader.readFloat32() else { return nil }
        guard let bottom = reader.readFloat32() else { return nil }
        return HandleHitArea(left: left, top: top, right: right, bottom: bottom)
    }

    static func decodeHandleHitArea(_ data: Data) -> HandleHitArea? {
        return data.withUnsafeBytes { raw in
            decodeHandleHitArea(raw)
        }
    }

    static func decodeHandleHitArea(_ data: UnsafeRawBufferPointer) -> HandleHitArea? {
        var reader = BinaryReader(data)
        return readHandleHitArea(&reader)
    }

    static func writeHandleHitArea(_ writer: inout BinaryWriter, _ value: HandleHitArea) {
        writer.writeFloat32(value.left)
        writer.writeFloat32(value.top)
        writer.writeFloat32(value.right)
        writer.writeFloat32(value.bottom)
    }

    static func sizeOfHandleHitArea(_ value: HandleHitArea) -> Int {
        4 + 4 + 4 + 4
    }

    static func readRangeEffectStyle(_ reader: inout BinaryReader) -> RangeEffectStyle? {
        guard let foreground_color = reader.readInt32() else { return nil }
        guard let background_color = reader.readInt32() else { return nil }
        guard let border_color = reader.readInt32() else { return nil }
        guard let underline_color = reader.readInt32() else { return nil }
        guard let underline_style = readRangeEffectUnderlineStyle(&reader) else { return nil }
        return RangeEffectStyle(foreground_color: foreground_color, background_color: background_color, border_color: border_color, underline_color: underline_color, underline_style: underline_style)
    }

    static func decodeRangeEffectStyle(_ data: Data) -> RangeEffectStyle? {
        return data.withUnsafeBytes { raw in
            decodeRangeEffectStyle(raw)
        }
    }

    static func decodeRangeEffectStyle(_ data: UnsafeRawBufferPointer) -> RangeEffectStyle? {
        var reader = BinaryReader(data)
        return readRangeEffectStyle(&reader)
    }

    static func writeRangeEffectStyle(_ writer: inout BinaryWriter, _ value: RangeEffectStyle) {
        writer.writeInt32(value.foreground_color)
        writer.writeInt32(value.background_color)
        writer.writeInt32(value.border_color)
        writer.writeInt32(value.underline_color)
        writer.writeInt32(value.underline_style.rawValue)
    }

    static func sizeOfRangeEffectStyle(_ value: RangeEffectStyle) -> Int {
        4 + 4 + 4 + 4 + 4
    }

    static func writeScrollbarConfig(_ writer: inout BinaryWriter, _ value: ScrollbarConfig) {
        writer.writeFloat32(value.thickness)
        writer.writeFloat32(value.min_thumb)
        writer.writeFloat32(value.thumb_hit_padding)
        writer.writeInt32(value.mode.rawValue)
        writer.writeBoolU8(value.thumb_draggable)
        writer.writeInt32(value.track_tap_mode.rawValue)
        writer.writeUInt16(UInt16(value.fade_delay_ms))
        writer.writeUInt16(UInt16(value.fade_duration_ms))
    }

    static func sizeOfScrollbarConfig(_ value: ScrollbarConfig) -> Int {
        4 + 4 + 4 + 4 + 1 + 4 + 2 + 2
    }

    static func readIntRange(_ reader: inout BinaryReader) -> IntRange? {
        guard let start = reader.readInt32() else { return nil }
        guard let end = reader.readInt32() else { return nil }
        return IntRange(start: start, end: end)
    }

    static func decodeIntRange(_ data: Data) -> IntRange? {
        return data.withUnsafeBytes { raw in
            decodeIntRange(raw)
        }
    }

    static func decodeIntRange(_ data: UnsafeRawBufferPointer) -> IntRange? {
        var reader = BinaryReader(data)
        return readIntRange(&reader)
    }

    static func writeIntRange(_ writer: inout BinaryWriter, _ value: IntRange) {
        writer.writeInt32(value.start)
        writer.writeInt32(value.end)
    }

    static func sizeOfIntRange(_ value: IntRange) -> Int {
        4 + 4
    }

    static func readPointF(_ reader: inout BinaryReader) -> PointF? {
        guard let x = reader.readFloat32() else { return nil }
        guard let y = reader.readFloat32() else { return nil }
        return PointF(x: x, y: y)
    }

    static func decodePointF(_ data: Data) -> PointF? {
        return data.withUnsafeBytes { raw in
            decodePointF(raw)
        }
    }

    static func decodePointF(_ data: UnsafeRawBufferPointer) -> PointF? {
        var reader = BinaryReader(data)
        return readPointF(&reader)
    }

    static func writePointF(_ writer: inout BinaryWriter, _ value: PointF) {
        writer.writeFloat32(value.x)
        writer.writeFloat32(value.y)
    }

    static func sizeOfPointF(_ value: PointF) -> Int {
        4 + 4
    }

    static func readRect(_ reader: inout BinaryReader) -> Rect? {
        guard let origin = readPointF(&reader) else { return nil }
        guard let width = reader.readFloat32() else { return nil }
        guard let height = reader.readFloat32() else { return nil }
        return Rect(origin: origin, width: width, height: height)
    }

    static func decodeRect(_ data: Data) -> Rect? {
        return data.withUnsafeBytes { raw in
            decodeRect(raw)
        }
    }

    static func decodeRect(_ data: UnsafeRawBufferPointer) -> Rect? {
        var reader = BinaryReader(data)
        return readRect(&reader)
    }

    static func writeRect(_ writer: inout BinaryWriter, _ value: Rect) {
        writePointF(&writer, value.origin)
        writer.writeFloat32(value.width)
        writer.writeFloat32(value.height)
    }

    static func sizeOfRect(_ value: Rect) -> Int {
        sizeOfPointF(value.origin) + 4 + 4
    }

    static func readSize(_ reader: inout BinaryReader) -> Size? {
        guard let width = reader.readFloat32() else { return nil }
        guard let height = reader.readFloat32() else { return nil }
        return Size(width: width, height: height)
    }

    static func decodeSize(_ data: Data) -> Size? {
        return data.withUnsafeBytes { raw in
            decodeSize(raw)
        }
    }

    static func decodeSize(_ data: UnsafeRawBufferPointer) -> Size? {
        var reader = BinaryReader(data)
        return readSize(&reader)
    }

    static func writeSize(_ writer: inout BinaryWriter, _ value: Size) {
        writer.writeFloat32(value.width)
        writer.writeFloat32(value.height)
    }

    static func sizeOfSize(_ value: Size) -> Int {
        4 + 4
    }

    static func readTextChange(_ reader: inout BinaryReader) -> TextChange? {
        guard let range = readTextRange(&reader) else { return nil }
        guard let new_text = reader.readUtf8String() else { return nil }
        return TextChange(range: range, new_text: new_text)
    }

    static func decodeTextChange(_ data: Data) -> TextChange? {
        return data.withUnsafeBytes { raw in
            decodeTextChange(raw)
        }
    }

    static func decodeTextChange(_ data: UnsafeRawBufferPointer) -> TextChange? {
        var reader = BinaryReader(data)
        return readTextChange(&reader)
    }

    static func readTextEdit(_ reader: inout BinaryReader) -> TextEdit? {
        guard let range = readTextRange(&reader) else { return nil }
        guard let new_text = reader.readUtf8String() else { return nil }
        return TextEdit(range: range, new_text: new_text)
    }

    static func decodeTextEdit(_ data: Data) -> TextEdit? {
        return data.withUnsafeBytes { raw in
            decodeTextEdit(raw)
        }
    }

    static func decodeTextEdit(_ data: UnsafeRawBufferPointer) -> TextEdit? {
        var reader = BinaryReader(data)
        return readTextEdit(&reader)
    }

    static func writeTextEdit(_ writer: inout BinaryWriter, _ value: TextEdit) {
        writeTextRange(&writer, value.range)
        writer.writeUtf8String(value.new_text)
    }

    static func sizeOfTextEdit(_ value: TextEdit) -> Int {
        sizeOfTextRange(value.range) + sizeOfUtf8String(value.new_text)
    }

    static func readTextPosition(_ reader: inout BinaryReader) -> TextPosition? {
        guard let line = reader.readInt32() else { return nil }
        guard let column = reader.readInt32() else { return nil }
        return TextPosition(line: line, column: column)
    }

    static func decodeTextPosition(_ data: Data) -> TextPosition? {
        return data.withUnsafeBytes { raw in
            decodeTextPosition(raw)
        }
    }

    static func decodeTextPosition(_ data: UnsafeRawBufferPointer) -> TextPosition? {
        var reader = BinaryReader(data)
        return readTextPosition(&reader)
    }

    static func writeTextPosition(_ writer: inout BinaryWriter, _ value: TextPosition) {
        writer.writeInt32(value.line)
        writer.writeInt32(value.column)
    }

    static func sizeOfTextPosition(_ value: TextPosition) -> Int {
        4 + 4
    }

    static func readTextRange(_ reader: inout BinaryReader) -> TextRange? {
        guard let start = readTextPosition(&reader) else { return nil }
        guard let end = readTextPosition(&reader) else { return nil }
        return TextRange(start: start, end: end)
    }

    static func decodeTextRange(_ data: Data) -> TextRange? {
        return data.withUnsafeBytes { raw in
            decodeTextRange(raw)
        }
    }

    static func decodeTextRange(_ data: UnsafeRawBufferPointer) -> TextRange? {
        var reader = BinaryReader(data)
        return readTextRange(&reader)
    }

    static func writeTextRange(_ writer: inout BinaryWriter, _ value: TextRange) {
        writeTextPosition(&writer, value.start)
        writeTextPosition(&writer, value.end)
    }

    static func sizeOfTextRange(_ value: TextRange) -> Int {
        sizeOfTextPosition(value.start) + sizeOfTextPosition(value.end)
    }

    static func writeImeDocumentTextReplacement(_ writer: inout BinaryWriter, _ value: ImeDocumentTextReplacement) {
        writer.writeInt32(value.start_offset)
        writer.writeInt32(value.end_offset)
        writer.writeUtf8String(value.text)
        writer.writeInt32(value.cursor_offset)
        writer.writeInt32(value.script_class.rawValue)
    }

    static func sizeOfImeDocumentTextReplacement(_ value: ImeDocumentTextReplacement) -> Int {
        4 + 4 + sizeOfUtf8String(value.text) + 4 + 4
    }

    static func readImeInputContext(_ reader: inout BinaryReader) -> ImeInputContext? {
        guard let id = reader.readInt64() else { return nil }
        guard let revision = reader.readInt32() else { return nil }
        guard let document_start_offset = reader.readInt32() else { return nil }
        guard let text = reader.readUtf8String() else { return nil }
        guard let selection = readImeOffsetRange(&reader) else { return nil }
        guard let has_composition = reader.readBoolI32() else { return nil }
        guard let composition = readImeOffsetRange(&reader) else { return nil }
        guard let kind = readImeInputContextKind(&reader) else { return nil }
        return ImeInputContext(id: id, revision: revision, document_start_offset: document_start_offset, text: text, selection: selection, has_composition: has_composition, composition: composition, kind: kind)
    }

    static func decodeImeInputContext(_ data: Data) -> ImeInputContext? {
        return data.withUnsafeBytes { raw in
            decodeImeInputContext(raw)
        }
    }

    static func decodeImeInputContext(_ data: UnsafeRawBufferPointer) -> ImeInputContext? {
        var reader = BinaryReader(data)
        return readImeInputContext(&reader)
    }

    static func writeImeInputContextTextReplacement(_ writer: inout BinaryWriter, _ value: ImeInputContextTextReplacement) {
        writer.writeInt32(value.start_offset)
        writer.writeInt32(value.end_offset)
        writer.writeUtf8String(value.text)
        writer.writeInt32(value.cursor_offset)
        writer.writeInt32(value.script_class.rawValue)
    }

    static func sizeOfImeInputContextTextReplacement(_ value: ImeInputContextTextReplacement) -> Int {
        4 + 4 + sizeOfUtf8String(value.text) + 4 + 4
    }

    static func writeImeInputStateTextReplacement(_ writer: inout BinaryWriter, _ value: ImeInputStateTextReplacement) {
        writer.writeInt64(value.context_id)
        writer.writeInt32(value.document_start_offset)
        writer.writeInt32(value.start_offset)
        writer.writeInt32(value.end_offset)
        writer.writeUtf8String(value.text)
        writer.writeInt32(value.cursor_offset)
        writer.writeInt32(value.script_class.rawValue)
    }

    static func sizeOfImeInputStateTextReplacement(_ value: ImeInputStateTextReplacement) -> Int {
        8 + 4 + 4 + 4 + sizeOfUtf8String(value.text) + 4 + 4
    }

    static func readImeOffsetRange(_ reader: inout BinaryReader) -> ImeOffsetRange? {
        guard let start = reader.readInt32() else { return nil }
        guard let end = reader.readInt32() else { return nil }
        return ImeOffsetRange(start: start, end: end)
    }

    static func decodeImeOffsetRange(_ data: Data) -> ImeOffsetRange? {
        return data.withUnsafeBytes { raw in
            decodeImeOffsetRange(raw)
        }
    }

    static func decodeImeOffsetRange(_ data: UnsafeRawBufferPointer) -> ImeOffsetRange? {
        var reader = BinaryReader(data)
        return readImeOffsetRange(&reader)
    }

    static func writeImeOffsetRange(_ writer: inout BinaryWriter, _ value: ImeOffsetRange) {
        writer.writeInt32(value.start)
        writer.writeInt32(value.end)
    }

    static func sizeOfImeOffsetRange(_ value: ImeOffsetRange) -> Int {
        4 + 4
    }

    static func readImeSyncSnapshot(_ reader: inout BinaryReader) -> ImeSyncSnapshot? {
        guard let cursor = readTextPosition(&reader) else { return nil }
        guard let selection = readTextRange(&reader) else { return nil }
        guard let has_selection = reader.readBoolI32() else { return nil }
        guard let has_composing_session = reader.readBoolI32() else { return nil }
        guard let has_visible_composition_range = reader.readBoolI32() else { return nil }
        guard let visible_composition_range = readTextRange(&reader) else { return nil }
        guard let has_platform_marked_range = reader.readBoolI32() else { return nil }
        guard let platform_marked_range = readTextRange(&reader) else { return nil }
        guard let preedit_storage = readImePreeditStorage(&reader) else { return nil }
        guard let context_policy = readImeContextPolicy(&reader) else { return nil }
        guard let clear_platform_preedit = reader.readBoolI32() else { return nil }
        return ImeSyncSnapshot(cursor: cursor, selection: selection, has_selection: has_selection, has_composing_session: has_composing_session, has_visible_composition_range: has_visible_composition_range, visible_composition_range: visible_composition_range, has_platform_marked_range: has_platform_marked_range, platform_marked_range: platform_marked_range, preedit_storage: preedit_storage, context_policy: context_policy, clear_platform_preedit: clear_platform_preedit)
    }

    static func decodeImeSyncSnapshot(_ data: Data) -> ImeSyncSnapshot? {
        return data.withUnsafeBytes { raw in
            decodeImeSyncSnapshot(raw)
        }
    }

    static func decodeImeSyncSnapshot(_ data: UnsafeRawBufferPointer) -> ImeSyncSnapshot? {
        var reader = BinaryReader(data)
        return readImeSyncSnapshot(&reader)
    }

    static func writeImeTextModelDelta(_ writer: inout BinaryWriter, _ value: ImeTextModelDelta) {
        writer.writeInt32(value.mode.rawValue)
        writer.writeInt64(value.context_id)
        writer.writeInt32(value.document_start_offset)
        writer.writeUtf8String(value.old_text)
        writeImeOffsetRange(&writer, value.delta)
        writer.writeUtf8String(value.delta_text)
        writeImeOffsetRange(&writer, value.selection)
        writeImeOffsetRange(&writer, value.composition)
        writer.writeInt32(value.script_class.rawValue)
    }

    static func sizeOfImeTextModelDelta(_ value: ImeTextModelDelta) -> Int {
        4 + 8 + 4 + sizeOfUtf8String(value.old_text) + sizeOfImeOffsetRange(value.delta) + sizeOfUtf8String(value.delta_text) + sizeOfImeOffsetRange(value.selection) + sizeOfImeOffsetRange(value.composition) + 4
    }

    static func writeImeTextModelState(_ writer: inout BinaryWriter, _ value: ImeTextModelState) {
        writer.writeInt32(value.mode.rawValue)
        writer.writeInt64(value.context_id)
        writer.writeInt32(value.document_start_offset)
        writer.writeUtf8String(value.text)
        writeImeOffsetRange(&writer, value.selection)
        writeImeOffsetRange(&writer, value.composition)
        writer.writeInt32(value.script_class.rawValue)
    }

    static func sizeOfImeTextModelState(_ value: ImeTextModelState) -> Int {
        4 + 8 + 4 + sizeOfUtf8String(value.text) + sizeOfImeOffsetRange(value.selection) + sizeOfImeOffsetRange(value.composition) + 4
    }

    static func writeImeTextReplacement(_ writer: inout BinaryWriter, _ value: ImeTextReplacement) {
        writeTextRange(&writer, value.range)
        writer.writeUtf8String(value.text)
        writer.writeInt32(value.script_class.rawValue)
    }

    static func sizeOfImeTextReplacement(_ value: ImeTextReplacement) -> Int {
        sizeOfTextRange(value.range) + sizeOfUtf8String(value.text) + 4
    }

    static func writeGestureEvent(_ writer: inout BinaryWriter, _ value: GestureEvent) {
        writer.writeInt32(value.type.rawValue)
        writePointFList(&writer, value.points)
        writer.writeInt32(value.modifiers)
        writer.writeFloat32(value.wheel_delta_x)
        writer.writeFloat32(value.wheel_delta_y)
        writer.writeFloat32(value.direct_scale)
    }

    static func sizeOfGestureEvent(_ value: GestureEvent) -> Int {
        4 + sizeOfPointFList(value.points) + 4 + 4 + 4 + 4
    }

    static func readHitTarget(_ reader: inout BinaryReader) -> HitTarget? {
        guard let type = readHitTargetType(&reader) else { return nil }
        guard let line = reader.readInt32() else { return nil }
        guard let column = reader.readInt32() else { return nil }
        guard let icon_id = reader.readInt32() else { return nil }
        guard let color_value = reader.readInt32() else { return nil }
        return HitTarget(type: type, line: line, column: column, icon_id: icon_id, color_value: color_value)
    }

    static func decodeHitTarget(_ data: Data) -> HitTarget? {
        return data.withUnsafeBytes { raw in
            decodeHitTarget(raw)
        }
    }

    static func decodeHitTarget(_ data: UnsafeRawBufferPointer) -> HitTarget? {
        var reader = BinaryReader(data)
        return readHitTarget(&reader)
    }

    static func readKeyBinding(_ reader: inout BinaryReader) -> KeyBinding? {
        guard let first = readKeyChord(&reader) else { return nil }
        guard let second = readKeyChord(&reader) else { return nil }
        guard let command = reader.readInt32() else { return nil }
        return KeyBinding(first: first, second: second, command: command)
    }

    static func decodeKeyBinding(_ data: Data) -> KeyBinding? {
        return data.withUnsafeBytes { raw in
            decodeKeyBinding(raw)
        }
    }

    static func decodeKeyBinding(_ data: UnsafeRawBufferPointer) -> KeyBinding? {
        var reader = BinaryReader(data)
        return readKeyBinding(&reader)
    }

    static func writeKeyBinding(_ writer: inout BinaryWriter, _ value: KeyBinding) {
        writeKeyChord(&writer, value.first)
        writeKeyChord(&writer, value.second)
        writer.writeInt32(value.command)
    }

    static func sizeOfKeyBinding(_ value: KeyBinding) -> Int {
        sizeOfKeyChord(value.first) + sizeOfKeyChord(value.second) + 4
    }

    static func readKeyChord(_ reader: inout BinaryReader) -> KeyChord? {
        guard let modifiers = reader.readUInt8().map(Int32.init) else { return nil }
        guard let key_code = reader.readUInt16().map(Int32.init) else { return nil }
        return KeyChord(modifiers: modifiers, key_code: key_code)
    }

    static func decodeKeyChord(_ data: Data) -> KeyChord? {
        return data.withUnsafeBytes { raw in
            decodeKeyChord(raw)
        }
    }

    static func decodeKeyChord(_ data: UnsafeRawBufferPointer) -> KeyChord? {
        var reader = BinaryReader(data)
        return readKeyChord(&reader)
    }

    static func writeKeyChord(_ writer: inout BinaryWriter, _ value: KeyChord) {
        writer.writeUInt8(UInt8(value.modifiers))
        writer.writeUInt16(UInt16(value.key_code))
    }

    static func sizeOfKeyChord(_ value: KeyChord) -> Int {
        1 + 2
    }

    static func writeLinkedEditingModel(_ writer: inout BinaryWriter, _ value: LinkedEditingModel) {
        writeTabStopGroupList(&writer, value.groups)
    }

    static func sizeOfLinkedEditingModel(_ value: LinkedEditingModel) -> Int {
        sizeOfTabStopGroupList(value.groups)
    }

    static func writeTabStopGroup(_ writer: inout BinaryWriter, _ value: TabStopGroup) {
        writer.writeInt32(value.index)
        writeTextRangeList(&writer, value.ranges)
        writer.writeUtf8String(value.default_text)
    }

    static func sizeOfTabStopGroup(_ value: TabStopGroup) -> Int {
        4 + sizeOfTextRangeList(value.ranges) + sizeOfUtf8String(value.default_text)
    }

    static func readSearchOptions(_ reader: inout BinaryReader) -> SearchOptions? {
        guard let case_sensitive = reader.readBoolI32() else { return nil }
        guard let whole_word = reader.readBoolI32() else { return nil }
        guard let use_regex = reader.readBoolI32() else { return nil }
        guard let wrap_around = reader.readBoolI32() else { return nil }
        guard let max_matches = reader.readInt32() else { return nil }
        return SearchOptions(case_sensitive: case_sensitive, whole_word: whole_word, use_regex: use_regex, wrap_around: wrap_around, max_matches: max_matches)
    }

    static func decodeSearchOptions(_ data: Data) -> SearchOptions? {
        return data.withUnsafeBytes { raw in
            decodeSearchOptions(raw)
        }
    }

    static func decodeSearchOptions(_ data: UnsafeRawBufferPointer) -> SearchOptions? {
        var reader = BinaryReader(data)
        return readSearchOptions(&reader)
    }

    static func writeSearchOptions(_ writer: inout BinaryWriter, _ value: SearchOptions) {
        writer.writeBoolI32(value.case_sensitive)
        writer.writeBoolI32(value.whole_word)
        writer.writeBoolI32(value.use_regex)
        writer.writeBoolI32(value.wrap_around)
        writer.writeInt32(value.max_matches)
    }

    static func sizeOfSearchOptions(_ value: SearchOptions) -> Int {
        4 + 4 + 4 + 4 + 4
    }

    static func writeSearchRequest(_ writer: inout BinaryWriter, _ value: SearchRequest) {
        writer.writeUtf8String(value.pattern)
        writeSearchOptions(&writer, value.options)
    }

    static func sizeOfSearchRequest(_ value: SearchRequest) -> Int {
        sizeOfUtf8String(value.pattern) + sizeOfSearchOptions(value.options)
    }

    static func readSearchState(_ reader: inout BinaryReader) -> SearchState? {
        guard let status = readSearchStatus(&reader) else { return nil }
        guard let pattern = reader.readUtf8String() else { return nil }
        guard let options = readSearchOptions(&reader) else { return nil }
        guard let generation = reader.readInt64() else { return nil }
        guard let match_count = reader.readInt32() else { return nil }
        guard let current_index = reader.readInt32() else { return nil }
        guard let has_current_match = reader.readBoolI32() else { return nil }
        guard let current_range = readTextRange(&reader) else { return nil }
        guard let error_message = reader.readUtf8String() else { return nil }
        return SearchState(status: status, pattern: pattern, options: options, generation: generation, match_count: match_count, current_index: current_index, has_current_match: has_current_match, current_range: current_range, error_message: error_message)
    }

    static func decodeSearchState(_ data: Data) -> SearchState? {
        return data.withUnsafeBytes { raw in
            decodeSearchState(raw)
        }
    }

    static func decodeSearchState(_ data: UnsafeRawBufferPointer) -> SearchState? {
        var reader = BinaryReader(data)
        return readSearchState(&reader)
    }

    static func readCursor(_ reader: inout BinaryReader) -> Cursor? {
        guard let text_position = readTextPosition(&reader) else { return nil }
        guard let position = readPointF(&reader) else { return nil }
        guard let height = reader.readFloat32() else { return nil }
        guard let visible = reader.readBoolI32() else { return nil }
        guard let show_dragger = reader.readBoolI32() else { return nil }
        return Cursor(text_position: text_position, position: position, height: height, visible: visible, show_dragger: show_dragger)
    }

    static func decodeCursor(_ data: Data) -> Cursor? {
        return data.withUnsafeBytes { raw in
            decodeCursor(raw)
        }
    }

    static func decodeCursor(_ data: UnsafeRawBufferPointer) -> Cursor? {
        var reader = BinaryReader(data)
        return readCursor(&reader)
    }

    static func readCursorRect(_ reader: inout BinaryReader) -> CursorRect? {
        guard let x = reader.readFloat32() else { return nil }
        guard let y = reader.readFloat32() else { return nil }
        guard let height = reader.readFloat32() else { return nil }
        return CursorRect(x: x, y: y, height: height)
    }

    static func decodeCursorRect(_ data: Data) -> CursorRect? {
        return data.withUnsafeBytes { raw in
            decodeCursorRect(raw)
        }
    }

    static func decodeCursorRect(_ data: UnsafeRawBufferPointer) -> CursorRect? {
        var reader = BinaryReader(data)
        return readCursorRect(&reader)
    }

    static func writeCursorRect(_ writer: inout BinaryWriter, _ value: CursorRect) {
        writer.writeFloat32(value.x)
        writer.writeFloat32(value.y)
        writer.writeFloat32(value.height)
    }

    static func sizeOfCursorRect(_ value: CursorRect) -> Int {
        4 + 4 + 4
    }

    static func readEditorRenderModel(_ reader: inout BinaryReader) -> EditorRenderModel? {
        guard let split_x = reader.readFloat32() else { return nil }
        guard let split_line_visible = reader.readBoolI32() else { return nil }
        guard let scroll_x = reader.readFloat32() else { return nil }
        guard let scroll_y = reader.readFloat32() else { return nil }
        guard let viewport_size = readSize(&reader) else { return nil }
        guard let current_line = readPointF(&reader) else { return nil }
        guard let current_line_render_mode = readCurrentLineRenderMode(&reader) else { return nil }
        guard let lines = readVisualLineList(&reader) else { return nil }
        guard let cursor = readCursor(&reader) else { return nil }
        guard let range_effects = readRangeEffectRenderItemList(&reader) else { return nil }
        guard let selection_start_handle = readSelectionHandle(&reader) else { return nil }
        guard let selection_end_handle = readSelectionHandle(&reader) else { return nil }
        guard let guide_segments = readGuideSegmentList(&reader) else { return nil }
        guard let max_gutter_icons = reader.readInt32() else { return nil }
        guard let gutter_icons = readGutterIconRenderItemList(&reader) else { return nil }
        guard let fold_markers = readFoldMarkerRenderItemList(&reader) else { return nil }
        guard let vertical_scrollbar = readScrollbarModel(&reader) else { return nil }
        guard let horizontal_scrollbar = readScrollbarModel(&reader) else { return nil }
        guard let gutter_sticky = reader.readBoolI32() else { return nil }
        guard let gutter_visible = reader.readBoolI32() else { return nil }
        guard let pointer_cursor_type = readPointerCursorType(&reader) else { return nil }
        return EditorRenderModel(split_x: split_x, split_line_visible: split_line_visible, scroll_x: scroll_x, scroll_y: scroll_y, viewport_size: viewport_size, current_line: current_line, current_line_render_mode: current_line_render_mode, lines: lines, cursor: cursor, range_effects: range_effects, selection_start_handle: selection_start_handle, selection_end_handle: selection_end_handle, guide_segments: guide_segments, max_gutter_icons: max_gutter_icons, gutter_icons: gutter_icons, fold_markers: fold_markers, vertical_scrollbar: vertical_scrollbar, horizontal_scrollbar: horizontal_scrollbar, gutter_sticky: gutter_sticky, gutter_visible: gutter_visible, pointer_cursor_type: pointer_cursor_type)
    }

    static func decodeEditorRenderModel(_ data: Data) -> EditorRenderModel? {
        return data.withUnsafeBytes { raw in
            decodeEditorRenderModel(raw)
        }
    }

    static func decodeEditorRenderModel(_ data: UnsafeRawBufferPointer) -> EditorRenderModel? {
        var reader = BinaryReader(data)
        return readEditorRenderModel(&reader)
    }

    static func readFoldMarkerRenderItem(_ reader: inout BinaryReader) -> FoldMarkerRenderItem? {
        guard let logical_line = reader.readInt32() else { return nil }
        guard let fold_state = readFoldState(&reader) else { return nil }
        guard let rect = readRect(&reader) else { return nil }
        return FoldMarkerRenderItem(logical_line: logical_line, fold_state: fold_state, rect: rect)
    }

    static func decodeFoldMarkerRenderItem(_ data: Data) -> FoldMarkerRenderItem? {
        return data.withUnsafeBytes { raw in
            decodeFoldMarkerRenderItem(raw)
        }
    }

    static func decodeFoldMarkerRenderItem(_ data: UnsafeRawBufferPointer) -> FoldMarkerRenderItem? {
        var reader = BinaryReader(data)
        return readFoldMarkerRenderItem(&reader)
    }

    static func readGuideSegment(_ reader: inout BinaryReader) -> GuideSegment? {
        guard let direction = readGuideDirection(&reader) else { return nil }
        guard let type = readGuideType(&reader) else { return nil }
        guard let style = readGuideStyle(&reader) else { return nil }
        guard let start = readPointF(&reader) else { return nil }
        guard let end = readPointF(&reader) else { return nil }
        guard let arrow_end = reader.readBoolI32() else { return nil }
        return GuideSegment(direction: direction, type: type, style: style, start: start, end: end, arrow_end: arrow_end)
    }

    static func decodeGuideSegment(_ data: Data) -> GuideSegment? {
        return data.withUnsafeBytes { raw in
            decodeGuideSegment(raw)
        }
    }

    static func decodeGuideSegment(_ data: UnsafeRawBufferPointer) -> GuideSegment? {
        var reader = BinaryReader(data)
        return readGuideSegment(&reader)
    }

    static func readGutterIconRenderItem(_ reader: inout BinaryReader) -> GutterIconRenderItem? {
        guard let logical_line = reader.readInt32() else { return nil }
        guard let icon_id = reader.readInt32() else { return nil }
        guard let rect = readRect(&reader) else { return nil }
        return GutterIconRenderItem(logical_line: logical_line, icon_id: icon_id, rect: rect)
    }

    static func decodeGutterIconRenderItem(_ data: Data) -> GutterIconRenderItem? {
        return data.withUnsafeBytes { raw in
            decodeGutterIconRenderItem(raw)
        }
    }

    static func decodeGutterIconRenderItem(_ data: UnsafeRawBufferPointer) -> GutterIconRenderItem? {
        var reader = BinaryReader(data)
        return readGutterIconRenderItem(&reader)
    }

    static func readLayoutMetrics(_ reader: inout BinaryReader) -> LayoutMetrics? {
        guard let font_height = reader.readFloat32() else { return nil }
        guard let font_ascent = reader.readFloat32() else { return nil }
        guard let line_spacing_add = reader.readFloat32() else { return nil }
        guard let line_spacing_mult = reader.readFloat32() else { return nil }
        guard let line_number_margin = reader.readFloat32() else { return nil }
        guard let line_number_width = reader.readFloat32() else { return nil }
        guard let content_start_padding = reader.readFloat32() else { return nil }
        guard let max_gutter_icons = reader.readInt32() else { return nil }
        guard let inlay_hint_padding = reader.readFloat32() else { return nil }
        guard let inlay_hint_margin = reader.readFloat32() else { return nil }
        guard let fold_arrow_mode = readFoldArrowMode(&reader) else { return nil }
        guard let has_fold_regions = reader.readBoolI32() else { return nil }
        guard let gutter_sticky = reader.readBoolI32() else { return nil }
        guard let gutter_visible = reader.readBoolI32() else { return nil }
        return LayoutMetrics(font_height: font_height, font_ascent: font_ascent, line_spacing_add: line_spacing_add, line_spacing_mult: line_spacing_mult, line_number_margin: line_number_margin, line_number_width: line_number_width, content_start_padding: content_start_padding, max_gutter_icons: max_gutter_icons, inlay_hint_padding: inlay_hint_padding, inlay_hint_margin: inlay_hint_margin, fold_arrow_mode: fold_arrow_mode, has_fold_regions: has_fold_regions, gutter_sticky: gutter_sticky, gutter_visible: gutter_visible)
    }

    static func decodeLayoutMetrics(_ data: Data) -> LayoutMetrics? {
        return data.withUnsafeBytes { raw in
            decodeLayoutMetrics(raw)
        }
    }

    static func decodeLayoutMetrics(_ data: UnsafeRawBufferPointer) -> LayoutMetrics? {
        var reader = BinaryReader(data)
        return readLayoutMetrics(&reader)
    }

    static func readRangeEffectRenderItem(_ reader: inout BinaryReader) -> RangeEffectRenderItem? {
        guard let rect = readRect(&reader) else { return nil }
        guard let kind = readRangeEffectKind(&reader) else { return nil }
        guard let style = readRangeEffectStyle(&reader) else { return nil }
        return RangeEffectRenderItem(rect: rect, kind: kind, style: style)
    }

    static func decodeRangeEffectRenderItem(_ data: Data) -> RangeEffectRenderItem? {
        return data.withUnsafeBytes { raw in
            decodeRangeEffectRenderItem(raw)
        }
    }

    static func decodeRangeEffectRenderItem(_ data: UnsafeRawBufferPointer) -> RangeEffectRenderItem? {
        var reader = BinaryReader(data)
        return readRangeEffectRenderItem(&reader)
    }

    static func readScrollMetrics(_ reader: inout BinaryReader) -> ScrollMetrics? {
        guard let scale = reader.readFloat32() else { return nil }
        guard let scroll_x = reader.readFloat32() else { return nil }
        guard let scroll_y = reader.readFloat32() else { return nil }
        guard let max_scroll_x = reader.readFloat32() else { return nil }
        guard let max_scroll_y = reader.readFloat32() else { return nil }
        guard let content_size = readSize(&reader) else { return nil }
        guard let viewport_size = readSize(&reader) else { return nil }
        guard let text_area_x = reader.readFloat32() else { return nil }
        guard let text_area_width = reader.readFloat32() else { return nil }
        guard let can_scroll_x = reader.readBoolI32() else { return nil }
        guard let can_scroll_y = reader.readBoolI32() else { return nil }
        return ScrollMetrics(scale: scale, scroll_x: scroll_x, scroll_y: scroll_y, max_scroll_x: max_scroll_x, max_scroll_y: max_scroll_y, content_size: content_size, viewport_size: viewport_size, text_area_x: text_area_x, text_area_width: text_area_width, can_scroll_x: can_scroll_x, can_scroll_y: can_scroll_y)
    }

    static func decodeScrollMetrics(_ data: Data) -> ScrollMetrics? {
        return data.withUnsafeBytes { raw in
            decodeScrollMetrics(raw)
        }
    }

    static func decodeScrollMetrics(_ data: UnsafeRawBufferPointer) -> ScrollMetrics? {
        var reader = BinaryReader(data)
        return readScrollMetrics(&reader)
    }

    static func readScrollbarModel(_ reader: inout BinaryReader) -> ScrollbarModel? {
        guard let visible = reader.readBoolI32() else { return nil }
        guard let alpha = reader.readFloat32() else { return nil }
        guard let thumb_active = reader.readBoolI32() else { return nil }
        guard let track = readRect(&reader) else { return nil }
        guard let thumb = readRect(&reader) else { return nil }
        return ScrollbarModel(visible: visible, alpha: alpha, thumb_active: thumb_active, track: track, thumb: thumb)
    }

    static func decodeScrollbarModel(_ data: Data) -> ScrollbarModel? {
        return data.withUnsafeBytes { raw in
            decodeScrollbarModel(raw)
        }
    }

    static func decodeScrollbarModel(_ data: UnsafeRawBufferPointer) -> ScrollbarModel? {
        var reader = BinaryReader(data)
        return readScrollbarModel(&reader)
    }

    static func readSelectionHandle(_ reader: inout BinaryReader) -> SelectionHandle? {
        guard let position = readPointF(&reader) else { return nil }
        guard let height = reader.readFloat32() else { return nil }
        guard let visible = reader.readBoolI32() else { return nil }
        return SelectionHandle(position: position, height: height, visible: visible)
    }

    static func decodeSelectionHandle(_ data: Data) -> SelectionHandle? {
        return data.withUnsafeBytes { raw in
            decodeSelectionHandle(raw)
        }
    }

    static func decodeSelectionHandle(_ data: UnsafeRawBufferPointer) -> SelectionHandle? {
        var reader = BinaryReader(data)
        return readSelectionHandle(&reader)
    }

    static func readVisualLine(_ reader: inout BinaryReader) -> VisualLine? {
        guard let logical_line = reader.readInt32() else { return nil }
        guard let wrap_index = reader.readInt32() else { return nil }
        guard let line_number_position = readPointF(&reader) else { return nil }
        guard let runs = readVisualRunList(&reader) else { return nil }
        guard let kind = readVisualLineKind(&reader) else { return nil }
        guard let owns_gutter_semantics = reader.readBoolI32() else { return nil }
        guard let fold_state = readFoldState(&reader) else { return nil }
        return VisualLine(logical_line: logical_line, wrap_index: wrap_index, line_number_position: line_number_position, runs: runs, kind: kind, owns_gutter_semantics: owns_gutter_semantics, fold_state: fold_state)
    }

    static func decodeVisualLine(_ data: Data) -> VisualLine? {
        return data.withUnsafeBytes { raw in
            decodeVisualLine(raw)
        }
    }

    static func decodeVisualLine(_ data: UnsafeRawBufferPointer) -> VisualLine? {
        var reader = BinaryReader(data)
        return readVisualLine(&reader)
    }

    static func readVisualRun(_ reader: inout BinaryReader) -> VisualRun? {
        guard let type = readVisualRunType(&reader) else { return nil }
        guard let x = reader.readFloat32() else { return nil }
        guard let y = reader.readFloat32() else { return nil }
        guard let text = reader.readUtf8String() else { return nil }
        guard let style = readTextStyle(&reader) else { return nil }
        guard let icon_id = reader.readInt32() else { return nil }
        guard let color_value = reader.readInt32() else { return nil }
        guard let width = reader.readFloat32() else { return nil }
        guard let padding = reader.readFloat32() else { return nil }
        guard let margin = reader.readFloat32() else { return nil }
        guard let active = reader.readBoolI32() else { return nil }
        return VisualRun(type: type, x: x, y: y, text: text, style: style, icon_id: icon_id, color_value: color_value, width: width, padding: padding, margin: margin, active: active)
    }

    static func decodeVisualRun(_ data: Data) -> VisualRun? {
        return data.withUnsafeBytes { raw in
            decodeVisualRun(raw)
        }
    }

    static func decodeVisualRun(_ data: UnsafeRawBufferPointer) -> VisualRun? {
        var reader = BinaryReader(data)
        return readVisualRun(&reader)
    }

    static func encodeBracketGuide(_ value: BracketGuide) -> Data {
        var writer = BinaryWriter()
        writeBracketGuide(&writer, value)
        return writer.data()
    }

    static func encodeCodeLensItem(_ value: CodeLensItem) -> Data {
        var writer = BinaryWriter()
        writeCodeLensItem(&writer, value)
        return writer.data()
    }

    static func encodeDiagnostic(_ value: Diagnostic) -> Data {
        var writer = BinaryWriter()
        writeDiagnostic(&writer, value)
        return writer.data()
    }

    static func encodeDocumentHighlight(_ value: DocumentHighlight) -> Data {
        var writer = BinaryWriter()
        writeDocumentHighlight(&writer, value)
        return writer.data()
    }

    static func encodeFlowGuide(_ value: FlowGuide) -> Data {
        var writer = BinaryWriter()
        writeFlowGuide(&writer, value)
        return writer.data()
    }

    static func encodeFoldRegion(_ value: FoldRegion) -> Data {
        var writer = BinaryWriter()
        writeFoldRegion(&writer, value)
        return writer.data()
    }

    static func encodeGutterIcon(_ value: GutterIcon) -> Data {
        var writer = BinaryWriter()
        writeGutterIcon(&writer, value)
        return writer.data()
    }

    static func encodeIndentGuide(_ value: IndentGuide) -> Data {
        var writer = BinaryWriter()
        writeIndentGuide(&writer, value)
        return writer.data()
    }

    static func encodeInlayHint(_ value: InlayHint) -> Data {
        var writer = BinaryWriter()
        writeInlayHint(&writer, value)
        return writer.data()
    }

    static func encodeLinkSpan(_ value: LinkSpan) -> Data {
        var writer = BinaryWriter()
        writeLinkSpan(&writer, value)
        return writer.data()
    }

    static func encodePhantomText(_ value: PhantomText) -> Data {
        var writer = BinaryWriter()
        writePhantomText(&writer, value)
        return writer.data()
    }

    static func writeRegisterBatchTextStylesPayloadWire(_ writer: inout BinaryWriter, styleByStyleId: [Int32: TextStyle]) {
        writer.writeInt32(Int32(styleByStyleId.count))
        for key in styleByStyleId.keys.sorted() {
            writer.writeInt32(key)
            let value = styleByStyleId[key]!
            writeTextStyle(&writer, value)
        }
    }

    static func sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId: [Int32: TextStyle]) -> Int {
        var size = 0
        size += 4
        for key in styleByStyleId.keys.sorted() {
            size += 4
            let value = styleByStyleId[key]!
            size += sizeOfTextStyle(value)
        }
        return size
    }

    static func encodeRegisterBatchTextStylesPayload(styleByStyleId: [Int32: TextStyle]) -> Data {
        var writer = BinaryWriter()
        writeRegisterBatchTextStylesPayloadWire(&writer, styleByStyleId: styleByStyleId)
        return writer.data()
    }

    static func encodeSeparatorGuide(_ value: SeparatorGuide) -> Data {
        var writer = BinaryWriter()
        writeSeparatorGuide(&writer, value)
        return writer.data()
    }

    static func writeSetBatchLineCodeLensPayloadWire(_ writer: inout BinaryWriter, itemsByLine: [Int32: [CodeLensItem]]) {
        writer.writeInt32(Int32(itemsByLine.count))
        for key in itemsByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = itemsByLine[key]!
            writeCodeLensItemList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineCodeLensPayloadWire(itemsByLine: [Int32: [CodeLensItem]]) -> Int {
        var size = 0
        size += 4
        for key in itemsByLine.keys.sorted() {
            size += 4
            let value = itemsByLine[key]!
            size += sizeOfCodeLensItemList(value)
        }
        return size
    }

    static func encodeSetBatchLineCodeLensPayload(itemsByLine: [Int32: [CodeLensItem]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineCodeLensPayloadWire(&writer, itemsByLine: itemsByLine)
        return writer.data()
    }

    static func writeSetBatchLineDiagnosticsPayloadWire(_ writer: inout BinaryWriter, diagnosticsByLine: [Int32: [Diagnostic]]) {
        writer.writeInt32(Int32(diagnosticsByLine.count))
        for key in diagnosticsByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = diagnosticsByLine[key]!
            writeDiagnosticList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine: [Int32: [Diagnostic]]) -> Int {
        var size = 0
        size += 4
        for key in diagnosticsByLine.keys.sorted() {
            size += 4
            let value = diagnosticsByLine[key]!
            size += sizeOfDiagnosticList(value)
        }
        return size
    }

    static func encodeSetBatchLineDiagnosticsPayload(diagnosticsByLine: [Int32: [Diagnostic]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineDiagnosticsPayloadWire(&writer, diagnosticsByLine: diagnosticsByLine)
        return writer.data()
    }

    static func writeSetBatchLineDocumentHighlightsPayloadWire(_ writer: inout BinaryWriter, highlightsByLine: [Int32: [DocumentHighlight]]) {
        writer.writeInt32(Int32(highlightsByLine.count))
        for key in highlightsByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = highlightsByLine[key]!
            writeDocumentHighlightList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineDocumentHighlightsPayloadWire(highlightsByLine: [Int32: [DocumentHighlight]]) -> Int {
        var size = 0
        size += 4
        for key in highlightsByLine.keys.sorted() {
            size += 4
            let value = highlightsByLine[key]!
            size += sizeOfDocumentHighlightList(value)
        }
        return size
    }

    static func encodeSetBatchLineDocumentHighlightsPayload(highlightsByLine: [Int32: [DocumentHighlight]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineDocumentHighlightsPayloadWire(&writer, highlightsByLine: highlightsByLine)
        return writer.data()
    }

    static func writeSetBatchLineGutterIconsPayloadWire(_ writer: inout BinaryWriter, iconsByLine: [Int32: [GutterIcon]]) {
        writer.writeInt32(Int32(iconsByLine.count))
        for key in iconsByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = iconsByLine[key]!
            writeGutterIconList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine: [Int32: [GutterIcon]]) -> Int {
        var size = 0
        size += 4
        for key in iconsByLine.keys.sorted() {
            size += 4
            let value = iconsByLine[key]!
            size += sizeOfGutterIconList(value)
        }
        return size
    }

    static func encodeSetBatchLineGutterIconsPayload(iconsByLine: [Int32: [GutterIcon]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineGutterIconsPayloadWire(&writer, iconsByLine: iconsByLine)
        return writer.data()
    }

    static func writeSetBatchLineInlayHintsPayloadWire(_ writer: inout BinaryWriter, hintsByLine: [Int32: [InlayHint]]) {
        writer.writeInt32(Int32(hintsByLine.count))
        for key in hintsByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = hintsByLine[key]!
            writeInlayHintList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine: [Int32: [InlayHint]]) -> Int {
        var size = 0
        size += 4
        for key in hintsByLine.keys.sorted() {
            size += 4
            let value = hintsByLine[key]!
            size += sizeOfInlayHintList(value)
        }
        return size
    }

    static func encodeSetBatchLineInlayHintsPayload(hintsByLine: [Int32: [InlayHint]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineInlayHintsPayloadWire(&writer, hintsByLine: hintsByLine)
        return writer.data()
    }

    static func writeSetBatchLineLinksPayloadWire(_ writer: inout BinaryWriter, linksByLine: [Int32: [LinkSpan]]) {
        writer.writeInt32(Int32(linksByLine.count))
        for key in linksByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = linksByLine[key]!
            writeLinkSpanList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineLinksPayloadWire(linksByLine: [Int32: [LinkSpan]]) -> Int {
        var size = 0
        size += 4
        for key in linksByLine.keys.sorted() {
            size += 4
            let value = linksByLine[key]!
            size += sizeOfLinkSpanList(value)
        }
        return size
    }

    static func encodeSetBatchLineLinksPayload(linksByLine: [Int32: [LinkSpan]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineLinksPayloadWire(&writer, linksByLine: linksByLine)
        return writer.data()
    }

    static func writeSetBatchLinePhantomTextsPayloadWire(_ writer: inout BinaryWriter, phantomsByLine: [Int32: [PhantomText]]) {
        writer.writeInt32(Int32(phantomsByLine.count))
        for key in phantomsByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = phantomsByLine[key]!
            writePhantomTextList(&writer, value)
        }
    }

    static func sizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine: [Int32: [PhantomText]]) -> Int {
        var size = 0
        size += 4
        for key in phantomsByLine.keys.sorted() {
            size += 4
            let value = phantomsByLine[key]!
            size += sizeOfPhantomTextList(value)
        }
        return size
    }

    static func encodeSetBatchLinePhantomTextsPayload(phantomsByLine: [Int32: [PhantomText]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLinePhantomTextsPayloadWire(&writer, phantomsByLine: phantomsByLine)
        return writer.data()
    }

    static func writeSetBatchLineSpansPayloadWire(_ writer: inout BinaryWriter, layer: SpanLayer, spansByLine: [Int32: [StyleSpan]]) {
        writer.writeInt32(layer.rawValue)
        writer.writeInt32(Int32(spansByLine.count))
        for key in spansByLine.keys.sorted() {
            writer.writeInt32(key)
            let value = spansByLine[key]!
            writeStyleSpanList(&writer, value)
        }
    }

    static func sizeOfSetBatchLineSpansPayloadWire(layer: SpanLayer, spansByLine: [Int32: [StyleSpan]]) -> Int {
        var size = 0
        size += 4
        size += 4
        for key in spansByLine.keys.sorted() {
            size += 4
            let value = spansByLine[key]!
            size += sizeOfStyleSpanList(value)
        }
        return size
    }

    static func encodeSetBatchLineSpansPayload(layer: SpanLayer, spansByLine: [Int32: [StyleSpan]]) -> Data {
        var writer = BinaryWriter()
        writeSetBatchLineSpansPayloadWire(&writer, layer: layer, spansByLine: spansByLine)
        return writer.data()
    }

    static func writeSetBracketGuidesPayloadWire(_ writer: inout BinaryWriter, guides: [BracketGuide]) {
        writeBracketGuideList(&writer, guides)
    }

    static func sizeOfSetBracketGuidesPayloadWire(guides: [BracketGuide]) -> Int {
        var size = 0
        size += sizeOfBracketGuideList(guides)
        return size
    }

    static func encodeSetBracketGuidesPayload(guides: [BracketGuide]) -> Data {
        var writer = BinaryWriter()
        writeSetBracketGuidesPayloadWire(&writer, guides: guides)
        return writer.data()
    }

    static func writeSetFlowGuidesPayloadWire(_ writer: inout BinaryWriter, guides: [FlowGuide]) {
        writeFlowGuideList(&writer, guides)
    }

    static func sizeOfSetFlowGuidesPayloadWire(guides: [FlowGuide]) -> Int {
        var size = 0
        size += sizeOfFlowGuideList(guides)
        return size
    }

    static func encodeSetFlowGuidesPayload(guides: [FlowGuide]) -> Data {
        var writer = BinaryWriter()
        writeSetFlowGuidesPayloadWire(&writer, guides: guides)
        return writer.data()
    }

    static func writeSetFoldRegionsPayloadWire(_ writer: inout BinaryWriter, regions: [FoldRegion]) {
        writeFoldRegionList(&writer, regions)
    }

    static func sizeOfSetFoldRegionsPayloadWire(regions: [FoldRegion]) -> Int {
        var size = 0
        size += sizeOfFoldRegionList(regions)
        return size
    }

    static func encodeSetFoldRegionsPayload(regions: [FoldRegion]) -> Data {
        var writer = BinaryWriter()
        writeSetFoldRegionsPayloadWire(&writer, regions: regions)
        return writer.data()
    }

    static func writeSetIndentGuidesPayloadWire(_ writer: inout BinaryWriter, guides: [IndentGuide]) {
        writeIndentGuideList(&writer, guides)
    }

    static func sizeOfSetIndentGuidesPayloadWire(guides: [IndentGuide]) -> Int {
        var size = 0
        size += sizeOfIndentGuideList(guides)
        return size
    }

    static func encodeSetIndentGuidesPayload(guides: [IndentGuide]) -> Data {
        var writer = BinaryWriter()
        writeSetIndentGuidesPayloadWire(&writer, guides: guides)
        return writer.data()
    }

    static func writeSetLineCodeLensPayloadWire(_ writer: inout BinaryWriter, line: Int32, items: [CodeLensItem]) {
        writer.writeInt32(line)
        writeCodeLensItemList(&writer, items)
    }

    static func sizeOfSetLineCodeLensPayloadWire(line: Int32, items: [CodeLensItem]) -> Int {
        var size = 0
        size += 4
        size += sizeOfCodeLensItemList(items)
        return size
    }

    static func encodeSetLineCodeLensPayload(line: Int32, items: [CodeLensItem]) -> Data {
        var writer = BinaryWriter()
        writeSetLineCodeLensPayloadWire(&writer, line: line, items: items)
        return writer.data()
    }

    static func writeSetLineDiagnosticsPayloadWire(_ writer: inout BinaryWriter, line: Int32, diagnostics: [Diagnostic]) {
        writer.writeInt32(line)
        writeDiagnosticList(&writer, diagnostics)
    }

    static func sizeOfSetLineDiagnosticsPayloadWire(line: Int32, diagnostics: [Diagnostic]) -> Int {
        var size = 0
        size += 4
        size += sizeOfDiagnosticList(diagnostics)
        return size
    }

    static func encodeSetLineDiagnosticsPayload(line: Int32, diagnostics: [Diagnostic]) -> Data {
        var writer = BinaryWriter()
        writeSetLineDiagnosticsPayloadWire(&writer, line: line, diagnostics: diagnostics)
        return writer.data()
    }

    static func writeSetLineDocumentHighlightsPayloadWire(_ writer: inout BinaryWriter, line: Int32, highlights: [DocumentHighlight]) {
        writer.writeInt32(line)
        writeDocumentHighlightList(&writer, highlights)
    }

    static func sizeOfSetLineDocumentHighlightsPayloadWire(line: Int32, highlights: [DocumentHighlight]) -> Int {
        var size = 0
        size += 4
        size += sizeOfDocumentHighlightList(highlights)
        return size
    }

    static func encodeSetLineDocumentHighlightsPayload(line: Int32, highlights: [DocumentHighlight]) -> Data {
        var writer = BinaryWriter()
        writeSetLineDocumentHighlightsPayloadWire(&writer, line: line, highlights: highlights)
        return writer.data()
    }

    static func writeSetLineGutterIconsPayloadWire(_ writer: inout BinaryWriter, line: Int32, icons: [GutterIcon]) {
        writer.writeInt32(line)
        writeGutterIconList(&writer, icons)
    }

    static func sizeOfSetLineGutterIconsPayloadWire(line: Int32, icons: [GutterIcon]) -> Int {
        var size = 0
        size += 4
        size += sizeOfGutterIconList(icons)
        return size
    }

    static func encodeSetLineGutterIconsPayload(line: Int32, icons: [GutterIcon]) -> Data {
        var writer = BinaryWriter()
        writeSetLineGutterIconsPayloadWire(&writer, line: line, icons: icons)
        return writer.data()
    }

    static func writeSetLineInlayHintsPayloadWire(_ writer: inout BinaryWriter, line: Int32, hints: [InlayHint]) {
        writer.writeInt32(line)
        writeInlayHintList(&writer, hints)
    }

    static func sizeOfSetLineInlayHintsPayloadWire(line: Int32, hints: [InlayHint]) -> Int {
        var size = 0
        size += 4
        size += sizeOfInlayHintList(hints)
        return size
    }

    static func encodeSetLineInlayHintsPayload(line: Int32, hints: [InlayHint]) -> Data {
        var writer = BinaryWriter()
        writeSetLineInlayHintsPayloadWire(&writer, line: line, hints: hints)
        return writer.data()
    }

    static func writeSetLineLinksPayloadWire(_ writer: inout BinaryWriter, line: Int32, links: [LinkSpan]) {
        writer.writeInt32(line)
        writeLinkSpanList(&writer, links)
    }

    static func sizeOfSetLineLinksPayloadWire(line: Int32, links: [LinkSpan]) -> Int {
        var size = 0
        size += 4
        size += sizeOfLinkSpanList(links)
        return size
    }

    static func encodeSetLineLinksPayload(line: Int32, links: [LinkSpan]) -> Data {
        var writer = BinaryWriter()
        writeSetLineLinksPayloadWire(&writer, line: line, links: links)
        return writer.data()
    }

    static func writeSetLinePhantomTextsPayloadWire(_ writer: inout BinaryWriter, line: Int32, phantoms: [PhantomText]) {
        writer.writeInt32(line)
        writePhantomTextList(&writer, phantoms)
    }

    static func sizeOfSetLinePhantomTextsPayloadWire(line: Int32, phantoms: [PhantomText]) -> Int {
        var size = 0
        size += 4
        size += sizeOfPhantomTextList(phantoms)
        return size
    }

    static func encodeSetLinePhantomTextsPayload(line: Int32, phantoms: [PhantomText]) -> Data {
        var writer = BinaryWriter()
        writeSetLinePhantomTextsPayloadWire(&writer, line: line, phantoms: phantoms)
        return writer.data()
    }

    static func writeSetLineSpansPayloadWire(_ writer: inout BinaryWriter, line: Int32, layer: SpanLayer, spans: [StyleSpan]) {
        writer.writeInt32(line)
        writer.writeInt32(layer.rawValue)
        writeStyleSpanList(&writer, spans)
    }

    static func sizeOfSetLineSpansPayloadWire(line: Int32, layer: SpanLayer, spans: [StyleSpan]) -> Int {
        var size = 0
        size += 4
        size += 4
        size += sizeOfStyleSpanList(spans)
        return size
    }

    static func encodeSetLineSpansPayload(line: Int32, layer: SpanLayer, spans: [StyleSpan]) -> Data {
        var writer = BinaryWriter()
        writeSetLineSpansPayloadWire(&writer, line: line, layer: layer, spans: spans)
        return writer.data()
    }

    static func writeSetSeparatorGuidesPayloadWire(_ writer: inout BinaryWriter, guides: [SeparatorGuide]) {
        writeSeparatorGuideList(&writer, guides)
    }

    static func sizeOfSetSeparatorGuidesPayloadWire(guides: [SeparatorGuide]) -> Int {
        var size = 0
        size += sizeOfSeparatorGuideList(guides)
        return size
    }

    static func encodeSetSeparatorGuidesPayload(guides: [SeparatorGuide]) -> Data {
        var writer = BinaryWriter()
        writeSetSeparatorGuidesPayloadWire(&writer, guides: guides)
        return writer.data()
    }

    static func encodeEditorOptions(_ value: EditorOptions) -> Data {
        var writer = BinaryWriter()
        writeEditorOptions(&writer, value)
        return writer.data()
    }

    static func encodeEditorRangeEffectStyles(_ value: EditorRangeEffectStyles) -> Data {
        var writer = BinaryWriter()
        writeEditorRangeEffectStyles(&writer, value)
        return writer.data()
    }

    static func encodeEditorRenderColors(_ value: EditorRenderColors) -> Data {
        var writer = BinaryWriter()
        writeEditorRenderColors(&writer, value)
        return writer.data()
    }

    static func encodeHandleConfig(_ value: HandleConfig) -> Data {
        var writer = BinaryWriter()
        writeHandleConfig(&writer, value)
        return writer.data()
    }

    static func encodeScrollbarConfig(_ value: ScrollbarConfig) -> Data {
        var writer = BinaryWriter()
        writeScrollbarConfig(&writer, value)
        return writer.data()
    }

    static func writeApplyTextEditsPayloadWire(_ writer: inout BinaryWriter, edits: [TextEdit]) {
        writeTextEditList(&writer, edits)
    }

    static func sizeOfApplyTextEditsPayloadWire(edits: [TextEdit]) -> Int {
        var size = 0
        size += sizeOfTextEditList(edits)
        return size
    }

    static func encodeApplyTextEditsPayload(edits: [TextEdit]) -> Data {
        var writer = BinaryWriter()
        writeApplyTextEditsPayloadWire(&writer, edits: edits)
        return writer.data()
    }

    static func encodeImeDocumentTextReplacement(_ value: ImeDocumentTextReplacement) -> Data {
        var writer = BinaryWriter()
        writeImeDocumentTextReplacement(&writer, value)
        return writer.data()
    }

    static func encodeImeInputContextTextReplacement(_ value: ImeInputContextTextReplacement) -> Data {
        var writer = BinaryWriter()
        writeImeInputContextTextReplacement(&writer, value)
        return writer.data()
    }

    static func encodeImeInputStateTextReplacement(_ value: ImeInputStateTextReplacement) -> Data {
        var writer = BinaryWriter()
        writeImeInputStateTextReplacement(&writer, value)
        return writer.data()
    }

    static func encodeImeTextModelDelta(_ value: ImeTextModelDelta) -> Data {
        var writer = BinaryWriter()
        writeImeTextModelDelta(&writer, value)
        return writer.data()
    }

    static func encodeImeTextModelState(_ value: ImeTextModelState) -> Data {
        var writer = BinaryWriter()
        writeImeTextModelState(&writer, value)
        return writer.data()
    }

    static func encodeImeTextReplacement(_ value: ImeTextReplacement) -> Data {
        var writer = BinaryWriter()
        writeImeTextReplacement(&writer, value)
        return writer.data()
    }

    static func encodeGestureEvent(_ value: GestureEvent) -> Data {
        var writer = BinaryWriter()
        writeGestureEvent(&writer, value)
        return writer.data()
    }

    static func writeSetKeyMapPayloadWire(_ writer: inout BinaryWriter, bindings: [KeyBinding]) {
        writeKeyBindingList(&writer, bindings)
    }

    static func sizeOfSetKeyMapPayloadWire(bindings: [KeyBinding]) -> Int {
        var size = 0
        size += sizeOfKeyBindingList(bindings)
        return size
    }

    static func encodeSetKeyMapPayload(bindings: [KeyBinding]) -> Data {
        var writer = BinaryWriter()
        writeSetKeyMapPayloadWire(&writer, bindings: bindings)
        return writer.data()
    }

    static func encodeLinkedEditingModel(_ value: LinkedEditingModel) -> Data {
        var writer = BinaryWriter()
        writeLinkedEditingModel(&writer, value)
        return writer.data()
    }

    static func writeStartLinkedEditingPayloadWire(_ writer: inout BinaryWriter, model: LinkedEditingModel) {
        writeLinkedEditingModel(&writer, model)
    }

    static func sizeOfStartLinkedEditingPayloadWire(model: LinkedEditingModel) -> Int {
        var size = 0
        size += sizeOfLinkedEditingModel(model)
        return size
    }

    static func encodeStartLinkedEditingPayload(model: LinkedEditingModel) -> Data {
        var writer = BinaryWriter()
        writeStartLinkedEditingPayloadWire(&writer, model: model)
        return writer.data()
    }

    static func encodeTabStopGroup(_ value: TabStopGroup) -> Data {
        var writer = BinaryWriter()
        writeTabStopGroup(&writer, value)
        return writer.data()
    }

    static func encodeSearchRequest(_ value: SearchRequest) -> Data {
        var writer = BinaryWriter()
        writeSearchRequest(&writer, value)
        return writer.data()
    }
}
