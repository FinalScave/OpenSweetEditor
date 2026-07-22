#if os(macOS)
import AppKit
import SweetEditorShared

final class InputConnection {
    private unowned let owner: SweetEditorView
    private let imeSession: ImeSession

    init(owner: SweetEditorView) {
        self.owner = owner
        imeSession = ImeSession(core: owner.editorCore)
    }

    var hasComposition: Bool {
        imeSession.hasComposition
    }

    var isSessionActive: Bool {
        imeSession.isActive
    }

    var selectedRange: NSRange {
        imeSession.selectionRange ?? NSRange(location: 0, length: 0)
    }

    var markedRange: NSRange {
        imeSession.compositionRange ?? NSRange(location: NSNotFound, length: 0)
    }

    func beginSession() -> Bool {
        imeSession.isActive || imeSession.begin()
    }

    func endSession() -> EditorActionResult? {
        imeSession.end()
    }

    func setCompositionEnabled(_ enabled: Bool) -> EditorActionResult? {
        imeSession.setEnabled(enabled)
    }

    func commitText(_ text: String, replacementRange: NSRange) -> EditorActionResult? {
        guard imeSession.isActive else { return nil }
        let range = replacementRange.location == NSNotFound ? nil : replacementRange
        return imeSession.commitText(text, replacementRange: range)
    }

    func setMarkedText(
        _ text: String,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) -> EditorActionResult? {
        guard imeSession.isActive else { return nil }
        let range = replacementRange.location == NSNotFound ? nil : replacementRange
        return imeSession.updateComposition(text, selectedRange: selectedRange, replacementRange: range)
    }

    func unmarkText() -> EditorActionResult? {
        guard imeSession.hasComposition else { return nil }
        return imeSession.finishComposition()
    }

    func attributedSubstring(for range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard range.location != NSNotFound,
              let totalLength = imeSession.totalLength else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }
        let start = min(max(range.location, 0), totalLength)
        let end = min(max(range.location + range.length, start), totalLength)
        let normalized = NSRange(location: start, length: end - start)
        guard let text = imeSession.text(in: normalized) else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }
        actualRange?.pointee = normalized
        return NSAttributedString(string: text)
    }

    func synchronize(_ result: EditorActionResult) {
        imeSession.synchronize(result)
        if result.ime_host_action != .NONE {
            owner.inputContext?.discardMarkedText()
            owner.window?.makeFirstResponder(nil)
        }
    }
}
#endif
