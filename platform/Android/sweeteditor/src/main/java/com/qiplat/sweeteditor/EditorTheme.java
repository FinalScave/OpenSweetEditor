package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.adornment.TextStyle;
import java.util.HashMap;
import java.util.Map;

/**
 * Editor theme configuration containing all configurable color properties.
 * <p>
 * All colors are in ARGB format (e.g., 0xFF1E1E1E).
 * Apply theme via {@link SweetEditor#applyTheme(EditorTheme)}.
 */
public class EditorTheme {
    public static final int STYLE_KEYWORD = 1;
    public static final int STYLE_STRING = 2;
    public static final int STYLE_COMMENT = 3;
    public static final int STYLE_NUMBER = 4;
    public static final int STYLE_BUILTIN = 5;
    public static final int STYLE_TYPE = 6;
    public static final int STYLE_CLASS = 7;
    public static final int STYLE_FUNCTION = 8;
    public static final int STYLE_VARIABLE = 9;
    public static final int STYLE_PUNCTUATION = 10;
    public static final int STYLE_ANNOTATION = 11;
    public static final int STYLE_PREPROCESSOR = 12;
    /**
     * Base style ID reserved for application-defined/custom text styles.
     * <p>
     * Built-in styles in this library currently occupy low IDs (1..12). To avoid collisions with
     * current/future built-in style IDs and keep style IDs portable across all platform bindings,
     * allocate custom style IDs starting from {@code STYLE_USER_BASE} and above.
     */
    public static final int STYLE_USER_BASE = 100;

    /** Editor background color (ARGB). */
    public int backgroundColor;
    /** Default text color (ARGB), used when not overridden by syntax highlighting. */
    public int textColor;
    /** Cursor color (ARGB). */
    public int cursorColor;
    /** Selection highlight fill color (ARGB, recommended to include transparency). */
    public int selectionColor;
    /** Selected text foreground color (ARGB), 0 means keep original text color. */
    public int selectionTextColor;
    /** Line number text color (ARGB). */
    public int lineNumberColor;
    /** Current line number text color (ARGB). */
    public int currentLineNumberColor;
    /** Current line highlight background color (ARGB, recommended to include transparency). */
    public int currentLineColor;

    /** Code structure line color (indent/bracket/flow guide, ARGB). */
    public int guideColor;
    /** Separator line color (SeparatorGuide, ARGB). */
    public int separatorLineColor;

    /** Line number area split line color (ARGB). */
    public int splitLineColor;
    /** Scrollbar track color (ARGB). */
    public int scrollbarTrackColor = 0x48FFFFFF;
    /** Scrollbar thumb color (ARGB). */
    public int scrollbarThumbColor = 0xAA858585;
    /** Scrollbar thumb active (dragging) color (ARGB). */
    public int scrollbarThumbActiveColor = 0xFFBBBBBB;

    /** IME composition underline color (ARGB). */
    public int compositionUnderlineColor;

    /** CodeLens text color (ARGB). */
    public int codeLensColor;
    /** CodeLens active text color (ARGB). */
    public int codeLensActiveColor;
    /** Link text color (ARGB). */
    public int linkColor;
    /** Link active text color (ARGB). */
    public int linkActiveColor;

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

    /** Invisible character marker color (ARGB). */
    public int invisibleCharacterColor;

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

    /** Search match highlight background color (ARGB, recommended to include transparency). */
    public int searchMatchBgColor;
    /** Current search match highlight background color (ARGB, recommended to include transparency). */
    public int searchCurrentBgColor;
    /** Current search match highlight border color (ARGB). */
    public int searchCurrentBorderColor;

    /** Document highlight TEXT background color (ARGB, recommended to include transparency). */
    public int documentHighlightTextBgColor;
    /** Document highlight READ background color (ARGB, recommended to include transparency). */
    public int documentHighlightReadBgColor;
    /** Document highlight WRITE background color (ARGB, recommended to include transparency). */
    public int documentHighlightWriteBgColor;

    /** Inline suggestion action bar background color (ARGB). */
    public int inlineSuggestionBarBgColor;
    /** Inline suggestion action bar accept button text color (ARGB). */
    public int inlineSuggestionBarAcceptColor;
    /** Inline suggestion action bar dismiss button text color (ARGB). */
    public int inlineSuggestionBarDismissColor;

    /** Completion popup background color (ARGB). */
    public int completionBgColor;
    /** Completion popup border color (ARGB). */
    public int completionBorderColor;
    /** Completion popup selected row highlight color (ARGB). */
    public int completionSelectedBgColor;
    /** Completion popup label text color (ARGB). */
    public int completionLabelColor;
    /** Completion popup detail text color (ARGB). */
    public int completionDetailColor;

    /** Selection menu background color (ARGB). */
    public int selectionMenuBgColor;
    /** Selection menu button text color (ARGB). */
    public int selectionMenuTextColor;
    /** Selection menu divider color (ARGB). */
    public int selectionMenuDividerColor;
    /** Context menu background color (ARGB). */
    public int contextMenuBgColor;
    /** Context menu text color (ARGB). */
    public int contextMenuTextColor;
    /** Context menu divider color (ARGB). */
    public int contextMenuDividerColor;

