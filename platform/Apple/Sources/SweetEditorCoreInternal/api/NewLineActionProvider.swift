import Foundation

// MARK: - NewLineAction

/// Newline action result describing text to insert when Enter is pressed.
struct NewLineAction {
    /// Full text to insert (including newline and indentation).
    let text: String
}

// MARK: - NewLineContext

/// Newline context used by NewLineActionProvider for indentation decisions.
struct NewLineContext {
    /// Caret line number (0-based).
    let lineNumber: Int
    /// Caret column (0-based).
    let column: Int
    /// Current line text (UTF-16).
    let lineText: String
    /// Language configuration (may be nil).
    let languageConfiguration: LanguageConfiguration?
}

// MARK: - NewLineActionProvider Protocol

/// Smart newline provider protocol.
/// Implement this to customize newline behavior (indentation, continued comments, bracket expansion, etc.).
/// Returning nil means this provider does not handle the case and the next provider can try.
protocol NewLineActionProvider: AnyObject {
    func provideNewLineAction(context: NewLineContext) -> NewLineAction?
}

// MARK: - NewLineActionProviderManager

/// Chain manager for newline providers; uses the first provider that returns non-nil.
class NewLineActionProviderManager {
    private var providers: [NewLineActionProvider] = []

    func addProvider(_ provider: NewLineActionProvider) {
        providers.append(provider)
    }

    func removeProvider(_ provider: NewLineActionProvider) {
        providers.removeAll { $0 === provider }
    }

    /// Iterates all providers and returns the first non-nil NewLineAction; returns nil if none handle it.
    func provideNewLineAction(context: NewLineContext) -> NewLineAction? {
        for provider in providers {
            if let action = provider.provideNewLineAction(context: context) {
                return action
            }
        }
        return nil
    }
}
