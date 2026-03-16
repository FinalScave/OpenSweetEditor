import Foundation
import SweetEditorBridge

enum CBridge {
    static func createDocument(from text: String) -> Int {
        return text.withCString(encodedAs: UTF16.self) { pointer in
            create_document_from_utf16(pointer)
        }
    }
}
