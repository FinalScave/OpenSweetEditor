import CoreGraphics

/// Editor theme configuration with all configurable color properties.
public struct EditorTheme {
    public static let styleKeyword: Int32 = 1
    public static let styleString: Int32 = 2
    public static let styleComment: Int32 = 3
    public static let styleNumber: Int32 = 4
    public static let styleBuiltin: Int32 = 5
    public static let styleType: Int32 = 6
    public static let styleClass: Int32 = 7
    public static let styleFunction: Int32 = 8
    public static let styleVariable: Int32 = 9
    public static let stylePunctuation: Int32 = 10
    public static let styleAnnotation: Int32 = 11
    public static let stylePreprocessor: Int32 = 12
    public static let styleUserBase: Int32 = 100

    public var backgroundColor: CGColor
    public var textColor: CGColor
    public var cursorColor: CGColor
    public var selectionColor: CGColor
    public var selectionTextColor: CGColor
    public var lineNumberColor: CGColor
    public var currentLineNumberColor: CGColor
    public var currentLineColor: CGColor
    public var guideColor: CGColor
    public var separatorLineColor: CGColor
    public var splitLineColor: CGColor
    public var scrollbarTrackColor: CGColor
    public var scrollbarThumbColor: CGColor
    public var scrollbarThumbActiveColor: CGColor
    public var compositionUnderlineColor: CGColor
    public var codeLensColor: CGColor?
    public var codeLensActiveColor: CGColor?
    public var linkColor: CGColor?
    public var linkActiveColor: CGColor?
    public var inlayHintBgColor: CGColor
    public var inlayHintTextColor: CGColor
    public var inlayHintIconColor: CGColor
    public var completionBgColor: CGColor
    public var completionBorderColor: CGColor
    public var completionSelectedBgColor: CGColor
    public var completionLabelColor: CGColor
    public var completionDetailColor: CGColor
    public var selectionMenuBgColor: CGColor
    public var selectionMenuTextColor: CGColor
    public var selectionMenuDividerColor: CGColor

    // Default diagnostic decoration colors (severity: ERROR/WARNING/INFO/HINT).
    public var diagnosticErrorColor: CGColor
    public var diagnosticWarningColor: CGColor
    public var diagnosticInfoColor: CGColor
    public var diagnosticHintColor: CGColor

    // Linked-editing highlight colors.
    public var linkedEditingActiveColor: CGColor
    public var linkedEditingInactiveColor: CGColor

    // Bracket-pair highlight colors.
    public var bracketHighlightBorderColor: CGColor
    public var bracketHighlightBgColor: CGColor

    // Search highlight colors.
    public var searchMatchBgColor: CGColor
    public var searchCurrentBgColor: CGColor
    public var searchCurrentBorderColor: CGColor

    // Document highlight colors.
    public var documentHighlightTextBgColor: CGColor
    public var documentHighlightReadBgColor: CGColor
    public var documentHighlightWriteBgColor: CGColor

    public var foldPlaceholderBgColor: CGColor
    public var foldPlaceholderTextColor: CGColor
    public var phantomTextColor: CGColor
    public var invisibleCharacterColor: CGColor
    public var textStyles: [Int32: TextStyle] = [:]

    public mutating func defineTextStyle(_ styleId: Int32, style: TextStyle) {
        textStyles[styleId] = style
    }

    var guideLineColor: CGColor { guideColor }
    var inlayHintTextAlpha: CGFloat { inlayHintTextColor.alpha }
    var foldPlaceholderBgAlpha: CGFloat { foldPlaceholderBgColor.alpha }
    var foldPlaceholderTextAlpha: CGFloat { foldPlaceholderTextColor.alpha }
    var phantomTextAlpha: CGFloat { phantomTextColor.alpha }

