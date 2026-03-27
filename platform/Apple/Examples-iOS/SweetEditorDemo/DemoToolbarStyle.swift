import Foundation

enum DemoToolbarStyle {
    enum ForegroundRole: Equatable {
        case primary
        case secondary
    }

    static func titleRole(isDarkTheme: Bool) -> ForegroundRole {
        .primary
    }

    static func subtitleRole(isDarkTheme: Bool) -> ForegroundRole {
        .secondary
    }
}
