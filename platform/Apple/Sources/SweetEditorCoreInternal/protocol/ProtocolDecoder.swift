import Foundation
import CoreGraphics

final class ProtocolDecoder {
    unowned let owner: SweetEditorCore

    init(owner: SweetEditorCore) {
        self.owner = owner
    }

    func decodeTextEditResultLite(_ data: Data?) -> TextEditResultLite? {
        owner.parseTextEditResultLite(data)
    }

    func decodeImeEventEditResultLite(_ data: Data?) -> TextEditResultLite? {
        owner.parseImeEventEditResultLite(data)
    }

    func decodeKeyEventResult(_ data: Data?) -> KeyEventResultData? {
        owner.parseKeyEventResult(data)
    }

    func decodeGestureResult(_ data: Data?) -> GestureResultData? {
        owner.parseGestureResult(data)
    }

    func decodeRenderModel(_ data: Data) -> EditorRenderModel? {
        owner.readEditorRenderModel(data)
    }

    func decodeLayoutMetrics(_ data: Data?) -> LayoutMetrics? {
        guard let payload = data else { return nil }
        return owner.readLayoutMetrics(payload)
    }

    func decodeScrollMetrics(_ data: Data?) -> SweetEditorCore.ScrollMetrics {
        guard let payload = data else { return owner.defaultScrollMetrics() }
        var reader = SweetEditorCore.BinaryReader(data: payload)
        guard let scale = reader.readFloat(),
              let scrollX = reader.readFloat(),
              let scrollY = reader.readFloat(),
              let maxScrollX = reader.readFloat(),
              let maxScrollY = reader.readFloat(),
              let contentWidth = reader.readFloat(),
              let contentHeight = reader.readFloat(),
              let viewportWidth = reader.readFloat(),
              let viewportHeight = reader.readFloat(),
              let textAreaX = reader.readFloat(),
              let textAreaWidth = reader.readFloat(),
              let canScrollX = reader.readInt32(),
              let canScrollY = reader.readInt32() else {
            return owner.defaultScrollMetrics()
        }
        return SweetEditorCore.ScrollMetrics(
            scale: CGFloat(scale),
            scrollX: CGFloat(scrollX),
            scrollY: CGFloat(scrollY),
            maxScrollX: CGFloat(maxScrollX),
            maxScrollY: CGFloat(maxScrollY),
            contentWidth: CGFloat(contentWidth),
            contentHeight: CGFloat(contentHeight),
            viewportWidth: CGFloat(viewportWidth),
            viewportHeight: CGFloat(viewportHeight),
            textAreaX: CGFloat(textAreaX),
            textAreaWidth: CGFloat(textAreaWidth),
            canScrollX: canScrollX != 0,
            canScrollY: canScrollY != 0
        )
    }
}

extension SweetEditorCore {
    fileprivate struct BinaryReader {
        let data: Data
        var offset: Int = 0

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

        mutating func readFloat() -> Float? {
            guard let raw = readUInt32() else { return nil }
            return Float(bitPattern: raw)
        }

        mutating func readString() -> String? {
            guard let lenI32 = readInt32(), lenI32 >= 0 else { return nil }
            let len = Int(lenI32)
            guard offset + len <= data.count else { return nil }
            defer { offset += len }
            if len == 0 { return "" }
            let slice = data.subdata(in: offset..<(offset + len))
            return String(data: slice, encoding: .utf8) ?? ""
        }
    }

    fileprivate func gestureType(from value: Int32) -> GestureType {
        switch value {
        case 1: return .TAP
        case 2: return .DOUBLE_TAP
        case 3: return .LONG_PRESS
        case 4: return .SCALE
        case 5: return .SCROLL
        case 6: return .FAST_SCROLL
        case 7: return .DRAG_SELECT
        case 8: return .CONTEXT_MENU
        default: return .UNDEFINED
        }
    }

    fileprivate func hitTargetType(from value: Int32) -> HitTargetType {
        switch value {
        case 1: return .INLAY_HINT_TEXT
        case 2: return .INLAY_HINT_ICON
        case 3: return .GUTTER_ICON
        case 4: return .FOLD_PLACEHOLDER
        case 5: return .FOLD_GUTTER
        case 6: return .INLAY_HINT_COLOR
        case 7: return .CODELENS
        case 8: return .LINK
        default: return .NONE
        }
    }

