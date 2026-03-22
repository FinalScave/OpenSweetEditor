using System.Diagnostics;
using System.Text;
using SweetEditor;
using SweetLine;
using EditorTextPosition = SweetEditor.TextPosition;
using EditorTextRange = SweetEditor.TextRange;
using SweetLineTextPosition = SweetLine.TextPosition;
using SweetLineTextRange = SweetLine.TextRange;

namespace Demo {
	public partial class Form1 : Form {
		private const int STYLE_COLOR = (int)EditorTheme.STYLE_PREPROCESSOR + 1;
		private const string DEFAULT_FILE_NAME = "example.cpp";
		private const string FALLBACK_SAMPLE_CODE =
			"// SweetEditor Demo\n" +
			"int main() {\n" +
			"    return 0;\n" +
			"}\n";

		private Label statusLabel = null!;
		private ComboBox fileComboBox = null!;
		private bool isDarkTheme = true;
		private WrapMode wrapModePreset = WrapMode.NONE;
		private bool suppressFileSelection;
		private readonly List<string> demoFiles = new();

		private DemoDecorationProvider? demoProvider;
		private DemoCompletionProvider? demoCompletionProvider;

		public Form1() {
			InitializeComponent();
			SetupToolbar();
			RegisterColorStyleForCurrentTheme();

			try {
				DemoDecorationProvider.EnsureSweetLineReady(ResolveSyntaxFiles());
			} catch (Exception ex) {
				throw new InvalidOperationException("Failed to initialize SweetLine syntaxes", ex);
			}

			demoProvider = new DemoDecorationProvider();
			editorControl1.AddDecorationProvider(demoProvider);

			demoCompletionProvider = new DemoCompletionProvider();
			editorControl1.AddCompletionProvider(demoCompletionProvider);

			SetupFileSpinner();
		}

		private void SetupToolbar() {
			var toolbar = new FlowLayoutPanel {
				Dock = DockStyle.Top,
				Height = 40,
				AutoSize = false,
				WrapContents = false,
				Padding = new Padding(4, 4, 4, 0)
			};

			fileComboBox = new ComboBox {
				DropDownStyle = ComboBoxStyle.DropDownList,
				Width = 150,
				Margin = new Padding(2, 0, 2, 0)
			};
			fileComboBox.SelectedIndexChanged += (_, _) => {
				if (suppressFileSelection) {
					return;
				}
				int index = fileComboBox.SelectedIndex;
				if (index < 0 || index >= demoFiles.Count) {
					return;
				}
				LoadDemoFile(demoFiles[index]);
			};

			toolbar.Controls.Add(fileComboBox);
			toolbar.Controls.Add(MakeButton("Undo", (_, _) => {
				if (editorControl1.CanUndo()) {
					editorControl1.Undo();
					UpdateStatus("Undo");
				} else {
					UpdateStatus("Nothing to undo");
				}
			}));
			toolbar.Controls.Add(MakeButton("Redo", (_, _) => {
				if (editorControl1.CanRedo()) {
					editorControl1.Redo();
					UpdateStatus("Redo");
				} else {
					UpdateStatus("Nothing to redo");
				}
			}));
			toolbar.Controls.Add(MakeButton("Toggle Theme", (_, _) => {
				isDarkTheme = !isDarkTheme;
				editorControl1.ApplyTheme(isDarkTheme ? EditorTheme.Dark() : EditorTheme.Light());
				RegisterColorStyleForCurrentTheme();
				UpdateStatus(isDarkTheme ? "Switched to dark theme" : "Switched to light theme");
			}));
			toolbar.Controls.Add(MakeButton("WrapMode", (_, _) => CycleWrapMode()));

			statusLabel = new Label {
				AutoSize = true,
				Text = "Ready",
				Padding = new Padding(8, 6, 0, 0)
			};
			toolbar.Controls.Add(statusLabel);

			Controls.Add(toolbar);
			editorControl1.Top = toolbar.Height;
			editorControl1.Left = 0;
		}

		protected override void OnResize(EventArgs e) {
			base.OnResize(e);
			if (editorControl1 != null) {
				editorControl1.Size = new Size(ClientSize.Width, ClientSize.Height - editorControl1.Top);
			}
		}

		private static Button MakeButton(string text, EventHandler click) {
			var btn = new Button {
				Text = text,
				AutoSize = true,
				Height = 30,
				Margin = new Padding(2, 0, 2, 0)
			};
			btn.Click += click;
			return btn;
		}