    /// Dark theme aligned with the other platform presets.
    public static func dark() -> EditorTheme {
        EditorTheme(
            backgroundColor: makeColor(0xFF1B1E24),
            textColor: makeColor(0xFFD7DEE9),
            cursorColor: makeColor(0xFF8FB8FF),
            selectionColor: makeColor(0x553B4F72),
            selectionTextColor: makeColor(0xFFFFFFFF),
            lineNumberColor: makeColor(0xFF5E6778),
            currentLineNumberColor: makeColor(0xFF9CB3D6),
            currentLineColor: makeColor(0x503A4A66),
            guideColor: makeColor(0x8056617A),
            separatorLineColor: makeColor(0xFF4A8F7A),
            splitLineColor: makeColor(0x3356617A),
            scrollbarTrackColor: makeColor(0x2AFFFFFF),
            scrollbarThumbColor: makeColor(0x9A7282A0),
            scrollbarThumbActiveColor: makeColor(0xFFAABEDD),
            compositionUnderlineColor: makeColor(0xFF7AA2F7),
            codeLensColor: makeColor(0xC0AFC2E0),
            codeLensActiveColor: makeColor(0xFF9CB3D6),
            linkColor: makeColor(0xFF4C9DFF),
            linkActiveColor: makeColor(0xFF4C9DFF),
            inlayHintBgColor: makeColor(0x223A4A66),
            inlayHintTextColor: makeColor(0xC0AFC2E0),
            inlayHintIconColor: makeColor(0xCC9CB0CD),
            completionBgColor: makeColor(0xF0252830),
            completionBorderColor: makeColor(0x40607090),
            completionSelectedBgColor: makeColor(0x3D5580BB),
            completionLabelColor: makeColor(0xFFD8DEE9),
            completionDetailColor: makeColor(0xFF7A8494),
            selectionMenuBgColor: makeColor(0xF0252830),
            selectionMenuTextColor: makeColor(0xFFD8DEE9),
            selectionMenuDividerColor: makeColor(0x33D8DEE9),
            diagnosticErrorColor: makeColor(0xFFF7768E),
            diagnosticWarningColor: makeColor(0xFFE0AF68),
            diagnosticInfoColor: makeColor(0xFF7DCFFF),
            diagnosticHintColor: makeColor(0xFF8FA3BF),
            linkedEditingActiveColor: makeColor(0xCC7AA2F7),
            linkedEditingInactiveColor: makeColor(0x667AA2F7),
            bracketHighlightBorderColor: makeColor(0xCC9ECE6A),
            bracketHighlightBgColor: makeColor(0x2A9ECE6A),
            searchMatchBgColor: makeColor(0x33E0AF68),
            searchCurrentBgColor: makeColor(0x55E0AF68),
            searchCurrentBorderColor: makeColor(0xFFE0AF68),
            documentHighlightTextBgColor: makeColor(0x1C7AA2F7),
            documentHighlightReadBgColor: makeColor(0x267AA2F7),
            documentHighlightWriteBgColor: makeColor(0x337AA2F7),
            foldPlaceholderBgColor: makeColor(0x36506C90),
            foldPlaceholderTextColor: makeColor(0xFFE2ECFF),
            phantomTextColor: makeColor(0x8AA3B5D1),
            invisibleCharacterColor: makeColor(0x486B7890),
            textStyles: [
                styleKeyword: TextStyle(color: uncheckedARGB(0xFF, 0x7A, 0xA2, 0xF7), font_style: 1),
                styleString: TextStyle(color: uncheckedARGB(0xFF, 0x9E, 0xCE, 0x6A)),
                styleComment: TextStyle(color: uncheckedARGB(0xFF, 0x7A, 0x82, 0x94), font_style: 2),
                styleNumber: TextStyle(color: uncheckedARGB(0xFF, 0xFF, 0x9E, 0x64)),
                styleBuiltin: TextStyle(color: uncheckedARGB(0xFF, 0x7D, 0xCF, 0xFF)),
                styleType: TextStyle(color: uncheckedARGB(0xFF, 0xBB, 0x9A, 0xF7)),
                styleClass: TextStyle(color: uncheckedARGB(0xFF, 0xE0, 0xAF, 0x68), font_style: 1),
                styleFunction: TextStyle(color: uncheckedARGB(0xFF, 0x73, 0xDA, 0xCA)),
                styleVariable: TextStyle(color: uncheckedARGB(0xFF, 0xD7, 0xDE, 0xE9)),
                stylePunctuation: TextStyle(color: uncheckedARGB(0xFF, 0xB0, 0xBE, 0xD3)),
                styleAnnotation: TextStyle(color: uncheckedARGB(0xFF, 0x2A, 0xC3, 0xDE)),
                stylePreprocessor: TextStyle(color: uncheckedARGB(0xFF, 0xF7, 0x76, 0x8E)),
            ]
        )
    }