    fileprivate func parseTextChange(_ reader: inout BinaryReader) -> TextChangeData? {
        guard let startLine = reader.readInt32(),
              let startColumn = reader.readInt32(),
              let endLine = reader.readInt32(),
              let endColumn = reader.readInt32(),
              let newText = reader.readString() else {
            return nil
        }
        let range = TextRangeData(
            start: TextPositionData(line: Int(startLine), column: Int(startColumn)),
            end: TextPositionData(line: Int(endLine), column: Int(endColumn))
        )
        return TextChangeData(range: range, new_text: newText)
    }

    fileprivate func parseTextEditResultLite(_ data: Data?) -> TextEditResultLite? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let changed = reader.readInt32(), changed != 0,
              let count = reader.readInt32(), count > 0 else {
            return nil
        }
        var changes: [TextChangeData] = []
        let changeCount = Int(count)
        changes.reserveCapacity(changeCount)
        for _ in 0..<changeCount {
            guard let change = parseTextChange(&reader) else { break }
            changes.append(change)
        }
        guard !changes.isEmpty else { return nil }
        return TextEditResultLite(changes: changes)
    }

    fileprivate func parseImeEventEditResultLite(_ data: Data?) -> TextEditResultLite? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard reader.readInt32() != nil,
              reader.readInt32() != nil,
              reader.readInt32() != nil,
              reader.readInt32() != nil,
              let hasEdit = reader.readInt32(),
              hasEdit != 0,
              let count = reader.readInt32(),
              count > 0 else {
            return nil
        }
        var changes: [TextChangeData] = []
        let changeCount = Int(count)
        changes.reserveCapacity(changeCount)
        for _ in 0..<changeCount {
            guard let change = parseTextChange(&reader) else { break }
            changes.append(change)
        }
        guard !changes.isEmpty else { return nil }
        return TextEditResultLite(changes: changes)
    }

    fileprivate func parseKeyEventResult(_ data: Data?) -> KeyEventResultData? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let handled = reader.readInt32(),
              let contentChanged = reader.readInt32(),
              let cursorChanged = reader.readInt32(),
              let selectionChanged = reader.readInt32(),
              let hasEdit = reader.readInt32() else {
            return nil
        }

        var editChanges: [TextChangeData] = []
        if hasEdit != 0, let count = reader.readInt32(), count > 0 {
            let changeCount = Int(count)
            editChanges.reserveCapacity(changeCount)
            for _ in 0..<changeCount {
                guard let change = parseTextChange(&reader) else { break }
                editChanges.append(change)
            }
        }
        let zeroPos = TextPositionData(line: 0, column: 0)
        let edit = TextEditResultData(
            changed: !editChanges.isEmpty,
            changes: editChanges,
            cursor_before: zeroPos,
            cursor_after: zeroPos
        )
        return KeyEventResultData(
            handled: handled != 0,
            content_changed: contentChanged != 0,
            cursor_changed: cursorChanged != 0,
            selection_changed: selectionChanged != 0,
            edit_result: edit
        )
    }

    fileprivate func parseGestureResult(_ data: Data?) -> GestureResultData? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let typeValue = reader.readInt32() else { return nil }
        let type = gestureType(from: typeValue)
        var tapPoint = PointData(x: 0, y: 0)
        if type == .TAP || type == .DOUBLE_TAP || type == .LONG_PRESS || type == .DRAG_SELECT || type == .CONTEXT_MENU {
            guard let x = reader.readFloat(), let y = reader.readFloat() else { return nil }
            tapPoint = PointData(x: x, y: y)
        }

        guard let cursorLine = reader.readInt32(),
              let cursorColumn = reader.readInt32(),
              let hasSelectionI32 = reader.readInt32(),
              let selStartLine = reader.readInt32(),
              let selStartColumn = reader.readInt32(),
              let selEndLine = reader.readInt32(),
              let selEndColumn = reader.readInt32(),
              let viewScrollX = reader.readFloat(),
              let viewScrollY = reader.readFloat(),
              let viewScale = reader.readFloat() else {
            return nil
        }

        var hitTarget = HitTargetData(type: .NONE, line: 0, column: 0, icon_id: 0, color_value: 0)
        if let hitType = reader.readInt32(),
           let hitLine = reader.readInt32(),
           let hitColumn = reader.readInt32(),
           let hitIcon = reader.readInt32(),
           let hitColor = reader.readInt32() {
            hitTarget = HitTargetData(
                type: hitTargetType(from: hitType),
                line: Int(hitLine),
                column: Int(hitColumn),
                icon_id: Int32(hitIcon),
                color_value: Int32(hitColor)
            )
        }

        let cursor = TextPositionData(line: Int(cursorLine), column: Int(cursorColumn))
        let selection = TextRangeData(
            start: TextPositionData(line: Int(selStartLine), column: Int(selStartColumn)),
            end: TextPositionData(line: Int(selEndLine), column: Int(selEndColumn))
        )
        return GestureResultData(
            type: type,
            tap_point: tapPoint,
            modifiers: 0,
            scale: 1,
            scroll_x: 0,
            scroll_y: 0,
            cursor_position: cursor,
            has_selection: hasSelectionI32 != 0,
            selection: selection,
            view_scroll_x: viewScrollX,
            view_scroll_y: viewScrollY,
            view_scale: viewScale,
            hit_target: hitTarget
        )
    }

    fileprivate func visualRunType(from value: Int32) -> VisualRunType {
        switch value {
        case 1: return .WHITESPACE
        case 2: return .NEWLINE
        case 3: return .INLAY_HINT
        case 4: return .PHANTOM_TEXT
        case 5: return .FOLD_PLACEHOLDER
        case 6: return .TAB
        case 7: return .CODELENS
        case 8: return .LINK
        default: return .TEXT
        }
    }

    fileprivate func foldState(from value: Int32) -> FoldState {
        switch value {
        case 1: return .EXPANDED
        case 2: return .COLLAPSED
        default: return .NONE
        }
    }

    fileprivate func guideDirection(from value: Int32) -> GuideDirection {
        switch value {
        case 1: return .VERTICAL
        default: return .HORIZONTAL
        }
    }

    fileprivate func guideType(from value: Int32) -> GuideType {
        switch value {
        case 1: return .BRACKET
        case 2: return .FLOW
        case 3: return .SEPARATOR
        default: return .INDENT
        }
    }

    fileprivate func guideStyle(from value: Int32) -> GuideStyle {
        switch value {
        case 1: return .DASHED
        case 2: return .DOUBLE
        default: return .SOLID
        }
    }

    fileprivate func foldArrowModeName(from value: Int32) -> String {
        switch value {
        case 1: return "ALWAYS"
        case 2: return "HIDDEN"
        default: return "AUTO"
        }
    }

    fileprivate func readPointData(_ reader: inout BinaryReader) -> PointData? {
        guard let x = reader.readFloat(), let y = reader.readFloat() else { return nil }
        return PointData(x: x, y: y)
    }

    fileprivate func readTextPositionData(_ reader: inout BinaryReader) -> TextPositionData? {
        guard let line = reader.readInt32(), let column = reader.readInt32() else { return nil }
        return TextPositionData(line: Int(line), column: Int(column))
    }

    fileprivate func readInlineStyle(_ reader: inout BinaryReader) -> InlineStyle? {
        guard let color = reader.readInt32(),
              let backgroundColor = reader.readInt32(),
              let fontStyle = reader.readInt32() else {
            return nil
        }
        return InlineStyle(font_style: fontStyle, color: color, background_color: backgroundColor)
    }

    fileprivate func readVisualRun(_ reader: inout BinaryReader) -> VisualRun? {
        guard let typeValue = reader.readInt32(),
              let x = reader.readFloat(),
              let y = reader.readFloat(),
              let text = reader.readString(),
              let style = readInlineStyle(&reader),
              let iconId = reader.readInt32(),
              let colorValue = reader.readInt32(),
              let width = reader.readFloat(),
              let padding = reader.readFloat(),
              let margin = reader.readFloat(),
              let active = reader.readInt32() else {
            return nil
        }
        return VisualRun(
            type: visualRunType(from: typeValue),
            x: x,
            y: y,
            text: text,
            style: style,
            icon_id: iconId,
            color_value: colorValue,
            width: width,
            padding: padding,
            margin: margin,
            active: active != 0
        )
    }

    fileprivate func readVisualLine(_ reader: inout BinaryReader) -> VisualLine? {
        guard let logicalLine = reader.readInt32(),
              let wrapIndex = reader.readInt32(),
              let lineNumberPosition = readPointData(&reader),
              let kindValue = reader.readInt32(),
              let ownsGutterSemanticsValue = reader.readInt32(),
              let foldStateValue = reader.readInt32() else {
            return nil
        }

        let gutterIconIds: [Int32] = []
        guard let runCount = reader.readInt32(), runCount >= 0 else { return nil }
        var runs: [VisualRun] = []
        runs.reserveCapacity(Int(runCount))
        for _ in 0..<Int(runCount) {
            guard let run = readVisualRun(&reader) else { return nil }
            runs.append(run)
        }
        return VisualLine(
            logical_line: Int(logicalLine),
            wrap_index: Int(wrapIndex),
            line_number_position: lineNumberPosition,
            runs: runs,
            kind: VisualLineKind(rawValue: Int(kindValue)) ?? .CONTENT,
            owns_gutter_semantics: ownsGutterSemanticsValue != 0,
            gutter_icon_ids: gutterIconIds,
            fold_state: foldState(from: foldStateValue)
        )
    }

    fileprivate func readCursorRender(_ reader: inout BinaryReader) -> Cursor? {
        guard let textPosition = readTextPositionData(&reader),
              let position = readPointData(&reader),
              let height = reader.readFloat(),
              let visible = reader.readInt32(),
              let showDragger = reader.readInt32() else {
            return nil
        }
        return Cursor(
            text_position: textPosition,
            position: position,
            height: height,
            visible: visible != 0,
            show_dragger: showDragger != 0
        )
    }

    fileprivate func readSelectionRect(_ reader: inout BinaryReader) -> SelectionRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return SelectionRect(origin: origin, width: width, height: height)
    }

    fileprivate func readSelectionHandle(_ reader: inout BinaryReader) -> SelectionHandle? {
        guard let position = readPointData(&reader),
              let height = reader.readFloat(),
              let visible = reader.readInt32() else {
            return nil
        }
        return SelectionHandle(position: position, height: height, visible: visible != 0)
    }

    fileprivate func readCompositionDecoration(_ reader: inout BinaryReader) -> CompositionDecoration? {
        guard let active = reader.readInt32(),
              let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return CompositionDecoration(active: active != 0, origin: origin, width: width, height: height)
    }

    fileprivate func readGuideSegment(_ reader: inout BinaryReader) -> GuideSegment? {
        guard let directionValue = reader.readInt32(),
              let typeValue = reader.readInt32(),
              let styleValue = reader.readInt32(),
              let start = readPointData(&reader),
              let end = readPointData(&reader),
              let arrowEnd = reader.readInt32() else {
            return nil
        }
        return GuideSegment(
            direction: guideDirection(from: directionValue),
            type: guideType(from: typeValue),
            style: guideStyle(from: styleValue),
            start: start,
            end: end,
            arrow_end: arrowEnd != 0
        )
    }

    fileprivate func readDiagnosticDecoration(_ reader: inout BinaryReader) -> DiagnosticDecoration? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat(),
              let severity = reader.readInt32() else {
            return nil
        }
        return DiagnosticDecoration(origin: origin, width: width, height: height, severity: severity)
    }

    fileprivate func readLinkedEditingRect(_ reader: inout BinaryReader) -> LinkedEditingRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat(),
              let isActive = reader.readInt32() else {
            return nil
        }
        return LinkedEditingRect(origin: origin, width: width, height: height, is_active: isActive != 0)
    }

    fileprivate func readBracketHighlightRect(_ reader: inout BinaryReader) -> BracketHighlightRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return BracketHighlightRect(origin: origin, width: width, height: height)
    }

    fileprivate func skipGutterIconRenderItem(_ reader: inout BinaryReader) -> Bool {
        guard reader.readInt32() != nil,
              reader.readInt32() != nil,
              readPointData(&reader) != nil,
              reader.readFloat() != nil,
              reader.readFloat() != nil else {
            return false
        }
        return true
    }

    fileprivate func skipFoldMarkerRenderItem(_ reader: inout BinaryReader) -> Bool {
        guard reader.readInt32() != nil,
              reader.readInt32() != nil,
              readPointData(&reader) != nil,
              reader.readFloat() != nil,
              reader.readFloat() != nil else {
            return false
        }
        return true
    }

    fileprivate func defaultScrollbarRect() -> ScrollbarRect {
        ScrollbarRect(origin: PointData(x: 0, y: 0), width: 0, height: 0)
    }

    fileprivate func defaultScrollbarModel() -> ScrollbarModel {
        ScrollbarModel(visible: false, alpha: 0, thumb_active: false, track: defaultScrollbarRect(), thumb: defaultScrollbarRect())
    }

    fileprivate func readScrollbarRect(_ reader: inout BinaryReader) -> ScrollbarRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return ScrollbarRect(origin: origin, width: width, height: height)
    }

    fileprivate func readScrollbarModel(_ reader: inout BinaryReader) -> ScrollbarModel? {
        guard let visible = reader.readInt32(),
              let alpha = reader.readFloat(),
              let thumbActive = reader.readInt32(),
              let track = readScrollbarRect(&reader),
              let thumb = readScrollbarRect(&reader) else {
            return nil
        }
        return ScrollbarModel(visible: visible != 0, alpha: alpha, thumb_active: thumbActive != 0, track: track, thumb: thumb)
    }

    fileprivate func readEditorRenderModel(_ data: Data) -> EditorRenderModel? {
        var reader = BinaryReader(data: data)
        guard let splitX = reader.readFloat(),
              let splitLineVisible = reader.readInt32(),
              let scrollX = reader.readFloat(),
              let scrollY = reader.readFloat(),
              let viewportWidth = reader.readFloat(),
              let viewportHeight = reader.readFloat(),
              let currentLine = readPointData(&reader),
              let currentLineRenderMode = reader.readInt32(),
              let lineCount = reader.readInt32(),
              lineCount >= 0 else {
            return nil
        }

        var lines: [VisualLine] = []
        lines.reserveCapacity(Int(lineCount))
        for _ in 0..<Int(lineCount) {
            guard let line = readVisualLine(&reader) else { return nil }
            lines.append(line)
        }

        guard let gutterIconCount = reader.readInt32(),
              gutterIconCount >= 0 else {
            return nil
        }
        for _ in 0..<Int(gutterIconCount) {
            guard skipGutterIconRenderItem(&reader) else { return nil }
        }

        guard let foldMarkerCount = reader.readInt32(),
              foldMarkerCount >= 0 else {
            return nil
        }
        for _ in 0..<Int(foldMarkerCount) {
            guard skipFoldMarkerRenderItem(&reader) else { return nil }
        }

        guard let cursor = readCursorRender(&reader),
              let selectionRectCount = reader.readInt32(),
              selectionRectCount >= 0 else {
            return nil
        }
        var selectionRects: [SelectionRect] = []
        selectionRects.reserveCapacity(Int(selectionRectCount))
        for _ in 0..<Int(selectionRectCount) {
            guard let rect = readSelectionRect(&reader) else { return nil }
            selectionRects.append(rect)
        }

        guard let selectionStartHandle = readSelectionHandle(&reader),
              let selectionEndHandle = readSelectionHandle(&reader),
              let compositionDecoration = readCompositionDecoration(&reader),
              let guideCount = reader.readInt32(),
              guideCount >= 0 else {
            return nil
        }
        var guideSegments: [GuideSegment] = []
        guideSegments.reserveCapacity(Int(guideCount))
        for _ in 0..<Int(guideCount) {
            guard let segment = readGuideSegment(&reader) else { return nil }
            guideSegments.append(segment)
        }

        guard let diagnosticCount = reader.readInt32(), diagnosticCount >= 0 else { return nil }
        var diagnosticDecorations: [DiagnosticDecoration] = []
        diagnosticDecorations.reserveCapacity(Int(diagnosticCount))
        for _ in 0..<Int(diagnosticCount) {
            guard let decoration = readDiagnosticDecoration(&reader) else { return nil }
            diagnosticDecorations.append(decoration)
        }

        guard let maxGutterIcons = reader.readInt32(),
              let linkedEditingRectCount = reader.readInt32(),
              linkedEditingRectCount >= 0 else {
            return nil
        }
        var linkedEditingRects: [LinkedEditingRect] = []
        linkedEditingRects.reserveCapacity(Int(linkedEditingRectCount))
        for _ in 0..<Int(linkedEditingRectCount) {
            guard let rect = readLinkedEditingRect(&reader) else { return nil }
            linkedEditingRects.append(rect)
        }

        guard let bracketHighlightRectCount = reader.readInt32(), bracketHighlightRectCount >= 0 else {
            return nil
        }
        var bracketHighlightRects: [BracketHighlightRect] = []
        bracketHighlightRects.reserveCapacity(Int(bracketHighlightRectCount))
        for _ in 0..<Int(bracketHighlightRectCount) {
            guard let rect = readBracketHighlightRect(&reader) else { return nil }
            bracketHighlightRects.append(rect)
        }

        var verticalScrollbar = defaultScrollbarModel()
        var horizontalScrollbar = defaultScrollbarModel()
        if reader.data.count - reader.offset >= 88 {
            guard let vertical = readScrollbarModel(&reader),
                  let horizontal = readScrollbarModel(&reader) else {
                return nil
            }
            verticalScrollbar = vertical
            horizontalScrollbar = horizontal
        }

        return EditorRenderModel(
            split_x: splitX,
            scroll_x: scrollX,
            scroll_y: scrollY,
            viewport_width: viewportWidth,
            viewport_height: viewportHeight,
            current_line: currentLine,
            lines: lines,
            cursor: cursor,
            selection_rects: selectionRects,
            selection_start_handle: selectionStartHandle,
            selection_end_handle: selectionEndHandle,
            composition_decoration: compositionDecoration,
            guide_segments: guideSegments,
            diagnostic_decorations: diagnosticDecorations,
            max_gutter_icons: UInt32(bitPattern: maxGutterIcons),
            fold_arrow_x: splitLineVisible != 0 ? Float(currentLineRenderMode) : 0,
            linked_editing_rects: linkedEditingRects,
            bracket_highlight_rects: bracketHighlightRects,
            vertical_scrollbar: verticalScrollbar,
            horizontal_scrollbar: horizontalScrollbar
        )
    }

    fileprivate func readLayoutMetrics(_ data: Data) -> LayoutMetrics? {
        var reader = BinaryReader(data: data)
        guard let fontHeight = reader.readFloat(),
              let fontAscent = reader.readFloat(),
              let lineSpacingAdd = reader.readFloat(),
              let lineSpacingMult = reader.readFloat(),
              let lineNumberMargin = reader.readFloat(),
              let lineNumberWidth = reader.readFloat(),
              let maxGutterIcons = reader.readInt32(),
              let inlayHintPadding = reader.readFloat(),
              let inlayHintMargin = reader.readFloat(),
              let foldArrowMode = reader.readInt32(),
              let hasFoldRegions = reader.readInt32() else {
            return nil
        }

        return LayoutMetrics(
            font_height: fontHeight,
            font_ascent: fontAscent,
            line_spacing_add: lineSpacingAdd,
            line_spacing_mult: lineSpacingMult,
            line_number_margin: lineNumberMargin,
            line_number_width: lineNumberWidth,
            max_gutter_icons: UInt32(bitPattern: maxGutterIcons),
            inlay_hint_padding: inlayHintPadding,
            inlay_hint_margin: inlayHintMargin,
            fold_arrow_mode: foldArrowModeName(from: foldArrowMode),
            has_fold_regions: hasFoldRegions != 0
        )
    }

    fileprivate func defaultScrollMetrics() -> ScrollMetrics {
        ScrollMetrics(
            scale: 1.0,
            scrollX: 0.0,
            scrollY: 0.0,
            maxScrollX: 0.0,
            maxScrollY: 0.0,
            contentWidth: 0.0,
            contentHeight: 0.0,
            viewportWidth: 0.0,
            viewportHeight: 0.0,
            textAreaX: 0.0,
            textAreaWidth: 0.0,
            canScrollX: false,
            canScrollY: false
        )
    }
}