		private void SetupFileSpinner() {
			demoFiles.Clear();
			demoFiles.AddRange(ListDemoFiles());

			suppressFileSelection = true;
			fileComboBox.Items.Clear();
			foreach (string file in demoFiles) {
				fileComboBox.Items.Add(Path.GetFileName(file));
			}
			suppressFileSelection = false;

			if (demoFiles.Count == 0) {
				LoadDemoText(DEFAULT_FILE_NAME, FALLBACK_SAMPLE_CODE);
				return;
			}

			fileComboBox.SelectedIndex = 0;
		}

		private void LoadDemoFile(string filePath) {
			try {
				string text = File.ReadAllText(filePath);
				LoadDemoText(Path.GetFileName(filePath), text);
			} catch {
				LoadDemoText(Path.GetFileName(filePath), FALLBACK_SAMPLE_CODE);
			}
		}

		private void LoadDemoText(string fileName, string text) {
			string normalizedText = NormalizeNewlines(text);
			demoProvider?.SetDocumentSource(fileName, normalizedText);
			editorControl1.LoadDocument(new SweetEditor.Document(normalizedText));
			editorControl1.SetMetadata(new DemoFileMetadata(fileName));
			editorControl1.RequestDecorationRefresh();
			if (IsHandleCreated) {
				BeginInvoke((Action)(() => editorControl1.RequestDecorationRefresh()));
			}
			UpdateStatus($"Loaded: {fileName}");
		}

		private void RegisterColorStyleForCurrentTheme() {
			int color = isDarkTheme ? unchecked((int)0xFFB5CEA8) : unchecked((int)0xFF098658);
			editorControl1.registerTextStyle(STYLE_COLOR, color, 0);
		}

		private void UpdateStatus(string message) {
			statusLabel.Text = message;
		}

		private void CycleWrapMode() {
			var wrapModes = Enum.GetValues<WrapMode>();
			wrapModePreset = wrapModes[((int)wrapModePreset + 1) % wrapModes.Length];
			editorControl1.Settings.SetWrapMode(wrapModePreset);
			UpdateStatus($"WrapMode: {wrapModePreset}");
		}

		private static string NormalizeNewlines(string text) {
			return text.Replace("\r\n", "\n").Replace('\r', '\n');
		}

		private static List<string> ListDemoFiles() {
			string? resRoot = ResolveDemoResRoot();
			if (string.IsNullOrEmpty(resRoot)) {
				return new List<string>();
			}
			string filesDir = Path.Combine(resRoot, "files");
			if (!Directory.Exists(filesDir)) {
				return new List<string>();
			}
			return Directory
				.EnumerateFiles(filesDir, "*", SearchOption.TopDirectoryOnly)
				.OrderBy(path => Path.GetFileName(path), StringComparer.OrdinalIgnoreCase)
				.ToList();
		}

		private static List<string> ResolveSyntaxFiles() {
			string? resRoot = ResolveDemoResRoot();
			if (string.IsNullOrEmpty(resRoot)) {
				return new List<string>();
			}
			string syntaxDir = Path.Combine(resRoot, "syntaxes");
			if (!Directory.Exists(syntaxDir)) {
				return new List<string>();
			}
			return Directory
				.EnumerateFiles(syntaxDir, "*.json", SearchOption.AllDirectories)
				.OrderBy(path => Path.GetFileName(path), StringComparer.OrdinalIgnoreCase)
				.ToList();
		}

		private static string? ResolveDemoResRoot() {
			string? envPath = Environment.GetEnvironmentVariable("SWEETEDITOR_DEMO_RES_DIR");
			if (!string.IsNullOrWhiteSpace(envPath) && Directory.Exists(envPath)) {
				return Path.GetFullPath(envPath);
			}

			var starts = new List<string>();
			try {
				starts.Add(AppContext.BaseDirectory);
			} catch {
				// ignore
			}
			try {
				starts.Add(Directory.GetCurrentDirectory());
			} catch {
				// ignore
			}

			foreach (string start in starts) {
				DirectoryInfo? dir = new DirectoryInfo(start);
				while (dir != null) {
					string candidate1 = Path.Combine(dir.FullName, "_res");
					if (Directory.Exists(candidate1)) {
						return candidate1;
					}
					string candidate2 = Path.Combine(dir.FullName, "platform", "_res");
					if (Directory.Exists(candidate2)) {
						return candidate2;
					}
					dir = dir.Parent;
				}
			}

			return null;
		}

