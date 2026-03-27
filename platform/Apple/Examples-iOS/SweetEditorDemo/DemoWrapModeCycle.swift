import SweetEditoriOS

enum DemoWrapModeCycle {
    static func next(after mode: WrapMode) -> WrapMode {
        switch mode {
        case .none:
            return .charBreak
        case .charBreak:
            return .wordBreak
        case .wordBreak:
            return .none
        }
    }

    static func title(for mode: WrapMode) -> String {
        switch mode {
        case .none:
            return "Wrap: NONE"
        case .charBreak:
            return "Wrap: CHAR_BREAK"
        case .wordBreak:
            return "Wrap: WORD_BREAK"
        }
    }
}
