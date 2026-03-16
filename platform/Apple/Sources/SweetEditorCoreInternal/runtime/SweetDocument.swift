import Foundation
import SweetEditorBridge

class SweetDocument {
    private(set) var handle: Int = 0

    init(text: String) {
        handle = text.withCString(encodedAs: UTF16.self) { ptr in
            create_document_from_utf16(ptr)
        }
    }

    init(filePath: String) {
        handle = filePath.withCString { cPath in
            create_document_from_file(cPath)
        }
    }

    deinit {
        if handle != 0 {
            free_document(handle)
        }
    }

    /// Returns the text content of a specific line.
    /// - Parameter line: Line number (0-based).
    /// - Returns: Line text, or an empty string when the handle is invalid.
    func getLineText(_ line: Int) -> String {
        guard handle != 0 else { return "" }
        guard let u16Ptr = get_document_line_text(handle, line) else { return "" }
        let text = stringFromU16Ptr(u16Ptr)
        free_u16_string(Int(bitPattern: u16Ptr))
        return text
    }

    /// Current document line count.
    func getLineCount() -> Int {
        guard handle != 0 else { return 0 }
        return Int(get_document_line_count(handle))
    }
}
