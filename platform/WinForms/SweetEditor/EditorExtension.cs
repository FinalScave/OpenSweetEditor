using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

namespace SweetEditor {

	/// <summary>Completion item data model. Apply priority on confirm: TextEdit -> InsertText -> Label.</summary>
	public class CompletionItem {
		/// <summary>Precise replacement edit (explicit replacement range + new text).</summary>
		public class TextEdit {
			public TextRange Range { get; }
			public string NewText { get; }
			public TextEdit(TextRange range, string newText) { Range = range; NewText = newText; }
		}

		public string Label { get; set; }
		public string? Detail { get; set; }
		public int IconId { get; set; }
		public string? InsertText { get; set; }
		/// <summary>Insert text format: INSERT_TEXT_FORMAT_PLAIN_TEXT or INSERT_TEXT_FORMAT_SNIPPET.</summary>
		public int InsertTextFormat { get; set; } = INSERT_TEXT_FORMAT_PLAIN_TEXT;
		public TextEdit? TextEditValue { get; set; }
		public string? FilterText { get; set; }
		public string? SortKey { get; set; }
		public int Kind { get; set; }

		public string MatchText => FilterText ?? Label;

		public const int KIND_KEYWORD = 0;
		public const int KIND_FUNCTION = 1;
		public const int KIND_VARIABLE = 2;
		public const int KIND_CLASS = 3;
		public const int KIND_INTERFACE = 4;
		public const int KIND_MODULE = 5;
		public const int KIND_PROPERTY = 6;
		public const int KIND_SNIPPET = 7;
		public const int KIND_TEXT = 8;

		/// <summary>Plain text format (default).</summary>
		public const int INSERT_TEXT_FORMAT_PLAIN_TEXT = 1;
		/// <summary>VSCode Snippet format (supports placeholders like $1, ${1:default}, and $0).</summary>
		public const int INSERT_TEXT_FORMAT_SNIPPET = 2;

		public override string ToString() => $"CompletionItem{{label='{Label}', kind={Kind}}}";
	}

	/// <summary>Completion trigger kind.</summary>
	public enum CompletionTriggerKind { Invoked, Character, Retrigger }

	/// <summary>Completion context.</summary>
	public class CompletionContext {
		public CompletionTriggerKind TriggerKind { get; }
		public string? TriggerCharacter { get; }
		public TextPosition CursorPosition { get; }
		public string LineText { get; }
		public TextRange? WordRange { get; }
		/// <summary>Current language configuration (from LanguageConfiguration).</summary>
		public LanguageConfiguration? LanguageConfiguration { get; }

		public CompletionContext(CompletionTriggerKind triggerKind, string? triggerCharacter,
								 TextPosition cursorPosition, string lineText, TextRange? wordRange,
								 LanguageConfiguration? languageConfiguration = null) {
			TriggerKind = triggerKind;
			TriggerCharacter = triggerCharacter;
			CursorPosition = cursorPosition;
			LineText = lineText;
			WordRange = wordRange;
			LanguageConfiguration = languageConfiguration;
		}
	}

	/// <summary>Provider result.</summary>
	public class CompletionResult {
		public List<CompletionItem> Items { get; }
		public bool IsIncomplete { get; }
		public CompletionResult(List<CompletionItem> items, bool isIncomplete = false) {
			Items = items;
			IsIncomplete = isIncomplete;
		}
	}

	/// <summary>Asynchronous callback interface.</summary>
	public interface ICompletionReceiver {
		bool Accept(CompletionResult result);
		bool IsCancelled { get; }
	}

