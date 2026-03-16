using System.Diagnostics;
using System.Collections.Generic;
using System.Threading.Tasks;
using SweetEditor;

	namespace Demo {
		public partial class Form1 : Form {
		private const string SECTION_BASIC = "//==== Basic Utilities ====";
		private const string SECTION_LEXICAL = "//---- Lexical Analysis ----";
		private const string SECTION_MAIN = "//==== Main Program ====";

		private const string SAMPLE_CODE =
			"// SweetEditor Demo\n" +
			"#include <iostream>\n" +
			"#include <string>\n" +
			"#include <vector>\n" +
			SECTION_BASIC + "\n" +
			"namespace editor {\n" +
			"class Logger {\n" +
			"public:\n" +
			"    enum Level { DEBUG, INFO, WARN, ERROR };\n" +
			"    void log(Level level, const std::string& msg) {\n" +
			"        const char* tags[] = {\"D\", \"I\", \"W\", \"E\"};\n" +
			"        std::cout << \"[\" << tags[level] << \"] \" << msg << std::endl;\n" +
			"    }\n" +
			"};\n" +
			SECTION_LEXICAL + "\n" +
			"struct Token {\n" +
			"    int type;\n" +
			"    size_t start;\n" +
			"    size_t length;\n" +
			"};\n" +
			"std::vector<Token> tokenize(const std::string& line) {\n" +
			"    std::vector<Token> result;\n" +
			"    for (size_t i = 0; i < line.size(); ++i) {\n" +
			"        switch (line[i]) {\n" +
			"            case '#':\n" +
			"                result.push_back({1, i, 1});\n" +
			"                break;\n" +
			"            case '\"':\n" +
			"                result.push_back({2, i, 1});\n" +
			"                break;\n" +
			"            case '/':\n" +
			"                result.push_back({3, i, 1});\n" +
			"                break;\n" +
			"            default:\n" +
			"                result.push_back({0, i, 1});\n" +
			"                break;\n" +
			"        }\n" +
			"    }\n" +
			"    return result;\n" +
			"}\n" +
			"} // namespace editor\n" +
			SECTION_MAIN + "\n" +
			"int main() {\n" +
			"    editor::Logger logger;\n" +
			"    logger.log(editor::Logger::INFO, \"SweetEditor started\");\n" +
			"    auto tokens = editor::tokenize(\"int x = 42;\");\n" +
			"    std::cout << \"Tokens: \" << tokens.size() << std::endl;\n" +
			"    return 0;\n" +
			"}\n";

		private Label statusLabel;
		private bool isDarkTheme = true;
		private WrapMode wrapModePreset = WrapMode.NONE;
		private DemoDecorationProvider? demoProvider;
		private DemoCompletionProvider? demoCompletionProvider;

		public Form1() {
			InitializeComponent();
			SetupToolbar();

			// Auto-load the document and decorations on startup.
			Document doc = new Document(SAMPLE_CODE);
			editorControl1.LoadDocument(doc);
			ApplyAllDecorations();

			// Register DecorationProvider (receiver callback mode).
			demoProvider = new DemoDecorationProvider();
			editorControl1.AddDecorationProvider(demoProvider);

			// Register CompletionProvider (completion callback mode).
			demoCompletionProvider = new DemoCompletionProvider();
			editorControl1.AddCompletionProvider(demoCompletionProvider);

			//editorControl1.SetPerfOverlayEnabled(true);
		}

		private void SetupToolbar() {
			var toolbar = new FlowLayoutPanel {
				Dock = DockStyle.Top,
				Height = 40,
				AutoSize = false,
				WrapContents = false,
				Padding = new Padding(4, 4, 4, 0)
			};

			toolbar.Controls.Add(MakeButton("Undo", (_, _) => { if (editorControl1.CanUndo()) { editorControl1.Undo(); UpdateStatus("Undo"); } }));
			toolbar.Controls.Add(MakeButton("Redo", (_, _) => { if (editorControl1.CanRedo()) { editorControl1.Redo(); UpdateStatus("Redo"); } }));
			toolbar.Controls.Add(MakeButton("Select All", (_, _) => { editorControl1.SelectAll(); UpdateStatus("Select All"); }));
			toolbar.Controls.Add(MakeButton("Get Selection", (_, _) => {
				string sel = editorControl1.GetSelectedText();
				UpdateStatus(string.IsNullOrEmpty(sel) ? "No selection" : $"Selection: {sel[..Math.Min(30, sel.Length)]}");
			}));
			toolbar.Controls.Add(MakeButton("Load Decorations", (_, _) => ApplyAllDecorations()));
			toolbar.Controls.Add(MakeButton("Clear Decorations", (_, _) => {
				editorControl1.ClearAllDecorations(); editorControl1.ClearGuides(); editorControl1.ClearDiagnostics();
				UpdateStatus("Decorations cleared");
			}));
			toolbar.Controls.Add(MakeButton("Toggle Theme", (_, _) => {
				isDarkTheme = !isDarkTheme;
				editorControl1.ApplyTheme(isDarkTheme ? EditorTheme.Dark() : EditorTheme.Light());
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

		private void UpdateStatus(string message) {
			statusLabel.Text = message;
		}

		private void CycleWrapMode() {
			wrapModePreset = (WrapMode)(((int)wrapModePreset + 1) % 3);
			editorControl1.SetWrapMode(wrapModePreset);
			UpdateStatus($"WrapMode: {wrapModePreset}");
		}

		private void ApplyAllDecorations() {
			editorControl1.ClearAllDecorations();
			editorControl1.ClearGuides();
			editorControl1.ClearDiagnostics();
			ApplySyntaxHighlight();
			ApplyInlayHints();
			ApplyGuides();
			ApplyFoldRegions();
			ApplyDiagnostics();
			UpdateStatus("Applied all decorations");
		}

		private void ApplySyntaxHighlight() {
			int SK = 1, ST = 2, SS = 3, SC = 4, SP = 5, SF = 6, SN = 7, SL = 8;

			editorControl1.SetLineSpans(0, new List<StyleSpan> { new(0, 19, SC) });
			editorControl1.SetLineSpans(1, new List<StyleSpan> { new(0, 8, SP), new(9, 10, SS) });
			editorControl1.SetLineSpans(2, new List<StyleSpan> { new(0, 8, SP), new(9, 8, SS) });
			editorControl1.SetLineSpans(3, new List<StyleSpan> { new(0, 8, SP), new(9, 8, SS) });
			editorControl1.SetLineSpans(4, new List<StyleSpan> { new(0, SECTION_BASIC.Length, SC) });
			editorControl1.SetLineSpans(5, new List<StyleSpan> { new(0, 9, SK) });
			editorControl1.SetLineSpans(6, new List<StyleSpan> { new(0, 5, SK), new(6, 6, SL) });
			editorControl1.SetLineSpans(7, new List<StyleSpan> { new(0, 6, SK) });
			editorControl1.SetLineSpans(8, new List<StyleSpan> { new(4, 4, SK), new(9, 5, SL) });
			editorControl1.SetLineSpans(9, new List<StyleSpan> { new(4, 4, SK), new(9, 3, SF), new(13, 5, SL), new(26, 5, SK) });
			editorControl1.SetLineSpans(10, new List<StyleSpan> { new(8, 5, SK), new(14, 4, ST), new(30, 3, SS), new(35, 3, SS), new(40, 3, SS), new(45, 3, SS) });
			editorControl1.SetLineSpans(11, new List<StyleSpan> { new(21, 3, SS), new(43, 4, SS) });
			editorControl1.SetLineSpans(14, new List<StyleSpan> { new(0, SECTION_LEXICAL.Length, SC) });
			editorControl1.SetLineSpans(15, new List<StyleSpan> { new(0, 6, SK), new(7, 5, SL) });
			editorControl1.SetLineSpans(16, new List<StyleSpan> { new(4, 3, ST) });
			editorControl1.SetLineSpans(17, new List<StyleSpan> { new(4, 6, ST) });
			editorControl1.SetLineSpans(18, new List<StyleSpan> { new(4, 6, ST) });
			editorControl1.SetLineSpans(20, new List<StyleSpan> { new(12, 5, SL), new(19, 8, SF), new(28, 5, SK) });
			editorControl1.SetLineSpans(22, new List<StyleSpan> { new(4, 3, SK), new(9, 6, ST), new(20, 1, SN) });
			editorControl1.SetLineSpans(23, new List<StyleSpan> { new(8, 6, SK) });
			editorControl1.SetLineSpans(24, new List<StyleSpan> { new(12, 4, SK), new(17, 3, SS) });
			editorControl1.SetLineSpans(27, new List<StyleSpan> { new(12, 4, SK), new(17, 3, SS) });
			editorControl1.SetLineSpans(30, new List<StyleSpan> { new(12, 4, SK), new(17, 3, SS) });
			editorControl1.SetLineSpans(33, new List<StyleSpan> { new(12, 7, SK) });
			editorControl1.SetLineSpans(25, new List<StyleSpan> { new(34, 1, SN), new(40, 1, SN) });
			editorControl1.SetLineSpans(28, new List<StyleSpan> { new(34, 1, SN), new(40, 1, SN) });
			editorControl1.SetLineSpans(31, new List<StyleSpan> { new(34, 1, SN), new(40, 1, SN) });
			editorControl1.SetLineSpans(34, new List<StyleSpan> { new(34, 1, SN), new(40, 1, SN) });
			foreach (int i in new[] { 26, 29, 32, 35 }) {
				editorControl1.SetLineSpans(i, new List<StyleSpan> { new(16, 5, SK) });
			}
			editorControl1.SetLineSpans(38, new List<StyleSpan> { new(4, 6, SK) });
			editorControl1.SetLineSpans(40, new List<StyleSpan> { new(2, 19, SC) });
			editorControl1.SetLineSpans(41, new List<StyleSpan> { new(0, SECTION_MAIN.Length, SC) });
			editorControl1.SetLineSpans(42, new List<StyleSpan> { new(0, 3, ST), new(4, 4, SF) });
			editorControl1.SetLineSpans(43, new List<StyleSpan> { new(12, 6, SL) });
			editorControl1.SetLineSpans(44, new List<StyleSpan> { new(11, 3, SF), new(23, 6, SL), new(37, 21, SS) });
			editorControl1.SetLineSpans(45, new List<StyleSpan> { new(4, 4, SK), new(26, 8, SF), new(35, 13, SS) });
			editorControl1.SetLineSpans(46, new List<StyleSpan> { new(17, 10, SS) });
			editorControl1.SetLineSpans(47, new List<StyleSpan> { new(4, 6, SK), new(11, 1, SN) });
		}

		private void ApplyInlayHints() {
			editorControl1.SetLineInlayHints(44, new List<InlayHint> {
				InlayHint.TextHint(15, "level: "),
				InlayHint.TextHint(37, "msg: ")
			});
			editorControl1.SetLineInlayHints(45, new List<InlayHint> {
				InlayHint.TextHint(35, "line: ")
			});
			editorControl1.SetLineInlayHints(10, new List<InlayHint> {
				InlayHint.ColorHint(30, unchecked((int)0xFF4CAF50)),
				InlayHint.ColorHint(35, unchecked((int)0xFF2196F3)),
				InlayHint.ColorHint(40, unchecked((int)0xFFFF9800)),
				InlayHint.ColorHint(45, unchecked((int)0xFFF44336))
			});

			editorControl1.SetLinePhantomTexts(13, new List<PhantomText> { new(2, " // end class Logger") });
			editorControl1.SetLinePhantomTexts(39, new List<PhantomText> { new(1, " // end tokenize") });
			editorControl1.SetLinePhantomTexts(48, new List<PhantomText> { new(1, " // end main") });
			editorControl1.SetLinePhantomTexts(12, new List<PhantomText> { new(5, "\n    void warn(const std::string& m) { log(WARN, m); }") });
		}

		private void ApplyGuides() {
			editorControl1.ClearGuides();
			editorControl1.SetIndentGuides(new List<IndentGuide> {
				new(6, 0, 13, 0),
				new(9, 4, 12, 4),
				new(20, 0, 39, 0),
				new(22, 4, 37, 4),
				new(23, 8, 36, 8),
				new(42, 0, 48, 0)
			});

			editorControl1.SetBracketGuides(new List<BracketGuide> {
				new(
					new TextPosition { Line = 23, Column = 8 },
					new TextPosition { Line = 36, Column = 8 },
					new[] {
						new TextPosition { Line = 24, Column = 12 },
						new TextPosition { Line = 27, Column = 12 },
						new TextPosition { Line = 30, Column = 12 },
						new TextPosition { Line = 33, Column = 12 }
					})
			});

			editorControl1.SetFlowGuides(new List<FlowGuide> {
				new(22, 4, 37, 4)
			});

			editorControl1.SetSeparatorGuides(new List<SeparatorGuide> {
				new(4, (int)SeparatorStyle.DOUBLE, 4, SECTION_BASIC.Length),
				new(14, (int)SeparatorStyle.SINGLE, 4, SECTION_LEXICAL.Length),
				new(41, (int)SeparatorStyle.DOUBLE, 4, SECTION_MAIN.Length)
			});
		}

		private void ApplyFoldRegions() {
			editorControl1.SetFoldRegions(new List<FoldRegion> {
				new(6, 13, false), new(9, 12, false), new(15, 19, true),
				new(20, 39, false), new(22, 37, false), new(23, 36, true),
				new(42, 48, false), new(5, 40, false)
			});
		}

		private void ApplyDiagnostics() {
			editorControl1.ClearDiagnostics();
			editorControl1.SetLineDiagnostics(9, new List<DiagnosticItem> { new(13, 5, 0, 0) });
			editorControl1.SetLineDiagnostics(16, new List<DiagnosticItem> { new(8, 4, 1, 0) });
			editorControl1.SetLineDiagnostics(22, new List<DiagnosticItem> { new(4, 3, 3, 0) });
			editorControl1.SetLineDiagnostics(44, new List<DiagnosticItem> { new(38, 20, 2, 0) });
			editorControl1.SetLineDiagnostics(45, new List<DiagnosticItem> { new(4, 4, 1, unchecked((int)0xFFFF8C00)) });
			editorControl1.SetLineDiagnostics(46, new List<DiagnosticItem> { new(17, 10, 2, 0), new(31, 6, 0, 0) });
		}

		private sealed class DemoCompletionProvider : ICompletionProvider {
			private static readonly HashSet<string> TriggerChars = [".", ":"];

			public bool IsTriggerCharacter(string ch) => TriggerChars.Contains(ch);

			public void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver) {
				Debug.WriteLine($"[DemoCompletionProvider] provideCompletions: kind={context.TriggerKind} trigger='{context.TriggerCharacter}' cursor={context.CursorPosition.Line}:{context.CursorPosition.Column}");

				if (context.TriggerKind == CompletionTriggerKind.Character && context.TriggerCharacter == ".") {
					var items = new List<CompletionItem> {
						new() { Label = "length", Detail = "size_t", Kind = CompletionItem.KIND_PROPERTY, InsertText = "length()", SortKey = "a_length" },
						new() { Label = "push_back", Detail = "void push_back(T)", Kind = CompletionItem.KIND_FUNCTION, InsertText = "push_back()", SortKey = "b_push_back" },
						new() { Label = "begin", Detail = "iterator", Kind = CompletionItem.KIND_FUNCTION, InsertText = "begin()", SortKey = "c_begin" },
						new() { Label = "end", Detail = "iterator", Kind = CompletionItem.KIND_FUNCTION, InsertText = "end()", SortKey = "d_end" },
						new() { Label = "size", Detail = "size_t", Kind = CompletionItem.KIND_FUNCTION, InsertText = "size()", SortKey = "e_size" }
					};
					receiver.Accept(new CompletionResult(items));
					Debug.WriteLine($"[DemoCompletionProvider] Sync push: {items.Count} member candidates");
					return;
				}

				Task.Run(async () => {
					await Task.Delay(200);

					if (receiver.IsCancelled) {
						Debug.WriteLine("[DemoCompletionProvider] Async completion cancelled");
						return;
					}

					var items = new List<CompletionItem> {
						new() { Label = "std::string", Detail = "class", Kind = CompletionItem.KIND_CLASS, InsertText = "std::string", SortKey = "a_string" },
						new() { Label = "std::vector", Detail = "template class", Kind = CompletionItem.KIND_CLASS, InsertText = "std::vector<>", SortKey = "b_vector" },
						new() { Label = "std::cout", Detail = "ostream", Kind = CompletionItem.KIND_VARIABLE, InsertText = "std::cout", SortKey = "c_cout" },
						new() { Label = "if", Detail = "snippet", Kind = CompletionItem.KIND_SNIPPET, InsertText = "if (${1:condition}) {\n\t$0\n}", InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET, SortKey = "d_if" },
						new() { Label = "for", Detail = "snippet", Kind = CompletionItem.KIND_SNIPPET, InsertText = "for (int ${1:i} = 0; ${1:i} < ${2:n}; ++${1:i}) {\n\t$0\n}", InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET, SortKey = "e_for" },
						new() { Label = "class", Detail = "snippet — class definition", Kind = CompletionItem.KIND_SNIPPET, InsertText = "class ${1:ClassName} {\npublic:\n\t${1:ClassName}() {$2}\n\t~${1:ClassName}() {$3}\n$0\n};", InsertTextFormat = CompletionItem.INSERT_TEXT_FORMAT_SNIPPET, SortKey = "f_class" },
						new() { Label = "return", Detail = "keyword", Kind = CompletionItem.KIND_KEYWORD, InsertText = "return ", SortKey = "g_return" }
					};
					receiver.Accept(new CompletionResult(items));
					Debug.WriteLine($"[DemoCompletionProvider] Async push: {items.Count} keyword/identifier candidates (delay 200ms)");
				});
			}
		}

		private sealed class DemoDecorationProvider : IDecorationProvider {
			public DecorationType Capabilities =>
				DecorationType.InlayHint | DecorationType.PhantomText | DecorationType.Diagnostic;

			public void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver) {
				Debug.WriteLine($"[DemoProvider] provideDecorations: visible={context.VisibleStartLine}-{context.VisibleEndLine}");

				var hints = new Dictionary<int, List<DecorationResult.InlayHintItem>> {
					[44] = [
						DecorationResult.InlayHintItem.TextHint(15, "level: "),
						DecorationResult.InlayHintItem.TextHint(37, "msg: ")
					],
					[45] = [DecorationResult.InlayHintItem.TextHint(35, "line: ")],
					[10] = [
						DecorationResult.InlayHintItem.ColorHint(30, unchecked((int)0xFF4CAF50)),
						DecorationResult.InlayHintItem.ColorHint(35, unchecked((int)0xFF2196F3)),
						DecorationResult.InlayHintItem.ColorHint(40, unchecked((int)0xFFFF9800)),
						DecorationResult.InlayHintItem.ColorHint(45, unchecked((int)0xFFF44336))
					]
				};

				var phantoms = new Dictionary<int, List<DecorationResult.PhantomTextItem>> {
					[13] = [new(2, " // end class Logger")],
					[39] = [new(1, " // end tokenize")],
					[48] = [new(1, " // end main")]
				};

				receiver.Accept(new DecorationResult {
					InlayHints = hints,
					PhantomTexts = phantoms
				});

				Debug.WriteLine("[DemoProvider] Sync push complete: InlayHint + PhantomText");

				Task.Run(async () => {
					await Task.Delay(500);

					if (receiver.IsCancelled) {
						Debug.WriteLine("[DemoProvider] Async diagnostic cancelled");
						return;
					}

					var diags = new Dictionary<int, List<DecorationResult.DiagnosticItem>> {
						[9] = [new(13, 5, 0, 0)],
						[16] = [new(8, 4, 1, 0)],
						[22] = [new(4, 3, 3, 0)],
						[44] = [new(38, 20, 2, 0)],
						[45] = [new(4, 4, 1, unchecked((int)0xFFFF8C00))],
						[46] = [new(17, 10, 2, 0), new(31, 6, 0, 0)]
					};

					receiver.Accept(new DecorationResult {
						Diagnostics = diags
					});

					Debug.WriteLine("[DemoProvider] Async push complete: Diagnostic (delay 500ms)");
				});
			}
		}
	}
}
