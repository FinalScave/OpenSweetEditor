#if os(macOS)
import AppKit
import SweetEditorShared

struct ScrollbarPolicy {
    let scrollerStyle: NSScroller.Style

    init(scrollerStyle: NSScroller.Style = NSScroller.preferredScrollerStyle) {
        self.scrollerStyle = scrollerStyle
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

    func visualStyle(for theme: EditorTheme) -> ScrollbarRenderStyle {
        switch scrollerStyle {
        case .legacy:
            return ScrollbarRenderStyle(
                trackColor: theme.scrollbarTrackColor,
                thumbColor: theme.scrollbarThumbColor,
                activeThumbColor: theme.scrollbarThumbActiveColor,
                verticalInset: 1.0,
                horizontalInset: 1.0,
                longitudinalInset: 1.0,
                minimumCornerRadius: 2.0,
                shouldAntialias: false
            )
        case .overlay:
            return ScrollbarRenderStyle.themedDefault(for: theme)
        @unknown default:
            return ScrollbarRenderStyle.themedDefault(for: theme)
        }
    }
}
#endif
