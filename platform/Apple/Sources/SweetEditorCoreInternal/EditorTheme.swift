import CoreGraphics

/// Syntax highlight style definition (color + font style).
struct SyntaxStyleDef {
    /// ARGB color value (Int32), aligned with C++ core `registerStyle`.
    let color: Int32
    /// Font-style bit flags (0=normal, 1=bold, 2=italic, 4=strikethrough).
    let fontStyle: Int32
}

/// Editor theme configuration with all configurable color properties.
struct EditorTheme {
    var backgroundColor: CGColor
    var textColor: CGColor
    var cursorColor: CGColor
    var selectionColor: CGColor
    var selectionTextColor: CGColor
    var lineNumberColor: CGColor
    var currentLineNumberColor: CGColor
    var currentLineColor: CGColor
    var guideColor: CGColor
    var separatorLineColor: CGColor
    var splitLineColor: CGColor
    var scrollbarTrackColor: CGColor
    var scrollbarThumbColor: CGColor
    var compositionUnderlineColor: CGColor
    var codeLensColor: CGColor?
    var codeLensActiveColor: CGColor?
    var linkColor: CGColor?
    var linkActiveColor: CGColor?
    var inlayHintBgColor: CGColor
    var inlayHintTextColor: CGColor
    var inlayHintIconColor: CGColor

    // Default diagnostic decoration colors (severity: ERROR/WARNING/INFO/HINT).
    var diagnosticErrorColor: CGColor
    var diagnosticWarningColor: CGColor
    var diagnosticInfoColor: CGColor
    var diagnosticHintColor: CGColor

    // Linked-editing highlight colors.
    var linkedEditingActiveColor: CGColor
    var linkedEditingInactiveColor: CGColor

    // Bracket-pair highlight colors.
    var bracketHighlightBorderColor: CGColor
    var bracketHighlightBgColor: CGColor

    // Search highlight colors.
    var searchMatchBgColor: CGColor
    var searchCurrentBgColor: CGColor
    var searchCurrentBorderColor: CGColor

    // Document highlight colors.
    var documentHighlightTextBgColor: CGColor
    var documentHighlightReadBgColor: CGColor
    var documentHighlightWriteBgColor: CGColor

    var foldPlaceholderBgColor: CGColor
    var foldPlaceholderTextColor: CGColor
    var phantomTextColor: CGColor
    var invisibleCharacterColor: CGColor

    /// Syntax style map (extensible).
    /// Key: styleId (UInt32), Value: SyntaxStyleDef。
    /// Re-registered to the C++ core when switching themes.
    var syntaxStyles: [UInt32: SyntaxStyleDef] = [:]

    /// Registers one syntax style into the theme.
    mutating func putSyntaxStyle(_ styleId: UInt32, color: Int32, fontStyle: Int32) {
        syntaxStyles[styleId] = SyntaxStyleDef(color: color, fontStyle: fontStyle)
    }

    var guideLineColor: CGColor { guideColor }
    var inlayHintTextAlpha: CGFloat { inlayHintTextColor.alpha }
    var foldPlaceholderBgAlpha: CGFloat { foldPlaceholderBgColor.alpha }
    var foldPlaceholderTextAlpha: CGFloat { foldPlaceholderTextColor.alpha }
    var phantomTextAlpha: CGFloat { phantomTextColor.alpha }

