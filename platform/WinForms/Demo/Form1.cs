using System.Diagnostics;
using System.Text;
using System.Threading;
using SweetEditor;
using SweetLine;
using EditorTextPosition = SweetEditor.TextPosition;
using EditorTextRange = SweetEditor.TextRange;
using DrawingSize = System.Drawing.Size;
using SweetLineLineRange = SweetLine.LineRange;
using SweetLineTextPosition = SweetLine.TextPosition;
using SweetLineTextRange = SweetLine.TextRange;

namespace Demo {
	public partial class Form1 : Form {
		private const int STYLE_COLOR = EditorTheme.STYLE_USER_BASE + 1;
		private const int STYLE_URL = EditorTheme.STYLE_USER_BASE + 2;
		private const string DEFAULT_FILE_NAME = "example.cpp";
		private const int CODELENS_RUN = 1;
		private const int CODELENS_DEBUG = 2;
		private const string FALLBACK_SAMPLE_CODE =
			"// SweetEditor Demo\n" +
			"int main() {\n" +
			"    return 0;\n" +
			"}\n";

		private Label statusLabel = null!;
		private ComboBox fileComboBox = null!;
		private FlowLayoutPanel toolbar = null!;
		private Panel searchPanel = null!;
		private FlowLayoutPanel replaceRow = null!;
		private TextBox searchTextBox = null!;
		private TextBox replaceTextBox = null!;
		private Label searchCounterLabel = null!;
		private CheckBox matchCaseCheckBox = null!;
		private CheckBox wholeWordCheckBox = null!;
		private CheckBox regexCheckBox = null!;
		private bool isDarkTheme = true;
		private WrapMode wrapModePreset = WrapMode.NONE;
		private bool suppressFileSelection;
		private readonly List<string> demoFiles = new();

		private DemoDecorationProvider? demoProvider;
		private DemoCompletionProvider? demoCompletionProvider;

		public Form1() {
			InitializeComponent();
			KeyPreview = true;
			SetupToolbar();
			RegisterColorStyleForCurrentTheme();
			KeyDown += OnDemoKeyDown;

			try {
				DemoDecorationProvider.EnsureSweetLineReady(ResolveSyntaxFiles());
			} catch (Exception ex) {
				throw new InvalidOperationException("Failed to initialize SweetLine syntaxes", ex);
			}

			demoProvider = new DemoDecorationProvider();
			editorControl1.AddDecorationProvider(demoProvider);

			demoCompletionProvider = new DemoCompletionProvider();
			editorControl1.AddCompletionProvider(demoCompletionProvider);
			editorControl1.CodeLensClick += (_, e) =>
				UpdateStatus($"CodeLens {DescribeCodeLensCommand(e.CommandId)} at line {e.Line + 1}");

			editorControl1.Settings.SetCurrentLineRenderMode(CurrentLineRenderMode.BORDER);

			SetupFileSpinner();
		}

