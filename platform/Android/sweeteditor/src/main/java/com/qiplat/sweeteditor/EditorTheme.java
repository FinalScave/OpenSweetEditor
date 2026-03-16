package com.qiplat.sweeteditor;

import java.util.HashMap;
import java.util.Map;

/**
 * Editor theme configuration containing all configurable color properties.
 * <p>
 * All colors are in ARGB format (e.g., 0xFF1E1E1E).
 * Apply theme via {@link SweetEditor#applyTheme(EditorTheme)}.
 */
public class EditorTheme {

    /** Editor background color (ARGB). */
    public int backgroundColor;
    /** Default text color (ARGB), used when not overridden by syntax highlighting. */
    public int textColor;
    /** Cursor color (ARGB). */
    public int cursorColor;
    /** Selection highlight fill color (ARGB, recommended to include transparency). */
    public int selectionColor;
    /** Line number text color (ARGB). */
    public int lineNumberColor;
    /** Current line highlight background color (ARGB, recommended to include transparency). */
    public int currentLineColor;

    /** Code structure line color (indent/bracket/flow guide, ARGB). */
    public int guideColor;
    /** Separator line color (SeparatorGuide, ARGB). */
    public int separatorLineColor;

    /** Line number area split line color (ARGB). */
    public int splitLineColor;

    /** IME composition underline color (ARGB). */
    public int compositionUnderlineColor;

    /** InlayHint rounded background color (ARGB). */
    public int inlayHintBgColor;
    /** InlayHint text color (ARGB, typically with transparency to distinguish from main text). */
    public int inlayHintTextColor;

    /** Fold placeholder background color (ARGB, typically with transparency). */
    public int foldPlaceholderBgColor;
    /** Fold placeholder text color (ARGB, typically with transparency to distinguish from main text). */
    public int foldPlaceholderTextColor;

    /** PhantomText color (ARGB, typically with transparency to distinguish from main text). */
    public int phantomTextColor;

    /** InlayHint icon tint color (ARGB, typically with transparency). */
    public int inlayHintIconColor;

    /** Diagnostic decoration ERROR level default color (ARGB). */
    public int diagnosticErrorColor;
    /** Diagnostic decoration WARNING level default color (ARGB). */
    public int diagnosticWarningColor;
    /** Diagnostic decoration INFO level default color (ARGB). */
    public int diagnosticInfoColor;
    /** Diagnostic decoration HINT level default color (ARGB). */
    public int diagnosticHintColor;

    /** Linked editing active tab stop border color (ARGB). */
    public int linkedEditingActiveColor;
    /** Linked editing inactive tab stop border color (ARGB). */
    public int linkedEditingInactiveColor;

    /** Bracket match highlight border color (ARGB, golden tone). */
    public int bracketHighlightBorderColor;
    /** Bracket match highlight background color (ARGB, semi-transparent). */
    public int bracketHighlightBgColor;

    /**
     * Syntax highlighting style mapping (extensible).
     * <p>Key: styleId, Value: {@code int[2] {color(ARGB), fontStyle(bit flags)}}.
     * When switching themes, iterates through this map to re-register all styles to C++ core.
     */
    public final Map<Integer, int[]> syntaxStyles = new HashMap<>();

    /**
     * Register a syntax highlighting style to the theme.
     * @param styleId   Style ID
     * @param color     ARGB foreground color
     * @param fontStyle Font style bit flags (0=normal, 1=bold, 2=italic, 4=strikethrough)
     * @return this (supports method chaining)
     */
    public EditorTheme putSyntaxStyle(int styleId, int color, int fontStyle) {
        syntaxStyles.put(styleId, new int[]{color, fontStyle});
        return this;
    }

