#if os(iOS)
import CoreGraphics

public struct SweetEditorFoldToggleEvent {
    public let line: Int
    public let isGutter: Bool
    public let locationInView: CGPoint

    public init(line: Int, isGutter: Bool, locationInView: CGPoint) {
        self.line = line
        self.isGutter = isGutter
        self.locationInView = locationInView
    }
}
#endif