		private sealed class DemoCompletionProvider : ICompletionProvider {
			private static readonly HashSet<string> TriggerChars = [".", ":"];

			public bool IsTriggerCharacter(string ch) => TriggerChars.Contains(ch);

			public void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver) {
				if (context.TriggerKind == CompletionTriggerKind.Character && context.TriggerCharacter == ".") {
					var items = new List<CompletionItem> {
						new() { Label = "length", Detail = "size_t", Kind = CompletionItem.KIND_PROPERTY, InsertText = "length()", SortKey = "a_length" },
						new() { Label = "push_back", Detail = "void push_back(T)", Kind = CompletionItem.KIND_FUNCTION, InsertText = "push_back()", SortKey = "b_push_back" },
						new() { Label = "begin", Detail = "iterator", Kind = CompletionItem.KIND_FUNCTION, InsertText = "begin()", SortKey = "c_begin" },
						new() { Label = "end", Detail = "iterator", Kind = CompletionItem.KIND_FUNCTION, InsertText = "end()", SortKey = "d_end" },
						new() { Label = "size", Detail = "size_t", Kind = CompletionItem.KIND_FUNCTION, InsertText = "size()", SortKey = "e_size" }
					};
					receiver.Accept(new CompletionResult(items));
					return;
				}

				Task.Run(async () => {
					await Task.Delay(200);

					if (receiver.IsCancelled) {
						return;
					}

					var items = new List<CompletionItem> {
						new() { Label = "std::string", Detail = "class", Kind = CompletionItem.KIND_CLASS, InsertText = "std::string", SortKey = "a_string" },
						new() { Label = "std::vector", Detail = "template class", Kind = CompletionItem.KIND_CLASS, InsertText = "std::vector<>", SortKey = "b_vector" },
						new() { Label = "std::cout", Detail = "ostream", Kind = CompletionItem.KIND_VARIABLE, InsertText = "std::cout", SortKey = "c_cout" },
						new() { Label = "if", Detail = "snippet", Kind = CompletionItem.KIND_SNIPPET, InsertText = "if (${1:condition}) {\n\t$0\n}", InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET, SortKey = "d_if" },
						new() { Label = "for", Detail = "snippet", Kind = CompletionItem.KIND_SNIPPET, InsertText = "for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n\t$0\n}", InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET, SortKey = "e_for" },
						new() { Label = "class", Detail = "snippet - class definition", Kind = CompletionItem.KIND_SNIPPET, InsertText = "class ${1:ClassName} {\npublic:\n\t${1:ClassName}() {$2}\n\t~${1:ClassName}() {$3}\n$0\n};", InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET, SortKey = "f_class" },
						new() { Label = "return", Detail = "keyword", Kind = CompletionItem.KIND_KEYWORD, InsertText = "return ", SortKey = "g_return" }
					};
					receiver.Accept(new CompletionResult(items));
				});
			}
		}

		private sealed class DemoDecorationProvider : IDecorationProvider {
			private const string DefaultAnalysisFileName = "example.cpp";
			private const int StyleKeyword = (int)EditorTheme.STYLE_KEYWORD;
			private const int StyleComment = (int)EditorTheme.STYLE_COMMENT;
			private const int StyleAnnotation = (int)EditorTheme.STYLE_ANNOTATION;
			private const int StyleColor = STYLE_COLOR;
			private const int IconClass = 1;
			private const int MaxDynamicDiagnostics = 8;
			private const string PhantomMemberStub =
				"\n    void debugTrace(const std::string& tag) {\n        log(DEBUG, tag);\n    }";
			private const string PhantomInlineHint = " /* demo phantom */";

			private static HighlightEngine? highlightEngine;

			private readonly object stateLock = new();
			private DocumentAnalyzer? documentAnalyzer;
			private DocumentHighlight? cacheHighlight;
			private string sourceFileName = DefaultAnalysisFileName;
			private string sourceText = string.Empty;
			private string analyzedFileName = DefaultAnalysisFileName;

