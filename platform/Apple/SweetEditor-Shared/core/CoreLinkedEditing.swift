import Foundation

public struct LinkedEditingModel {
    public var groups: [TabStopGroup] = []

    public init(groups: [TabStopGroup] = []) {
        self.groups = groups
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
