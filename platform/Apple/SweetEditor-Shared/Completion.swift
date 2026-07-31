import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Completion Data Models

/// Completion trigger type.
public enum CompletionTriggerKind {
    case invoked
    case character
    case retrigger
}

/// Completion candidate item. Confirmation priority: textEdit -> insertText -> label.
public struct CompletionItem {
    public let label: String
    public var detail: String?
    public var insertText: String?
    public var insertTextFormat: Int = CompletionItem.insertTextFormatPlainText
    public var textEdit: TextEdit?
    public var additionalTextEdits: [TextEdit] = []
    public var filterText: String?
    public var sortKey: String?
    public var kind: Int = 0

    public var matchText: String { filterText ?? label }

    public static let kindKeyword = 0
    public static let kindFunction = 1
    public static let kindVariable = 2
    public static let kindClass = 3
    public static let kindInterface = 4
    public static let kindModule = 5
    public static let kindProperty = 6
    public static let kindSnippet = 7
    public static let kindText = 8

    /// Plain text format (default).
    public static let insertTextFormatPlainText = 1
    /// VSCode snippet format (supports placeholders like $1, ${1:default}, $0).
    public static let insertTextFormatSnippet = 2

    package var kindAbbreviation: String {
        switch kind {
        case Self.kindKeyword: return "K"
        case Self.kindFunction: return "F"
        case Self.kindVariable: return "V"
        case Self.kindClass: return "C"
        case Self.kindInterface: return "I"
        case Self.kindModule: return "M"
        case Self.kindProperty: return "P"
        case Self.kindSnippet: return "S"
        case Self.kindText: return "T"
        default: return "?"
        }
    }

    public init(
        label: String,
        detail: String? = nil,
        kind: Int = 0,
        insertText: String? = nil,
        insertTextFormat: Int = CompletionItem.insertTextFormatPlainText,
        textEdit: TextEdit? = nil,
        additionalTextEdits: [TextEdit] = [],
        filterText: String? = nil,
        sortKey: String? = nil
    ) {
        self.label = label
        self.detail = detail
        self.insertText = insertText
        self.insertTextFormat = insertTextFormat
        self.textEdit = textEdit
        self.additionalTextEdits = additionalTextEdits
        self.filterText = filterText
        self.sortKey = sortKey
        self.kind = kind
    }
}

/// Completion context.
public struct CompletionContext {
    public let triggerKind: CompletionTriggerKind
    public let triggerCharacter: String?
    public let cursorPosition: TextPosition
    public let lineText: String
    public let wordRange: TextRange
    /// Current language configuration (from LanguageConfiguration).
    public let languageConfiguration: LanguageConfiguration?
    /// Host-defined metadata attached to the editor.
    public let editorMetadata: EditorMetadata?
}

/// Provider result.
public struct CompletionResult {
    public let items: [CompletionItem]
    public let isIncomplete: Bool

    public init(items: [CompletionItem], isIncomplete: Bool = false) {
        self.items = items
        self.isIncomplete = isIncomplete
    }
}

// MARK: - Protocols

/// Editor accessor protocol used by CompletionProviderManager to build completion context.
package protocol CompletionEditorAccessor: AnyObject {
    func getCursorPosition() -> TextPosition?
    func getDocument() -> Document?
    func getWordRangeAtCursor() -> TextRange
    /// Current language configuration (from LanguageConfiguration).
    var languageConfiguration: LanguageConfiguration? { get }
    var metadata: EditorMetadata? { get }
}

/// Async callback interface.
public protocol CompletionReceiver: AnyObject {
    @discardableResult
    func accept(_ result: CompletionResult) -> Bool
    var isCancelled: Bool { get }
}

/// Completion provider protocol.
public protocol CompletionProvider: AnyObject {
    func isTriggerCharacter(_ ch: String) -> Bool
    func provideCompletions(context: CompletionContext, receiver: CompletionReceiver)
}

public extension CompletionProvider {
    func isTriggerCharacter(_ ch: String) -> Bool { false }
}

// MARK: - CompletionProviderManager

