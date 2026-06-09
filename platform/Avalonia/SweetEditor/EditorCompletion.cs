using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Threading;

namespace SweetEditor {
	public sealed class CompletionTextEdit {
		public TextRange Range { get; }
		public string NewText { get; }

		public CompletionTextEdit(TextRange range, string newText) {
			Range = range;
			NewText = newText ?? string.Empty;
		}
	}

	public class CompletionItem {
		public const int KIND_KEYWORD = 0;
		public const int KIND_FUNCTION = 1;
		public const int KIND_VARIABLE = 2;
		public const int KIND_CLASS = 3;
		public const int KIND_INTERFACE = 4;
		public const int KIND_MODULE = 5;
		public const int KIND_PROPERTY = 6;
		public const int KIND_SNIPPET = 7;
		public const int KIND_TEXT = 8;

		public const int INSERT_TEXT_FORMAT_PLAIN_TEXT = 1;
		public const int INSERT_TEXT_FORMAT_SNIPPET = 2;

		public string Label { get; set; } = string.Empty;
		public string? Detail { get; set; }
		public string? InsertText { get; set; }
		public int InsertTextFormat { get; set; } = INSERT_TEXT_FORMAT_PLAIN_TEXT;
		public CompletionTextEdit? TextEdit { get; set; }
		public string? FilterText { get; set; }
		public string? SortKey { get; set; }
		public int Kind { get; set; }
	}

	public enum CompletionTriggerKind {
		Invoked = 0,
		Character = 1,
		Retrigger = 2,
	}

	public sealed class CompletionContext {
		public CompletionTriggerKind TriggerKind { get; }
		public string? TriggerCharacter { get; }
		public TextPosition CursorPosition { get; }
		public string LineText { get; }
		public TextRange? WordRange { get; }
		public LanguageConfiguration? LanguageConfiguration { get; }
		public IEditorMetadata? EditorMetadata { get; }

		public CompletionContext(
			CompletionTriggerKind triggerKind,
			string? triggerCharacter,
			TextPosition cursorPosition,
			string lineText,
			TextRange? wordRange,
			LanguageConfiguration? languageConfiguration,
			IEditorMetadata? editorMetadata) {
			TriggerKind = triggerKind;
			TriggerCharacter = triggerCharacter;
			CursorPosition = cursorPosition;
			LineText = lineText;
			WordRange = wordRange;
			LanguageConfiguration = languageConfiguration;
			EditorMetadata = editorMetadata;
		}
	}

	public sealed class CompletionResult {
		public List<CompletionItem> Items { get; }
		public bool IsIncomplete { get; }

		public CompletionResult(List<CompletionItem> items, bool isIncomplete = false) {
			Items = items;
			IsIncomplete = isIncomplete;
		}
	}

	public interface ICompletionReceiver {
		bool Accept(CompletionResult result);
		bool IsCancelled { get; }
	}