			public DecorationType Capabilities =>
				DecorationType.SyntaxHighlight |
				DecorationType.IndentGuide |
				DecorationType.FoldRegion |
				DecorationType.SeparatorGuide |
				DecorationType.GutterIcon |
				DecorationType.InlayHint |
				DecorationType.PhantomText |
				DecorationType.Diagnostic;

			public static bool EnsureSweetLineReady(IReadOnlyList<string> syntaxFiles) {
				if (highlightEngine != null) {
					return true;
				}
				if (syntaxFiles == null || syntaxFiles.Count == 0) {
					throw new InvalidOperationException("No syntax files configured");
				}

				var engine = new HighlightEngine(new HighlightConfig(false, false));
				RegisterStyleMap(engine);

				foreach (string syntaxFile in syntaxFiles) {
					string syntaxJson = File.ReadAllText(syntaxFile);
					try {
						engine.CompileSyntaxFromJson(syntaxJson);
					} catch (SyntaxCompileError ex) {
						throw new InvalidOperationException($"Failed to compile syntax file: {syntaxFile}", ex);
					}
				}

				highlightEngine = engine;
				return true;
			}

			public void SetDocumentSource(string fileName, string text) {
				lock (stateLock) {
					sourceFileName = string.IsNullOrWhiteSpace(fileName) ? DefaultAnalysisFileName : fileName;
					sourceText = text ?? string.Empty;
					documentAnalyzer = null;
					cacheHighlight = null;
					analyzedFileName = sourceFileName;
				}
			}

			public void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver) {
				var diagnostics = new Dictionary<int, List<DecorationResult.DiagnosticItem>>();

				DecorationResult sweetLineResult = BuildSweetLineDecorationResult(context, diagnostics);
				receiver.Accept(sweetLineResult);

				Task.Run(async () => {
					await Task.Delay(500);
					if (receiver.IsCancelled) {
						return;
					}

					receiver.Accept(new DecorationResult {
						Diagnostics = diagnostics,
						DiagnosticsMode = DecorationApplyMode.REPLACE_ALL
					});
				});
			}

