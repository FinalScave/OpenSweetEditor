import Foundation

public enum DiagnosticSeverity: Int32 {
    case DIAG_ERROR = 0
    case DIAG_WARNING = 1
    case DIAG_INFO = 2
    case DIAG_HINT = 3

    public static func fromValue(_ value: Int32) -> DiagnosticSeverity {
        switch value {
        case 0: return .DIAG_ERROR
        case 1: return .DIAG_WARNING
        case 2: return .DIAG_INFO
        case 3: return .DIAG_HINT
        default: return .DIAG_ERROR
        }
    }
}

public enum InlayType: Int32 {
    case TEXT = 0
    case ICON = 1
    case COLOR = 2

    public static func fromValue(_ value: Int32) -> InlayType {
        switch value {
        case 0: return .TEXT
        case 1: return .ICON
        case 2: return .COLOR
        default: return .TEXT
        }
    }
}

public enum SeparatorStyle: Int32 {
    case SINGLE = 0
    case DOUBLE = 1

    public static func fromValue(_ value: Int32) -> SeparatorStyle {
        switch value {
        case 0: return .SINGLE
        case 1: return .DOUBLE
        default: return .SINGLE
        }
    }
}

public enum SpanLayer: Int32 {
    case SYNTAX = 0
    case SEMANTIC = 1

    public static func fromValue(_ value: Int32) -> SpanLayer {
        switch value {
        case 0: return .SYNTAX
        case 1: return .SEMANTIC
        default: return .SYNTAX
        }
    }
}

public struct BracketGuide {
    public var parent: TextPosition = TextPosition()
    public var end: TextPosition = TextPosition()
    public var children: [TextPosition] = []

    public init(parent: TextPosition = TextPosition(), end: TextPosition = TextPosition(), children: [TextPosition] = []) {
        self.parent = parent
        self.end = end
        self.children = children
    }
}

public struct CodeLensItem {
    public var column: Int32 = 0
    public var command_id: Int32 = 0
    public var text: String = ""

    public init(column: Int32 = 0, command_id: Int32 = 0, text: String = "") {
        self.column = column
        self.command_id = command_id
        self.text = text
    }
}

public struct Diagnostic {
    public var column: Int32 = 0
    public var length: Int32 = 0
    public var severity: DiagnosticSeverity = .DIAG_ERROR

    public init(column: Int32 = 0, length: Int32 = 0, severity: DiagnosticSeverity = .DIAG_ERROR) {
        self.column = column
        self.length = length
        self.severity = severity
    }
}

public struct FlowGuide {
    public var start: TextPosition = TextPosition()
    public var end: TextPosition = TextPosition()

    public init(start: TextPosition = TextPosition(), end: TextPosition = TextPosition()) {
        self.start = start
        self.end = end
    }
}

public struct FoldRegion {
    public var start_line: Int32 = 0
    public var end_line: Int32 = 0
    public var collapsed: Bool = false

    public init(start_line: Int32 = 0, end_line: Int32 = 0, collapsed: Bool = false) {
        self.start_line = start_line
        self.end_line = end_line
        self.collapsed = collapsed
    }
}

public struct GutterIcon {
    public var icon_id: Int32 = 0

    public init(icon_id: Int32 = 0) {
        self.icon_id = icon_id
    }
}

public struct IndentGuide {
    public var start: TextPosition = TextPosition()
    public var end: TextPosition = TextPosition()

    public init(start: TextPosition = TextPosition(), end: TextPosition = TextPosition()) {
        self.start = start
        self.end = end
    }
}

public struct InlayHint {
    public var type: InlayType = .TEXT
    public var column: Int32 = 0
    public var int_value: Int32 = 0
    public var text: String = ""

    public init(type: InlayType = .TEXT, column: Int32 = 0, int_value: Int32 = 0, text: String = "") {
        self.type = type
        self.column = column
        self.int_value = int_value
        self.text = text
    }
}

public struct LinkSpan {
    public var column: Int32 = 0
    public var length: Int32 = 0
    public var target: String = ""

    public init(column: Int32 = 0, length: Int32 = 0, target: String = "") {
        self.column = column
        self.length = length
        self.target = target
    }
}

public struct PhantomText {
    public var column: Int32 = 0
    public var text: String = ""

    public init(column: Int32 = 0, text: String = "") {
        self.column = column
        self.text = text
    }
}

public struct SeparatorGuide {
    public var line: Int32 = 0
    public var style: SeparatorStyle = .SINGLE
    public var count: Int32 = 0
    public var text_end_column: Int32 = 0

    public init(line: Int32 = 0, style: SeparatorStyle = .SINGLE, count: Int32 = 0, text_end_column: Int32 = 0) {
        self.line = line
        self.style = style
        self.count = count
        self.text_end_column = text_end_column
    }
}

public struct StyleSpan {
    public var column: Int32 = 0
    public var length: Int32 = 0
    public var style_id: Int32 = 0

    public init(column: Int32 = 0, length: Int32 = 0, style_id: Int32 = 0) {
        self.column = column
        self.length = length
        self.style_id = style_id
    }
}

public struct TextStyle {
    public var color: Int32 = 0
    public var background_color: Int32 = 0
    public var font_style: Int32 = 0

    public init(color: Int32 = 0, background_color: Int32 = 0, font_style: Int32 = 0) {
        self.color = color
        self.background_color = background_color
        self.font_style = font_style
    }
}
