using System;
using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;

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
		Link = 1 << 12,
		DocumentHighlight = 1 << 13,
	}

	public enum DecorationApplyMode {
		MERGE = 0,
		REPLACE_ALL = 1,
		REPLACE_RANGE = 2,
	}

	public sealed class DecorationContext {
		public IntRange VisibleLineRange { get; }
		public int TotalLineCount { get; }
		/// <summary>All text changes accumulated in this refresh cycle (read-only). An empty list means the refresh was triggered by a non-text change.</summary>
		public IReadOnlyList<TextChange> TextChanges { get; }
		/// <summary>Current language configuration (from LanguageConfiguration).</summary>
		public LanguageConfiguration? LanguageConfiguration { get; }
		/// <summary>Current editor metadata (from SweetEditorControl).</summary>
		public IEditorMetadata? EditorMetadata { get; }

		public DecorationContext(IntRange visibleLineRange, int totalLineCount,
								 IReadOnlyList<TextChange> textChanges, LanguageConfiguration? languageConfiguration = null,
								 IEditorMetadata? editorMetadata = null) {
			VisibleLineRange = visibleLineRange;
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

	/// <summary>
	/// Decoration provider interface.
	/// ProvideDecorations is invoked from the UI thread by the WinForms editor.
	/// Providers may start background work, but results delivered through IDecorationReceiver may arrive from any thread and are marshaled back to the UI thread before being applied to the editor.
	/// </summary>
	public interface IDecorationProvider {
		DecorationType Capabilities { get; }
		void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver);
	}

	public sealed class DecorationResult {
		public Dictionary<int, List<StyleSpan>>? SyntaxSpans { get; set; }
		public Dictionary<int, List<StyleSpan>>? SemanticSpans { get; set; }
		public Dictionary<int, List<InlayHint>>? InlayHints { get; set; }
		public Dictionary<int, List<Diagnostic>>? Diagnostics { get; set; }
		public Dictionary<int, List<DocumentHighlight>>? DocumentHighlights { get; set; }
		public List<IndentGuide>? IndentGuides { get; set; }
		public List<BracketGuide>? BracketGuides { get; set; }
		public List<FlowGuide>? FlowGuides { get; set; }
		public List<SeparatorGuide>? SeparatorGuides { get; set; }
		public List<FoldRegion>? FoldRegions { get; set; }
		public Dictionary<int, List<GutterIcon>>? GutterIcons { get; set; }
		public Dictionary<int, List<PhantomText>>? PhantomTexts { get; set; }
		public Dictionary<int, List<CodeLensItem>>? CodeLensItems { get; set; }
		public Dictionary<int, List<LinkSpan>>? Links { get; set; }

		public DecorationApplyMode SyntaxSpansMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode SemanticSpansMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode InlayHintsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode DiagnosticsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode DocumentHighlightsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode IndentGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode BracketGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode FlowGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode SeparatorGuidesMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode FoldRegionsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode GutterIconsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode PhantomTextsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode CodeLensItemsMode { get; set; } = DecorationApplyMode.MERGE;
		public DecorationApplyMode LinksMode { get; set; } = DecorationApplyMode.MERGE;

		public DecorationResult Clone() {
			return new DecorationResult {
				SyntaxSpans = CopyMap(SyntaxSpans),
				SemanticSpans = CopyMap(SemanticSpans),
				InlayHints = CopyMap(InlayHints),
				Diagnostics = CopyMap(Diagnostics),
				DocumentHighlights = CopyMap(DocumentHighlights),
				IndentGuides = IndentGuides == null ? null : new List<IndentGuide>(IndentGuides),
				BracketGuides = BracketGuides == null ? null : new List<BracketGuide>(BracketGuides),
				FlowGuides = FlowGuides == null ? null : new List<FlowGuide>(FlowGuides),
				SeparatorGuides = SeparatorGuides == null ? null : new List<SeparatorGuide>(SeparatorGuides),
				FoldRegions = FoldRegions == null ? null : new List<FoldRegion>(FoldRegions),
				GutterIcons = CopyMap(GutterIcons),
				PhantomTexts = CopyMap(PhantomTexts),
				CodeLensItems = CopyMap(CodeLensItems),
				Links = CopyMap(Links),
				SyntaxSpansMode = SyntaxSpansMode,
				SemanticSpansMode = SemanticSpansMode,
				InlayHintsMode = InlayHintsMode,
				DiagnosticsMode = DiagnosticsMode,
				DocumentHighlightsMode = DocumentHighlightsMode,
				IndentGuidesMode = IndentGuidesMode,
				BracketGuidesMode = BracketGuidesMode,
				FlowGuidesMode = FlowGuidesMode,
				SeparatorGuidesMode = SeparatorGuidesMode,
				FoldRegionsMode = FoldRegionsMode,
				GutterIconsMode = GutterIconsMode,
				PhantomTextsMode = PhantomTextsMode,
				CodeLensItemsMode = CodeLensItemsMode,
				LinksMode = LinksMode,
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
	}

	internal sealed class DecorationProviderManager : IDisposable {
		private readonly SweetEditorControl editor;
		private readonly List<IDecorationProvider> providers = new();
		private readonly Dictionary<IDecorationProvider, ProviderState> states = new();
		private readonly System.Windows.Forms.Timer debounceTimer;
		private readonly System.Windows.Forms.Timer scrollRefreshTimer;

		private readonly List<TextChange> pendingTextChanges = new();
		private bool applyScheduled;
		private int generation;
		private IntRange lastVisibleLineRange = new(0, -1);
		private bool scrollRefreshScheduled;
		private bool pendingScrollRefresh;
		private long lastScrollRefreshTickMs;
		private bool disposed;

		public DecorationProviderManager(SweetEditorControl editor) {
			this.editor = editor;
			debounceTimer = new System.Windows.Forms.Timer { Interval = 50 };
			debounceTimer.Tick += (_, _) => {
				debounceTimer.Stop();
				DoRefresh();
			};
			scrollRefreshTimer = new System.Windows.Forms.Timer { Interval = 1 };
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
		public void OnScrollChanged() => ScheduleScrollRefresh();
		public void OnTextChanged(List<TextChange>? changes) => ScheduleRefresh(50, changes);

		private void ScheduleRefresh(int delayMs, List<TextChange>? changes) {
			if (changes != null) {
				pendingTextChanges.AddRange(changes);
			}
			if (scrollRefreshScheduled) {
				scrollRefreshTimer.Stop();
				scrollRefreshScheduled = false;
			}
			pendingScrollRefresh = false;
			debounceTimer.Stop();
			debounceTimer.Interval = Math.Max(1, delayMs == 0 ? 1 : delayMs);
			debounceTimer.Start();
		}

		private void ScheduleScrollRefresh() {
			long now = Environment.TickCount64;
			long elapsed = now - lastScrollRefreshTickMs;
			int minInterval = GetScrollRefreshMinIntervalMs();
			int delay = elapsed >= minInterval
				? 1
				: (int)Math.Max(1, minInterval - elapsed);
			if (scrollRefreshScheduled) {
				pendingScrollRefresh = true;
				return;
			}
			scrollRefreshScheduled = true;
			scrollRefreshTimer.Stop();
			scrollRefreshTimer.Interval = delay;
			scrollRefreshTimer.Start();
		}

		private void DoRefresh() {
			generation++;
			int currentGeneration = generation;

			var visible = editor.GetVisibleLineRange();
			lastVisibleLineRange = visible;
			var changes = new List<TextChange>(pendingTextChanges).AsReadOnly();
			pendingTextChanges.Clear();
			int total = editor.GetTotalLineCount();
			int contextStart = visible.Start;
			int contextEnd = visible.End;
			if (total > 0 && visible.End >= visible.Start) {
				int overscanLines = CalculateOverscanLines(visible.Start, visible.End);
				contextStart = Math.Max(0, visible.Start - overscanLines);
				contextEnd = Math.Min(total - 1, visible.End + overscanLines);
			}
			var context = new DecorationContext(
				new IntRange(contextStart, contextEnd),
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
					} catch {
					}
				});
			}
		}

		private void ScheduleApply() {
			if (disposed || applyScheduled || editor.IsDisposed || !editor.IsHandleCreated) return;
			applyScheduled = true;
			try {
				editor.BeginInvoke(new Action(ApplyMerged));
			} catch (ObjectDisposedException) {
				applyScheduled = false;
			} catch (InvalidOperationException) {
				applyScheduled = false;
			}
		}

		private void ApplyMerged() {
			applyScheduled = false;

			var syntaxSpans = new Dictionary<int, List<StyleSpan>>();
			var semanticSpans = new Dictionary<int, List<StyleSpan>>();
			var inlayHints = new Dictionary<int, List<InlayHint>>();
			var diagnostics = new Dictionary<int, List<Diagnostic>>();
			var documentHighlights = new Dictionary<int, List<DocumentHighlight>>();
			List<IndentGuide>? indentGuides = null;
			List<BracketGuide>? bracketGuides = null;
			List<FlowGuide>? flowGuides = null;
			List<SeparatorGuide>? separatorGuides = null;
			var foldRegions = new List<FoldRegion>();
			var gutterIcons = new Dictionary<int, List<GutterIcon>>();
			var phantomTexts = new Dictionary<int, List<PhantomText>>();
			var codeLensItems = new Dictionary<int, List<CodeLensItem>>();
			var links = new Dictionary<int, List<LinkSpan>>();
			DecorationApplyMode syntaxMode = DecorationApplyMode.MERGE;
			DecorationApplyMode semanticMode = DecorationApplyMode.MERGE;
			DecorationApplyMode inlayMode = DecorationApplyMode.MERGE;
			DecorationApplyMode diagnosticMode = DecorationApplyMode.MERGE;
			DecorationApplyMode documentHighlightMode = DecorationApplyMode.MERGE;
			DecorationApplyMode indentMode = DecorationApplyMode.MERGE;
			DecorationApplyMode bracketMode = DecorationApplyMode.MERGE;
			DecorationApplyMode flowMode = DecorationApplyMode.MERGE;
			DecorationApplyMode separatorMode = DecorationApplyMode.MERGE;
			DecorationApplyMode foldMode = DecorationApplyMode.MERGE;
			DecorationApplyMode gutterMode = DecorationApplyMode.MERGE;
			DecorationApplyMode phantomMode = DecorationApplyMode.MERGE;
			DecorationApplyMode codeLensMode = DecorationApplyMode.MERGE;
			DecorationApplyMode linksMode = DecorationApplyMode.MERGE;

			foreach (var provider in providers) {
				if (!states.TryGetValue(provider, out var st) || st.Snapshot == null) continue;
				var r = st.Snapshot;
				syntaxMode = MergeMode(syntaxMode, r.SyntaxSpansMode);
				if (r.SyntaxSpans != null) {
					AppendMap(syntaxSpans, r.SyntaxSpans);
				}
				semanticMode = MergeMode(semanticMode, r.SemanticSpansMode);
				if (r.SemanticSpans != null) {
					AppendMap(semanticSpans, r.SemanticSpans);
				}
				inlayMode = MergeMode(inlayMode, r.InlayHintsMode);
				if (r.InlayHints != null) {
					AppendMap(inlayHints, r.InlayHints);
				}
				diagnosticMode = MergeMode(diagnosticMode, r.DiagnosticsMode);
				if (r.Diagnostics != null) {
					AppendMap(diagnostics, r.Diagnostics);
				}
				documentHighlightMode = MergeMode(documentHighlightMode, r.DocumentHighlightsMode);
				if (r.DocumentHighlights != null) {
					AppendMap(documentHighlights, r.DocumentHighlights);
				}
				gutterMode = MergeMode(gutterMode, r.GutterIconsMode);
				if (r.GutterIcons != null) {
					AppendMap(gutterIcons, r.GutterIcons);
				}
				phantomMode = MergeMode(phantomMode, r.PhantomTextsMode);
				if (r.PhantomTexts != null) {
					AppendMap(phantomTexts, r.PhantomTexts);
				}
				codeLensMode = MergeMode(codeLensMode, r.CodeLensItemsMode);
				if (r.CodeLensItems != null) {
					AppendMap(codeLensItems, r.CodeLensItems);
				}
				linksMode = MergeMode(linksMode, r.LinksMode);
				if (r.Links != null) {
					AppendMap(links, r.Links);
				}

				indentMode = MergeMode(indentMode, r.IndentGuidesMode);
				if (r.IndentGuides != null) {
					indentGuides = new List<IndentGuide>(r.IndentGuides);
				}
				bracketMode = MergeMode(bracketMode, r.BracketGuidesMode);
				if (r.BracketGuides != null) {
					bracketGuides = new List<BracketGuide>(r.BracketGuides);
				}
				flowMode = MergeMode(flowMode, r.FlowGuidesMode);
				if (r.FlowGuides != null) {
					flowGuides = new List<FlowGuide>(r.FlowGuides);
				}
				separatorMode = MergeMode(separatorMode, r.SeparatorGuidesMode);
				if (r.SeparatorGuides != null) {
					separatorGuides = new List<SeparatorGuide>(r.SeparatorGuides);
				}
				foldMode = MergeMode(foldMode, r.FoldRegionsMode);
				if (r.FoldRegions != null) {
					foldRegions.AddRange(r.FoldRegions);
				}
			}

			ApplySpanMode(SpanLayer.SYNTAX, syntaxMode);
			ApplySpanMode(SpanLayer.SEMANTIC, semanticMode);
			ApplySpans(syntaxSpans, SpanLayer.SYNTAX);
			ApplySpans(semanticSpans, SpanLayer.SEMANTIC);

			ApplyInlayMode(inlayMode);
			foreach (var (line, items) in inlayHints) {
				editor.SetLineInlayHints(line, items);
			}

			ApplyDiagnosticMode(diagnosticMode);
			foreach (var (line, items) in diagnostics) {
				editor.SetLineDiagnostics(line, items);
			}

			ApplyDocumentHighlightMode(documentHighlightMode);
			foreach (var (line, items) in documentHighlights) {
				editor.SetLineDocumentHighlights(line, items);
			}

			if (indentMode == DecorationApplyMode.REPLACE_ALL || indentMode == DecorationApplyMode.REPLACE_RANGE) {
				if (indentGuides != null) {
					editor.SetIndentGuides(indentGuides);
				} else {
					editor.SetIndentGuides(new List<IndentGuide>());
				}
			} else if (indentGuides != null) {
				editor.SetIndentGuides(indentGuides);
			}

			if (bracketMode == DecorationApplyMode.REPLACE_ALL || bracketMode == DecorationApplyMode.REPLACE_RANGE) {
				if (bracketGuides != null) {
					editor.SetBracketGuides(bracketGuides);
				} else {
					editor.SetBracketGuides(new List<BracketGuide>());
				}
			} else if (bracketGuides != null) {
				editor.SetBracketGuides(bracketGuides);
			}

			if (flowMode == DecorationApplyMode.REPLACE_ALL || flowMode == DecorationApplyMode.REPLACE_RANGE) {
				if (flowGuides != null) {
					editor.SetFlowGuides(flowGuides);
				} else {
					editor.SetFlowGuides(new List<FlowGuide>());
				}
			} else if (flowGuides != null) {
				editor.SetFlowGuides(flowGuides);
			}

			if (separatorMode == DecorationApplyMode.REPLACE_ALL || separatorMode == DecorationApplyMode.REPLACE_RANGE) {
				if (separatorGuides != null) {
					editor.SetSeparatorGuides(separatorGuides);
				} else {
					editor.SetSeparatorGuides(new List<SeparatorGuide>());
				}
			} else if (separatorGuides != null) {
				editor.SetSeparatorGuides(separatorGuides);
			}

			if (foldMode == DecorationApplyMode.REPLACE_ALL || foldMode == DecorationApplyMode.REPLACE_RANGE) {
				editor.SetFoldRegions(foldRegions);
			} else if (foldRegions.Count > 0) {
				editor.SetFoldRegions(foldRegions);
			}

			ApplyGutterMode(gutterMode);
			foreach (var (line, icons) in gutterIcons) {
				editor.SetLineGutterIcons(line, icons);
			}

			ApplyPhantomMode(phantomMode);
			foreach (var (line, items) in phantomTexts) {
				editor.SetLinePhantomTexts(line, items);
			}

			ApplyCodeLensMode(codeLensMode);
			foreach (var (line, items) in codeLensItems) {
				editor.SetLineCodeLens(line, items);
			}

			ApplyLinksMode(linksMode);
			foreach (var (line, items) in links) {
				editor.SetLineLinks(line, items);
			}

			editor.Flush();
		}

		private void ApplySpanMode(SpanLayer layer, DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearHighlights(layer);
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearSpanRange(layer, lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyInlayMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearInlayHints();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearInlayRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyDiagnosticMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearDiagnostics();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearDiagnosticRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyDocumentHighlightMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearDocumentHighlights();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearDocumentHighlightRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyGutterMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearGutterIcons();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearGutterRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyPhantomMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearPhantomTexts();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearPhantomRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyCodeLensMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearCodeLens();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearCodeLensRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ApplyLinksMode(DecorationApplyMode mode) {
			if (mode == DecorationApplyMode.REPLACE_ALL) {
				editor.ClearLinks();
			} else if (mode == DecorationApplyMode.REPLACE_RANGE) {
				ClearLinksRange(lastVisibleLineRange.Start, lastVisibleLineRange.End);
			}
		}

		private void ClearSpanRange(SpanLayer layer, int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<StyleSpan>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineSpans(layer, empty);
		}

		private void ClearInlayRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<InlayHint>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineInlayHints(empty);
		}

		private void ClearDiagnosticRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<Diagnostic>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineDiagnostics(empty);
		}

		private void ClearDocumentHighlightRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<DocumentHighlight>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineDocumentHighlights(empty);
		}

		private void ClearGutterRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<GutterIcon>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineGutterIcons(empty);
		}

		private void ClearPhantomRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<PhantomText>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLinePhantomTexts(empty);
		}

		private void ClearCodeLensRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<CodeLensItem>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineCodeLens(empty);
		}

		private void ClearLinksRange(int startLine, int endLine) {
			var empty = BuildEmptyRangeMap<LinkSpan>(startLine, endLine);
			if (empty.Count == 0) return;
			editor.SetBatchLineLinks(empty);
		}

		private static Dictionary<int, IList<T>> BuildEmptyRangeMap<T>(int startLine, int endLine) {
			var outMap = new Dictionary<int, IList<T>>();
			if (endLine < startLine) return outMap;
			IList<T> empty = Array.Empty<T>();
			for (int line = startLine; line <= endLine; line++) {
				outMap[line] = empty;
			}
			return outMap;
		}

		private static DecorationApplyMode MergeMode(DecorationApplyMode current, DecorationApplyMode next) {
			return ModePriority(next) > ModePriority(current) ? next : current;
		}

		private static int ModePriority(DecorationApplyMode mode) {
			return mode switch {
				DecorationApplyMode.MERGE => 0,
				DecorationApplyMode.REPLACE_RANGE => 1,
				DecorationApplyMode.REPLACE_ALL => 2,
				_ => 0
			};
		}

		private int GetScrollRefreshMinIntervalMs() {
			return Math.Max(0, editor.Settings.GetDecorationScrollRefreshMinIntervalMs());
		}

		private int CalculateOverscanLines(int visibleStart, int visibleEnd) {
			int viewportLineCount = visibleEnd >= visibleStart ? (visibleEnd - visibleStart + 1) : 0;
			if (viewportLineCount <= 0) return 0;
			float multiplier = Math.Max(0f, editor.Settings.GetDecorationOverscanViewportMultiplier());
			return Math.Max(0, (int)Math.Ceiling(viewportLineCount * multiplier));
		}

		public void Dispose() {
			if (disposed) return;
			disposed = true;
			debounceTimer.Stop();
			debounceTimer.Dispose();
			scrollRefreshTimer.Stop();
			scrollRefreshTimer.Dispose();
			generation++;
			foreach (var state in states.Values) {
				state.ActiveReceiver?.Cancel();
			}
			providers.Clear();
			states.Clear();
			pendingTextChanges.Clear();
			applyScheduled = false;
			scrollRefreshScheduled = false;
			pendingScrollRefresh = false;
		}

		private void ApplySpans(Dictionary<int, List<StyleSpan>> map, SpanLayer layer) {
			foreach (var (line, spans) in map) {
				editor.SetLineSpans(line, layer, spans);
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
			if (patch.SyntaxSpans != null) {
				target.SyntaxSpans = patch.SyntaxSpans;
				target.SyntaxSpansMode = patch.SyntaxSpansMode;
			} else if (patch.SyntaxSpansMode != DecorationApplyMode.MERGE) {
				target.SyntaxSpans = null;
				target.SyntaxSpansMode = patch.SyntaxSpansMode;
			}
			if (patch.SemanticSpans != null) {
				target.SemanticSpans = patch.SemanticSpans;
				target.SemanticSpansMode = patch.SemanticSpansMode;
			} else if (patch.SemanticSpansMode != DecorationApplyMode.MERGE) {
				target.SemanticSpans = null;
				target.SemanticSpansMode = patch.SemanticSpansMode;
			}
			if (patch.InlayHints != null) {
				target.InlayHints = patch.InlayHints;
				target.InlayHintsMode = patch.InlayHintsMode;
			} else if (patch.InlayHintsMode != DecorationApplyMode.MERGE) {
				target.InlayHints = null;
				target.InlayHintsMode = patch.InlayHintsMode;
			}
			if (patch.Diagnostics != null) {
				target.Diagnostics = patch.Diagnostics;
				target.DiagnosticsMode = patch.DiagnosticsMode;
			} else if (patch.DiagnosticsMode != DecorationApplyMode.MERGE) {
				target.Diagnostics = null;
				target.DiagnosticsMode = patch.DiagnosticsMode;
			}
			if (patch.DocumentHighlights != null) {
				target.DocumentHighlights = patch.DocumentHighlights;
				target.DocumentHighlightsMode = patch.DocumentHighlightsMode;
			} else if (patch.DocumentHighlightsMode != DecorationApplyMode.MERGE) {
				target.DocumentHighlights = null;
				target.DocumentHighlightsMode = patch.DocumentHighlightsMode;
			}
			if (patch.IndentGuides != null) {
				target.IndentGuides = patch.IndentGuides;
				target.IndentGuidesMode = patch.IndentGuidesMode;
			} else if (patch.IndentGuidesMode != DecorationApplyMode.MERGE) {
				target.IndentGuides = null;
				target.IndentGuidesMode = patch.IndentGuidesMode;
			}
			if (patch.BracketGuides != null) {
				target.BracketGuides = patch.BracketGuides;
				target.BracketGuidesMode = patch.BracketGuidesMode;
			} else if (patch.BracketGuidesMode != DecorationApplyMode.MERGE) {
				target.BracketGuides = null;
				target.BracketGuidesMode = patch.BracketGuidesMode;
			}
			if (patch.FlowGuides != null) {
				target.FlowGuides = patch.FlowGuides;
				target.FlowGuidesMode = patch.FlowGuidesMode;
			} else if (patch.FlowGuidesMode != DecorationApplyMode.MERGE) {
				target.FlowGuides = null;
				target.FlowGuidesMode = patch.FlowGuidesMode;
			}
			if (patch.SeparatorGuides != null) {
				target.SeparatorGuides = patch.SeparatorGuides;
				target.SeparatorGuidesMode = patch.SeparatorGuidesMode;
			} else if (patch.SeparatorGuidesMode != DecorationApplyMode.MERGE) {
				target.SeparatorGuides = null;
				target.SeparatorGuidesMode = patch.SeparatorGuidesMode;
			}
			if (patch.FoldRegions != null) {
				target.FoldRegions = patch.FoldRegions;
				target.FoldRegionsMode = patch.FoldRegionsMode;
			} else if (patch.FoldRegionsMode != DecorationApplyMode.MERGE) {
				target.FoldRegions = null;
				target.FoldRegionsMode = patch.FoldRegionsMode;
			}
			if (patch.GutterIcons != null) {
				target.GutterIcons = patch.GutterIcons;
				target.GutterIconsMode = patch.GutterIconsMode;
			} else if (patch.GutterIconsMode != DecorationApplyMode.MERGE) {
				target.GutterIcons = null;
				target.GutterIconsMode = patch.GutterIconsMode;
			}
			if (patch.PhantomTexts != null) {
				target.PhantomTexts = patch.PhantomTexts;
				target.PhantomTextsMode = patch.PhantomTextsMode;
			} else if (patch.PhantomTextsMode != DecorationApplyMode.MERGE) {
				target.PhantomTexts = null;
				target.PhantomTextsMode = patch.PhantomTextsMode;
			}
			if (patch.CodeLensItems != null) {
				target.CodeLensItems = patch.CodeLensItems;
				target.CodeLensItemsMode = patch.CodeLensItemsMode;
			} else if (patch.CodeLensItemsMode != DecorationApplyMode.MERGE) {
				target.CodeLensItems = null;
				target.CodeLensItemsMode = patch.CodeLensItemsMode;
			}
			if (patch.Links != null) {
				target.Links = patch.Links;
				target.LinksMode = patch.LinksMode;
			} else if (patch.LinksMode != DecorationApplyMode.MERGE) {
				target.Links = null;
				target.LinksMode = patch.LinksMode;
			}
		}

		private sealed class ProviderState {
			public DecorationResult? Snapshot;
			public ManagedReceiver? ActiveReceiver;
			public SemaphoreSlim Gate { get; } = new(1, 1);
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
				if (manager.editor.IsDisposed || !manager.editor.IsHandleCreated) return false;
				try {
					manager.editor.BeginInvoke(new Action(() => {
						if (cancelled || receiverGeneration != manager.generation) return;
						manager.OnReceiverAccept(provider, receiverGeneration, snapshot);
					}));
				} catch (ObjectDisposedException) {
					return false;
				} catch (InvalidOperationException) {
					return false;
				}
				return true;
			}

			public bool IsCancelled => cancelled || receiverGeneration != manager.generation;

			public void Cancel() => cancelled = true;
		}
	}


}