	/// <summary>Completion provider interface.</summary>
	public interface ICompletionProvider {
		bool IsTriggerCharacter(string ch);
		void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver);
	}

	/// <summary>Custom completion item renderer delegate interface.</summary>
	public interface ICompletionItemRenderer {
		void DrawItem(System.Drawing.Graphics g, System.Drawing.Rectangle bounds, CompletionItem item, bool isSelected);
		int ItemHeight { get; }
	}

	/// <summary>Completion provider manager.</summary>
	internal sealed class CompletionProviderManager {

		public delegate void CompletionItemsUpdatedHandler(List<CompletionItem> items);
		public delegate void CompletionDismissedHandler();

		public event CompletionItemsUpdatedHandler? OnItemsUpdated;
		public event CompletionDismissedHandler? OnDismissed;

		private readonly List<ICompletionProvider> providers = new();
		private readonly Dictionary<ICompletionProvider, ManagedReceiver> activeReceivers = new();
		private readonly EditorControl editor;
		private readonly System.Windows.Forms.Timer debounceTimer;

		private int generation;
		private readonly List<CompletionItem> mergedItems = new();
		private CompletionTriggerKind lastTriggerKind;
		private string? lastTriggerChar;

		public CompletionProviderManager(EditorControl editor) {
			this.editor = editor;
			debounceTimer = new System.Windows.Forms.Timer { Interval = 50 };
			debounceTimer.Tick += (_, _) => { debounceTimer.Stop(); ExecuteRefresh(lastTriggerKind, lastTriggerChar); };
		}

		public void AddProvider(ICompletionProvider provider) {
			if (!providers.Contains(provider)) providers.Add(provider);
		}

		public void RemoveProvider(ICompletionProvider provider) {
			providers.Remove(provider);
			if (activeReceivers.TryGetValue(provider, out var receiver)) {
				receiver.Cancel();
				activeReceivers.Remove(provider);
			}
		}

		public void TriggerCompletion(CompletionTriggerKind kind, string? triggerChar) {
			if (providers.Count == 0) return;
			lastTriggerKind = kind;
			lastTriggerChar = triggerChar;
			debounceTimer.Stop();
			int delay = kind == CompletionTriggerKind.Invoked ? 0 : 50;
			debounceTimer.Interval = Math.Max(delay, 1);
			debounceTimer.Start();
		}

		public void Dismiss() {
			debounceTimer.Stop();
			generation++;
			CancelAllReceivers();
			mergedItems.Clear();
			OnDismissed?.Invoke();
		}

		public bool IsTriggerCharacter(string ch) {
			foreach (var p in providers) {
				if (p.IsTriggerCharacter(ch)) return true;
			}
			return false;
		}

		public void ShowItems(List<CompletionItem> items) {
			debounceTimer.Stop();
			generation++;
			CancelAllReceivers();
			mergedItems.Clear();
			mergedItems.AddRange(items);
			OnItemsUpdated?.Invoke(new List<CompletionItem>(mergedItems));
		}

		private void ExecuteRefresh(CompletionTriggerKind kind, string? triggerChar) {
			int currentGen = ++generation;
			CancelAllReceivers();
			mergedItems.Clear();

			var context = BuildContext(kind, triggerChar);
			if (context == null) { Dismiss(); return; }

			foreach (var provider in providers) {
				var receiver = new ManagedReceiver(this, provider, currentGen);
				activeReceivers[provider] = receiver;
				try { provider.ProvideCompletions(context, receiver); } catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"CompletionProvider error: {ex.Message}"); }
			}
		}

		private void CancelAllReceivers() {
			foreach (var r in activeReceivers.Values) r.Cancel();
			activeReceivers.Clear();
		}

		private CompletionContext? BuildContext(CompletionTriggerKind kind, string? triggerChar) {
			var cursor = editor.GetCursorPosition();
			var doc = editor.GetDocument();
			string lineText = doc?.GetLineText(cursor.Line) ?? "";
			var wordRange = editor.GetWordRangeAtCursor();
			return new CompletionContext(kind, triggerChar, cursor, lineText, wordRange, editor.GetLanguageConfiguration());
		}

		private void OnReceiverAccept(ICompletionProvider provider, CompletionResult result, int receiverGen) {
			if (receiverGen != generation) return;
			mergedItems.AddRange(result.Items);
			mergedItems.Sort((a, b) => string.Compare(a.SortKey ?? a.Label, b.SortKey ?? b.Label, StringComparison.Ordinal));
			if (mergedItems.Count == 0) {
				OnDismissed?.Invoke();
			} else {
				OnItemsUpdated?.Invoke(new List<CompletionItem>(mergedItems));
			}
		}

		private sealed class ManagedReceiver : ICompletionReceiver {
			private readonly CompletionProviderManager manager;
			private readonly ICompletionProvider provider;
			private readonly int receiverGeneration;
			private bool cancelled;

			public ManagedReceiver(CompletionProviderManager manager, ICompletionProvider provider, int receiverGeneration) {
				this.manager = manager;
				this.provider = provider;
				this.receiverGeneration = receiverGeneration;
			}

			public void Cancel() => cancelled = true;

			public bool Accept(CompletionResult result) {
				if (cancelled || receiverGeneration != manager.generation) return false;
				if (manager.editor != null) {
					// Marshal to UI thread
					manager.editor.BeginInvoke(new Action(() => {
						if (cancelled || receiverGeneration != manager.generation) return;
						manager.OnReceiverAccept(provider, result, receiverGeneration);
					}));
				}
				return true;
			}

			public bool IsCancelled => cancelled || receiverGeneration != manager.generation;
		}
	}

	[Flags]
	public enum DecorationType {
		SyntaxHighlight = 1 << 0,
		SemanticHighlight = 1 << 1,
		InlayHint = 1 << 2,
		Diagnostic = 1 << 3,
		FoldRegion = 1 << 4,
		IndentGuide = 1 << 5,
		BracketGuide = 1 << 6,
		FlowGuide = 1 << 7,
		SeparatorGuide = 1 << 8,
		GutterIcon = 1 << 9,
		PhantomText = 1 << 10,
	}

	public sealed class DecorationContext {
		public int VisibleStartLine { get; }
		public int VisibleEndLine { get; }
		public int TotalLineCount { get; }
		/// <summary>All text changes accumulated in this refresh cycle (read-only). An empty list means the refresh was triggered by a non-text change.</summary>
		public IReadOnlyList<TextChange> TextChanges { get; }
		/// <summary>Current language configuration (from LanguageConfiguration).</summary>
		public LanguageConfiguration? LanguageConfiguration { get; }

		public DecorationContext(int visibleStartLine, int visibleEndLine, int totalLineCount,
								 IReadOnlyList<TextChange> textChanges, LanguageConfiguration? languageConfiguration = null) {
			VisibleStartLine = visibleStartLine;
			VisibleEndLine = visibleEndLine;
			TotalLineCount = totalLineCount;
			TextChanges = textChanges;
			LanguageConfiguration = languageConfiguration;
		}
	}

	public interface IDecorationReceiver {
		bool Accept(DecorationResult result);
		bool IsCancelled { get; }
	}

	public interface IDecorationProvider {
		DecorationType Capabilities { get; }
		void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver);
	}

	public sealed class DecorationResult {
		public Dictionary<int, List<SpanItem>>? SyntaxSpans { get; set; }
		public Dictionary<int, List<SpanItem>>? SemanticSpans { get; set; }
		public Dictionary<int, List<InlayHintItem>>? InlayHints { get; set; }
		public Dictionary<int, List<DiagnosticItem>>? Diagnostics { get; set; }
		public List<IndentGuideItem>? IndentGuides { get; set; }
		public List<BracketGuideItem>? BracketGuides { get; set; }
		public List<FlowGuideItem>? FlowGuides { get; set; }
		public List<SeparatorGuideItem>? SeparatorGuides { get; set; }
		public List<FoldRegionItem>? FoldRegions { get; set; }
		public Dictionary<int, List<int>>? GutterIcons { get; set; }
		public Dictionary<int, List<PhantomTextItem>>? PhantomTexts { get; set; }

		public DecorationResult Clone() {
			return new DecorationResult {
				SyntaxSpans = CopyMap(SyntaxSpans),
				SemanticSpans = CopyMap(SemanticSpans),
				InlayHints = CopyMap(InlayHints),
				Diagnostics = CopyMap(Diagnostics),
				IndentGuides = IndentGuides == null ? null : new List<IndentGuideItem>(IndentGuides),
				BracketGuides = BracketGuides == null ? null : new List<BracketGuideItem>(BracketGuides),
				FlowGuides = FlowGuides == null ? null : new List<FlowGuideItem>(FlowGuides),
				SeparatorGuides = SeparatorGuides == null ? null : new List<SeparatorGuideItem>(SeparatorGuides),
				FoldRegions = FoldRegions == null ? null : new List<FoldRegionItem>(FoldRegions),
				GutterIcons = CopyMap(GutterIcons),
				PhantomTexts = CopyMap(PhantomTexts),
			};
		}

		private static Dictionary<int, List<T>>? CopyMap<T>(Dictionary<int, List<T>>? source) {
			if (source == null) return null;
			var outMap = new Dictionary<int, List<T>>(source.Count);
			foreach (var kv in source) {
				outMap[kv.Key] = kv.Value == null ? new List<T>() : new List<T>(kv.Value);
			}
			return outMap;
		}

		public sealed record SpanItem(int Column, int Length, int StyleId);
		public sealed record DiagnosticItem(int Column, int Length, int Severity, int Color);
		public sealed record FoldRegionItem(int StartLine, int EndLine, bool Collapsed);
		public sealed record IndentGuideItem(TextPosition Start, TextPosition End);
		public sealed record BracketGuideItem(TextPosition Parent, TextPosition End, TextPosition[]? Children);
		public sealed record FlowGuideItem(TextPosition Start, TextPosition End);
		public sealed record SeparatorGuideItem(int Line, int Style, int Count, int TextEndColumn);
		public sealed record PhantomTextItem(int Column, string Text);

		public sealed record InlayHintItem(int Column, InlayHintType Type, string? Text, int IntValue) {
			public static InlayHintItem TextHint(int column, string text) => new(column, InlayHintType.Text, text, 0);
			public static InlayHintItem IconHint(int column, int iconId) => new(column, InlayHintType.Icon, null, iconId);
			public static InlayHintItem ColorHint(int column, int color) => new(column, InlayHintType.Color, null, color);
		}

		public enum InlayHintType {
			Text = 0,
			Icon = 1,
			Color = 2,
		}
	}

	internal sealed class DecorationProviderManager {
		private readonly EditorControl editor;
		private readonly List<IDecorationProvider> providers = new();
		private readonly Dictionary<IDecorationProvider, ProviderState> states = new();
		private readonly System.Windows.Forms.Timer debounceTimer;

		private readonly List<TextChange> pendingTextChanges = new();
		private bool applyScheduled;
		private int generation;

		public DecorationProviderManager(EditorControl editor) {
			this.editor = editor;
			debounceTimer = new System.Windows.Forms.Timer { Interval = 50 };
			debounceTimer.Tick += (_, _) => {
				debounceTimer.Stop();
				DoRefresh();
			};
		}

		public void AddProvider(IDecorationProvider provider) {
			if (providers.Contains(provider)) return;
			providers.Add(provider);
			states[provider] = new ProviderState();
			RequestRefresh();
		}

		public void RemoveProvider(IDecorationProvider provider) {
			providers.Remove(provider);
			if (states.TryGetValue(provider, out var st) && st.ActiveReceiver != null) {
				st.ActiveReceiver.Cancel();
			}
			states.Remove(provider);
			ScheduleApply();
		}

		public void RequestRefresh() => ScheduleRefresh(0, null);
		public void OnDocumentLoaded() => ScheduleRefresh(0, null);
		public void OnScrollChanged() => ScheduleRefresh(50, null);
		public void OnTextChanged(List<TextChange>? changes) => ScheduleRefresh(50, changes);

		private void ScheduleRefresh(int delayMs, List<TextChange>? changes) {
			if (changes != null) {
				pendingTextChanges.AddRange(changes);
			}
			debounceTimer.Stop();
			debounceTimer.Interval = Math.Max(1, delayMs == 0 ? 1 : delayMs);
			debounceTimer.Start();
		}

		private void DoRefresh() {
			generation++;
			int currentGeneration = generation;

			var visible = editor.GetVisibleLineRange();
			var changes = new List<TextChange>(pendingTextChanges).AsReadOnly();
			pendingTextChanges.Clear();
			var context = new DecorationContext(visible.start, visible.end, editor.GetTotalLineCount(), changes, editor.GetLanguageConfiguration());

			foreach (var provider in providers) {
				if (!states.TryGetValue(provider, out var state)) {
					state = new ProviderState();
					states[provider] = state;
				}
				state.ActiveReceiver?.Cancel();
				var receiver = new ManagedReceiver(this, provider, currentGeneration);
				state.ActiveReceiver = receiver;
				try {
					provider.ProvideDecorations(context, receiver);
				} catch {
				}
			}
		}

		private void ScheduleApply() {
			if (applyScheduled) return;
			applyScheduled = true;
			editor.BeginInvoke(new Action(ApplyMerged));
		}

		private void ApplyMerged() {
			applyScheduled = false;

			var syntaxSpans = new Dictionary<int, List<DecorationResult.SpanItem>>();
			var semanticSpans = new Dictionary<int, List<DecorationResult.SpanItem>>();
			var inlayHints = new Dictionary<int, List<DecorationResult.InlayHintItem>>();
			var diagnostics = new Dictionary<int, List<DecorationResult.DiagnosticItem>>();
			List<DecorationResult.IndentGuideItem>? indentGuides = null;
			List<DecorationResult.BracketGuideItem>? bracketGuides = null;
			List<DecorationResult.FlowGuideItem>? flowGuides = null;
			List<DecorationResult.SeparatorGuideItem>? separatorGuides = null;
			var foldRegions = new List<DecorationResult.FoldRegionItem>();
			var gutterIcons = new Dictionary<int, List<int>>();
			var phantomTexts = new Dictionary<int, List<DecorationResult.PhantomTextItem>>();

			foreach (var provider in providers) {
				if (!states.TryGetValue(provider, out var st) || st.Snapshot == null) continue;
				var r = st.Snapshot;
				AppendMap(syntaxSpans, r.SyntaxSpans);
				AppendMap(semanticSpans, r.SemanticSpans);
				AppendMap(inlayHints, r.InlayHints);
				AppendMap(diagnostics, r.Diagnostics);
				AppendMap(gutterIcons, r.GutterIcons);
				AppendMap(phantomTexts, r.PhantomTexts);

				if (r.IndentGuides != null) indentGuides = new List<DecorationResult.IndentGuideItem>(r.IndentGuides);
				if (r.BracketGuides != null) bracketGuides = new List<DecorationResult.BracketGuideItem>(r.BracketGuides);
				if (r.FlowGuides != null) flowGuides = new List<DecorationResult.FlowGuideItem>(r.FlowGuides);
				if (r.SeparatorGuides != null) separatorGuides = new List<DecorationResult.SeparatorGuideItem>(r.SeparatorGuides);
				if (r.FoldRegions != null) foldRegions.AddRange(r.FoldRegions);
			}

			editor.ClearHighlights();
			ApplySpans(syntaxSpans, SpanLayer.SYNTAX);
			ApplySpans(semanticSpans, SpanLayer.SEMANTIC);

			editor.ClearInlayHints();
			foreach (var (line, items) in inlayHints) {
				var hints = new List<InlayHint>(items.Count);
				foreach (var item in items) {
					switch (item.Type) {
						case DecorationResult.InlayHintType.Text when item.Text != null:
							hints.Add(InlayHint.TextHint(item.Column, item.Text));
							break;
						case DecorationResult.InlayHintType.Icon:
							hints.Add(InlayHint.IconHint(item.Column, item.IntValue));
							break;
						case DecorationResult.InlayHintType.Color:
							hints.Add(InlayHint.ColorHint(item.Column, item.IntValue));
							break;
					}
				}
				editor.SetLineInlayHints(line, hints);
			}

			editor.ClearDiagnostics();
			foreach (var (line, items) in diagnostics) {
				var diagItems = new List<DiagnosticItem>(items.Count);
				for (int i = 0; i < items.Count; i++) {
					diagItems.Add(new DiagnosticItem(items[i].Column, items[i].Length, items[i].Severity, items[i].Color));
				}
				editor.SetLineDiagnostics(line, diagItems);
			}

			editor.ClearGuides();
			if (indentGuides != null) {
				var guides = new List<IndentGuide>(indentGuides.Count);
				foreach (var item in indentGuides) guides.Add(new IndentGuide(item.Start, item.End));
				editor.SetIndentGuides(guides);
			}
			if (bracketGuides != null) {
				var guides = new List<BracketGuide>(bracketGuides.Count);
				foreach (var item in bracketGuides) guides.Add(new BracketGuide(item.Parent, item.End, item.Children));
				editor.SetBracketGuides(guides);
			}
			if (flowGuides != null) {
				var guides = new List<FlowGuide>(flowGuides.Count);
				foreach (var item in flowGuides) guides.Add(new FlowGuide(item.Start, item.End));
				editor.SetFlowGuides(guides);
			}
			if (separatorGuides != null) {
				var guides = new List<SeparatorGuide>(separatorGuides.Count);
				foreach (var item in separatorGuides) {
					guides.Add(new SeparatorGuide(item.Line, item.Style, item.Count, item.TextEndColumn));
				}
				editor.SetSeparatorGuides(guides);
			}

			if (foldRegions.Count > 0) {
				var regions = new List<FoldRegion>(foldRegions.Count);
				for (int i = 0; i < foldRegions.Count; i++) {
					var r = foldRegions[i];
					regions.Add(new FoldRegion(r.StartLine, r.EndLine, r.Collapsed));
				}
				editor.SetFoldRegions(regions);
			}

			editor.ClearGutterIcons();
			foreach (var (line, icons) in gutterIcons) {
				var iconList = new List<GutterIcon>(icons.Count);
				foreach (var icon in icons) iconList.Add(new GutterIcon(icon));
				editor.SetLineGutterIcons(line, iconList);
			}

			editor.ClearPhantomTexts();
			foreach (var (line, items) in phantomTexts) {
				var phantomList = new List<PhantomText>(items.Count);
				foreach (var item in items) phantomList.Add(new PhantomText(item.Column, item.Text));
				editor.SetLinePhantomTexts(line, phantomList);
			}

			editor.Flush();
		}

		private void ApplySpans(Dictionary<int, List<DecorationResult.SpanItem>> map, SpanLayer layer) {
			foreach (var (line, spans) in map) {
				var styleSpans = new List<StyleSpan>(spans.Count);
				for (int i = 0; i < spans.Count; i++) {
					styleSpans.Add(new StyleSpan(spans[i].Column, spans[i].Length, spans[i].StyleId));
				}
				editor.SetLineSpans(line, layer, styleSpans);
			}
		}

		private static void AppendMap<T>(Dictionary<int, List<T>> target, Dictionary<int, List<T>>? source) {
			if (source == null) return;
			foreach (var (line, list) in source) {
				if (!target.TryGetValue(line, out var dst)) {
					dst = new List<T>();
					target[line] = dst;
				}
				if (list != null) dst.AddRange(list);
			}
		}

		private void OnReceiverAccept(IDecorationProvider provider, int receiverGeneration, DecorationResult result) {
			if (receiverGeneration != generation) return;
			if (!states.TryGetValue(provider, out var state)) {
				state = new ProviderState();
				states[provider] = state;
			}
			if (state.Snapshot == null) state.Snapshot = new DecorationResult();
			MergePatch(state.Snapshot, result);
			ScheduleApply();
		}

		private static void MergePatch(DecorationResult target, DecorationResult patch) {
			if (patch.SyntaxSpans != null) target.SyntaxSpans = CopyMap(patch.SyntaxSpans);
			if (patch.SemanticSpans != null) target.SemanticSpans = CopyMap(patch.SemanticSpans);
			if (patch.InlayHints != null) target.InlayHints = CopyMap(patch.InlayHints);
			if (patch.Diagnostics != null) target.Diagnostics = CopyMap(patch.Diagnostics);
			if (patch.IndentGuides != null) target.IndentGuides = new List<DecorationResult.IndentGuideItem>(patch.IndentGuides);
			if (patch.BracketGuides != null) target.BracketGuides = new List<DecorationResult.BracketGuideItem>(patch.BracketGuides);
			if (patch.FlowGuides != null) target.FlowGuides = new List<DecorationResult.FlowGuideItem>(patch.FlowGuides);
			if (patch.SeparatorGuides != null) target.SeparatorGuides = new List<DecorationResult.SeparatorGuideItem>(patch.SeparatorGuides);
			if (patch.FoldRegions != null) target.FoldRegions = new List<DecorationResult.FoldRegionItem>(patch.FoldRegions);
			if (patch.GutterIcons != null) target.GutterIcons = CopyMap(patch.GutterIcons);
			if (patch.PhantomTexts != null) target.PhantomTexts = CopyMap(patch.PhantomTexts);
		}

		private static Dictionary<int, List<T>> CopyMap<T>(Dictionary<int, List<T>> source) {
			var outMap = new Dictionary<int, List<T>>(source.Count);
			foreach (var (k, v) in source) {
				outMap[k] = v == null ? new List<T>() : new List<T>(v);
			}
			return outMap;
		}

		private sealed class ProviderState {
			public DecorationResult? Snapshot;
			public ManagedReceiver? ActiveReceiver;
		}

		private sealed class ManagedReceiver : IDecorationReceiver {
			private readonly DecorationProviderManager manager;
			private readonly IDecorationProvider provider;
			private readonly int receiverGeneration;
			private bool cancelled;

			public ManagedReceiver(DecorationProviderManager manager, IDecorationProvider provider, int receiverGeneration) {
				this.manager = manager;
				this.provider = provider;
				this.receiverGeneration = receiverGeneration;
			}

			public bool Accept(DecorationResult result) {
				if (cancelled || receiverGeneration != manager.generation) return false;
				var snapshot = result.Clone();
				manager.editor.BeginInvoke(new Action(() => {
					if (cancelled || receiverGeneration != manager.generation) return;
					manager.OnReceiverAccept(provider, receiverGeneration, snapshot);
				}));
				return true;
			}

			public bool IsCancelled => cancelled || receiverGeneration != manager.generation;

			public void Cancel() => cancelled = true;
		}
	}


	/// <summary>New-line action result that describes the text to insert after pressing Enter.</summary>
	public sealed class NewLineAction {
		/// <summary>Full text to insert (including line break and indentation).</summary>
		public string Text { get; }
		public NewLineAction(string text) { Text = text; }
	}

	/// <summary>New-line context passed to INewLineActionProvider for indentation calculation.</summary>
	public sealed class NewLineContext {
		/// <summary>Caret line number (0-based).</summary>
		public int LineNumber { get; }
		/// <summary>Caret column (0-based).</summary>
		public int Column { get; }
		/// <summary>Current line text.</summary>
		public string LineText { get; }
		/// <summary>Language configuration (nullable).</summary>
		public LanguageConfiguration? LanguageConfig { get; }

		public NewLineContext(int lineNumber, int column, string lineText, LanguageConfiguration? languageConfig) {
			LineNumber = lineNumber;
			Column = column;
			LineText = lineText;
			LanguageConfig = languageConfig;
		}
	}

	/// <summary>
	/// Smart new-line provider interface.
	/// Implement this interface to customize new-line behavior (smart indentation, comment continuation, bracket expansion, etc.).
	/// Returning null means this provider does not handle the request and it falls through to the next provider in the chain.
	/// </summary>
	public interface INewLineActionProvider {
		NewLineAction? ProvideNewLineAction(NewLineContext context);
	}

	/// <summary>Manages new-line providers as a chain and uses the first provider that returns a non-null result.</summary>
	internal sealed class NewLineActionProviderManager {
		private readonly List<INewLineActionProvider> providers = new();

		public void AddProvider(INewLineActionProvider provider) {
			providers.Add(provider);
		}

		public void RemoveProvider(INewLineActionProvider provider) {
			providers.Remove(provider);
		}

		/// <summary>Iterates all providers and returns the first non-null NewLineAction; returns null if all providers return null.</summary>
		public NewLineAction? ProvideNewLineAction(NewLineContext context) {
			foreach (var provider in providers) {
				var action = provider.ProvideNewLineAction(context);
				if (action != null) return action;
			}
			return null;
		}
	}


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


	/// <summary>
	/// Completion popup controller: ListBox panel management + ICompletionItemRenderer-based custom rendering delegate.
	/// </summary>
	internal sealed class CompletionPopupController {

		private sealed class CompletionPopupForm : Form {
			private const int WS_EX_NOACTIVATE = 0x08000000;

			protected override bool ShowWithoutActivation => true;

			protected override CreateParams CreateParams {
				get {
					var cp = base.CreateParams;
					cp.ExStyle |= WS_EX_NOACTIVATE;
					return cp;
				}
			}
		}

		public delegate void CompletionConfirmHandler(CompletionItem item);
		public event CompletionConfirmHandler? OnConfirmed;

		private const int MaxVisibleItems = 6;
		private const int ItemHeight = 24;
		private const int PopupWidth = 300;
		private const int Gap = 4;

		private readonly Control anchorControl;
		private Form? popupForm;
		private ListBox? listBox;
		private readonly List<CompletionItem> items = new();
		private int selectedIndex;
		private ICompletionItemRenderer? customRenderer;
		private float cachedCursorX;
		private float cachedCursorY;
		private float cachedCursorHeight;

		public CompletionPopupController(Control anchorControl) {
			this.anchorControl = anchorControl;
			InitPopup();
		}

		public void SetRenderer(ICompletionItemRenderer? renderer) {
			customRenderer = renderer;
		}

		public bool IsShowing => popupForm != null && popupForm.Visible;

		public void UpdateItems(List<CompletionItem> newItems) {
			items.Clear();
			items.AddRange(newItems);
			selectedIndex = 0;
			listBox!.Items.Clear();
			foreach (var item in items) listBox.Items.Add(item);
			if (items.Count == 0) {
				Dismiss();
			} else {
				listBox.SelectedIndex = 0;
				Show();
			}
		}

		public void DismissPanel() {
			Dismiss();
		}

		/// <summary>
		/// Handles key codes. Enter=13, Escape=27, Up=38, Down=40.
		/// Returns true when the key is consumed.
		/// </summary>
		public bool HandleKeyCode(Keys keyCode) {
			if (!IsShowing || items.Count == 0) return false;
			switch (keyCode) {
				case Keys.Enter:
					ConfirmSelected();
					return true;
				case Keys.Escape:
					Dismiss();
					return true;
				case Keys.Up:
					MoveSelection(-1);
					return true;
				case Keys.Down:
					MoveSelection(1);
					return true;
				default:
					return false;
			}
		}

		public void UpdateCursorPosition(float cursorX, float cursorY, float cursorHeight) {
			cachedCursorX = cursorX;
			cachedCursorY = cursorY;
			cachedCursorHeight = cursorHeight;
			if (IsShowing) {
				ApplyPosition();
			}
		}

		public void UpdatePosition(float cursorX, float cursorY, float cursorHeight) {
			UpdateCursorPosition(cursorX, cursorY, cursorHeight);
		}

		private void ApplyPosition() {
			if (popupForm == null) return;
			var screenPos = anchorControl.PointToScreen(Point.Empty);
			int x = screenPos.X + (int)cachedCursorX;
			int y = screenPos.Y + (int)(cachedCursorY + cachedCursorHeight + Gap);

			int popupHeight = popupForm.Height;
			var screen = Screen.FromControl(anchorControl);
			if (y + popupHeight > screen.WorkingArea.Bottom) {
				y = screenPos.Y + (int)cachedCursorY - popupHeight - Gap;
			}
			if (x + PopupWidth > screen.WorkingArea.Right) {
				x = screen.WorkingArea.Right - PopupWidth;
			}
			if (x < 0) x = 0;
			if (y < 0) y = 0;

			popupForm.Location = new Point(x, y);
		}

		public void Dismiss() {
			if (popupForm != null && popupForm.Visible) {
				popupForm.Hide();
			}
		}

		private void InitPopup() {
			popupForm = new CompletionPopupForm {
				FormBorderStyle = FormBorderStyle.None,
				ShowInTaskbar = false,
				StartPosition = FormStartPosition.Manual,
				TopMost = true,
				Size = new Size(PopupWidth, ItemHeight * MaxVisibleItems)
			};

			listBox = new ListBox {
				Dock = DockStyle.Fill,
				IntegralHeight = false,
				ItemHeight = ItemHeight,
				DrawMode = DrawMode.OwnerDrawFixed,
				BorderStyle = BorderStyle.FixedSingle,
				Font = new Font("Consolas", 10f),
				TabStop = false
			};

			listBox.DrawItem += (sender, e) => {
				if (e.Index < 0 || e.Index >= items.Count) return;
				var item = items[e.Index];
				bool isSelected = e.Index == selectedIndex;

				if (customRenderer != null) {
					customRenderer.DrawItem(e.Graphics, e.Bounds, item, isSelected);
				} else {
					e.Graphics.FillRectangle(
						isSelected ? new SolidBrush(Color.FromArgb(0xD0, 0xE8, 0xFF)) : new SolidBrush(Color.FromArgb(0xF5, 0xF5, 0xF5)),
						e.Bounds);
					TextRenderer.DrawText(e.Graphics, item.Label, listBox.Font,
						new Point(e.Bounds.Left + 6, e.Bounds.Top + 2), Color.Black);
					if (!string.IsNullOrEmpty(item.Detail)) {
						var detailFont = new Font("Segoe UI", 8f);
						var detailSize = TextRenderer.MeasureText(item.Detail, detailFont);
						TextRenderer.DrawText(e.Graphics, item.Detail, detailFont,
							new Point(e.Bounds.Right - detailSize.Width - 6, e.Bounds.Top + 4), Color.Gray);
					}
				}
			};

			listBox.Click += (sender, e) => {
				if (listBox.SelectedIndex >= 0) {
					selectedIndex = listBox.SelectedIndex;
					ConfirmSelected();
				}
			};

			popupForm.Controls.Add(listBox);
		}

		private void Show() {
			int visibleCount = Math.Min(items.Count, MaxVisibleItems);
			popupForm!.Size = new Size(PopupWidth, visibleCount * ItemHeight + 2);
			if (!popupForm.Visible) {
				popupForm.Show(anchorControl.FindForm());
				anchorControl.BeginInvoke(new Action(() => {
					if (anchorControl.CanFocus) {
						anchorControl.Focus();
					}
				}));
			}
			ApplyPosition();
		}

		private void MoveSelection(int delta) {
			if (items.Count == 0) return;
			int old = selectedIndex;
			selectedIndex = Math.Max(0, Math.Min(items.Count - 1, selectedIndex + delta));
			if (old != selectedIndex) {
				listBox!.SelectedIndex = selectedIndex;
				listBox.Invalidate();
			}
		}

		private void ConfirmSelected() {
			if (selectedIndex >= 0 && selectedIndex < items.Count) {
				var item = items[selectedIndex];
				Dismiss();
				OnConfirmed?.Invoke(item);
			}
		}
	}

}