			private DecorationResult BuildSweetLineDecorationResult(
				DecorationContext context,
				Dictionary<int, List<DecorationResult.DiagnosticItem>> dynamicDiagnostics) {
				var dynamicPhantoms = new Dictionary<int, List<DecorationResult.PhantomTextItem>>();
				var syntaxSpans = new Dictionary<int, List<DecorationResult.SpanItem>>();
				var inlayHints = new Dictionary<int, List<DecorationResult.InlayHintItem>>();
				var gutterIcons = new Dictionary<int, List<int>>();
				var indentGuides = new List<DecorationResult.IndentGuideItem>();
				var foldRegions = new List<DecorationResult.FoldRegionItem>();
				var separatorGuides = new List<DecorationResult.SeparatorGuideItem>();
				var seenColorHints = new HashSet<string>();
				var phantomLines = new HashSet<int>();
				var seenDiagnostics = new HashSet<string>();
				int diagnosticCount = 0;
				TokenRangeInfo? firstKeywordRange = null;

				DocumentAnalyzer? analyzerSnapshot;
				DocumentHighlight? highlightSnapshot;
				string textSnapshot;

				lock (stateLock) {
					if (highlightEngine == null) {
						return new DecorationResult {
							PhantomTexts = dynamicPhantoms,
							PhantomTextsMode = DecorationApplyMode.REPLACE_ALL
						};
					}

					string currentFileName = ResolveCurrentFileName(context);
					if (!string.Equals(currentFileName, sourceFileName, StringComparison.Ordinal)) {
						sourceFileName = currentFileName;
					}

					if (cacheHighlight == null || documentAnalyzer == null || !string.Equals(currentFileName, analyzedFileName, StringComparison.Ordinal)) {
						using var sweetDoc = new SweetLine.Document(BuildAnalysisUri(currentFileName), sourceText);
						documentAnalyzer = highlightEngine.LoadDocument(sweetDoc);
						cacheHighlight = documentAnalyzer?.Analyze();
						analyzedFileName = currentFileName;
					} else if (context.TextChanges.Count > 0 && documentAnalyzer != null) {
						foreach (TextChange change in context.TextChanges) {
							if (change.Range == null) {
								continue;
							}
							string newText = change.NewText ?? string.Empty;
							cacheHighlight = documentAnalyzer.AnalyzeIncremental(ConvertAsSLTextRange(change.Range.Value), newText);
							sourceText = ApplyTextChange(sourceText, change.Range.Value, newText);
						}
					}

					analyzerSnapshot = documentAnalyzer;
					highlightSnapshot = cacheHighlight;
					textSnapshot = sourceText;
				}

				if (highlightSnapshot?.Lines == null || highlightSnapshot.Lines.Count == 0) {
					return new DecorationResult {
						PhantomTexts = dynamicPhantoms,
						PhantomTextsMode = DecorationApplyMode.REPLACE_ALL,
						SyntaxSpans = syntaxSpans,
						SyntaxSpansMode = DecorationApplyMode.MERGE,
						InlayHints = inlayHints,
						InlayHintsMode = DecorationApplyMode.REPLACE_RANGE,
						IndentGuides = indentGuides,
						IndentGuidesMode = DecorationApplyMode.REPLACE_ALL,
						FoldRegions = foldRegions,
						FoldRegionsMode = DecorationApplyMode.REPLACE_ALL,
						SeparatorGuides = separatorGuides,
						SeparatorGuidesMode = DecorationApplyMode.REPLACE_ALL,
						GutterIcons = gutterIcons,
						GutterIconsMode = DecorationApplyMode.REPLACE_ALL
					};
				}

				List<string> textLines = SplitLines(textSnapshot);
				int renderStartLine = Math.Max(0, context.VisibleStartLine);
				int maxLine = Math.Min(context.VisibleEndLine, highlightSnapshot.Lines.Count - 1);
				for (int i = renderStartLine; i <= maxLine; i++) {
					LineHighlight lineHighlight = highlightSnapshot.Lines[i];
					if (lineHighlight?.Spans == null) {
						continue;
					}
					foreach (TokenSpan token in lineHighlight.Spans) {
						AppendStyleSpan(syntaxSpans, token);
						AppendColorInlayHint(inlayHints, seenColorHints, textLines, token);
						AppendTextInlayHint(inlayHints, textLines, token);
						AppendSeparator(separatorGuides, textLines, token);
						AppendGutterIcons(gutterIcons, textLines, token);
						firstKeywordRange = AppendDynamicDemoDecorations(
							dynamicPhantoms,
							phantomLines,
							dynamicDiagnostics,
							seenDiagnostics,
							ref diagnosticCount,
							firstKeywordRange,
							textLines,
							token);
					}
				}
				AppendDiagnosticFallbackIfNeeded(dynamicDiagnostics, seenDiagnostics, ref diagnosticCount, firstKeywordRange);

				if (analyzerSnapshot != null && (context.TotalLineCount < 0 || context.TotalLineCount < 2048)) {
					IndentGuideResult guideResult = analyzerSnapshot.AnalyzeIndentGuides();
					if (guideResult?.GuideLines != null) {
						var seenFolds = new HashSet<string>();
						foreach (IndentGuideLine guide in guideResult.GuideLines) {
							if (guide == null || guide.EndLine < guide.StartLine) {
								continue;
							}

							int column = Math.Max(guide.Column, 0);
							indentGuides.Add(new DecorationResult.IndentGuideItem(
								new EditorTextPosition { Line = guide.StartLine, Column = column },
								new EditorTextPosition { Line = guide.EndLine, Column = column }));

							if (guide.EndLine <= guide.StartLine) {
								continue;
							}

							string key = $"{guide.StartLine}:{guide.EndLine}";
							if (seenFolds.Add(key)) {
								foldRegions.Add(new DecorationResult.FoldRegionItem(guide.StartLine, guide.EndLine));
							}
						}
					}
				}

				return new DecorationResult {
					PhantomTexts = dynamicPhantoms,
					PhantomTextsMode = DecorationApplyMode.REPLACE_ALL,
					SyntaxSpans = syntaxSpans,
					SyntaxSpansMode = DecorationApplyMode.MERGE,
					InlayHints = inlayHints,
					InlayHintsMode = DecorationApplyMode.REPLACE_RANGE,
					IndentGuides = indentGuides,
					IndentGuidesMode = DecorationApplyMode.REPLACE_ALL,
					FoldRegions = foldRegions,
					FoldRegionsMode = DecorationApplyMode.REPLACE_ALL,
					SeparatorGuides = separatorGuides,
					SeparatorGuidesMode = DecorationApplyMode.REPLACE_ALL,
					GutterIcons = gutterIcons,
					GutterIconsMode = DecorationApplyMode.REPLACE_ALL
				};
			}

