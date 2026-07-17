#if os(macOS)
import AppKit
import SweetEditorShared

struct MacOSScrollbarPolicy {
    let scrollerStyle: NSScroller.Style
    var hoverRevealEnabled: Bool

    init(scrollerStyle: NSScroller.Style = NSScroller.preferredScrollerStyle,
         hoverRevealEnabled: Bool? = nil) {
        self.scrollerStyle = scrollerStyle
        self.hoverRevealEnabled = hoverRevealEnabled ?? (scrollerStyle == .overlay)
    }

    func defaultConfig() -> ScrollbarConfig {
        switch scrollerStyle {
        case .legacy:
            return ScrollbarConfig(
                thickness: 12.0,
                minThumb: 24.0,
                thumbHitPadding: 0.0,
                mode: .ALWAYS,
                thumbDraggable: true,
                trackTapMode: .JUMP,
                fadeDelayMs: 700,
                fadeDurationMs: 300
            )
        case .overlay:
            return ScrollbarConfig(
                thickness: 12.0,
                minThumb: 48.0,
                thumbHitPadding: 16.0,
                mode: .ALWAYS,
                thumbDraggable: true,
                trackTapMode: .DISABLED,
                fadeDelayMs: 700,
                fadeDurationMs: 300
            )
        @unknown default:
            return ScrollbarConfig(
                thickness: 12.0,
                minThumb: 48.0,
                thumbHitPadding: 16.0,
                mode: .ALWAYS,
                thumbDraggable: true,
                trackTapMode: .DISABLED,
                fadeDelayMs: 700,
                fadeDurationMs: 300
            )
        }
    }

    func visualStyle(for theme: EditorTheme) -> ScrollbarVisualStyle {
        switch scrollerStyle {
        case .legacy:
            return ScrollbarVisualStyle(
                trackColor: theme.scrollbarTrackColor,
                thumbColor: theme.scrollbarThumbColor,
                verticalInset: 1.0,
                horizontalInset: 1.0,
                longitudinalInset: 1.0,
                minimumCornerRadius: 2.0,
                shouldAntialias: false
            )
        case .overlay:
            return ScrollbarVisualStyle.themedDefault(for: theme)
        @unknown default:
            return ScrollbarVisualStyle.themedDefault(for: theme)
        }
    }
}
#endif
