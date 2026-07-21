import Foundation

public enum CaretAffinity: Int32 {
    case DOWNSTREAM = 0
    case UPSTREAM = 1

    public static func fromValue(_ value: Int32) -> CaretAffinity? {
        switch value {
        case 0: return .DOWNSTREAM
        case 1: return .UPSTREAM
        default: return nil
        }
    }
}

public struct IntRange {
    public var start: Int32 = 0
    public var end: Int32 = -1

    public init(start: Int32 = 0, end: Int32 = -1) {
        self.start = start
        self.end = end
    }
}

public struct PointF {
    public var x: Float = 0
    public var y: Float = 0

    public init(x: Float = 0, y: Float = 0) {
        self.x = x
        self.y = y
    }
}

public struct Rect {
    public var origin: PointF = PointF()
    public var width: Float = 0
    public var height: Float = 0

    public init(origin: PointF = PointF(), width: Float = 0, height: Float = 0) {
        self.origin = origin
        self.width = width
        self.height = height
    }
}

public struct Size {
    public var width: Float = 0
    public var height: Float = 0

    public init(width: Float = 0, height: Float = 0) {
        self.width = width
        self.height = height
    }
}

public struct TabStopGroup {
    public var index: Int32 = 0
    public var ranges: [TextRange] = []
    public var default_text: String = ""

    public init(index: Int32 = 0, ranges: [TextRange] = [], default_text: String = "") {
        self.index = index
        self.ranges = ranges
        self.default_text = default_text
    }
}

public struct TextChange {
    public var range: TextRange = TextRange()
    public var new_text: String = ""

    public init(range: TextRange = TextRange(), new_text: String = "") {
        self.range = range
        self.new_text = new_text
    }
}

public struct TextEdit {
    public var range: TextRange = TextRange()
    public var new_text: String = ""

    public init(range: TextRange = TextRange(), new_text: String = "") {
        self.range = range
        self.new_text = new_text
    }
}

public struct TextPosition {
    public var line: Int32 = 0
    public var column: Int32 = 0

    public init(line: Int32 = 0, column: Int32 = 0) {
        self.line = line
        self.column = column
    }
}

public struct TextRange {
    public var start: TextPosition = TextPosition()
    public var end: TextPosition = TextPosition()

    public init(start: TextPosition = TextPosition(), end: TextPosition = TextPosition()) {
        self.start = start
        self.end = end
    }
}
