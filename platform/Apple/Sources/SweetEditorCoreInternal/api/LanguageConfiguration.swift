import Foundation

// MARK: - LanguageConfiguration

/// Language configuration describing language-specific metadata such as brackets, comments, and indentation.
/// When set on SweetEditorCore, bracket pairs are automatically synced to Core via `setBracketPairs`.
public struct LanguageConfiguration {

    /// Bracket pair.
    public struct BracketPair {
        public let open: String
        public let close: String

        public init(open: String, close: String) {
            self.open = open
            self.close = close
        }
    }

    /// Block comment pair.
    public struct BlockComment {
        public let open: String
        public let close: String

        public init(open: String, close: String) {
            self.open = open
            self.close = close
        }
    }

    /// Language identifier (for example: "swift", "java", "cpp").
    public let languageId: String

    /// Bracket pair list (synced to Core `setBracketPairs`).
    public let brackets: [BracketPair]

    /// Auto-closing pair list (used by platform-side auto-closing logic).
    public let autoClosingPairs: [BracketPair]

    /// Line-comment prefix (for example: "//").
    public let lineComment: String?

    /// Block-comment pair (for example: ("/*", "*/")).
    public let blockComment: BlockComment?

    /// Tab width (optional; if omitted, editor default is used).
    public let tabSize: Int?

    /// Whether to use spaces instead of tabs (optional).
    public let insertSpaces: Bool?

    public init(languageId: String,
                brackets: [BracketPair] = [],
                autoClosingPairs: [BracketPair] = [],
                lineComment: String? = nil,
                blockComment: BlockComment? = nil,
                tabSize: Int? = nil,
                insertSpaces: Bool? = nil) {
        self.languageId = languageId
        self.brackets = brackets
        self.autoClosingPairs = autoClosingPairs
        self.lineComment = lineComment
        self.blockComment = blockComment
        self.tabSize = tabSize
        self.insertSpaces = insertSpaces
    }
}
