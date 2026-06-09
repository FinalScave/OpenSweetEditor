using System;
using System.Collections.Generic;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Controls.Primitives.PopupPositioning;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using AvaloniaRect = Avalonia.Rect;
using Button = Avalonia.Controls.Button;
using Orientation = Avalonia.Layout.Orientation;

namespace SweetEditor {
	public sealed class SelectionMenuItem {
		public const string ACTION_CUT = "cut";
		public const string ACTION_COPY = "copy";
		public const string ACTION_PASTE = "paste";
		public const string ACTION_SELECT_ALL = "select_all";

		public string Id { get; }
		public string Label { get; }
		public bool Enabled { get; }

		public SelectionMenuItem(string id, string label, bool enabled = true) {
			Id = string.IsNullOrWhiteSpace(id) ? string.Empty : id;
			Label = label ?? string.Empty;
			Enabled = enabled;
		}
	}

	public interface ISelectionMenuItemProvider {
		IReadOnlyList<SelectionMenuItem> ProvideMenuItems(SweetEditorControl editor);
	}

	public interface ISelectionMenuListener {
		void OnSelectionMenuItemSelected(string itemId);
	}

	public sealed class SelectionMenuItemClickEventArgs : EditorEventArgs {
		public SelectionMenuItem Item { get; }

		public SelectionMenuItemClickEventArgs(SelectionMenuItem item)
			: base(EditorEventType.SelectionMenuItemClick) {
			Item = item;
		}
	}

	internal sealed class SelectionMenuController : IDisposable {
		private const int ShowDelayMs = 100;
		private const int ViewportRestoreDelayMs = 120;
		private const double VerticalOffset = 8;
		private const double HandleClearance = 32;
		private const double FallbackMenuWidth = 220;
		private const double FallbackMenuHeight = 40;

		private readonly SweetEditorControl editor;
		private readonly DispatcherTimer showTimer;
		private readonly DispatcherTimer viewportRestoreTimer;
		private Popup? popup;
		private ISelectionMenuItemProvider? itemProvider;
		private ISelectionMenuListener? listener;
		private bool hiddenByViewportGesture;
		private bool disposed;

		public event Action<SelectionMenuItem>? CustomItemSelected;

		public SelectionMenuController(SweetEditorControl editor) {
			this.editor = editor;
			showTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(ShowDelayMs),
			};
			showTimer.Tick += (_, _) => {
				showTimer.Stop();
				ShowNow();
			};

			viewportRestoreTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(ViewportRestoreDelayMs),
			};
			viewportRestoreTimer.Tick += (_, _) => {
				viewportRestoreTimer.Stop();
				if (disposed || !hiddenByViewportGesture) {
					return;
				}
				hiddenByViewportGesture = false;
				if (ShouldShowForCurrentState()) {
					ScheduleShow();
				}
			};
		}

		public bool IsShowing => popup?.IsOpen == true;

		public void SetItemProvider(ISelectionMenuItemProvider? provider) {
			itemProvider = provider;
			if (IsShowing && !hiddenByViewportGesture) {
				ScheduleShow();
			}
		}

		public void SetListener(ISelectionMenuListener? listener) {
			this.listener = listener;
		}

		public void ScheduleShow() {
			if (disposed || !editor.IsMounted || hiddenByViewportGesture) {
				return;
			}
			showTimer.Stop();
			showTimer.Start();
		}

		public void OnSelectionChanged(bool hasSelection) {
			if (disposed) {
				return;
			}

			if (!hasSelection && !editor.IsInlineSuggestionShowing()) {
				Dismiss();
				return;
			}

			if (hiddenByViewportGesture) {
				return;
			}

			if (IsShowing) {
				UpdatePosition();
				return;
			}

			ScheduleShow();
		}

		public void OnTextChanged() {
			hiddenByViewportGesture = false;
			viewportRestoreTimer.Stop();
			Dismiss();
		}

		public void OnEditorActionResult(EditorActionResult result) {
			if (disposed) {
				return;
			}

			switch (result.GestureType) {
				case GestureType.DOUBLE_TAP:
				case GestureType.LONG_PRESS:
					hiddenByViewportGesture = false;
					viewportRestoreTimer.Stop();
					if (result.HasSelectionAfter || editor.IsInlineSuggestionShowing()) {
						ScheduleShow();
					} else {
						Dismiss();
					}
					break;
				case GestureType.TAP:
					hiddenByViewportGesture = false;
					viewportRestoreTimer.Stop();
					if (result.HasSelectionAfter || editor.IsInlineSuggestionShowing()) {
						ScheduleShow();
					} else {
						Dismiss();
					}
					break;
				case GestureType.DRAG_SELECT:
					hiddenByViewportGesture = true;
					Dismiss();
					if (result.HasSelectionAfter || editor.IsInlineSuggestionShowing()) {
						ScheduleViewportRestore();
					}
					break;
				case GestureType.SCROLL:
				case GestureType.FAST_SCROLL:
				case GestureType.SCALE:
					hiddenByViewportGesture = true;
					Dismiss();
					if (result.HasSelectionAfter || editor.IsInlineSuggestionShowing()) {
						ScheduleViewportRestore();
					}
					break;
				default:
					if (hiddenByViewportGesture && (result.HasSelectionAfter || editor.IsInlineSuggestionShowing())) {
						ScheduleViewportRestore();
					}
					break;
			}
		}

		public void OnViewportGestureSettled() {
			if (disposed || !hiddenByViewportGesture) {
				return;
			}
			hiddenByViewportGesture = false;
			viewportRestoreTimer.Stop();
			if (ShouldShowForCurrentState()) {
				ScheduleShow();
			}
		}

		public void UpdatePosition() {
			if (disposed || popup == null) {
				return;
			}

			if (!editor.IsMounted) {
				Dismiss();
				return;
			}

			if (!TryComputeAnchorRect(out AvaloniaRect anchorRect)) {
				Dismiss();
				return;
			}

			popup.PlacementTarget = editor;
			popup.PlacementRect = anchorRect;
			if (!popup.IsOpen) {
				popup.IsOpen = true;
			}
		}

		public void Dismiss() {
			showTimer.Stop();
			if (popup != null) {
				popup.IsOpen = false;
			}
		}

		public void Dispose() {
			if (disposed) {
				return;
			}
			disposed = true;
			showTimer.Stop();
			viewportRestoreTimer.Stop();
			if (popup != null) {
				popup.IsOpen = false;
				popup.Child = null;
				popup = null;
			}
			listener = null;
			itemProvider = null;
		}

		private void ScheduleViewportRestore() {
			if (disposed) {
				return;
			}
			viewportRestoreTimer.Stop();
			viewportRestoreTimer.Start();
		}

		private bool ShouldShowForCurrentState() {
			var selection = editor.GetSelection();
			return selection.hasSelection || editor.IsInlineSuggestionShowing();
		}

		private void ShowNow() {
			if (disposed || !editor.IsMounted || hiddenByViewportGesture) {
				return;
			}

			if (!ShouldShowForCurrentState()) {
				Dismiss();
				return;
			}

			var items = BuildItems();
			if (items.Count == 0) {
				Dismiss();
				return;
			}

			EnsurePopup();
			RebuildPopupContent(items);
			UpdatePosition();
		}

		private IReadOnlyList<SelectionMenuItem> BuildItems() {
			bool hasSelection = editor.GetSelection().hasSelection;
			var merged = new List<SelectionMenuItem> {
				new(SelectionMenuItem.ACTION_CUT, "Cut", hasSelection),
				new(SelectionMenuItem.ACTION_COPY, "Copy", hasSelection),
				new(SelectionMenuItem.ACTION_PASTE, "Paste"),
				new(SelectionMenuItem.ACTION_SELECT_ALL, "Select All"),
			};

			if (itemProvider == null) {
				return merged;
			}

			try {
				var items = itemProvider.ProvideMenuItems(editor);
				if (items != null) {
					foreach (var item in items) {
						if (item == null || string.IsNullOrWhiteSpace(item.Id)) {
							continue;
						}

						int existingIndex = merged.FindIndex(existing => string.Equals(existing.Id, item.Id, StringComparison.Ordinal));
						if (existingIndex >= 0) {
							merged[existingIndex] = item;
						} else {
							merged.Add(item);
						}
					}
				}
			}
			catch (Exception ex) {
				Console.Error.WriteLine($"Selection menu item provider error: {ex.Message}");
			}

			return merged;
		}

		private void EnsurePopup() {
			if (popup != null) {
				return;
			}

				popup = new Popup {
					PlacementTarget = editor,
					Placement = PlacementMode.AnchorAndGravity,
					PlacementAnchor = PopupAnchor.TopLeft,
					PlacementGravity = PopupGravity.TopLeft,
					HorizontalOffset = 0,
					VerticalOffset = 0,
					IsLightDismissEnabled = true,
					OverlayDismissEventPassThrough = true,
					Topmost = true,
				};
			}

			private void RebuildPopupContent(IReadOnlyList<SelectionMenuItem> items) {
				if (popup == null) {
					return;
				}

			double maxWidth = Math.Max(180, editor.Bounds.Width - 12);
			var row = new WrapPanel {
				Orientation = Orientation.Horizontal,
				ItemSpacing = 4,
				LineSpacing = 4,
				MaxWidth = maxWidth,
			};

				foreach (var item in items) {
					var button = new Button {
						Content = item.Label,
						IsEnabled = item.Enabled,
						Padding = new Thickness(8, 4),
						ClickMode = ClickMode.Press,
					};
					bool invoked = false;
					void invoke() {
						if (invoked || !item.Enabled) {
							return;
						}
						invoked = true;
						OnMenuItemClicked(item);
					}
					button.Click += (_, _) => invoke();
					button.AddHandler(InputElement.PointerPressedEvent, (_, e) => {
						if (!item.Enabled) {
							return;
						}
						if (!editor.IsPrimaryPointerPress(button, e)) {
							return;
						}
						e.Handled = true;
						invoke();
					}, RoutingStrategies.Tunnel);
					row.Children.Add(button);
				}

			EditorTheme theme = editor.GetTheme();
			popup.Child = new Border {
				Padding = new Thickness(6),
				CornerRadius = new CornerRadius(8),
				BorderThickness = new Thickness(1),
				BorderBrush = new SolidColorBrush(Color.FromUInt32(theme.CompletionBorderColor)),
				Background = new SolidColorBrush(Color.FromUInt32(theme.CompletionBgColor)),
				Child = row,
			};
		}

		private void OnMenuItemClicked(SelectionMenuItem item) {
			if (disposed) {
				return;
			}

			switch (item.Id) {
				case SelectionMenuItem.ACTION_CUT:
					editor.CutToClipboard();
					break;
				case SelectionMenuItem.ACTION_COPY:
					editor.CopyToClipboard();
					break;
				case SelectionMenuItem.ACTION_PASTE:
					editor.PasteFromClipboard();
					break;
				case SelectionMenuItem.ACTION_SELECT_ALL:
					editor.SelectAll();
					break;
				default:
					try {
						listener?.OnSelectionMenuItemSelected(item.Id);
					}
					catch (Exception ex) {
						Console.Error.WriteLine($"Selection menu listener error: {ex.Message}");
					}
					CustomItemSelected?.Invoke(item);
					break;
			}

			Dismiss();
		}

		private bool TryComputeAnchorRect(out AvaloniaRect rect) {
			rect = default;

			Size menuSize = MeasurePopupSize();
			double menuWidth = Math.Max(1, menuSize.Width > 1 ? menuSize.Width : FallbackMenuWidth);
			double menuHeight = Math.Max(1, menuSize.Height > 1 ? menuSize.Height : FallbackMenuHeight);
			AvaloniaRect viewport = editor.GetPopupViewportRect();
			if (viewport.Width <= 0 || viewport.Height <= 0) {
				return false;
			}
			double minX = viewport.X;
			double minY = viewport.Y;
			double maxX = Math.Max(minX, viewport.Right - menuWidth);
			double maxY = Math.Max(minY, viewport.Bottom - menuHeight);

			var selection = editor.GetSelection();
			if (!selection.hasSelection) {
				if (!editor.IsInlineSuggestionShowing()) {
					return false;
				}

				var cursor = editor.GetCursorRect();
				double anchorX = cursor.X - menuWidth * 0.5;
				double aboveY = cursor.Y - menuHeight - VerticalOffset;
				double belowY = cursor.Y + Math.Max(1f, cursor.Height) + VerticalOffset;
				double anchorY = aboveY >= minY ? aboveY : belowY;

				anchorX = Math.Clamp(anchorX, minX, maxX);
				anchorY = Math.Clamp(anchorY, minY, maxY);
				rect = new AvaloniaRect(anchorX, anchorY, 1, 1);
				return true;
			}

			var start = editor.GetPositionRect(selection.range.Start.Line, selection.range.Start.Column);
			var end = editor.GetPositionRect(selection.range.End.Line, selection.range.End.Column);
			double startBottom = start.Y + Math.Max(1f, start.Height);
			double endBottom = end.Y + Math.Max(1f, end.Height);
			double anchorXCenter = (start.X + end.X) * 0.5;
			double topY = Math.Min(start.Y, end.Y);
			double bottomY = Math.Max(startBottom, endBottom) + HandleClearance;
			double above = topY - menuHeight - VerticalOffset;
			double below = bottomY + VerticalOffset;
			double anchorYSelection = above >= minY ? above : below;
			double anchorXSelection = anchorXCenter - menuWidth * 0.5;

			anchorXSelection = Math.Clamp(anchorXSelection, minX, maxX);
			anchorYSelection = Math.Clamp(anchorYSelection, minY, maxY);
			rect = new AvaloniaRect(anchorXSelection, anchorYSelection, 1, 1);
			return true;
		}

		private Size MeasurePopupSize() {
			if (popup?.Child == null) {
				return default;
			}
			popup.Child.Measure(Size.Infinity);
			return popup.Child.DesiredSize;
		}
	}
}
