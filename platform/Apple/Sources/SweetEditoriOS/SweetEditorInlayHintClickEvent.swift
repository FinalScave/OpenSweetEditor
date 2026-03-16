#if os(iOS)
import CoreGraphics

public enum SweetEditorInlayHintKind {
    case text
    case icon
    case color
}

public struct SweetEditorInlayHintClickEvent {
    public let line: Int
    public let column: Int
    public let kind: SweetEditorInlayHintKind
    public let iconId: Int32
    public let colorValue: Int32
    public let locationInView: CGPoint

    public init(
        line: Int,
        column: Int,
        kind: SweetEditorInlayHintKind,
        iconId: Int32,
        colorValue: Int32,
        locationInView: CGPoint
    ) {
        self.line = line
        self.column = column
        self.kind = kind
        self.iconId = iconId
        self.colorValue = colorValue
        self.locationInView = locationInView
    }
}
#endif