		private void SetupToolbar() {
			toolbar = new FlowLayoutPanel {
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
			toolbar.Controls.Add(MakeButton("Search", (_, _) => OpenSearchPanel(false)));
			toolbar.Controls.Add(MakeButton("Replace", (_, _) => OpenSearchPanel(true)));

			statusLabel = new Label {
				AutoSize = true,
				Text = "Ready",
				Padding = new Padding(8, 6, 0, 0)
			};
			toolbar.Controls.Add(statusLabel);

			searchPanel = new Panel {
				Height = 70,
				Visible = false,
				BackColor = toolbar.BackColor
			};
			var searchRow = new FlowLayoutPanel {
				Left = 4,
				Top = 4,
				Height = 30,
				AutoSize = false,
				WrapContents = false,
				FlowDirection = FlowDirection.LeftToRight
			};
			searchRow.Controls.Add(MakeLabel("Search"));
			searchTextBox = new TextBox { Width = 190, Margin = new Padding(2, 2, 2, 0) };
			searchTextBox.TextChanged += (_, _) => PerformSearch();
			searchTextBox.KeyDown += (_, e) => {
				if (e.KeyCode == Keys.Enter) {
					FindNextSearchMatch();
					e.SuppressKeyPress = true;
				}
			};
			searchRow.Controls.Add(searchTextBox);
			searchRow.Controls.Add(MakeButton("\\n", (_, _) => InsertNewlineToken(searchTextBox)));
			searchCounterLabel = MakeLabel("0/0");
			searchCounterLabel.Width = 56;
			searchRow.Controls.Add(searchCounterLabel);
			matchCaseCheckBox = MakeCheckBox("Aa");
			wholeWordCheckBox = MakeCheckBox("Word");
			regexCheckBox = MakeCheckBox(".*");
			searchRow.Controls.Add(matchCaseCheckBox);
			searchRow.Controls.Add(wholeWordCheckBox);
			searchRow.Controls.Add(regexCheckBox);
			searchRow.Controls.Add(MakeButton("Prev", (_, _) => FindPreviousSearchMatch()));
			searchRow.Controls.Add(MakeButton("Next", (_, _) => FindNextSearchMatch()));
			searchRow.Controls.Add(MakeButton("Close", (_, _) => CloseSearchPanel()));

			replaceRow = new FlowLayoutPanel {
				Left = 4,
				Top = 36,
				Height = 30,
				AutoSize = false,
				WrapContents = false,
				FlowDirection = FlowDirection.LeftToRight
			};
			replaceRow.Controls.Add(MakeLabel("Replace"));
			replaceTextBox = new TextBox { Width = 190, Margin = new Padding(2, 2, 2, 0) };
			replaceTextBox.KeyDown += (_, e) => {
				if (e.KeyCode == Keys.Enter) {
					ReplaceCurrentSearchMatch();
					e.SuppressKeyPress = true;
				}
			};
			replaceRow.Controls.Add(replaceTextBox);
			replaceRow.Controls.Add(MakeButton("\\n", (_, _) => InsertNewlineToken(replaceTextBox)));
			replaceRow.Controls.Add(MakeButton("Replace", (_, _) => ReplaceCurrentSearchMatch()));
			replaceRow.Controls.Add(MakeButton("All", (_, _) => ReplaceAllSearchMatches()));
			searchPanel.Controls.Add(searchRow);
			searchPanel.Controls.Add(replaceRow);

			Controls.Add(toolbar);
			Controls.Add(searchPanel);
			LayoutEditorChrome();
		}

		protected override void OnResize(EventArgs e) {
			base.OnResize(e);
			LayoutEditorChrome();
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

		private static Label MakeLabel(string text) {
			return new Label {
				AutoSize = true,
				Text = text,
				Padding = new Padding(4, 6, 2, 0),
				Margin = new Padding(2, 0, 2, 0)
			};
		}

		private CheckBox MakeCheckBox(string text) {
			var checkBox = new CheckBox {
				Text = text,
				AutoSize = true,
				Margin = new Padding(2, 5, 2, 0)
			};
			checkBox.CheckedChanged += (_, _) => PerformSearch();
			return checkBox;
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
			ClearSearchState();
			UpdateStatus($"Loaded: {fileName}");
		}

		private void OpenSearchPanel(bool replaceMode) {
			searchPanel.Visible = true;
			replaceRow.Visible = replaceMode;
			LayoutEditorChrome();
			searchTextBox.Focus();
			searchTextBox.SelectAll();
			if (!string.IsNullOrEmpty(searchTextBox.Text)) {
				PerformSearch();
			}
		}

		private void CloseSearchPanel() {
			ClearSearchState();
			searchPanel.Visible = false;
			LayoutEditorChrome();
			editorControl1.Focus();
		}

		private void ClearSearchState() {
			editorControl1.ClearSearch();
			if (searchCounterLabel != null) {
				searchCounterLabel.Text = "0/0";
			}
		}

		private void PerformSearch() {
			if (searchPanel == null || !searchPanel.Visible) {
				return;
			}
			string pattern = DecodeNewlineTokens(searchTextBox.Text);
			if (string.IsNullOrEmpty(pattern)) {
				ClearSearchState();
				return;
			}
			var options = new SearchOptions {
				CaseSensitive = matchCaseCheckBox.Checked,
				WholeWord = wholeWordCheckBox.Checked,
				UseRegex = regexCheckBox.Checked
			};
			editorControl1.Search(new SearchRequest { Pattern = pattern, Options = options });
			RefreshSearchState();
		}

		private void FindNextSearchMatch() {
			if (string.IsNullOrEmpty(searchTextBox.Text)) return;
			editorControl1.FindNextSearchMatch();
			RefreshSearchState();
		}

		private void FindPreviousSearchMatch() {
			if (string.IsNullOrEmpty(searchTextBox.Text)) return;
			editorControl1.FindPreviousSearchMatch();
			RefreshSearchState();
		}

		private void ReplaceCurrentSearchMatch() {
			if (string.IsNullOrEmpty(searchTextBox.Text)) return;
			SearchState state = editorControl1.GetSearchState();
			if (state.Status == SearchStatus.FAILED || !state.HasCurrentMatch) return;
			editorControl1.ReplaceCurrentSearchMatch(DecodeNewlineTokens(replaceTextBox.Text));
			PerformSearch();
			UpdateStatus("Replace");
		}

		private void ReplaceAllSearchMatches() {
			if (string.IsNullOrEmpty(searchTextBox.Text)) return;
			SearchState state = editorControl1.GetSearchState();
			if (state.Status == SearchStatus.FAILED || state.MatchCount <= 0) return;
			int count = state.MatchCount;
			editorControl1.ReplaceAllSearchMatches(DecodeNewlineTokens(replaceTextBox.Text));
			PerformSearch();
			UpdateStatus($"Replaced {count} matches");
		}

		private void RefreshSearchState() {
			SearchState state = editorControl1.GetSearchState();
			if (state.Status == SearchStatus.FAILED) {
				searchCounterLabel.Text = "Error";
				UpdateStatus(string.IsNullOrEmpty(state.ErrorMessage) ? "Search error" : state.ErrorMessage);
			} else if (state.MatchCount <= 0) {
				searchCounterLabel.Text = "0/0";
				UpdateStatus("No matches");
			} else {
				int current = state.CurrentIndex >= 0 ? state.CurrentIndex + 1 : 0;
				searchCounterLabel.Text = $"{current}/{state.MatchCount}";
				UpdateStatus($"Search {current}/{state.MatchCount}");
			}
		}

		private void OnDemoKeyDown(object? sender, KeyEventArgs e) {
			if (e.Control && e.KeyCode == Keys.F) {
				OpenSearchPanel(false);
				e.SuppressKeyPress = true;
			} else if (e.Control && e.KeyCode == Keys.H) {
				OpenSearchPanel(true);
				e.SuppressKeyPress = true;
			} else if (e.KeyCode == Keys.Escape && searchPanel.Visible) {
				CloseSearchPanel();
				e.SuppressKeyPress = true;
			} else if (e.Shift && e.KeyCode == Keys.Enter && searchPanel.Visible) {
				FindPreviousSearchMatch();
				e.SuppressKeyPress = true;
			}
		}

		private void LayoutEditorChrome() {
			if (toolbar == null || searchPanel == null || editorControl1 == null) return;
			toolbar.Width = ClientSize.Width;
			searchPanel.Top = toolbar.Height;
			searchPanel.Left = 0;
			searchPanel.Width = ClientSize.Width;
			foreach (Control child in searchPanel.Controls) {
				child.Width = Math.Max(0, ClientSize.Width - 8);
			}
			int top = toolbar.Height + (searchPanel.Visible ? searchPanel.Height : 0);
			editorControl1.Top = top;
			editorControl1.Left = 0;
			editorControl1.Size = new DrawingSize(ClientSize.Width, Math.Max(0, ClientSize.Height - top));
		}

		private static void InsertNewlineToken(TextBox textBox) {
			int start = textBox.SelectionStart;
			int length = textBox.SelectionLength;
			textBox.Text = textBox.Text.Remove(start, length).Insert(start, "\\n");
			textBox.SelectionStart = start + 2;
		}

		private static string DecodeNewlineTokens(string text) {
			var builder = new StringBuilder(text.Length);
			for (int i = 0; i < text.Length; i++) {
				char ch = text[i];
				if (ch == '\\' && i + 1 < text.Length) {
					char next = text[i + 1];
					if (next == 'n') {
						builder.Append('\n');
						i++;
						continue;
					}
					if (next == '\\') {
						builder.Append('\\');
						i++;
						continue;
					}
				}
				builder.Append(ch);
			}
			return builder.ToString();
		}

		private void RegisterColorStyleForCurrentTheme() {
			int color = isDarkTheme ? unchecked((int)0xFFB5CEA8) : unchecked((int)0xFF098658);
			int urlColor = isDarkTheme ? unchecked((int)0xFF7DCFFF) : unchecked((int)0xFF005FB8);
			editorControl1.registerTextStyle(STYLE_COLOR, color, 0);
			editorControl1.registerTextStyle(STYLE_URL, urlColor, 0);
		}

		private void UpdateStatus(string message) {
			statusLabel.Text = message;
		}

		private static string DescribeCodeLensCommand(int commandId) {
			return commandId switch {
				CODELENS_RUN => "▶ Run",
				CODELENS_DEBUG => "◎ Debug",
				_ => $"Command#{commandId}",
			};
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
					ApplyReplacementEdits(items, context);
					receiver.Accept(new CompletionResult(items));
				});
			}

