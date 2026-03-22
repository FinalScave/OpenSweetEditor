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
		/// <summary>Current editor metadata (from EditorControl).</summary>
		public IEditorMetadata? EditorMetadata { get; }

		public CompletionContext(CompletionTriggerKind triggerKind, string? triggerCharacter,
								 TextPosition cursorPosition, string lineText, TextRange? wordRange,
								 LanguageConfiguration? languageConfiguration = null,
								 IEditorMetadata? editorMetadata = null) {
			TriggerKind = triggerKind;
			TriggerCharacter = triggerCharacter;
			CursorPosition = cursorPosition;
			LineText = lineText;
			WordRange = wordRange;
			LanguageConfiguration = languageConfiguration;
			EditorMetadata = editorMetadata;
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
			return new CompletionContext(
				kind,
				triggerChar,
				cursor,
				lineText,
				wordRange,
				editor.GetLanguageConfiguration(),
				editor.Metadata);
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
