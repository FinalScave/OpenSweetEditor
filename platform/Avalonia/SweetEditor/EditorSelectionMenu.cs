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
using AvaloniaSize = Avalonia.Size;
using Button = Avalonia.Controls.Button;
using Orientation = Avalonia.Layout.Orientation;

namespace SweetEditor {
	public sealed class SelectionMenuItem {
		public const string ACTION_CUT = "cut";
		public const string ACTION_COPY = "copy";
		public const string ACTION_DELETE = "delete";
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
		private enum LifecycleState {
			Hidden,
			PendingShow,
			Visible,
			Suspended,
		}

		private const int ShowDelayMs = 100;
		private const double VerticalOffset = 8;
		private const double HandleClearance = 32;
		private const double FallbackMenuWidth = 220;
		private const double FallbackMenuHeight = 40;

		private readonly SweetEditorControl editor;
		private readonly DispatcherTimer showTimer;
		private Popup? popup;
		private ISelectionMenuItemProvider? itemProvider;
		private ISelectionMenuListener? listener;
		private IReadOnlyList<SelectionMenuItem> visibleItems = [];
		private LifecycleState state;
		private bool hasSelection;
		private bool coreBlocked;
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
		}

		public bool IsShowing => state == LifecycleState.Visible && popup?.IsOpen == true;

		public void SetItemProvider(ISelectionMenuItemProvider? provider) {
			itemProvider = provider;
		}

		public void SetListener(ISelectionMenuListener? listener) {
			this.listener = listener;
		}

		private void ScheduleShow() {
			if (disposed || !editor.IsMounted || !hasSelection) {
				return;
			}
			if (coreBlocked) {
				Suspend();
				return;
			}
			showTimer.Stop();
			if (popup != null) {
				popup.IsOpen = false;
			}
			visibleItems = [];
			state = LifecycleState.PendingShow;
			showTimer.Start();
		}

		public void ApplyTheme() {
			if (disposed || state != LifecycleState.Visible || popup?.IsOpen != true || visibleItems.Count == 0) {
				return;
			}

			RebuildPopupContent(visibleItems);
			UpdatePosition();
		}

		public void OnEditorActionResult(EditorActionResult result) {
			if (disposed) {
				return;
			}

			hasSelection = result.HasSelectionAfter;
			coreBlocked = result.HasActiveInteraction || result.NeedsViewportMotion;

			if (result.TextChanges.Count > 0 || !hasSelection) {
				Dismiss();
				return;
			}

			bool wantsShow = result.SelectionChanged;
			if (coreBlocked) {
				if (wantsShow || state != LifecycleState.Hidden) {
					Suspend();
				}
				return;
			}

			if (wantsShow || state == LifecycleState.Suspended) {
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
			state = LifecycleState.Hidden;
			visibleItems = [];
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
			visibleItems = [];
			if (popup != null) {
				popup.IsOpen = false;
				popup.Child = null;
				popup = null;
			}
			listener = null;
			itemProvider = null;
		}

		private void Suspend() {
			showTimer.Stop();
			visibleItems = [];
			if (popup != null) {
				popup.IsOpen = false;
			}
			state = LifecycleState.Suspended;
		}

		private void ShowNow() {
			if (disposed || !editor.IsMounted || state != LifecycleState.PendingShow) {
				return;
			}

			if (!hasSelection || !editor.GetSelection().hasSelection) {
				Dismiss();
				return;
			}
			if (coreBlocked) {
				Suspend();
				return;
			}

			var items = BuildItems();
			if (items.Count == 0) {
				Dismiss();
				return;
			}

			EnsurePopup();
			visibleItems = new List<SelectionMenuItem>(items);
			RebuildPopupContent(visibleItems);
			state = LifecycleState.Visible;
			UpdatePosition();
		}

		private IReadOnlyList<SelectionMenuItem> BuildItems() {
			if (itemProvider != null) {
				try {
					var provided = itemProvider.ProvideMenuItems(editor);
					if (provided == null) {
						return [];
					}
					var items = new List<SelectionMenuItem>();
					foreach (var item in provided) {
						if (item != null && !string.IsNullOrWhiteSpace(item.Id)) {
							items.Add(item);
						}
					}
					return items;
				}
				catch (Exception ex) {
					Console.Error.WriteLine($"Selection menu item provider error: {ex.Message}");
					return [];
				}
			}

			bool hasSelection = editor.GetSelection().hasSelection;
			return [
				new(SelectionMenuItem.ACTION_CUT, "Cut", hasSelection),
				new(SelectionMenuItem.ACTION_COPY, "Copy", hasSelection),
				new(SelectionMenuItem.ACTION_PASTE, "Paste"),
				new(SelectionMenuItem.ACTION_SELECT_ALL, "Select All"),
			];
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

			EditorTheme theme = editor.GetTheme();
			bool firstItem = true;
			foreach (var item in items) {
				var itemContainer = new StackPanel {
					Orientation = Orientation.Horizontal,
				};
				if (!firstItem) {
					itemContainer.Children.Add(new Border {
						Width = 1,
						Height = 18,
						Margin = new Thickness(2, 4),
						VerticalAlignment = VerticalAlignment.Center,
						Background = new SolidColorBrush(Color.FromUInt32(theme.SelectionMenuDividerColor)),
					});
				}
				firstItem = false;
				var button = new Button {
					Content = item.Label,
					IsEnabled = item.Enabled,
					Padding = new Thickness(8, 4),
					ClickMode = ClickMode.Press,
					Foreground = new SolidColorBrush(Color.FromUInt32(theme.SelectionMenuTextColor)),
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
				itemContainer.Children.Add(button);
				row.Children.Add(itemContainer);
			}

			popup.Child = new Border {
				Padding = new Thickness(6),
				CornerRadius = new CornerRadius(8),
				BorderThickness = new Thickness(1),
				BorderBrush = new SolidColorBrush(Color.FromUInt32(theme.CompletionBorderColor)),
				Background = new SolidColorBrush(Color.FromUInt32(theme.SelectionMenuBgColor)),
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
				case SelectionMenuItem.ACTION_DELETE:
					var selection = editor.GetSelection();
					if (selection.hasSelection) {
						editor.DeleteText(selection.range);
					}
					break;
				case SelectionMenuItem.ACTION_PASTE:
					editor.PasteFromClipboard();
					break;
				case SelectionMenuItem.ACTION_SELECT_ALL:
					editor.SelectAll();
					return;
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

			AvaloniaSize menuSize = MeasurePopupSize();
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
				return false;
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

		private AvaloniaSize MeasurePopupSize() {
			if (popup?.Child == null) {
				return default;
			}
			popup.Child.Measure(AvaloniaSize.Infinity);
			return popup.Child.DesiredSize;
		}
	}
}
