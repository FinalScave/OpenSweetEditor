import Foundation

// MARK: - EditorMetadata

/// Editor metadata protocol.
/// External callers can implement this protocol to attach custom metadata to an editor view.
/// Use `as?` to cast it back to the concrete type when reading.
///
/// Example:
/// ```swift
/// class FileMetadata: EditorMetadata {
///     let filePath: String
///     init(filePath: String) { self.filePath = filePath }
/// }
/// editor.metadata = FileMetadata(filePath: "/a/b.cpp")
/// let file = editor.metadata as? FileMetadata
/// ```
public protocol EditorMetadata: AnyObject {}
