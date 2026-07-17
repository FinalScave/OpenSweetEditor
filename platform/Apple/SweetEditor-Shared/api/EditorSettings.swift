import Foundation

protocol EditorSettingsHost: AnyObject {
    func applyEditorSettings(_ settings: EditorSettings)
}

/// Centralized runtime editor configuration shared by Apple platform bindings.
///
/// This type mirrors the Android-side `EditorSettings` design: runtime behavior knobs
/// such as scale, wrapping, read-only mode, line spacing, split-line visibility, and
/// gutter/icon limits live here and take effect immediately when mutated.
///
/// Keep theme, language configuration, highlights, diagnostics, and provider-style
/// integrations outside this type. Those are separate editor concepts and should stay
/// on their dedicated APIs.
public final class EditorSettings {
    private weak var host: EditorSettingsHost?

    public private(set) var editorTextSize: Float = 14.0
    public private(set) var typeface: String = "Menlo"
    public private(set) var scale: Float = 1.0
    public private(set) var foldArrowMode: FoldArrowMode = .always
    public private(set) var wrapMode: WrapMode = .none
    public private(set) var renderWhitespace: WhitespaceRenderMode = .none
    public private(set) var renderLineBreaks = false
    public private(set) var lineSpacingAdd: Float = 0.0
    public private(set) var lineSpacingMult: Float = 1.2
    public private(set) var contentStartPadding: Float = 0.0
    public private(set) var showSplitLine = true
    public private(set) var currentLineRenderMode: CurrentLineRenderMode = .background
    public private(set) var autoIndentMode: AutoIndentMode = .keepIndent
    public private(set) var backspaceUnindent = true
    public private(set) var readOnly = false
    public private(set) var compositionEnabled = true
    public private(set) var maxGutterIcons: UInt32 = 0
    public private(set) var decorationScrollRefreshMinIntervalMs: Int64 = 16
    public private(set) var decorationOverscanViewportMultiplier: Float = 1.5

    init(host: EditorSettingsHost?) {
        self.host = host
    }

    func attachHost(_ host: EditorSettingsHost) {
        self.host = host
    }

    /// Updates the editor text size and applies the change immediately.
    public func setEditorTextSize(_ textSize: Float) {
        editorTextSize = textSize
        apply()
    }

    /// Updates the editor typeface and applies the change immediately.
    public func setTypeface(_ typeface: String) {
        self.typeface = typeface
        apply()
    }

    /// Updates editor scale and applies the change immediately.
    public func setScale(_ scale: Float) {
        self.scale = scale
        apply()
    }

    /// Updates fold-arrow rendering mode and applies the change immediately.
    public func setFoldArrowMode(_ mode: FoldArrowMode) {
        foldArrowMode = mode
        apply()
    }

    /// Updates wrapping mode and applies the change immediately.
    public func setWrapMode(_ mode: WrapMode) {
        wrapMode = mode
        apply()
    }

    /// Updates whitespace marker rendering mode and applies the change immediately.
    public func setRenderWhitespace(_ mode: WhitespaceRenderMode) {
        renderWhitespace = mode
        apply()
    }

    /// Shows or hides line-break markers and applies the change immediately.
    public func setRenderLineBreaks(_ enabled: Bool) {
        renderLineBreaks = enabled
        apply()
    }

    /// Updates line spacing and applies the change immediately.
    public func setLineSpacing(add: Float, mult: Float) {
        lineSpacingAdd = add
        lineSpacingMult = mult
        apply()
    }

    /// Updates leading content padding and applies the change immediately.
    public func setContentStartPadding(_ padding: Float) {
        contentStartPadding = max(0, padding)
        apply()
    }

    /// Shows or hides the split line and applies the change immediately.
    public func setShowSplitLine(_ show: Bool) {
        showSplitLine = show
        apply()
    }

    /// Updates current-line rendering mode and applies the change immediately.
    public func setCurrentLineRenderMode(_ mode: CurrentLineRenderMode) {
        currentLineRenderMode = mode
        apply()
    }

    /// Updates auto-indent behavior and applies the change immediately.
    public func setAutoIndentMode(_ mode: AutoIndentMode) {
        autoIndentMode = mode
        apply()
    }

    /// Updates backspace unindent behavior and applies the change immediately.
    public func setBackspaceUnindent(_ enabled: Bool) {
        backspaceUnindent = enabled
        apply()
    }

    /// Updates read-only mode and applies the change immediately.
    public func setReadOnly(_ readOnly: Bool) {
        self.readOnly = readOnly
        apply()
    }

    public func setCompositionEnabled(_ enabled: Bool) {
        compositionEnabled = enabled
        apply()
    }

    /// Updates the maximum visible gutter icon count and applies the change immediately.
    public func setMaxGutterIcons(_ count: UInt32) {
        maxGutterIcons = count
        apply()
    }

    public func setDecorationScrollRefreshMinIntervalMs(_ intervalMs: Int64) {
        decorationScrollRefreshMinIntervalMs = max(0, intervalMs)
    }

    public func setDecorationOverscanViewportMultiplier(_ multiplier: Float) {
        decorationOverscanViewportMultiplier = max(0, multiplier)
    }

    private func apply() {
        host?.applyEditorSettings(self)
    }
}