			private static void RegisterStyleMap(HighlightEngine engine) {
				engine.RegisterStyleName("keyword", (int)EditorTheme.STYLE_KEYWORD);
				engine.RegisterStyleName("type", (int)EditorTheme.STYLE_TYPE);
				engine.RegisterStyleName("string", (int)EditorTheme.STYLE_STRING);
				engine.RegisterStyleName("comment", (int)EditorTheme.STYLE_COMMENT);
				engine.RegisterStyleName("preprocessor", (int)EditorTheme.STYLE_PREPROCESSOR);
				engine.RegisterStyleName("macro", (int)EditorTheme.STYLE_PREPROCESSOR);
				engine.RegisterStyleName("method", (int)EditorTheme.STYLE_FUNCTION);
				engine.RegisterStyleName("function", (int)EditorTheme.STYLE_FUNCTION);
				engine.RegisterStyleName("variable", (int)EditorTheme.STYLE_VARIABLE);
				engine.RegisterStyleName("field", (int)EditorTheme.STYLE_VARIABLE);
				engine.RegisterStyleName("number", (int)EditorTheme.STYLE_NUMBER);
				engine.RegisterStyleName("class", (int)EditorTheme.STYLE_CLASS);
				engine.RegisterStyleName("color", StyleColor);
				engine.RegisterStyleName("builtin", (int)EditorTheme.STYLE_BUILTIN);
				engine.RegisterStyleName("annotation", (int)EditorTheme.STYLE_ANNOTATION);
			}

			private static string ResolveCurrentFileName(DecorationContext context) {
				if (context.EditorMetadata is DemoFileMetadata fileMetadata &&
					!string.IsNullOrWhiteSpace(fileMetadata.FileName)) {
					return fileMetadata.FileName;
				}
				return DefaultAnalysisFileName;
			}

			private static string BuildAnalysisUri(string fileName) {
				return $"file:///{fileName}";
			}

			private static void AppendStyleSpan(Dictionary<int, List<DecorationResult.SpanItem>> syntaxSpans, TokenSpan token) {
				if (token.StyleId <= 0) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				GetOrCreate(syntaxSpans, range.Line)
					.Add(new DecorationResult.SpanItem(range.StartColumn, range.Length, token.StyleId));
			}

			private static void AppendColorInlayHint(Dictionary<int, List<DecorationResult.InlayHintItem>> inlayHints,
													 HashSet<string> seenHints,
													 List<string> textLines,
													 TokenSpan token) {
				if (token.StyleId != StyleColor) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string literal = GetTokenLiteral(textLines, range);
				int? color = ParseColorLiteral(literal);
				if (color == null) {
					return;
				}
				string key = $"{range.Line}:{range.StartColumn}:{literal}";
				if (!seenHints.Add(key)) {
					return;
				}
				GetOrCreate(inlayHints, range.Line)
					.Add(DecorationResult.InlayHintItem.ColorHint(range.StartColumn, color.Value));
			}

			private static void AppendTextInlayHint(Dictionary<int, List<DecorationResult.InlayHintItem>> inlayHints,
													List<string> textLines,
													TokenSpan token) {
				if (token.StyleId != StyleKeyword) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string literal = GetTokenLiteral(textLines, range);
				List<DecorationResult.InlayHintItem> lineHints = GetOrCreate(inlayHints, range.Line);
				if (literal == "const") {
					lineHints.Add(DecorationResult.InlayHintItem.TextHint(range.EndColumn + 1, "immutable"));
				} else if (literal == "return") {
					lineHints.Add(DecorationResult.InlayHintItem.TextHint(range.EndColumn + 1, "value: "));
				} else if (literal == "case") {
					lineHints.Add(DecorationResult.InlayHintItem.TextHint(range.EndColumn + 1, "condition: "));
				}
			}

