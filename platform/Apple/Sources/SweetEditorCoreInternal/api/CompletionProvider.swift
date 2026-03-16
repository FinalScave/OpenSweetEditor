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

/// Precise replacement edit.
public struct CompletionTextEdit {
    public let range: TextRange
    public let newText: String

    public init(
        range: TextRange,
        newText: String
    ) {
        self.range = range
        self.newText = newText
    }
}

/// Completion candidate item. Confirmation priority: textEdit -> insertText -> label.
public struct CompletionItem {
    public let label: String
    public var detail: String?
    public var iconId: Int = 0
    public var insertText: String?
    public var insertTextFormat: Int = CompletionItem.insertTextFormatPlainText
    public var textEdit: CompletionTextEdit?
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

    public init(
        label: String,
        detail: String? = nil,
        kind: Int = 0,
        insertText: String? = nil,
        insertTextFormat: Int = CompletionItem.insertTextFormatPlainText,
        textEdit: CompletionTextEdit? = nil,
        filterText: String? = nil,
        sortKey: String? = nil,
        iconId: Int = 0
    ) {
        self.label = label
        self.detail = detail
        self.iconId = iconId
        self.insertText = insertText
        self.insertTextFormat = insertTextFormat
        self.textEdit = textEdit
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
protocol CompletionEditorAccessor: AnyObject {
    func getCursorPosition() -> TextPosition?
    func getDocument() -> SweetDocument?
    func getWordRangeAtCursor() -> TextRange
    func getWordAtCursor() -> String
    /// Current language configuration (from LanguageConfiguration).
    var languageConfiguration: LanguageConfiguration? { get }
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

/// Custom rendering protocol.
protocol CompletionItemCellProvider: AnyObject {
    #if os(iOS)
    func createCell() -> UIView
    func bindCell(_ cell: UIView, item: CompletionItem, isSelected: Bool)
    #elseif os(macOS)
    func createCell() -> NSView
    func bindCell(_ cell: NSView, item: CompletionItem, isSelected: Bool)
    #endif
}

// MARK: - CompletionProviderManager

final class CompletionProviderManager {

    var onItemsUpdated: (([CompletionItem]) -> Void)?
    var onDismissed: (() -> Void)?

    // Closures for update callbacks (alternative to delegate)
    var itemsUpdatedHandler: (([CompletionItem]) -> Void)?
    var dismissedHandler: (() -> Void)?

    private var providers: [CompletionProvider] = []
    private var activeReceivers: [ObjectIdentifier: ManagedReceiver] = [:]
    private var debounceItem: DispatchWorkItem?
    private var generation = 0
    private var mergedItems: [CompletionItem] = []

    private var lastTriggerKind: CompletionTriggerKind = .invoked
    private var lastTriggerChar: String?

    private let editor: CompletionEditorAccessor

    init(editor: CompletionEditorAccessor) {
        self.editor = editor
    }

    func addProvider(_ provider: CompletionProvider) {
        if providers.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(provider) }) { return }
        providers.append(provider)
    }

    func removeProvider(_ provider: CompletionProvider) {
        let key = ObjectIdentifier(provider)
        providers.removeAll { ObjectIdentifier($0) == key }
        activeReceivers[key]?.cancel()
        activeReceivers.removeValue(forKey: key)
    }

    func triggerCompletion(_ kind: CompletionTriggerKind, triggerCharacter: String? = nil) {
        if providers.isEmpty { return }
        lastTriggerKind = kind
        lastTriggerChar = triggerCharacter
        debounceItem?.cancel()
        let delay = kind == .invoked ? 0.0 : 0.05
        let item = DispatchWorkItem { [weak self] in
            self?.executeRefresh()
        }
        debounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func dismiss() {
        debounceItem?.cancel()
        generation += 1
        cancelAllReceivers()
        mergedItems.removeAll()
        dismissedHandler?()
    }

    func isTriggerCharacter(_ ch: String) -> Bool {
        for provider in providers {
            if provider.isTriggerCharacter(ch) { return true }
        }
        return false
    }

    func showItems(_ items: [CompletionItem]) {
        debounceItem?.cancel()
        generation += 1
        cancelAllReceivers()
        mergedItems = items
        itemsUpdatedHandler?(mergedItems)
    }

    // MARK: - Internal

    private func executeRefresh() {
        generation += 1
        let currentGen = generation
        cancelAllReceivers()
        mergedItems.removeAll()

        guard let context = buildContext() else { dismiss(); return }

        for provider in providers {
            let key = ObjectIdentifier(provider)
            let receiver = ManagedReceiver(manager: self, provider: provider, generation: currentGen)
            activeReceivers[key] = receiver
            provider.provideCompletions(context: context, receiver: receiver)
        }
    }

    private func cancelAllReceivers() {
        for receiver in activeReceivers.values { receiver.cancel() }
        activeReceivers.removeAll()
    }

    private func buildContext() -> CompletionContext? {
        guard let cursorPosition = editor.getCursorPosition() else { return nil }
        let lineText = editor.getDocument()?.getLineText(cursorPosition.line) ?? ""
        return CompletionContext(
            triggerKind: lastTriggerKind,
            triggerCharacter: lastTriggerChar,
            cursorPosition: cursorPosition,
            lineText: lineText,
            wordRange: editor.getWordRangeAtCursor(),
            languageConfiguration: editor.languageConfiguration
        )
    }

    fileprivate func onReceiverAccept(provider: CompletionProvider, result: CompletionResult, receiverGeneration: Int) {
        guard receiverGeneration == generation else { return }
        mergedItems.append(contentsOf: result.items)
        mergedItems.sort { ($0.sortKey ?? $0.label) < ($1.sortKey ?? $1.label) }
        if mergedItems.isEmpty {
            dismissedHandler?()
        } else {
            itemsUpdatedHandler?(mergedItems)
        }
    }

    // MARK: - ManagedReceiver

    private final class ManagedReceiver: CompletionReceiver {
        private weak var manager: CompletionProviderManager?
        private weak var provider: CompletionProvider?
        private let receiverGeneration: Int
        private var cancelledValue = false

        init(manager: CompletionProviderManager, provider: CompletionProvider, generation: Int) {
            self.manager = manager
            self.provider = provider
            self.receiverGeneration = generation
        }

        var isCancelled: Bool {
            cancelledValue || (manager?.generation != receiverGeneration)
        }

        func cancel() { cancelledValue = true }

        @discardableResult
        func accept(_ result: CompletionResult) -> Bool {
            guard let manager, let provider, !isCancelled else { return false }
            DispatchQueue.main.async { [weak manager] in
                manager?.onReceiverAccept(provider: provider, result: result, receiverGeneration: self.receiverGeneration)
            }
            return true
        }
    }
}
