import CoreGraphics
import Foundation

public extension AutoIndentMode {
    static let none = AutoIndentMode.NONE
    static let keepIndent = AutoIndentMode.KEEP_INDENT

    init(_ mode: AutoIndentMode) {
        self = mode
    }
}

public extension CurrentLineRenderMode {
    static let background = CurrentLineRenderMode.BACKGROUND
    static let border = CurrentLineRenderMode.BORDER
    static let none = CurrentLineRenderMode.NONE
}

public extension FoldArrowMode {
    static let auto = FoldArrowMode.AUTO
    static let always = FoldArrowMode.ALWAYS
    static let hidden = FoldArrowMode.HIDDEN

    init(_ mode: FoldArrowMode) {
        self = mode
    }
}

public extension WrapMode {
    static let none = WrapMode.NONE
    static let charBreak = WrapMode.CHAR_BREAK
    static let wordBreak = WrapMode.WORD_BREAK

    init(_ mode: WrapMode) {
        self = mode
    }
}

public extension WhitespaceRenderMode {
    static let none = WhitespaceRenderMode.NONE
    static let boundary = WhitespaceRenderMode.BOUNDARY
    static let selection = WhitespaceRenderMode.SELECTION
    static let trailing = WhitespaceRenderMode.TRAILING
    static let all = WhitespaceRenderMode.ALL

    init(_ mode: WhitespaceRenderMode) {
        self = mode
    }
}

public extension SpanLayer {
    static let syntax = SpanLayer.SYNTAX
    static let semantic = SpanLayer.SEMANTIC
}

public extension ScrollbarMode {
    static let always = ScrollbarMode.ALWAYS
    static let transient = ScrollbarMode.TRANSIENT
    static let never = ScrollbarMode.NEVER
}

public extension ScrollbarTrackTapMode {
    static let jump = ScrollbarTrackTapMode.JUMP
    static let disabled = ScrollbarTrackTapMode.DISABLED
}

public extension TextPosition {
    init(line: Int, column: Int) {
        self.init(line: Int32(line), column: Int32(column))
    }
}

public extension TextRange {
    var isCollapsed: Bool {
        start.line == end.line && start.column == end.column
    }
}

public extension IntRange {
    init(start: Int, end: Int) {
        self.init(start: Int32(start), end: Int32(end))
    }

    var isEmpty: Bool {
        end < start
    }

    var length: Int {
        isEmpty ? 0 : Int(end - start + 1)
    }

    func contains(_ value: Int) -> Bool {
        !isEmpty && value >= Int(start) && value <= Int(end)
    }

    static func == (lhs: IntRange, rhs: IntRange) -> Bool {
        lhs.start == rhs.start && lhs.end == rhs.end
    }
}

extension IntRange: Equatable {}

public extension TextChange {
    init(range: TextRange, newText: String) {
        self.init(range: range, new_text: newText)
    }

    var newText: String {
        new_text
    }
}

public extension ScrollbarConfig {
    init(thickness: Float = 10.0,
         minThumb: Float = 24.0,
         thumbHitPadding: Float = 0.0,
         mode: ScrollbarMode = .ALWAYS,
         thumbDraggable: Bool = true,
         trackTapMode: ScrollbarTrackTapMode = .JUMP,
         fadeDelayMs: Int32 = 700,
         fadeDurationMs: Int32 = 300) {
        self.init(
            thickness: thickness,
            min_thumb: minThumb,
            thumb_hit_padding: thumbHitPadding,
            mode: mode,
            thumb_draggable: thumbDraggable,
            track_tap_mode: trackTapMode,
            fade_delay_ms: fadeDelayMs,
            fade_duration_ms: fadeDurationMs
        )
    }

    var minThumb: Float {
        min_thumb
    }

    var thumbHitPadding: Float {
        thumb_hit_padding
    }

    var thumbDraggable: Bool {
        thumb_draggable
    }

    var trackTapMode: ScrollbarTrackTapMode {
        track_tap_mode
    }

    var fadeDelayMs: Int32 {
        fade_delay_ms
    }

