import Foundation
import SweetEditorBridge

// MARK: - Style IDs

enum HighlightStyleId: UInt32 {
    case keyword      = 1
    case type         = 2
    case string       = 3
    case comment      = 4
    case number       = 5
    case preprocessor = 6
    case function     = 7
    case classType    = 8
}

// MARK: - Keywords

private let cppKeywords: Set<String> = [
    "auto", "break", "case", "catch", "class", "const", "constexpr", "continue",
    "default", "delete", "do", "else", "enum", "explicit", "extern", "false",
    "for", "friend", "goto", "if", "inline", "mutable", "namespace", "new",
    "noexcept", "nullptr", "operator", "override", "private", "protected",
    "public", "return", "sizeof", "static", "static_cast", "struct", "switch",
    "template", "this", "throw", "true", "try", "typedef", "typeid", "typename",
    "union", "using", "virtual", "void", "volatile", "while",
]

private let cppTypes: Set<String> = [
    "bool", "char", "char16_t", "char32_t", "double", "float", "int", "long",
    "short", "signed", "size_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t",
    "int8_t", "int16_t", "int32_t", "int64_t", "intptr_t", "uintptr_t",
    "unsigned", "wchar_t", "string", "vector", "map", "set", "list",
    "shared_ptr", "unique_ptr", "weak_ptr",
    "String", "Array", "Int", "Float", "Double", "Bool", "UInt",  // Swift types
]

// MARK: - SyntaxHighlighter

class SyntaxHighlighter {
    private weak var editorCore: SweetEditorCore?
    private var inBlockComment = false

    init(editorCore: SweetEditorCore) {
        self.editorCore = editorCore
        registerStyles()
    }

    private func registerStyles() {
        guard let core = editorCore else { return }
        let theme = EditorRenderer.theme
        for (styleId, styleDef) in theme.syntaxStyles {
            core.registerStyle(styleId: styleId, color: styleDef.color, fontStyle: styleDef.fontStyle)
        }
    }

