import Foundation

package enum EditorSettingChange {
    case font(size: Float, typeface: String)
    case scale(Float)
    case foldArrowMode(FoldArrowMode)
    case wrapMode(WrapMode)
    case renderWhitespace(WhitespaceRenderMode)
    case renderLineBreaks(Bool)
    case lineSpacing(add: Float, mult: Float)
    case contentStartPadding(Float)
    case showSplitLine(Bool)
    case gutterSticky(Bool)
    case gutterVisible(Bool)
    case currentLineRenderMode(CurrentLineRenderMode)
    case autoIndentMode(AutoIndentMode)
    case backspaceUnindent(Bool)
    case readOnly(Bool)
    case compositionEnabled(Bool)
    case maxGutterIcons(UInt32)
    case decorationOverscanViewportMultiplier
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
    private let onChange: (EditorSettingChange) -> Void

    public private(set) var editorTextSize: Float
    public private(set) var typeface: String = "Menlo"
    public private(set) var scale: Float = 1.0
    public private(set) var foldArrowMode: FoldArrowMode = .always
    public private(set) var wrapMode: WrapMode = .none
    public private(set) var renderWhitespace: WhitespaceRenderMode = .none
    public private(set) var renderLineBreaks = false
    public private(set) var lineSpacingAdd: Float = 0.0
    public private(set) var lineSpacingMult: Float = 1.2
    public private(set) var contentStartPadding: Float = 3.0
    public private(set) var showSplitLine = true
    public private(set) var gutterSticky: Bool
    public private(set) var gutterVisible = true
    public private(set) var currentLineRenderMode: CurrentLineRenderMode = .background
    public private(set) var autoIndentMode: AutoIndentMode = .keepIndent
    public private(set) var backspaceUnindent = true
    public private(set) var readOnly = false
    public private(set) var compositionEnabled = true
    public private(set) var maxGutterIcons: UInt32 = 0
    public private(set) var decorationScrollRefreshMinIntervalMs: Int64 = 16
    public private(set) var decorationOverscanViewportMultiplier: Float = 1.5

    package init(editorTextSize: Float,
                 gutterSticky: Bool,
                 onChange: @escaping (EditorSettingChange) -> Void) {
        self.editorTextSize = editorTextSize
        self.gutterSticky = gutterSticky
        self.onChange = onChange
    }

    /// Updates the editor text size and applies the change immediately.
    public func setEditorTextSize(_ textSize: Float) {
        editorTextSize = max(1, textSize)
        apply(.font(size: editorTextSize, typeface: typeface))
    }

    /// Updates the editor typeface and applies the change immediately.
    public func setTypeface(_ typeface: String) {
        self.typeface = typeface
        apply(.font(size: editorTextSize, typeface: typeface))
    }

    /// Updates editor scale and applies the change immediately.
    public func setScale(_ scale: Float) {
        self.scale = scale
        apply(.scale(scale))
    }

    /// Updates fold-arrow rendering mode and applies the change immediately.
    public func setFoldArrowMode(_ mode: FoldArrowMode) {
        foldArrowMode = mode
        apply(.foldArrowMode(mode))
    }

    /// Updates wrapping mode and applies the change immediately.
    public func setWrapMode(_ mode: WrapMode) {
        wrapMode = mode
        apply(.wrapMode(mode))
    }

    /// Updates whitespace marker rendering mode and applies the change immediately.
    public func setRenderWhitespace(_ mode: WhitespaceRenderMode) {
        renderWhitespace = mode
        apply(.renderWhitespace(mode))
    }

    /// Shows or hides line-break markers and applies the change immediately.
    public func setRenderLineBreaks(_ enabled: Bool) {
        renderLineBreaks = enabled
        apply(.renderLineBreaks(enabled))
    }

    /// Updates line spacing and applies the change immediately.
    public func setLineSpacing(add: Float, mult: Float) {
        lineSpacingAdd = add
        lineSpacingMult = mult
        apply(.lineSpacing(add: add, mult: mult))
    }

    /// Updates leading content padding and applies the change immediately.
    public func setContentStartPadding(_ padding: Float) {
        contentStartPadding = max(0, padding)
        apply(.contentStartPadding(contentStartPadding))
    }

    /// Shows or hides the split line and applies the change immediately.
    public func setShowSplitLine(_ show: Bool) {
        showSplitLine = show
        apply(.showSplitLine(show))
    }

    /// Controls whether the gutter remains fixed during horizontal scrolling.
    public func setGutterSticky(_ sticky: Bool) {
        gutterSticky = sticky
        apply(.gutterSticky(sticky))
    }

    /// Shows or hides the gutter area.
    public func setGutterVisible(_ visible: Bool) {
        gutterVisible = visible
        apply(.gutterVisible(visible))
    }

    /// Updates current-line rendering mode and applies the change immediately.
    public func setCurrentLineRenderMode(_ mode: CurrentLineRenderMode) {
        currentLineRenderMode = mode
        apply(.currentLineRenderMode(mode))
    }

    /// Updates auto-indent behavior and applies the change immediately.
    public func setAutoIndentMode(_ mode: AutoIndentMode) {
        autoIndentMode = mode
        apply(.autoIndentMode(mode))
    }

    /// Updates backspace unindent behavior and applies the change immediately.
    public func setBackspaceUnindent(_ enabled: Bool) {
        backspaceUnindent = enabled
        apply(.backspaceUnindent(enabled))
    }

    /// Updates read-only mode and applies the change immediately.
    public func setReadOnly(_ readOnly: Bool) {
        self.readOnly = readOnly
        apply(.readOnly(readOnly))
    }

    public func setCompositionEnabled(_ enabled: Bool) {
        compositionEnabled = enabled
        apply(.compositionEnabled(enabled))
    }

    /// Updates the maximum visible gutter icon count and applies the change immediately.
    public func setMaxGutterIcons(_ count: UInt32) {
        maxGutterIcons = count
        apply(.maxGutterIcons(count))
    }

    public func setDecorationScrollRefreshMinIntervalMs(_ intervalMs: Int64) {
        decorationScrollRefreshMinIntervalMs = max(0, intervalMs)
    }

    public func setDecorationOverscanViewportMultiplier(_ multiplier: Float) {
        decorationOverscanViewportMultiplier = max(0, multiplier)
        apply(.decorationOverscanViewportMultiplier)
    }

    package func applyAll() {
        let changes: [EditorSettingChange] = [
            .font(size: editorTextSize, typeface: typeface),
            .scale(scale),
            .foldArrowMode(foldArrowMode),
            .wrapMode(wrapMode),
            .renderWhitespace(renderWhitespace),
            .renderLineBreaks(renderLineBreaks),
            .lineSpacing(add: lineSpacingAdd, mult: lineSpacingMult),
            .contentStartPadding(contentStartPadding),
            .showSplitLine(showSplitLine),
            .gutterSticky(gutterSticky),
            .gutterVisible(gutterVisible),
            .currentLineRenderMode(currentLineRenderMode),
            .autoIndentMode(autoIndentMode),
            .backspaceUnindent(backspaceUnindent),
            .readOnly(readOnly),
            .compositionEnabled(compositionEnabled),
            .maxGutterIcons(maxGutterIcons),
        ]
        for change in changes {
            apply(change)
        }
    }

    private func apply(_ change: EditorSettingChange) {
        onChange(change)
    }
}
