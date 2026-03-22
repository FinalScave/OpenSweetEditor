using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Windows.Forms.Design;
using SweetEditor.Perf;

namespace SweetEditor {
	/// <summary>Loads and manages private font resources for the editor.</summary>
	public class EditorFontLoader : IDisposable {
		[DllImport("gdi32.dll", EntryPoint = "AddFontResourceEx", SetLastError = true)]
		private static extern int AddFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);

		[DllImport("gdi32.dll", EntryPoint = "RemoveFontResourceEx", SetLastError = true)]
		private static extern int RemoveFontResourceEx(string lpszFilename, uint fl, IntPtr pdv);

		private const uint FR_PRIVATE = 0x10;
		private readonly PrivateFontCollection fontCollection = new PrivateFontCollection();
		private string fontFilePath;

		public string LoadFont(string path) {
			fontFilePath = Path.GetFullPath(path);
			if (!File.Exists(fontFilePath)) {
				throw new FileNotFoundException("Font file not found", fontFilePath);
			}
			int added = AddFontResourceEx(fontFilePath, FR_PRIVATE, IntPtr.Zero);
			if (added == 0) {
				Console.WriteLine("Warning: Failed to register font with GDI.");
			}
			fontCollection.AddFontFile(fontFilePath);
			return fontCollection.Families[fontCollection.Families.Length - 1].Name;
		}

		public Font CreateFont(float size, FontStyle style = FontStyle.Regular) {
			if (fontCollection.Families.Length == 0)
				throw new InvalidOperationException("No font loaded.");

			return new Font(fontCollection.Families[0], size, style);
		}

