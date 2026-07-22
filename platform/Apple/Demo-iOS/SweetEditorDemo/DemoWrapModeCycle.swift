import SweetEditorIOS

enum DemoWrapModeCycle {
    static func next(after mode: WrapMode) -> WrapMode {
        switch mode {
        case .NONE:
            return .CHAR_BREAK
        case .CHAR_BREAK:
            return .WORD_BREAK
        case .WORD_BREAK:
            return .NONE
        }
    }

    static func title(for mode: WrapMode) -> String {
        switch mode {
        case .NONE:
            return "Wrap: NONE"
        case .CHAR_BREAK:
            return "Wrap: CHAR_BREAK"
        case .WORD_BREAK:
            return "Wrap: WORD_BREAK"
        }
    }
}
