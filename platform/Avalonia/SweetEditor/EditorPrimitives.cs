using System.Collections.Generic;

namespace SweetEditor {
	public interface EditorIconProvider {
		object? GetIcon(int iconId);
	}

	public interface IEditorMetadata {
	}

	public sealed class BracketPair {
		public string Open { get; }
		public string Close { get; }

		public BracketPair(string open, string close) {
			Open = open;
			Close = close;
		}
	}

	public sealed class BlockComment {
		public string Open { get; }
		public string Close { get; }

		public BlockComment(string open, string close) {
			Open = open;
			Close = close;
		}
	}

	public sealed class LanguageConfiguration {
		public string LanguageId { get; }
		public IReadOnlyList<BracketPair>? Brackets { get; }
		public IReadOnlyList<BracketPair>? AutoClosingPairs { get; }
		public string? LineComment { get; }
		public BlockComment? BlockCommentValue { get; }
		public int? TabSize { get; }
		public bool? InsertSpaces { get; }

		public LanguageConfiguration(
			string languageId,
			IReadOnlyList<BracketPair>? brackets = null,
			IReadOnlyList<BracketPair>? autoClosingPairs = null,
			string? lineComment = null,
			BlockComment? blockComment = null,
			int? tabSize = null,
			bool? insertSpaces = null) {
			LanguageId = languageId;
			Brackets = brackets;
			AutoClosingPairs = autoClosingPairs;
			LineComment = lineComment;
			BlockCommentValue = blockComment;
			TabSize = tabSize;
			InsertSpaces = insertSpaces;
		}
	}

	public class EditorTheme {
		public const int STYLE_KEYWORD = 1;
		public const int STYLE_STRING = 2;
		public const int STYLE_COMMENT = 3;
		public const int STYLE_NUMBER = 4;
		public const int STYLE_BUILTIN = 5;
		public const int STYLE_TYPE = 6;
		public const int STYLE_CLASS = 7;
		public const int STYLE_FUNCTION = 8;
		public const int STYLE_VARIABLE = 9;
		public const int STYLE_PUNCTUATION = 10;
		public const int STYLE_ANNOTATION = 11;
		public const int STYLE_PREPROCESSOR = 12;
		public const int STYLE_USER_BASE = 100;

		public uint BackgroundColor { get; set; }
		public uint TextColor { get; set; }
		public uint CursorColor { get; set; }
		public uint SelectionColor { get; set; }
		public uint SelectionTextColor { get; set; }
		public uint LineNumberColor { get; set; }
		public uint CurrentLineNumberColor { get; set; }
		public uint CurrentLineColor { get; set; }
		public uint GuideColor { get; set; }
		public uint SeparatorLineColor { get; set; }
		public uint SplitLineColor { get; set; }
		public uint ScrollbarTrackColor { get; set; }
		public uint ScrollbarThumbColor { get; set; }
		public uint ScrollbarThumbActiveColor { get; set; }
		public uint CompositionUnderlineColor { get; set; }
		public uint InlayHintBgColor { get; set; }
		public uint InlayHintTextColor { get; set; }
		public uint InlayHintIconColor { get; set; }
		public uint FoldPlaceholderBgColor { get; set; }
		public uint FoldPlaceholderTextColor { get; set; }
		public uint PhantomTextColor { get; set; }
		public uint DiagnosticErrorColor { get; set; }
		public uint DiagnosticWarningColor { get; set; }
		public uint DiagnosticInfoColor { get; set; }
		public uint DiagnosticHintColor { get; set; }
		public uint LinkedEditingActiveColor { get; set; }
		public uint LinkedEditingInactiveColor { get; set; }
		public uint BracketHighlightBorderColor { get; set; }
		public uint BracketHighlightBgColor { get; set; }
		public uint CompletionBgColor { get; set; }
		public uint CompletionBorderColor { get; set; }
		public uint CompletionSelectedBgColor { get; set; }
		public uint CompletionLabelColor { get; set; }
		public uint CompletionDetailColor { get; set; }

		public Dictionary<int, TextStyle> TextStyles { get; set; } = new();

		// Compatibility aliases for prior bindings.
		public uint ForegroundColor { get => TextColor; set => TextColor = value; }
		public uint SelectionBackgroundColor { get => SelectionColor; set => SelectionColor = value; }
		public uint SeparatorColor { get => SeparatorLineColor; set => SeparatorLineColor = value; }
		public uint CompositionColor { get => CompositionUnderlineColor; set => CompositionUnderlineColor = value; }

		public EditorTheme DefineTextStyle(int styleId, TextStyle style) {
			TextStyles[styleId] = style;
			return this;
		}

