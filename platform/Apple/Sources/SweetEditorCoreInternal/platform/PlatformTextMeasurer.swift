import Foundation

enum PlatformTextMeasurer {
    static var defaultFontName: String {
        #if os(iOS)
        return "Menlo"
        #elseif os(macOS)
        return "Menlo"
        #else
        return "Menlo"
        #endif
    }
}
