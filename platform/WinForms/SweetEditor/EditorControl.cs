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
	/// Editor theme configuration containing all configurable color properties.
	/// All colors are in ARGB format.
	/// Apply a theme via <see cref="EditorControl.ApplyTheme(EditorTheme)"/>.
	/// </summary>
	public class EditorTheme {
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
		/// <summary>Current line highlight background color (ARGB, typically semi-transparent).</summary>
		public Color CurrentLineColor { get; set; }

		/// <summary>Code structure line color (indent/bracket/flow guides, ARGB).</summary>
		public Color GuideColor { get; set; }
		/// <summary>Separator line color (SeparatorGuide, ARGB).</summary>
		public Color SeparatorColor { get; set; }

		/// <summary>Line number area split line color (ARGB).</summary>
		public Color SplitLineColor { get; set; }

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
		/// Syntax highlighting style mapping.
		/// Key: style ID. Value: tuple (color ARGB, fontStyle bit flags).
		/// Applied to the C++ core when a theme is applied.
		/// </summary>
		public Dictionary<uint, (int color, int fontStyle)> SyntaxStyles { get; set; } = new();

		/// <summary>
		/// Registers a syntax highlighting style in the theme.
		/// </summary>
		/// <param name="styleId">Style ID.</param>
		/// <param name="color">ARGB foreground color.</param>
		/// <param name="fontStyle">Font style bit flags (0=normal, 1=bold, 2=italic, 4=strikethrough).</param>
		/// <returns>This theme instance (for chaining).</returns>
		public EditorTheme PutSyntaxStyle(uint styleId, int color, int fontStyle) {
			SyntaxStyles[styleId] = (color, fontStyle);
			return this;
		}

		/// <summary>
		/// Creates dark theme preset (VSCode Dark+ style).
		/// </summary>
		public static EditorTheme Dark() => new EditorTheme {
			BackgroundColor = Color.FromArgb(unchecked((int)0xFF1E1E1E)),
			TextColor = Color.FromArgb(unchecked((int)0xFFD4D4D4)),
			CursorColor = Color.FromArgb(unchecked((int)0xFFAEAFAD)),
			SelectionColor = Color.FromArgb(unchecked((int)0x99264F78)),
			LineNumberColor = Color.FromArgb(unchecked((int)0xFF858585)),
			CurrentLineColor = Color.FromArgb(unchecked((int)0x15FFFFFF)),
			GuideColor = Color.FromArgb(unchecked((int)0x33FFFFFF)),
			SeparatorColor = Color.FromArgb(unchecked((int)0xFF6A9955)),
			SplitLineColor = Color.FromArgb(unchecked((int)0x33FFFFFF)),
			CompositionColor = Color.FromArgb(unchecked((int)0xFFFFCC00)),
			InlayHintBgColor = Color.FromArgb(unchecked((int)0x20FFFFFF)),
			InlayHintTextColor = Color.FromArgb(unchecked((int)0xFFA0A0A0)),
			InlayHintIconColor = Color.FromArgb(unchecked((int)0xFFA0A0A0)),
			PhantomTextColor = Color.FromArgb(unchecked((int)0xFF6A6A6A)),
			FoldPlaceholderBgColor = Color.FromArgb(100, 80, 80, 80),
			FoldPlaceholderTextColor = Color.FromArgb(160, 200, 200, 200),
			DiagnosticErrorColor = Color.FromArgb(unchecked((int)0xFFF44747)),
			DiagnosticWarningColor = Color.FromArgb(unchecked((int)0xFFCCA700)),
			DiagnosticInfoColor = Color.FromArgb(unchecked((int)0xFF3794FF)),
			DiagnosticHintColor = Color.FromArgb(unchecked((int)0xFFEEEEEE)),
			LinkedEditingActiveColor = Color.FromArgb(unchecked((int)0x40007ACC)),
			LinkedEditingInactiveColor = Color.FromArgb(unchecked((int)0x20007ACC)),
			BracketHighlightBorderColor = Color.FromArgb(unchecked((int)0xFF888888)),
			BracketHighlightBgColor = Color.FromArgb(unchecked((int)0x20FFFFFF)),
			SyntaxStyles = new() {
				[1] = (unchecked((int)0xFFC678DD), 1),
				[2] = (unchecked((int)0xFF56B6C2), 0),
				[3] = (unchecked((int)0xFFCE9178), 0),
				[4] = (unchecked((int)0xFF6A9955), 2),
				[5] = (unchecked((int)0xFFD19A66), 0),
				[6] = (unchecked((int)0xFF61AFEF), 0),
				[7] = (unchecked((int)0xFFB5CEA8), 0),
				[8] = (unchecked((int)0xFFE5C07B), 1),
			},
		};

		/// <summary>
		/// Creates light theme preset (VSCode Light+ style).
		/// </summary>
		public static EditorTheme Light() => new EditorTheme {
			BackgroundColor = Color.FromArgb(unchecked((int)0xFFFFFFFF)),
			TextColor = Color.FromArgb(unchecked((int)0xFF000000)),
			CursorColor = Color.FromArgb(unchecked((int)0xFF000000)),
			SelectionColor = Color.FromArgb(unchecked((int)0x99ADD6FF)),
			LineNumberColor = Color.FromArgb(unchecked((int)0xFF237893)),
			CurrentLineColor = Color.FromArgb(unchecked((int)0x15000000)),
			GuideColor = Color.FromArgb(unchecked((int)0x33000000)),
			SeparatorColor = Color.FromArgb(unchecked((int)0xFF008000)),
			SplitLineColor = Color.FromArgb(unchecked((int)0x33000000)),
			CompositionColor = Color.FromArgb(unchecked((int)0xFF0066FF)),
			InlayHintBgColor = Color.FromArgb(unchecked((int)0x20000000)),
			InlayHintTextColor = Color.FromArgb(unchecked((int)0xFF808080)),
			InlayHintIconColor = Color.FromArgb(unchecked((int)0xFF808080)),
			PhantomTextColor = Color.FromArgb(unchecked((int)0xFFA0A0A0)),
			FoldPlaceholderBgColor = Color.FromArgb(100, 200, 200, 200),
			FoldPlaceholderTextColor = Color.FromArgb(160, 80, 80, 80),
			DiagnosticErrorColor = Color.FromArgb(unchecked((int)0xFFE51400)),
			DiagnosticWarningColor = Color.FromArgb(unchecked((int)0xFFBF8803)),
			DiagnosticInfoColor = Color.FromArgb(unchecked((int)0xFF1A85FF)),
			DiagnosticHintColor = Color.FromArgb(unchecked((int)0xFF6E6E6E)),
			LinkedEditingActiveColor = Color.FromArgb(unchecked((int)0x40007ACC)),
			LinkedEditingInactiveColor = Color.FromArgb(unchecked((int)0x20007ACC)),
			BracketHighlightBorderColor = Color.FromArgb(unchecked((int)0xFF888888)),
			BracketHighlightBgColor = Color.FromArgb(unchecked((int)0x20000000)),
			SyntaxStyles = new() {
				[1] = (unchecked((int)0xFF0000FF), 0),
				[2] = (unchecked((int)0xFF267F99), 0),
				[3] = (unchecked((int)0xFFA31515), 0),
				[4] = (unchecked((int)0xFF008000), 2),
				[5] = (unchecked((int)0xFF795E26), 0),
				[6] = (unchecked((int)0xFF795E26), 0),
				[7] = (unchecked((int)0xFF098658), 0),
				[8] = (unchecked((int)0xFF267F99), 1),
			},
		};
	}

	/// <summary>
	/// SweetEditor WinForms editor control.
	/// Based on <see cref="EditorCore"/> C++ engine for editing, layout and rendering-model generation.
	/// </summary>
	[Designer("System.Windows.Forms.Design.ControlDesigner, System.Design")]
	public class EditorControl : Control {
		/// <summary>
		/// Editor icon provider interface.
		/// Host code implements this interface to provide icon images for gutter icons and InlayHint ICON rendering.
		/// </summary>
		public interface EditorIconProvider {
			/// <summary>
			/// Returns the icon image for the given icon ID.
			/// Return <c>null</c> to skip rendering.
			/// </summary>
			Image? GetIconImage(int iconId);
		}

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

		// Current theme (default dark).
		private EditorTheme currentTheme = EditorTheme.Dark();

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

		private const float BaseTextFontSize = 11f;
		private const float BaseInlayHintFontSize = 9.5f;
		private const string BaseTextFontFamily = "Consolas";
		private const string BaseInlayHintFontFamily = "Segoe UI";
		private EditorCore editorCore;
		private Font regularFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Regular);
		private Font boldFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Bold);
		private Font italicFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Italic);
		private Font boldItalicFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Bold | FontStyle.Italic);
		// InlayHint font set.
		private Font inlayHintFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Regular);
		private Font inlayHintBoldFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Bold);
		private Font inlayHintItalicFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Italic);
		private Font inlayHintBoldItalicFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Bold | FontStyle.Italic);
		private Graphics textGraphics;
		private EditorRenderModel? renderModel;
		private int currentDrawingLineNumber = -1;
		private EditorIconProvider? editorIconProvider;
		private DecorationProviderManager? decorationProviderManager;
		private CompletionProviderManager? completionProviderManager;
		private CompletionPopupController? completionPopupController;
		private NewLineActionProviderManager? newLineActionProviderManager;
		// Brush cache to avoid per-run allocations.
		private readonly Dictionary<int, SolidBrush> brushCache = new Dictionary<int, SolidBrush>();
		private int lastMeasureDpi;
		private LanguageConfiguration? languageConfiguration;
		/// <summary>
		/// Custom editor metadata attached by host code.
		/// Cast to the concrete metadata subtype when reading it.
		/// </summary>
		public IEditorMetadata? Metadata { get; set; }

		// TextRenderer flags for consistent measuring/drawing.
		private static readonly TextFormatFlags TextMeasureDrawFlags = TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix;
		private const float ScrollbarThickness = 10f;
		private const float ScrollbarMinThumb = 24f;
		private ScrollMetrics scrollMetrics;
		private bool hasScrollMetrics = false;
		private RectangleF verticalScrollbarTrackRect = RectangleF.Empty;
		private RectangleF verticalScrollbarThumbRect = RectangleF.Empty;
		private RectangleF horizontalScrollbarTrackRect = RectangleF.Empty;
		private RectangleF horizontalScrollbarThumbRect = RectangleF.Empty;
		private bool draggingVerticalScrollbar = false;
		private bool draggingHorizontalScrollbar = false;
		private float scrollbarDragStartMouseX = 0f;
		private float scrollbarDragStartMouseY = 0f;
		private float scrollbarDragStartScrollX = 0f;
		private float scrollbarDragStartScrollY = 0f;
		private float scrollbarDragTravelX = 0f;
		private float scrollbarDragTravelY = 0f;
		private float scrollbarDragMaxScrollX = 0f;
		private float scrollbarDragMaxScrollY = 0f;
		private readonly MeasurePerfStats perfMeasureStats = new MeasurePerfStats();
		private readonly PerfOverlay perfOverlay = new PerfOverlay();

		private SolidBrush GetOrCreateBrush(int argb) {
			if (!brushCache.TryGetValue(argb, out var b)) {
				b = new SolidBrush(System.Drawing.Color.FromArgb(argb));
				brushCache[argb] = b;
			}
			return b;
		}

		private void LogBuildPerfSummary(PerfStepRecorder perf) {
			if (!EditorPerf.Enabled) return;
			double totalMs = EditorPerf.TicksToMs(perf.TotalTicks);
			double buildMs = perf.GetStepMs(PerfStepRecorder.StepBuild);
			bool shouldLog = totalMs >= EditorPerf.WarnBuildMs || buildMs >= EditorPerf.WarnBuildMs || perfMeasureStats.ShouldLogBuild();
			if (!shouldLog) return;
			Debug.WriteLine(
				$"[PERF][Build] total={totalMs:F2}ms " +
				$"{PerfStepRecorder.StepPrep}={perf.GetStepMs(PerfStepRecorder.StepPrep):F2}ms " +
				$"{PerfStepRecorder.StepBuild}={buildMs:F2}ms " +
				$"{PerfStepRecorder.StepMetrics}={perf.GetStepMs(PerfStepRecorder.StepMetrics):F2}ms " +
				$"{PerfStepRecorder.StepAnchor}={perf.GetStepMs(PerfStepRecorder.StepAnchor):F2}ms " +
				$"{PerfStepRecorder.StepInvalidate}={perf.GetStepMs(PerfStepRecorder.StepInvalidate):F2}ms " +
				$"| {perfMeasureStats.BuildSummary()}");
		}

		private void LogPaintPerfSummary(PerfStepRecorder perf) {
			if (!EditorPerf.Enabled) return;
			double totalMs = EditorPerf.TicksToMs(perf.TotalTicks);
			if (totalMs < EditorPerf.WarnPaintMs && !perf.AnyStepOver(EditorPerf.WarnPaintStepMs)) return;
			Debug.WriteLine(
				$"[PERF][Paint] total={totalMs:F2}ms " +
				$"{PerfStepRecorder.StepClear}={perf.GetStepMs(PerfStepRecorder.StepClear):F2}ms " +
				$"{PerfStepRecorder.StepCurrent}={perf.GetStepMs(PerfStepRecorder.StepCurrent):F2}ms " +
				$"{PerfStepRecorder.StepSelection}={perf.GetStepMs(PerfStepRecorder.StepSelection):F2}ms " +
				$"{PerfStepRecorder.StepLines}={perf.GetStepMs(PerfStepRecorder.StepLines):F2}ms " +
				$"{PerfStepRecorder.StepGuides}={perf.GetStepMs(PerfStepRecorder.StepGuides):F2}ms " +
				$"{PerfStepRecorder.StepComposition}={perf.GetStepMs(PerfStepRecorder.StepComposition):F2}ms " +
				$"{PerfStepRecorder.StepDiagnostics}={perf.GetStepMs(PerfStepRecorder.StepDiagnostics):F2}ms " +
				$"{PerfStepRecorder.StepLinkedEditing}={perf.GetStepMs(PerfStepRecorder.StepLinkedEditing):F2}ms " +
				$"{PerfStepRecorder.StepBracket}={perf.GetStepMs(PerfStepRecorder.StepBracket):F2}ms " +
				$"{PerfStepRecorder.StepCursor}={perf.GetStepMs(PerfStepRecorder.StepCursor):F2}ms " +
				$"{PerfStepRecorder.StepGutter}={perf.GetStepMs(PerfStepRecorder.StepGutter):F2}ms " +
				$"{PerfStepRecorder.StepLineNumber}={perf.GetStepMs(PerfStepRecorder.StepLineNumber):F2}ms " +
				$"{PerfStepRecorder.StepScrollbar}={perf.GetStepMs(PerfStepRecorder.StepScrollbar):F2}ms " +
				$"{PerfStepRecorder.StepPopup}={perf.GetStepMs(PerfStepRecorder.StepPopup):F2}ms");
		}

		private void RecordInputPerf(string tag, double elapsedMs) {
			perfOverlay.RecordInput(tag, elapsedMs);
		}

		private PerfScope StartInputPerf(string tag) {
			return PerfScope.Start(tag, EditorPerf.WarnInputMs, RecordInputPerf);
		}

		// Select main font by style flags.
		private Font GetFontByStyle(int fontStyle) {
			bool isBold = (fontStyle & FONT_STYLE_BOLD) != 0;
			bool isItalic = (fontStyle & FONT_STYLE_ITALIC) != 0;
			if (isBold && isItalic) return boldItalicFont;
			if (isBold) return boldFont;
			if (isItalic) return italicFont;
			return regularFont;
		}

		// Select inlay-hint font by style flags.
		private Font GetInlayHintFontByStyle(int fontStyle) {
			bool isBold = (fontStyle & FONT_STYLE_BOLD) != 0;
			bool isItalic = (fontStyle & FONT_STYLE_ITALIC) != 0;
			if (isBold && isItalic) return inlayHintBoldItalicFont;
			if (isBold) return inlayHintBoldFont;
			if (isItalic) return inlayHintItalicFont;
			return inlayHintFont;
		}

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
			this.BackColor = currentTheme.BackgroundColor;
			this.ForeColor = currentTheme.TextColor;

			// Re-register syntax highlighting styles to C++ core after theme change.
			if (editorCore != null) {
				foreach (var kvp in theme.SyntaxStyles) {
					editorCore.RegisterStyle(kvp.Key, kvp.Value.color, kvp.Value.fontStyle);
				}
			}

			Flush();
		}

		/// <summary>Enables or disables the performance overlay.</summary>
		public void SetPerfOverlayEnabled(bool enabled) {
			perfOverlay.SetEnabled(enabled);
			Invalidate();
		}

		/// <summary>Returns whether the performance overlay is enabled.</summary>
		public bool IsPerfOverlayEnabled() => perfOverlay.IsEnabled;

		#endregion

		#region Public API - Viewport/Font/Appearance

 /// <summary>Sets fold arrow mode.</summary>
 /// <param name="mode">Mode value.</param>
		public void SetFoldArrowMode(FoldArrowMode mode) => editorCore.SetFoldArrowMode((int)mode);

 /// <summary>Sets wrap mode.</summary>
 /// <param name="mode">Mode value.</param>
		public void SetWrapMode(WrapMode mode) {
			editorCore.SetWrapMode((int)mode);
			Flush();
		}

 /// <summary>Sets auto indent mode.</summary>
 /// <param name="mode">Mode value.</param>
		public void SetAutoIndentMode(AutoIndentMode mode) {
			editorCore.SetAutoIndentMode((int)mode);
		}

 /// <summary>Gets auto indent mode.</summary>
 /// <returns>Returns the resulting value.</returns>
		public AutoIndentMode GetAutoIndentMode() {
			return (AutoIndentMode)editorCore.GetAutoIndentMode();
		}

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
			newLineActionProviderManager ??= new NewLineActionProviderManager();
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

		/// <summary>Sets line spacing.</summary>
 /// <param name="add">Additional line spacing in pixels.</param>
 /// <param name="mult">Line spacing multiplier.</param>
		public void SetLineSpacing(float add, float mult) {
			editorCore.SetLineSpacing(add, mult);
			Flush();
		}

		/// <summary>Sets editor scale.</summary>
 /// <param name="scale">Scale factor (1.0 = 100%).</param>
		public void SetScale(float scale) {
			editorCore.SetScale(scale);
			SyncPlatformScale(scale);
			Flush();
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
		public void RegisterStyle(uint styleId, int color, int backgroundColor, int fontStyle) =>
			editorCore.RegisterStyle(styleId, color, backgroundColor, fontStyle);

 /// <summary>Register style.</summary>
 /// <param name="styleId">Style identifier.</param>
 /// <param name="color">Color value (ARGB).</param>
 /// <param name="fontStyle">Font style flags.</param>
		public void RegisterStyle(uint styleId, int color, int fontStyle) =>
			editorCore.RegisterStyle(styleId, color, fontStyle);

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

		#region Public API — InlayHint / PhantomText

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
			editorIconProvider = provider;
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
 /// <summary>Sets max gutter icons.</summary>
		public void SetMaxGutterIcons(int count) => editorCore.SetMaxGutterIcons(count);

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
			this.BackColor = currentTheme.BackgroundColor;
			this.ForeColor = currentTheme.TextColor;
			this.Font = regularFont;
			this.TabStop = true;
			if (IsDesignMode()) {
				return;
			}
			textGraphics = CreateGraphics();
			textGraphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
			var doubleClickSize = SystemInformation.DoubleClickSize;
			float clickSlop = Math.Max(20f, Math.Max(doubleClickSize.Width, doubleClickSize.Height));
			int doubleClickTime = SystemInformation.DoubleClickTime;
			editorCore = new EditorCore(new EditorCore.TextMeasurer {
				MeasureTextWidth = OnMeasureText,
				MeasureInlayHintWidth = OnMeasureInlayHintText,
				MeasureIconWidth = OnMeasureIconWidth,
				GetFontMetrics = OnGetFontMetrics
			}, new EditorOptions { TouchSlop = clickSlop, DoubleTapTimeout = doubleClickTime });
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

			// Register default theme syntax highlighting styles.
			foreach (var kvp in currentTheme.SyntaxStyles) {
				editorCore.RegisterStyle(kvp.Key, kvp.Value.color, kvp.Value.fontStyle);
			}
		}

		protected override void OnHandleCreated(EventArgs e) {
			base.OnHandleCreated(e);
			if (IsDesignMode() || editorCore == null) return;
			// Recreate measuring graphics after handle exists to align with actual DPI.
			RecreateTextGraphicsAndResetMeasurer();
			// Force one rebuild so pre-handle zero-width measurements are cleared.
			Flush();
		}

		protected override void OnPaint(PaintEventArgs e) {
			base.OnPaint(e);
			var perf = PerfStepRecorder.Start();
			e.Graphics.Clear(currentTheme.BackgroundColor);
			perf.Mark(PerfStepRecorder.StepClear);

			if (this.renderModel == null) {
				perf.Finish();
				EditorPerf.LogSlow("OnPaint(no-model)", perf.TotalTicks, EditorPerf.WarnPaintMs);
				perfOverlay.RecordDraw(perf);
				perfOverlay.Draw(e.Graphics, ClientSize.Width);
				return;
			}
			e.Graphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
			e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;

			EditorRenderModel renderModel = (EditorRenderModel)this.renderModel;

			DrawCurrentLineHighlight(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepCurrent);
			DrawSelectionRects(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepSelection);
			DrawLines(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepLines);
			DrawGuideSegments(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepGuides);
			if (renderModel.CompositionDecoration.Active) {
				DrawCompositionDecoration(e.Graphics, renderModel.CompositionDecoration);
				perf.Mark(PerfStepRecorder.StepComposition);
			}
			DrawDiagnosticDecorations(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepDiagnostics);
			DrawLinkedEditingRects(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepLinkedEditing);
			DrawBracketHighlightRects(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepBracket);
			DrawCursor(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepCursor);
			DrawGutterOverlay(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepGutter);
			DrawLineNumbers(e.Graphics, renderModel);
			perf.Mark(PerfStepRecorder.StepLineNumber);
			DrawScrollbars(e.Graphics);
			perf.Mark(PerfStepRecorder.StepScrollbar);
			UpdateCompletionPopupCursorAnchor();
			perf.Mark(PerfStepRecorder.StepPopup);

			perf.Finish();
			LogPaintPerfSummary(perf);
			perfOverlay.RecordDraw(perf);
			perfOverlay.Draw(e.Graphics, ClientSize.Width);
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
				var cursor = editorCore.GetCursorPosition();
				var doc = editorCore.GetDocument();
				string lineText = doc?.GetLineText(cursor.Line) ?? "";
				var ctx = new NewLineContext(cursor.Line, cursor.Column, lineText,
					GetLanguageConfiguration());
			var action = newLineActionProviderManager.ProvideNewLineAction(ctx);
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
			if (e.Button == MouseButtons.Left && HandleScrollbarMouseDown(e)) {
				base.OnMouseDown(e);
				return;
			}
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
			if (HandleScrollbarMouseMove(e)) {
				base.OnMouseMove(e);
				return;
			}
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
			}
			base.OnMouseMove(e);
		}

		protected override void OnMouseUp(MouseEventArgs e) {
			using var perf = StartInputPerf($"OnMouseUp({e.Button})");
			if (e.Button == MouseButtons.Left && HandleScrollbarMouseUp()) {
				base.OnMouseUp(e);
				return;
			}
			if (e.Button == MouseButtons.Left) {
				Modifier mods = GetCurrentModifiers();
				GestureResult gestureResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_UP,
					Points = [new PointF(e.X, e.Y)],
					Modifiers = mods,
					DirectScale = 1
				});
				FireGestureEvents(gestureResult, new System.Drawing.PointF(e.X, e.Y));
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

		private bool HandleScrollbarMouseDown(MouseEventArgs e) {
			UpdateScrollbarGeometry();
			System.Drawing.PointF point = new System.Drawing.PointF(e.X, e.Y);

			if (verticalScrollbarThumbRect.Contains(point)) {
				draggingVerticalScrollbar = true;
				draggingHorizontalScrollbar = false;
				scrollbarDragStartMouseY = e.Y;
				scrollbarDragStartScrollY = hasScrollMetrics ? scrollMetrics.ScrollY : 0f;
				scrollbarDragTravelY = Math.Max(0f, verticalScrollbarTrackRect.Height - verticalScrollbarThumbRect.Height);
				scrollbarDragMaxScrollY = hasScrollMetrics ? Math.Max(0f, scrollMetrics.MaxScrollY) : 0f;
				Capture = true;
				return true;
			}

			if (horizontalScrollbarThumbRect.Contains(point)) {
				draggingHorizontalScrollbar = true;
				draggingVerticalScrollbar = false;
				scrollbarDragStartMouseX = e.X;
				scrollbarDragStartScrollX = hasScrollMetrics ? scrollMetrics.ScrollX : 0f;
				scrollbarDragTravelX = Math.Max(0f, horizontalScrollbarTrackRect.Width - horizontalScrollbarThumbRect.Width);
				scrollbarDragMaxScrollX = hasScrollMetrics ? Math.Max(0f, scrollMetrics.MaxScrollX) : 0f;
				Capture = true;
				return true;
			}

			if (hasScrollMetrics && verticalScrollbarTrackRect.Contains(point)) {
				if (verticalScrollbarTrackRect.Height > 0f && scrollMetrics.MaxScrollY > 0f) {
					float travel = Math.Max(0f, verticalScrollbarTrackRect.Height - verticalScrollbarThumbRect.Height);
					float ratio = travel <= 0f
						? 0f
						: Clamp01((e.Y - verticalScrollbarTrackRect.Y - verticalScrollbarThumbRect.Height * 0.5f) / travel);
					float targetY = ratio * scrollMetrics.MaxScrollY;
					SetScrollFromScrollbar(scrollMetrics.ScrollX, targetY);
				}
				return true;
			}

			if (hasScrollMetrics && horizontalScrollbarTrackRect.Contains(point)) {
				if (horizontalScrollbarTrackRect.Width > 0f && scrollMetrics.MaxScrollX > 0f) {
					float travel = Math.Max(0f, horizontalScrollbarTrackRect.Width - horizontalScrollbarThumbRect.Width);
					float ratio = travel <= 0f
						? 0f
						: Clamp01((e.X - horizontalScrollbarTrackRect.X - horizontalScrollbarThumbRect.Width * 0.5f) / travel);
					float targetX = ratio * scrollMetrics.MaxScrollX;
					SetScrollFromScrollbar(targetX, scrollMetrics.ScrollY);
				}
				return true;
			}

			return false;
		}

		private bool HandleScrollbarMouseMove(MouseEventArgs e) {
			if (!draggingVerticalScrollbar && !draggingHorizontalScrollbar) {
				return false;
			}
			if (!hasScrollMetrics) {
				return true;
			}

			if (draggingVerticalScrollbar) {
				float targetY = scrollbarDragStartScrollY;
				if (scrollbarDragTravelY > 0f && scrollbarDragMaxScrollY > 0f) {
					float delta = e.Y - scrollbarDragStartMouseY;
					targetY += delta * scrollbarDragMaxScrollY / scrollbarDragTravelY;
				}
				targetY = Clamp(targetY, 0f, scrollMetrics.MaxScrollY);
				SetScrollFromScrollbar(scrollMetrics.ScrollX, targetY);
				return true;
			}

			if (draggingHorizontalScrollbar) {
				float targetX = scrollbarDragStartScrollX;
				if (scrollbarDragTravelX > 0f && scrollbarDragMaxScrollX > 0f) {
					float delta = e.X - scrollbarDragStartMouseX;
					targetX += delta * scrollbarDragMaxScrollX / scrollbarDragTravelX;
				}
				targetX = Clamp(targetX, 0f, scrollMetrics.MaxScrollX);
				SetScrollFromScrollbar(targetX, scrollMetrics.ScrollY);
				return true;
			}

			return false;
		}

		private bool HandleScrollbarMouseUp() {
			if (!draggingVerticalScrollbar && !draggingHorizontalScrollbar) {
				return false;
			}
			draggingVerticalScrollbar = false;
			draggingHorizontalScrollbar = false;
			Capture = false;
			return true;
		}

		private void SetScrollFromScrollbar(float scrollX, float scrollY) {
			editorCore.SetScroll(scrollX, scrollY);
			Flush();
			if (hasScrollMetrics) {
				ScrollChanged?.Invoke(this, new ScrollChangedEventArgs(scrollMetrics.ScrollX, scrollMetrics.ScrollY));
			}
			decorationProviderManager?.OnScrollChanged();
			if (completionPopupController != null && completionPopupController.IsShowing) {
				completionProviderManager?.Dismiss();
			}
		}

		private static Modifier GetCurrentModifiers() {
			Modifier mods = Modifier.NONE;
			if ((Control.ModifierKeys & Keys.Shift) != 0) mods |= Modifier.SHIFT;
			if ((Control.ModifierKeys & Keys.Control) != 0) mods |= Modifier.CTRL;
			if ((Control.ModifierKeys & Keys.Alt) != 0) mods |= Modifier.ALT;
			return mods;
		}

		/// <summary>Gets font ascent.</summary>
		private static float GetFontAscent(Graphics g, Font font) {
			int designAscent = font.FontFamily.GetCellAscent(font.Style);
			int designEmHeight = font.FontFamily.GetEmHeight(font.Style);
			// points -> pixels: px = pt * dpi / 72
			float pixelAscent = designAscent * font.SizeInPoints * g.DpiY / (designEmHeight * 72f);
			return pixelAscent;
		}

		#region Rendering

		private void DrawLines(Graphics g, EditorRenderModel model) {
			List<VisualLine> lines = model.VisualLines;
			if (lines == null) return;
			foreach (var line in lines) {
				if (line.Runs == null) continue;
				foreach (var run in line.Runs) {
					DrawVisualRun(g, run);
				}
			}
		}

		private void DrawGutterOverlay(Graphics g, EditorRenderModel model) {
			if (model.SplitX <= 0) return;
			using var brush = new SolidBrush(currentTheme.BackgroundColor);
			g.FillRectangle(brush, 0, 0, model.SplitX, this.ClientSize.Height);
			DrawCurrentLineHighlight(g, model, model.SplitX);
			DrawLineSplit(g, model.SplitX);
		}

		private void DrawLineNumbers(Graphics g, EditorRenderModel model) {
			List<VisualLine> lines = model.VisualLines;
			if (lines == null) return;
			currentDrawingLineNumber = -1;
			foreach (var line in lines) {
				DrawLineNumber(g, line, model);
			}
		}

		private void DrawScrollbars(Graphics g) {
			UpdateScrollbarGeometry();
			bool hasVertical = verticalScrollbarTrackRect.Width > 0 && verticalScrollbarTrackRect.Height > 0;
			bool hasHorizontal = horizontalScrollbarTrackRect.Width > 0 && horizontalScrollbarTrackRect.Height > 0;
			if (!hasVertical && !hasHorizontal) return;

			using var trackBrush = new SolidBrush(WithAlpha(currentTheme.SplitLineColor, 72));
			using var thumbBrush = new SolidBrush(WithAlpha(currentTheme.LineNumberColor, 170));
			using var activeThumbBrush = new SolidBrush(WithAlpha(currentTheme.LineNumberColor, 220));

			if (hasVertical) {
				g.FillRectangle(trackBrush, verticalScrollbarTrackRect);
				using var path = CreateRoundedRectPath(verticalScrollbarThumbRect, ScrollbarThickness * 0.5f);
				g.FillPath(draggingVerticalScrollbar ? activeThumbBrush : thumbBrush, path);
			}

			if (hasHorizontal) {
				g.FillRectangle(trackBrush, horizontalScrollbarTrackRect);
				using var path = CreateRoundedRectPath(horizontalScrollbarThumbRect, ScrollbarThickness * 0.5f);
				g.FillPath(draggingHorizontalScrollbar ? activeThumbBrush : thumbBrush, path);
			}

			if (hasVertical && hasHorizontal) {
				var corner = new RectangleF(
					verticalScrollbarTrackRect.X,
					horizontalScrollbarTrackRect.Y,
					verticalScrollbarTrackRect.Width,
					horizontalScrollbarTrackRect.Height);
				g.FillRectangle(trackBrush, corner);
			}
		}

		private void UpdateScrollbarGeometry() {
			if (!hasScrollMetrics || ClientSize.Width <= 0 || ClientSize.Height <= 0) {
				ResetScrollbarRects();
				return;
			}

			bool showVertical = scrollMetrics.CanScrollY;
			bool showHorizontal = scrollMetrics.CanScrollX;

			float width = ClientSize.Width;
			float height = ClientSize.Height;

			float verticalTrackHeight = height - (showHorizontal ? ScrollbarThickness : 0f);
			if (showVertical && verticalTrackHeight > 0f) {
				verticalScrollbarTrackRect = new RectangleF(
					width - ScrollbarThickness,
					0f,
					ScrollbarThickness,
					verticalTrackHeight);
				float viewport = Math.Max(1f, scrollMetrics.ViewportHeight);
				float contentSpan = Math.Max(viewport, scrollMetrics.MaxScrollY + viewport);
				float thumbHeight = Math.Max(ScrollbarMinThumb, verticalTrackHeight * viewport / contentSpan);
				thumbHeight = Math.Min(thumbHeight, verticalTrackHeight);
				float travel = Math.Max(0f, verticalTrackHeight - thumbHeight);
				float ratio = scrollMetrics.MaxScrollY <= 0f ? 0f : Clamp01(scrollMetrics.ScrollY / scrollMetrics.MaxScrollY);
				float thumbY = travel <= 0f ? 0f : travel * ratio;
				verticalScrollbarThumbRect = new RectangleF(
					verticalScrollbarTrackRect.X,
					thumbY,
					ScrollbarThickness,
					thumbHeight);
			} else {
				verticalScrollbarTrackRect = RectangleF.Empty;
				verticalScrollbarThumbRect = RectangleF.Empty;
			}

			float horizontalTrackX = Math.Max(0f, scrollMetrics.TextAreaX);
			float horizontalTrackWidth = width - horizontalTrackX - (showVertical ? ScrollbarThickness : 0f);
			float horizontalTrackY = height - ScrollbarThickness;
			if (showHorizontal && horizontalTrackWidth > 0f && horizontalTrackY >= 0f) {
				horizontalScrollbarTrackRect = new RectangleF(
					horizontalTrackX,
					horizontalTrackY,
					horizontalTrackWidth,
					ScrollbarThickness);
				float viewport = Math.Max(1f, scrollMetrics.TextAreaWidth);
				float contentSpan = Math.Max(viewport, scrollMetrics.MaxScrollX + viewport);
				float thumbWidth = Math.Max(ScrollbarMinThumb, horizontalTrackWidth * viewport / contentSpan);
				thumbWidth = Math.Min(thumbWidth, horizontalTrackWidth);
				float travel = Math.Max(0f, horizontalTrackWidth - thumbWidth);
				float ratio = scrollMetrics.MaxScrollX <= 0f ? 0f : Clamp01(scrollMetrics.ScrollX / scrollMetrics.MaxScrollX);
				float thumbX = horizontalTrackX + (travel <= 0f ? 0f : travel * ratio);
				horizontalScrollbarThumbRect = new RectangleF(
					thumbX,
					horizontalTrackY,
					thumbWidth,
					ScrollbarThickness);
			} else {
				horizontalScrollbarTrackRect = RectangleF.Empty;
				horizontalScrollbarThumbRect = RectangleF.Empty;
			}
		}

		private void ResetScrollbarRects() {
			verticalScrollbarTrackRect = RectangleF.Empty;
			verticalScrollbarThumbRect = RectangleF.Empty;
			horizontalScrollbarTrackRect = RectangleF.Empty;
			horizontalScrollbarThumbRect = RectangleF.Empty;
		}

		private static GraphicsPath CreateRoundedRectPath(RectangleF rect, float radius) {
			var path = new GraphicsPath();
			if (rect.Width <= 0f || rect.Height <= 0f || radius <= 0f) {
				path.AddRectangle(rect);
				return path;
			}
			float d = radius * 2f;
			path.AddArc(rect.X, rect.Y, d, d, 180, 90);
			path.AddArc(rect.Right - d, rect.Y, d, d, 270, 90);
			path.AddArc(rect.Right - d, rect.Bottom - d, d, d, 0, 90);
			path.AddArc(rect.X, rect.Bottom - d, d, d, 90, 90);
			path.CloseFigure();
			return path;
		}

		private static float Clamp01(float value) {
			if (value < 0f) return 0f;
			if (value > 1f) return 1f;
			return value;
		}

		private static float Clamp(float value, float min, float max) {
			return Math.Max(min, Math.Min(max, value));
		}

		private static Color WithAlpha(Color color, int alpha) {
			return Color.FromArgb(Math.Max(0, Math.Min(255, alpha)), color.R, color.G, color.B);
		}

		private void DrawLineNumber(Graphics g, VisualLine visualLine, EditorRenderModel model) {
			if (visualLine.WrapIndex != 0 || visualLine.IsPhantomLine) return;
			PointF position = visualLine.LineNumberPosition;
			float topY = position.Y - GetFontAscent(g, regularFont);
			float lineHeight = regularFont.GetHeight(g);
			List<int>? gutterIconIds = visualLine.GutterIconIds;
		bool hasIcons = editorIconProvider != null && gutterIconIds is { Count: > 0 };
			int newLineNumber = visualLine.LogicalLine + 1;
			if (model.MaxGutterIcons == 0 && hasIcons) {
				List<int> iconIds = gutterIconIds!;
				DrawOverlayGutterIcon(g, iconIds[0], position.X, topY, lineHeight);
				currentDrawingLineNumber = newLineNumber;
			} else if (newLineNumber != currentDrawingLineNumber) {
				var rect = new Rectangle((int)position.X, (int)topY, 120, (int)Math.Ceiling(regularFont.GetHeight(g)));
				TextRenderer.DrawText(g, newLineNumber.ToString(), regularFont, rect, currentTheme.LineNumberColor, TextMeasureDrawFlags);
				currentDrawingLineNumber = newLineNumber;
			}

			if (hasIcons && model.MaxGutterIcons != 0) {
				List<int> iconIds = gutterIconIds!;
				float iconRight = model.FoldArrowX > 0 ? model.FoldArrowX - lineHeight * 0.5f : model.SplitX - 2f;
				int maxIcons = model.MaxGutterIcons > 0
					? Math.Min(iconIds.Count, model.MaxGutterIcons)
					: iconIds.Count;
				for (int i = maxIcons - 1; i >= 0; i--) {
					int iconId = iconIds[i];
					if (DrawGutterIcon(g, iconId, iconRight - lineHeight, topY, lineHeight, lineHeight)) {
						iconRight -= lineHeight;
					}
				}
			}

			if (visualLine.FoldState != FoldState.NONE) {
				float halfSize = lineHeight * 0.2f;
				float centerX = model.FoldArrowX > 0 ? model.FoldArrowX : model.SplitX - lineHeight * 0.5f;
				float centerY = topY + lineHeight * 0.5f;

				using var path = new GraphicsPath();
				using var pen = new Pen(currentTheme.LineNumberColor, Math.Max(1f, lineHeight * 0.1f)) {
					StartCap = LineCap.Round,
					EndCap = LineCap.Round,
					LineJoin = LineJoin.Round
				};

				if (visualLine.FoldState == FoldState.COLLAPSED) {
					path.AddLines([
						new System.Drawing.PointF(centerX - halfSize * 0.5f, centerY - halfSize),
						new System.Drawing.PointF(centerX + halfSize * 0.5f, centerY),
						new System.Drawing.PointF(centerX - halfSize * 0.5f, centerY + halfSize)
					]);
				} else {
					path.AddLines([
						new System.Drawing.PointF(centerX - halfSize, centerY - halfSize * 0.5f),
						new System.Drawing.PointF(centerX, centerY + halfSize * 0.5f),
						new System.Drawing.PointF(centerX + halfSize, centerY - halfSize * 0.5f)
					]);
				}
				g.DrawPath(pen, path);
			}
		}

		private void DrawLineSplit(Graphics g, float x) {
			using var pen = new Pen(currentTheme.SplitLineColor, 1f);
			g.DrawLine(pen, x, 0, x, this.ClientSize.Height);
		}

		private void DrawOverlayGutterIcon(Graphics g, int iconId, float x, float y, float size) {
			DrawGutterIcon(g, iconId, x, y, size, size);
		}

		private bool DrawGutterIcon(Graphics g, int iconId, float x, float y, float width, float height) {
		Image? image = editorIconProvider?.GetIconImage(iconId);
			if (image == null) return false;
			InterpolationMode oldInterpolation = g.InterpolationMode;
			g.InterpolationMode = InterpolationMode.HighQualityBicubic;
			g.DrawImage(image, x, y, width, height);
			g.InterpolationMode = oldInterpolation;
			return true;
		}

		private void DrawVisualRun(Graphics g, VisualRun visualRun) {
			string text = visualRun.Text;
			string drawTextContent = text ?? string.Empty;
			bool hasText = !string.IsNullOrEmpty(text);
			if (!hasText && visualRun.Type != VisualRunType.INLAY_HINT) return;
			// InlayHint uses dedicated fonts, others use main fonts.
			Font font = (visualRun.Type == VisualRunType.INLAY_HINT)
				? GetInlayHintFontByStyle(visualRun.Style.FontStyle)
				: GetFontByStyle(visualRun.Style.FontStyle);
			Color color = (visualRun.Style.Color != 0)
				? Color.FromArgb(visualRun.Style.Color)
				: currentTheme.TextColor;

			// C++ run.y is baseline; convert to top.
			float ascent = GetFontAscent(g, font);
			float topY = visualRun.Y - ascent;
			int lineHeight = (int)Math.Ceiling(font.GetHeight(g));

			// Re-measure with current graphics to avoid stale/zero widths.
			Size measuredSize = TextRenderer.MeasureText(g, drawTextContent, font, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags);
			int drawWidth = Math.Max((int)Math.Ceiling(visualRun.Width), measuredSize.Width);
			if (drawWidth < 1) drawWidth = 1;

			// Draw fold-placeholder: semi-transparent rounded background + "…" text.
			if (visualRun.Type == VisualRunType.FOLD_PLACEHOLDER) {
				float mgn = visualRun.Margin;
				float fontHeight = font.GetHeight(g);
				float bgLeft = visualRun.X + mgn;
				float bgTop = topY;
				float bgWidth = visualRun.Width - mgn * 2;
				float bgHeight = fontHeight;
				float radius = fontHeight * 0.2f;
				using (var bgBrush = new SolidBrush(currentTheme.FoldPlaceholderBgColor)) {
					DrawRoundedRect(g, bgBrush, bgLeft, bgTop, bgWidth, bgHeight, radius);
				}
				float textX = visualRun.X + mgn + visualRun.Padding;
				int foldW = Math.Max(1, (int)Math.Ceiling(visualRun.Width - mgn * 2 - visualRun.Padding * 2));
				foldW = Math.Max(foldW, measuredSize.Width);
				var foldRect = new Rectangle((int)textX, (int)topY, foldW, lineHeight);
				Color foldColor = currentTheme.FoldPlaceholderTextColor;
				TextRenderer.DrawText(g, drawTextContent, font, foldRect, foldColor, TextMeasureDrawFlags);
			}
			// Draw inlay-hint rounded background and inner text padding.
			else if (visualRun.Type == VisualRunType.INLAY_HINT) {
				float mgn = visualRun.Margin;
				float fontHeight = font.GetHeight(g);
				float bgLeft = visualRun.X + mgn;
				float bgTop = topY;
				float bgWidth = visualRun.Width - mgn * 2; // includes margins, paddings, and text width
				float bgHeight = fontHeight;

				if (visualRun.ColorValue != 0) {
 // COLOR :, background, padding, rectangle
					float blockSize = fontHeight;
					float colorLeft = visualRun.X + mgn;
					float colorTop = topY;
					using (var colorBrush = new SolidBrush(Color.FromArgb(visualRun.ColorValue))) {
						g.FillRectangle(colorBrush, colorLeft, colorTop, blockSize, blockSize);
					}
				} else {
 // TEXT / ICON : background + content
					float radius = fontHeight * 0.2f;
					using (var bgBrush = new SolidBrush(currentTheme.InlayHintBgColor)) {
						DrawRoundedRect(g, bgBrush, bgLeft, bgTop, bgWidth, bgHeight, radius);
					}
				if (visualRun.IconId > 0 && editorIconProvider != null) {
						float iconSize = Math.Min(bgWidth, bgHeight);
						float iconLeft = bgLeft + (bgWidth - iconSize) * 0.5f;
						float iconTop2 = bgTop + (bgHeight - iconSize) * 0.5f;
						DrawGutterIcon(g, visualRun.IconId, iconLeft, iconTop2, iconSize, iconSize);
					} else if (hasText) {
						float textX = visualRun.X + mgn + visualRun.Padding;
						int inlayW = Math.Max(1, (int)Math.Ceiling(visualRun.Width - mgn * 2 - visualRun.Padding * 2));
						inlayW = Math.Max(inlayW, measuredSize.Width);
						var inlayRect = new Rectangle((int)textX, (int)topY, inlayW, lineHeight);
						TextRenderer.DrawText(g, drawTextContent, font, inlayRect, color, TextMeasureDrawFlags);
					}
				}
			} else {
 // background (/)
				if (visualRun.Style.BackgroundColor != 0) {
					using var bgBrush = new SolidBrush(Color.FromArgb(visualRun.Style.BackgroundColor));
					g.FillRectangle(bgBrush, visualRun.X, topY, drawWidth, lineHeight);
				}
				var rect = new Rectangle((int)visualRun.X, (int)topY, drawWidth, lineHeight);
				Color drawColor = visualRun.Type == VisualRunType.PHANTOM_TEXT
					? Color.FromArgb(128, color)
					: color;
				TextRenderer.DrawText(g, drawTextContent, font, rect, drawColor, TextMeasureDrawFlags);
			}

			// Draw strikethrough around x-height center.
			if ((visualRun.Style.FontStyle & FONT_STYLE_STRIKETHROUGH) != 0) {
				float strikeY = topY + ascent * 0.5f;
				using var pen = new Pen(color, 1f);
				g.DrawLine(pen, visualRun.X, strikeY, visualRun.X + visualRun.Width, strikeY);
			}
		}

		/// <summary>Draw rounded rect.</summary>
		private static void DrawRoundedRect(Graphics g, Brush brush, float x, float y, float width, float height, float radius) {
			if (radius <= 0) {
				g.FillRectangle(brush, x, y, width, height);
				return;
			}
			using (var path = new GraphicsPath()) {
				float d = radius * 2;
				path.AddArc(x, y, d, d, 180, 90);
				path.AddArc(x + width - d, y, d, d, 270, 90);
				path.AddArc(x + width - d, y + height - d, d, d, 0, 90);
				path.AddArc(x, y + height - d, d, d, 90, 90);
				path.CloseFigure();
				g.FillPath(brush, path);
			}
		}

		/// <summary>Draw current line highlight.</summary>
		private void DrawCurrentLineHighlight(Graphics g, EditorRenderModel model) {
			DrawCurrentLineHighlight(g, model, ClientSize.Width);
		}

		private void DrawCurrentLineHighlight(Graphics g, EditorRenderModel model, float width) {
			if (model.VisualLines == null || model.VisualLines.Count == 0) return;
			float lineH = model.Cursor.Height > 0 ? model.Cursor.Height : regularFont.GetHeight(g);
			using var brush = new SolidBrush(currentTheme.CurrentLineColor);
			g.FillRectangle(brush, 0, model.CurrentLine.Y, width, lineH);
		}

		/// <summary>Draw selection rects.</summary>
		private void DrawSelectionRects(Graphics g, EditorRenderModel model) {
			if (model.SelectionRects == null || model.SelectionRects.Count == 0) return;
			using var brush = new SolidBrush(currentTheme.SelectionColor);
			foreach (var rect in model.SelectionRects) {
				g.FillRectangle(brush, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
			}
		}

		/// <summary>Draw cursor.</summary>
		private void DrawCursor(Graphics g, EditorRenderModel model) {
			if (!model.Cursor.Visible) return;
			using var brush = new SolidBrush(currentTheme.CursorColor);
			g.FillRectangle(brush, model.Cursor.Position.X, model.Cursor.Position.Y, 2f, model.Cursor.Height);
		}

		/// <summary>Draw composition decoration.</summary>
		private void DrawCompositionDecoration(Graphics g, CompositionDecoration comp) {
			float y = comp.Origin.Y + comp.Height;
			using var pen = new Pen(currentTheme.CompositionColor, 2f);
			g.DrawLine(pen, comp.Origin.X, y, comp.Origin.X + comp.Width, y);
		}

		/// <summary>Draw diagnostic decorations.</summary>
		private void DrawDiagnosticDecorations(Graphics g, EditorRenderModel model) {
			if (model.DiagnosticDecorations == null || model.DiagnosticDecorations.Count == 0) return;

			foreach (var diag in model.DiagnosticDecorations) {
				var color = diag.Color != 0
					? System.Drawing.Color.FromArgb(diag.Color)
					: diag.Severity switch {
						0 => System.Drawing.Color.FromArgb(255, 255, 0, 0),      // ERROR: red
						1 => System.Drawing.Color.FromArgb(255, 255, 204, 0),    // WARNING: yellow
						2 => System.Drawing.Color.FromArgb(255, 97, 181, 237),   // INFO: blue
						_ => System.Drawing.Color.FromArgb(178, 153, 153, 153),  // HINT: gray 70%
					};

				float startX = diag.Origin.X;
				float endX = startX + diag.Width;
				float baseY = diag.Origin.Y + diag.Height - 1f;

				using var pen = new Pen(color, 3.0f);

				if (diag.Severity == 3) {
					// HINT: dashed straight underline
					pen.DashPattern = [3f, 2f];
					g.DrawLine(pen, startX, baseY, endX, baseY);
				} else {
					// ERROR/WARNING/INFO: smooth arc wavy line
					float halfWave = 7f;
					float amplitude = 3.5f;
					using var path = new GraphicsPath();
					float x = startX;
					int step = 0;
					while (x < endX) {
						float nextX = Math.Min(x + halfWave, endX);
						float midX = (x + nextX) / 2f;
						float peakY = (step % 2 == 0) ? baseY - amplitude : baseY + amplitude;
						// Quadratic bezier → cubic: ctrl = Q, P0→P1 endpoints
						float c1x = x + 2f / 3f * (midX - x);
						float c1y = baseY + 2f / 3f * (peakY - baseY);
						float c2x = nextX + 2f / 3f * (midX - nextX);
						float c2y = baseY + 2f / 3f * (peakY - baseY);
						var p0 = step == 0
							? new System.Drawing.PointF(x, baseY)
							: path.GetLastPoint();
						path.AddBezier(p0,
							new System.Drawing.PointF(c1x, c1y),
							new System.Drawing.PointF(c2x, c2y),
							new System.Drawing.PointF(nextX, baseY));
						x = nextX;
						step++;
					}
					g.DrawPath(pen, path);
				}
			}
		}

		/// <summary>Draw linked editing rects.</summary>
		private void DrawLinkedEditingRects(Graphics g, EditorRenderModel model) {
			if (model.LinkedEditingRects == null || model.LinkedEditingRects.Count == 0) return;
			foreach (var rect in model.LinkedEditingRects) {
				if (rect.IsActive) {
					// Active tab stop: semi-transparent fill + thicker border
					using var fillBrush = new SolidBrush(System.Drawing.Color.FromArgb(30, 86, 156, 214));
					g.FillRectangle(fillBrush, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
					using var pen = new Pen(System.Drawing.Color.FromArgb(204, 86, 156, 214), 2f);
					g.DrawRectangle(pen, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
				} else {
					// Inactive tab stop: border only
					using var pen = new Pen(System.Drawing.Color.FromArgb(102, 86, 156, 214), 1f);
					g.DrawRectangle(pen, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
				}
			}
		}

		/// <summary>Draw bracket highlight rects.</summary>
		private void DrawBracketHighlightRects(Graphics g, EditorRenderModel model) {
			if (model.BracketHighlightRects == null || model.BracketHighlightRects.Count == 0) return;
			foreach (var rect in model.BracketHighlightRects) {
				// Background fill (semi-transparent gold)
				using var fillBrush = new SolidBrush(System.Drawing.Color.FromArgb(48, 255, 215, 0));
				g.FillRectangle(fillBrush, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
				// Border (gold)
				using var pen = new Pen(System.Drawing.Color.FromArgb(204, 255, 215, 0), 1.5f);
				g.DrawRectangle(pen, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
			}
		}

		/// <summary>Draw guide segments.</summary>
		private void DrawGuideSegments(Graphics g, EditorRenderModel model) {
			if (model.GuideSegments == null || model.GuideSegments.Count == 0) return;
			foreach (var seg in model.GuideSegments) {
				var color = seg.Type switch {
					GuideType.SEPARATOR => currentTheme.SeparatorColor,
					_ => currentTheme.GuideColor
				};
				float lineWidth = seg.Type == GuideType.INDENT ? 1f : 1.2f;
				using var pen = new Pen(color, lineWidth);

				if (seg.ArrowEnd) {
					float dpiScale = g.DpiX / 96f;
					float arrowLen = (seg.Type == GuideType.FLOW ? 9f : 8f) * dpiScale;
					float arrowAngle = (float)(Math.PI * 28.0 / 180.0);
					float arrowDepth = (float)(arrowLen * Math.Cos(arrowAngle));
					float dx = seg.End.X - seg.Start.X;
					float dy = seg.End.Y - seg.Start.Y;
					float len = (float)Math.Sqrt(dx * dx + dy * dy);
					float trim = arrowDepth + lineWidth * 0.5f;
					if (len > trim) {
						float ratio = (len - trim) / len;
						float lineEndX = seg.Start.X + dx * ratio;
						float lineEndY = seg.Start.Y + dy * ratio;
						g.DrawLine(pen, seg.Start.X, seg.Start.Y, lineEndX, lineEndY);
					}
					DrawArrowHead(g, color, seg.Start, seg.End, arrowLen, arrowAngle);
				} else {
					g.DrawLine(pen, seg.Start.X, seg.Start.Y, seg.End.X, seg.End.Y);
				}
			}
		}

		/// <summary>Draw arrow head.</summary>
		private static void DrawArrowHead(Graphics g, System.Drawing.Color color, PointF from, PointF to, float arrowLen, float arrowAngle) {
			float dx = to.X - from.X;
			float dy = to.Y - from.Y;
			float len = (float)Math.Sqrt(dx * dx + dy * dy);
			if (len < 1f) return;
			float ux = dx / len;
			float uy = dy / len;
			float cosA = (float)Math.Cos(arrowAngle);
			float sinA = (float)Math.Sin(arrowAngle);
			float ax1 = to.X - arrowLen * (ux * cosA - uy * sinA);
			float ay1 = to.Y - arrowLen * (uy * cosA + ux * sinA);
			float ax2 = to.X - arrowLen * (ux * cosA + uy * sinA);
			float ay2 = to.Y - arrowLen * (uy * cosA - ux * sinA);

			using var brush = new SolidBrush(color);
			using var path = new GraphicsPath();
			path.AddPolygon([
				new System.Drawing.PointF(to.X, to.Y),
				new System.Drawing.PointF(ax1, ay1),
				new System.Drawing.PointF(ax2, ay2)
			]);
			g.FillPath(brush, path);
		}

		#endregion

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
					RecreateTextGraphicsAndResetMeasurer();
					lastMeasureDpi = dpi;
				}
				// Ensure measurer has a valid DC.
				if (textGraphics == null) {
					textGraphics = CreateGraphics();
					textGraphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
					// Text width cache stays valid across normal rebuilds; only reset after DC/DPI changes.
					editorCore.ResetMeasurer();
				}
				perf.Mark(PerfStepRecorder.StepPrep);
			}

			perfMeasureStats.Reset();

			renderModel = editorCore.BuildRenderModel();
			perf.Mark(PerfStepRecorder.StepBuild);
			scrollMetrics = editorCore.GetScrollMetrics();
			hasScrollMetrics = true;
			UpdateScrollbarGeometry();
			perf.Mark(PerfStepRecorder.StepMetrics);
			UpdateCompletionPopupCursorAnchor();
			perf.Mark(PerfStepRecorder.StepAnchor);
			Invalidate();
			perf.Mark(PerfStepRecorder.StepInvalidate);
			perf.Finish();
			LogBuildPerfSummary(perf);
			perfOverlay.RecordBuild(perf, perfMeasureStats.BuildSummary());
		}

		private void UpdateCompletionPopupCursorAnchor() {
			if (completionPopupController == null || renderModel == null) return;
			EditorRenderModel model = (EditorRenderModel)renderModel;
			completionPopupController.UpdateCursorPosition(
				model.Cursor.Position.X,
				model.Cursor.Position.Y,
				model.Cursor.Height);
		}

		/// <summary>Sync platform-side fonts and measurer to the latest scale.</summary>
		private void SyncPlatformScale(float scale) {
			if (scale <= 0f) return;

			float textSize = Math.Max(1f, BaseTextFontSize * scale);
			float inlaySize = Math.Max(1f, BaseInlayHintFontSize * scale);

			regularFont.Dispose();
			boldFont.Dispose();
			italicFont.Dispose();
			boldItalicFont.Dispose();
			inlayHintFont.Dispose();
			inlayHintBoldFont.Dispose();
			inlayHintItalicFont.Dispose();
			inlayHintBoldItalicFont.Dispose();

			regularFont = new Font(BaseTextFontFamily, textSize, FontStyle.Regular);
			boldFont = new Font(BaseTextFontFamily, textSize, FontStyle.Bold);
			italicFont = new Font(BaseTextFontFamily, textSize, FontStyle.Italic);
			boldItalicFont = new Font(BaseTextFontFamily, textSize, FontStyle.Bold | FontStyle.Italic);
			inlayHintFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Regular);
			inlayHintBoldFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Bold);
			inlayHintItalicFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Italic);
			inlayHintBoldItalicFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Bold | FontStyle.Italic);

			Font = regularFont;
			if (editorCore != null) {
				editorCore.ResetMeasurer();
			}
		}

		/// <summary>Recreate text graphics and reset measurer.</summary>
		private void RecreateTextGraphicsAndResetMeasurer() {
			textGraphics?.Dispose();
			textGraphics = CreateGraphics();
			textGraphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
			editorCore.ResetMeasurer();
			// Rebuild is deferred; next model build will use updated DPI.
		}

		private float OnMeasureText(string text, int fontStyle) {
			if (string.IsNullOrEmpty(text)) return 0f;
			long startTicks = PerfScope.StartTicks();
			Font font = GetFontByStyle(fontStyle);
			if (textGraphics == null) return 0f;
			Size sz = TextRenderer.MeasureText(textGraphics, text, font, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags);
			float w = sz.Width;
			// Fallback when measured width is non-positive.
			if (w <= 0)
				w = (float)TextRenderer.MeasureText(textGraphics, text, regularFont, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags).Width;
			perfMeasureStats.RecordText(PerfScope.ElapsedTicks(startTicks), text.Length, fontStyle);
			return w;
		}

		private float OnMeasureInlayHintText(string text) {
			long startTicks = PerfScope.StartTicks();
			if (textGraphics == null) return 0f;
			float width = (float)TextRenderer.MeasureText(textGraphics, text, inlayHintFont, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags).Width;
			perfMeasureStats.RecordInlay(PerfScope.ElapsedTicks(startTicks), text?.Length ?? 0);
			return width;
		}

		private float OnMeasureIconWidth(int iconId) {
			// Default icon is square with width equal to font height.
			long startTicks = PerfScope.StartTicks();
			float width = textGraphics != null
				? regularFont.GetHeight(textGraphics)
				: regularFont.GetHeight();
			perfMeasureStats.RecordIcon(PerfScope.ElapsedTicks(startTicks), iconId);
			return width;
		}

		private void OnGetFontMetrics(IntPtr arrPtr, UIntPtr length) {
			int designAscent = regularFont.FontFamily.GetCellAscent(regularFont.Style);
			int designDescent = regularFont.FontFamily.GetCellDescent(regularFont.Style);
			int designEmHeight = regularFont.FontFamily.GetEmHeight(regularFont.Style);
			float emSizeInPoints = regularFont.SizeInPoints;
			// points -> pixels: px = pt * dpi / 72
			float pixelAscent = designAscent * emSizeInPoints * textGraphics.DpiY / (designEmHeight * 72f);
			float pixelDescent = designDescent * emSizeInPoints * textGraphics.DpiY / (designEmHeight * 72f);
			float[] metrics = [-pixelAscent, pixelDescent];
			Marshal.Copy(metrics, 0, arrPtr, metrics.Length);
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
				perfOverlay.Dispose();
			}
			base.Dispose(disposing);
		}

		#endregion
	}
}