		public static EditorTheme Dark() {
			return new EditorTheme {
				BackgroundColor = 0xFF1B1E24,
				TextColor = 0xFFD7DEE9,
				CursorColor = 0xFF8FB8FF,
				SelectionColor = 0x553B4F72,
				SelectionTextColor = 0xFFFFFFFF,
				LineNumberColor = 0xFF5E6778,
				CurrentLineNumberColor = 0xFF9CB3D6,
				CurrentLineColor = 0x163A4A66,
				GuideColor = 0x2E56617A,
				SeparatorLineColor = 0xFF4A8F7A,
				SplitLineColor = 0x3356617A,
				ScrollbarTrackColor = 0x2AFFFFFF,
				ScrollbarThumbColor = 0x9A7282A0,
				ScrollbarThumbActiveColor = 0xFFAABEDD,
				CompositionUnderlineColor = 0xFF7AA2F7,
				InlayHintBgColor = 0x223A4A66,
				InlayHintTextColor = 0xC0AFC2E0,
				InlayHintIconColor = 0xCC9CB0CD,
				FoldPlaceholderBgColor = 0x36506C90,
				FoldPlaceholderTextColor = 0xFFE2ECFF,
				PhantomTextColor = 0x8AA3B5D1,
				DiagnosticErrorColor = 0xFFF7768E,
				DiagnosticWarningColor = 0xFFE0AF68,
				DiagnosticInfoColor = 0xFF7DCFFF,
				DiagnosticHintColor = 0xFF8FA3BF,
				LinkedEditingActiveColor = 0xCC7AA2F7,
				LinkedEditingInactiveColor = 0x667AA2F7,
				BracketHighlightBorderColor = 0xCC9ECE6A,
				BracketHighlightBgColor = 0x2A9ECE6A,
				CompletionBgColor = 0xF0252830,
				CompletionBorderColor = 0x40607090,
				CompletionSelectedBgColor = 0x3D5580BB,
				CompletionLabelColor = 0xFFD8DEE9,
				CompletionDetailColor = 0xFF7A8494,
				TextStyles = new Dictionary<int, TextStyle> {
					[STYLE_KEYWORD] = new TextStyle(unchecked((int)0xFF7AA2F7), 1),
					[STYLE_STRING] = new TextStyle(unchecked((int)0xFF9ECE6A), 0),
					[STYLE_COMMENT] = new TextStyle(unchecked((int)0xFF7A8294), 2),
					[STYLE_NUMBER] = new TextStyle(unchecked((int)0xFFFF9E64), 0),
					[STYLE_BUILTIN] = new TextStyle(unchecked((int)0xFF7DCFFF), 0),
					[STYLE_TYPE] = new TextStyle(unchecked((int)0xFFBB9AF7), 0),
					[STYLE_CLASS] = new TextStyle(unchecked((int)0xFFE0AF68), 1),
					[STYLE_FUNCTION] = new TextStyle(unchecked((int)0xFF73DACA), 0),
					[STYLE_VARIABLE] = new TextStyle(unchecked((int)0xFFD7DEE9), 0),
					[STYLE_PUNCTUATION] = new TextStyle(unchecked((int)0xFFB0BED3), 0),
					[STYLE_ANNOTATION] = new TextStyle(unchecked((int)0xFF2AC3DE), 0),
					[STYLE_PREPROCESSOR] = new TextStyle(unchecked((int)0xFFF7768E), 0),
				},
			};
		}

		public static EditorTheme Light() {
			return new EditorTheme {
				BackgroundColor = 0xFFFAFBFD,
				TextColor = 0xFF1F2937,
				CursorColor = 0xFF2563EB,
				SelectionColor = 0x4D60A5FA,
				SelectionTextColor = 0xFFFFFFFF,
				LineNumberColor = 0xFF8A94A6,
				CurrentLineNumberColor = 0xFF3A5FA0,
				CurrentLineColor = 0x120D3B66,
				GuideColor = 0x2229426B,
				SeparatorLineColor = 0xFF2F855A,
				SplitLineColor = 0x1F29426B,
				ScrollbarTrackColor = 0x1F2A3B55,
				ScrollbarThumbColor = 0x80446C9C,
				ScrollbarThumbActiveColor = 0xEE6A9AD0,
				CompositionUnderlineColor = 0xFF2563EB,
				InlayHintBgColor = 0x143B82F6,
				InlayHintTextColor = 0xB0344A73,
				InlayHintIconColor = 0xB04B607E,
				FoldPlaceholderBgColor = 0x2E748DB0,
				FoldPlaceholderTextColor = 0xFF284A70,
				PhantomTextColor = 0x8A4B607E,
				DiagnosticErrorColor = 0xFFDC2626,
				DiagnosticWarningColor = 0xFFD97706,
				DiagnosticInfoColor = 0xFF0EA5E9,
				DiagnosticHintColor = 0xFF64748B,
				LinkedEditingActiveColor = 0xCC2563EB,
				LinkedEditingInactiveColor = 0x662563EB,
				BracketHighlightBorderColor = 0xCC0F766E,
				BracketHighlightBgColor = 0x260F766E,
				CompletionBgColor = 0xF0FAFBFD,
				CompletionBorderColor = 0x30A0A8B8,
				CompletionSelectedBgColor = 0x3D3B82F6,
				CompletionLabelColor = 0xFF1F2937,
				CompletionDetailColor = 0xFF8A94A6,
				TextStyles = new Dictionary<int, TextStyle> {
					[STYLE_KEYWORD] = new TextStyle(unchecked((int)0xFF3559D6), 1),
					[STYLE_STRING] = new TextStyle(unchecked((int)0xFF0F7B6C), 0),
					[STYLE_COMMENT] = new TextStyle(unchecked((int)0xFF7B8798), 2),
					[STYLE_NUMBER] = new TextStyle(unchecked((int)0xFFB45309), 0),
					[STYLE_BUILTIN] = new TextStyle(unchecked((int)0xFF006E7F), 0),
					[STYLE_TYPE] = new TextStyle(unchecked((int)0xFF6D28D9), 0),
					[STYLE_CLASS] = new TextStyle(unchecked((int)0xFF9A3412), 1),
					[STYLE_FUNCTION] = new TextStyle(unchecked((int)0xFF0E7490), 0),
					[STYLE_VARIABLE] = new TextStyle(unchecked((int)0xFF1F2937), 0),
					[STYLE_PUNCTUATION] = new TextStyle(unchecked((int)0xFF6E82A0), 0),
					[STYLE_ANNOTATION] = new TextStyle(unchecked((int)0xFF0F766E), 0),
					[STYLE_PREPROCESSOR] = new TextStyle(unchecked((int)0xFFBE123C), 0),
				},
			};
		}
	}
}
