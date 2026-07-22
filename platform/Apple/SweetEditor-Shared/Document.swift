import Foundation
#if os(iOS)
import SweetEditorCoreIOS
#elseif os(macOS)
import SweetEditorCoreMacOS
#endif

public final class Document {
    private(set) var handle: Int = 0

    public init(text: String) {
        handle = text.withCString(encodedAs: UTF16.self) { ptr in
            create_document_from_utf16(ptr)
        }
    }

    public init(filePath: String) {
        handle = filePath.withCString { cPath in
            create_document_from_file(cPath)
        }
    }

    deinit {
        if handle != 0 {
            free_document(handle)
        }
    }

    /// Returns the complete document text with its original line endings.
    public func getText() -> String {
        guard handle != 0 else { return "" }
        guard let u8Ptr = get_document_utf8(handle) else { return "" }
        defer { free_u8_string(Int(bitPattern: u8Ptr)) }
        return String(cString: u8Ptr)
    }

    /// Returns the text content of a specific line.
    /// - Parameter line: Line number (0-based).
    /// - Returns: Line text, or an empty string when the handle is invalid.
    public func getLineText(_ line: Int) -> String {
        guard handle != 0 else { return "" }
        guard let u16Ptr = get_document_line_utf16(handle, line) else { return "" }
        let text = stringFromU16Ptr(u16Ptr)
        free_u16_string(Int(bitPattern: u16Ptr))
        return text
    }

    /// Current document line count.
    public func getLineCount() -> Int {
        guard handle != 0 else { return 0 }
        return Int(get_document_line_count(handle))
    }
}

package extension Document {
    var editingUTF16Length: Int {
        let lineCount = getLineCount()
        guard lineCount > 0 else { return 0 }

        var length = lineCount - 1
        for line in 0..<lineCount {
            length += getLineText(line).utf16.count
        }
        return length
    }

    func editingLocation(forUTF16Offset offset: Int) -> (line: Int, column: Int) {
        let lineCount = getLineCount()
        guard lineCount > 0 else { return (0, 0) }

        let clampedOffset = min(max(offset, 0), editingUTF16Length)
        var lineStart = 0
        for line in 0..<lineCount {
            let lineLength = getLineText(line).utf16.count
            let lineEnd = lineStart + lineLength
            if clampedOffset <= lineEnd {
                return (line, clampedOffset - lineStart)
            }
            lineStart = lineEnd + 1
        }

        let lastLine = lineCount - 1
        return (lastLine, getLineText(lastLine).utf16.count)
    }

    func editingUTF16Offset(line: Int, column: Int) -> Int {
        let lineCount = getLineCount()
        guard lineCount > 0 else { return 0 }

        let clampedLine = min(max(line, 0), lineCount - 1)
        var offset = clampedLine
        for currentLine in 0..<clampedLine {
            offset += getLineText(currentLine).utf16.count
        }
        let lineLength = getLineText(clampedLine).utf16.count
        return offset + min(max(column, 0), lineLength)
    }
}
