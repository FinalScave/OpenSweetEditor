import 'editor_core.dart' as core;

/// Editor metadata marker interface.
/// External implementations can use this to define custom metadata
/// and attach it to the editor instance.
abstract class EditorMetadata {}

/// Icon provider interface for gutter icons and InlayHint ICON types.
abstract class EditorIconProvider {
  Object? getIconImage(int iconId);
}

/// Bracket pair definition.
class BracketPair {
  const BracketPair({required this.open, required this.close});

  final String open;
  final String close;
}

/// Language configuration describing brackets, comments,
/// and indentation for a specific programming language.
class LanguageConfiguration {
  static const int defaultTabSize = 4;

  const LanguageConfiguration({
    required this.languageId,
    this.brackets,
    this.autoClosingPairs,
    this.tabSize = defaultTabSize,
    this.insertSpaces = false,
  });

  final String languageId;
  final List<BracketPair>? brackets;
  final List<BracketPair>? autoClosingPairs;
  final int tabSize;
  final bool insertSpaces;
}

/// Editor theme with color definitions and text styles.
class EditorTheme {
  static const int styleKeyword = 1;
  static const int styleString = 2;
  static const int styleComment = 3;
  static const int styleNumber = 4;
  static const int styleBuiltin = 5;
  static const int styleType = 6;
  static const int styleClass = 7;
  static const int styleFunction = 8;
  static const int styleVariable = 9;
  static const int stylePunctuation = 10;
  static const int styleAnnotation = 11;
  static const int stylePreprocessor = 12;
  static const int styleUserBase = 100;

  int backgroundColor = 0xFF1B1E24;
  int textColor = 0xFFD7DEE9;
  int cursorColor = 0xFF8FB8FF;
  int selectionColor = 0x553B4F72;
  int lineNumberColor = 0xFF5E6778;
  int currentLineNumberColor = 0xFF9CB3D6;
  int currentLineColor = 0x163A4A66;
  int guideColor = 0x2E56617A;
  int separatorColor = 0xFF4A8F7A;
  int splitLineColor = 0x3356617A;
  int scrollbarTrackColor = 0x48FFFFFF;
  int scrollbarThumbColor = 0xAA858585;
  int scrollbarThumbActiveColor = 0xFFBBBBBB;
  int compositionColor = 0xFF7AA2F7;
  int inlayHintBgColor = 0x223A4A66;
  int inlayHintTextColor = 0xC0AFC2E0;
  int inlayHintIconColor = 0xCC9CB0CD;
  int phantomTextColor = 0x8AA3B5D1;
  int foldPlaceholderBgColor = 0x36506C90;
  int foldPlaceholderTextColor = 0xFFE2ECFF;
  int diagnosticErrorColor = 0xFFF7768E;
  int diagnosticWarningColor = 0xFFE0AF68;
  int diagnosticInfoColor = 0xFF7DCFFF;
  int diagnosticHintColor = 0xFF8FA3BF;
  int linkedEditingActiveColor = 0xCC7AA2F7;
  int linkedEditingInactiveColor = 0x667AA2F7;
  int bracketHighlightBorderColor = 0xCC9ECE6A;
  int bracketHighlightBgColor = 0x2A9ECE6A;
  int inlineSuggestionBarBgColor = 0xF2303030;
  int inlineSuggestionBarAcceptColor = 0xFF4FC1FF;
  int inlineSuggestionBarDismissColor = 0xFFCCCCCC;
  int completionBgColor = 0xF0252830;
  int completionBorderColor = 0x40607090;
  int completionSelectedBgColor = 0x3D5580BB;
  int completionLabelColor = 0xFFD8DEE9;
  int completionDetailColor = 0xFF7A8494;
  int selectionMenuBgColor = 0xF0252830;
  int selectionMenuTextColor = 0xFFD7DEE9;
  int selectionMenuBorderColor = 0x40607090;
  int selectionMenuDividerColor = 0x1FD8DEE9;
  Map<int, core.TextStyle> textStyles = {};

  EditorTheme defineTextStyle(int styleId, core.TextStyle style) {
    textStyles[styleId] = style;
    return this;
  }

