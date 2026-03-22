package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.adornment.TextStyle;
import java.awt.Color;
import java.util.HashMap;
import java.util.Map;

/**
 * Editor theme configuration containing all configurable color properties.
 * <p>
 * All color fields use {@link Color}. Built-in presets are initialized from ARGB constants
 * (e.g., {@code 0xFF1E1E1E}).
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

    /** Editor background color. */
    public Color backgroundColor;
    /** Default text color, used when not overridden by syntax highlighting. */
    public Color textColor;
    /** Cursor color. */
    public Color cursorColor;
    /** Selection highlight fill color, recommended to include alpha. */
    public Color selectionColor;
    /** Line number text color. */
    public Color lineNumberColor;
    /** Current line number text color. */
    public Color currentLineNumberColor;
    /** Current line highlight background color, recommended to include alpha. */
    public Color currentLineColor;

    /** Code structure line color (indent/bracket/flow guide). */
    public Color guideColor;
    /** Separator line color (SeparatorGuide). */
    public Color separatorLineColor;

    /** Line number area split line color. */
    public Color splitLineColor;
    /** Scrollbar track color. */
    public Color scrollbarTrackColor = argb(0x48FFFFFF);
    /** Scrollbar thumb color. */
    public Color scrollbarThumbColor = argb(0xAA858585);

    /** IME composition underline color. */
    public Color compositionUnderlineColor;

    /** InlayHint rounded background color. */
    public Color inlayHintBgColor;
    /** InlayHint text color, typically with alpha to distinguish from main text. */
    public Color inlayHintTextColor;

    /** Fold placeholder background color, typically with alpha. */
    public Color foldPlaceholderBgColor;
    /** Fold placeholder text color, typically with alpha to distinguish from main text. */
    public Color foldPlaceholderTextColor;

    /** PhantomText color, typically with alpha to distinguish from main text. */
    public Color phantomTextColor;

    /** InlayHint icon tint color, typically with alpha. */
    public Color inlayHintIconColor;

    /** Diagnostic decoration ERROR level default color. */
    public Color diagnosticErrorColor;
    /** Diagnostic decoration WARNING level default color. */
    public Color diagnosticWarningColor;
    /** Diagnostic decoration INFO level default color. */
    public Color diagnosticInfoColor;
    /** Diagnostic decoration HINT level default color. */
    public Color diagnosticHintColor;

    /** Linked editing active tab stop border color. */
    public Color linkedEditingActiveColor;
    /** Linked editing inactive tab stop border color. */
    public Color linkedEditingInactiveColor;

    /** Bracket match highlight border color (golden tone). */
    public Color bracketHighlightBorderColor;
    /** Bracket match highlight background color, typically with alpha. */
    public Color bracketHighlightBgColor;

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
     */
    public static EditorTheme dark() {
        EditorTheme t = new EditorTheme();
        t.backgroundColor           = argb(0xFF1B1E24);
        t.textColor                 = argb(0xFFD7DEE9);
        t.cursorColor               = argb(0xFF8FB8FF);
        t.selectionColor            = argb(0x553B4F72);
        t.lineNumberColor           = argb(0xFF5E6778);
        t.currentLineNumberColor    = argb(0xFF9CB3D6);
        t.currentLineColor          = argb(0x163A4A66);
        t.guideColor                = argb(0x2E56617A);
        t.separatorLineColor        = argb(0xFF4A8F7A);
        t.splitLineColor            = argb(0x3356617A);
        t.scrollbarTrackColor       = argb(0x2AFFFFFF);
        t.scrollbarThumbColor       = argb(0x9A7282A0);
        t.compositionUnderlineColor = argb(0xFF7AA2F7);
        t.inlayHintBgColor          = argb(0x223A4A66);
        t.inlayHintTextColor        = argb(0xC0AFC2E0);
        t.foldPlaceholderBgColor    = argb(0x36506C90);
        t.foldPlaceholderTextColor  = argb(0xFFE2ECFF);
        t.phantomTextColor          = argb(0x8AA3B5D1);
        t.inlayHintIconColor        = argb(0xCC9CB0CD);
        t.diagnosticErrorColor      = argb(0xFFF7768E);
        t.diagnosticWarningColor    = argb(0xFFE0AF68);
        t.diagnosticInfoColor       = argb(0xFF7DCFFF);
        t.diagnosticHintColor       = argb(0xFF8FA3BF);
        t.linkedEditingActiveColor   = argb(0xCC7AA2F7);
        t.linkedEditingInactiveColor = argb(0x667AA2F7);
        t.bracketHighlightBorderColor = argb(0xCC9ECE6A);
        t.bracketHighlightBgColor     = argb(0x2A9ECE6A);

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
     */
    public static EditorTheme light() {
        EditorTheme t = new EditorTheme();
        t.backgroundColor           = argb(0xFFFAFBFD);
        t.textColor                 = argb(0xFF1F2937);
        t.cursorColor               = argb(0xFF2563EB);
        t.selectionColor            = argb(0x4D60A5FA);
        t.lineNumberColor           = argb(0xFF8A94A6);
        t.currentLineNumberColor    = argb(0xFF3A5FA0);
        t.currentLineColor          = argb(0x120D3B66);
        t.guideColor                = argb(0x2229426B);
        t.separatorLineColor        = argb(0xFF2F855A);
        t.splitLineColor            = argb(0x1F29426B);
        t.scrollbarTrackColor       = argb(0x1F2A3B55);
        t.scrollbarThumbColor       = argb(0x80446C9C);
        t.compositionUnderlineColor = argb(0xFF2563EB);
        t.inlayHintBgColor          = argb(0x143B82F6);
        t.inlayHintTextColor        = argb(0xB0344A73);
        t.foldPlaceholderBgColor    = argb(0x2E748DB0);
        t.foldPlaceholderTextColor  = argb(0xFF284A70);
        t.phantomTextColor          = argb(0x8A4B607E);
        t.inlayHintIconColor        = argb(0xB04B607E);
        t.diagnosticErrorColor      = argb(0xFFDC2626);
        t.diagnosticWarningColor    = argb(0xFFD97706);
        t.diagnosticInfoColor       = argb(0xFF0EA5E9);
        t.diagnosticHintColor       = argb(0xFF64748B);
        t.linkedEditingActiveColor   = argb(0xCC2563EB);
        t.linkedEditingInactiveColor = argb(0x662563EB);
        t.bracketHighlightBorderColor = argb(0xCC0F766E);
        t.bracketHighlightBgColor     = argb(0x260F766E);

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

    private static Color argb(int argb) {
        return new Color(argb, true);
    }
}

