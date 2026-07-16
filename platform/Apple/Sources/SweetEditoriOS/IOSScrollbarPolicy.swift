import SweetEditorCoreInternal

struct IOSScrollbarPolicy {
    let defaultThickness: Float = 5.0
    let defaultMinThumb: Float = 48.0
    let defaultThumbHitPadding: Float = 16.0

    func defaultConfig() -> ScrollbarConfig {
        ScrollbarConfig(
            thickness: defaultThickness,
            minThumb: defaultMinThumb,
            thumbHitPadding: defaultThumbHitPadding,
            mode: .TRANSIENT,
            thumbDraggable: true,
            trackTapMode: .DISABLED,
            fadeDelayMs: 700,
            fadeDurationMs: 300
        )
    }
}
