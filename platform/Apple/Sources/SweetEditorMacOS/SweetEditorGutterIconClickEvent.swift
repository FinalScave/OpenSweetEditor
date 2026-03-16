#if os(macOS)
import CoreGraphics

public struct SweetEditorGutterIconClickEvent {
    public let line: Int
    public let iconId: Int32
    public let locationInView: CGPoint

    public init(line: Int, iconId: Int32, locationInView: CGPoint) {
        self.line = line
        self.iconId = iconId
        self.locationInView = locationInView
    }
}
#endif
