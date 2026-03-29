#if os(iOS)
import UIKit

final class SweetEditorTextPosition: UITextPosition {
    let offset: Int

    init(offset: Int) {
        self.offset = offset
        super.init()
    }
}

final class SweetEditorTextRange: UITextRange {
    let internalStart: SweetEditorTextPosition
    let internalEnd: SweetEditorTextPosition

    override var start: UITextPosition { internalStart }
    override var end: UITextPosition { internalEnd }
    override var isEmpty: Bool { internalStart.offset == internalEnd.offset }

    init(start: SweetEditorTextPosition, end: SweetEditorTextPosition) {
        self.internalStart = start
        self.internalEnd = end
        super.init()
    }
}
#endif