package final class CompletionProviderManager {
    private var providers: [CompletionProvider] = []
    private var activeReceivers: [ObjectIdentifier: ManagedReceiver] = [:]
    private var debounceItem: DispatchWorkItem?
    private var generation = 0
    private var displayedGeneration = -1
    private var requestActive = false
    private var mergedItems: [CompletionItem] = []

    private let editor: CompletionEditorAccessor
    private let onItemsUpdated: ([CompletionItem]) -> Void
    private let onDismissed: () -> Void

    package init(editor: CompletionEditorAccessor,
                 onItemsUpdated: @escaping ([CompletionItem]) -> Void,
                 onDismissed: @escaping () -> Void) {
        self.editor = editor
        self.onItemsUpdated = onItemsUpdated
        self.onDismissed = onDismissed
    }

    package func addProvider(_ provider: CompletionProvider) {
        if providers.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(provider) }) { return }
        providers.append(provider)
    }

    package func removeProvider(_ provider: CompletionProvider) {
        let key = ObjectIdentifier(provider)
        providers.removeAll { ObjectIdentifier($0) == key }
        activeReceivers[key]?.cancel()
        activeReceivers.removeValue(forKey: key)
    }

    package func triggerCompletion(_ kind: CompletionTriggerKind, triggerCharacter: String? = nil) {
        invalidate()
        guard !providers.isEmpty else {
            onDismissed()
            return
        }

        requestActive = true
        let delay = kind == .invoked ? 0.0 : 0.05
        let requestGeneration = generation
        let item = DispatchWorkItem { [weak self] in
            self?.executeRefresh(
                kind: kind,
                triggerCharacter: triggerCharacter,
                generation: requestGeneration
            )
        }
        debounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    package func dismiss() {
        invalidate()
        onDismissed()
    }

    package func invalidate() {
        debounceItem?.cancel()
        debounceItem = nil
        generation += 1
        cancelAllReceivers()
        mergedItems.removeAll()
        displayedGeneration = -1
        requestActive = false
    }

    package var isActive: Bool {
        requestActive
    }

    package func isTriggerCharacter(_ ch: String) -> Bool {
        for provider in providers {
            if provider.isTriggerCharacter(ch) { return true }
        }
        return false
    }

    package func update(for result: EditorActionResult, isLinkedEditing: Bool) {
        if result.ime_host_action != .NONE {
            dismiss()
            return
        }
        let contextChanged = !result.text_changes.isEmpty
            || result.composition_changed
            || result.cursor_changed
            || result.selection_changed
        guard contextChanged else { return }

        let completionActive = isActive
        if isLinkedEditing {
            dismiss()
            return
        }

        guard result.text_changes.count == 1,
              let change = result.text_changes.first else {
            dismiss()
            return
        }

        let compositionRange = result.ime_state.composition_range
        let compositionActive = result.ime_state.session_id != 0
            && compositionRange.start_utf16 >= 0
            && compositionRange.end_utf16 >= 0
        if compositionActive {
            triggerCompletion(.retrigger)
            return
        }

        let triggerText: String
        if change.new_text.count == 1 {
            triggerText = change.new_text
        } else if result.composition_changed,
                  let lastCharacter = change.new_text.last {
            triggerText = String(lastCharacter)
        } else {
            triggerText = ""
        }

        if !triggerText.isEmpty, isTriggerCharacter(triggerText) {
            triggerCompletion(.character, triggerCharacter: triggerText)
        } else if completionActive {
            triggerCompletion(.retrigger)
        } else if shouldAutoTriggerCompletion(for: change.new_text, source: result.source) {
            triggerCompletion(.invoked)
        } else {
            invalidate()
        }
    }

    package func showItems(_ items: [CompletionItem]) {
        invalidate()
        requestActive = !items.isEmpty
        displayedGeneration = requestActive ? generation : -1
        mergedItems = items
        if items.isEmpty {
            onDismissed()
        } else {
            onItemsUpdated(mergedItems)
        }
    }

    package func consumeDisplayedGeneration() -> Bool {
        let current = requestActive && displayedGeneration == generation
        invalidate()
        return current
    }

    // MARK: - Internal

    private func executeRefresh(
        kind: CompletionTriggerKind,
        triggerCharacter: String?,
        generation requestGeneration: Int
    ) {
        guard requestActive, requestGeneration == generation else { return }
        debounceItem = nil
        mergedItems.removeAll()

        guard let context = buildContext(kind: kind, triggerCharacter: triggerCharacter) else {
            dismiss()
            return
        }

        for provider in providers {
            let key = ObjectIdentifier(provider)
            let receiver = ManagedReceiver(manager: self, generation: requestGeneration)
            activeReceivers[key] = receiver
            provider.provideCompletions(context: context, receiver: receiver)
        }
    }

    private func cancelAllReceivers() {
        for receiver in activeReceivers.values { receiver.cancel() }
        activeReceivers.removeAll()
    }

    private func buildContext(
        kind: CompletionTriggerKind,
        triggerCharacter: String?
    ) -> CompletionContext? {
        guard let cursorPosition = editor.getCursorPosition() else { return nil }
        let lineText = editor.getDocument()?.getLineText(Int(cursorPosition.line)) ?? ""
        return CompletionContext(
            triggerKind: kind,
            triggerCharacter: triggerCharacter,
            cursorPosition: cursorPosition,
            lineText: lineText,
            wordRange: editor.getWordRangeAtCursor(),
            languageConfiguration: editor.languageConfiguration,
            editorMetadata: editor.metadata
        )
    }

    private func onReceiverAccept(result: CompletionResult, receiverGeneration: Int) {
        guard requestActive, receiverGeneration == generation else { return }
        mergedItems.append(contentsOf: result.items)
        mergedItems.sort { ($0.sortKey ?? $0.label) < ($1.sortKey ?? $1.label) }
        if mergedItems.isEmpty {
            onDismissed()
        } else {
            displayedGeneration = generation
            onItemsUpdated(mergedItems)
        }
    }

    private func shouldAutoTriggerCompletion(
        for text: String,
        source: EditorActionSource
    ) -> Bool {
        guard source == .KEYBOARD || source == .IME, text.count == 1 else { return false }
        return text.unicodeScalars.allSatisfy {
            $0.value == 0x5F || CharacterSet.alphanumerics.contains($0)
        }
    }

    // MARK: - ManagedReceiver

    private final class ManagedReceiver: CompletionReceiver {
        private weak var manager: CompletionProviderManager?
        private let receiverGeneration: Int
        private let lock = NSLock()
        private var cancelledValue = false

        init(manager: CompletionProviderManager, generation: Int) {
            self.manager = manager
            self.receiverGeneration = generation
        }

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelledValue
        }

        func cancel() {
            lock.lock()
            cancelledValue = true
            lock.unlock()
        }

        @discardableResult
        func accept(_ result: CompletionResult) -> Bool {
            guard !isCancelled, let manager else { return false }
            DispatchQueue.main.async { [weak manager] in
                manager?.onReceiverAccept(result: result, receiverGeneration: self.receiverGeneration)
            }
            return true
        }
    }
}