			private static void AppendSeparator(List<DecorationResult.SeparatorGuideItem> separatorGuides,
												List<string> textLines,
												TokenSpan token) {
				if (token.StyleId != StyleComment) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string? lineText = GetLineText(textLines, range.Line);
				if (lineText == null || range.EndColumn > lineText.Length) {
					return;
				}
				int count = -1;
				bool isDouble = false;
				for (int i = 0; i < lineText.Length; i++) {
					char ch = lineText[i];
					if (count < 0) {
						if (ch == '/') {
							continue;
						}
						if (ch == '=') {
							count = 1;
							isDouble = true;
						} else if (ch == '-') {
							count = 1;
							isDouble = false;
						}
					} else if (isDouble && ch == '=') {
						count++;
					} else if (!isDouble && ch == '-') {
						count++;
					} else {
						break;
					}
				}
				if (count > 0) {
					separatorGuides.Add(new DecorationResult.SeparatorGuideItem(
						range.Line,
						isDouble ? 1 : 0,
						count,
						lineText.Length));
				}
			}

			private static void AppendGutterIcons(Dictionary<int, List<int>> gutterIcons,
												  List<string> textLines,
												  TokenSpan token) {
				if (token.StyleId != StyleKeyword) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string literal = GetTokenLiteral(textLines, range);
				if (literal == "class" || literal == "struct") {
					GetOrCreate(gutterIcons, range.Line).Add(IconClass);
				}
			}

			private static TokenRangeInfo? AppendDynamicDemoDecorations(
				Dictionary<int, List<DecorationResult.PhantomTextItem>> phantoms,
				HashSet<int> phantomLines,
				Dictionary<int, List<DecorationResult.DiagnosticItem>> diagnostics,
				HashSet<string> seenDiagnostics,
				ref int diagnosticCount,
				TokenRangeInfo? firstKeywordRange,
				List<string> textLines,
				TokenSpan token) {
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return firstKeywordRange;
				}
				string literal = GetTokenLiteral(textLines, range);
				if (string.IsNullOrEmpty(literal)) {
					return firstKeywordRange;
				}

				if (token.StyleId == StyleKeyword) {
					firstKeywordRange ??= range;
					if (phantomLines.Count == 0 && (literal == "class" || literal == "struct")) {
						GetOrCreate(phantoms, range.Line)
							.Add(new DecorationResult.PhantomTextItem(range.EndColumn, PhantomMemberStub));
						phantomLines.Add(range.Line);
					} else if (phantomLines.Count == 0 && literal == "return") {
						GetOrCreate(phantoms, range.Line)
							.Add(new DecorationResult.PhantomTextItem(range.EndColumn, PhantomInlineHint));
						phantomLines.Add(range.Line);
					}
					return firstKeywordRange;
				}