    /// Highlight all lines of a document
    func highlightAll(document: SweetDocument) {
        guard let core = editorCore else { return }
        let lineCount = get_document_line_count(document.handle)
        inBlockComment = false
        for line in 0..<lineCount {
            let spans = highlightLine(document: document, line: line)
            let mapped = spans.map {
                SweetEditorCore.StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId)
            }
            core.setLineSpans(line: Int(line), layer: 0, spans: mapped)
        }
    }

    /// Highlight a single line, returns spans
    func highlightLine(document: SweetDocument, line: Int) -> [(column: UInt32, length: UInt32, styleId: UInt32)] {
        guard let u16Ptr = get_document_line_text(document.handle, line) else { return [] }
        let text = stringFromU16Ptr(u16Ptr)
        free_u16_string(Int(bitPattern: u16Ptr))
        return tokenizeLine(text)
    }

    private func tokenizeLine(_ text: String) -> [(column: UInt32, length: UInt32, styleId: UInt32)] {
        var spans: [(column: UInt32, length: UInt32, styleId: UInt32)] = []
        let chars = Array(text.utf16)
        let len = chars.count
        var i = 0

        // If we're inside a block comment from a previous line
        if inBlockComment {
            if let endIdx = findBlockCommentEnd(chars, from: 0) {
                spans.append((column: 0, length: UInt32(endIdx), styleId: HighlightStyleId.comment.rawValue))
                inBlockComment = false
                i = endIdx
            } else {
                spans.append((column: 0, length: UInt32(len), styleId: HighlightStyleId.comment.rawValue))
                return spans
            }
        }

        while i < len {
            let ch = chars[i]

            // Skip whitespace
            if ch == 0x20 || ch == 0x09 { // space or tab
                i += 1
                continue
            }

            // Line comment //
            if ch == 0x2F && i + 1 < len && chars[i + 1] == 0x2F {
                spans.append((column: UInt32(i), length: UInt32(len - i), styleId: HighlightStyleId.comment.rawValue))
                return spans
            }

            // Block comment /*
            if ch == 0x2F && i + 1 < len && chars[i + 1] == 0x2A {
                let start = i
                i += 2
                if let endIdx = findBlockCommentEnd(chars, from: i) {
                    spans.append((column: UInt32(start), length: UInt32(endIdx - start), styleId: HighlightStyleId.comment.rawValue))
                    i = endIdx
                } else {
                    spans.append((column: UInt32(start), length: UInt32(len - start), styleId: HighlightStyleId.comment.rawValue))
                    inBlockComment = true
                    return spans
                }
                continue
            }

            // Preprocessor directive #
            if ch == 0x23 { // '#'
                spans.append((column: UInt32(i), length: UInt32(len - i), styleId: HighlightStyleId.preprocessor.rawValue))
                return spans
            }

            // String literal " or '
            if ch == 0x22 || ch == 0x27 { // " or '
                let quote = ch
                let start = i
                i += 1
                while i < len {
                    if chars[i] == 0x5C { // backslash escape
                        i += 2
                        continue
                    }
                    if chars[i] == quote {
                        i += 1
                        break
                    }
                    i += 1
                }
                spans.append((column: UInt32(start), length: UInt32(i - start), styleId: HighlightStyleId.string.rawValue))
                continue
            }

            // Number
            if isDigit(ch) || (ch == 0x2E && i + 1 < len && isDigit(chars[i + 1])) {
                let start = i
                i += 1
                while i < len && (isDigit(chars[i]) || chars[i] == 0x2E || chars[i] == 0x78 || chars[i] == 0x58
                                   || chars[i] == 0x66 || chars[i] == 0x46
                                   || (chars[i] >= 0x61 && chars[i] <= 0x66) // a-f
                                   || (chars[i] >= 0x41 && chars[i] <= 0x46) // A-F
                                   || chars[i] == 0x5F) { // _
                    i += 1
                }
                // Trailing suffixes like 'u', 'l', 'f'
                while i < len && (chars[i] == 0x75 || chars[i] == 0x55 || chars[i] == 0x6C || chars[i] == 0x4C) {
                    i += 1
                }
                spans.append((column: UInt32(start), length: UInt32(i - start), styleId: HighlightStyleId.number.rawValue))
                continue
            }

            // Identifier or keyword
            if isIdentStart(ch) {
                let start = i
                i += 1
                while i < len && isIdentChar(chars[i]) {
                    i += 1
                }
                let word = String(utf16CodeUnits: Array(chars[start..<i]), count: i - start)

                if cppKeywords.contains(word) {
                    spans.append((column: UInt32(start), length: UInt32(i - start), styleId: HighlightStyleId.keyword.rawValue))
                } else if cppTypes.contains(word) {
                    spans.append((column: UInt32(start), length: UInt32(i - start), styleId: HighlightStyleId.type.rawValue))
                } else if i < len && chars[i] == 0x28 { // followed by '(' -> function call
                    spans.append((column: UInt32(start), length: UInt32(i - start), styleId: HighlightStyleId.function.rawValue))
                }
                // else: default color, no span needed
                continue
            }

            i += 1
        }

        return spans
    }

    private func findBlockCommentEnd(_ chars: [UInt16], from start: Int) -> Int? {
        var i = start
        while i + 1 < chars.count {
            if chars[i] == 0x2A && chars[i + 1] == 0x2F { // */
                return i + 2
            }
            i += 1
        }
        return nil
    }

    private func isDigit(_ ch: UInt16) -> Bool {
        return ch >= 0x30 && ch <= 0x39 // '0'-'9'
    }

    private func isIdentStart(_ ch: UInt16) -> Bool {
        return (ch >= 0x41 && ch <= 0x5A) || (ch >= 0x61 && ch <= 0x7A) || ch == 0x5F // A-Z, a-z, _
    }

    private func isIdentChar(_ ch: UInt16) -> Bool {
        return isIdentStart(ch) || isDigit(ch)
    }
}