    /// Light theme aligned with the other platform presets.
    public static func light() -> EditorTheme {
        EditorTheme(
            backgroundColor: makeColor(0xFFFAFBFD),
            textColor: makeColor(0xFF1F2937),
            cursorColor: makeColor(0xFF2563EB),
            selectionColor: makeColor(0x4D60A5FA),
            selectionTextColor: makeColor(0xFFFFFFFF),
            lineNumberColor: makeColor(0xFF8A94A6),
            currentLineNumberColor: makeColor(0xFF3A5FA0),
            currentLineColor: makeColor(0x1A0D3B66),
            guideColor: makeColor(0x4029426B),
            separatorLineColor: makeColor(0xFF2F855A),
            splitLineColor: makeColor(0x1F29426B),
            scrollbarTrackColor: makeColor(0x1F2A3B55),
            scrollbarThumbColor: makeColor(0x80446C9C),
            scrollbarThumbActiveColor: makeColor(0xEE6A9AD0),
            compositionUnderlineColor: makeColor(0xFF2563EB),
            codeLensColor: makeColor(0xB0344A73),
            codeLensActiveColor: makeColor(0xFF3A5FA0),
            linkColor: makeColor(0xFF4C9DFF),
            linkActiveColor: makeColor(0xFF4C9DFF),
            inlayHintBgColor: makeColor(0x143B82F6),
            inlayHintTextColor: makeColor(0xB0344A73),
            inlayHintIconColor: makeColor(0xB04B607E),
            completionBgColor: makeColor(0xF0FAFBFD),
            completionBorderColor: makeColor(0x30A0A8B8),
            completionSelectedBgColor: makeColor(0x3D3B82F6),
            completionLabelColor: makeColor(0xFF1F2937),
            completionDetailColor: makeColor(0xFF8A94A6),
            selectionMenuBgColor: makeColor(0xF0FAFBFD),
            selectionMenuTextColor: makeColor(0xFF1F2937),
            selectionMenuDividerColor: makeColor(0x331F2937),
            diagnosticErrorColor: makeColor(0xFFDC2626),
            diagnosticWarningColor: makeColor(0xFFD97706),
            diagnosticInfoColor: makeColor(0xFF0EA5E9),
            diagnosticHintColor: makeColor(0xFF64748B),
            linkedEditingActiveColor: makeColor(0xCC2563EB),
            linkedEditingInactiveColor: makeColor(0x662563EB),
            bracketHighlightBorderColor: makeColor(0xCC0F766E),
            bracketHighlightBgColor: makeColor(0x260F766E),
            searchMatchBgColor: makeColor(0x33F59E0B),
            searchCurrentBgColor: makeColor(0x55F59E0B),
            searchCurrentBorderColor: makeColor(0xFFD97706),
            documentHighlightTextBgColor: makeColor(0x142563EB),
            documentHighlightReadBgColor: makeColor(0x1C2563EB),
            documentHighlightWriteBgColor: makeColor(0x282563EB),
            foldPlaceholderBgColor: makeColor(0x2E748DB0),
            foldPlaceholderTextColor: makeColor(0xFF284A70),
            phantomTextColor: makeColor(0x8A4B607E),
            invisibleCharacterColor: makeColor(0x405D6B82),
            textStyles: [
                styleKeyword: TextStyle(color: uncheckedARGB(0xFF, 0x35, 0x59, 0xD6), font_style: 1),
                styleString: TextStyle(color: uncheckedARGB(0xFF, 0x0F, 0x7B, 0x6C)),
                styleComment: TextStyle(color: uncheckedARGB(0xFF, 0x7B, 0x87, 0x98), font_style: 2),
                styleNumber: TextStyle(color: uncheckedARGB(0xFF, 0xB4, 0x53, 0x09)),
                styleBuiltin: TextStyle(color: uncheckedARGB(0xFF, 0x00, 0x6E, 0x7F)),
                styleType: TextStyle(color: uncheckedARGB(0xFF, 0x6D, 0x28, 0xD9)),
                styleClass: TextStyle(color: uncheckedARGB(0xFF, 0x9A, 0x34, 0x12), font_style: 1),
                styleFunction: TextStyle(color: uncheckedARGB(0xFF, 0x0E, 0x74, 0x90)),
                styleVariable: TextStyle(color: uncheckedARGB(0xFF, 0x1F, 0x29, 0x37)),
                stylePunctuation: TextStyle(color: uncheckedARGB(0xFF, 0x6E, 0x82, 0xA0)),
                styleAnnotation: TextStyle(color: uncheckedARGB(0xFF, 0x0F, 0x76, 0x6E)),
                stylePreprocessor: TextStyle(color: uncheckedARGB(0xFF, 0xBE, 0x12, 0x3C)),
            ]
        )
    }