				if (token.StyleId == StyleComment) {
					int fixmeIndex = literal.IndexOf("FIXME", StringComparison.OrdinalIgnoreCase);
					if (fixmeIndex >= 0) {
						AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
							range.Line, range.StartColumn + fixmeIndex, 5, 0, 0);
					}
					int todoIndex = literal.IndexOf("TODO", StringComparison.OrdinalIgnoreCase);
					if (todoIndex >= 0) {
						AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
							range.Line, range.StartColumn + todoIndex, 4, 1, 0);
					}
					return firstKeywordRange;
				}

				if (token.StyleId == StyleColor) {
					int? color = ParseColorLiteral(literal);
					if (color.HasValue) {
						AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
							range.Line, range.StartColumn, range.Length, 2, color.Value);
					}
					return firstKeywordRange;
				}

				if (token.StyleId == StyleAnnotation) {
					AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
						range.Line, range.StartColumn, range.Length, 3, 0);
				}
				return firstKeywordRange;
			}

			private static void AppendDiagnostic(
				Dictionary<int, List<DecorationResult.DiagnosticItem>> diagnostics,
				HashSet<string> seenDiagnostics,
				ref int diagnosticCount,
				int line,
				int column,
				int length,
				int severity,
				int color) {
				if (diagnosticCount >= MaxDynamicDiagnostics) {
					return;
				}
				if (line < 0 || column < 0 || length <= 0) {
					return;
				}
				string key = $"{line}:{column}:{length}:{severity}:{color}";
				if (!seenDiagnostics.Add(key)) {
					return;
				}
				GetOrCreate(diagnostics, line).Add(new DecorationResult.DiagnosticItem(column, length, severity, color));
				diagnosticCount++;
			}

			private static void AppendDiagnosticFallbackIfNeeded(
				Dictionary<int, List<DecorationResult.DiagnosticItem>> diagnostics,
				HashSet<string> seenDiagnostics,
				ref int diagnosticCount,
				TokenRangeInfo? firstKeywordRange) {
				if (diagnosticCount > 0 || firstKeywordRange == null) {
					return;
				}
				AppendDiagnostic(
					diagnostics,
					seenDiagnostics,
					ref diagnosticCount,
					firstKeywordRange.Line,
					firstKeywordRange.StartColumn,
					firstKeywordRange.Length,
					3,
					0);
			}

			private static int? ParseColorLiteral(string literal) {
				if (!literal.StartsWith("0X", StringComparison.Ordinal)) {
					return null;
				}
				try {
					return unchecked((int)Convert.ToUInt32(literal[2..], 16));
				} catch {
					return null;
				}
			}

			private static string GetTokenLiteral(List<string> textLines, TokenRangeInfo range) {
				string? lineText = GetLineText(textLines, range.Line);
				if (lineText == null || range.EndColumn > lineText.Length) {
					return string.Empty;
				}
				return lineText.Substring(range.StartColumn, range.Length);
			}

			private static string? GetLineText(List<string> textLines, int line) {
				if (line < 0 || line >= textLines.Count) {
					return null;
				}
				return textLines[line];
			}

			private static List<string> SplitLines(string text) {
				var lines = new List<string>();
				int start = 0;
				for (int i = 0; i < text.Length; i++) {
					if (text[i] == '\n') {
						string line = text.Substring(start, i - start);
						if (line.EndsWith("\r", StringComparison.Ordinal)) {
							line = line[..^1];
						}
						lines.Add(line);
						start = i + 1;
					}
				}
				string tail = text[start..];
				if (tail.EndsWith("\r", StringComparison.Ordinal)) {
					tail = tail[..^1];
				}
				lines.Add(tail);
				return lines;
			}

			private static TokenRangeInfo? ExtractSingleLineTokenRange(TokenSpan token) {
				int startLine = token.Range.Start.Line;
				int endLine = token.Range.End.Line;
				int startColumn = token.Range.Start.Column;
				int endColumn = token.Range.End.Column;
				if (startLine < 0 || startLine != endLine || startColumn < 0 || endColumn <= startColumn) {
					return null;
				}
				return new TokenRangeInfo(startLine, startColumn, endColumn);
			}

			private static string ApplyTextChange(string originalText, EditorTextRange range, string newText) {
				int startOffset = LineColumnToOffset(originalText, range.Start.Line, range.Start.Column);
				int endOffset = LineColumnToOffset(originalText, range.End.Line, range.End.Column);
				if (startOffset > endOffset) {
					(startOffset, endOffset) = (endOffset, startOffset);
				}
				var builder = new StringBuilder(Math.Max(0, originalText.Length - (endOffset - startOffset)) + newText.Length);
				builder.Append(originalText, 0, startOffset);
				builder.Append(newText);
				builder.Append(originalText, endOffset, originalText.Length - endOffset);
				return builder.ToString();
			}

			private static int LineColumnToOffset(string text, int targetLine, int targetColumn) {
				int line = 0;
				int index = 0;

				while (index < text.Length && line < Math.Max(0, targetLine)) {
					char ch = text[index++];
					if (ch == '\n') {
						line++;
					}
				}

				int column = 0;
				while (index < text.Length && column < Math.Max(0, targetColumn)) {
					char ch = text[index];
					if (ch == '\n') {
						break;
					}
					index++;
					column++;
				}
				return index;
			}

			private static SweetLineTextRange ConvertAsSLTextRange(EditorTextRange range) {
				return new SweetLineTextRange(
					new SweetLineTextPosition(range.Start.Line, range.Start.Column, 0),
					new SweetLineTextPosition(range.End.Line, range.End.Column, 0));
			}

			private static List<T> GetOrCreate<T>(Dictionary<int, List<T>> map, int line) {
				if (!map.TryGetValue(line, out List<T>? list)) {
					list = new List<T>();
					map[line] = list;
				}
				return list;
			}

			private sealed class TokenRangeInfo {
				public int Line { get; }
				public int StartColumn { get; }
				public int EndColumn { get; }
				public int Length => EndColumn - StartColumn;

				public TokenRangeInfo(int line, int startColumn, int endColumn) {
					Line = line;
					StartColumn = startColumn;
					EndColumn = endColumn;
				}
			}
		}

		private sealed class DemoFileMetadata : IEditorMetadata {
			public string FileName { get; }

			public DemoFileMetadata(string fileName) {
				FileName = fileName;
			}
		}
	}
}