    /// Dark theme (VSCode Dark+ style, aligned with Android/WinForms).
    static func dark() -> EditorTheme {
        EditorTheme(
            backgroundColor:          CGColor(srgbRed: 0x1E/255.0, green: 0x1E/255.0, blue: 0x1E/255.0, alpha: 1.0),
            textColor:                CGColor(srgbRed: 0xD4/255.0, green: 0xD4/255.0, blue: 0xD4/255.0, alpha: 1.0),
            cursorColor:              CGColor(srgbRed: 0xAE/255.0, green: 0xAF/255.0, blue: 0xAD/255.0, alpha: 1.0),
            selectionColor:           CGColor(srgbRed: 0x26/255.0, green: 0x4F/255.0, blue: 0x78/255.0, alpha: 0x99/255.0),
            selectionTextColor:       CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            lineNumberColor:          CGColor(srgbRed: 0x85/255.0, green: 0x85/255.0, blue: 0x85/255.0, alpha: 1.0),
            currentLineNumberColor:   CGColor(srgbRed: 0xAE/255.0, green: 0xAF/255.0, blue: 0xAD/255.0, alpha: 1.0),
            currentLineColor:         CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0x15/255.0),
            guideColor:               CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0x33/255.0),
            separatorLineColor:       CGColor(srgbRed: 0x6A/255.0, green: 0x99/255.0, blue: 0x55/255.0, alpha: 1.0),
            splitLineColor:           CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0x33/255.0),
            scrollbarTrackColor:      CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0x18/255.0),
            scrollbarThumbColor:      CGColor(srgbRed: 0xA8/255.0, green: 0xA8/255.0, blue: 0xA8/255.0, alpha: 0xD0/255.0),
            compositionUnderlineColor: CGColor(srgbRed: 1.0, green: 0xCC/255.0, blue: 0.0, alpha: 1.0),
            codeLensColor:            CGColor(srgbRed: 0xD4/255.0, green: 0xD4/255.0, blue: 0xD4/255.0, alpha: 0.55),
            codeLensActiveColor:      CGColor(srgbRed: 0xAE/255.0, green: 0xAF/255.0, blue: 0xAD/255.0, alpha: 1.0),
            linkColor:                CGColor(srgbRed: 0x4C/255.0, green: 0x9D/255.0, blue: 0xFF/255.0, alpha: 1.0),
            linkActiveColor:          CGColor(srgbRed: 0x7D/255.0, green: 0xCF/255.0, blue: 0xFF/255.0, alpha: 1.0),
            inlayHintBgColor:         CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0x20/255.0),
            inlayHintTextColor:       CGColor(srgbRed: 0xD4/255.0, green: 0xD4/255.0, blue: 0xD4/255.0, alpha: 0.55),
            inlayHintIconColor:       CGColor(srgbRed: 0xD4/255.0, green: 0xD4/255.0, blue: 0xD4/255.0, alpha: 0xB2/255.0),
            diagnosticErrorColor:     CGColor(srgbRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0),
            diagnosticWarningColor:   CGColor(srgbRed: 1.0, green: 0.8, blue: 0.0, alpha: 1.0),
            diagnosticInfoColor:      CGColor(srgbRed: 0.38, green: 0.71, blue: 0.93, alpha: 1.0),
            diagnosticHintColor:      CGColor(srgbRed: 0.6, green: 0.6, blue: 0.6, alpha: 0.7),
            linkedEditingActiveColor:  CGColor(srgbRed: 0x56/255.0, green: 0x9C/255.0, blue: 0xD6/255.0, alpha: 0.8),
            linkedEditingInactiveColor: CGColor(srgbRed: 0x56/255.0, green: 0x9C/255.0, blue: 0xD6/255.0, alpha: 0.4),
            bracketHighlightBorderColor: CGColor(srgbRed: 1.0, green: 0xD7/255.0, blue: 0.0, alpha: 0.8),
            bracketHighlightBgColor: CGColor(srgbRed: 1.0, green: 0xD7/255.0, blue: 0.0, alpha: 0.19),
            searchMatchBgColor:      CGColor(srgbRed: 0xE0/255.0, green: 0xAF/255.0, blue: 0x68/255.0, alpha: 0x33/255.0),
            searchCurrentBgColor:    CGColor(srgbRed: 0xE0/255.0, green: 0xAF/255.0, blue: 0x68/255.0, alpha: 0x55/255.0),
            searchCurrentBorderColor: CGColor(srgbRed: 0xE0/255.0, green: 0xAF/255.0, blue: 0x68/255.0, alpha: 1.0),
            documentHighlightTextBgColor: CGColor(srgbRed: 0x7A/255.0, green: 0xA2/255.0, blue: 0xF7/255.0, alpha: 0x1C/255.0),
            documentHighlightReadBgColor: CGColor(srgbRed: 0x7A/255.0, green: 0xA2/255.0, blue: 0xF7/255.0, alpha: 0x26/255.0),
            documentHighlightWriteBgColor: CGColor(srgbRed: 0x7A/255.0, green: 0xA2/255.0, blue: 0xF7/255.0, alpha: 0x33/255.0),
            foldPlaceholderBgColor:   CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 0.4),
            foldPlaceholderTextColor: CGColor(srgbRed: 0xD4/255.0, green: 0xD4/255.0, blue: 0xD4/255.0, alpha: 0.63),
            phantomTextColor:         CGColor(srgbRed: 0xD4/255.0, green: 0xD4/255.0, blue: 0xD4/255.0, alpha: 0.45),
            invisibleCharacterColor:  CGColor(srgbRed: 0x6B/255.0, green: 0x78/255.0, blue: 0x90/255.0, alpha: 0x70/255.0),
            syntaxStyles: [
                1: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0xC6, 0x78, 0xDD), fontStyle: 1),  // keyword      - magenta purple, bold
                2: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x56, 0xB6, 0xC2), fontStyle: 0),  // type         - cyan
                3: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0xCE, 0x91, 0x78), fontStyle: 0),  // string       - orange
                4: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x6A, 0x99, 0x55), fontStyle: 2),  // comment      - green, italic
                5: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0xD1, 0x9A, 0x66), fontStyle: 0),  // preprocessor - amber
                6: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x61, 0xAF, 0xEF), fontStyle: 0),  // function     - blue
                7: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0xB5, 0xCE, 0xA8), fontStyle: 0),  // number       - light green
                8: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0xE5, 0xC0, 0x7B), fontStyle: 1),  // class        - yellow, bold
            ]
        )
    }

    /// Light theme (VSCode Light+ style).
    static func light() -> EditorTheme {
        EditorTheme(
            backgroundColor:          CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            textColor:                CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            cursorColor:              CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 1.0),
            selectionColor:           CGColor(srgbRed: 0xAD/255.0, green: 0xD6/255.0, blue: 1.0, alpha: 0x99/255.0),
            selectionTextColor:       CGColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1.0),
            lineNumberColor:          CGColor(srgbRed: 0x23/255.0, green: 0x78/255.0, blue: 0x93/255.0, alpha: 1.0),
            currentLineNumberColor:   CGColor(srgbRed: 0x23/255.0, green: 0x78/255.0, blue: 0x93/255.0, alpha: 1.0),
            currentLineColor:         CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0x15/255.0),
            guideColor:               CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0x33/255.0),
            separatorLineColor:       CGColor(srgbRed: 0.0, green: 0x80/255.0, blue: 0.0, alpha: 1.0),
            splitLineColor:           CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0x33/255.0),
            scrollbarTrackColor:      CGColor(srgbRed: 0x2A/255.0, green: 0x3B/255.0, blue: 0x55/255.0, alpha: 0x12/255.0),
            scrollbarThumbColor:      CGColor(srgbRed: 0x5C/255.0, green: 0x6A/255.0, blue: 0x7A/255.0, alpha: 0x96/255.0),
            compositionUnderlineColor: CGColor(srgbRed: 0.0, green: 0x66/255.0, blue: 1.0, alpha: 1.0),
            codeLensColor:            CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.55),
            codeLensActiveColor:      CGColor(srgbRed: 0x23/255.0, green: 0x78/255.0, blue: 0x93/255.0, alpha: 1.0),
            linkColor:                CGColor(srgbRed: 0x00/255.0, green: 0x5F/255.0, blue: 0xB8/255.0, alpha: 1.0),
            linkActiveColor:          CGColor(srgbRed: 0x4C/255.0, green: 0x9D/255.0, blue: 0xFF/255.0, alpha: 1.0),
            inlayHintBgColor:         CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0x20/255.0),
            inlayHintTextColor:       CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.55),
            inlayHintIconColor:       CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0xB2/255.0),
            diagnosticErrorColor:     CGColor(srgbRed: 0.85, green: 0.0, blue: 0.0, alpha: 1.0),
            diagnosticWarningColor:   CGColor(srgbRed: 0.75, green: 0.6, blue: 0.0, alpha: 1.0),
            diagnosticInfoColor:      CGColor(srgbRed: 0.15, green: 0.47, blue: 0.73, alpha: 1.0),
            diagnosticHintColor:      CGColor(srgbRed: 0.4, green: 0.4, blue: 0.4, alpha: 0.7),
            linkedEditingActiveColor:  CGColor(srgbRed: 0.0, green: 0x66/255.0, blue: 1.0, alpha: 0.8),
            linkedEditingInactiveColor: CGColor(srgbRed: 0.0, green: 0x66/255.0, blue: 1.0, alpha: 0.4),
            bracketHighlightBorderColor: CGColor(srgbRed: 0xB8/255.0, green: 0x86/255.0, blue: 0x0B/255.0, alpha: 0.8),
            bracketHighlightBgColor: CGColor(srgbRed: 0xB8/255.0, green: 0x86/255.0, blue: 0x0B/255.0, alpha: 0.19),
            searchMatchBgColor:      CGColor(srgbRed: 0xF5/255.0, green: 0x9E/255.0, blue: 0x0B/255.0, alpha: 0x33/255.0),
            searchCurrentBgColor:    CGColor(srgbRed: 0xF5/255.0, green: 0x9E/255.0, blue: 0x0B/255.0, alpha: 0x55/255.0),
            searchCurrentBorderColor: CGColor(srgbRed: 0xD9/255.0, green: 0x77/255.0, blue: 0x06/255.0, alpha: 1.0),
            documentHighlightTextBgColor: CGColor(srgbRed: 0x25/255.0, green: 0x63/255.0, blue: 0xEB/255.0, alpha: 0x14/255.0),
            documentHighlightReadBgColor: CGColor(srgbRed: 0x25/255.0, green: 0x63/255.0, blue: 0xEB/255.0, alpha: 0x1C/255.0),
            documentHighlightWriteBgColor: CGColor(srgbRed: 0x25/255.0, green: 0x63/255.0, blue: 0xEB/255.0, alpha: 0x28/255.0),
            foldPlaceholderBgColor:   CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.4),
            foldPlaceholderTextColor: CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.63),
            phantomTextColor:         CGColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.45),
            invisibleCharacterColor:  CGColor(srgbRed: 0x5D/255.0, green: 0x6B/255.0, blue: 0x82/255.0, alpha: 0x70/255.0),
            syntaxStyles: [
                1: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x00, 0x00, 0xFF), fontStyle: 0),  // keyword      - blue
                2: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x26, 0x7F, 0x99), fontStyle: 0),  // type         - deep teal
                3: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0xA3, 0x15, 0x15), fontStyle: 0),  // string       - red
                4: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x00, 0x80, 0x00), fontStyle: 2),  // comment      - green, italic
                5: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x79, 0x5E, 0x26), fontStyle: 0),  // preprocessor - brown
                6: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x79, 0x5E, 0x26), fontStyle: 0),  // function     - brown
                7: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x09, 0x86, 0x58), fontStyle: 0),  // number       - dark green
                8: SyntaxStyleDef(color: uncheckedARGB(0xFF, 0x26, 0x7F, 0x99), fontStyle: 1),  // class        - deep teal, bold
            ]
        )
    }
}

func uncheckedARGB(_ a: UInt8, _ r: UInt8, _ g: UInt8, _ b: UInt8) -> Int32 {
    return Int32(bitPattern: (UInt32(a) << 24) | (UInt32(r) << 16) | (UInt32(g) << 8) | UInt32(b))
}
