import Foundation
import SweetEditorIOS

final class DemoCompletionProvider: CompletionProvider {
    private static let triggerCharacters: Set<String> = [".", ":"]

    func isTriggerCharacter(_ ch: String) -> Bool {
        Self.triggerCharacters.contains(ch)
    }

    func provideCompletions(context: CompletionContext, receiver: CompletionReceiver) {
        if context.triggerKind == .character && context.triggerCharacter == "." {
            receiver.accept(CompletionResult(items: Self.memberItems()))
            return
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2) {
            guard !receiver.isCancelled else { return }
            let range = Self.identifierRange(in: context)
            let pattern = Self.identifierPrefix(in: context, range: range)
            var items = Self.globalItems().filter {
                pattern.isEmpty
                    || $0.label.hasPrefix(pattern)
                    || ($0.insertText?.hasPrefix(pattern) ?? false)
                    || ($0.filterText?.hasPrefix(pattern) ?? false)
            }
            if let range {
                for index in items.indices {
                    items[index].textEdit = TextEdit(
                        range: range,
                        new_text: items[index].insertText ?? items[index].label
                    )
                }
            }
            guard !receiver.isCancelled else { return }
            receiver.accept(CompletionResult(items: items))
        }
    }

    private static func memberItems() -> [CompletionItem] {
        [
            CompletionItem(label: "length", detail: "size_t", kind: CompletionItem.kindProperty,
                           insertText: "length()", sortKey: "a_length"),
            CompletionItem(label: "push_back", detail: "void push_back(T)", kind: CompletionItem.kindFunction,
                           insertText: "push_back()", sortKey: "b_push_back"),
            CompletionItem(label: "begin", detail: "iterator", kind: CompletionItem.kindFunction,
                           insertText: "begin()", sortKey: "c_begin"),
            CompletionItem(label: "end", detail: "iterator", kind: CompletionItem.kindFunction,
                           insertText: "end()", sortKey: "d_end"),
            CompletionItem(label: "size", detail: "size_t", kind: CompletionItem.kindFunction,
                           insertText: "size()", sortKey: "e_size"),
        ]
    }

    private static func globalItems() -> [CompletionItem] {
        [
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
                           insertText: "return ", sortKey: "g_return"),
        ]
    }

    private static func identifierPrefix(
        in context: CompletionContext,
        range: SweetEditorIOS.TextRange?
    ) -> String {
        guard let range else { return "" }
        let start = Int(range.start.column)
        let cursor = Int(context.cursorPosition.column)
        let codeUnits = Array(context.lineText.utf16)
        guard start <= cursor, cursor <= codeUnits.count else { return "" }
        return String(decoding: codeUnits[start..<cursor], as: UTF16.self)
    }

    private static func identifierRange(in context: CompletionContext) -> SweetEditorIOS.TextRange? {
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
              codeUnits[startColumn..<endColumn].allSatisfy(isWordCodeUnit) else {
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
