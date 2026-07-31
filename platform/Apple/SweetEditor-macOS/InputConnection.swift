#if os(macOS)
import AppKit
import SweetEditorShared

final class InputConnection {
    private unowned let owner: SweetEditorView
    private let imeSession: ImeSession
    private var lifecycleVersion: UInt64 = 0

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
        if imeSession.isActive {
            return true
        }
        lifecycleVersion &+= 1
        return imeSession.begin()
    }

    func endSession() -> EditorActionResult? {
        lifecycleVersion &+= 1
        return imeSession.end()
    }

    func setCompositionEnabled(_ enabled: Bool) -> EditorActionResult? {
        imeSession.setEnabled(enabled)
    }

    func commitText(_ text: String, replacementRange: NSRange) -> EditorActionResult? {
        guard beginSession() else { return nil }
        let range = replacementRange.location == NSNotFound ? nil : replacementRange
        return imeSession.commitText(text, replacementRange: range)
    }

    func setMarkedText(
        _ text: String,
        selectedRange: NSRange,
        replacementRange: NSRange
    ) -> EditorActionResult? {
        guard beginSession() else { return nil }
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
        let hadComposition = imeSession.hasComposition
        imeSession.synchronize(result)
        if result.ime_host_action == .CLOSE_SESSION {
            lifecycleVersion &+= 1
            owner.window?.makeFirstResponder(nil)
            return
        }
        guard result.ime_host_action == .RESTART_SESSION else {
            return
        }

        lifecycleVersion &+= 1
        let version = lifecycleVersion
        if hadComposition {
            owner.inputContext?.discardMarkedText()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  version == self.lifecycleVersion,
                  self.owner.window?.firstResponder === self.owner,
                  !self.owner.editorCore.isReadOnly() else {
                return
            }
            _ = self.imeSession.begin()
        }
    }
}
#endif
