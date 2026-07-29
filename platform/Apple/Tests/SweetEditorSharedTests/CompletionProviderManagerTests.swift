import XCTest
@testable import SweetEditorShared

final class CompletionProviderManagerTests: XCTestCase {
    func testRetriggerInvalidatesPreviousReceiverImmediately() {
        let firstRequest = expectation(description: "first request")
        let secondRequest = expectation(description: "second request")
        let provider = DeferredCompletionProvider(expectations: [firstRequest, secondRequest])
        let manager = makeManager()
        manager.addProvider(provider)

        manager.triggerCompletion(.invoked)
        wait(for: [firstRequest], timeout: 1)
        let firstReceiver = provider.receivers[0]

        manager.triggerCompletion(.retrigger)

        XCTAssertTrue(firstReceiver.isCancelled)
        XCTAssertFalse(firstReceiver.accept(CompletionResult(items: [CompletionItem(label: "stale")])))
        wait(for: [secondRequest], timeout: 1)
    }

    func testDisplayedGenerationCanOnlyBeConsumedOnce() {
        let itemsUpdated = expectation(description: "items updated")
        let manager = makeManager(onItemsUpdated: { _ in itemsUpdated.fulfill() })

        manager.showItems([CompletionItem(label: "value")])

        wait(for: [itemsUpdated], timeout: 1)
        XCTAssertTrue(manager.consumeDisplayedGeneration())
        XCTAssertFalse(manager.consumeDisplayedGeneration())
    }

    func testLinkedEditingDismissesActiveCompletion() {
        let dismissed = expectation(description: "dismissed")
        let manager = makeManager(onDismissed: { dismissed.fulfill() })
        manager.showItems([CompletionItem(label: "value")])

        manager.update(
            for: EditorActionResult(cursor_changed: true),
            isLinkedEditing: true
        )

        wait(for: [dismissed], timeout: 1)
        XCTAssertFalse(manager.isActive)
    }

    func testMarkOnlyCompositionDoesNotRequestCompletion() {
        let requested = expectation(description: "completion requested")
        requested.isInverted = true
        let provider = DeferredCompletionProvider(expectations: [requested])
        let manager = makeManager()
        manager.addProvider(provider)

        manager.update(
            for: EditorActionResult(
                composition_changed: true,
                ime_state: ImeState(
                    session_id: 1,
                    composition_range: ImeOffsetRange(start_utf16: 0, end_utf16: 5)
                )
            ),
            isLinkedEditing: false
        )

        wait(for: [requested], timeout: 0.1)
        XCTAssertTrue(provider.receivers.isEmpty)
        XCTAssertFalse(manager.isActive)
    }

    func testMultipleTextChangesDismissWithoutRequestingCompletion() {
        let requested = expectation(description: "completion requested")
        requested.isInverted = true
        let dismissed = expectation(description: "dismissed")
        let provider = DeferredCompletionProvider(expectations: [requested])
        let manager = makeManager(onDismissed: { dismissed.fulfill() })
        manager.addProvider(provider)
        manager.showItems([CompletionItem(label: "value")])

        manager.update(
            for: EditorActionResult(
                text_changes: [
                    TextChange(new_text: "."),
                    TextChange(new_text: "import")
                ]
            ),
            isLinkedEditing: false
        )

        wait(for: [dismissed, requested], timeout: 0.1)
        XCTAssertTrue(provider.receivers.isEmpty)
        XCTAssertFalse(manager.isActive)
    }

    private func makeManager(
        onItemsUpdated: @escaping ([CompletionItem]) -> Void = { _ in },
        onDismissed: @escaping () -> Void = {}
    ) -> CompletionProviderManager {
        CompletionProviderManager(
            editor: CompletionAccessorStub(),
            onItemsUpdated: onItemsUpdated,
            onDismissed: onDismissed
        )
    }
}

private final class CompletionAccessorStub: CompletionEditorAccessor {
    private let document = Document(text: "value")

    func getCursorPosition() -> TextPosition? {
        TextPosition(line: 0, column: 5)
    }

    func getDocument() -> Document? {
        document
    }

    func getWordRangeAtCursor() -> SweetEditorShared.TextRange {
        SweetEditorShared.TextRange(
            start: TextPosition(line: 0, column: 0),
            end: TextPosition(line: 0, column: 5)
        )
    }

    var languageConfiguration: LanguageConfiguration? { nil }
    var metadata: EditorMetadata? { nil }
}

private final class DeferredCompletionProvider: CompletionProvider {
    private var expectations: [XCTestExpectation]
    private(set) var receivers: [CompletionReceiver] = []

    init(expectations: [XCTestExpectation]) {
        self.expectations = expectations
    }

    func isTriggerCharacter(_ ch: String) -> Bool {
        ch == "."
    }

    func provideCompletions(context: CompletionContext, receiver: CompletionReceiver) {
        receivers.append(receiver)
        if !expectations.isEmpty {
            expectations.removeFirst().fulfill()
        }
    }
}
