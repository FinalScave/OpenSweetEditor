import CoreGraphics

struct ScrollbarVisualStyle {
    let trackColor: CGColor
    let thumbColor: CGColor
    let verticalInset: CGFloat
    let horizontalInset: CGFloat
    let longitudinalInset: CGFloat
    let minimumCornerRadius: CGFloat
    let shouldAntialias: Bool

    static func themedDefault(for theme: EditorTheme) -> ScrollbarVisualStyle {
        ScrollbarVisualStyle(
            trackColor: theme.scrollbarTrackColor,
            thumbColor: theme.scrollbarThumbColor,
            verticalInset: 2.0,
            horizontalInset: 2.0,
            longitudinalInset: 1.0,
            minimumCornerRadius: 2.0,
            shouldAntialias: false
        )
    }
}