    /**
     * Theme text style mapping (extensible).
     * <p>Key: styleId, Value: {@link TextStyle}.
     */
    public final Map<Integer, TextStyle> textStyles = new HashMap<>();

    /**
     * Define one text style in the theme by style ID.
     *
     * @param styleId Style ID
     * @param style   style definition (foreground/background/font style)
     * @return this (supports method chaining)
     */
    public EditorTheme defineTextStyle(int styleId, TextStyle style) {
        if (style == null) {
            throw new IllegalArgumentException("style == null");
        }
        textStyles.put(styleId, style);
        return this;
    }

    /**
     * Create refined dark theme preset.
     *
     * @return Dark theme instance
     */
    public static EditorTheme dark() {
        EditorTheme t = new EditorTheme();
        t.backgroundColor           = 0xFF1B1E24;
        t.textColor                 = 0xFFD7DEE9;
        t.cursorColor               = 0xFF8FB8FF;
        t.selectionColor            = 0x553B4F72;
        t.selectionTextColor        = 0xFFFFFFFF;
        t.lineNumberColor           = 0xFF5E6778;
        t.currentLineNumberColor    = 0xFF9CB3D6;
        t.currentLineColor          = 0x163A4A66;
        t.guideColor                = 0x2E56617A;
        t.separatorLineColor        = 0xFF4A8F7A;
        t.splitLineColor            = 0x3356617A;
        t.scrollbarTrackColor       = 0x2AFFFFFF;
        t.scrollbarThumbColor       = 0x9A7282A0;
        t.scrollbarThumbActiveColor = 0xFFAABEDD;
        t.compositionUnderlineColor = 0xFF7AA2F7;
        t.codeLensColor             = 0xC0AFC2E0;
        t.codeLensActiveColor       = 0xFF9CB3D6;
        t.linkColor                 = 0xFF4C9DFF;
        t.linkActiveColor           = t.linkColor;
        t.inlayHintBgColor          = 0x223A4A66;
        t.inlayHintTextColor        = 0xC0AFC2E0;
        t.foldPlaceholderBgColor    = 0x36506C90;
        t.foldPlaceholderTextColor  = 0xFFE2ECFF;
        t.phantomTextColor          = 0x8AA3B5D1;
        t.invisibleCharacterColor   = 0x706B7890;
        t.inlayHintIconColor        = 0xCC9CB0CD;
        t.diagnosticErrorColor      = 0xFFF7768E;
        t.diagnosticWarningColor    = 0xFFE0AF68;
        t.diagnosticInfoColor       = 0xFF7DCFFF;
        t.diagnosticHintColor       = 0xFF8FA3BF;
        t.linkedEditingActiveColor   = 0xCC7AA2F7;
        t.linkedEditingInactiveColor = 0x667AA2F7;
        t.bracketHighlightBorderColor = 0xCC9ECE6A;
        t.bracketHighlightBgColor     = 0x2A9ECE6A;
        t.searchMatchBgColor          = 0x33E0AF68;
        t.searchCurrentBgColor        = 0x55E0AF68;
        t.searchCurrentBorderColor    = 0xFFE0AF68;
        t.documentHighlightTextBgColor  = 0x1C7AA2F7;
        t.documentHighlightReadBgColor  = 0x267AA2F7;
        t.documentHighlightWriteBgColor = 0x337AA2F7;
        t.inlineSuggestionBarBgColor     = 0xF2303030;
        t.inlineSuggestionBarAcceptColor = 0xFF4FC1FF;
        t.inlineSuggestionBarDismissColor = 0xFFCCCCCC;
        t.completionBgColor              = 0xF0252830;
        t.completionBorderColor          = 0x40607090;
        t.completionSelectedBgColor      = 0x3D5580BB;
        t.completionLabelColor           = 0xFFD8DEE9;
        t.completionDetailColor          = 0xFF7A8494;
        t.selectionMenuBgColor           = t.completionBgColor;
        t.selectionMenuTextColor         = t.completionLabelColor;
        t.selectionMenuDividerColor      = 0x33D8DEE9;
        t.contextMenuBgColor             = t.selectionMenuBgColor;
        t.contextMenuTextColor           = t.selectionMenuTextColor;
        t.contextMenuDividerColor        = t.selectionMenuDividerColor;

        t.defineTextStyle(STYLE_KEYWORD, new TextStyle(0xFF7AA2F7, TextStyle.BOLD));
        t.defineTextStyle(STYLE_STRING, new TextStyle(0xFF9ECE6A, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_COMMENT, new TextStyle(0xFF7A8294, TextStyle.ITALIC));
        t.defineTextStyle(STYLE_NUMBER, new TextStyle(0xFFFF9E64, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_BUILTIN, new TextStyle(0xFF7DCFFF, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_TYPE, new TextStyle(0xFFBB9AF7, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_CLASS, new TextStyle(0xFFE0AF68, TextStyle.BOLD));
        t.defineTextStyle(STYLE_FUNCTION, new TextStyle(0xFF73DACA, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_VARIABLE, new TextStyle(0xFFD7DEE9, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_PUNCTUATION, new TextStyle(0xFFB0BED3, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_ANNOTATION, new TextStyle(0xFF2AC3DE, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_PREPROCESSOR, new TextStyle(0xFFF7768E, TextStyle.NORMAL));
        return t;
    }

    /**
     * Create refined light theme preset.
     *
     * @return Light theme instance
     */
    public static EditorTheme light() {
        EditorTheme t = new EditorTheme();
        t.backgroundColor           = 0xFFFAFBFD;
        t.textColor                 = 0xFF1F2937;
        t.cursorColor               = 0xFF2563EB;
        t.selectionColor            = 0x4D60A5FA;
        t.selectionTextColor        = 0xFFFFFFFF;
        t.lineNumberColor           = 0xFF8A94A6;
        t.currentLineNumberColor    = 0xFF3A5FA0;
        t.currentLineColor          = 0x120D3B66;
        t.guideColor                = 0x2229426B;
        t.separatorLineColor        = 0xFF2F855A;
        t.splitLineColor            = 0x1F29426B;
        t.scrollbarTrackColor       = 0x1F2A3B55;
        t.scrollbarThumbColor       = 0x80446C9C;
        t.scrollbarThumbActiveColor = 0xEE6A9AD0;
        t.compositionUnderlineColor = 0xFF2563EB;
        t.codeLensColor             = 0xB0344A73;
        t.codeLensActiveColor       = 0xFF3A5FA0;
        t.linkColor                 = 0xFF4C9DFF;
        t.linkActiveColor           = t.linkColor;
        t.inlayHintBgColor          = 0x143B82F6;
        t.inlayHintTextColor        = 0xB0344A73;
        t.foldPlaceholderBgColor    = 0x2E748DB0;
        t.foldPlaceholderTextColor  = 0xFF284A70;
        t.phantomTextColor          = 0x8A4B607E;
        t.invisibleCharacterColor   = 0x705D6B82;
        t.inlayHintIconColor        = 0xB04B607E;
        t.diagnosticErrorColor      = 0xFFDC2626;
        t.diagnosticWarningColor    = 0xFFD97706;
        t.diagnosticInfoColor       = 0xFF0EA5E9;
        t.diagnosticHintColor       = 0xFF64748B;
        t.linkedEditingActiveColor   = 0xCC2563EB;
        t.linkedEditingInactiveColor = 0x662563EB;
        t.bracketHighlightBorderColor = 0xCC0F766E;
        t.bracketHighlightBgColor     = 0x260F766E;
        t.searchMatchBgColor          = 0x33F59E0B;
        t.searchCurrentBgColor        = 0x55F59E0B;
        t.searchCurrentBorderColor    = 0xFFD97706;
        t.documentHighlightTextBgColor  = 0x142563EB;
        t.documentHighlightReadBgColor  = 0x1C2563EB;
        t.documentHighlightWriteBgColor = 0x282563EB;
        t.inlineSuggestionBarBgColor     = 0xF2F0F0F0;
        t.inlineSuggestionBarAcceptColor = 0xFF1A73E8;
        t.inlineSuggestionBarDismissColor = 0xFF555555;
        t.completionBgColor              = 0xF0FAFBFD;
        t.completionBorderColor          = 0x30A0A8B8;
        t.completionSelectedBgColor      = 0x3D3B82F6;
        t.completionLabelColor           = 0xFF1F2937;
        t.completionDetailColor          = 0xFF8A94A6;
        t.selectionMenuBgColor           = t.completionBgColor;
        t.selectionMenuTextColor         = t.completionLabelColor;
        t.selectionMenuDividerColor      = 0x331F2937;
        t.contextMenuBgColor             = t.selectionMenuBgColor;
        t.contextMenuTextColor           = t.selectionMenuTextColor;
        t.contextMenuDividerColor        = t.selectionMenuDividerColor;

        t.defineTextStyle(STYLE_KEYWORD, new TextStyle(0xFF3559D6, TextStyle.BOLD));
        t.defineTextStyle(STYLE_STRING, new TextStyle(0xFF0F7B6C, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_COMMENT, new TextStyle(0xFF7B8798, TextStyle.ITALIC));
        t.defineTextStyle(STYLE_NUMBER, new TextStyle(0xFFB45309, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_BUILTIN, new TextStyle(0xFF006E7F, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_TYPE, new TextStyle(0xFF6D28D9, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_CLASS, new TextStyle(0xFF9A3412, TextStyle.BOLD));
        t.defineTextStyle(STYLE_FUNCTION, new TextStyle(0xFF0E7490, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_VARIABLE, new TextStyle(0xFF1F2937, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_PUNCTUATION, new TextStyle(0xFF6E82A0, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_ANNOTATION, new TextStyle(0xFF0F766E, TextStyle.NORMAL));
        t.defineTextStyle(STYLE_PREPROCESSOR, new TextStyle(0xFFBE123C, TextStyle.NORMAL));
        return t;
    }
}
