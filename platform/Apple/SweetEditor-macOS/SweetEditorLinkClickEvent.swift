#if os(macOS)
import CoreGraphics

public struct SweetEditorLinkClickEvent {
    public let line: Int
    public let column: Int
    public let target: String
    public let locationInView: CGPoint

    public init(line: Int, column: Int, target: String, locationInView: CGPoint) {
        self.line = line
        self.column = column
        self.target = target
        self.locationInView = locationInView
    }
}
#endif
