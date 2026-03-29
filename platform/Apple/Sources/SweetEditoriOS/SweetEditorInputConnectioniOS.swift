#if os(iOS)
import UIKit
import SweetEditorCoreInternal

final class SweetEditorInputConnectioniOS {
    weak var inputDelegate: UITextInputDelegate?
    lazy var tokenizer: UITextInputTokenizer = UITextInputStringTokenizer(textInput: owner)

    private unowned let owner: IOSEditorView
    private var selectedRangeValue = NSRange(location: 0, length: 0)
    private var markedRangeValue: NSRange?
    private var markedSelectionRangeValue: NSRange?
    private var markedTextValue: String?
    private var isComposing = false

    init(owner: IOSEditorView) {
        self.owner = owner
    }

    private func clearLocalCompositionState() {
        isComposing = false
        markedRangeValue = nil
        markedSelectionRangeValue = nil
        markedTextValue = nil
    }

    var selectedTextRange: UITextRange? {
        get {
            if owner.editorCore.isComposing(), let markedSelectionRangeValue {
                selectedRangeValue = markedSelectionRangeValue
                return owner.uiTextRange(from: markedSelectionRangeValue)
            }

            let derivedRange = owner.currentSelectionNSRange()
            selectedRangeValue = derivedRange
            return owner.uiTextRange(from: derivedRange)
        }
        set {
            guard let range = owner.nsRange(from: newValue) else { return }
            inputDelegate?.selectionWillChange(owner)

            if isComposing,
               let existingMarkedRange = markedRangeValue {
                let selectionStart = range.location
                let selectionEnd = range.location + range.length
                let markedStart = existingMarkedRange.location
                let markedEnd = existingMarkedRange.location + existingMarkedRange.length
                let staysWithinMarkedRange = selectionStart >= markedStart && selectionEnd <= markedEnd

                if !staysWithinMarkedRange {
                    owner.editorCore.compositionCancel()
                    clearLocalCompositionState()
                }
            }

            owner.setSelection(from: range)
            selectedRangeValue = range
            inputDelegate?.selectionDidChange(owner)
        }
    }

    var markedTextRange: UITextRange? {
        guard owner.editorCore.isComposing() else {
            clearLocalCompositionState()
            return nil
        }
        guard let markedRangeValue else { return nil }
        return owner.uiTextRange(from: markedRangeValue)
    }

    func text(in range: UITextRange) -> String? {
        guard let nsRange = owner.nsRange(from: range) else { return nil }
        if let markedRangeValue,
           nsRange.location == markedRangeValue.location,
           nsRange.length == markedRangeValue.length {
            return markedTextValue ?? ""
        }
        return owner.substring(for: nsRange)
    }

    func replace(_ range: UITextRange, withText text: String) {
        guard let nsRange = owner.nsRange(from: range) else { return }
        replace(nsRange, withText: text, marked: false)
    }

    func commitInsertTextIfNeeded(_ text: String) -> Bool {
        guard isComposing else { return false }

        inputDelegate?.selectionWillChange(owner)
        inputDelegate?.textWillChange(owner)

        _ = owner.editorCore.compositionEnd(text)

        clearLocalCompositionState()
        selectedRangeValue = owner.currentSelectionNSRange()

        owner.rehighlightAndRedraw()
        owner.notifyDocumentTextChanged()
        inputDelegate?.textDidChange(owner)
        inputDelegate?.selectionDidChange(owner)
        return true
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        let text = markedText ?? ""

        let currentSelection = owner.currentSelectionNSRange()
        if isComposing,
           let existingMarkedRange = markedRangeValue,
           !NSLocationInRange(currentSelection.location, existingMarkedRange) {
            _ = owner.editorCore.compositionEnd(nil)
            clearLocalCompositionState()
        }

        if !isComposing {
            owner.editorCore.compositionStart()
            isComposing = true
        }

        inputDelegate?.selectionWillChange(owner)
        inputDelegate?.textWillChange(owner)

        owner.editorCore.compositionUpdate(text)

        let baseRange = owner.currentSelectionNSRange()
        markedRangeValue = NSRange(location: baseRange.location, length: text.utf16.count)
        markedTextValue = text

        let clampedLocation = min(max(selectedRange.location, 0), text.utf16.count)
        let clampedLength = min(max(selectedRange.length, 0), max(text.utf16.count - clampedLocation, 0))
        let absoluteRange = NSRange(location: markedRangeValue!.location + clampedLocation, length: clampedLength)
        markedSelectionRangeValue = absoluteRange

        selectedRangeValue = absoluteRange
        owner.rehighlightAndRedraw()
        owner.notifyDocumentTextChanged()
        inputDelegate?.textDidChange(owner)
        inputDelegate?.selectionDidChange(owner)
    }

    func unmarkText() {
        guard isComposing || markedRangeValue != nil else { return }
        inputDelegate?.selectionWillChange(owner)
        inputDelegate?.textWillChange(owner)
        if isComposing {
            let committedText = markedTextValue ?? ""
            _ = owner.editorCore.compositionEnd(committedText.isEmpty ? nil : committedText)
        }
        clearLocalCompositionState()
        selectedRangeValue = owner.currentSelectionNSRange()
        owner.rehighlightAndRedraw()
        owner.notifyDocumentTextChanged()
        inputDelegate?.textDidChange(owner)
        inputDelegate?.selectionDidChange(owner)
    }

    func beginningOfDocument() -> UITextPosition {
        SweetEditorTextPosition(offset: 0)
    }

    func endOfDocument() -> UITextPosition {
        SweetEditorTextPosition(offset: owner.documentLength())
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let start = fromPosition as? SweetEditorTextPosition,
              let end = toPosition as? SweetEditorTextPosition else { return nil }
        return SweetEditorTextRange(start: start, end: end)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let position = position as? SweetEditorTextPosition else { return nil }
        let nextOffset = min(max(position.offset + offset, 0), owner.documentLength())
        return SweetEditorTextPosition(offset: nextOffset)
    }

    func offset(from: UITextPosition, to: UITextPosition) -> Int {
        guard let from = from as? SweetEditorTextPosition,
              let to = to as? SweetEditorTextPosition else { return 0 }
        return to.offset - from.offset
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        guard let position = position as? SweetEditorTextPosition,
              let location = owner.locationForOffset(position.offset) else { return .zero }
        let rect = owner.getPositionRect(line: location.line, column: location.column)
        return CGRect(x: rect.x, y: rect.y, width: 1, height: rect.height)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let nsRange = owner.nsRange(from: range),
              let location = owner.locationForOffset(nsRange.location) else { return .zero }
        let rect = owner.getPositionRect(line: location.line, column: location.column)
        return CGRect(x: rect.x, y: rect.y, width: 1, height: rect.height)
    }

    private func replace(_ range: NSRange, withText text: String, marked: Bool) {
        inputDelegate?.selectionWillChange(owner)
        inputDelegate?.textWillChange(owner)

        owner.replaceText(in: range, with: text)

        let newRange = NSRange(location: range.location, length: text.utf16.count)
        markedRangeValue = marked ? newRange : nil
        markedSelectionRangeValue = marked ? NSRange(location: newRange.location + newRange.length, length: 0) : nil
        markedTextValue = marked ? text : nil
        isComposing = marked
        selectedRangeValue = NSRange(location: newRange.location + newRange.length, length: 0)
        owner.notifyDocumentTextChanged()

        inputDelegate?.textDidChange(owner)
        inputDelegate?.selectionDidChange(owner)
    }
}
#endif