	public interface ICompletionProvider {
		bool IsTriggerCharacter(string ch);
		void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver);
	}

	public interface ICompletionItemRenderer {
		double ItemHeight { get; }
	}

	internal sealed class CompletionProviderManager : IDisposable {
		public event Action<IReadOnlyList<CompletionItem>>? ItemsUpdated;
		public event Action? Dismissed;

		private readonly List<ICompletionProvider> providers = new();
		private readonly Dictionary<ICompletionProvider, ManagedReceiver> activeReceivers = new();
		private readonly Dictionary<ICompletionProvider, SemaphoreSlim> providerGates = new();
		private readonly SweetEditorControl editor;
		private readonly DispatcherTimer debounceTimer;

		private int generation;
		private readonly List<CompletionItem> mergedItems = new();
		private CompletionTriggerKind lastTriggerKind;
		private string? lastTriggerChar;

		public CompletionProviderManager(SweetEditorControl editor) {
			this.editor = editor;
			debounceTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(50),
			};
			debounceTimer.Tick += (_, _) => {
				debounceTimer.Stop();
				ExecuteRefresh(lastTriggerKind, lastTriggerChar);
			};
		}

		public void AddProvider(ICompletionProvider provider) {
			if (provider == null) {
				return;
			}
			if (!providers.Contains(provider)) {
				providers.Add(provider);
				providerGates[provider] = new SemaphoreSlim(1, 1);
			}
		}

		public void RemoveProvider(ICompletionProvider provider) {
			if (provider == null) {
				return;
			}
			providers.Remove(provider);
			if (activeReceivers.TryGetValue(provider, out var receiver)) {
				receiver.Cancel();
				activeReceivers.Remove(provider);
			}
			providerGates.Remove(provider);
		}

		public void TriggerCompletion(CompletionTriggerKind kind, string? triggerChar) {
			if (providers.Count == 0) {
				return;
			}
			lastTriggerKind = kind;
			lastTriggerChar = triggerChar;
			debounceTimer.Stop();
			int delay = kind == CompletionTriggerKind.Invoked ? 1 : 50;
			debounceTimer.Interval = TimeSpan.FromMilliseconds(Math.Max(delay, 1));
			debounceTimer.Start();
		}

		public void Dismiss() {
			debounceTimer.Stop();
			generation++;
			CancelAllReceivers();
			mergedItems.Clear();
			Dismissed?.Invoke();
		}

		public bool IsTriggerCharacter(string ch) {
			foreach (var provider in providers) {
				if (provider.IsTriggerCharacter(ch)) {
					return true;
				}
			}
			return false;
		}

		public void ShowItems(List<CompletionItem> items) {
			debounceTimer.Stop();
			generation++;
			CancelAllReceivers();
			mergedItems.Clear();
			mergedItems.AddRange(items);
			ItemsUpdated?.Invoke(new List<CompletionItem>(mergedItems));
		}

		public void Dispose() {
			debounceTimer.Stop();
			generation++;
			CancelAllReceivers();
			mergedItems.Clear();
			providers.Clear();
			foreach (var sem in providerGates.Values) {
				sem.Dispose();
			}
			providerGates.Clear();
		}

		private void ExecuteRefresh(CompletionTriggerKind kind, string? triggerChar) {
			int currentGeneration = ++generation;
			CancelAllReceivers();
			mergedItems.Clear();

			var context = BuildContext(kind, triggerChar);
			if (context == null) {
				Dismiss();
				return;
			}

			foreach (var provider in providers) {
				var receiver = new ManagedReceiver(this, provider, currentGeneration);
				activeReceivers[provider] = receiver;

				SemaphoreSlim gate = providerGates.TryGetValue(provider, out var existing)
					? existing
					: (providerGates[provider] = new SemaphoreSlim(1, 1));

				_ = Task.Run(async () => {
					try {
						await gate.WaitAsync().ConfigureAwait(false);
						try {
							if (receiver.IsCancelled) {
								return;
							}
							provider.ProvideCompletions(context, receiver);
						} finally {
							gate.Release();
						}
					} catch (Exception ex) {
						Console.Error.WriteLine($"Completion provider error: {ex.Message}");
					}
				});
			}
		}

		private CompletionContext? BuildContext(CompletionTriggerKind kind, string? triggerChar) {
			var cursor = editor.GetCursorPosition();
			var doc = editor.GetDocument();
			string lineText = doc?.GetLineText(cursor.Line) ?? string.Empty;
			var wordRange = editor.GetWordRangeAtCursor();
			return new CompletionContext(
				kind,
				triggerChar,
				cursor,
				lineText,
				wordRange,
				editor.GetLanguageConfiguration(),
				editor.MetadataInternal);
		}

		private void CancelAllReceivers() {
			foreach (var receiver in activeReceivers.Values) {
				receiver.Cancel();
			}
			activeReceivers.Clear();
		}

		private void OnReceiverAccept(ICompletionProvider provider, CompletionResult result, int receiverGeneration) {
			if (receiverGeneration != generation) {
				return;
			}

			mergedItems.AddRange(result.Items);
			mergedItems.Sort((a, b) => string.Compare(a.SortKey ?? a.Label, b.SortKey ?? b.Label, StringComparison.Ordinal));

			if (mergedItems.Count == 0) {
				Dismissed?.Invoke();
			} else {
				ItemsUpdated?.Invoke(new List<CompletionItem>(mergedItems));
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

			public bool Accept(CompletionResult result) {
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
