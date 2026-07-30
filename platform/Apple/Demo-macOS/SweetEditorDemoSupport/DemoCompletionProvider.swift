import Foundation
import SweetEditorMacOS

/// Demonstrates immediate member completion and delayed LSP-style completion.
public final class DemoCompletionProvider: CompletionProvider {

    private let triggerChars: Set<String> = [".", ":"]

    public init() {}

    public func isTriggerCharacter(_ ch: String) -> Bool {
        triggerChars.contains(ch)
    }

    public func provideCompletions(context: CompletionContext, receiver: CompletionReceiver) {
        print("[DemoCompletionProvider] provideCompletions: kind=\(context.triggerKind) trigger='\(context.triggerCharacter ?? "")' cursor=\(context.cursorPosition.line):\(context.cursorPosition.column)")

        if context.triggerKind == .character && context.triggerCharacter == "." {
            // Member completions are available immediately for trigger characters.
            let items: [CompletionItem] = [
                CompletionItem(label: "length", detail: "size_t", kind: CompletionItem.kindProperty,
                              insertText: "length()", sortKey: "a_length"),
                CompletionItem(label: "push_back", detail: "void push_back(T)", kind: CompletionItem.kindFunction,
                              insertText: "push_back()", sortKey: "b_push_back"),
                CompletionItem(label: "begin", detail: "iterator", kind: CompletionItem.kindFunction,
                              insertText: "begin()", sortKey: "c_begin"),
                CompletionItem(label: "end", detail: "iterator", kind: CompletionItem.kindFunction,
                              insertText: "end()", sortKey: "d_end"),
                CompletionItem(label: "size", detail: "size_t", kind: CompletionItem.kindFunction,
                              insertText: "size()", sortKey: "e_size")
            ]
            receiver.accept(CompletionResult(items: items))
            print("[DemoCompletionProvider] Sync push: \(items.count) member candidates")
            return
        }

        // Keyword and identifier completions simulate an asynchronous language server.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            guard !receiver.isCancelled else {
                print("[DemoCompletionProvider] Async completion cancelled")
                return
            }

            var items: [CompletionItem] = [
                CompletionItem(label: "std::string", detail: "class", kind: CompletionItem.kindClass,
                              insertText: "std::string", sortKey: "a_string"),
                CompletionItem(label: "std::vector", detail: "template class", kind: CompletionItem.kindClass,
                              insertText: "std::vector<>", sortKey: "b_vector"),
                CompletionItem(label: "std::cout", detail: "ostream", kind: CompletionItem.kindVariable,
                              insertText: "std::cout", sortKey: "c_cout"),
                CompletionItem(label: "if", detail: "snippet", kind: CompletionItem.kindSnippet,
                              insertText: "if (${1:condition}) {\n\t$0\n}",
                              insertTextFormat: CompletionItem.insertTextFormatSnippet, sortKey: "d_if"),
                CompletionItem(label: "for", detail: "snippet", kind: CompletionItem.kindSnippet,
                              insertText: "for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n\t$0\n}",
                              insertTextFormat: CompletionItem.insertTextFormatSnippet, sortKey: "e_for"),
                CompletionItem(label: "class", detail: "snippet — class definition", kind: CompletionItem.kindSnippet,
                              insertText: "class ${1:ClassName} {\npublic:\n\t${1:ClassName}() {$2}\n\t~${1:ClassName}() {$3}\n$0\n};",
                              insertTextFormat: CompletionItem.insertTextFormatSnippet, sortKey: "f_class"),
                CompletionItem(label: "return", detail: "keyword", kind: CompletionItem.kindKeyword,
                              insertText: "return ", sortKey: "g_return")
            ]
            if let range = Self.identifierRange(in: context) {
                for index in items.indices {
                    items[index].textEdit = TextEdit(
                        range: range,
                        new_text: items[index].insertText ?? items[index].label
                    )
                }
            }
            receiver.accept(CompletionResult(items: items))
            print("[DemoCompletionProvider] Async push: \(items.count) keyword/identifier candidates (200ms delay)")
        }
    }

    private static func identifierRange(in context: CompletionContext) -> TextRange? {
        let range = context.wordRange
        let line = context.cursorPosition.line
        let cursorColumn = Int(context.cursorPosition.column)
        let startColumn = Int(range.start.column)
        let endColumn = Int(range.end.column)
        let codeUnits = Array(context.lineText.utf16)
        guard range.start.line == line,
              range.end.line == line,
              startColumn >= 0,
              startColumn < endColumn,
              cursorColumn >= startColumn,
              cursorColumn <= endColumn,
              endColumn <= codeUnits.count,
              codeUnits[startColumn..<endColumn].allSatisfy(isWordCodeUnit)
        else {
            return nil
        }
        return range
    }

    private static func isWordCodeUnit(_ value: UInt16) -> Bool {
        (value >= 0x61 && value <= 0x7A)
            || (value >= 0x41 && value <= 0x5A)
            || (value >= 0x30 && value <= 0x39)
            || value == 0x5F
            || value > 0x7F
    }
}
