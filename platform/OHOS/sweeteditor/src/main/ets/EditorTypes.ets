import image from '@ohos.multimedia.image';
import { TextStyle } from './core/CoreAdornments';

/**
 * Editor metadata marker interface.
 * External implementations can use this interface to define custom metadata
 * and attach it to the editor instance.
 */
export interface EditorMetadata {}

/**
 * Icon provider interface for gutter icons and InlayHint ICON types.
 * Implementations return a PixelMap for the given icon ID.
 */
export interface EditorIconProvider {
  getIconPixelMap(iconId: number): image.PixelMap | null;
}

/**
 * Language configuration describing metadata such as brackets, comments,
 * and indentation for a specific programming language.
 * When set to SweetEditor, brackets will be automatically synced to Core layer's setBracketPairs.
 */
export class LanguageConfiguration {
  static readonly DEFAULT_TAB_SIZE: number = 4;

  readonly languageId: string;
  readonly brackets: BracketPair[] | null;
  readonly autoClosingPairs: BracketPair[] | null;
  readonly tabSize: number;
  readonly insertSpaces: boolean;

  constructor(
    languageId: string,
    brackets: BracketPair[] | null = null,
    autoClosingPairs: BracketPair[] | null = null,
    tabSize: number = LanguageConfiguration.DEFAULT_TAB_SIZE,
    insertSpaces: boolean = false,
  ) {
    this.languageId = languageId;
    this.brackets = brackets ? [...brackets] : null;
    this.autoClosingPairs = autoClosingPairs ? [...autoClosingPairs] : null;
    this.tabSize = tabSize;
    this.insertSpaces = insertSpaces;
  }
}

export interface BracketPair {
  readonly open: string;
  readonly close: string;
}

export class EditorTheme {
  static readonly STYLE_KEYWORD: number = 1;
  static readonly STYLE_STRING: number = 2;
  static readonly STYLE_COMMENT: number = 3;
  static readonly STYLE_NUMBER: number = 4;
  static readonly STYLE_BUILTIN: number = 5;
  static readonly STYLE_TYPE: number = 6;
  static readonly STYLE_CLASS: number = 7;
  static readonly STYLE_FUNCTION: number = 8;
  static readonly STYLE_VARIABLE: number = 9;
  static readonly STYLE_PUNCTUATION: number = 10;
  static readonly STYLE_ANNOTATION: number = 11;
  static readonly STYLE_PREPROCESSOR: number = 12;
  static readonly STYLE_USER_BASE: number = 100;
  backgroundColor: number = 0xFF1B1E24;
  textColor: number = 0xFFD7DEE9;
  cursorColor: number = 0xFF8FB8FF;
  selectionColor: number = 0x553B4F72;
  lineNumberColor: number = 0xFF5E6778;
  currentLineNumberColor: number = 0xFF9CB3D6;
  currentLineColor: number = 0x163A4A66;
  guideColor: number = 0x2E56617A;
  separatorColor: number = 0xFF4A8F7A;
  splitLineColor: number = 0x3356617A;
  scrollbarTrackColor: number = 0x48FFFFFF;
  scrollbarThumbColor: number = 0xAA858585;
  scrollbarThumbActiveColor: number = 0xFFBBBBBB;
  compositionColor: number = 0xFF7AA2F7;
  inlayHintBgColor: number = 0x223A4A66;
  inlayHintTextColor: number = 0xC0AFC2E0;
  inlayHintIconColor: number = 0xCC9CB0CD;
  phantomTextColor: number = 0x8AA3B5D1;
  foldPlaceholderBgColor: number = 0x36506C90;
  foldPlaceholderTextColor: number = 0xFFE2ECFF;
  diagnosticErrorColor: number = 0xFFF7768E;
  diagnosticWarningColor: number = 0xFFE0AF68;
  diagnosticInfoColor: number = 0xFF7DCFFF;
  diagnosticHintColor: number = 0xFF8FA3BF;
  linkedEditingActiveColor: number = 0xCC7AA2F7;
  linkedEditingInactiveColor: number = 0x667AA2F7;
  bracketHighlightBorderColor: number = 0xCC9ECE6A;
  bracketHighlightBgColor: number = 0x2A9ECE6A;
  inlineSuggestionBarBgColor: number = 0xF2303030;
  inlineSuggestionBarAcceptColor: number = 0xFF4FC1FF;
  inlineSuggestionBarDismissColor: number = 0xFFCCCCCC;
  completionBgColor: number = 0xF0252830;
  completionBorderColor: number = 0x40607090;
  completionSelectedBgColor: number = 0x3D5580BB;
  completionLabelColor: number = 0xFFD8DEE9;
  completionDetailColor: number = 0xFF7A8494;
  selectionMenuBgColor: number = 0xF0252830;
  selectionMenuTextColor: number = 0xFFD7DEE9;
  selectionMenuBorderColor: number = 0x40607090;
  selectionMenuDividerColor: number = 0x1FD8DEE9;
  textStyles: Map<number, TextStyle> = new Map();

