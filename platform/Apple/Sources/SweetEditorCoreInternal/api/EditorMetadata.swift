import Foundation

// MARK: - EditorMetadata

/// Editor metadata protocol.
/// External callers can implement this protocol to attach custom metadata to a SweetEditorCore instance.
/// Use `as?` to cast it back to the concrete type when reading.
///
/// Example:
/// ```swift
/// class FileMetadata: EditorMetadata {
///     let filePath: String
///     init(filePath: String) { self.filePath = filePath }
/// }
/// editorCore.metadata = FileMetadata(filePath: "/a/b.cpp")
/// let file = editorCore.metadata as? FileMetadata
/// ```
protocol EditorMetadata: AnyObject {}