    var fadeDurationMs: Int32 {
        fade_duration_ms
    }
}

public extension ScrollMetrics {
    var scrollX: CGFloat { CGFloat(scroll_x) }
    var scrollY: CGFloat { CGFloat(scroll_y) }
    var maxScrollX: CGFloat { CGFloat(max_scroll_x) }
    var maxScrollY: CGFloat { CGFloat(max_scroll_y) }
    var textAreaX: CGFloat { CGFloat(text_area_x) }
    var textAreaWidth: CGFloat { CGFloat(text_area_width) }
    var canScrollX: Bool { can_scroll_x }
    var canScrollY: Bool { can_scroll_y }
}

public extension StyleSpan {
    init(column: UInt32, length: UInt32, styleId: UInt32) {
        self.init(column: Int32(bitPattern: column), length: Int32(bitPattern: length), style_id: Int32(bitPattern: styleId))
    }

    init(column: Int, length: Int, styleId: Int) {
        self.init(column: Int32(column), length: Int32(length), style_id: Int32(styleId))
    }

    init(column: Int32, length: Int32, styleId: Int32) {
        self.init(column: column, length: length, style_id: styleId)
    }
}

public extension Diagnostic {
    init(column: Int, length: Int, severity: Int32) {
        self.init(column: Int32(column), length: Int32(length), severity: DiagnosticSeverity.fromValue(severity))
    }

    init(column: Int32, length: Int32, severity: Int32) {
        self.init(column: column, length: length, severity: DiagnosticSeverity.fromValue(severity))
    }
}

public extension InlayHint {
    static func text(column: Int, text: String) -> InlayHint {
        InlayHint(type: .TEXT, column: Int32(column), int_value: 0, text: text)
    }

    static func icon(column: Int, iconId: Int32) -> InlayHint {
        InlayHint(type: .ICON, column: Int32(column), int_value: iconId, text: "")
    }

    static func color(column: Int, color: Int32) -> InlayHint {
        InlayHint(type: .COLOR, column: Int32(column), int_value: color, text: "")
    }
}

public extension PhantomText {
    init(column: Int, text: String) {
        self.init(column: Int32(column), text: text)
    }
}

public extension GutterIcon {
    init(iconId: Int32) {
        self.init(icon_id: iconId)
    }

    var iconId: Int32 {
        icon_id
    }
}

public extension CodeLensItem {
    init(column: Int, text: String, commandId: Int32) {
        self.init(column: Int32(column), command_id: commandId, text: text)
    }

    init(column: Int32, text: String, commandId: Int32) {
        self.init(column: column, command_id: commandId, text: text)
    }

    var commandId: Int32 {
        command_id
    }
}

public extension LinkSpan {
    init(column: Int, length: Int, target: String) {
        self.init(column: Int32(column), length: Int32(length), target: target)
    }
}

public extension FoldRegion {
    init(startLine: Int, endLine: Int, collapsed: Bool) {
        self.init(start_line: Int32(startLine), end_line: Int32(endLine), collapsed: collapsed)
    }
}

public extension IndentGuide {
    init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        self.init(
            start: TextPosition(line: startLine, column: startColumn),
            end: TextPosition(line: endLine, column: endColumn)
        )
    }
}

public extension BracketGuide {
    init(parentLine: Int, parentColumn: Int, endLine: Int, endColumn: Int, children: [(line: Int, column: Int)]) {
        self.init(
            parent: TextPosition(line: parentLine, column: parentColumn),
            end: TextPosition(line: endLine, column: endColumn),
            children: children.map { TextPosition(line: $0.line, column: $0.column) }
        )
    }
}

public extension FlowGuide {
    init(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        self.init(
            start: TextPosition(line: startLine, column: startColumn),
            end: TextPosition(line: endLine, column: endColumn)
        )
    }
}

public extension SeparatorGuide {
    init(line: Int32, style: SeparatorStyle, count: Int32, textEndColumn: UInt32) {
        self.init(line: line, style: style, count: count, text_end_column: Int32(bitPattern: textEndColumn))
    }
}