			private static void ApplyReplacementEdits(List<CompletionItem> items, CompletionContext context) {
				SweetEditor.TextRange? range = GetIdentifierRange(context);
				if (range == null) {
					return;
				}
				foreach (CompletionItem item in items) {
					item.TextEdit = new SweetEditor.TextEdit(range, item.InsertText ?? item.Label);
				}
			}

			private static SweetEditor.TextRange? GetIdentifierRange(CompletionContext context) {
				SweetEditor.TextRange range = context.WordRange;
				int line = context.CursorPosition.Line;
				int cursorColumn = context.CursorPosition.Column;
				int startColumn = range.Start.Column;
				int endColumn = range.End.Column;
				if (range.Start.Line != line || range.End.Line != line
						|| startColumn < 0 || startColumn >= endColumn
						|| cursorColumn < startColumn || cursorColumn > endColumn
						|| endColumn > context.LineText.Length) {
					return null;
				}
				for (int column = startColumn; column < endColumn; column++) {
					if (!IsWordChar(context.LineText[column])) {
						return null;
					}
				}
				return range;
			}

			private static bool IsWordChar(char ch) =>
				(ch >= 'a' && ch <= 'z')
				|| (ch >= 'A' && ch <= 'Z')
				|| (ch >= '0' && ch <= '9')
				|| ch == '_'
				|| ch > 0x7F;
		}

