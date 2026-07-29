#if os(iOS)
import UIKit
import SweetEditorShared

final class TextInputPosition: UITextPosition {
    let offset: Int

    init(offset: Int) {
        self.offset = offset
        super.init()
    }
}

final class TextInputRange: UITextRange {
    let internalStart: TextInputPosition
    let internalEnd: TextInputPosition

    override var start: UITextPosition { internalStart }
    override var end: UITextPosition { internalEnd }
    override var isEmpty: Bool { internalStart.offset == internalEnd.offset }

    init(start: TextInputPosition, end: TextInputPosition) {
        self.internalStart = start
        self.internalEnd = end
        super.init()
    }
}

final class InputConnection {
    weak var inputDelegate: UITextInputDelegate?
    lazy var tokenizer: UITextInputTokenizer = UITextInputStringTokenizer(textInput: owner)

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

    var selectedTextRange: UITextRange? {
        get {
            guard let range = imeSession.selectionRange else { return nil }
            return owner.uiTextRange(from: range)
        }
        set {
            guard let range = owner.nsRange(from: newValue) else { return }
            let affinity: CaretAffinity = owner.selectionAffinity == .backward ? .UPSTREAM : .DOWNSTREAM
            owner.dispatchEditorActionResult(
                imeSession.setSelection(range, affinity: affinity),
                notifyInputDelegate: false
            )
        }
    }

    var markedTextRange: UITextRange? {
        guard imeSession.isEnabled,
              let range = imeSession.compositionRange else {
            return nil
        }
        return owner.uiTextRange(from: range)
    }

    var selectionAffinity: UITextStorageDirection {
        get {
            imeSession.state.selection.affinity == .UPSTREAM ? .backward : .forward
        }
        set {
            guard let range = imeSession.selectionRange, range.length == 0 else { return }
            let affinity: CaretAffinity = newValue == .backward ? .UPSTREAM : .DOWNSTREAM
            owner.dispatchEditorActionResult(
                imeSession.setSelection(range, affinity: affinity),
                notifyInputDelegate: false
            )
        }
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
        imeSession.end()
    }

    func setCompositionEnabled(_ enabled: Bool) -> EditorActionResult? {
        imeSession.setEnabled(enabled)
    }

    func text(in range: UITextRange) -> String? {
        guard let range = owner.nsRange(from: range) else { return nil }
        return imeSession.text(in: range)
    }

    func commitText(_ text: String) -> EditorActionResult? {
        guard beginSession() else { return nil }
        return imeSession.commitText(text)
    }

    func replace(_ range: UITextRange, withText text: String) {
        guard let range = owner.nsRange(from: range), imeSession.isActive else { return }
        owner.dispatchEditorActionResult(
            imeSession.commitText(text, replacementRange: range),
            notifyInputDelegate: false
        )
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        guard beginSession() else { return }
        owner.dispatchEditorActionResult(
            imeSession.updateComposition(markedText ?? "", selectedRange: selectedRange),
            notifyInputDelegate: false
        )
    }

    func unmarkText() {
        guard imeSession.hasComposition else { return }
        owner.dispatchEditorActionResult(
            imeSession.finishComposition(),
            notifyInputDelegate: false
        )
    }

    func syncEditorActionResult(
        _ result: EditorActionResult,
        notifyInputDelegate: Bool
    ) -> Bool {
        imeSession.synchronize(result)
        if result.ime_host_action == .CLOSE_SESSION {
            lifecycleVersion &+= 1
            owner.resignFirstResponder()
            return false
        }
        guard result.ime_host_action == .RESTART_SESSION else {
            return false
        }

        lifecycleVersion &+= 1
        let version = lifecycleVersion
        let notifyText = notifyInputDelegate
            && (!result.text_changes.isEmpty || result.composition_changed)
        let notifySelection = notifyInputDelegate
            && (result.cursor_changed || result.selection_changed)
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  version == self.lifecycleVersion,
                  self.owner.isFirstResponder,
                  !self.owner.editorCore.isReadOnly(),
                  self.imeSession.begin() else {
                return
            }
            if notifyText {
                self.inputDelegate?.textDidChange(self.owner)
            }
            if notifySelection {
                self.inputDelegate?.selectionDidChange(self.owner)
            }
        }
        return notifyInputDelegate
    }

    func beginningOfDocument() -> UITextPosition {
        TextInputPosition(offset: 0)
    }

    func endOfDocument() -> UITextPosition {
        TextInputPosition(offset: imeSession.totalLength ?? 0)
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let start = fromPosition as? TextInputPosition,
              let end = toPosition as? TextInputPosition else {
            return nil
        }
        return TextInputRange(start: start, end: end)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let position = position as? TextInputPosition else { return nil }
        let documentLength = imeSession.totalLength ?? 0
        let nextOffset = min(max(position.offset + offset, 0), documentLength)
        return TextInputPosition(offset: nextOffset)
    }

    func offset(from: UITextPosition, to: UITextPosition) -> Int {
        guard let from = from as? TextInputPosition,
              let to = to as? TextInputPosition else {
            return 0
        }
        return to.offset - from.offset
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        guard let position = position as? TextInputPosition,
              let location = owner.locationForOffset(position.offset) else {
            return .zero
        }
        let rect = owner.getPositionRect(line: location.line, column: location.column)
        return CGRect(x: CGFloat(rect.x), y: CGFloat(rect.y), width: 1, height: CGFloat(rect.height))
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let range = owner.nsRange(from: range),
              let location = owner.locationForOffset(range.location) else {
            return .zero
        }
        let rect = owner.getPositionRect(line: location.line, column: location.column)
        return CGRect(x: CGFloat(rect.x), y: CGFloat(rect.y), width: 1, height: CGFloat(rect.height))
    }
}
#endif
