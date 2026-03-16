import CoreGraphics

public protocol EditorIconProvider: AnyObject {
    func iconImage(for iconId: Int32) -> CGImage?
}
