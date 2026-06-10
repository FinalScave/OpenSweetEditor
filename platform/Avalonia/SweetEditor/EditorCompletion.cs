using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Controls.Primitives.PopupPositioning;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;

namespace SweetEditor {
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
		public TextEdit? TextEdit { get; set; }
		public List<TextEdit> AdditionalTextEdits { get; } = new();
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
		Control? CreateItemView(CompletionItem item, bool isSelected, EditorTheme theme);
	}

	internal sealed class CompletionPopupController : IDisposable {
		private const int MaxVisibleItems = 6;
		private const double DefaultItemHeight = 32;
		private const double PopupWidth = 300;
		private const double PopupMinWidth = 160;
		private const double PopupMargin = 6;
		private const double PopupGap = 4;
		private const double BadgeSize = 18;

		private readonly SweetEditorControl editor;
		private readonly List<CompletionItem> items = new();
		private Popup? popup;
		private Border? chrome;
		private ScrollViewer? scrollViewer;
		private StackPanel? itemPanel;
		private ICompletionItemRenderer? renderer;
		private EditorTheme theme;
		private int selectedIndex = -1;
		private bool disposed;

		public CompletionPopupController(SweetEditorControl editor, EditorTheme theme) {
			this.editor = editor;
			this.theme = theme;
		}

		public event Action<CompletionItem>? Confirmed;

		public bool IsShowing => popup?.IsOpen == true;

		private double ItemHeight => Math.Max(20, renderer?.ItemHeight ?? DefaultItemHeight);

		public void ApplyTheme(EditorTheme theme) {
			this.theme = theme;
			ApplyThemeToChrome();
			if (IsShowing) {
				RenderItems();
			}
		}

		public void SetRenderer(ICompletionItemRenderer? renderer) {
			this.renderer = renderer;
			if (IsShowing) {
				RenderItems();
				UpdatePosition();
			}
		}

		public void UpdateItems(IReadOnlyList<CompletionItem> newItems) {
			if (disposed) {
				return;
			}

			items.Clear();
			items.AddRange(newItems);
			selectedIndex = items.Count > 0 ? 0 : -1;
			if (items.Count == 0) {
				Dismiss();
				return;
			}

			EnsurePopup();
			RenderItems();
			UpdatePosition();
		}

		public bool HandleKey(Key key) {
			if (!IsShowing || items.Count == 0) {
				return false;
			}

			switch (key) {
			case Key.Enter:
				ConfirmSelected();
				return true;
			case Key.Up:
				MoveSelection(-1);
				return true;
			case Key.Down:
				MoveSelection(1);
				return true;
			case Key.Escape:
				Dismiss();
				return true;
			default:
				return false;
			}
		}

		public void UpdatePosition() {
			if (disposed || popup == null || items.Count == 0) {
				return;
			}

			Avalonia.Rect viewport = editor.GetPopupViewportRect();
			if (viewport.Width <= 0 || viewport.Height <= 0) {
				Dismiss();
				return;
			}

			CursorRect cursor = editor.GetCursorRect();
			double width = Math.Min(PopupWidth, Math.Max(PopupMinWidth, viewport.Width - PopupMargin * 2));
			width = Math.Max(1, Math.Min(width, viewport.Width));

			double visibleCount = Math.Min(Math.Max(items.Count, 1), MaxVisibleItems);
			double popupHeight = Math.Min(ItemHeight * visibleCount + 12, Math.Max(ItemHeight + 12, viewport.Height - PopupMargin * 2));
			double maxX = Math.Max(viewport.X, viewport.Right - width);
			double maxY = Math.Max(viewport.Y, viewport.Bottom - popupHeight);
			double x = Math.Clamp(cursor.X, viewport.X, maxX);
			double below = cursor.Y + Math.Max(1f, cursor.Height) + PopupGap;
			double above = cursor.Y - popupHeight - PopupGap;
			double y = below + popupHeight <= viewport.Bottom
				? below
				: above >= viewport.Y
					? above
					: Math.Clamp(below, viewport.Y, maxY);

			if (chrome != null) {
				chrome.Width = width;
				chrome.MaxHeight = popupHeight;
			}
			if (scrollViewer != null) {
				scrollViewer.MaxHeight = Math.Max(ItemHeight, popupHeight - 12);
			}

			popup.PlacementTarget = editor;
			popup.PlacementRect = new Avalonia.Rect(x, y, 1, Math.Max(1f, cursor.Height));
			if (editor.IsMounted && !popup.IsOpen) {
				popup.IsOpen = true;
			}
		}

		public void Dismiss() {
			if (popup != null) {
				popup.IsOpen = false;
			}
		}

		public void Dispose() {
			if (disposed) {
				return;
			}
			disposed = true;
			Confirmed = null;
			items.Clear();
			if (popup != null) {
				popup.IsOpen = false;
				popup.Child = null;
				popup = null;
			}
			chrome = null;
			scrollViewer = null;
			itemPanel = null;
			renderer = null;
		}

		private void EnsurePopup() {
			if (popup != null) {
				return;
			}

			itemPanel = new StackPanel {
				Spacing = 0,
			};
			scrollViewer = new ScrollViewer {
				Content = itemPanel,
				HorizontalScrollBarVisibility = ScrollBarVisibility.Disabled,
				VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
			};
			chrome = new Border {
				Padding = new Thickness(4, 6),
				CornerRadius = new CornerRadius(8),
				BorderThickness = new Thickness(1),
				Child = scrollViewer,
			};
			ApplyThemeToChrome();

			popup = new Popup {
				PlacementTarget = editor,
				Placement = PlacementMode.AnchorAndGravity,
				PlacementAnchor = PopupAnchor.TopLeft,
				PlacementGravity = PopupGravity.TopLeft,
				IsLightDismissEnabled = true,
				OverlayDismissEventPassThrough = true,
				Topmost = true,
				Child = chrome,
			};
		}

		private void ApplyThemeToChrome() {
			if (chrome == null) {
				return;
			}

			chrome.Background = new SolidColorBrush(Color.FromUInt32(theme.CompletionBgColor));
			chrome.BorderBrush = new SolidColorBrush(Color.FromUInt32(theme.CompletionBorderColor));
		}

		private void RenderItems() {
			if (itemPanel == null) {
				return;
			}

			itemPanel.Children.Clear();
			for (int i = 0; i < items.Count; i++) {
				itemPanel.Children.Add(BuildItemView(items[i], i == selectedIndex, i));
			}
			EnsureSelectedItemVisible();
		}

		private Control BuildItemView(CompletionItem item, bool selected, int index) {
			Control content = BuildItemContent(item, selected);
			var button = new Button {
				Background = Brushes.Transparent,
				BorderBrush = Brushes.Transparent,
				BorderThickness = new Thickness(0),
				Padding = new Thickness(0),
				MinHeight = ItemHeight,
				HorizontalAlignment = HorizontalAlignment.Stretch,
				HorizontalContentAlignment = HorizontalAlignment.Stretch,
				Content = content,
			};
			button.Click += (_, _) => ConfirmAt(index);
			button.AddHandler(InputElement.PointerPressedEvent, (_, e) => {
				if (!editor.IsPrimaryPointerPress(button, e)) {
					return;
				}
				e.Handled = true;
				ConfirmAt(index);
			}, RoutingStrategies.Tunnel);
			return button;
		}

		private Control BuildItemContent(CompletionItem item, bool selected) {
			if (renderer != null) {
				try {
					Control? custom = renderer.CreateItemView(item, selected, theme);
					if (custom != null) {
						return custom;
					}
				} catch (Exception ex) {
					Console.Error.WriteLine($"Completion item renderer error: {ex.Message}");
				}
			}

			string detailText = !string.IsNullOrWhiteSpace(item.Detail)
				? item.Detail!
				: KindText(item.Kind);

			var badge = new Border {
				Width = BadgeSize,
				Height = BadgeSize,
				CornerRadius = new CornerRadius(6),
				Background = new SolidColorBrush(KindColor(item.Kind)),
				Child = new TextBlock {
					Text = KindLetter(item.Kind),
					FontSize = 10,
					FontWeight = FontWeight.Bold,
					Foreground = Brushes.White,
					HorizontalAlignment = HorizontalAlignment.Center,
					VerticalAlignment = VerticalAlignment.Center,
					TextAlignment = TextAlignment.Center,
				},
			};

			var row = new Grid {
				ColumnDefinitions = new ColumnDefinitions("Auto,*,Auto"),
				ColumnSpacing = 8,
				HorizontalAlignment = HorizontalAlignment.Stretch,
				VerticalAlignment = VerticalAlignment.Center,
			};
			row.Children.Add(badge);

			var label = new TextBlock {
				Text = item.Label,
				FontSize = 13,
				FontWeight = FontWeight.Medium,
				TextTrimming = TextTrimming.CharacterEllipsis,
				Foreground = new SolidColorBrush(Color.FromUInt32(theme.CompletionLabelColor)),
				VerticalAlignment = VerticalAlignment.Center,
			};
			Grid.SetColumn(label, 1);
			row.Children.Add(label);

			var detail = new TextBlock {
				Text = detailText,
				FontSize = 11,
				TextTrimming = TextTrimming.CharacterEllipsis,
				Foreground = new SolidColorBrush(Color.FromUInt32(theme.CompletionDetailColor)),
				VerticalAlignment = VerticalAlignment.Center,
				TextAlignment = TextAlignment.Right,
				HorizontalAlignment = HorizontalAlignment.Right,
				MaxWidth = 108,
			};
			Grid.SetColumn(detail, 2);
			row.Children.Add(detail);

			var rowChrome = new Border {
				Background = selected ? new SolidColorBrush(Color.FromUInt32(theme.CompletionSelectedBgColor)) : Brushes.Transparent,
				CornerRadius = new CornerRadius(6),
				MinHeight = ItemHeight,
				Padding = new Thickness(8, 2),
				HorizontalAlignment = HorizontalAlignment.Stretch,
				Child = row,
			};
			return rowChrome;
		}

		private void ConfirmAt(int index) {
			if (index < 0 || index >= items.Count) {
				return;
			}

			selectedIndex = index;
			CompletionItem item = items[index];
			Dismiss();
			Confirmed?.Invoke(item);
		}

		private void ConfirmSelected() {
			ConfirmAt(selectedIndex);
		}

		private void MoveSelection(int delta) {
			if (items.Count == 0) {
				return;
			}

			int nextIndex = Math.Clamp(selectedIndex + delta, 0, items.Count - 1);
			if (nextIndex == selectedIndex) {
				return;
			}

			selectedIndex = nextIndex;
			RenderItems();
		}

		private void EnsureSelectedItemVisible() {
			if (scrollViewer == null || selectedIndex < 0) {
				return;
			}

			double itemTop = selectedIndex * ItemHeight;
			double itemBottom = itemTop + ItemHeight;
			double viewportTop = scrollViewer.Offset.Y;
			double viewportBottom = viewportTop + scrollViewer.Viewport.Height;
			if (itemTop < viewportTop) {
				scrollViewer.Offset = new Vector(0, itemTop);
			} else if (itemBottom > viewportBottom) {
				scrollViewer.Offset = new Vector(0, Math.Max(0, itemBottom - scrollViewer.Viewport.Height));
			}
		}

		private static Color KindColor(int kind) => kind switch {
			CompletionItem.KIND_KEYWORD => Color.FromRgb(0xC6, 0x78, 0xDD),
			CompletionItem.KIND_FUNCTION => Color.FromRgb(0x61, 0xAF, 0xEF),
			CompletionItem.KIND_VARIABLE => Color.FromRgb(0xE5, 0xC0, 0x7B),
			CompletionItem.KIND_CLASS => Color.FromRgb(0xE0, 0x6C, 0x75),
			CompletionItem.KIND_INTERFACE => Color.FromRgb(0x56, 0xB6, 0xC2),
			CompletionItem.KIND_MODULE => Color.FromRgb(0xD1, 0x9A, 0x66),
			CompletionItem.KIND_PROPERTY => Color.FromRgb(0x98, 0xC3, 0x79),
			CompletionItem.KIND_SNIPPET => Color.FromRgb(0xBE, 0x50, 0x46),
			_ => Color.FromRgb(0x7A, 0x84, 0x94),
		};

		private static string KindLetter(int kind) => kind switch {
			CompletionItem.KIND_KEYWORD => "K",
			CompletionItem.KIND_FUNCTION => "F",
			CompletionItem.KIND_VARIABLE => "V",
			CompletionItem.KIND_CLASS => "C",
			CompletionItem.KIND_INTERFACE => "I",
			CompletionItem.KIND_MODULE => "M",
			CompletionItem.KIND_PROPERTY => "P",
			CompletionItem.KIND_SNIPPET => "S",
			_ => "T",
		};

		private static string KindText(int kind) => kind switch {
			CompletionItem.KIND_KEYWORD => "keyword",
			CompletionItem.KIND_FUNCTION => "function",
			CompletionItem.KIND_VARIABLE => "variable",
			CompletionItem.KIND_CLASS => "class",
			CompletionItem.KIND_INTERFACE => "interface",
			CompletionItem.KIND_MODULE => "module",
			CompletionItem.KIND_PROPERTY => "property",
			CompletionItem.KIND_SNIPPET => "snippet",
			_ => "text",
		};
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