  defineTextStyle(styleId: number, style: TextStyle): EditorTheme {
    this.textStyles.set(styleId, style);
    return this;
  }

  static dark(): EditorTheme {
    const theme = new EditorTheme();
    theme.backgroundColor = 0xFF1B1E24;
    theme.textColor = 0xFFD7DEE9;
    theme.cursorColor = 0xFF8FB8FF;
    theme.selectionColor = 0x553B4F72;
    theme.lineNumberColor = 0xFF5E6778;
    theme.currentLineNumberColor = 0xFF9CB3D6;
    theme.currentLineColor = 0x163A4A66;
    theme.guideColor = 0x2E56617A;
    theme.separatorColor = 0xFF4A8F7A;
    theme.splitLineColor = 0x3356617A;
    theme.scrollbarTrackColor = 0x2AFFFFFF;
    theme.scrollbarThumbColor = 0x9A7282A0;
    theme.scrollbarThumbActiveColor = 0xFFAABEDD;
    theme.compositionColor = 0xFF7AA2F7;
    theme.inlayHintBgColor = 0x223A4A66;
    theme.inlayHintTextColor = 0xC0AFC2E0;
    theme.inlayHintIconColor = 0xCC9CB0CD;
    theme.phantomTextColor = 0x8AA3B5D1;
    theme.foldPlaceholderBgColor = 0x36506C90;
    theme.foldPlaceholderTextColor = 0xFFE2ECFF;
    theme.diagnosticErrorColor = 0xFFF7768E;
    theme.diagnosticWarningColor = 0xFFE0AF68;
    theme.diagnosticInfoColor = 0xFF7DCFFF;
    theme.diagnosticHintColor = 0xFF8FA3BF;
    theme.linkedEditingActiveColor = 0xCC7AA2F7;
    theme.linkedEditingInactiveColor = 0x667AA2F7;
    theme.bracketHighlightBorderColor = 0xCC9ECE6A;
    theme.bracketHighlightBgColor = 0x2A9ECE6A;
    theme.inlineSuggestionBarBgColor = 0xF2303030;
    theme.inlineSuggestionBarAcceptColor = 0xFF4FC1FF;
    theme.inlineSuggestionBarDismissColor = 0xFFCCCCCC;
    theme.completionBgColor = 0xF0252830;
    theme.completionBorderColor = 0x40607090;
    theme.completionSelectedBgColor = 0x3D5580BB;
    theme.completionLabelColor = 0xFFD8DEE9;
    theme.completionDetailColor = 0xFF7A8494;
    theme.selectionMenuBgColor = theme.completionBgColor;
    theme.selectionMenuTextColor = 0xFFD7DEE9;
    theme.selectionMenuBorderColor = theme.completionBorderColor;
    theme.selectionMenuDividerColor = 0x1FD8DEE9;
    theme.textStyles = new Map<number, TextStyle>([
      [EditorTheme.STYLE_KEYWORD, { color: 0xFF7AA2F7, backgroundColor: 0, fontStyle: 1 } as TextStyle],
      [EditorTheme.STYLE_STRING, { color: 0xFF9ECE6A, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_COMMENT, { color: 0xFF7A8294, backgroundColor: 0, fontStyle: 2 } as TextStyle],
      [EditorTheme.STYLE_NUMBER, { color: 0xFFFF9E64, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_BUILTIN, { color: 0xFF7DCFFF, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_TYPE, { color: 0xFFBB9AF7, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_CLASS, { color: 0xFFE0AF68, backgroundColor: 0, fontStyle: 1 } as TextStyle],
      [EditorTheme.STYLE_FUNCTION, { color: 0xFF73DACA, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_VARIABLE, { color: 0xFFD7DEE9, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_PUNCTUATION, { color: 0xFFB0BED3, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_ANNOTATION, { color: 0xFF2AC3DE, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_PREPROCESSOR, { color: 0xFFF7768E, backgroundColor: 0, fontStyle: 0 } as TextStyle],
    ]);
    return theme;
  }

  static light(): EditorTheme {
    const theme = new EditorTheme();
    theme.backgroundColor = 0xFFFAFBFD;
    theme.textColor = 0xFF1F2937;
    theme.cursorColor = 0xFF2563EB;
    theme.selectionColor = 0x4D60A5FA;
    theme.lineNumberColor = 0xFF8A94A6;
    theme.currentLineNumberColor = 0xFF3A5FA0;
    theme.currentLineColor = 0x120D3B66;
    theme.guideColor = 0x2229426B;
    theme.separatorColor = 0xFF2F855A;
    theme.splitLineColor = 0x1F29426B;
    theme.scrollbarTrackColor = 0x1F2A3B55;
    theme.scrollbarThumbColor = 0x80446C9C;
    theme.scrollbarThumbActiveColor = 0xEE6A9AD0;
    theme.compositionColor = 0xFF2563EB;
    theme.inlayHintBgColor = 0x143B82F6;
    theme.inlayHintTextColor = 0xB0344A73;
    theme.inlayHintIconColor = 0xB04B607E;
    theme.phantomTextColor = 0x8A4B607E;
    theme.foldPlaceholderBgColor = 0x2E748DB0;
    theme.foldPlaceholderTextColor = 0xFF284A70;
    theme.diagnosticErrorColor = 0xFFDC2626;
    theme.diagnosticWarningColor = 0xFFD97706;
    theme.diagnosticInfoColor = 0xFF0EA5E9;
    theme.diagnosticHintColor = 0xFF64748B;
    theme.linkedEditingActiveColor = 0xCC2563EB;
    theme.linkedEditingInactiveColor = 0x662563EB;
    theme.bracketHighlightBorderColor = 0xCC0F766E;
    theme.bracketHighlightBgColor = 0x260F766E;
    theme.inlineSuggestionBarBgColor = 0xF2F0F0F0;
    theme.inlineSuggestionBarAcceptColor = 0xFF1A73E8;
    theme.inlineSuggestionBarDismissColor = 0xFF555555;
    theme.completionBgColor = 0xF0FAFBFD;
    theme.completionBorderColor = 0x30A0A8B8;
    theme.completionSelectedBgColor = 0x3D3B82F6;
    theme.completionLabelColor = 0xFF1F2937;
    theme.completionDetailColor = 0xFF8A94A6;
    theme.selectionMenuBgColor = theme.completionBgColor;
    theme.selectionMenuTextColor = 0xFF1F2937;
    theme.selectionMenuBorderColor = theme.completionBorderColor;
    theme.selectionMenuDividerColor = 0x1F1F2937;
    theme.textStyles = new Map<number, TextStyle>([
      [EditorTheme.STYLE_KEYWORD, { color: 0xFF3559D6, backgroundColor: 0, fontStyle: 1 } as TextStyle],
      [EditorTheme.STYLE_STRING, { color: 0xFF0F7B6C, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_COMMENT, { color: 0xFF7B8798, backgroundColor: 0, fontStyle: 2 } as TextStyle],
      [EditorTheme.STYLE_NUMBER, { color: 0xFFB45309, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_BUILTIN, { color: 0xFF006E7F, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_TYPE, { color: 0xFF6D28D9, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_CLASS, { color: 0xFFC2410C, backgroundColor: 0, fontStyle: 1 } as TextStyle],
      [EditorTheme.STYLE_FUNCTION, { color: 0xFF0D9488, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_VARIABLE, { color: 0xFF1F2937, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_PUNCTUATION, { color: 0xFF4B5563, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_ANNOTATION, { color: 0xFF0891B2, backgroundColor: 0, fontStyle: 0 } as TextStyle],
      [EditorTheme.STYLE_PREPROCESSOR, { color: 0xFFDC2626, backgroundColor: 0, fontStyle: 0 } as TextStyle],
    ]);
    return theme;
  }
}