    /**
     * Create dark theme (VSCode Dark+ style, consistent with original default values).
     *
     * @return Dark theme instance
     */
    public static EditorTheme dark() {
        EditorTheme t = new EditorTheme();
        t.backgroundColor          = 0xFF1E1E1E;
        t.textColor                = 0xFFD4D4D4;
        t.cursorColor              = 0xFFAEAFAD;
        t.selectionColor           = 0x99264F78;
        t.lineNumberColor          = 0xFF858585;
        t.currentLineColor         = 0x15FFFFFF;
        t.guideColor               = 0x33FFFFFF;
        t.separatorLineColor       = 0xFF6A9955;
        t.splitLineColor           = 0x33FFFFFF;
        t.compositionUnderlineColor = 0xFFFFCC00;
        t.inlayHintBgColor         = 0x20FFFFFF;
        t.inlayHintTextColor       = 0x80D4D4D4;
        t.foldPlaceholderBgColor   = 0x64FFFFFF;
        t.foldPlaceholderTextColor = 0xA0D4D4D4;
        t.phantomTextColor         = 0x80D4D4D4;
        t.inlayHintIconColor       = 0xB2D4D4D4;
        t.diagnosticErrorColor     = 0xFFFF0000;
        t.diagnosticWarningColor   = 0xFFFFCC00;
        t.diagnosticInfoColor      = 0xFF61B5ED;
        t.diagnosticHintColor      = 0xB3999999;
        t.linkedEditingActiveColor  = 0xCC569CD6;  // Blue border
        t.linkedEditingInactiveColor = 0x66569CD6; // Semi-transparent blue border
        t.bracketHighlightBorderColor = 0xCCFFD700; // Golden border
        t.bracketHighlightBgColor     = 0x30FFD700; // Semi-transparent golden background
        // VSCode Dark+ syntax highlighting presets
        t.putSyntaxStyle(1, 0xFFC678DD, 1);  // keyword      — purple, bold
        t.putSyntaxStyle(2, 0xFF56B6C2, 0);  // type         — cyan
        t.putSyntaxStyle(3, 0xFFCE9178, 0);  // string       — orange
        t.putSyntaxStyle(4, 0xFF6A9955, 2);  // comment      — green, italic
        t.putSyntaxStyle(5, 0xFFD19A66, 0);  // preprocessor — orange-yellow
        t.putSyntaxStyle(6, 0xFF61AFEF, 0);  // function     — blue
        t.putSyntaxStyle(7, 0xFFB5CEA8, 0);  // number       — light green
        t.putSyntaxStyle(8, 0xFFE5C07B, 1);  // class        — yellow, bold
        return t;
    }

    /**
     * Create light theme (VSCode Light+ style).
     *
     * @return Light theme instance
     */
    public static EditorTheme light() {
        EditorTheme t = new EditorTheme();
        t.backgroundColor          = 0xFFFFFFFF;
        t.textColor                = 0xFF000000;
        t.cursorColor              = 0xFF000000;
        t.selectionColor           = 0x99ADD6FF;
        t.lineNumberColor          = 0xFF237893;
        t.currentLineColor         = 0x15000000;
        t.guideColor               = 0x33000000;
        t.separatorLineColor       = 0xFF008000;
        t.splitLineColor           = 0x33000000;
        t.compositionUnderlineColor = 0xFF0066FF;
        t.inlayHintBgColor         = 0x20000000;
        t.inlayHintTextColor       = 0x80000000;
        t.foldPlaceholderBgColor   = 0x64000000;
        t.foldPlaceholderTextColor = 0xA0000000;
        t.phantomTextColor         = 0x80000000;
        t.inlayHintIconColor       = 0xB2000000;
        t.diagnosticErrorColor     = 0xFFFF0000;
        t.diagnosticWarningColor   = 0xFFFFCC00;
        t.diagnosticInfoColor      = 0xFF61B5ED;
        t.diagnosticHintColor      = 0xB3999999;
        t.linkedEditingActiveColor  = 0xCC0066FF;  // Blue border
        t.linkedEditingInactiveColor = 0x660066FF; // Semi-transparent blue border
        t.bracketHighlightBorderColor = 0xCCB8860B; // Dark golden border
        t.bracketHighlightBgColor     = 0x30B8860B; // Semi-transparent dark golden background
        // VSCode Light+ syntax highlighting presets
        t.putSyntaxStyle(1, 0xFF0000FF, 0);  // keyword      — blue
        t.putSyntaxStyle(2, 0xFF267F99, 0);  // type         — dark cyan
        t.putSyntaxStyle(3, 0xFFA31515, 0);  // string       — red
        t.putSyntaxStyle(4, 0xFF008000, 2);  // comment      — green, italic
        t.putSyntaxStyle(5, 0xFF795E26, 0);  // preprocessor — brown
        t.putSyntaxStyle(6, 0xFF795E26, 0);  // function     — brown
        t.putSyntaxStyle(7, 0xFF098658, 0);  // number       — dark green
        t.putSyntaxStyle(8, 0xFF267F99, 1);  // class        — dark cyan, bold
        return t;
    }
}