		public void Dispose() {
			fontCollection?.Dispose();
			if (!string.IsNullOrEmpty(fontFilePath)) {
				RemoveFontResourceEx(fontFilePath, FR_PRIVATE, IntPtr.Zero);
			}
		}
	}

	/// <summary>
	/// Editor icon provider interface.
	/// Host code implements this to provide icon images for gutter icons and InlayHint ICON rendering.
	/// </summary>
	public interface EditorIconProvider {
		Image? GetIconImage(int iconId);
	}

	/// <summary>
	/// Immutable text style definition referenced by StyleSpan.styleId.
	/// </summary>
	public readonly struct TextStyle {
		/// <summary>Foreground color (ARGB).</summary>
		public int Color { get; }
		/// <summary>Background color (ARGB), 0 means transparent.</summary>
		public int BackgroundColor { get; }
		/// <summary>Font style bit flags (BOLD | ITALIC | STRIKETHROUGH).</summary>
		public int FontStyle { get; }

		public TextStyle(int color, int fontStyle) : this(color, 0, fontStyle) { }

		public TextStyle(int color, int backgroundColor, int fontStyle) {
			Color = color;
			BackgroundColor = backgroundColor;
			FontStyle = fontStyle;
		}
	}

	/// <summary>
	/// Editor theme configuration containing all configurable color properties.
	/// All colors are in ARGB format.
	/// Apply a theme via <see cref="EditorControl.ApplyTheme(EditorTheme)"/>.
	/// </summary>
	public class EditorTheme {
		public const uint STYLE_KEYWORD = 1;
		public const uint STYLE_STRING = 2;
		public const uint STYLE_COMMENT = 3;
		public const uint STYLE_NUMBER = 4;
		public const uint STYLE_BUILTIN = 5;
		public const uint STYLE_TYPE = 6;
		public const uint STYLE_CLASS = 7;
		public const uint STYLE_FUNCTION = 8;
		public const uint STYLE_VARIABLE = 9;
		public const uint STYLE_PUNCTUATION = 10;
		public const uint STYLE_ANNOTATION = 11;
		public const uint STYLE_PREPROCESSOR = 12;
		/// <summary>
		/// Base style ID reserved for application-defined/custom text styles.
		/// Built-in styles in this library currently use low IDs (1..12); to avoid conflicts
		/// with current/future built-in IDs and keep style IDs consistent across platform bindings,
		/// allocate custom style IDs starting from <see cref="STYLE_USER_BASE"/> and above.
		/// </summary>
		public const uint STYLE_USER_BASE = 100;

		/// <summary>Editor background color (ARGB).</summary>
		public Color BackgroundColor { get; set; }
		/// <summary>Default text color (ARGB), used when not overridden by syntax highlighting.</summary>
		public Color TextColor { get; set; }
		/// <summary>Cursor color (ARGB).</summary>
		public Color CursorColor { get; set; }
		/// <summary>Selection highlight fill color (ARGB, typically semi-transparent).</summary>
		public Color SelectionColor { get; set; }
		/// <summary>Line number text color (ARGB).</summary>
		public Color LineNumberColor { get; set; }
		/// <summary>Current line number text color (ARGB).</summary>
		public Color CurrentLineNumberColor { get; set; }
		/// <summary>Current line highlight background color (ARGB, typically semi-transparent).</summary>
		public Color CurrentLineColor { get; set; }

		/// <summary>Code structure line color (indent/bracket/flow guides, ARGB).</summary>
		public Color GuideColor { get; set; }
		/// <summary>Separator line color (SeparatorGuide, ARGB).</summary>
		public Color SeparatorColor { get; set; }

		/// <summary>Line number area split line color (ARGB).</summary>
		public Color SplitLineColor { get; set; }
		/// <summary>Scrollbar track color (ARGB).</summary>
		public Color ScrollbarTrackColor { get; set; } = Color.FromArgb(unchecked((int)0x48FFFFFF));
		/// <summary>Scrollbar thumb color (ARGB).</summary>
		public Color ScrollbarThumbColor { get; set; } = Color.FromArgb(unchecked((int)0xAA858585));

		/// <summary>IME composition underline color (ARGB).</summary>
		public Color CompositionColor { get; set; }

		/// <summary>InlayHint rounded background color (ARGB).</summary>
		public Color InlayHintBgColor { get; set; }

		/// <summary>InlayHint text color (ARGB, usually semi-transparent).</summary>
		public Color InlayHintTextColor { get; set; }
		/// <summary>InlayHint icon tint color (ARGB, usually semi-transparent).</summary>
		public Color InlayHintIconColor { get; set; }

		/// <summary>Phantom text color (ARGB, usually semi-transparent).</summary>
		public Color PhantomTextColor { get; set; }

		/// <summary>Fold placeholder background color (ARGB, typically semi-transparent).</summary>
		public Color FoldPlaceholderBgColor { get; set; }
		/// <summary>Fold placeholder text color (ARGB, typically semi-transparent).</summary>
		public Color FoldPlaceholderTextColor { get; set; }

		/// <summary>Diagnostic decoration ERROR default color (ARGB).</summary>
		public Color DiagnosticErrorColor { get; set; }
		/// <summary>Diagnostic decoration WARNING default color (ARGB).</summary>
		public Color DiagnosticWarningColor { get; set; }
		/// <summary>Diagnostic decoration INFO default color (ARGB).</summary>
		public Color DiagnosticInfoColor { get; set; }
		/// <summary>Diagnostic decoration HINT default color (ARGB).</summary>
		public Color DiagnosticHintColor { get; set; }

		/// <summary>Linked editing active tab-stop border color (ARGB).</summary>
		public Color LinkedEditingActiveColor { get; set; }
		/// <summary>Linked editing inactive tab-stop border color (ARGB).</summary>
		public Color LinkedEditingInactiveColor { get; set; }

		/// <summary>Bracket match highlight border color (ARGB).</summary>
		public Color BracketHighlightBorderColor { get; set; }
		/// <summary>Bracket match highlight background color (ARGB, typically semi-transparent).</summary>
		public Color BracketHighlightBgColor { get; set; }

		/// <summary>
		/// Theme text style mapping.
		/// Key: style ID. Value: text style definition.
		/// Applied to the C++ core when a theme is applied.
		/// </summary>
		public Dictionary<uint, TextStyle> TextStyles { get; set; } = new();

		/// <summary>
		/// Defines a text style in the theme.
		/// </summary>
		/// <param name="styleId">Style ID.</param>
		/// <param name="style">Text style definition.</param>
		/// <returns>This theme instance (for chaining).</returns>
		public EditorTheme DefineTextStyle(uint styleId, TextStyle style) {
			TextStyles[styleId] = style;
			return this;
		}

		/// <summary>
		/// Creates refined dark theme preset.
		/// </summary>
		public static EditorTheme Dark() => new EditorTheme {
			BackgroundColor = Color.FromArgb(unchecked((int)0xFF1B1E24)),
			TextColor = Color.FromArgb(unchecked((int)0xFFD7DEE9)),
			CursorColor = Color.FromArgb(unchecked((int)0xFF8FB8FF)),
			SelectionColor = Color.FromArgb(unchecked((int)0x553B4F72)),
			LineNumberColor = Color.FromArgb(unchecked((int)0xFF5E6778)),
			CurrentLineNumberColor = Color.FromArgb(unchecked((int)0xFF9CB3D6)),
			CurrentLineColor = Color.FromArgb(unchecked((int)0x163A4A66)),
			GuideColor = Color.FromArgb(unchecked((int)0x2E56617A)),
			SeparatorColor = Color.FromArgb(unchecked((int)0xFF4A8F7A)),
			SplitLineColor = Color.FromArgb(unchecked((int)0x3356617A)),
			ScrollbarTrackColor = Color.FromArgb(unchecked((int)0x2AFFFFFF)),
			ScrollbarThumbColor = Color.FromArgb(unchecked((int)0x9A7282A0)),
			CompositionColor = Color.FromArgb(unchecked((int)0xFF7AA2F7)),
			InlayHintBgColor = Color.FromArgb(unchecked((int)0x223A4A66)),
			InlayHintTextColor = Color.FromArgb(unchecked((int)0xC0AFC2E0)),
			InlayHintIconColor = Color.FromArgb(unchecked((int)0xCC9CB0CD)),
			PhantomTextColor = Color.FromArgb(unchecked((int)0x8AA3B5D1)),
			FoldPlaceholderBgColor = Color.FromArgb(unchecked((int)0x36506C90)),
			FoldPlaceholderTextColor = Color.FromArgb(unchecked((int)0xFFE2ECFF)),
			DiagnosticErrorColor = Color.FromArgb(unchecked((int)0xFFF7768E)),
			DiagnosticWarningColor = Color.FromArgb(unchecked((int)0xFFE0AF68)),
			DiagnosticInfoColor = Color.FromArgb(unchecked((int)0xFF7DCFFF)),
			DiagnosticHintColor = Color.FromArgb(unchecked((int)0xFF8FA3BF)),
			LinkedEditingActiveColor = Color.FromArgb(unchecked((int)0xCC7AA2F7)),
			LinkedEditingInactiveColor = Color.FromArgb(unchecked((int)0x667AA2F7)),
			BracketHighlightBorderColor = Color.FromArgb(unchecked((int)0xCC9ECE6A)),
			BracketHighlightBgColor = Color.FromArgb(unchecked((int)0x2A9ECE6A)),
			TextStyles = new() {
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

		/// <summary>
		/// Creates refined light theme preset.
		/// </summary>
		public static EditorTheme Light() => new EditorTheme {
			BackgroundColor = Color.FromArgb(unchecked((int)0xFFFAFBFD)),
			TextColor = Color.FromArgb(unchecked((int)0xFF1F2937)),
			CursorColor = Color.FromArgb(unchecked((int)0xFF2563EB)),
			SelectionColor = Color.FromArgb(unchecked((int)0x4D60A5FA)),
			LineNumberColor = Color.FromArgb(unchecked((int)0xFF8A94A6)),
			CurrentLineNumberColor = Color.FromArgb(unchecked((int)0xFF3A5FA0)),
			CurrentLineColor = Color.FromArgb(unchecked((int)0x120D3B66)),
			GuideColor = Color.FromArgb(unchecked((int)0x2229426B)),
			SeparatorColor = Color.FromArgb(unchecked((int)0xFF2F855A)),
			SplitLineColor = Color.FromArgb(unchecked((int)0x1F29426B)),
			ScrollbarTrackColor = Color.FromArgb(unchecked((int)0x1F2A3B55)),
			ScrollbarThumbColor = Color.FromArgb(unchecked((int)0x80446C9C)),
			CompositionColor = Color.FromArgb(unchecked((int)0xFF2563EB)),
			InlayHintBgColor = Color.FromArgb(unchecked((int)0x143B82F6)),
			InlayHintTextColor = Color.FromArgb(unchecked((int)0xB0344A73)),
			InlayHintIconColor = Color.FromArgb(unchecked((int)0xB04B607E)),
			PhantomTextColor = Color.FromArgb(unchecked((int)0x8A4B607E)),
			FoldPlaceholderBgColor = Color.FromArgb(unchecked((int)0x2E748DB0)),
			FoldPlaceholderTextColor = Color.FromArgb(unchecked((int)0xFF284A70)),
			DiagnosticErrorColor = Color.FromArgb(unchecked((int)0xFFDC2626)),
			DiagnosticWarningColor = Color.FromArgb(unchecked((int)0xFFD97706)),
			DiagnosticInfoColor = Color.FromArgb(unchecked((int)0xFF0EA5E9)),
			DiagnosticHintColor = Color.FromArgb(unchecked((int)0xFF64748B)),
			LinkedEditingActiveColor = Color.FromArgb(unchecked((int)0xCC2563EB)),
			LinkedEditingInactiveColor = Color.FromArgb(unchecked((int)0x662563EB)),
			BracketHighlightBorderColor = Color.FromArgb(unchecked((int)0xCC0F766E)),
			BracketHighlightBgColor = Color.FromArgb(unchecked((int)0x260F766E)),
			TextStyles = new() {
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

	/// <summary>
	/// SweetEditor WinForms editor control.
	/// Based on <see cref="EditorCore"/> C++ engine for editing, layout and rendering-model generation.
	/// </summary>

	/// <summary>Bracket pair.</summary>
	public sealed class BracketPair {
		public string Open { get; }
		public string Close { get; }
		public BracketPair(string open, string close) { Open = open; Close = close; }
	}

	/// <summary>Block comment.</summary>
	public sealed class BlockComment {
		public string Open { get; }
		public string Close { get; }
		public BlockComment(string open, string close) { Open = open; Close = close; }
	}

	/// <summary>
	/// Language configuration that describes language-specific metadata such as brackets, comments, and indentation.
	/// When assigned to EditorCore, brackets are automatically synchronized to SetBracketPairs in the core layer.
	/// </summary>
	public sealed class LanguageConfiguration {
		/// <summary>Language identifier (for example: "csharp", "java", "cpp").</summary>
		public string LanguageId { get; }
		/// <summary>Bracket pair list (synchronized to SetBracketPairs in the core layer).</summary>
		public IReadOnlyList<BracketPair> Brackets { get; }
		/// <summary>Auto-closing pair list.</summary>
		public IReadOnlyList<BracketPair> AutoClosingPairs { get; }
		/// <summary>Line comment prefix (for example: "//").</summary>
		public string? LineComment { get; }
		/// <summary>Block comment.</summary>
		public BlockComment? BlockCommentValue { get; }
		/// <summary>Tab width (optional).</summary>
		public int? TabSize { get; }
		/// <summary>Whether spaces are used instead of tabs (optional).</summary>
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
			Brackets = brackets ?? new List<BracketPair>();
			AutoClosingPairs = autoClosingPairs ?? new List<BracketPair>();
			LineComment = lineComment;
			BlockCommentValue = blockComment;
			TabSize = tabSize;
			InsertSpaces = insertSpaces;
		}
	}


	/// <summary>
	/// Marker interface for editor metadata.
	/// External code can implement this interface to attach custom metadata to an editor instance.
	/// Cast to the concrete subtype when using it.
	/// </summary>
	/// <example>
	/// <code>
	/// public class FileMetadata : IEditorMetadata {
	///     public string FilePath { get; }
	///     public FileMetadata(string filePath) { FilePath = filePath; }
	/// }
	/// editor.Metadata = new FileMetadata("/a/b.cpp");
	/// var file = editor.Metadata as FileMetadata;
	/// </code>
	/// </example>
	public interface IEditorMetadata { }


	[Designer("System.Windows.Forms.Design.ControlDesigner, System.Design")]
	public class EditorControl : Control {
		#region Events
		/// <summary>Text changed event.</summary>
		public event EventHandler<TextChangedEventArgs> TextChanged;
		/// <summary>Cursor position changed event.</summary>
		public event EventHandler<CursorChangedEventArgs> CursorChanged;
		/// <summary>Selection changed event.</summary>
		public event EventHandler<SelectionChangedEventArgs> SelectionChanged;
		/// <summary>Scroll position changed event.</summary>
		public event EventHandler<ScrollChangedEventArgs> ScrollChanged;
		/// <summary>Scale ratio changed event.</summary>
		public event EventHandler<ScaleChangedEventArgs> ScaleChanged;
		/// <summary>Long press event.</summary>
		public event EventHandler<LongPressEventArgs> LongPress;
		/// <summary>Double-tap selection event.</summary>
		public event EventHandler<DoubleTapEventArgs> DoubleTap;
		/// <summary>Right-click/context menu event.</summary>
		public event EventHandler<ContextMenuEventArgs> ContextMenu;
		/// <summary>InlayHint click event.</summary>
		public event EventHandler<InlayHintClickEventArgs> InlayHintClick;
		/// <summary>Gutter icon click event.</summary>
		public event EventHandler<GutterIconClickEventArgs> GutterIconClick;
		/// <summary>Fold toggle event.</summary>
		public event EventHandler<FoldToggleEventArgs> FoldToggle;
		#endregion

		#region Constants

		// Font style bit flag constants (consistent with C++ FontStyle enum).
		// These are combinable bit flags, not mutually exclusive values.
		/// <summary>Normal style (no flags).</summary>
		public const int FONT_STYLE_NORMAL = 0;
		/// <summary>Bold style flag.</summary>
		public const int FONT_STYLE_BOLD = 1;       // 1 << 0
		/// <summary>Italic style flag.</summary>
		public const int FONT_STYLE_ITALIC = 1 << 1;  // 2
		/// <summary>Strikethrough style flag.</summary>
		public const int FONT_STYLE_STRIKETHROUGH = 1 << 2;  // 4

		#endregion

		private EditorTheme currentTheme = EditorTheme.Dark();
		private EditorRenderer renderer;

		// Win32 IME message constants.
		private const int WM_IME_STARTCOMPOSITION = 0x010D;
		private const int WM_IME_ENDCOMPOSITION = 0x010E;
		private const int WM_IME_COMPOSITION = 0x010F;
		private const int GCS_COMPSTR = 0x0008;
		private const int GCS_RESULTSTR = 0x0800;

		[DllImport("imm32.dll")]
		private static extern IntPtr ImmGetContext(IntPtr hWnd);
		[DllImport("imm32.dll")]
		private static extern bool ImmReleaseContext(IntPtr hWnd, IntPtr hIMC);
		[DllImport("imm32.dll", CharSet = CharSet.Unicode)]
		private static extern int ImmGetCompositionString(IntPtr hIMC, int dwIndex, byte[] lpBuf, int dwBufLen);

		private EditorCore editorCore;
		private EditorRenderModel? renderModel;
		private DecorationProviderManager? decorationProviderManager;
		private CompletionProviderManager? completionProviderManager;
		private CompletionPopupController? completionPopupController;
		private NewLineActionProviderManager? newLineActionProviderManager;
		private int lastMeasureDpi;
		private LanguageConfiguration? languageConfiguration;
		/// <summary>
		/// Custom editor metadata attached by host code.
		/// Cast to the concrete metadata subtype when reading it.
		/// </summary>
		public IEditorMetadata? Metadata { get; set; }

		private EditorSettings? settings;

		// Edge-scroll timer for auto-scrolling during mouse drag selection
		private const int EdgeScrollIntervalMs = 16;
		private System.Windows.Forms.Timer? edgeScrollTimer;
		private bool edgeScrollActive = false;
		private const float DefaultContentStartPaddingDp = 3.0f;

		public EditorControl() {
			InitializeComponent();
		}

		public EditorControl(IContainer container) {
			container.Add(this);
			InitializeComponent();
		}

		#region Public API - Construction/Initialization/Lifecycle

		/// <summary>Loads a document into the editor.</summary>
		/// <param name="document">Document instance to load.</param>
		public void LoadDocument(Document document) {
			editorCore.LoadDocument(document);
			decorationProviderManager?.OnDocumentLoaded();
			Flush();
		}

		/// <summary>Gets the current editor theme.</summary>
		public EditorTheme GetTheme() => currentTheme;

		/// <summary>
		/// Applies an editor theme.
		/// Re-registers theme syntax styles to the C++ core.
		/// </summary>
		public void ApplyTheme(EditorTheme theme) {
			currentTheme = theme;
			renderer.ApplyTheme(theme);
			this.BackColor = currentTheme.BackgroundColor;
			this.ForeColor = currentTheme.TextColor;

			// Re-register text styles to C++ core after theme change.
			if (editorCore != null) {
				foreach (var kvp in theme.TextStyles) {
					editorCore.registerTextStyle(kvp.Key, kvp.Value.Color, kvp.Value.BackgroundColor, kvp.Value.FontStyle);
				}
			}

			Flush();
		}

		/// <summary>Enables or disables the performance overlay.</summary>
		public void SetPerfOverlayEnabled(bool enabled) {
			renderer.SetPerfOverlayEnabled(enabled);
			Invalidate();
		}

		/// <summary>Returns whether the performance overlay is enabled.</summary>
		public bool IsPerfOverlayEnabled() => renderer.IsPerfOverlayEnabled;

		/// <summary>Gets the centralized editor settings.</summary>
		public EditorSettings Settings => settings;

		/// <summary>Internal accessor for EditorCore, used by <see cref="EditorSettings"/>.</summary>
		internal EditorCore EditorCoreInternal => editorCore;

		#endregion

		#region Public API - Viewport/Font/Appearance

		// ==================== LanguageConfiguration API ====================

		/// <summary>Sets language configuration.</summary>
		public void SetLanguageConfiguration(LanguageConfiguration? config) {
			languageConfiguration = config;
			if (config != null && config.Brackets.Count > 0) {
				int[] opens = new int[config.Brackets.Count];
				int[] closes = new int[config.Brackets.Count];
				for (int i = 0; i < config.Brackets.Count; i++) {
					opens[i] = string.IsNullOrEmpty(config.Brackets[i].Open) ? 0 : char.ConvertToUtf32(config.Brackets[i].Open, 0);
					closes[i] = string.IsNullOrEmpty(config.Brackets[i].Close) ? 0 : char.ConvertToUtf32(config.Brackets[i].Close, 0);
				}
				editorCore.SetBracketPairs(opens, closes);
			}
		}

		public LanguageConfiguration? GetLanguageConfiguration() => languageConfiguration;

		// ==================== EditorMetadata API ====================

		/// <summary>Sets metadata.</summary>
		public void SetMetadata<T>(T? metadata) where T : class, IEditorMetadata {
			Metadata = metadata;
		}

		/// <summary>Gets metadata.</summary>
		public T? GetMetadata<T>() where T : class, IEditorMetadata {
			return Metadata as T;
		}

		// ==================== NewLineActionProvider API ====================

		public void AddNewLineActionProvider(INewLineActionProvider provider) {
			newLineActionProviderManager ??= new NewLineActionProviderManager(this);
			newLineActionProviderManager.AddProvider(provider);
		}

		public void RemoveNewLineActionProvider(INewLineActionProvider provider) {
			newLineActionProviderManager?.RemoveProvider(provider);
		}

		/// <summary>Gets position rect.</summary>
		/// <param name="line">Line index (0-based).</param>
		/// <param name="column">Column index (0-based).</param>
		/// <returns>Returns the cursor rectangle in control coordinates.</returns>
		public CursorRect GetPositionRect(int line, int column) {
			return editorCore.GetPositionRect(line, column);
		}

		/// <summary>Gets cursor rect.</summary>
		/// <returns>Returns the cursor rectangle in control coordinates.</returns>
		public CursorRect GetCursorRect() {
			return editorCore.GetCursorRect();
		}

		#endregion

		#region Public API - Text Editing

		/// <summary>Inserts text.</summary>
		/// <param name="text">Text content.</param>
		public void InsertText(string text) {
			var result = editorCore.InsertText(text);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Replaces text.</summary>
		/// <param name="range">Target text range.</param>
		/// <param name="newText">Replacement text.</param>
		public void ReplaceText(TextRange range, string newText) {
			var result = editorCore.ReplaceText(range, newText);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Deletes text.</summary>
		/// <param name="range">Target text range.</param>
		public void DeleteText(TextRange range) {
			var result = editorCore.DeleteText(range);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Gets selected text.</summary>
		/// <returns>Returns the resulting string value.</returns>
		public string GetSelectedText() => editorCore.GetSelectedText();

		/// <summary>Moves line up.</summary>
		public void MoveLineUp() {
			var result = editorCore.MoveLineUp();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Moves line down.</summary>
		public void MoveLineDown() {
			var result = editorCore.MoveLineDown();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Copies line up.</summary>
		public void CopyLineUp() {
			var result = editorCore.CopyLineUp();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Copies line down.</summary>
		public void CopyLineDown() {
			var result = editorCore.CopyLineDown();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Deletes line.</summary>
		public void DeleteLine() {
			var result = editorCore.DeleteLine();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Inserts line above.</summary>
		public void InsertLineAbove() {
			var result = editorCore.InsertLineAbove();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		/// <summary>Inserts line below.</summary>
		public void InsertLineBelow() {
			var result = editorCore.InsertLineBelow();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		#endregion

		#region Public API - Undo/Redo

		/// <summary>Performs an undo operation.</summary>
		/// <returns>Returns <c>true</c> when the operation succeeds.</returns>
		public bool Undo() {
			var result = editorCore.Undo();
			if (result != null) { FireTextChanged(TextChangeAction.Undo, result); Flush(); return true; }
			return false;
		}

		/// <summary>Performs a redo operation.</summary>
		/// <returns>Returns <c>true</c> when the operation succeeds.</returns>
		public bool Redo() {
			var result = editorCore.Redo();
			if (result != null) { FireTextChanged(TextChangeAction.Redo, result); Flush(); return true; }
			return false;
		}

		/// <summary>Returns whether undo.</summary>
		public bool CanUndo() => editorCore.CanUndo();
		/// <summary>Returns whether redo.</summary>
		public bool CanRedo() => editorCore.CanRedo();

		#endregion

		#region Public API - Caret/Selection Management

		/// <summary>Gets cursor position.</summary>
		public TextPosition GetCursorPosition() => editorCore.GetCursorPosition();

		/// <summary>Gets document.</summary>
		public Document? GetDocument() => editorCore.GetDocument();

		/// <summary>Gets word range at cursor.</summary>
		public TextRange? GetWordRangeAtCursor() => editorCore.GetWordRangeAtCursor();

		/// <summary>Gets word at cursor.</summary>
		public string GetWordAtCursor() => editorCore.GetWordAtCursor();

		/// <summary>Sets cursor position.</summary>
		public void SetCursorPosition(TextPosition position) {
			editorCore.SetCursorPosition(position);
			Flush();
		}

		/// <summary>Sets selection.</summary>
		/// <param name="startLine">Start line index (0-based).</param>
		/// <param name="startColumn">Start column index (0-based).</param>
		/// <param name="endLine">End line index (0-based).</param>
		/// <param name="endColumn">End column index (0-based).</param>
		public void SetSelection(int startLine, int startColumn, int endLine, int endColumn) {
			editorCore.SetSelection(startLine, startColumn, endLine, endColumn);
			Flush();
		}

		/// <summary>Sets selection.</summary>
		/// <param name="range">Target text range.</param>
		public void SetSelection(TextRange range) {
			SetSelection(range.Start.Line, range.Start.Column, range.End.Line, range.End.Column);
		}

		/// <summary>Public.</summary>
		public (bool hasSelection, TextRange range) GetSelection() => editorCore.GetSelection();

		/// <summary>Select all.</summary>
		public void SelectAll() {
			editorCore.SelectAll();
			Flush();
		}

		#endregion

		#region Public API - Scrolling/Navigation

		/// <summary>Goto position.</summary>
		/// <param name="line">Line index (0-based).</param>
		/// <param name="column">Column index (0-based).</param>
		public void GotoPosition(int line, int column = 0) {
			editorCore.GotoPosition(line, column);
			Flush();
		}

		/// <summary>Scroll to line.</summary>
		/// <param name="line">Line index (0-based).</param>
		/// <param name="behavior">Scroll behavior.</param>
		public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.CENTER) {
			editorCore.ScrollToLine(line, (int)behavior);
			Flush();
		}

		/// <summary>Sets scroll.</summary>
		public void SetScroll(float scrollX, float scrollY) {
			editorCore.SetScroll(scrollX, scrollY);
			Flush();
		}

		/// <summary>Gets scroll metrics.</summary>
		public ScrollMetrics GetScrollMetrics() => editorCore.GetScrollMetrics();

		#endregion

		#region Public API - Style Registration + Highlight Spans

		/// <summary>Register style.</summary>
		/// <param name="styleId">Style identifier.</param>
		/// <param name="color">Color value (ARGB).</param>
		/// <param name="backgroundColor">Background color value (ARGB).</param>
		/// <param name="fontStyle">Font style flags.</param>
		public void registerTextStyle(uint styleId, int color, int backgroundColor, int fontStyle) =>
			editorCore.registerTextStyle(styleId, color, backgroundColor, fontStyle);

		/// <summary>Register style.</summary>
		/// <param name="styleId">Style identifier.</param>
		/// <param name="color">Color value (ARGB).</param>
		/// <param name="fontStyle">Font style flags.</param>
		public void registerTextStyle(uint styleId, int color, int fontStyle) =>
			editorCore.registerTextStyle(styleId, color, fontStyle);

		/// <summary>Sets line spans.</summary>
		public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans) {
			editorCore.SetLineSpans(line, (int)layer, spans);
		}

		/// <summary>Sets line spans.</summary>
		public void SetLineSpans(int line, IList<StyleSpan> spans) {
			SetLineSpans(line, SpanLayer.SYNTAX, spans);
		}

		/// <summary>Sets batch line spans.</summary>
		public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine) {
			editorCore.SetBatchLineSpans((int)layer, spansByLine);
		}

		#endregion

		#region Public API 閳?InlayHint / PhantomText

		/// <summary>Sets line inlay hints.</summary>
		public void SetLineInlayHints(int line, IList<InlayHint> hints) {
			editorCore.SetLineInlayHints(line, hints);
		}

		/// <summary>Sets batch line inlay hints.</summary>
		public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) {
			editorCore.SetBatchLineInlayHints(hintsByLine);
		}

		/// <summary>Sets line phantom texts.</summary>
		public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms) {
			editorCore.SetLinePhantomTexts(line, phantoms);
		}

		/// <summary>Sets batch line phantom texts.</summary>
		public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) {
			editorCore.SetBatchLinePhantomTexts(phantomsByLine);
		}

		#endregion

		#region Public API - Gutter Icons

		/// <summary>Sets editor icon provider.</summary>
		public void SetEditorIconProvider(EditorIconProvider? provider) {
			renderer.SetEditorIconProvider(provider);
			Flush();
		}

		/// <summary>Sets line gutter icons.</summary>
		public void SetLineGutterIcons(int line, IList<GutterIcon> icons) {
			editorCore.SetLineGutterIcons(line, icons);
		}

		/// <summary>Sets batch line gutter icons.</summary>
		public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) {
			editorCore.SetBatchLineGutterIcons(iconsByLine);
		}

		/// <summary>Clears gutter icons.</summary>
		public void ClearGutterIcons() { editorCore.ClearGutterIcons(); }

		public void AddDecorationProvider(IDecorationProvider provider) => decorationProviderManager?.AddProvider(provider);
		public void RemoveDecorationProvider(IDecorationProvider provider) => decorationProviderManager?.RemoveProvider(provider);
		public void RequestDecorationRefresh() => decorationProviderManager?.RequestRefresh();

		// ==================== CompletionProvider API ====================

		public void AddCompletionProvider(ICompletionProvider provider) => completionProviderManager?.AddProvider(provider);
		public void RemoveCompletionProvider(ICompletionProvider provider) => completionProviderManager?.RemoveProvider(provider);

		/// <summary>Trigger completion.</summary>
		public void TriggerCompletion() => completionProviderManager?.TriggerCompletion(CompletionTriggerKind.Invoked, null);

		/// <summary>Show completion items.</summary>
		public void ShowCompletionItems(List<CompletionItem> items) => completionProviderManager?.ShowItems(items);

		/// <summary>Dismiss completion.</summary>
		public void DismissCompletion() => completionProviderManager?.Dismiss();

		/// <summary>Sets completion item renderer.</summary>
		public void SetCompletionItemRenderer(ICompletionItemRenderer? renderer) => completionPopupController?.SetRenderer(renderer);

		public (int start, int end) GetVisibleLineRange() {
			var model = editorCore.BuildRenderModel();
			if (model.VisualLines == null || model.VisualLines.Count == 0) {
				return (0, -1);
			}
			int start = int.MaxValue;
			int end = -1;
			foreach (var line in model.VisualLines) {
				if (line.LogicalLine < start) start = line.LogicalLine;
				if (line.LogicalLine > end) end = line.LogicalLine;
			}
			if (start == int.MaxValue) start = 0;
			return (start, end);
		}

		public int GetTotalLineCount() => -1;

		#endregion

		#region Public API - Diagnostic Decorations

		/// <summary>Sets line diagnostics.</summary>
		public void SetLineDiagnostics(int line, IList<DiagnosticItem> items) {
			editorCore.SetLineDiagnostics(line, items);
		}

		/// <summary>Sets batch line diagnostics.</summary>
		public void SetBatchLineDiagnostics(Dictionary<int, IList<DiagnosticItem>> diagsByLine) {
			editorCore.SetBatchLineDiagnostics(diagsByLine);
		}

		/// <summary>Clears diagnostics.</summary>
		public void ClearDiagnostics() {
			editorCore.ClearDiagnostics();
		}

		#endregion

		#region Public API - Guide Structure Lines

		/// <summary>Sets indent guides.</summary>
		public void SetIndentGuides(IList<IndentGuide> guides) {
			editorCore.SetIndentGuides(guides);
		}

		/// <summary>Sets bracket guides.</summary>
		public void SetBracketGuides(IList<BracketGuide> guides) {
			editorCore.SetBracketGuides(guides);
		}

		/// <summary>Sets flow guides.</summary>
		public void SetFlowGuides(IList<FlowGuide> guides) {
			editorCore.SetFlowGuides(guides);
		}

		/// <summary>Sets separator guides.</summary>
		public void SetSeparatorGuides(IList<SeparatorGuide> guides) {
			editorCore.SetSeparatorGuides(guides);
		}

		/// <summary>Clears guides.</summary>
		public void ClearGuides() { editorCore.ClearGuides(); }

		#endregion

		#region Public API - Code Folding

		/// <summary>Sets fold regions.</summary>
		public void SetFoldRegions(IList<FoldRegion> regions) {
			editorCore.SetFoldRegions(regions);
		}

		/// <summary>Toggle fold.</summary>
		/// <param name="line">Line index (0-based).</param>
		/// <returns>Returns <c>true</c> when the operation succeeds.</returns>
		public bool ToggleFold(int line) {
			bool result = editorCore.ToggleFold(line);
			if (result) Flush();
			return result;
		}

		/// <summary>Fold at.</summary>
		/// <param name="line">Line index (0-based).</param>
		/// <returns>Returns <c>true</c> when the operation succeeds.</returns>
		public bool FoldAt(int line) {
			bool result = editorCore.FoldAt(line);
			if (result) Flush();
			return result;
		}

		/// <summary>Unfold at.</summary>
		/// <param name="line">Line index (0-based).</param>
		/// <returns>Returns <c>true</c> when the operation succeeds.</returns>
		public bool UnfoldAt(int line) {
			bool result = editorCore.UnfoldAt(line);
			if (result) Flush();
			return result;
		}

		/// <summary>Fold all.</summary>
		public void FoldAll() { editorCore.FoldAll(); Flush(); }
		/// <summary>Unfold all.</summary>
		public void UnfoldAll() { editorCore.UnfoldAll(); Flush(); }
		/// <summary>Returns whether line visible.</summary>
		public bool IsLineVisible(int line) => editorCore.IsLineVisible(line);

		#endregion

		#region Public API - Clear Operations

		/// <summary>Clears highlights.</summary>
		public void ClearHighlights() { editorCore.ClearHighlights(); }
		/// <summary>Clears highlights.</summary>
		public void ClearHighlights(SpanLayer layer) { editorCore.ClearHighlights((int)layer); }
		/// <summary>Clears inlay hints.</summary>
		public void ClearInlayHints() { editorCore.ClearInlayHints(); }
		/// <summary>Clears phantom texts.</summary>
		public void ClearPhantomTexts() { editorCore.ClearPhantomTexts(); }
		/// <summary>Clears all decorations.</summary>
		public void ClearAllDecorations() {
			editorCore.ClearAllDecorations();
			editorCore.ClearDiagnostics();
		}
		/// <summary>Clears matched brackets.</summary>
		public void ClearMatchedBrackets() { editorCore.ClearMatchedBrackets(); Flush(); }

		#endregion

		#region Public API - Linked Editing

		/// <summary>Inserts snippet.</summary>
		public TextEditResult InsertSnippet(string snippetTemplate) {
			var result = editorCore.InsertSnippet(snippetTemplate);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
			return result;
		}

		/// <summary>Starts linked editing.</summary>
		public void StartLinkedEditing(LinkedEditingModel model) {
			editorCore.StartLinkedEditing(model);
			Flush();
		}

		/// <summary>Returns whether in linked editing.</summary>
		public bool IsInLinkedEditing() { return editorCore.IsInLinkedEditing(); }

		/// <summary>Linked editing next.</summary>
		public bool LinkedEditingNext() { bool r = editorCore.LinkedEditingNext(); Flush(); return r; }

		/// <summary>Linked editing prev.</summary>
		public bool LinkedEditingPrev() { bool r = editorCore.LinkedEditingPrev(); Flush(); return r; }

		/// <summary>Cancels linked editing.</summary>
		public void CancelLinkedEditing() { editorCore.CancelLinkedEditing(); Flush(); }

		#endregion

		private void InitializeComponent() {
			SetStyle(ControlStyles.OptimizedDoubleBuffer |
					 ControlStyles.AllPaintingInWmPaint |
					 ControlStyles.UserPaint |
					 ControlStyles.Selectable |
					 ControlStyles.ResizeRedraw, true);
			SetStyle(ControlStyles.StandardDoubleClick, false);
			this.DoubleBuffered = true;
			renderer = new EditorRenderer(currentTheme);
			this.BackColor = currentTheme.BackgroundColor;
			this.ForeColor = currentTheme.TextColor;
			this.Font = renderer.RegularFont;
			this.TabStop = true;
			if (IsDesignMode()) {
				return;
			}
			renderer.RecreateTextGraphics(this);
			var doubleClickSize = SystemInformation.DoubleClickSize;
			float clickSlop = Math.Max(20f, Math.Max(doubleClickSize.Width, doubleClickSize.Height));
			int doubleClickTime = SystemInformation.DoubleClickTime;
			editorCore = new EditorCore(renderer.GetTextMeasurer(), new EditorOptions { TouchSlop = clickSlop, DoubleTapTimeout = doubleClickTime });
			decorationProviderManager = new DecorationProviderManager(this);

			// Completion manager and popup controller.
			completionProviderManager = new CompletionProviderManager(this);
			completionPopupController = new CompletionPopupController(this);
			completionProviderManager.OnItemsUpdated += items => {
				UpdateCompletionPopupCursorAnchor();
				completionPopupController.UpdateItems(items);
			};
			completionProviderManager.OnDismissed += () => completionPopupController.DismissPanel();
			completionPopupController.OnConfirmed += ApplyCompletionItem;

			// Register default theme text styles.
			foreach (var kvp in currentTheme.TextStyles) {
				editorCore.registerTextStyle(kvp.Key, kvp.Value.Color, kvp.Value.BackgroundColor, kvp.Value.FontStyle);
			}

			settings = new EditorSettings(this);
			settings.SetContentStartPadding(DpToPx(DefaultContentStartPaddingDp));
		}

		protected override void OnHandleCreated(EventArgs e) {
			base.OnHandleCreated(e);
			if (IsDesignMode() || editorCore == null) return;
			renderer.RecreateTextGraphics(this);
			editorCore.ResetMeasurer();
			Flush();
		}

		protected override void OnPaint(PaintEventArgs e) {
			base.OnPaint(e);
			renderer.Render(e.Graphics, renderModel, currentTheme, ClientSize);
			UpdateCompletionPopupCursorAnchor();
		}

		protected override void OnResize(EventArgs e) {
			base.OnResize(e);
			if (IsDesignMode()) {
				return;
			}
			editorCore.SetViewport(this.ClientSize.Width, this.ClientSize.Height);
			Flush();
		}

		protected override bool IsInputKey(Keys keyData) {
			if (completionPopupController != null && completionPopupController.IsShowing) {
				Keys keyCode = keyData & Keys.KeyCode;
				if (keyCode == Keys.Up || keyCode == Keys.Down || keyCode == Keys.Enter || keyCode == Keys.Escape) {
					return true;
				}
			}
			return base.IsInputKey(keyData);
		}

		protected override void OnKeyDown(KeyEventArgs e) {
			using var perf = StartInputPerf($"OnKeyDown({e.KeyCode})");
			// Ignore normal key handling while IME composition is active (except Escape).
			// IME (ProcessKey), composing .
			if (editorCore.IsComposing() && e.KeyCode != Keys.Escape) {
				if (e.KeyCode != Keys.ProcessKey && !e.Control && !e.Alt) {
					editorCore.CompositionCancel();
					FireTextChanged(TextChangeAction.Composition);
					Flush();
				} else {
					base.OnKeyDown(e);
					return;
				}
			}

			// completion
			if (completionPopupController != null && completionPopupController.IsShowing) {
				if (completionPopupController.HandleKeyCode(e.KeyCode)) {
					e.Handled = true;
					e.SuppressKeyPress = true;
					return;
				}
			}

			// Manually trigger completion with Ctrl+Space.
			if (e.Control && e.KeyCode == Keys.Space) {
				TriggerCompletion();
				e.Handled = true;
				e.SuppressKeyPress = true;
				return;
			}

			byte modifiers = 0;
			if (e.Shift) modifiers |= 1;
			if (e.Control) modifiers |= 2;
			if (e.Alt) modifiers |= 4;

			ushort keyCode = MapKeysToKeyCode(e.KeyCode);

			// Let NewLineActionProvider handle Enter first.
			// If it returns null, fall back to core default behavior.
			if (keyCode == 13 && newLineActionProviderManager != null) {
				var action = newLineActionProviderManager.ProvideNewLineAction();
				if (action != null) {
					var editResult = editorCore.InsertText(action.Text);
					FireTextChanged(TextChangeAction.Key, editResult);
					e.Handled = true;
					e.SuppressKeyPress = true;
					Flush();
					return;
				}
			}

			if (keyCode != 0 || (e.Control && (e.KeyCode == Keys.A || e.KeyCode == Keys.C || e.KeyCode == Keys.V || e.KeyCode == Keys.X || e.KeyCode == Keys.Z || e.KeyCode == Keys.Y))) {
				// Ctrl shortcuts also need keyCode.
				if (keyCode == 0 && e.Control) {
					keyCode = (ushort)e.KeyValue;
				}
				KeyEventResult result = editorCore.HandleKeyEvent(keyCode, null, modifiers);
				if (result.Handled) {
					e.Handled = true;
					e.SuppressKeyPress = true;
					FireKeyEventChanges(result, TextChangeAction.Key);
					Flush();
				}
			}
			base.OnKeyDown(e);
		}
		// KeyPress is handled by WM_IME_COMPOSITION while composing.
		protected override void OnKeyPress(KeyPressEventArgs e) {
			using var perf = StartInputPerf($"OnKeyPress({(int)e.KeyChar})");
			// Ignore KeyPress while IME composition is active.
			if (editorCore.IsComposing()) {
				base.OnKeyPress(e);
				return;
			}

			if (!char.IsControl(e.KeyChar)) {
				var result = editorCore.InsertText(e.KeyChar.ToString());
				e.Handled = true;
				FireTextChanged(TextChangeAction.Key, result);
				// linked editing completion, completion Enter/Tab
				if (!editorCore.IsInLinkedEditing()) {
					string charStr = e.KeyChar.ToString();
					if (completionProviderManager != null) {
						if (completionProviderManager.IsTriggerCharacter(charStr)) {
							completionProviderManager.TriggerCompletion(CompletionTriggerKind.Character, charStr);
						} else if (completionPopupController != null && completionPopupController.IsShowing) {
							completionProviderManager.TriggerCompletion(CompletionTriggerKind.Retrigger, null);
						} else if (char.IsLetterOrDigit(e.KeyChar) || e.KeyChar == '_') {
							completionProviderManager.TriggerCompletion(CompletionTriggerKind.Invoked, null);
						}
					}
				}
				Flush();
			}
			base.OnKeyPress(e);
		}

		protected override void WndProc(ref Message m) {
			switch (m.Msg) {
				case WM_IME_STARTCOMPOSITION: {
					using var perf = StartInputPerf("WndProc(IME_START)");
					// START composing, START .
					base.WndProc(ref m);
					return;
				}
				case WM_IME_COMPOSITION: {
					using var perf = StartInputPerf("WndProc(IME_COMPOSITION)");
					int imeFlags = (int)m.LParam;
					IntPtr hIMC = ImmGetContext(this.Handle);
					if (hIMC != IntPtr.Zero) {
						// Final committed IME text.
						if ((imeFlags & GCS_RESULTSTR) != 0) {
							string resultStr = GetImmCompositionString(hIMC, GCS_RESULTSTR);
							if (!string.IsNullOrEmpty(resultStr)) {
								var editResult = editorCore.CompositionEnd(resultStr);
								FireTextChanged(TextChangeAction.Composition, editResult);
								Flush();
							} else if (editorCore.IsComposing()) {
								var editResult = editorCore.CompositionEnd("");
								FireTextChanged(TextChangeAction.Composition, editResult);
								Flush();
							}
						}
						// IME composition text update.
						else if ((imeFlags & GCS_COMPSTR) != 0) {
							if (!editorCore.IsComposing()) {
								editorCore.CompositionStart();
							}
							string compStr = GetImmCompositionString(hIMC, GCS_COMPSTR);
							editorCore.CompositionUpdate(compStr ?? "");
							Flush();
						}
						ImmReleaseContext(this.Handle, hIMC);
					}
					// Do not call base.WndProc here to avoid default IME side effects.
					return;
				}
				case WM_IME_ENDCOMPOSITION: {
					using var perf = StartInputPerf("WndProc(IME_END)");
					// In some cases this arrives after GCS_RESULTSTR.
					if (editorCore.IsComposing()) {
						var editResult = editorCore.CompositionEnd("");
						FireTextChanged(TextChangeAction.Composition, editResult);
						Flush();
					}
					base.WndProc(ref m);
					return;
				}
			}
			base.WndProc(ref m);
		}

		private static string GetImmCompositionString(IntPtr hIMC, int dwIndex) {
			int byteLen = ImmGetCompositionString(hIMC, dwIndex, null, 0);
			if (byteLen <= 0) return "";
			byte[] buffer = new byte[byteLen];
			ImmGetCompositionString(hIMC, dwIndex, buffer, byteLen);
			return System.Text.Encoding.Unicode.GetString(buffer, 0, byteLen);
		}

		private static ushort MapKeysToKeyCode(Keys key) {
			switch (key) {
				case Keys.Back: return 8;
				case Keys.Tab: return 9;
				case Keys.Enter: return 13;
				case Keys.Escape: return 27;
				case Keys.Delete: return 46;
				case Keys.Left: return 37;
				case Keys.Up: return 38;
				case Keys.Right: return 39;
				case Keys.Down: return 40;
				case Keys.Home: return 36;
				case Keys.End: return 35;
				case Keys.PageUp: return 33;
				case Keys.PageDown: return 34;
				default: return 0;
			}
		}

		protected override void OnMouseDown(MouseEventArgs e) {
			using var perf = StartInputPerf($"OnMouseDown({e.Button})");
			Focus();
			Modifier mods = GetCurrentModifiers();
			if (e.Button == MouseButtons.Left) {
				GestureResult gestureResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_DOWN,
					Points = [new PointF(e.X, e.Y)],
					Modifiers = mods,
					DirectScale = 1
				});
				FireGestureEvents(gestureResult, new System.Drawing.PointF(e.X, e.Y));
				Flush();
				UpdateEdgeScrollTimer(gestureResult.NeedsEdgeScroll);
			} else if (e.Button == MouseButtons.Right) {
				GestureResult gestureResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_RIGHT_DOWN,
					Points = [new PointF(e.X, e.Y)],
					Modifiers = mods,
					DirectScale = 1
				});
				FireGestureEvents(gestureResult, new System.Drawing.PointF(e.X, e.Y));
				Flush();
			}
			base.OnMouseDown(e);
		}

		protected override void OnMouseMove(MouseEventArgs e) {
			using var perf = StartInputPerf($"OnMouseMove({e.Button})");
			if (e.Button == MouseButtons.Left) {
				Modifier mods = GetCurrentModifiers();
				GestureResult gestureResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_MOVE,
					Points = [new PointF(e.X, e.Y)],
					Modifiers = mods,
					DirectScale = 1
				});
				FireGestureEvents(gestureResult, new System.Drawing.PointF(e.X, e.Y));
				Flush();
				UpdateEdgeScrollTimer(gestureResult.NeedsEdgeScroll);
			}
			base.OnMouseMove(e);
		}

		protected override void OnMouseUp(MouseEventArgs e) {
			using var perf = StartInputPerf($"OnMouseUp({e.Button})");
			if (e.Button == MouseButtons.Left) {
				Modifier mods = GetCurrentModifiers();
				GestureResult gestureResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_UP,
					Points = [new PointF(e.X, e.Y)],
					Modifiers = mods,
					DirectScale = 1
				});
				FireGestureEvents(gestureResult, new System.Drawing.PointF(e.X, e.Y));
				UpdateEdgeScrollTimer(false);
			}
			base.OnMouseUp(e);
		}

		protected override void OnMouseWheel(MouseEventArgs e) {
			using var perf = StartInputPerf($"OnMouseWheel({e.Delta})");
			Modifier mods = GetCurrentModifiers();
			float deltaY = e.Delta;
			GestureResult gestureResult = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.MOUSE_WHEEL,
				Points = [new PointF(e.X, e.Y)],
				Modifiers = mods,
				WheelDeltaY = deltaY,
				DirectScale = 1
			});
			FireGestureEvents(gestureResult, new System.Drawing.PointF(e.X, e.Y));
			Flush();
			base.OnMouseWheel(e);
		}

		private void InitEdgeScrollTimer() {
			edgeScrollTimer = new System.Windows.Forms.Timer();
			edgeScrollTimer.Interval = EdgeScrollIntervalMs;
			edgeScrollTimer.Tick += (_, _) => {
				if (!edgeScrollActive) return;
				GestureResult result = editorCore.TickEdgeScroll();
				FireGestureEvents(result, System.Drawing.PointF.Empty);
				Flush();
				if (!result.NeedsEdgeScroll) {
					edgeScrollActive = false;
					edgeScrollTimer.Stop();
				}
			};
		}

		private void UpdateEdgeScrollTimer(bool needsEdgeScroll) {
			if (edgeScrollTimer == null) InitEdgeScrollTimer();
			if (needsEdgeScroll && !edgeScrollActive) {
				edgeScrollActive = true;
				edgeScrollTimer!.Start();
			} else if (!needsEdgeScroll && edgeScrollActive) {
				edgeScrollActive = false;
				edgeScrollTimer!.Stop();
			}
		}

		private static Modifier GetCurrentModifiers() {
			Modifier mods = Modifier.NONE;
			if ((Control.ModifierKeys & Keys.Shift) != 0) mods |= Modifier.SHIFT;
			if ((Control.ModifierKeys & Keys.Control) != 0) mods |= Modifier.CTRL;
			if ((Control.ModifierKeys & Keys.Alt) != 0) mods |= Modifier.ALT;
			return mods;
		}

		#region Event Dispatching

		/// <summary>Fire gesture events.</summary>
		private void FireGestureEvents(GestureResult result, System.Drawing.PointF screenPoint) {
			var sp = new PointF(screenPoint.X, screenPoint.Y);
			switch (result.Type) {
				case GestureType.LONG_PRESS:
					LongPress?.Invoke(this, new LongPressEventArgs(result.CursorPosition, sp));
					CursorChanged?.Invoke(this, new CursorChangedEventArgs(result.CursorPosition));
					break;
				case GestureType.DOUBLE_TAP:
					DoubleTap?.Invoke(this, new DoubleTapEventArgs(result.CursorPosition, result.HasSelection, result.Selection, sp));
					CursorChanged?.Invoke(this, new CursorChangedEventArgs(result.CursorPosition));
					if (result.HasSelection) {
						SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(true, result.Selection, result.CursorPosition));
					}
					break;
				case GestureType.TAP:
					CursorChanged?.Invoke(this, new CursorChangedEventArgs(result.CursorPosition));
					// Dismiss completion on tap.
					if (completionPopupController != null && completionPopupController.IsShowing) {
						completionProviderManager?.Dismiss();
					}
					// Check whether InlayHint or GutterIcon was hit.
					if (result.HitTarget.Type != HitTargetType.NONE) {
						switch (result.HitTarget.Type) {
							case HitTargetType.INLAY_HINT_TEXT:
							case HitTargetType.INLAY_HINT_ICON:
								InlayHintClick?.Invoke(this, new InlayHintClickEventArgs(
									result.HitTarget.Line,
									result.HitTarget.Column,
									result.HitTarget.IconId,
									0,
									result.HitTarget.Type == HitTargetType.INLAY_HINT_ICON,
									sp));
								break;
							case HitTargetType.INLAY_HINT_COLOR:
								InlayHintClick?.Invoke(this, new InlayHintClickEventArgs(
									result.HitTarget.Line,
									result.HitTarget.Column,
									0,
									result.HitTarget.ColorValue,
									false,
									sp));
								break;
							case HitTargetType.GUTTER_ICON:
								GutterIconClick?.Invoke(this, new GutterIconClickEventArgs(
									result.HitTarget.Line,
									result.HitTarget.IconId,
									sp));
								break;
							case HitTargetType.FOLD_PLACEHOLDER:
							case HitTargetType.FOLD_GUTTER:
								FoldToggle?.Invoke(this, new FoldToggleEventArgs(
									result.HitTarget.Line,
									result.HitTarget.Type == HitTargetType.FOLD_GUTTER,
									sp));
								break;
						}
					}
					break;
				case GestureType.SCROLL:
				case GestureType.FAST_SCROLL:
					ScrollChanged?.Invoke(this, new ScrollChangedEventArgs(result.ViewScrollX, result.ViewScrollY));
					decorationProviderManager?.OnScrollChanged();
					// Dismiss completion while scrolling.
					if (completionPopupController != null && completionPopupController.IsShowing) {
						completionProviderManager?.Dismiss();
					}
					break;
				case GestureType.SCALE:
					// C++ core already applied scale during gesture handling; only sync platform fonts/measurer.
					SyncPlatformScale(result.ViewScale);
					ScaleChanged?.Invoke(this, new ScaleChangedEventArgs(result.ViewScale));
					break;
				case GestureType.DRAG_SELECT:
					SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(result.HasSelection, result.Selection, result.CursorPosition));
					break;
				case GestureType.CONTEXT_MENU:
					ContextMenu?.Invoke(this, new ContextMenuEventArgs(result.CursorPosition, sp));
					break;
			}
		}

		/// <summary>Applies completion item.</summary>
		private void ApplyCompletionItem(CompletionItem item) {
			var textEdit = item.TextEditValue;
			bool isSnippet = item.InsertTextFormat == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
			string text = item.InsertText ?? item.Label;

			// Determine replacement range: textEdit first, fallback to wordRange.
			TextRange replaceRange = default;
			bool hasReplaceRange = false;
			if (textEdit != null) {
				replaceRange = textEdit.Range;
				text = textEdit.NewText;
				hasReplaceRange = true;
			} else {
				var wr = GetWordRangeAtCursor();
				if (wr.HasValue) {
					TextRange wordRange = wr.Value;
					if (wordRange.Start.Line != wordRange.End.Line || wordRange.Start.Column != wordRange.End.Column) {
						replaceRange = wordRange;
						hasReplaceRange = true;
					}
				}
			}

			// Delete the replacement range first, then insert the new text.
			if (hasReplaceRange) {
				DeleteText(replaceRange);
			}
			if (isSnippet) {
				InsertSnippet(text);
			} else {
				InsertText(text);
			}
		}

		/// <summary>Fire key event changes.</summary>
		private void FireKeyEventChanges(KeyEventResult result, TextChangeAction action) {
			if (result.ContentChanged) {
				if (result.EditResult?.Changes != null && result.EditResult.Changes.Count > 0) {
					foreach (var change in result.EditResult.Changes) {
						TextChanged?.Invoke(this, new TextChangedEventArgs(action, change.Range, change.NewText));
					}
					decorationProviderManager?.OnTextChanged(result.EditResult.Changes);
				} else {
					TextChanged?.Invoke(this, new TextChangedEventArgs(action));
					decorationProviderManager?.OnTextChanged(null);
				}
			}
			if (result.CursorChanged) {
				CursorChanged?.Invoke(this, new CursorChangedEventArgs(editorCore.GetCursorPosition()));
			}
			if (result.SelectionChanged) {
				SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(false, default, editorCore.GetCursorPosition()));
			}
		}

		/// <summary>Fire text changed.</summary>
		private void FireTextChanged(TextChangeAction action, TextEditResult? editResult = null) {
			if (editResult?.Changes != null && editResult.Changes.Count > 0) {
				foreach (var change in editResult.Changes) {
					TextChanged?.Invoke(this, new TextChangedEventArgs(action, change.Range, change.NewText));
				}
				decorationProviderManager?.OnTextChanged(editResult.Changes);
			} else {
				TextChanged?.Invoke(this, new TextChangedEventArgs(action));
				decorationProviderManager?.OnTextChanged(null);
			}
		}

		#endregion

		#region Private Helpers/Internal Implementation

		/// <summary>
		/// Flush all pending changes (decoration / layout / scroll / selection) and trigger a redraw.
		/// <para>
		/// Decoration setters (SetLineSpans, ClearHighlights, SetFoldRegions, etc.) no longer
		/// trigger a redraw automatically. Call this method once after a batch of decoration
		/// updates to make them take effect.
		/// </para>
		/// </summary>
		public void Flush() {
			var perf = PerfStepRecorder.Start();

			if (!IsDesignMode() && IsHandleCreated && editorCore != null) {
				int dpi = DeviceDpi;
				if (dpi != lastMeasureDpi) {
					renderer.RecreateTextGraphics(this);
					editorCore.ResetMeasurer();
					lastMeasureDpi = dpi;
				}
				if (renderer.GetTextGraphics() == null) {
					renderer.RecreateTextGraphics(this);
					editorCore.ResetMeasurer();
				}
				perf.Mark(PerfStepRecorder.StepPrep);
			}

			renderer.PerfMeasureStats.Reset();

			renderModel = editorCore.BuildRenderModel();
			perf.Mark(PerfStepRecorder.StepBuild);
			perf.Mark(PerfStepRecorder.StepMetrics);
			UpdateCompletionPopupCursorAnchor();
			perf.Mark(PerfStepRecorder.StepAnchor);
			Invalidate();
			perf.Mark(PerfStepRecorder.StepInvalidate);
			perf.Finish();
			renderer.LogBuildPerfSummary(perf);
			renderer.PerfOverlay.RecordBuild(perf, renderer.PerfMeasureStats.BuildSummary());
		}

		private void UpdateCompletionPopupCursorAnchor() {
			if (completionPopupController == null || renderModel == null) return;
			EditorRenderModel model = (EditorRenderModel)renderModel;
			completionPopupController.UpdateCursorPosition(
				model.Cursor.Position.X,
				model.Cursor.Position.Y,
				model.Cursor.Height);
		}

		/// <summary>Internal accessor for SyncPlatformScale, used by <see cref="EditorSettings"/>.</summary>
		internal void SyncPlatformScaleInternal(float scale) => SyncPlatformScale(scale);

		private void SyncPlatformScale(float scale) {
			renderer.SyncPlatformScale(scale);
			Font = renderer.RegularFont;
			if (editorCore != null) {
				editorCore.ResetMeasurer();
			}
		}

		private float DpToPx(float dp) {
			int dpi = DeviceDpi > 0 ? DeviceDpi : 96;
			return dp * (dpi / 96f);
		}

		private PerfScope StartInputPerf(string tag) {
			return renderer.StartInputPerf(tag);
		}

		private static bool IsDesignMode() {
			if (LicenseManager.UsageMode == LicenseUsageMode.Designtime) {
				return true;
			}
			string processName = System.Diagnostics.Process.GetCurrentProcess().ProcessName.ToLower();
			if (processName.Contains("devenv") ||          // Visual Studio process
				processName.Contains("smsvc") ||           // service process
				processName.Contains("designtoolsserver")) // .NET Core WinForms designer
			{
				return true;
			}
			return false;
		}

		protected override void Dispose(bool disposing) {
			if (disposing) {
				renderer?.Dispose();
			}
			base.Dispose(disposing);
		}

		#endregion
	}
}

