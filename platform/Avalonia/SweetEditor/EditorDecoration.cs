using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Threading;

namespace SweetEditor {
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
		CodeLens = 1 << 11,
	}

	public enum DecorationApplyMode {
		MERGE = 0,
		REPLACE_ALL = 1,
		REPLACE_RANGE = 2,
	}

	public sealed class DecorationContext {
		public int VisibleStartLine { get; }
		public int VisibleEndLine { get; }
		public int TotalLineCount { get; }
		public IReadOnlyList<TextChange> TextChanges { get; }
		public LanguageConfiguration? LanguageConfiguration { get; }
		public IEditorMetadata? EditorMetadata { get; }

		public DecorationContext(
			int visibleStartLine,
			int visibleEndLine,
			int totalLineCount,
			IReadOnlyList<TextChange> textChanges,
			LanguageConfiguration? languageConfiguration,
			IEditorMetadata? editorMetadata) {
			VisibleStartLine = visibleStartLine;
			VisibleEndLine = visibleEndLine;
			TotalLineCount = totalLineCount;
			TextChanges = textChanges;
			LanguageConfiguration = languageConfiguration;
			EditorMetadata = editorMetadata;
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
		public Dictionary<int, List<StyleSpan>>? SyntaxSpans { get; set; }
		public Dictionary<int, List<StyleSpan>>? SemanticSpans { get; set; }
		public Dictionary<int, List<InlayHint>>? InlayHints { get; set; }
		public Dictionary<int, List<Diagnostic>>? Diagnostics { get; set; }
		public List<IndentGuide>? IndentGuides { get; set; }
		public List<BracketGuide>? BracketGuides { get; set; }
		public List<FlowGuide>? FlowGuides { get; set; }
		public List<SeparatorGuide>? SeparatorGuides { get; set; }
		public List<FoldRegion>? FoldRegions { get; set; }
		public Dictionary<int, List<GutterIcon>>? GutterIcons { get; set; }
		public Dictionary<int, List<PhantomText>>? PhantomTexts { get; set; }
		public Dictionary<int, List<CodeLensItem>>? CodeLensItems { get; set; }

		public DecorationApplyMode SyntaxSpansMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode SemanticSpansMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode InlayHintsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode DiagnosticsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode IndentGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode BracketGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode FlowGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode SeparatorGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode FoldRegionsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode GutterIconsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode PhantomTextsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode CodeLensItemsMode { get; set; } = DecorationApplyMode.MERGE;

		public DecorationResult Clone() {
			return new DecorationResult {
				SyntaxSpans = CopyMap(SyntaxSpans),
				SemanticSpans = CopyMap(SemanticSpans),
				InlayHints = CopyMap(InlayHints),
				Diagnostics = CopyMap(Diagnostics),
				IndentGuides = IndentGuides == null ? null : new List<IndentGuide>(IndentGuides),
				BracketGuides = BracketGuides == null ? null : new List<BracketGuide>(BracketGuides),
				FlowGuides = FlowGuides == null ? null : new List<FlowGuide>(FlowGuides),
				SeparatorGuides = SeparatorGuides == null ? null : new List<SeparatorGuide>(SeparatorGuides),
				FoldRegions = FoldRegions == null ? null : new List<FoldRegion>(FoldRegions),
				GutterIcons = CopyMap(GutterIcons),
				PhantomTexts = CopyMap(PhantomTexts),
				CodeLensItems = CopyMap(CodeLensItems),
				SyntaxSpansMode = SyntaxSpansMode,
				SemanticSpansMode = SemanticSpansMode,
				InlayHintsMode = InlayHintsMode,
				DiagnosticsMode = DiagnosticsMode,
				IndentGuidesMode = IndentGuidesMode,
				BracketGuidesMode = BracketGuidesMode,
				FlowGuidesMode = FlowGuidesMode,
				SeparatorGuidesMode = SeparatorGuidesMode,
				FoldRegionsMode = FoldRegionsMode,
				GutterIconsMode = GutterIconsMode,
				PhantomTextsMode = PhantomTextsMode,
				CodeLensItemsMode = CodeLensItemsMode,
			};
		}

		private static Dictionary<int, List<T>>? CopyMap<T>(Dictionary<int, List<T>>? source) {
			if (source == null) {
				return null;
			}
			var output = new Dictionary<int, List<T>>(source.Count);
			foreach (var kv in source) {
				output[kv.Key] = kv.Value == null ? new List<T>() : new List<T>(kv.Value);
			}
			return output;
		}
	}

	internal sealed class DecorationProviderManager : IDisposable {
		private readonly SweetEditorControl editor;
		private readonly List<IDecorationProvider> providers = new();
		private readonly Dictionary<IDecorationProvider, ProviderState> states = new();
		private readonly DispatcherTimer debounceTimer;
		private readonly DispatcherTimer scrollRefreshTimer;

		private readonly List<TextChange> pendingTextChanges = new();
		private bool applyScheduled;
		private int generation;
		private int lastVisibleStartLine;
		private int lastVisibleEndLine = -1;
		private int lastContextStartLine;
		private int lastContextEndLine = -1;
		private int appliedVisibleStartLine;
		private int appliedVisibleEndLine = -1;
		private int appliedContextStartLine;
		private int appliedContextEndLine = -1;
		private bool scrollRefreshScheduled;
		private bool pendingScrollRefresh;
		private long lastScrollRefreshTickMs;
		private bool lastRefreshHadTextChanges;
		private string appliedFoldRegionsSignature = string.Empty;

		public DecorationProviderManager(SweetEditorControl editor) {
			this.editor = editor;
			debounceTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(50),
			};
			debounceTimer.Tick += (_, _) => {
				debounceTimer.Stop();
				DoRefresh();
			};

			scrollRefreshTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(1),
			};
			scrollRefreshTimer.Tick += (_, _) => {
				scrollRefreshTimer.Stop();
				scrollRefreshScheduled = false;
				debounceTimer.Stop();
				DoRefresh();
				lastScrollRefreshTickMs = Environment.TickCount64;
				if (pendingScrollRefresh) {
					pendingScrollRefresh = false;
					ScheduleScrollRefresh();
				}
			};
		}

		public void AddProvider(IDecorationProvider provider) {
			if (provider == null) {
				return;
			}
			if (providers.Contains(provider)) {
				return;
			}
			providers.Add(provider);
			states[provider] = new ProviderState();
			RequestRefresh();
		}

		public void RemoveProvider(IDecorationProvider provider) {
			if (provider == null) {
				return;
			}
			providers.Remove(provider);
			if (states.TryGetValue(provider, out var state) && state.ActiveReceiver != null) {
				state.ActiveReceiver.Cancel();
			}
			states.Remove(provider);
			ScheduleApply();
		}

		public void RequestRefresh() => ScheduleRefresh(0, null);

		public void OnDocumentLoaded() {
			debounceTimer.Stop();
			scrollRefreshTimer.Stop();
			scrollRefreshScheduled = false;
			pendingScrollRefresh = false;
			pendingTextChanges.Clear();
			generation++;
			lastVisibleStartLine = 0;
			lastVisibleEndLine = -1;
			lastContextStartLine = 0;
			lastContextEndLine = -1;
			appliedVisibleStartLine = 0;
			appliedVisibleEndLine = -1;
			appliedContextStartLine = 0;
			appliedContextEndLine = -1;
			lastRefreshHadTextChanges = false;
			appliedFoldRegionsSignature = string.Empty;
			foreach (var state in states.Values) {
				state.ActiveReceiver?.Cancel();
				state.ActiveReceiver = null;
				state.Snapshot = null;
			}

			editor.ClearAllDecorations();
			editor.ClearCodeLens();
			editor.SetFoldRegions(Array.Empty<FoldRegion>());
			editor.Flush();
			ScheduleRefresh(0, null);
		}

		public void OnScrollChanged() {
			if (pendingTextChanges.Count == 0 &&
				!scrollRefreshScheduled &&
				!pendingScrollRefresh &&
				IsVisibleRangeCoveredByAppliedContext(editor.GetCachedVisibleLineRange())) {
				return;
			}

			ScheduleScrollRefresh();
		}

		public void OnTextChanged(IReadOnlyList<TextChange>? changes) => ScheduleRefresh(16, changes);

		public void Dispose() {
			debounceTimer.Stop();
			scrollRefreshTimer.Stop();
			generation++;
			foreach (var state in states.Values) {
				state.ActiveReceiver?.Cancel();
				state.Gate.Dispose();
			}
			states.Clear();
			providers.Clear();
			pendingTextChanges.Clear();
			appliedFoldRegionsSignature = string.Empty;
		}

		private void ScheduleRefresh(int delayMs, IReadOnlyList<TextChange>? changes) {
			if (changes != null && changes.Count > 0) {
				pendingTextChanges.AddRange(changes);
			}

			if (scrollRefreshScheduled) {
				scrollRefreshTimer.Stop();
				scrollRefreshScheduled = false;
			}
			pendingScrollRefresh = false;

			debounceTimer.Stop();
			debounceTimer.Interval = TimeSpan.FromMilliseconds(Math.Max(1, delayMs == 0 ? 1 : delayMs));
			debounceTimer.Start();
		}

		private void ScheduleScrollRefresh() {
			long now = Environment.TickCount64;
			long elapsed = now - lastScrollRefreshTickMs;
			long minInterval = Math.Max(0L, editor.GetSettings().GetDecorationScrollRefreshMinIntervalMs());
			long delay = elapsed >= minInterval ? 1L : Math.Max(1L, minInterval - elapsed);
			if (scrollRefreshScheduled) {
				pendingScrollRefresh = true;
				return;
			}
			scrollRefreshScheduled = true;
			scrollRefreshTimer.Stop();
			scrollRefreshTimer.Interval = TimeSpan.FromMilliseconds(delay);
			scrollRefreshTimer.Start();
		}

		private void DoRefresh() {
			generation++;
			int currentGeneration = generation;

			var visible = editor.GetCachedVisibleLineRange();
			lastVisibleStartLine = visible.start;
			lastVisibleEndLine = visible.end;
			var changes = new List<TextChange>(pendingTextChanges).AsReadOnly();
			lastRefreshHadTextChanges = changes.Count > 0;
			pendingTextChanges.Clear();
			int total = editor.GetTotalLineCount();

			int contextStart = visible.start;
			int contextEnd = visible.end;
			if (total > 0 && visible.end >= visible.start) {
				int overscan = CalculateOverscanLines(visible.start, visible.end);
				contextStart = Math.Max(0, visible.start - overscan);
				contextEnd = Math.Min(total - 1, visible.end + overscan);
			}
			lastContextStartLine = contextStart;
			lastContextEndLine = contextEnd;

			var context = new DecorationContext(
				contextStart,
				contextEnd,
				total,
				changes,
				editor.GetLanguageConfiguration(),
				editor.Metadata);

			foreach (var provider in providers) {
				if (!states.TryGetValue(provider, out var state)) {
					state = new ProviderState();
					states[provider] = state;
				}

				state.ActiveReceiver?.Cancel();
				var receiver = new ManagedReceiver(this, provider, currentGeneration);
				state.ActiveReceiver = receiver;

				_ = Task.Run(async () => {
					try {
						await state.Gate.WaitAsync().ConfigureAwait(false);
						try {
							if (receiver.IsCancelled) {
								return;
							}
							provider.ProvideDecorations(context, receiver);
						} finally {
							state.Gate.Release();
						}
					} catch (Exception ex) {
						Console.Error.WriteLine($"Decoration provider error: {ex.Message}");
					}
				});
			}
		}

		private int CalculateOverscanLines(int visibleStartLine, int visibleEndLine) {
			int visibleCount = Math.Max(0, visibleEndLine - visibleStartLine + 1);
			float multiplier = editor.GetSettings().GetDecorationOverscanViewportMultiplier();
			multiplier = Math.Max(0f, multiplier);
			return (int)Math.Ceiling(visibleCount * multiplier);
		}

		private void ScheduleApply() {
			if (applyScheduled) {
				return;
			}
			applyScheduled = true;
			Dispatcher.UIThread.Post(ApplyMerged);
		}

		private void ApplyMerged() {
			applyScheduled = false;
			int currentVisibleStartLine = lastVisibleStartLine;
			int currentVisibleEndLine = lastVisibleEndLine;
			int currentContextStartLine = lastContextStartLine;
			int currentContextEndLine = lastContextEndLine;

			var syntaxSpans = new Dictionary<int, List<StyleSpan>>();
			var semanticSpans = new Dictionary<int, List<StyleSpan>>();
			var inlayHints = new Dictionary<int, List<InlayHint>>();
			var diagnostics = new Dictionary<int, List<Diagnostic>>();
			List<IndentGuide>? indentGuides = null;
			List<BracketGuide>? bracketGuides = null;
			List<FlowGuide>? flowGuides = null;
			List<SeparatorGuide>? separatorGuides = null;
			var foldRegions = new List<FoldRegion>();
			var gutterIcons = new Dictionary<int, List<GutterIcon>>();
			var phantomTexts = new Dictionary<int, List<PhantomText>>();
			var codeLensItems = new Dictionary<int, List<CodeLensItem>>();

			DecorationApplyMode syntaxMode = DecorationApplyMode.MERGE;
			DecorationApplyMode semanticMode = DecorationApplyMode.MERGE;
			DecorationApplyMode inlayMode = DecorationApplyMode.MERGE;
			DecorationApplyMode diagnosticMode = DecorationApplyMode.MERGE;
			DecorationApplyMode indentMode = DecorationApplyMode.MERGE;
			DecorationApplyMode bracketMode = DecorationApplyMode.MERGE;
			DecorationApplyMode flowMode = DecorationApplyMode.MERGE;
			DecorationApplyMode separatorMode = DecorationApplyMode.MERGE;
			DecorationApplyMode foldMode = DecorationApplyMode.MERGE;
			DecorationApplyMode gutterMode = DecorationApplyMode.MERGE;
			DecorationApplyMode phantomMode = DecorationApplyMode.MERGE;
			DecorationApplyMode codeLensMode = DecorationApplyMode.MERGE;

			foreach (var provider in providers) {
				if (!states.TryGetValue(provider, out var state) || state.Snapshot == null) {
					continue;
				}
				var result = state.Snapshot;
				syntaxMode = MergeMode(syntaxMode, result.SyntaxSpansMode);
				if (result.SyntaxSpans != null) {
					AppendMap(syntaxSpans, result.SyntaxSpans);
				}
				semanticMode = MergeMode(semanticMode, result.SemanticSpansMode);
				if (result.SemanticSpans != null) {
					AppendMap(semanticSpans, result.SemanticSpans);
				}
				inlayMode = MergeMode(inlayMode, result.InlayHintsMode);
				if (result.InlayHints != null) {
					AppendMap(inlayHints, result.InlayHints);
				}
				diagnosticMode = MergeMode(diagnosticMode, result.DiagnosticsMode);
				if (result.Diagnostics != null) {
					AppendMap(diagnostics, result.Diagnostics);
				}
				gutterMode = MergeMode(gutterMode, result.GutterIconsMode);
				if (result.GutterIcons != null) {
					AppendMap(gutterIcons, result.GutterIcons);
				}
				phantomMode = MergeMode(phantomMode, result.PhantomTextsMode);
				if (result.PhantomTexts != null) {
					AppendMap(phantomTexts, result.PhantomTexts);
				}
				codeLensMode = MergeMode(codeLensMode, result.CodeLensItemsMode);
				if (result.CodeLensItems != null) {
					AppendMap(codeLensItems, result.CodeLensItems);
				}
				indentMode = MergeMode(indentMode, result.IndentGuidesMode);
				if (result.IndentGuides != null) {
					indentGuides = result.IndentGuides;
				}
				bracketMode = MergeMode(bracketMode, result.BracketGuidesMode);
				if (result.BracketGuides != null) {
					bracketGuides = result.BracketGuides;
				}
				flowMode = MergeMode(flowMode, result.FlowGuidesMode);
				if (result.FlowGuides != null) {
					flowGuides = result.FlowGuides;
				}
				separatorMode = MergeMode(separatorMode, result.SeparatorGuidesMode);
				if (result.SeparatorGuides != null) {
					separatorGuides = result.SeparatorGuides;
				}
				foldMode = MergeMode(foldMode, result.FoldRegionsMode);
				if (result.FoldRegions != null) {
					foldRegions.AddRange(result.FoldRegions);
				}
			}

			bool changed = false;
			changed |= ApplySpanMode(SpanLayer.SYNTAX, syntaxMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplySpanMode(SpanLayer.SEMANTIC, semanticMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplySpans(SpanLayer.SYNTAX, syntaxSpans);
			changed |= ApplySpans(SpanLayer.SEMANTIC, semanticSpans);
			changed |= ApplyInlayMode(inlayMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplyInlayHints(inlayHints);
			changed |= ApplyDiagnosticMode(diagnosticMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplyDiagnostics(diagnostics);
			changed |= ApplyGutterMode(gutterMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplyGutterIcons(gutterIcons);
			changed |= ApplyPhantomMode(phantomMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplyPhantomTexts(phantomTexts);
			changed |= ApplyCodeLensMode(codeLensMode, currentContextStartLine, currentContextEndLine);
			changed |= ApplyCodeLensItems(codeLensItems);
			changed |= ApplyIndentGuides(indentMode, indentGuides);
			changed |= ApplyBracketGuides(bracketMode, bracketGuides);
			changed |= ApplyFlowGuides(flowMode, flowGuides);
			changed |= ApplySeparatorGuides(separatorMode, separatorGuides);
			changed |= ApplyFoldRegions(foldMode, foldRegions);
			appliedVisibleStartLine = currentVisibleStartLine;
			appliedVisibleEndLine = currentVisibleEndLine;
			appliedContextStartLine = currentContextStartLine;
			appliedContextEndLine = currentContextEndLine;
			if (changed) {
				editor.ResetRenderModelDiagnostics();
				editor.FlushDecorationUpdate();
			}
		}

		private static DecorationApplyMode MergeMode(DecorationApplyMode current, DecorationApplyMode incoming) {
			if (incoming == DecorationApplyMode.REPLACE_ALL || current == DecorationApplyMode.REPLACE_ALL) {
				return DecorationApplyMode.REPLACE_ALL;
			}
			if (incoming == DecorationApplyMode.REPLACE_RANGE || current == DecorationApplyMode.REPLACE_RANGE) {
				return DecorationApplyMode.REPLACE_RANGE;
			}
			return DecorationApplyMode.MERGE;
		}

		private static void AppendMap<T>(Dictionary<int, List<T>> target, Dictionary<int, List<T>> source) {
			foreach (var kv in source) {
				if (!target.TryGetValue(kv.Key, out var existing)) {
					target[kv.Key] = kv.Value ?? new List<T>();
					continue;
				}

				if (kv.Value == null || kv.Value.Count == 0) {
					continue;
				}

				var combined = new List<T>(existing.Count + kv.Value.Count);
				combined.AddRange(existing);
				combined.AddRange(kv.Value);
				target[kv.Key] = combined;
			}
		}

		private bool ApplySpanMode(SpanLayer layer, DecorationApplyMode mode, int currentVisibleStartLine, int currentVisibleEndLine) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearHighlights(layer);
				return true;
			}
			if (mode == DecorationApplyMode.REPLACE_RANGE) {
				return ClearPreviousAndCurrentRange(
					(startLine, endLine) => ClearSpanRange(layer, startLine, endLine),
					currentVisibleStartLine,
					currentVisibleEndLine);
			}
			return false;
		}

		private bool ApplySpans(SpanLayer layer, Dictionary<int, List<StyleSpan>> source) {
			if (source.Count == 0) {
				return false;
			}
			editor.SetBatchLineSpans(layer, source);
			return true;
		}

		private bool ApplyInlayMode(DecorationApplyMode mode, int currentVisibleStartLine, int currentVisibleEndLine) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearInlayHints();
				return true;
			}
			if (mode == DecorationApplyMode.REPLACE_RANGE) {
				return ClearPreviousAndCurrentRange(ClearInlayRange, currentVisibleStartLine, currentVisibleEndLine);
			}
			return false;
		}

		private bool ApplyInlayHints(Dictionary<int, List<InlayHint>> source) {
			if (source.Count == 0) {
				return false;
			}
			editor.SetBatchLineInlayHints(source);
			return true;
		}

		private bool ApplyDiagnosticMode(DecorationApplyMode mode, int currentVisibleStartLine, int currentVisibleEndLine) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearDiagnostics();
				return true;
			}
			if (mode == DecorationApplyMode.REPLACE_RANGE) {
				return ClearPreviousAndCurrentRange(ClearDiagnosticRange, currentVisibleStartLine, currentVisibleEndLine);
			}
			return false;
		}

		private bool ApplyDiagnostics(Dictionary<int, List<Diagnostic>> source) {
			if (source.Count == 0) {
				return false;
			}
			editor.SetBatchLineDiagnostics(source);
			return true;
		}

		private bool ApplyGutterMode(DecorationApplyMode mode, int currentVisibleStartLine, int currentVisibleEndLine) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearGutterIcons();
				return true;
			}
			if (mode == DecorationApplyMode.REPLACE_RANGE) {
				return ClearPreviousAndCurrentRange(ClearGutterRange, currentVisibleStartLine, currentVisibleEndLine);
			}
			return false;
		}

		private bool ApplyGutterIcons(Dictionary<int, List<GutterIcon>> source) {
			if (source.Count == 0) {
				return false;
			}
			editor.SetBatchLineGutterIcons(source);
			return true;
		}

		private bool ApplyPhantomMode(DecorationApplyMode mode, int currentVisibleStartLine, int currentVisibleEndLine) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearPhantomTexts();
				return true;
			}
			if (mode == DecorationApplyMode.REPLACE_RANGE) {
				return ClearPreviousAndCurrentRange(ClearPhantomRange, currentVisibleStartLine, currentVisibleEndLine);
			}
			return false;
		}

		private bool ApplyPhantomTexts(Dictionary<int, List<PhantomText>> source) {
			if (source.Count == 0) {
				return false;
			}
			editor.SetBatchLinePhantomTexts(source);
			return true;
		}

		private bool ApplyCodeLensMode(DecorationApplyMode mode, int currentVisibleStartLine, int currentVisibleEndLine) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearCodeLens();
				return true;
			}
			if (mode == DecorationApplyMode.REPLACE_RANGE) {
				return ClearPreviousAndCurrentRange(ClearCodeLensRange, currentVisibleStartLine, currentVisibleEndLine);
			}
			return false;
		}

		private bool ApplyCodeLensItems(Dictionary<int, List<CodeLensItem>> source) {
			if (source.Count == 0) {
				return false;
			}
			editor.SetBatchLineCodeLens(source);
			return true;
		}

		private bool ClearSpanRange(SpanLayer layer, int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<StyleSpan>(startLine, endLine);
			if (empty.Count == 0) {
				return false;
			}
			editor.SetBatchLineSpans(layer, empty);
			return true;
		}

		private bool ClearInlayRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<InlayHint>(startLine, endLine);
			if (empty.Count == 0) {
				return false;
			}
			editor.SetBatchLineInlayHints(empty);
			return true;
		}

		private bool ClearDiagnosticRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<Diagnostic>(startLine, endLine);
			if (empty.Count == 0) {
				return false;
			}
			editor.SetBatchLineDiagnostics(empty);
			return true;
		}

		private bool ClearGutterRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<GutterIcon>(startLine, endLine);
			if (empty.Count == 0) {
				return false;
			}
			editor.SetBatchLineGutterIcons(empty);
			return true;
		}

		private bool ClearPhantomRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<PhantomText>(startLine, endLine);
			if (empty.Count == 0) {
				return false;
			}
			editor.SetBatchLinePhantomTexts(empty);
			return true;
		}

		private bool ClearCodeLensRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<CodeLensItem>(startLine, endLine);
			if (empty.Count == 0) {
				return false;
			}
			editor.SetBatchLineCodeLens(empty);
			return true;
		}

		private bool ClearPreviousAndCurrentRange(Func<int, int, bool> clearRange, int currentVisibleStartLine, int currentVisibleEndLine) {
			bool changed = false;
			if (appliedContextEndLine >= appliedContextStartLine) {
				changed |= clearRange(appliedContextStartLine, appliedContextEndLine);
			}
			if (currentVisibleEndLine >= currentVisibleStartLine &&
				(currentVisibleStartLine != appliedContextStartLine || currentVisibleEndLine != appliedContextEndLine)) {
				changed |= clearRange(currentVisibleStartLine, currentVisibleEndLine);
			}
			return changed;
		}

		private bool IsVisibleRangeCoveredByAppliedContext((int start, int end) visible) {
			if (visible.end < visible.start) {
				return true;
			}

			return appliedContextEndLine >= appliedContextStartLine &&
				visible.start >= appliedContextStartLine &&
				visible.end <= appliedContextEndLine;
		}

		private static Dictionary<int, List<T>> BuildEmptyRangeMap<T>(int startLine, int endLine) {
			var output = new Dictionary<int, List<T>>();
			if (endLine < startLine) {
				return output;
			}

			List<T> empty = new(0);
			for (int line = startLine; line <= endLine; line++) {
				output[line] = empty;
			}
			return output;
		}

		private bool ApplyIndentGuides(DecorationApplyMode mode, List<IndentGuide>? guides) {
			if (mode != DecorationApplyMode.MERGE) {
				editor.ClearGuides();
				if (guides == null) {
					return true;
				}
			}
			if (guides == null) {
				return false;
			}
			editor.SetIndentGuides(guides);
			return true;
		}

		private bool ApplyBracketGuides(DecorationApplyMode mode, List<BracketGuide>? guides) {
			if (mode != DecorationApplyMode.MERGE && guides == null) {
				editor.ClearGuides();
				return true;
			}
			if (guides == null) {
				return false;
			}
			editor.SetBracketGuides(guides);
			return true;
		}

		private bool ApplyFlowGuides(DecorationApplyMode mode, List<FlowGuide>? guides) {
			if (mode != DecorationApplyMode.MERGE && guides == null) {
				editor.ClearGuides();
				return true;
			}
			if (guides == null) {
				return false;
			}
			editor.SetFlowGuides(guides);
			return true;
		}

		private bool ApplySeparatorGuides(DecorationApplyMode mode, List<SeparatorGuide>? guides) {
			if (mode != DecorationApplyMode.MERGE && guides == null) {
				editor.ClearGuides();
				return true;
			}
			if (guides == null) {
				return false;
			}
			editor.SetSeparatorGuides(guides);
			return true;
		}

		private bool ApplyFoldRegions(DecorationApplyMode mode, List<FoldRegion> regions) {
			if (regions.Count == 0) {
				if (mode != DecorationApplyMode.MERGE && appliedFoldRegionsSignature.Length > 0) {
					if (!lastRefreshHadTextChanges && editor.GetTotalLineCount() > 0) {
						return false;
					}
					editor.SetFoldRegions(Array.Empty<FoldRegion>());
					appliedFoldRegionsSignature = string.Empty;
					return true;
				}
				return false;
			}

			List<FoldRegion> normalized = NormalizeFoldRegions(regions);
			if (normalized.Count == 0) {
				if (mode != DecorationApplyMode.MERGE && appliedFoldRegionsSignature.Length > 0) {
					if (!lastRefreshHadTextChanges && editor.GetTotalLineCount() > 0) {
						return false;
					}
					editor.SetFoldRegions(Array.Empty<FoldRegion>());
					appliedFoldRegionsSignature = string.Empty;
					return true;
				}
				return false;
			}

			// Keep user fold state stable during pure scroll/viewport refreshes.
			// Structural fold regions should only be reapplied after text changes.
			if (!lastRefreshHadTextChanges && appliedFoldRegionsSignature.Length > 0) {
				return false;
			}

			string signature = BuildFoldRegionSignature(normalized);
			if (signature == appliedFoldRegionsSignature) {
				return false;
			}

			editor.SetFoldRegions(normalized);
			appliedFoldRegionsSignature = signature;
			return true;
		}

		private static List<FoldRegion> NormalizeFoldRegions(List<FoldRegion> regions) {
			var normalized = new List<FoldRegion>(regions.Count);
			foreach (var region in regions) {
				if (region.StartLine < 0 || region.EndLine <= region.StartLine) {
					continue;
				}
				normalized.Add(new FoldRegion(region.StartLine, region.EndLine));
			}

			normalized.Sort(static (a, b) => {
				int start = a.StartLine.CompareTo(b.StartLine);
				return start != 0 ? start : a.EndLine.CompareTo(b.EndLine);
			});

			if (normalized.Count <= 1) {
				return normalized;
			}

			var deduped = new List<FoldRegion>(normalized.Count);
			FoldRegion? last = null;
			foreach (var region in normalized) {
				if (last != null &&
					last.StartLine == region.StartLine &&
					last.EndLine == region.EndLine) {
					continue;
				}
				deduped.Add(region);
				last = region;
			}
			return deduped;
		}

		private static string BuildFoldRegionSignature(List<FoldRegion> regions) {
			if (regions.Count == 0) {
				return string.Empty;
			}

			var sb = new StringBuilder(regions.Count * 10);
			foreach (var r in regions) {
				sb.Append(r.StartLine).Append(':').Append(r.EndLine).Append(';');
			}
			return sb.ToString();
		}

		private void OnReceiverAccept(IDecorationProvider provider, DecorationResult result, int receiverGeneration) {
			if (receiverGeneration != generation) {
				return;
			}

			if (!states.TryGetValue(provider, out var state)) {
				state = new ProviderState();
				states[provider] = state;
			}

			MergePatch(state, result);
			ScheduleApply();
		}

		private static void MergePatch(ProviderState state, DecorationResult patchResult) {
			state.Snapshot ??= new DecorationResult();
			var snapshot = state.Snapshot;

			if (patchResult.SyntaxSpans != null) {
				snapshot.SyntaxSpans = patchResult.SyntaxSpans;
				snapshot.SyntaxSpansMode = patchResult.SyntaxSpansMode;
			} else if (patchResult.SyntaxSpansMode != DecorationApplyMode.MERGE) {
				snapshot.SyntaxSpans = null;
				snapshot.SyntaxSpansMode = patchResult.SyntaxSpansMode;
			}

			if (patchResult.SemanticSpans != null) {
				snapshot.SemanticSpans = patchResult.SemanticSpans;
				snapshot.SemanticSpansMode = patchResult.SemanticSpansMode;
			} else if (patchResult.SemanticSpansMode != DecorationApplyMode.MERGE) {
				snapshot.SemanticSpans = null;
				snapshot.SemanticSpansMode = patchResult.SemanticSpansMode;
			}

			if (patchResult.InlayHints != null) {
				snapshot.InlayHints = patchResult.InlayHints;
				snapshot.InlayHintsMode = patchResult.InlayHintsMode;
			} else if (patchResult.InlayHintsMode != DecorationApplyMode.MERGE) {
				snapshot.InlayHints = null;
				snapshot.InlayHintsMode = patchResult.InlayHintsMode;
			}

			if (patchResult.Diagnostics != null) {
				snapshot.Diagnostics = patchResult.Diagnostics;
				snapshot.DiagnosticsMode = patchResult.DiagnosticsMode;
			} else if (patchResult.DiagnosticsMode != DecorationApplyMode.MERGE) {
				snapshot.Diagnostics = null;
				snapshot.DiagnosticsMode = patchResult.DiagnosticsMode;
			}

			if (patchResult.IndentGuides != null) {
				snapshot.IndentGuides = patchResult.IndentGuides;
				snapshot.IndentGuidesMode = patchResult.IndentGuidesMode;
			} else if (patchResult.IndentGuidesMode != DecorationApplyMode.MERGE) {
				snapshot.IndentGuides = null;
				snapshot.IndentGuidesMode = patchResult.IndentGuidesMode;
			}

			if (patchResult.BracketGuides != null) {
				snapshot.BracketGuides = patchResult.BracketGuides;
				snapshot.BracketGuidesMode = patchResult.BracketGuidesMode;
			} else if (patchResult.BracketGuidesMode != DecorationApplyMode.MERGE) {
				snapshot.BracketGuides = null;
				snapshot.BracketGuidesMode = patchResult.BracketGuidesMode;
			}

			if (patchResult.FlowGuides != null) {
				snapshot.FlowGuides = patchResult.FlowGuides;
				snapshot.FlowGuidesMode = patchResult.FlowGuidesMode;
			} else if (patchResult.FlowGuidesMode != DecorationApplyMode.MERGE) {
				snapshot.FlowGuides = null;
				snapshot.FlowGuidesMode = patchResult.FlowGuidesMode;
			}

			if (patchResult.SeparatorGuides != null) {
				snapshot.SeparatorGuides = patchResult.SeparatorGuides;
				snapshot.SeparatorGuidesMode = patchResult.SeparatorGuidesMode;
			} else if (patchResult.SeparatorGuidesMode != DecorationApplyMode.MERGE) {
				snapshot.SeparatorGuides = null;
				snapshot.SeparatorGuidesMode = patchResult.SeparatorGuidesMode;
			}

			if (patchResult.FoldRegions != null) {
				snapshot.FoldRegions = patchResult.FoldRegions;
				snapshot.FoldRegionsMode = patchResult.FoldRegionsMode;
			} else if (patchResult.FoldRegionsMode != DecorationApplyMode.MERGE) {
				snapshot.FoldRegions = null;
				snapshot.FoldRegionsMode = patchResult.FoldRegionsMode;
			}

			if (patchResult.GutterIcons != null) {
				snapshot.GutterIcons = patchResult.GutterIcons;
				snapshot.GutterIconsMode = patchResult.GutterIconsMode;
			} else if (patchResult.GutterIconsMode != DecorationApplyMode.MERGE) {
				snapshot.GutterIcons = null;
				snapshot.GutterIconsMode = patchResult.GutterIconsMode;
			}

			if (patchResult.PhantomTexts != null) {
				snapshot.PhantomTexts = patchResult.PhantomTexts;
				snapshot.PhantomTextsMode = patchResult.PhantomTextsMode;
			} else if (patchResult.PhantomTextsMode != DecorationApplyMode.MERGE) {
				snapshot.PhantomTexts = null;
				snapshot.PhantomTextsMode = patchResult.PhantomTextsMode;
			}

			if (patchResult.CodeLensItems != null) {
				snapshot.CodeLensItems = patchResult.CodeLensItems;
				snapshot.CodeLensItemsMode = patchResult.CodeLensItemsMode;
			} else if (patchResult.CodeLensItemsMode != DecorationApplyMode.MERGE) {
				snapshot.CodeLensItems = null;
				snapshot.CodeLensItemsMode = patchResult.CodeLensItemsMode;
			}
		}

		private sealed class ProviderState {
			public readonly SemaphoreSlim Gate = new(1, 1);
			public ManagedReceiver? ActiveReceiver;
			public DecorationResult? Snapshot;
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
				if (cancelled || receiverGeneration != manager.generation) {
					return false;
				}
				Dispatcher.UIThread.Post(() => {
					if (cancelled || receiverGeneration != manager.generation) {
						return;
					}
					manager.OnReceiverAccept(provider, result, receiverGeneration);
				});
				return true;
			}

			public bool IsCancelled => cancelled || receiverGeneration != manager.generation;

			public void Cancel() {
				cancelled = true;
			}
		}
	}
}