		private sealed class DemoDecorationProvider : IDecorationProvider {
			private const string DefaultAnalysisFileName = "example.cpp";
			private const int StyleColor = STYLE_COLOR;
			private const int StyleUrl = STYLE_URL;
			private const int IconClass = 1;
			private const int CodeLensRun = CODELENS_RUN;
			private const int CodeLensDebug = CODELENS_DEBUG;
			private const int MaxDynamicDiagnostics = 8;
			private const string PhantomMemberStub =
				"\n    void debugTrace(const std::string& tag) {\n        log(DEBUG, tag);\n    }";
			private const string PhantomInlineHint = " /* demo phantom */";

			private static HighlightEngine? highlightEngine;

			private readonly SemaphoreSlim analysisSemaphore = new(1, 1);
			private readonly object stateLock = new();
			private DocumentAnalyzer? documentAnalyzer;
			private DocumentHighlightSlice? cacheHighlight;
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
				DecorationType.Diagnostic |
				DecorationType.CodeLens |
				DecorationType.Link;

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
				_ = ProduceDecorationsAsync(context, receiver);
			}

			private async Task ProduceDecorationsAsync(DecorationContext context, IDecorationReceiver receiver) {
				bool hasTextChanges = context.TextChanges.Count > 0;
				Dictionary<int, List<Diagnostic>> diagnostics = new();
				DecorationResult? sweetLineResult = null;

				try {
					await analysisSemaphore.WaitAsync().ConfigureAwait(false);
					try {
						if (receiver.IsCancelled && !hasTextChanges) {
							return;
						}

						sweetLineResult = BuildSweetLineDecorationResult(context, diagnostics);
					} finally {
						analysisSemaphore.Release();
					}

					if (receiver.IsCancelled || sweetLineResult == null) {
						return;
					}

					receiver.Accept(sweetLineResult);

					await Task.Delay(500).ConfigureAwait(false);
					if (receiver.IsCancelled) {
						return;
					}

					receiver.Accept(new DecorationResult {
						Diagnostics = diagnostics,
						DiagnosticsMode = DecorationApplyMode.REPLACE_ALL
					});
				} catch {
				}
			}

