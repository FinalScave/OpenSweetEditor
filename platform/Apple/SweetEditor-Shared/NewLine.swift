import Foundation

// MARK: - NewLineAction

/// Newline action result describing text to insert when Enter is pressed.
public struct NewLineAction {
    /// Full text to insert (including newline and indentation).
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

// MARK: - NewLineContext

/// Newline context used by NewLineActionProvider for indentation decisions.
public struct NewLineContext {
    /// Caret line number (0-based).
    public let lineNumber: Int
    /// Caret column (0-based).
    public let column: Int
    /// Current line text (UTF-16).
    public let lineText: String
    /// Language configuration (may be nil).
    public let languageConfiguration: LanguageConfiguration?
    /// Host-defined metadata attached to the editor.
    public let editorMetadata: EditorMetadata?

    public init(
        lineNumber: Int,
        column: Int,
        lineText: String,
        languageConfiguration: LanguageConfiguration?,
        editorMetadata: EditorMetadata?
    ) {
        self.lineNumber = lineNumber
        self.column = column
        self.lineText = lineText
        self.languageConfiguration = languageConfiguration
        self.editorMetadata = editorMetadata
    }
}

// MARK: - NewLineActionProvider Protocol

/// Smart newline provider protocol.
/// Implement this to customize newline behavior (indentation, continued comments, bracket expansion, etc.).
/// Returning nil means this provider does not handle the case and the next provider can try.
public protocol NewLineActionProvider: AnyObject {
    func provideNewLineAction(context: NewLineContext) -> NewLineAction?
}

// MARK: - NewLineActionProviderManager

/// Chain manager for newline providers; uses the first provider that returns non-nil.
package final class NewLineActionProviderManager {
    private var providers: [NewLineActionProvider] = []

    package init() {}

    package func addProvider(_ provider: NewLineActionProvider) {
        providers.append(provider)
    }

    package func removeProvider(_ provider: NewLineActionProvider) {
        providers.removeAll { $0 === provider }
    }

    /// Iterates all providers and returns the first non-nil NewLineAction; returns nil if none handle it.
    package func provideNewLineAction(context: NewLineContext) -> NewLineAction? {
        for provider in providers {
            if let action = provider.provideNewLineAction(context: context) {
                return action
            }
        }
        return nil
    }
}
