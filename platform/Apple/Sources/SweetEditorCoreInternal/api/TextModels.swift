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

    public var isCollapsed: Bool {
        start.line == end.line && start.column == end.column
    }
}

public struct IntRange: Equatable {
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }

    public var isEmpty: Bool {
        end < start
    }

    public func contains(_ value: Int) -> Bool {
        !isEmpty && value >= start && value <= end
    }

    public var length: Int {
        isEmpty ? 0 : (end - start + 1)
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