			private DecorationResult BuildSweetLineDecorationResult(
				DecorationContext context,
				Dictionary<int, List<Diagnostic>> dynamicDiagnostics) {
				var dynamicPhantoms = new Dictionary<int, List<PhantomText>>();
				var syntaxSpans = new Dictionary<int, List<StyleSpan>>();
				var inlayHints = new Dictionary<int, List<InlayHint>>();
				var gutterIcons = new Dictionary<int, List<GutterIcon>>();
				var codeLensItems = new Dictionary<int, List<CodeLensItem>>();
				var links = new Dictionary<int, List<LinkSpan>>();
				var indentGuides = new List<IndentGuide>();
				var foldRegions = new List<FoldRegion>();
				var separatorGuides = new List<SeparatorGuide>();
				var seenColorHints = new HashSet<string>();
				var phantomLines = new HashSet<int>();
				var seenDiagnostics = new HashSet<string>();
				int diagnosticCount = 0;
				TokenRangeInfo? firstKeywordRange = null;

				DocumentAnalyzer? analyzerSnapshot;
				DocumentHighlightSlice? highlightSnapshot;
				string textSnapshot;

				lock (stateLock) {
					if (highlightEngine == null) {
						return new DecorationResult {
							PhantomTexts = dynamicPhantoms,
							PhantomTextsMode = DecorationApplyMode.REPLACE_ALL,
							Links = links,
							LinksMode = DecorationApplyMode.REPLACE_RANGE
						};
					}

					string currentFileName = ResolveCurrentFileName(context);
					if (!string.Equals(currentFileName, sourceFileName, StringComparison.Ordinal)) {
						sourceFileName = currentFileName;
					}
					var visibleRange = new SweetLineLineRange(
						StartLine: Math.Max(0, context.VisibleLineRange.Start),
						LineCount: Math.Max(0, context.VisibleLineRange.End - Math.Max(0, context.VisibleLineRange.Start) + 1));

					if (cacheHighlight == null || documentAnalyzer == null || !string.Equals(currentFileName, analyzedFileName, StringComparison.Ordinal)) {
						documentAnalyzer = null;
						cacheHighlight = null;
						using var sweetDoc = new SweetLine.Document(BuildAnalysisUri(currentFileName), sourceText);
						documentAnalyzer = highlightEngine.LoadDocument(sweetDoc);
						analyzedFileName = currentFileName;
					}

					if (context.TextChanges.Count > 0 && documentAnalyzer != null) {
						foreach (TextChange change in context.TextChanges) {
							string newText = change.NewText;
							cacheHighlight = documentAnalyzer.AnalyzeIncrementalInLineRange(
								ConvertAsSLTextRange(change.Range),
								newText,
								visibleRange);
							sourceText = ApplyTextChange(sourceText, change.Range, newText);
						}
					} else if (documentAnalyzer != null) {
						cacheHighlight = documentAnalyzer.AnalyzeLineRange(visibleRange);
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
						GutterIconsMode = DecorationApplyMode.REPLACE_ALL,
						Links = links,
						LinksMode = DecorationApplyMode.REPLACE_RANGE
					};
				}

				List<string> textLines = SplitLines(textSnapshot);
				foreach (LineHighlight lineHighlight in highlightSnapshot.Lines) {
					if (lineHighlight?.Spans == null) {
						continue;
					}
					foreach (TokenSpan token in lineHighlight.Spans) {
						AppendStyleSpan(syntaxSpans, token);
						AppendColorInlayHint(inlayHints, seenColorHints, textLines, token);
						AppendTextInlayHint(inlayHints, textLines, token);
						AppendSeparator(separatorGuides, textLines, token);
						AppendGutterIcons(gutterIcons, textLines, token);
						AppendCodeLens(codeLensItems, textLines, token);
						AppendLink(links, textLines, token);
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
							indentGuides.Add(new IndentGuide(
								new EditorTextPosition { Line = guide.StartLine, Column = column },
								new EditorTextPosition { Line = guide.EndLine, Column = column }));

							if (guide.EndLine <= guide.StartLine) {
								continue;
							}

							string key = $"{guide.StartLine}:{guide.EndLine}";
							if (seenFolds.Add(key)) {
								foldRegions.Add(new FoldRegion(guide.StartLine, guide.EndLine));
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
					GutterIconsMode = DecorationApplyMode.REPLACE_ALL,
					CodeLensItems = codeLensItems,
					CodeLensItemsMode = DecorationApplyMode.REPLACE_ALL,
					Links = links,
					LinksMode = DecorationApplyMode.REPLACE_RANGE
				};
			}

			private static void RegisterStyleMap(HighlightEngine engine) {
				engine.RegisterStyleName("keyword", EditorTheme.STYLE_KEYWORD);
				engine.RegisterStyleName("type", EditorTheme.STYLE_TYPE);
				engine.RegisterStyleName("string", EditorTheme.STYLE_STRING);
				engine.RegisterStyleName("comment", EditorTheme.STYLE_COMMENT);
				engine.RegisterStyleName("preprocessor", EditorTheme.STYLE_PREPROCESSOR);
				engine.RegisterStyleName("macro", EditorTheme.STYLE_PREPROCESSOR);
				engine.RegisterStyleName("method", EditorTheme.STYLE_FUNCTION);
				engine.RegisterStyleName("function", EditorTheme.STYLE_FUNCTION);
				engine.RegisterStyleName("variable", EditorTheme.STYLE_VARIABLE);
				engine.RegisterStyleName("field", EditorTheme.STYLE_VARIABLE);
				engine.RegisterStyleName("number", EditorTheme.STYLE_NUMBER);
				engine.RegisterStyleName("class", EditorTheme.STYLE_CLASS);
				engine.RegisterStyleName("color", StyleColor);
				engine.RegisterStyleName("url", StyleUrl);
				engine.RegisterStyleName("builtin", EditorTheme.STYLE_BUILTIN);
				engine.RegisterStyleName("annotation", EditorTheme.STYLE_ANNOTATION);
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

			private static void AppendStyleSpan(Dictionary<int, List<StyleSpan>> syntaxSpans, TokenSpan token) {
				if (token.StyleId <= 0) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				GetOrCreate(syntaxSpans, range.Line)
					.Add(new StyleSpan(range.StartColumn, range.Length, token.StyleId));
			}

			private static void AppendColorInlayHint(Dictionary<int, List<InlayHint>> inlayHints,
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
					.Add(InlayHint.ColorHint(range.StartColumn, color.Value));
			}

			private static void AppendTextInlayHint(Dictionary<int, List<InlayHint>> inlayHints,
													List<string> textLines,
													TokenSpan token) {
				if (token.StyleId != EditorTheme.STYLE_KEYWORD) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string literal = GetTokenLiteral(textLines, range);
				List<InlayHint> lineHints = GetOrCreate(inlayHints, range.Line);
				if (literal == "const") {
					lineHints.Add(InlayHint.TextHint(range.EndColumn + 1, "immutable"));
				} else if (literal == "return") {
					lineHints.Add(InlayHint.TextHint(range.EndColumn + 1, "value: "));
				} else if (literal == "case") {
					lineHints.Add(InlayHint.TextHint(range.EndColumn + 1, "condition: "));
				}
			}

			private static void AppendSeparator(List<SeparatorGuide> separatorGuides,
												List<string> textLines,
												TokenSpan token) {
				if (token.StyleId != EditorTheme.STYLE_COMMENT) {
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
						separatorGuides.Add(new SeparatorGuide(
							range.Line,
							isDouble ? SeparatorStyle.DOUBLE : SeparatorStyle.SINGLE,
							count,
							lineText.Length));
					}
			}

			private static void AppendGutterIcons(Dictionary<int, List<GutterIcon>> gutterIcons,
												  List<string> textLines,
												  TokenSpan token) {
				if (token.StyleId != EditorTheme.STYLE_KEYWORD) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string literal = GetTokenLiteral(textLines, range);
				if (literal == "class" || literal == "struct") {
					GetOrCreate(gutterIcons, range.Line).Add(new GutterIcon(IconClass));
				}
			}

			private static void AppendCodeLens(Dictionary<int, List<CodeLensItem>> codeLensItems,
												List<string> textLines,
												TokenSpan token) {
				if (codeLensItems.Count > 0) {
					return;
				}
				if (token.StyleId != EditorTheme.STYLE_KEYWORD) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string literal = GetTokenLiteral(textLines, range);
				if (literal == "class" || literal == "struct") {
					codeLensItems[range.Line] = new List<CodeLensItem> {
						new(range.StartColumn, "▶ Run", CodeLensRun),
						new(range.StartColumn, "◎ Debug", CodeLensDebug)
					};
				}
			}

			private static void AppendLink(Dictionary<int, List<LinkSpan>> links,
										   List<string> textLines,
										   TokenSpan token) {
				if (token.StyleId != StyleUrl) {
					return;
				}
				TokenRangeInfo? range = ExtractSingleLineTokenRange(token);
				if (range == null) {
					return;
				}
				string target = GetTokenLiteral(textLines, range);
				if (string.IsNullOrEmpty(target)) {
					return;
				}
				GetOrCreate(links, range.Line)
					.Add(new LinkSpan(range.StartColumn, range.Length, target));
			}

			private static TokenRangeInfo? AppendDynamicDemoDecorations(
				Dictionary<int, List<PhantomText>> phantoms,
				HashSet<int> phantomLines,
				Dictionary<int, List<Diagnostic>> diagnostics,
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

				if (token.StyleId == EditorTheme.STYLE_KEYWORD) {
					firstKeywordRange ??= range;
					if (phantomLines.Count == 0 && (literal == "class" || literal == "struct")) {
						GetOrCreate(phantoms, range.Line)
							.Add(new PhantomText(range.EndColumn, PhantomMemberStub));
						phantomLines.Add(range.Line);
					} else if (phantomLines.Count == 0 && literal == "return") {
						GetOrCreate(phantoms, range.Line)
							.Add(new PhantomText(range.EndColumn, PhantomInlineHint));
						phantomLines.Add(range.Line);
					}
					return firstKeywordRange;
				}

				if (token.StyleId == EditorTheme.STYLE_COMMENT) {
					int fixmeIndex = literal.IndexOf("FIXME", StringComparison.OrdinalIgnoreCase);
					if (fixmeIndex >= 0) {
						AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
							range.Line, range.StartColumn + fixmeIndex, 5, 0);
					}
					int todoIndex = literal.IndexOf("TODO", StringComparison.OrdinalIgnoreCase);
					if (todoIndex >= 0) {
						AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
							range.Line, range.StartColumn + todoIndex, 4, 1);
					}
					return firstKeywordRange;
				}

				if (token.StyleId == StyleColor) {
					int? color = ParseColorLiteral(literal);
					if (color.HasValue) {
						AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
							range.Line, range.StartColumn, range.Length, 2);
					}
					return firstKeywordRange;
				}

				if (token.StyleId == EditorTheme.STYLE_ANNOTATION) {
					AppendDiagnostic(diagnostics, seenDiagnostics, ref diagnosticCount,
						range.Line, range.StartColumn, range.Length, 3);
				}
				return firstKeywordRange;
			}

			private static void AppendDiagnostic(
				Dictionary<int, List<Diagnostic>> diagnostics,
				HashSet<string> seenDiagnostics,
				ref int diagnosticCount,
				int line,
				int column,
				int length,
				int severity) {
				if (diagnosticCount >= MaxDynamicDiagnostics) {
					return;
				}
				if (line < 0 || column < 0 || length <= 0) {
					return;
				}
				string key = $"{line}:{column}:{length}:{severity}";
				if (!seenDiagnostics.Add(key)) {
					return;
				}
				GetOrCreate(diagnostics, line).Add(new Diagnostic(column, length, severity));
				diagnosticCount++;
			}

			private static void AppendDiagnosticFallbackIfNeeded(
				Dictionary<int, List<Diagnostic>> diagnostics,
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
					3);
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
