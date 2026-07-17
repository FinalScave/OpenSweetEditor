#if os(macOS)
import CoreGraphics
import SweetEditorShared

struct MacOSScrollbarRevealRequest {
    let type: SEEventType
    let points: [(Float, Float)]
    let modifiers: SEModifier
    let wheelDeltaX: Float
    let wheelDeltaY: Float
}

struct MacOSScrollbarRevealTrigger {
    func makeRevealRequest(at point: CGPoint, modifiers: SEModifier) -> MacOSScrollbarRevealRequest {
        MacOSScrollbarRevealRequest(
            type: .directScroll,
            points: [(Float(point.x), Float(point.y))],
            modifiers: modifiers,
            wheelDeltaX: 0,
            wheelDeltaY: 0
        )
    }
}
#endif
