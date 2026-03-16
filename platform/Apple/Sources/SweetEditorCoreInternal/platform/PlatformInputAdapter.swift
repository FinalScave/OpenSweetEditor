import Foundation

enum PlatformInputAdapter {
    static var platformName: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "unsupported"
        #endif
    }
}