    /// Xcode Default dark theme.
    public static func xcodeDark() -> EditorTheme {
        var theme = dark()
        theme.backgroundColor = makeColor(0xFF1F1F24)
        theme.textColor = makeColor(0xD9FFFFFF)
        theme.cursorColor = makeColor(0xFFFFFFFF)
        theme.selectionColor = makeColor(0xFF515B70)
        theme.selectionTextColor = makeColor(0xD9FFFFFF)
        theme.lineNumberColor = makeColor(0xFF6C7986)
        theme.currentLineNumberColor = makeColor(0xD9FFFFFF)
        theme.currentLineColor = makeColor(0xFF23252B)
        theme.guideColor = makeColor(0x80424D5B)
        theme.separatorLineColor = makeColor(0xFF5D6875)
        theme.splitLineColor = makeColor(0x66424D5B)
        theme.scrollbarTrackColor = makeColor(0x1FFFFFFF)
        theme.scrollbarThumbColor = makeColor(0x805D6875)
        theme.scrollbarThumbActiveColor = makeColor(0xBFA0A8B4)
        theme.compositionUnderlineColor = makeColor(0xFF5482FF)
        theme.codeLensColor = makeColor(0xC06C7986)
        theme.codeLensActiveColor = makeColor(0xD9FFFFFF)
        theme.linkColor = makeColor(0xFF5482FF)
        theme.linkActiveColor = makeColor(0xFF79A0FF)
        theme.inlayHintBgColor = makeColor(0x40333A46)
        theme.inlayHintTextColor = makeColor(0xD96C7986)
        theme.inlayHintIconColor = makeColor(0xD98A96A3)
        theme.completionBgColor = makeColor(0xFA292A30)
        theme.completionBorderColor = makeColor(0x80515B70)
        theme.completionSelectedBgColor = makeColor(0xFF3D4759)
        theme.completionLabelColor = makeColor(0xD9FFFFFF)
        theme.completionDetailColor = makeColor(0xFF8A96A3)
        theme.selectionMenuBgColor = theme.completionBgColor
        theme.selectionMenuTextColor = theme.completionLabelColor
        theme.selectionMenuDividerColor = makeColor(0x40515B70)
        theme.diagnosticErrorColor = makeColor(0xFFF74A4A)
        theme.diagnosticWarningColor = makeColor(0xFFEFB759)
        theme.diagnosticInfoColor = makeColor(0xFF675FFF)
        theme.diagnosticHintColor = makeColor(0xFF8A96A3)
        theme.linkedEditingActiveColor = makeColor(0xFF5482FF)
        theme.linkedEditingInactiveColor = makeColor(0x805482FF)
        theme.bracketHighlightBorderColor = makeColor(0xFF67B7A4)
        theme.bracketHighlightBgColor = makeColor(0x3367B7A4)
        theme.searchMatchBgColor = makeColor(0x40D0BF69)
        theme.searchCurrentBgColor = makeColor(0x66D0BF69)
        theme.searchCurrentBorderColor = makeColor(0xFFD0BF69)
        theme.documentHighlightTextBgColor = makeColor(0x265482FF)
        theme.documentHighlightReadBgColor = makeColor(0x335482FF)
        theme.documentHighlightWriteBgColor = makeColor(0x4D5482FF)
        theme.foldPlaceholderBgColor = makeColor(0x66515B70)
        theme.foldPlaceholderTextColor = makeColor(0xD9FFFFFF)
        theme.phantomTextColor = makeColor(0xA66C7986)
        theme.invisibleCharacterColor = makeColor(0xFF424D5B)
        theme.textStyles = [
            styleKeyword: TextStyle(color: uncheckedARGB(0xFF, 0xFC, 0x5F, 0xA3), font_style: 1),
            styleString: TextStyle(color: uncheckedARGB(0xFF, 0xFC, 0x6A, 0x5D)),
            styleComment: TextStyle(color: uncheckedARGB(0xFF, 0x6C, 0x79, 0x86)),
            styleNumber: TextStyle(color: uncheckedARGB(0xFF, 0xD0, 0xBF, 0x69)),
            styleBuiltin: TextStyle(color: uncheckedARGB(0xFF, 0xA1, 0x67, 0xE6)),
            styleType: TextStyle(color: uncheckedARGB(0xFF, 0x5D, 0xD8, 0xFF)),
            styleClass: TextStyle(color: uncheckedARGB(0xFF, 0x9E, 0xF1, 0xDD)),
            styleFunction: TextStyle(color: uncheckedARGB(0xFF, 0x67, 0xB7, 0xA4)),
            styleVariable: TextStyle(color: uncheckedARGB(0xFF, 0x67, 0xB7, 0xA4)),
            stylePunctuation: TextStyle(color: uncheckedARGB(0xD9, 0xFF, 0xFF, 0xFF)),
            styleAnnotation: TextStyle(color: uncheckedARGB(0xFF, 0xBF, 0x85, 0x55)),
            stylePreprocessor: TextStyle(color: uncheckedARGB(0xFF, 0xFD, 0x8F, 0x3F)),
        ]
        return theme
    }

