import Foundation
import CoreGraphics

final class ProtocolDecoder {
    unowned let owner: SweetEditorCore

    init(owner: SweetEditorCore) {
        self.owner = owner
    }

    func decodeEditorActionResult(_ data: Data?) -> EditorActionResultData? {
        owner.parseEditorActionResult(data)
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

    fileprivate func eventType(from value: Int32) -> SEEventType {
        return SEEventType(rawValue: UInt8(clamping: value)) ?? .undefined
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

    fileprivate func editorActionReason(from value: Int32) -> EditorActionReason {
        return EditorActionReason(rawValue: value) ?? .NONE
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

    fileprivate func parseTextPosition(_ reader: inout BinaryReader) -> TextPositionData? {
        guard let line = reader.readInt32(),
              let column = reader.readInt32() else {
            return nil
        }
        return TextPositionData(line: Int(line), column: Int(column))
    }

    fileprivate func parseTextRange(_ reader: inout BinaryReader) -> TextRangeData? {
        guard let start = parseTextPosition(&reader),
              let end = parseTextPosition(&reader) else {
            return nil
        }
        return TextRangeData(start: start, end: end)
    }

    fileprivate func parseHitTarget(_ reader: inout BinaryReader) -> HitTargetData? {
        guard let hitType = reader.readInt32(),
              let hitLine = reader.readInt32(),
              let hitColumn = reader.readInt32(),
              let hitIcon = reader.readInt32(),
              let hitColor = reader.readInt32() else {
            return nil
        }
        return HitTargetData(
            type: hitTargetType(from: hitType),
            line: Int(hitLine),
            column: Int(hitColumn),
            icon_id: Int32(hitIcon),
            color_value: Int32(hitColor)
        )
    }

    fileprivate func parseTextChanges(_ reader: inout BinaryReader) -> [TextChangeData]? {
        guard let count = reader.readInt32(), count >= 0 else { return nil }
        var changes: [TextChangeData] = []
        let changeCount = Int(count)
        changes.reserveCapacity(changeCount)
        for _ in 0..<changeCount {
            guard let change = parseTextChange(&reader) else { return nil }
            changes.append(change)
        }
        return changes
    }

    fileprivate func parseImeSyncSnapshot(_ reader: inout BinaryReader) -> ImeSyncSnapshotData? {
        guard let cursor = parseTextPosition(&reader),
              let hasSelection = reader.readInt32(),
              let selection = parseTextRange(&reader),
              let hasComposingSession = reader.readInt32(),
              let hasVisibleCompositionRange = reader.readInt32(),
              let visibleCompositionRange = parseTextRange(&reader),
              let hasPlatformMarkedRange = reader.readInt32(),
              let platformMarkedRange = parseTextRange(&reader),
              let preeditStorage = reader.readInt32(),
              let contextPolicy = reader.readInt32(),
              let clearPlatformPreedit = reader.readInt32() else {
            return nil
        }
        return ImeSyncSnapshotData(
            cursor: cursor,
            has_selection: hasSelection != 0,
            selection: selection,
            has_composing_session: hasComposingSession != 0,
            has_visible_composition_range: hasVisibleCompositionRange != 0,
            visible_composition_range: visibleCompositionRange,
            has_platform_marked_range: hasPlatformMarkedRange != 0,
            platform_marked_range: platformMarkedRange,
            preedit_storage: preeditStorage,
            context_policy: contextPolicy,
            clear_platform_preedit: clearPlatformPreedit != 0
        )
    }

    fileprivate func parseEditorActionResult(_ data: Data?) -> EditorActionResultData? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let handled = reader.readInt32(),
              let needsRedraw = reader.readInt32(),
              let reasonValue = reader.readInt32(),
              let contentChanged = reader.readInt32(),
              let cursorChanged = reader.readInt32(),
              let selectionChanged = reader.readInt32(),
              let scrollChanged = reader.readInt32(),
              let scaleChanged = reader.readInt32(),
              let pointerCursorChanged = reader.readInt32(),
              let compositionChanged = reader.readInt32(),
              let decorationChanged = reader.readInt32(),
              let needsImeSync = reader.readInt32(),
              let needsEdgeScroll = reader.readInt32(),
              let needsFling = reader.readInt32(),
              let needsAnimation = reader.readInt32(),
              let isHandleDrag = reader.readInt32(),
              let changes = parseTextChanges(&reader),
              let cursorBefore = parseTextPosition(&reader),
              let cursorAfter = parseTextPosition(&reader),
              let hasSelectionBefore = reader.readInt32(),
              let selectionBefore = parseTextRange(&reader),
              let hasSelectionAfter = reader.readInt32(),
              let selectionAfter = parseTextRange(&reader),
              let scrollXBefore = reader.readFloat(),
              let scrollYBefore = reader.readFloat(),
              let scrollXAfter = reader.readFloat(),
              let scrollYAfter = reader.readFloat(),
              let scaleBefore = reader.readFloat(),
              let scaleAfter = reader.readFloat(),
              let pointerCursorBefore = reader.readInt32(),
              let pointerCursorAfter = reader.readInt32(),
              let imeSync = parseImeSyncSnapshot(&reader),
              let gestureTypeValue = reader.readInt32(),
              let gestureEventTypeValue = reader.readInt32(),
              let tapX = reader.readFloat(),
              let tapY = reader.readFloat(),
              let hitTarget = parseHitTarget(&reader),
              let modifiers = reader.readInt32(),
              let command = reader.readInt32() else {
            return nil
        }
        return EditorActionResultData(
            handled: handled != 0,
            needs_redraw: needsRedraw != 0,
            reason: editorActionReason(from: reasonValue),
            content_changed: contentChanged != 0,
            cursor_changed: cursorChanged != 0,
            selection_changed: selectionChanged != 0,
            scroll_changed: scrollChanged != 0,
            scale_changed: scaleChanged != 0,
            pointer_cursor_changed: pointerCursorChanged != 0,
            composition_changed: compositionChanged != 0,
            decoration_changed: decorationChanged != 0,
            needs_ime_sync: needsImeSync != 0,
            needs_edge_scroll: needsEdgeScroll != 0,
            needs_fling: needsFling != 0,
            needs_animation: needsAnimation != 0,
            is_handle_drag: isHandleDrag != 0,
            changes: changes,
            cursor_before: cursorBefore,
            cursor_after: cursorAfter,
            has_selection_before: hasSelectionBefore != 0,
            selection_before: selectionBefore,
            has_selection_after: hasSelectionAfter != 0,
            selection_after: selectionAfter,
            scroll_x_before: scrollXBefore,
            scroll_y_before: scrollYBefore,
            scroll_x_after: scrollXAfter,
            scroll_y_after: scrollYAfter,
            scale_before: scaleBefore,
            scale_after: scaleAfter,
            pointer_cursor_before: pointerCursorBefore,
            pointer_cursor_after: pointerCursorAfter,
            ime_sync: imeSync,
            gesture_type: gestureType(from: gestureTypeValue),
            gesture_event_type: eventType(from: gestureEventTypeValue),
            tap_point: PointData(x: tapX, y: tapY),
            hit_target: hitTarget,
            modifiers: UInt8(clamping: modifiers),
            command: command
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