  static EditorTheme dark() {
    final theme = EditorTheme();
    theme.textStyles = {
      styleKeyword: const core.TextStyle(color: 0xFF7AA2F7, fontStyle: 1),
      styleString: const core.TextStyle(color: 0xFF9ECE6A),
      styleComment: const core.TextStyle(color: 0xFF7A8294, fontStyle: 2),
      styleNumber: const core.TextStyle(color: 0xFFFF9E64),
      styleBuiltin: const core.TextStyle(color: 0xFF7DCFFF),
      styleType: const core.TextStyle(color: 0xFFBB9AF7),
      styleClass: const core.TextStyle(color: 0xFFE0AF68, fontStyle: 1),
      styleFunction: const core.TextStyle(color: 0xFF73DACA),
      styleVariable: const core.TextStyle(color: 0xFFD7DEE9),
      stylePunctuation: const core.TextStyle(color: 0xFFB0BED3),
      styleAnnotation: const core.TextStyle(color: 0xFF2AC3DE),
      stylePreprocessor: const core.TextStyle(color: 0xFFF7768E),
    };
    return theme;
  }

  static EditorTheme light() {
    final theme = EditorTheme()
      ..backgroundColor = 0xFFFAFBFD
      ..textColor = 0xFF1F2937
      ..cursorColor = 0xFF2563EB
      ..selectionColor = 0x4D60A5FA
      ..lineNumberColor = 0xFF8A94A6
      ..currentLineNumberColor = 0xFF3A5FA0
      ..currentLineColor = 0x120D3B66
      ..guideColor = 0x2229426B
      ..separatorColor = 0xFF2F855A
      ..splitLineColor = 0x1F29426B
      ..scrollbarTrackColor = 0x1F2A3B55
      ..scrollbarThumbColor = 0x80446C9C
      ..scrollbarThumbActiveColor = 0xEE6A9AD0
      ..compositionColor = 0xFF2563EB
      ..inlayHintBgColor = 0x143B82F6
      ..inlayHintTextColor = 0xB0344A73
      ..inlayHintIconColor = 0xB04B607E
      ..phantomTextColor = 0x8A4B607E
      ..foldPlaceholderBgColor = 0x2E748DB0
      ..foldPlaceholderTextColor = 0xFF284A70
      ..diagnosticErrorColor = 0xFFDC2626
      ..diagnosticWarningColor = 0xFFD97706
      ..diagnosticInfoColor = 0xFF0EA5E9
      ..diagnosticHintColor = 0xFF64748B
      ..linkedEditingActiveColor = 0xCC2563EB
      ..linkedEditingInactiveColor = 0x662563EB
      ..bracketHighlightBorderColor = 0xCC0F766E
      ..bracketHighlightBgColor = 0x260F766E
      ..inlineSuggestionBarBgColor = 0xF2F0F0F0
      ..inlineSuggestionBarAcceptColor = 0xFF1A73E8
      ..inlineSuggestionBarDismissColor = 0xFF555555
      ..completionBgColor = 0xF0FAFBFD
      ..completionBorderColor = 0x30A0A8B8
      ..completionSelectedBgColor = 0x3D3B82F6
      ..completionLabelColor = 0xFF1F2937
      ..completionDetailColor = 0xFF8A94A6
      ..selectionMenuBgColor = 0xF0FAFBFD
      ..selectionMenuTextColor = 0xFF1F2937
      ..selectionMenuBorderColor = 0x30A0A8B8
      ..selectionMenuDividerColor = 0x1F1F2937;
    theme.textStyles = {
      styleKeyword: const core.TextStyle(color: 0xFF3559D6, fontStyle: 1),
      styleString: const core.TextStyle(color: 0xFF0F7B6C),
      styleComment: const core.TextStyle(color: 0xFF7B8798, fontStyle: 2),
      styleNumber: const core.TextStyle(color: 0xFFB45309),
      styleBuiltin: const core.TextStyle(color: 0xFF006E7F),
      styleType: const core.TextStyle(color: 0xFF6D28D9),
      styleClass: const core.TextStyle(color: 0xFFC2410C, fontStyle: 1),
      styleFunction: const core.TextStyle(color: 0xFF0D9488),
      styleVariable: const core.TextStyle(color: 0xFF1F2937),
      stylePunctuation: const core.TextStyle(color: 0xFF4B5563),
      styleAnnotation: const core.TextStyle(color: 0xFF0891B2),
      stylePreprocessor: const core.TextStyle(color: 0xFFDC2626),
    };
    return theme;
  }
}