    /// Xcode Default light theme.
    public static func xcodeLight() -> EditorTheme {
        var theme = light()
        theme.backgroundColor = makeColor(0xFFFFFFFF)
        theme.textColor = makeColor(0xD9000000)
        theme.cursorColor = makeColor(0xFF000000)
        theme.selectionColor = makeColor(0xFFA4CDFF)
        theme.selectionTextColor = makeColor(0xD9000000)
        theme.lineNumberColor = makeColor(0xFF5D6C79)
        theme.currentLineNumberColor = makeColor(0xFF0B4F79)
        theme.currentLineColor = makeColor(0xFFE8F2FF)
        theme.guideColor = makeColor(0x80CCCCCC)
        theme.separatorLineColor = makeColor(0xFF8C8C8C)
        theme.splitLineColor = makeColor(0x66CCCCCC)
        theme.scrollbarTrackColor = makeColor(0x14000000)
        theme.scrollbarThumbColor = makeColor(0x668C8C8C)
        theme.scrollbarThumbActiveColor = makeColor(0xB36B6B6B)
        theme.compositionUnderlineColor = makeColor(0xFF0E0EFF)
        theme.codeLensColor = makeColor(0xC05D6C79)
        theme.codeLensActiveColor = makeColor(0xFF0B4F79)
        theme.linkColor = makeColor(0xFF0E0EFF)
        theme.linkActiveColor = makeColor(0xFF0645C0)
        theme.inlayHintBgColor = makeColor(0x2679A7D8)
        theme.inlayHintTextColor = makeColor(0xD95D6C79)
        theme.inlayHintIconColor = makeColor(0xD96B7884)
        theme.completionBgColor = makeColor(0xFAFFFFFF)
        theme.completionBorderColor = makeColor(0x809EA7B3)
        theme.completionSelectedBgColor = makeColor(0xFFA4CDFF)
        theme.completionLabelColor = makeColor(0xD9000000)
        theme.completionDetailColor = makeColor(0xFF687580)
        theme.selectionMenuBgColor = theme.completionBgColor
        theme.selectionMenuTextColor = theme.completionLabelColor
        theme.selectionMenuDividerColor = makeColor(0x409EA7B3)
        theme.diagnosticErrorColor = makeColor(0xFFF74A4A)
        theme.diagnosticWarningColor = makeColor(0xFFEFB759)
        theme.diagnosticInfoColor = makeColor(0xFF675FFF)
        theme.diagnosticHintColor = makeColor(0xFF687580)
        theme.linkedEditingActiveColor = makeColor(0xFF0E0EFF)
        theme.linkedEditingInactiveColor = makeColor(0x660E0EFF)
        theme.bracketHighlightBorderColor = makeColor(0xFF316B74)
        theme.bracketHighlightBgColor = makeColor(0x26316B74)
        theme.searchMatchBgColor = makeColor(0x40D6A300)
        theme.searchCurrentBgColor = makeColor(0x66D6A300)
        theme.searchCurrentBorderColor = makeColor(0xFFA36F00)
        theme.documentHighlightTextBgColor = makeColor(0x260E0EFF)
        theme.documentHighlightReadBgColor = makeColor(0x330E0EFF)
        theme.documentHighlightWriteBgColor = makeColor(0x4D0E0EFF)
        theme.foldPlaceholderBgColor = makeColor(0x4DA4CDFF)
        theme.foldPlaceholderTextColor = makeColor(0xFF0B4F79)
        theme.phantomTextColor = makeColor(0xA65D6C79)
        theme.invisibleCharacterColor = makeColor(0xFFCCCCCC)
        theme.textStyles = [
            styleKeyword: TextStyle(color: uncheckedARGB(0xFF, 0x9B, 0x23, 0x93), font_style: 1),
            styleString: TextStyle(color: uncheckedARGB(0xFF, 0xC4, 0x1A, 0x16)),
            styleComment: TextStyle(color: uncheckedARGB(0xFF, 0x5D, 0x6C, 0x79)),
            styleNumber: TextStyle(color: uncheckedARGB(0xFF, 0x1C, 0x00, 0xCF)),
            styleBuiltin: TextStyle(color: uncheckedARGB(0xFF, 0x6C, 0x36, 0xA9)),
            styleType: TextStyle(color: uncheckedARGB(0xFF, 0x0B, 0x4F, 0x79)),
            styleClass: TextStyle(color: uncheckedARGB(0xFF, 0x1C, 0x46, 0x4A)),
            styleFunction: TextStyle(color: uncheckedARGB(0xFF, 0x32, 0x6D, 0x74)),
            styleVariable: TextStyle(color: uncheckedARGB(0xFF, 0x32, 0x6D, 0x74)),
            stylePunctuation: TextStyle(color: uncheckedARGB(0xD9, 0x00, 0x00, 0x00)),
            styleAnnotation: TextStyle(color: uncheckedARGB(0xFF, 0x81, 0x5F, 0x03)),
            stylePreprocessor: TextStyle(color: uncheckedARGB(0xFF, 0x64, 0x38, 0x20)),
        ]
        return theme
    }
}

private func makeColor(_ argb: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
        green: CGFloat((argb >> 8) & 0xFF) / 255,
        blue: CGFloat(argb & 0xFF) / 255,
        alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
}

func uncheckedARGB(_ a: UInt8, _ r: UInt8, _ g: UInt8, _ b: UInt8) -> Int32 {
    return Int32(bitPattern: (UInt32(a) << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b))
}
