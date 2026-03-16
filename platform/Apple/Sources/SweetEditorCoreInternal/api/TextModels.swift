import Foundation

public struct TextPosition {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public struct TextRange {
    public var start: TextPosition
    public var end: TextPosition

    public init(start: TextPosition, end: TextPosition) {
        self.start = start
        self.end = end
    }
}

public struct TextChange {
    public let range: TextRange
    public let newText: String

    public init(range: TextRange, newText: String) {
        self.range = range
        self.newText = newText
    }
}
