import XCTest
@testable import SweetEditoriOS
@testable import SweetEditorCoreInternal

#if os(iOS)
import UIKit

final class SweetEditorTextInputTests: XCTestCase {
    func testIOSViewExposesUITextInputTokenizer() {
        let textInput: UITextInput = IOSEditorView(frame: .zero)

        XCTAssertNotNil(textInput.tokenizer)
    }

    func testIOSViewProvidesDocumentBoundaries() {
        let textInput: UITextInput = IOSEditorView(frame: .zero)

        XCTAssertNotNil(textInput.beginningOfDocument)
        XCTAssertNotNil(textInput.endOfDocument)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: textInput.endOfDocument), 0)
    }

    func testIOSViewSupportsSettingSelectedTextRange() {
        let textInput: UITextInput = IOSEditorView(frame: .zero)

        let start = textInput.beginningOfDocument
        let range = textInput.textRange(from: start, to: start)

        XCTAssertNotNil(range)

        textInput.selectedTextRange = range

        XCTAssertNotNil(textInput.selectedTextRange)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: textInput.selectedTextRange!.start), 0)
    }

    func testIOSViewSupportsMarkedTextLifecycle() {
        let textInput: UITextInput = IOSEditorView(frame: .zero)

        textInput.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertNotNil(textInput.markedTextRange)
        XCTAssertEqual(textInput.text(in: textInput.markedTextRange!), "ni")

        textInput.unmarkText()

        XCTAssertNil(textInput.markedTextRange)
    }

    func testSettingUITextSelectionUpdatesEditorCoreCursorAnchor() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc\ndef")

        let textInput: UITextInput = view
        let anchor = textInput.position(from: textInput.beginningOfDocument, offset: 1)
        let range = textInput.textRange(from: anchor!, to: anchor!)

        textInput.selectedTextRange = range

        let cursor = view.getCursorPosition()
        XCTAssertNotNil(cursor)
        XCTAssertEqual(cursor?.line, 0)
        XCTAssertEqual(cursor?.column, 1)
    }

    func testCommittedMarkedTextUsesCurrentCaretInsteadOfStaleAnchor() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let start = textInput.beginningOfDocument
        let end = textInput.position(from: start, offset: 0)
        textInput.selectedTextRange = textInput.textRange(from: end!, to: end!)
        textInput.setMarkedText("n", selectedRange: NSRange(location: 1, length: 0))

        let newCaret = textInput.position(from: textInput.beginningOfDocument, offset: 3)
        textInput.selectedTextRange = textInput.textRange(from: newCaret!, to: newCaret!)
        textInput.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))
        let markedRange = textInput.markedTextRange
        XCTAssertNotNil(markedRange)

        textInput.replace(markedRange!, withText: "你")

        XCTAssertEqual(view.documentLines().joined(separator: "\n"), "abc你")
    }

    func testInsertTextCommitsActiveCompositionAtCurrentCaret() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let newCaret = textInput.position(from: textInput.beginningOfDocument, offset: 3)
        textInput.selectedTextRange = textInput.textRange(from: newCaret!, to: newCaret!)
        textInput.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        view.insertText("你")

        XCTAssertEqual(view.documentLines().joined(separator: "\n"), "abc你")
        XCTAssertNil(textInput.markedTextRange)
    }

    func testReplaceCommittedMarkedTextEndsCoreCompositionState() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let newCaret = textInput.position(from: textInput.beginningOfDocument, offset: 3)
        textInput.selectedTextRange = textInput.textRange(from: newCaret!, to: newCaret!)
        textInput.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        let markedRange = textInput.markedTextRange
        XCTAssertNotNil(markedRange)

        textInput.replace(markedRange!, withText: "你")

        XCTAssertEqual(view.documentLines().joined(separator: "\n"), "abc你")
        XCTAssertFalse(view.isCoreComposing())
    }

    func testMovingSelectionCancelsActiveComposition() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abcdef")

        let textInput: UITextInput = view
        let startCaret = textInput.position(from: textInput.beginningOfDocument, offset: 2)
        textInput.selectedTextRange = textInput.textRange(from: startCaret!, to: startCaret!)
        textInput.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertNotNil(textInput.markedTextRange)
        XCTAssertTrue(view.isCoreComposing())

        let movedCaret = textInput.position(from: textInput.beginningOfDocument, offset: 5)
        textInput.selectedTextRange = textInput.textRange(from: movedCaret!, to: movedCaret!)

        XCTAssertNil(textInput.markedTextRange)
        XCTAssertFalse(view.isCoreComposing())
    }

    func testDirectionalPositionMovesBackwardForLeftDirection() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")
        let textInput: UITextInput = view
        let start = textInput.position(from: textInput.beginningOfDocument, offset: 2)

        let moved = textInput.position(from: start!, in: .left, offset: 1)

        XCTAssertNotNil(moved)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: moved!), 1)
    }

    func testCharacterRangeByExtendingPositionReturnsPreviousCharacterForLeftDirection() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let position = textInput.position(from: textInput.beginningOfDocument, offset: 2)

        let range = textInput.characterRange(byExtending: position!, in: .left)

        XCTAssertNotNil(range)
        XCTAssertEqual(textInput.text(in: range!), "b")
    }

    func testInsertTextReplacesSelectedRange() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abcd")

        let textInput: UITextInput = view
        let start = textInput.position(from: textInput.beginningOfDocument, offset: 1)
        let end = textInput.position(from: textInput.beginningOfDocument, offset: 3)
        textInput.selectedTextRange = textInput.textRange(from: start!, to: end!)

        view.insertText("X")

        XCTAssertEqual(view.documentLines().joined(separator: "\n"), "aXd")
    }

    func testTextInReturnsContextAroundCaretUsingExplicitRanges() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abcd")

        let textInput: UITextInput = view
        let caret = textInput.position(from: textInput.beginningOfDocument, offset: 2)
        let beforeStart = textInput.position(from: caret!, in: .left, offset: 2)
        let afterEnd = textInput.position(from: caret!, in: .right, offset: 2)

        let beforeRange = textInput.textRange(from: beforeStart!, to: caret!)
        let afterRange = textInput.textRange(from: caret!, to: afterEnd!)

        XCTAssertEqual(textInput.text(in: beforeRange!), "ab")
        XCTAssertEqual(textInput.text(in: afterRange!), "cd")
    }

    func testExplicitCursorContextHelpersReadBeforeAfterAndSelectedText() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abcdef")

        let textInput: UITextInput = view
        let start = textInput.position(from: textInput.beginningOfDocument, offset: 2)
        let end = textInput.position(from: textInput.beginningOfDocument, offset: 4)
        textInput.selectedTextRange = textInput.textRange(from: start!, to: end!)

        XCTAssertEqual(view.textBeforeCursor(2), "ab")
        XCTAssertEqual(view.textAfterCursor(2), "ef")
        XCTAssertEqual(view.selectedText(), "cd")
    }

    func testMarkedStateClearsWhenCoreCancelsComposition() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let caret = textInput.position(from: textInput.beginningOfDocument, offset: 1)
        textInput.selectedTextRange = textInput.textRange(from: caret!, to: caret!)
        textInput.setMarkedText("ni", selectedRange: NSRange(location: 2, length: 0))

        XCTAssertTrue(view.isCoreComposing())
        XCTAssertNotNil(textInput.markedTextRange)

        view.cancelCoreCompositionForTesting()

        XCTAssertFalse(view.isCoreComposing())
        XCTAssertNil(textInput.markedTextRange)
    }

    func testSelectedTextRangeTracksMarkedSelectionDuringComposition() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let caret = textInput.position(from: textInput.beginningOfDocument, offset: 1)
        textInput.selectedTextRange = textInput.textRange(from: caret!, to: caret!)
        textInput.setMarkedText("ni", selectedRange: NSRange(location: 1, length: 0))

        let selected = textInput.selectedTextRange

        XCTAssertNotNil(selected)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: selected!.start), 2)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: selected!.end), 2)
    }

    func testDeleteSurroundingTextRemovesBeforeAndAfterCaret() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abcdef")

        let textInput: UITextInput = view
        let caret = textInput.position(from: textInput.beginningOfDocument, offset: 3)
        textInput.selectedTextRange = textInput.textRange(from: caret!, to: caret!)

        view.deleteSurroundingText(before: 2, after: 1)

        XCTAssertEqual(view.documentLines().joined(separator: "\n"), "aef")
    }

    func testSyntaxHighlighterDoesNotSplitKeycapEmojiIntoNumberSpan() {
        let core = SweetEditorCore(fontSize: 14.0, fontName: "Menlo")
        let highlighter = SyntaxHighlighter(editorCore: core)
        let document = SweetDocument(text: "4️⃣")

        let spans = highlighter.highlightLine(document: document, line: 0)

        XCTAssertTrue(spans.isEmpty)
    }

    func testUnmarkTextCommitsMarkedTextAndPlacesCaretAtCommittedEnd() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let caret = textInput.position(from: textInput.beginningOfDocument, offset: 1)
        textInput.selectedTextRange = textInput.textRange(from: caret!, to: caret!)
        textInput.setMarkedText("防护服", selectedRange: NSRange(location: 3, length: 0))

        textInput.unmarkText()

        let selected = textInput.selectedTextRange
        XCTAssertNotNil(selected)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: selected!.start), 4)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: selected!.end), 4)
    }

    func testUnmarkTextKeepsCaretAtEndAfterMarkedTextChangesLength() {
        let view = IOSEditorView(frame: .zero)
        view.loadDocument(text: "abc")

        let textInput: UITextInput = view
        let caret = textInput.position(from: textInput.beginningOfDocument, offset: 1)
        textInput.selectedTextRange = textInput.textRange(from: caret!, to: caret!)
        textInput.setMarkedText("f h f", selectedRange: NSRange(location: 5, length: 0))
        textInput.setMarkedText("防护服", selectedRange: NSRange(location: 3, length: 0))

        textInput.unmarkText()

        let selected = textInput.selectedTextRange
        XCTAssertNotNil(selected)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: selected!.start), 4)
        XCTAssertEqual(textInput.offset(from: textInput.beginningOfDocument, to: selected!.end), 4)
    }

}
#endif
