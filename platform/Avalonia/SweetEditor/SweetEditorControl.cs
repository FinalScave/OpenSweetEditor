using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Primitives;
using Avalonia.Controls.Platform;
using Avalonia.Controls.Primitives.PopupPositioning;
using Avalonia.Input;
using Avalonia.Input.GestureRecognizers;
using Avalonia.Input.TextInput;
using Avalonia.Input.Platform;
using Avalonia.Interactivity;
using Avalonia.Layout;
using Avalonia.Media;
using Avalonia.Threading;
using Avalonia.VisualTree;

namespace SweetEditor {
	public sealed class DocumentLoadedEventArgs : EditorEventArgs {
		public DocumentLoadedEventArgs() : base(EditorEventType.DocumentLoaded) {
		}
	}

	public class SweetEditorControl : Control, IDisposable {
		private const int MaxMergedRenderRunTextLength = 192;
		private const int AndroidMergeMinTotalRuns = 512;
		private const int AndroidMergeMinAverageRunsPerLine = 10;

		public event EventHandler<TextChangedEventArgs>? TextChanged;
		public event EventHandler<CursorChangedEventArgs>? CursorChanged;
		public event EventHandler<SelectionChangedEventArgs>? SelectionChanged;
		public event EventHandler<ScrollChangedEventArgs>? ScrollChanged;
		public event EventHandler<ScaleChangedEventArgs>? ScaleChanged;
		public event EventHandler<DocumentLoadedEventArgs>? DocumentLoaded;
		public event EventHandler<LongPressEventArgs>? LongPress;
		public event EventHandler<DoubleTapEventArgs>? DoubleTap;
		public new event EventHandler<ContextMenuEventArgs>? ContextMenu;
		public event EventHandler<InlayHintClickEventArgs>? InlayHintClick;
		public event EventHandler<GutterIconClickEventArgs>? GutterIconClick;
		public event EventHandler<CodeLensClickEventArgs>? CodeLensClick;
		public event EventHandler<FoldToggleEventArgs>? FoldToggle;
		public event EventHandler<SelectionMenuItemClickEventArgs>? SelectionMenuItemClick;
		public event Action<IReadOnlyList<CompletionItem>>? CompletionItemsUpdated;
		public event Action? CompletionDismissed;
		public event Action<InlineSuggestion>? InlineSuggestionAccepted;
		public event Action<InlineSuggestion>? InlineSuggestionDismissed;

		private const int AnimationIntervalMs = 16;
		private const int AndroidScheduledTextInputNotifyMinIntervalMs = 48;
		private const float DefaultContentStartPadding = 3.0f;
		private const float TapFallbackDoubleTapDistanceDip = 18f;

		private readonly EditorCore editorCore;
		private readonly EditorRenderer renderer;
		private readonly EditorSettings settings;
		private readonly DecorationProviderManager decorationProviderManager;
		private readonly CompletionProviderManager completionProviderManager;
		private readonly NewLineActionProviderManager newLineActionProviderManager;
		private readonly SelectionMenuController selectionMenuController;
		private readonly DispatcherTimer animationTimer;
		private readonly List<CompletionItem> completionItems = new();
		private readonly EditorTextInputClient textInputClient;
		private readonly EditorPlatformBehavior platformBehavior;
		private readonly PinchGestureRecognizer pinchGestureRecognizer;
		private readonly ScrollGestureRecognizer? scrollGestureRecognizer;
		private EditorKeyMap keyMap = CreateDefaultEditorKeyMap();
		private KeyChord pendingKeyChord;
		private TopLevel? attachedTopLevel;
		private IInputPane? attachedInputPane;
		private IInsetsManager? attachedInsetsManager;
		private Rect lastKnownInputPaneOccludedRect;
		private Thickness lastKnownSafeAreaPadding;

		private readonly InlineSuggestionDecorationProvider inlineSuggestionDecorationProvider;
		private InlineSuggestion? inlineSuggestion;
		private IInlineSuggestionListener? inlineSuggestionListener;
		private Popup? inlineSuggestionPopup;

		private EditorRenderModel? renderModel;
		private EditorTheme currentTheme = EditorTheme.Dark();
		private LanguageConfiguration? languageConfiguration;
		private ICompletionItemRenderer? completionItemRenderer;
		private bool animationActive;
		private bool renderModelDirty = true;
		private bool visualInvalidationPending;
		private float lastFrameBuildMs;
		private bool attached;
		private bool disposed;
		private int cachedVisibleStartLine;
		private int cachedVisibleEndLine = -1;
		private bool pendingViewportDecorationRefresh = true;
		private bool pendingCursorViewportSync;
		private bool viewportUpdateScheduled;
		private bool forceViewportUpdate;
		private Size pendingViewportSize;
		private Size appliedViewportSize;
		private bool renderModelDebugLogged;
		private SweetEditorController? controller;
		private bool touchSequenceActive;
		private bool touchPendingFocus;
		private bool touchPointerMoved;
		private bool touchGestureHadScroll;
		private Point touchDownPosition;
		private Point lastPointerPosition;
		private float touchDownScrollX;
		private float touchDownScrollY;
		private long touchDownTickMs;
		private bool imeSuppressedByTouch;
		private bool textInputNotificationScheduled;
		private long lastTextInputNotificationTickMs;
		private bool tapFallbackArmed;
		private long lastTapFallbackTickMs;
		private PointF lastTapFallbackPoint;
		private bool touchMoveFlushScheduled;
		private long lastTouchMoveFlushTickMs;
		private bool hasAuthorizedDestructiveSelection;
		private TextRange authorizedDestructiveSelection;
		private bool selectionMenuHostManaged;

		private static EditorKeyMap CreateDefaultEditorKeyMap() {
			return EditorKeyMap.DefaultKeyMap();
		}

		public SweetEditorControl() {
			Focusable = true;
			ClipToBounds = true;
			InputMethod.SetIsInputMethodEnabled(this, true);
			TextInputOptions.SetMultiline(this, true);

			platformBehavior = EditorPlatformBehavior.DetectCurrent();
			renderer = new EditorRenderer(currentTheme);
			var options = new EditorOptions {
				TouchSlop = platformBehavior.DefaultTouchSlop,
				DoubleTapTimeout = platformBehavior.DefaultDoubleTapTimeout,
			};
			editorCore = new EditorCore(renderer.CreateTextMeasurer(), options);
			decorationProviderManager = new DecorationProviderManager(this);
			inlineSuggestionDecorationProvider = new InlineSuggestionDecorationProvider(() => inlineSuggestion);
			completionProviderManager = new CompletionProviderManager(this);
			newLineActionProviderManager = new NewLineActionProviderManager(this);
			selectionMenuController = new SelectionMenuController(this);
			settings = new EditorSettings(this);
			textInputClient = new EditorTextInputClient(this);
			pinchGestureRecognizer = new PinchGestureRecognizer();
			scrollGestureRecognizer = !platformBehavior.TouchFirst
				? new ScrollGestureRecognizer {
					CanHorizontallyScroll = true,
					CanVerticallyScroll = true,
					IsScrollInertiaEnabled = true,
				}
				: null;
			GestureRecognizers.Add(pinchGestureRecognizer);
			if (scrollGestureRecognizer != null) {
				GestureRecognizers.Add(scrollGestureRecognizer);
			}
			editorCore.SetKeyMap(keyMap);

			decorationProviderManager.AddProvider(inlineSuggestionDecorationProvider);
			TextInputMethodClientRequested += OnTextInputMethodClientRequested;
			AddHandler(Gestures.PinchEvent, OnPinchGesture);
            AddHandler(Gestures.PinchEndedEvent, OnPinchEnded);
            AddHandler(Gestures.ScrollGestureEvent, OnScrollGesture);
            AddHandler(Gestures.ScrollGestureEndedEvent, OnScrollGestureEnded);
            AddHandler(Gestures.ScrollGestureInertiaStartingEvent, OnScrollGestureInertiaStarting);
            AddHandler(Gestures.PointerTouchPadGestureMagnifyEvent, OnPointerTouchPadGestureMagnify);

			completionProviderManager.ItemsUpdated += OnCompletionItemsUpdated;
			completionProviderManager.Dismissed += OnCompletionDismissed;
			selectionMenuController.CustomItemSelected += OnSelectionMenuCustomItemSelected;

			editorCore.RegisterBatchTextStyles(currentTheme.TextStyles);
			settings.SetContentStartPadding(DefaultContentStartPadding);

			animationTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(AnimationIntervalMs),
			};
			animationTimer.Tick += (_, _) => TickAnimations();

			ApplyPlatformInteractionDefaults();
			if (platformBehavior.SuppressImeOnTouchDown) {
				SetImeSuppressedByTouch(true);
			}
		}

		public SweetEditorControl(SweetEditorController controller) : this() {
			AttachController(controller);
		}

		private void AttachController(SweetEditorController controller) {
			ArgumentNullException.ThrowIfNull(controller);

			if (ReferenceEquals(this.controller, controller)) {
				return;
			}

			SweetEditorController? oldController = this.controller;
			this.controller = controller;

			if (!attached) {
				return;
			}

			oldController?.Unbind(this);
			this.controller.Bind(this);
		}

		public IEditorMetadata? Metadata { get; private set; }

		public EditorSettings Settings => settings;

		internal EditorRenderer RendererInternal => renderer;

		internal EditorCore EditorCoreInternal => editorCore;

		internal bool IsMounted => attached && !disposed;

		public override void Render(DrawingContext context) {
			base.Render(context);
			visualInvalidationPending = false;
			if (disposed) {
				return;
			}

			EnsureRenderModelUpToDate();
			if (renderModel.HasValue) {
				renderer.Render(context, renderModel.Value, Bounds.Size, lastFrameBuildMs);
			}
		}

			protected override void OnAttachedToVisualTree(VisualTreeAttachmentEventArgs e) {
				base.OnAttachedToVisualTree(e);
				attached = true;
				if (disposed) {
					return;
				}

				AttachTopLevelHooks();
				ApplyPlatformInteractionDefaults();

				editorCore.OnFontMetricsChanged();
				controller?.Bind(this);
				pendingViewportDecorationRefresh = true;
				ScheduleViewportUpdate(Bounds.Size, force: true);
				NotifyTextInputStateChanged(textViewChanged: true, force: true);
		}

		protected override void OnDetachedFromVisualTree(VisualTreeAttachmentEventArgs e) {
			attached = false;
			animationActive = false;
			animationTimer.Stop();
			visualInvalidationPending = false;
			controller?.Unbind(this);
			DetachTopLevelHooks();
			CancelActiveTouchSequence(fireEvents: false, notifyViewportSettled: false, flushAfterCancel: false);
			SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
			selectionMenuController.Dismiss();
			DismissInlineSuggestionInternal(emitDismissedCallback: false);
			pendingKeyChord = KeyChord.Empty;
			base.OnDetachedFromVisualTree(e);
		}

		protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change) {
			base.OnPropertyChanged(change);
			if (disposed || change.Property != BoundsProperty) {
				return;
			}

			var rect = change.GetNewValue<Rect>();
			ScheduleViewportUpdate(rect.Size);
		}

		protected override Size ArrangeOverride(Size finalSize) {
			Size arranged = base.ArrangeOverride(finalSize);
			ScheduleViewportUpdate(arranged);
			return arranged;
		}

		protected override void OnGotFocus(GotFocusEventArgs e) {
			base.OnGotFocus(e);
			if (disposed) {
				return;
			}
			if (imeSuppressedByTouch) {
				return;
			}

			NotifyTextInputStateChanged(textViewChanged: true);
		}

		protected override void OnLostFocus(RoutedEventArgs e) {
			base.OnLostFocus(e);
			if (disposed) {
				return;
			}

			SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
			pendingKeyChord = KeyChord.Empty;
			NotifyTextInputStateChanged(force: true);
		}

		protected override void OnPointerPressed(PointerPressedEventArgs e) {
			bool touchLike = ShouldTreatPointerAsTouch(this, e, allowButtonlessMouseFallback: true);
			SetImeSuppressedByTouch(touchLike && platformBehavior.SuppressImeOnTouchDown);
			if (!touchLike) {
				base.OnPointerPressed(e);
			}
			if (disposed) {
				return;
			}

			if (touchLike) {
				touchSequenceActive = true;
				touchPendingFocus = true;
				touchPointerMoved = false;
				touchGestureHadScroll = false;
			} else {
				Focus();
				NotifyTextInputStateChanged(textViewChanged: true);
			}

				var point = e.GetPosition(this);
				lastPointerPosition = point;
				touchDownPosition = point;
				touchDownTickMs = Environment.TickCount64;
				var scroll = editorCore.GetScrollMetrics();
				touchDownScrollX = scroll.ScrollX;
				touchDownScrollY = scroll.ScrollY;
			var pointer = e.GetCurrentPoint(this);
			var modifiers = ToModifiers(e.KeyModifiers);

				if (touchLike) {
					// Force the first MOVE after DOWN to flush immediately.
					lastTouchMoveFlushTickMs = 0;
					if (!platformBehavior.TouchFirst) {
						e.Pointer.Capture(this);
					}

				var touchResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.TOUCH_DOWN,
					Points = [ToPointF(point)],
					Modifiers = modifiers,
					DirectScale = 1,
				});
				FireGestureEvents(touchResult, point);
				Flush();
				UpdateAnimationTimer(touchResult.NeedsAnimation);
				e.Handled = true;
				return;
			}

			if (pointer.Properties.IsRightButtonPressed) {
				var result = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_RIGHT_DOWN,
					Points = [ToPointF(point)],
					Modifiers = modifiers,
					DirectScale = 1,
				});
				FireGestureEvents(result, point);
				Flush();
				e.Handled = true;
				return;
			}

			if (pointer.Properties.IsLeftButtonPressed) {
				var result = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_DOWN,
					Points = [ToPointF(point)],
					Modifiers = modifiers,
					DirectScale = 1,
				});
				FireGestureEvents(result, point);
				Flush();
				UpdateAnimationTimer(result.NeedsAnimation);
				e.Handled = true;
			}
		}

		protected override void OnPointerMoved(PointerEventArgs e) {
			bool touchLike = ShouldTreatPointerAsTouch(this, e, allowButtonlessMouseFallback: touchSequenceActive);
			if (!touchLike) {
				base.OnPointerMoved(e);
			}
			if (disposed) {
				return;
			}

			var point = e.GetPosition(this);
			lastPointerPosition = point;
			if (touchLike) {
				// Android can occasionally miss the first DOWN in Avalonia gesture dispatch.
				// Recover by lazily starting the touch sequence on the first MOVE.
					if (!touchSequenceActive) {
						touchSequenceActive = true;
						touchPendingFocus = false;
						touchPointerMoved = true;
						touchGestureHadScroll = false;
						touchDownPosition = point;
						touchDownTickMs = Environment.TickCount64;
						var touchDownResult = editorCore.HandleGestureEvent(new GestureEvent {
							Type = EventType.TOUCH_DOWN,
							Points = [ToPointF(point)],
						Modifiers = ToModifiers(e.KeyModifiers),
						DirectScale = 1,
					});
					FireGestureEvents(touchDownResult, point);
				}

				SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
				if (touchPendingFocus && !touchPointerMoved &&
					IsTouchMovementBeyondFocusThreshold(point, touchDownPosition)) {
					touchPointerMoved = true;
				}

				var touchResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.TOUCH_MOVE,
					Points = [ToPointF(point)],
					Modifiers = ToModifiers(e.KeyModifiers),
					DirectScale = 1,
				});
				if (touchResult.Type is GestureType.SCROLL or GestureType.FAST_SCROLL or GestureType.SCALE or GestureType.DRAG_SELECT) {
					touchGestureHadScroll = true;
				}
				FireGestureEvents(touchResult, point);
				FlushTouchMove(touchResult);
				UpdateAnimationTimer(touchResult.NeedsAnimation);
				e.Handled = true;
				return;
			}

			var pointer = e.GetCurrentPoint(this);
			if (!pointer.Properties.IsLeftButtonPressed) {
				return;
			}

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.MOUSE_MOVE,
				Points = [ToPointF(point)],
				Modifiers = ToModifiers(e.KeyModifiers),
				DirectScale = 1,
			});
			FireGestureEvents(result, point);
			FlushAfterGesture(result);
			UpdateAnimationTimer(result.NeedsAnimation);
			e.Handled = true;
		}

		protected override void OnPointerReleased(PointerReleasedEventArgs e) {
			bool touchLike = ShouldTreatPointerAsTouch(this, e, allowButtonlessMouseFallback: touchSequenceActive);
			if (!touchLike) {
				base.OnPointerReleased(e);
			}
			if (disposed) {
				return;
			}

			var point = e.GetPosition(this);
			lastPointerPosition = point;
			if (touchLike) {
				if (!touchSequenceActive) {
					return;
				}

					touchSequenceActive = false;
					if (!platformBehavior.TouchFirst) {
						e.Pointer.Capture(null);
					}
				var touchResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.TOUCH_UP,
					Points = [ToPointF(point)],
					Modifiers = ToModifiers(e.KeyModifiers),
					DirectScale = 1,
				});
					if (touchPendingFocus) {
						bool movedByDistance = IsTouchMovementBeyondFocusThreshold(point, touchDownPosition);
						bool movedForImeTap = IsTouchMovementBeyondImeTapThreshold(point, touchDownPosition);
						var scroll = editorCore.GetScrollMetrics();
						bool movedByScroll =
							Math.Abs(scroll.ScrollX - touchDownScrollX) > 0.1f ||
							Math.Abs(scroll.ScrollY - touchDownScrollY) > 0.1f;
						long gestureDurationMs = Math.Max(0, Environment.TickCount64 - touchDownTickMs);
						bool gestureWasViewportOperation =
							touchResult.Type == GestureType.SCROLL ||
							touchResult.Type == GestureType.FAST_SCROLL ||
							touchResult.Type == GestureType.SCALE ||
							touchResult.Type == GestureType.DRAG_SELECT;
						bool textTap =
							touchResult.Type == GestureType.TAP &&
							touchResult.HitTarget.Type == HitTargetType.NONE &&
							!touchResult.HasSelection;
						bool allowImeForTap =
							!gestureWasViewportOperation &&
							!touchPointerMoved &&
							!movedByDistance &&
							!movedForImeTap &&
							!movedByScroll &&
							!touchGestureHadScroll &&
							textTap &&
							gestureDurationMs <= platformBehavior.TouchImeTapMaxDurationMs;
						if (allowImeForTap) {
							SetImeSuppressedByTouch(false);
							Focus();
							NotifyTextInputStateChanged(textViewChanged: true);
						} else {
							SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
					}
				}
				touchPendingFocus = false;
				touchPointerMoved = false;
				touchGestureHadScroll = false;

				FireGestureEvents(touchResult, point);
				NotifyViewportGestureSettled();
				FlushAfterGesture(touchResult);
				UpdateAnimationTimer(touchResult.NeedsAnimation);
				e.Handled = true;
				return;
			}

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.MOUSE_UP,
				Points = [ToPointF(point)],
				Modifiers = ToModifiers(e.KeyModifiers),
				DirectScale = 1,
			});
			FireGestureEvents(result, point);
			NotifyViewportGestureSettled();
			FlushAfterGesture(result);
			UpdateAnimationTimer(result.NeedsAnimation);
			e.Handled = true;
		}

		protected override void OnPointerWheelChanged(PointerWheelEventArgs e) {
			base.OnPointerWheelChanged(e);
			if (disposed) {
				return;
			}

			if (IsIntrinsicTouchLikePointer(e.Pointer.Type)) {
				return;
			}

			var point = e.GetPosition(this);
			lastPointerPosition = point;
			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.MOUSE_WHEEL,
				Points = [ToPointF(point)],
				Modifiers = ToModifiers(e.KeyModifiers),
				WheelDeltaX = (float)e.Delta.X * 120f,
				WheelDeltaY = (float)e.Delta.Y * 120f,
				DirectScale = 1,
			});
			FireGestureEvents(result, point);
			FlushWithoutTextInputState();
			e.Handled = true;
		}

		protected override void OnPointerCaptureLost(PointerCaptureLostEventArgs e) {
			base.OnPointerCaptureLost(e);
			if (disposed || !touchSequenceActive) {
				return;
			}

			CancelActiveTouchSequence(fireEvents: true, notifyViewportSettled: true, flushAfterCancel: true);
		}


		private void OnPinchGesture(object? sender, PinchEventArgs e) {
			if (disposed || !platformBehavior.EnableDirectPinch) {
				return;
			}

			touchPendingFocus = false;
			touchPointerMoved = true;
			touchGestureHadScroll = true;
			if (platformBehavior.SuppressImeOnTouchDown) {
				SetImeSuppressedByTouch(true);
			}

			Point origin = e.ScaleOrigin;
			lastPointerPosition = origin;
			float directScale = NormalizeDirectScale((float)e.Scale);
			if (Math.Abs(directScale - 1f) < 0.0001f) {
				return;
			}

			var result = editorCore.HandleGestureEventEx(new GestureEvent {
				Type = EventType.DIRECT_SCALE,
				Points = [ToPointF(origin)],
				Modifiers = Modifier.NONE,
				DirectScale = directScale,
			});
			FireGestureEvents(result, origin);
			FlushWithoutTextInputState();
			UpdateAnimationTimer(result.NeedsAnimation);
			e.Handled = true;
		}

		private void OnPinchEnded(object? sender, PinchEndedEventArgs e) {
			if (disposed || !platformBehavior.EnableDirectPinch) {
				return;
			}

			NotifyViewportGestureSettled();
			e.Handled = true;
		}

		private void OnScrollGesture(object? sender, ScrollGestureEventArgs e) {
			if (disposed) {
				return;
			}

			touchPendingFocus = false;
			touchPointerMoved = true;
			touchGestureHadScroll = true;
			if (platformBehavior.SuppressImeOnTouchDown) {
				SetImeSuppressedByTouch(true);
			}

			Point point = lastPointerPosition;
			float deltaX = NormalizeDirectScrollDelta(e.Delta.X);
			float deltaY = NormalizeDirectScrollDelta(e.Delta.Y);
			if (Math.Abs(deltaX) < 0.0001f && Math.Abs(deltaY) < 0.0001f) {
				return;
			}

			var result = editorCore.HandleGestureEventEx(new GestureEvent {
				Type = EventType.DIRECT_SCROLL,
				Points = [ToPointF(point)],
				Modifiers = Modifier.NONE,
				WheelDeltaX = deltaX,
				WheelDeltaY = deltaY,
				DirectScale = 1f,
			});
			FireGestureEvents(result, point);
			FlushWithoutTextInputState();
			UpdateAnimationTimer(result.NeedsAnimation);
			e.Handled = true;
		}

		private void OnScrollGestureEnded(object? sender, ScrollGestureEndedEventArgs e) {
			if (disposed) {
				return;
			}

			NotifyViewportGestureSettled();
			e.Handled = true;
		}

		private void OnScrollGestureInertiaStarting(object? sender, ScrollGestureInertiaStartingEventArgs e) {
			if (disposed) {
				return;
			}

			touchGestureHadScroll = true;
			if (platformBehavior.SuppressImeOnTouchDown) {
				SetImeSuppressedByTouch(true);
			}
			e.Handled = true;
		}

		private void OnPointerTouchPadGestureMagnify(object? sender, PointerDeltaEventArgs e) {
			if (disposed || !platformBehavior.EnableTouchPadMagnify) {
				return;
			}

			Point point = e.GetPosition(this);
			lastPointerPosition = point;

			double dominantDelta = Math.Abs(e.Delta.Y) >= Math.Abs(e.Delta.X)
				? e.Delta.Y
				: e.Delta.X;
			float directScale = NormalizeDirectScale(1f + (float)dominantDelta);
			if (Math.Abs(directScale - 1f) < 0.0001f) {
				return;
			}

			var result = editorCore.HandleGestureEventEx(new GestureEvent {
				Type = EventType.DIRECT_SCALE,
				Points = [ToPointF(point)],
				Modifiers = ToModifiers(e.KeyModifiers),
				DirectScale = directScale,
			});
			FireGestureEvents(result, point);
			Flush();
			UpdateAnimationTimer(result.NeedsAnimation);
			e.Handled = true;
		}

		protected override void OnKeyDown(KeyEventArgs e) {
			base.OnKeyDown(e);
			if (disposed) {
				return;
			}
			if (imeSuppressedByTouch) {
				SetImeSuppressedByTouch(false);
			}

			if (inlineSuggestion != null) {
				if (e.Key == Key.Tab) {
					AcceptInlineSuggestionInternal();
					e.Handled = true;
					return;
				}

				if (e.Key == Key.Escape) {
					DismissInlineSuggestionInternal(emitDismissedCallback: true);
					e.Handled = true;
					return;
				}
			}

			if (KeyChord.TryFromAvalonia(e.Key, e.KeyModifiers, out KeyChord incomingChord)) {
				KeyMapMatch match = keyMap.Match(incomingChord, ref pendingKeyChord);
				if (match.AwaitingSecondChord) {
					e.Handled = true;
					return;
				}
				if (match.IsCommand) {
					if (ExecuteKeyMapCommand(match.CommandId)) {
						e.Handled = true;
					}
					return;
				}

				return;
			}

			pendingKeyChord = KeyChord.Empty;

			ushort keyCode = MapKeyToKeyCode(e.Key);
			if (keyCode == 0 && (((e.KeyModifiers & KeyModifiers.Control) != 0) || ((e.KeyModifiers & KeyModifiers.Meta) != 0))) {
				if (TryMapShortcut(e.Key, out ushort shortcutCode)) {
					keyCode = shortcutCode;
				}
			}

			if (keyCode == 0) {
				return;
			}

			bool explicitSelectionSource = IsSelectionGestureKey(keyCode, e.KeyModifiers);
			if (IsDestructiveKey(keyCode)) {
				NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			}
			if (TryHandleAndroidPlainDeletionKey(e.Key, e.KeyModifiers)) {
				e.Handled = true;
				return;
			}

			if (e.Key == Key.Tab && (e.KeyModifiers == KeyModifiers.None || e.KeyModifiers == KeyModifiers.Shift)) {
				if (TryHandleConfiguredTab(e.KeyModifiers)) {
					e.Handled = true;
					return;
				}
			}
			if (e.Key == Key.Back && e.KeyModifiers == KeyModifiers.None) {
				if (TryHandleBackspaceUnindent()) {
					e.Handled = true;
					return;
				}
			}

			byte modifiers = ToModifierMask(e.KeyModifiers);
			var result = editorCore.HandleKeyEvent(keyCode, null, modifiers);
			if (result.Handled) {
				FireKeyEventChanges(result, TextChangeAction.Key, explicitSelectionSource);
				Flush();
				e.Handled = true;
			}
		}

		protected override void OnTextInput(TextInputEventArgs e) {
			base.OnTextInput(e);
			if (disposed || string.IsNullOrEmpty(e.Text)) {
				return;
			}

			if (e.Text.All(char.IsControl)) {
				return;
			}

			pendingKeyChord = KeyChord.Empty;
			NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();

			if (inlineSuggestion != null) {
				DismissInlineSuggestionInternal(emitDismissedCallback: true);
			}

			var result = InsertConfiguredText(e.Text);
			FireTextChanged(TextChangeAction.Key, result);

			Flush();
			e.Handled = true;
		}

		public void LoadDocument(Document document) {
			if (disposed || document == null) {
				return;
			}

			ClearAuthorizedDestructiveSelection();
			renderModelDebugLogged = false;
			editorCore.LoadDocument(document);
			editorCore.SetCursorPosition(new TextPosition { Line = 0, Column = 0 });
			editorCore.SetScroll(0, 0);
			decorationProviderManager.OnDocumentLoaded();
			pendingViewportDecorationRefresh = true;
			pendingCursorViewportSync = true;
			ScheduleViewportUpdate(Bounds.Size, force: true);
			DocumentLoaded?.Invoke(this, new DocumentLoadedEventArgs());
			Flush();
		}

		public Document? GetDocument() => disposed ? null : editorCore.GetDocument();

		public EditorTheme GetTheme() => currentTheme;

		public void ApplyTheme(EditorTheme theme) {
			if (disposed || theme == null) {
				return;
			}

			renderModelDebugLogged = false;
			currentTheme = theme;
			renderer.ApplyTheme(theme);
			editorCore.RegisterBatchTextStyles(theme.TextStyles);
			Flush();
		}

		public EditorSettings GetSettings() => settings;

		public void SetKeyMap(KeyMap map) {
			if (map == null) {
				map = EditorKeyMap.DefaultKeyMap();
			}
			keyMap = map is EditorKeyMap editorKeyMap
				? editorKeyMap.Clone()
				: new EditorKeyMap(map.Bindings);
			editorCore.SetKeyMap(keyMap);
			pendingKeyChord = KeyChord.Empty;
		}

		public KeyMap GetKeyMap() {
			return keyMap.Clone();
		}





		public void SetEditorIconProvider(EditorIconProvider? provider) {
			renderer.SetEditorIconProvider(provider);
			Flush();
		}

		public void SetLanguageConfiguration(LanguageConfiguration? config) {
			languageConfiguration = config;
			editorCore.SetAutoClosingPairs(config?.AutoClosingPairs);
			if (config != null) {
				if (config.Brackets != null) {
					int[] opens = new int[config.Brackets.Count];
					int[] closes = new int[config.Brackets.Count];
					for (int i = 0; i < config.Brackets.Count; i++) {
						opens[i] = string.IsNullOrEmpty(config.Brackets[i].Open) ? 0 : char.ConvertToUtf32(config.Brackets[i].Open, 0);
						closes[i] = string.IsNullOrEmpty(config.Brackets[i].Close) ? 0 : char.ConvertToUtf32(config.Brackets[i].Close, 0);
					}
					editorCore.SetBracketPairs(opens, closes);
				}
				if (config.TabSize.HasValue && config.TabSize.Value > 0) {
					editorCore.SetTabSize(config.TabSize.Value);
				}
				if (config.InsertSpaces.HasValue) {
					editorCore.SetInsertSpaces(config.InsertSpaces.Value);
				}
			}
			Flush();
		}

		public LanguageConfiguration? GetLanguageConfiguration() => languageConfiguration;

		public void SetMetadata(IEditorMetadata? metadata) {
			Metadata = metadata;
			renderModelDebugLogged = false;
			decorationProviderManager.RequestRefresh();
		}


		public IEditorMetadata? GetMetadata() => Metadata;


		public void AddNewLineActionProvider(INewLineActionProvider provider) => newLineActionProviderManager.AddProvider(provider);

		public void RemoveNewLineActionProvider(INewLineActionProvider provider) => newLineActionProviderManager.RemoveProvider(provider);

		public void AddDecorationProvider(IDecorationProvider provider) => decorationProviderManager.AddProvider(provider);

		public void RemoveDecorationProvider(IDecorationProvider provider) => decorationProviderManager.RemoveProvider(provider);

		public void RequestDecorationRefresh() => decorationProviderManager.RequestRefresh();

		public void AddCompletionProvider(ICompletionProvider provider) => completionProviderManager.AddProvider(provider);

		public void RemoveCompletionProvider(ICompletionProvider provider) => completionProviderManager.RemoveProvider(provider);

		public void TriggerCompletion() => completionProviderManager.TriggerCompletion(CompletionTriggerKind.Invoked, null);

		public void ShowCompletionItems(List<CompletionItem> items) => completionProviderManager.ShowItems(items);

		public void DismissCompletion() => completionProviderManager.Dismiss();

		public void SetCompletionItemRenderer(ICompletionItemRenderer? renderer) {
			completionItemRenderer = renderer;
		}


		public void ShowInlineSuggestion(InlineSuggestion suggestion) {
			if (disposed || suggestion == null || string.IsNullOrEmpty(suggestion.Text)) {
				return;
			}

			inlineSuggestion = suggestion;
			if (!selectionMenuHostManaged) {
				EnsureInlineSuggestionActionBar();
				if (inlineSuggestionPopup != null) {
					inlineSuggestionPopup.IsOpen = attached;
				}
				UpdateInlineSuggestionActionBarPosition();
				ScheduleSelectionMenuShow();
			} else {
				HideInlineSuggestionActionBar();
			}

			decorationProviderManager.RequestRefresh();
			Flush();
		}


		public void DismissInlineSuggestion() {
			DismissInlineSuggestionInternal(emitDismissedCallback: true);
		}

		public void AcceptInlineSuggestion() {
			AcceptInlineSuggestionInternal();
		}

		public bool IsInlineSuggestionShowing() => !disposed && inlineSuggestion != null;

		public void SetInlineSuggestionListener(IInlineSuggestionListener? listener) {
			inlineSuggestionListener = listener;
		}

		public void SetSelectionMenuItemProvider(ISelectionMenuItemProvider? provider) {
			selectionMenuController.SetItemProvider(provider);
		}

		public void SetSelectionMenuListener(ISelectionMenuListener? listener) {
			selectionMenuController.SetListener(listener);
		}

		public void SetSelectionMenuHostManaged(bool hostManaged) {
			if (disposed) {
				return;
			}

			selectionMenuHostManaged = hostManaged;
			selectionMenuController.Dismiss();
			if (hostManaged) {
				HideInlineSuggestionActionBar();
			}
			if (!hostManaged) {
				NotifySelectionMenuSelectionChanged(editorCore.GetSelection().hasSelection);
			}
		}

		public bool IsSelectionMenuShowing() => !disposed && selectionMenuController.IsShowing;

		internal void DismissSelectionMenu() => selectionMenuController.Dismiss();

		public void SetPerfOverlayEnabled(bool enabled) {
			renderer.SetPerfOverlayEnabled(enabled);
			Flush();
		}

		public bool IsPerfOverlayEnabled() => renderer.IsPerfOverlayEnabled();

		public void InsertText(string text) {
			if (disposed || text == null) {
				return;
			}
			NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			var result = InsertConfiguredText(text);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void ReplaceText(TextRange range, string newText) {
			if (disposed || newText == null) {
				return;
			}
			var result = editorCore.ReplaceText(range, newText);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void DeleteText(TextRange range) {
			if (disposed) {
				return;
			}
			var result = editorCore.DeleteText(range);
			FireTextChanged(TextChangeAction.Delete, result);
			Flush();
		}

		public void MoveLineUp() {
			var result = editorCore.MoveLineUp();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void MoveLineDown() {
			var result = editorCore.MoveLineDown();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void CopyLineUp() {
			var result = editorCore.CopyLineUp();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void CopyLineDown() {
			var result = editorCore.CopyLineDown();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void DeleteLine() {
			var result = editorCore.DeleteLine();
			FireTextChanged(TextChangeAction.Delete, result);
			Flush();
		}

		public void InsertLineAbove() {
			var result = editorCore.InsertLineAbove();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public void InsertLineBelow() {
			var result = editorCore.InsertLineBelow();
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
		}

		public bool Undo() {
			var result = editorCore.Undo();
			if (result == null) {
				return false;
			}
			FireTextChanged(TextChangeAction.Undo, result);
			Flush();
			return true;
		}

		public bool Redo() {
			var result = editorCore.Redo();
			if (result == null) {
				return false;
			}
			FireTextChanged(TextChangeAction.Redo, result);
			Flush();
			return true;
		}

		public bool CanUndo() => !disposed && editorCore.CanUndo();

		public bool CanRedo() => !disposed && editorCore.CanRedo();

		public void CopyToClipboard() {
			if (Dispatcher.UIThread.CheckAccess()) {
				_ = CopyToClipboardAsync();
			} else {
				Dispatcher.UIThread.Post(() => _ = CopyToClipboardAsync(), DispatcherPriority.Input);
			}
		}

		public void PasteFromClipboard() {
			if (Dispatcher.UIThread.CheckAccess()) {
				_ = PasteFromClipboardAsync();
			} else {
				Dispatcher.UIThread.Post(() => _ = PasteFromClipboardAsync(), DispatcherPriority.Input);
			}
		}

		public void CutToClipboard() {
			if (Dispatcher.UIThread.CheckAccess()) {
				_ = CutToClipboardAsync();
			} else {
				Dispatcher.UIThread.Post(() => _ = CutToClipboardAsync(), DispatcherPriority.Input);
			}
		}

		public void SelectAll() {
			editorCore.SelectAll();
			var cursor = editorCore.GetCursorPosition();
			var selection = editorCore.GetSelection();
			UpdateDestructiveSelectionAuthorization(selection.hasSelection, explicitSelectionSource: true, selection.range);
			SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(selection.hasSelection, selection.hasSelection ? selection.range : (TextRange?)null, cursor));
			NotifySelectionMenuSelectionChanged(selection.hasSelection);
			ScheduleSelectionMenuShow();
			Flush();
		}

		public string GetSelectedText() => disposed ? string.Empty : editorCore.GetSelectedText();

		public void SetSelection(int startLine, int startColumn, int endLine, int endColumn) {
			TryApplyValidatedSelection(new TextRange {
				Start = new TextPosition { Line = startLine, Column = startColumn },
				End = new TextPosition { Line = endLine, Column = endColumn }
			}, out _);
			var cursor = editorCore.GetCursorPosition();
			var selection = editorCore.GetSelection();
			UpdateDestructiveSelectionAuthorization(selection.hasSelection, explicitSelectionSource: true, selection.range);
			SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(selection.hasSelection, selection.hasSelection ? selection.range : (TextRange?)null, cursor));
			NotifySelectionMenuSelectionChanged(selection.hasSelection);
			Flush();
		}


		public (bool hasSelection, TextRange range) GetSelection() => disposed ? (false, default) : editorCore.GetSelection();

		public void SetCursorPosition(TextPosition position) {
			editorCore.SetCursorPosition(position);
			ClearAuthorizedDestructiveSelection();
			CursorChanged?.Invoke(this, new CursorChangedEventArgs(editorCore.GetCursorPosition()));
			NotifySelectionMenuSelectionChanged(editorCore.GetSelection().hasSelection);
			Flush();
		}

		public TextPosition GetCursorPosition() => disposed ? default : editorCore.GetCursorPosition();

		public TextRange? GetWordRangeAtCursor() => disposed ? null : editorCore.GetWordRangeAtCursor();

		public string GetWordAtCursor() => disposed ? string.Empty : editorCore.GetWordAtCursor();

		public void GotoPosition(int line, int column = 0) {
			editorCore.GotoPosition(line, column);
			ClearAuthorizedDestructiveSelection();
			CursorChanged?.Invoke(this, new CursorChangedEventArgs(editorCore.GetCursorPosition()));
			NotifySelectionMenuSelectionChanged(editorCore.GetSelection().hasSelection);
			Flush();
		}

		public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.CENTER) {
			editorCore.ScrollToLine(line, (int)behavior);
			var m = editorCore.GetScrollMetrics();
			ScrollChanged?.Invoke(this, new ScrollChangedEventArgs(m.ScrollX, m.ScrollY));
			if (ShouldUpdateSelectionMenuPopupPosition()) {
				selectionMenuController.UpdatePosition();
			}
			FlushWithoutTextInputState();
		}

		public void SetScroll(float scrollX, float scrollY) {
			editorCore.SetScroll(scrollX, scrollY);
			var m = editorCore.GetScrollMetrics();
			ScrollChanged?.Invoke(this, new ScrollChangedEventArgs(m.ScrollX, m.ScrollY));
			if (ShouldUpdateSelectionMenuPopupPosition()) {
				selectionMenuController.UpdatePosition();
			}
			FlushWithoutTextInputState();
		}

		public ScrollMetrics GetScrollMetrics() => disposed ? default : editorCore.GetScrollMetrics();

		public CursorRect GetPositionRect(int line, int column) => disposed ? default : editorCore.GetPositionRect(line, column);

		public CursorRect GetCursorRect() => disposed ? default : editorCore.GetCursorRect();

		public bool ToggleFoldAt(int line) {
			bool result = editorCore.ToggleFold(line);
			if (result) {
				Flush();
			}
			return result;
		}


		public bool FoldAt(int line) {
			bool result = editorCore.FoldAt(line);
			if (result) {
				Flush();
			}
			return result;
		}

		public bool UnfoldAt(int line) {
			bool result = editorCore.UnfoldAt(line);
			if (result) {
				Flush();
			}
			return result;
		}

		public bool IsLineVisible(int line) => !disposed && editorCore.IsLineVisible(line);

		public void FoldAll() {
			editorCore.FoldAll();
			Flush();
		}

		public void UnfoldAll() {
			editorCore.UnfoldAll();
			Flush();
		}

		public void RegisterTextStyle(uint styleId, int color, int backgroundColor, int fontStyle) =>
			editorCore.RegisterTextStyle(styleId, color, backgroundColor, fontStyle);


		public void RegisterBatchTextStyles(IReadOnlyDictionary<uint, TextStyle> stylesById) =>
			editorCore.RegisterBatchTextStyles(stylesById);


		public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans) => editorCore.SetLineSpans(line, (int)layer, spans);


		public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine) =>
			editorCore.SetBatchLineSpans((int)layer, spansByLine);

		internal void SetBatchLineSpans(SpanLayer layer, Dictionary<int, List<StyleSpan>> spansByLine) =>
			editorCore.SetBatchLineSpans((int)layer, spansByLine);

		public void ClearLineSpans(int line, SpanLayer layer) {
			editorCore.ClearLineSpans(line, (int)layer);
			Flush();
		}

		public void SetLineInlayHints(int line, IList<InlayHint> hints) => editorCore.SetLineInlayHints(line, hints);

		public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) => editorCore.SetBatchLineInlayHints(hintsByLine);

		internal void SetBatchLineInlayHints(Dictionary<int, List<InlayHint>> hintsByLine) => editorCore.SetBatchLineInlayHints(hintsByLine);

		public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms) => editorCore.SetLinePhantomTexts(line, phantoms);

		public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) => editorCore.SetBatchLinePhantomTexts(phantomsByLine);

		internal void SetBatchLinePhantomTexts(Dictionary<int, List<PhantomText>> phantomsByLine) => editorCore.SetBatchLinePhantomTexts(phantomsByLine);

		public void SetLineGutterIcons(int line, IList<GutterIcon> icons) => editorCore.SetLineGutterIcons(line, icons);

		public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) => editorCore.SetBatchLineGutterIcons(iconsByLine);

		internal void SetBatchLineGutterIcons(Dictionary<int, List<GutterIcon>> iconsByLine) => editorCore.SetBatchLineGutterIcons(iconsByLine);

		public void SetMaxGutterIcons(int count) => settings.SetMaxGutterIcons(count);

		public int GetMaxGutterIcons() => settings.GetMaxGutterIcons();

		public void SetLineCodeLens(int line, IList<CodeLensItem> items) => editorCore.SetLineCodeLens(line, items);

		public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine) => editorCore.SetBatchLineCodeLens(itemsByLine);

		internal void SetBatchLineCodeLens(Dictionary<int, List<CodeLensItem>> itemsByLine) => editorCore.SetBatchLineCodeLens(itemsByLine);

		public void SetLineDiagnostics<TDiagnostic>(int line, IList<TDiagnostic> items) where TDiagnostic : Diagnostic => editorCore.SetLineDiagnostics(line, items);

		public void SetBatchLineDiagnostics<TDiagnostic>(Dictionary<int, IList<TDiagnostic>> diagsByLine) where TDiagnostic : Diagnostic => editorCore.SetBatchLineDiagnostics(diagsByLine);

		internal void SetBatchLineDiagnostics<TDiagnostic>(Dictionary<int, List<TDiagnostic>> diagsByLine) where TDiagnostic : Diagnostic => editorCore.SetBatchLineDiagnostics(diagsByLine);

		public void SetIndentGuides(IList<IndentGuide> guides) => editorCore.SetIndentGuides(guides);

		public void SetBracketGuides(IList<BracketGuide> guides) => editorCore.SetBracketGuides(guides);

		public void SetFlowGuides(IList<FlowGuide> guides) => editorCore.SetFlowGuides(guides);

		public void SetSeparatorGuides(IList<SeparatorGuide> guides) => editorCore.SetSeparatorGuides(guides);

		public void SetFoldRegions(IList<FoldRegion> regions) => editorCore.SetFoldRegions(regions);

		public void ClearHighlights() => editorCore.ClearHighlights();

		public void ClearHighlights(SpanLayer layer) => editorCore.ClearHighlights((int)layer);

		public void ClearInlayHints() => editorCore.ClearInlayHints();

		public void ClearPhantomTexts() => editorCore.ClearPhantomTexts();

		public void ClearGutterIcons() => editorCore.ClearGutterIcons();

		public void ClearCodeLens() => editorCore.ClearCodeLens();

		public void ClearGuides() => editorCore.ClearGuides();

		public void ClearDiagnostics() => editorCore.ClearDiagnostics();

		public void ClearAllDecorations() {
			editorCore.ClearAllDecorations();
			editorCore.ClearDiagnostics();
			editorCore.ClearCodeLens();
		}

		public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn) {
			editorCore.SetMatchedBrackets(openLine, openColumn, closeLine, closeColumn);
			Flush();
		}

		public void ClearMatchedBrackets() {
			editorCore.ClearMatchedBrackets();
			Flush();
		}

		public TextEditResult InsertSnippet(string snippetTemplate) {
			NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			var result = editorCore.InsertSnippet(snippetTemplate);
			FireTextChanged(TextChangeAction.Insert, result);
			Flush();
			return result;
		}

		public void StartLinkedEditing(LinkedEditingModel model) {
			editorCore.StartLinkedEditing(model);
			Flush();
		}

		public bool IsInLinkedEditing() => editorCore.IsInLinkedEditing();

		public bool LinkedEditingNext() {
			bool result = editorCore.LinkedEditingNext();
			if (result) {
				Flush();
			}
			return result;
		}

		public bool LinkedEditingPrev() {
			bool result = editorCore.LinkedEditingPrev();
			if (result) {
				Flush();
			}
			return result;
		}

		public void CancelLinkedEditing() {
			editorCore.CancelLinkedEditing();
			Flush();
		}

		public void Flush() {
			FlushCore(scheduleTextInputState: true);
		}

		private void FlushWithoutTextInputState() {
			FlushCore(scheduleTextInputState: false);
		}

		internal void FlushDecorationUpdate() {
			FlushWithoutTextInputState();
		}

		private void FlushCore(bool scheduleTextInputState) {
			if (disposed) {
				return;
			}
			renderModelDirty = true;
			if (scheduleTextInputState) {
				ScheduleTextInputStateChanged();
			}
			if (ShouldUpdateInlineSuggestionPopupPosition()) {
				UpdateInlineSuggestionActionBarPosition();
			}
			RequestVisualInvalidate();
		}

		private void RequestVisualInvalidate() {
			if (visualInvalidationPending) {
				return;
			}

			visualInvalidationPending = true;
			InvalidateVisual();
		}

		public (int start, int end) GetVisibleLineRange() {
			EnsureRenderModelUpToDate();
			return (cachedVisibleStartLine, cachedVisibleEndLine);
		}

		internal (int start, int end) GetCachedVisibleLineRange() {
			return (cachedVisibleStartLine, cachedVisibleEndLine);
		}

		public int GetTotalLineCount() => editorCore.GetDocument()?.GetLineCount() ?? -1;

		internal void ResetRenderModelDiagnostics() {
			renderModelDebugLogged = false;
		}

		internal void DetachController(SweetEditorController owner) {
			if (ReferenceEquals(controller, owner)) {
				controller = null;
			}
		}

		public void Dispose() {
			if (disposed) {
				return;
			}
			disposed = true;
			animationActive = false;
			animationTimer.Stop();
			DismissInlineSuggestionInternal(emitDismissedCallback: false);

			controller?.Unbind(this);
			controller = null;

			selectionMenuController.CustomItemSelected -= OnSelectionMenuCustomItemSelected;
			selectionMenuController.Dispose();

			completionProviderManager.Dispose();
			decorationProviderManager.Dispose();
			newLineActionProviderManager.Dispose();

			ProtocolDecoder.RecycleRenderModel(renderModel);
			renderModel = null;
			renderer.Dispose();
			editorCore.Dispose();
			completionItems.Clear();
			visualInvalidationPending = false;
		}

		private async Task CopyToClipboardAsync() {
			if (disposed) {
				return;
			}
			var selected = GetSelectedText();
			if (string.IsNullOrEmpty(selected)) {
				return;
			}
			var clipboard = TopLevel.GetTopLevel(this)?.Clipboard;
			if (clipboard != null) {
				await clipboard.SetTextAsync(selected).ConfigureAwait(false);
			}
		}

		private async Task PasteFromClipboardAsync() {
			if (disposed) {
				return;
			}
			var clipboard = TopLevel.GetTopLevel(this)?.Clipboard;
			if (clipboard == null) {
				return;
			}

			string? text = await clipboard.TryGetTextAsync().ConfigureAwait(false);
			if (!string.IsNullOrEmpty(text)) {
				Dispatcher.UIThread.Post(() => InsertText(text));
			}
		}

		private async Task CutToClipboardAsync() {
			if (disposed) {
				return;
			}
			NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			var selection = GetSelection();
			if (!selection.hasSelection) {
				return;
			}
			string selected = GetSelectedText();
			if (string.IsNullOrEmpty(selected)) {
				return;
			}
			var stableSelection = GetSelection();
			if (!stableSelection.hasSelection || !AreSameRange(stableSelection.range, selection.range)) {
				return;
			}
			try {
				DeleteText(stableSelection.range);
			} catch (Exception ex) {
				Console.Error.WriteLine($"CutToClipboard delete failed: {ex.Message}");
				return;
			}

			var clipboard = TopLevel.GetTopLevel(this)?.Clipboard;
			if (clipboard != null) {
				await clipboard.SetTextAsync(selected).ConfigureAwait(false);
			}
		}

		private static bool AreSameRange(TextRange left, TextRange right) {
			return left.Start.Line == right.Start.Line &&
				left.Start.Column == right.Start.Column &&
				left.End.Line == right.End.Line &&
				left.End.Column == right.End.Column;
		}

		private static bool AreSamePosition(TextPosition left, TextPosition right) {
			return left.Line == right.Line && left.Column == right.Column;
		}

		private static int ComparePositions(TextPosition left, TextPosition right) {
			int lineCompare = left.Line.CompareTo(right.Line);
			return lineCompare != 0 ? lineCompare : left.Column.CompareTo(right.Column);
		}

		private static TextRange NormalizeRange(TextRange range) {
			return ComparePositions(range.Start, range.End) <= 0
				? range
				: new TextRange { Start = range.End, End = range.Start };
		}

		private void ClearAuthorizedDestructiveSelection() {
			hasAuthorizedDestructiveSelection = false;
			authorizedDestructiveSelection = default;
		}

		private void UpdateDestructiveSelectionAuthorization(bool hasSelection, bool explicitSelectionSource, TextRange range) {
			if (!hasSelection || !explicitSelectionSource) {
				ClearAuthorizedDestructiveSelection();
				return;
			}

			hasAuthorizedDestructiveSelection = true;
			authorizedDestructiveSelection = NormalizeRange(range);
		}

		private bool IsAuthorizedDestructiveSelection(TextRange range) {
			return hasAuthorizedDestructiveSelection && AreSameRange(authorizedDestructiveSelection, NormalizeRange(range));
		}

		private bool NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit() {
			if (disposed || platformBehavior.Kind != EditorPlatformKind.Android) {
				return false;
			}

			var selection = editorCore.GetSelection();
			if (!selection.hasSelection) {
				ClearAuthorizedDestructiveSelection();
				return false;
			}

			TextRange normalized = NormalizeRange(selection.range);
			if (IsAuthorizedDestructiveSelection(normalized) || !IsSuspiciousImplicitTailSelection(normalized)) {
				return false;
			}

			TextPosition cursor = editorCore.GetCursorPosition();
			editorCore.SetCursorPosition(cursor);
			ClearAuthorizedDestructiveSelection();
			Console.Error.WriteLine(
				$"Collapsed suspicious implicit selection before destructive edit: {normalized.Start.Line}:{normalized.Start.Column}-{normalized.End.Line}:{normalized.End.Column}");
			SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(false, (TextRange?)null, editorCore.GetCursorPosition()));
			NotifySelectionMenuSelectionChanged(false);
			Flush();
			return true;
		}

		private bool IsSuspiciousImplicitTailSelection(TextRange range, TextPosition? cursorOverride = null) {
			Document? document = editorCore.GetDocument();
			if (document == null) {
				return false;
			}

			TextRange normalized = NormalizeRange(range);
			if (normalized.Start.Line == normalized.End.Line) {
				return false;
			}

			int lineCount = document.GetLineCount();
			if (lineCount <= 0) {
				return false;
			}

			int lastLine = lineCount - 1;
			string lastLineText = document.GetLineText(lastLine) ?? string.Empty;
			if (normalized.End.Line != lastLine || normalized.End.Column != lastLineText.Length) {
				return false;
			}

			if (normalized.Start.Line == 0 && normalized.Start.Column == 0) {
				return false;
			}

			TextPosition cursor = cursorOverride ?? editorCore.GetCursorPosition();
			return AreSamePosition(cursor, normalized.Start) || AreSamePosition(cursor, normalized.End);
		}

			private void TickAnimations() {
			if (!animationActive || disposed) {
				return;
			}

				var result = editorCore.TickAnimations();
				FireGestureEvents(result, result.TapPoint.HasValue ? ToPoint(result.TapPoint.Value) : default);
				FlushAfterGesture(result);
				if (!result.NeedsAnimation) {
					NotifyViewportGestureSettled();
					animationActive = false;
					animationTimer.Stop();
				}
			}

		private void UpdateAnimationTimer(bool needsAnimation) {
			if (needsAnimation) {
				if (!animationActive) {
					animationActive = true;
					animationTimer.Start();
				}
				return;
			}

			if (animationActive) {
				animationActive = false;
				animationTimer.Stop();
			}
		}

		private void OnCompletionItemsUpdated(IReadOnlyList<CompletionItem> items) {
			completionItems.Clear();
			completionItems.AddRange(items);
			CompletionItemsUpdated?.Invoke(items);
		}

		private void OnCompletionDismissed() {
			completionItems.Clear();
			CompletionDismissed?.Invoke();
		}

		private bool ShouldAutoShowSelectionMenu() {
			return !selectionMenuHostManaged && platformBehavior.UseSelectionMenuByDefault;
		}

		private bool ShouldRaiseContextMenuEvent() {
			return platformBehavior.UseContextMenuByDefault;
		}

		private bool ShouldRaiseLongPressEvent() {
			return platformBehavior.Kind == EditorPlatformKind.Android;
		}

		private void NotifySelectionMenuSelectionChanged(bool hasSelection) {
			if (ShouldAutoShowSelectionMenu()) {
				selectionMenuController.OnSelectionChanged(hasSelection);
			} else if (!hasSelection && !IsInlineSuggestionShowing()) {
				selectionMenuController.Dismiss();
			}
		}

		private void ScheduleSelectionMenuShow() {
			if (ShouldAutoShowSelectionMenu()) {
				selectionMenuController.ScheduleShow();
			}
		}

		private void NotifyViewportGestureSettled() {
			if (ShouldAutoShowSelectionMenu()) {
				selectionMenuController.OnViewportGestureSettled();
			} else if (selectionMenuController.IsShowing) {
				selectionMenuController.Dismiss();
			}
		}

		private void NotifySelectionMenuGestureResult(GestureResult result) {
			if (!ShouldAutoShowSelectionMenu()) {
				if (!result.HasSelection && !IsInlineSuggestionShowing()) {
					selectionMenuController.Dismiss();
				}
				return;
			}

			if (result.Type == GestureType.LONG_PRESS && !platformBehavior.UseLongPressForContextMenu) {
				if (!result.HasSelection && !IsInlineSuggestionShowing()) {
					selectionMenuController.Dismiss();
				}
				return;
			}

			selectionMenuController.OnGestureResult(result);
		}

		private void OnSelectionMenuCustomItemSelected(SelectionMenuItem item) {
			SelectionMenuItemClick?.Invoke(this, new SelectionMenuItemClickEventArgs(item));
		}

		private void FireGestureEvents(GestureResult result, Point screenPoint) {
			var sp = new PointF((float)screenPoint.X, (float)screenPoint.Y);
			bool deferLargeDocumentDoubleTap = result.Type == GestureType.DOUBLE_TAP && ShouldDeferLargeDocumentDoubleTap();
			if (!deferLargeDocumentDoubleTap) {
				NormalizeImplicitGestureSelection(ref result);
			}

			if ((result.Type == GestureType.SCROLL || result.Type == GestureType.FAST_SCROLL) &&
				ShouldUpdateInlineSuggestionPopupPosition()) {
				UpdateInlineSuggestionActionBarPosition();
			} else if (inlineSuggestion != null &&
				(result.Type == GestureType.TAP || result.Type == GestureType.DOUBLE_TAP || result.Type == GestureType.LONG_PRESS || result.Type == GestureType.DRAG_SELECT)) {
				bool dismissInlineSuggestion = result.Type == GestureType.DRAG_SELECT;
				if (!dismissInlineSuggestion) {
					bool cursorMovedAway =
						result.CursorPosition.Line != inlineSuggestion.Line ||
						result.CursorPosition.Column != inlineSuggestion.Column;
					dismissInlineSuggestion = cursorMovedAway || result.HasSelection;
				}
				if (dismissInlineSuggestion) {
					DismissInlineSuggestionInternal(emitDismissedCallback: true);
				}
			}

			if (!deferLargeDocumentDoubleTap && result.Type == GestureType.DOUBLE_TAP) {
				NormalizeDoubleTapSelection(ref result);
			}

			if (!deferLargeDocumentDoubleTap) {
				NotifySelectionMenuGestureResult(result);
			}

				switch (result.Type) {
					case GestureType.LONG_PRESS:
						tapFallbackArmed = false;
						UpdateDestructiveSelectionAuthorization(result.HasSelection, explicitSelectionSource: result.HasSelection, result.Selection);
						if (ShouldRaiseLongPressEvent()) {
							LongPress?.Invoke(this, new LongPressEventArgs(result.CursorPosition, sp));
						}
						CursorChanged?.Invoke(this, new CursorChangedEventArgs(result.CursorPosition));
						if (result.HasSelection) {
							SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(true, result.Selection, result.CursorPosition));
						}
						break;
					case GestureType.DOUBLE_TAP:
						tapFallbackArmed = false;
						if (deferLargeDocumentDoubleTap) {
							ScheduleDeferredLargeDocumentDoubleTap(result.CursorPosition, sp);
							break;
						}
						UpdateDestructiveSelectionAuthorization(result.HasSelection, explicitSelectionSource: result.HasSelection, result.Selection);
						DoubleTap?.Invoke(this, new DoubleTapEventArgs(result.CursorPosition, result.HasSelection, result.HasSelection ? result.Selection : (TextRange?)null, sp));
						CursorChanged?.Invoke(this, new CursorChangedEventArgs(result.CursorPosition));
						if (result.HasSelection) {
							SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(true, result.Selection, result.CursorPosition));
					}
					break;
				case GestureType.TAP:
					ClearAuthorizedDestructiveSelection();
					CursorChanged?.Invoke(this, new CursorChangedEventArgs(result.CursorPosition));
					if (completionItems.Count > 0) {
						completionProviderManager.Dismiss();
					}
					if (result.HitTarget.Type != HitTargetType.NONE) {
						switch (result.HitTarget.Type) {
							case HitTargetType.INLAY_HINT_TEXT:
							case HitTargetType.INLAY_HINT_ICON:
								InlayHintClick?.Invoke(this, new InlayHintClickEventArgs(
									result.HitTarget.Line,
									result.HitTarget.Column,
									result.HitTarget.Type == HitTargetType.INLAY_HINT_ICON ? InlayType.Icon : InlayType.Text,
									result.HitTarget.Type == HitTargetType.INLAY_HINT_ICON ? result.HitTarget.IconId : 0,
									null,
									sp));
								break;
							case HitTargetType.INLAY_HINT_COLOR:
								InlayHintClick?.Invoke(this, new InlayHintClickEventArgs(
									result.HitTarget.Line,
									result.HitTarget.Column,
									InlayType.Color,
									result.HitTarget.ColorValue,
									null,
									sp));
								break;
							case HitTargetType.GUTTER_ICON:
								GutterIconClick?.Invoke(this, new GutterIconClickEventArgs(result.HitTarget.Line, result.HitTarget.IconId, sp));
								break;
							case HitTargetType.CODELENS:
								CodeLensClick?.Invoke(this, new CodeLensClickEventArgs(
									result.HitTarget.Line,
									result.HitTarget.Column,
									result.HitTarget.IconId,
									sp));
								break;
							case HitTargetType.FOLD_PLACEHOLDER:
								case HitTargetType.FOLD_GUTTER:
									FoldToggle?.Invoke(this, new FoldToggleEventArgs(
										result.HitTarget.Line,
										result.HitTarget.Type == HitTargetType.FOLD_GUTTER,
										sp));
									break;
							}
						}
						if (TryApplyTapFallbackDoubleTap(result, sp)) {
							break;
						}
						SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(result.HasSelection, result.HasSelection ? result.Selection : (TextRange?)null, result.CursorPosition));
						break;
					case GestureType.SCROLL:
					case GestureType.FAST_SCROLL:
						tapFallbackArmed = false;
						ClearAuthorizedDestructiveSelection();
						ScrollChanged?.Invoke(this, new ScrollChangedEventArgs(result.ViewScrollX, result.ViewScrollY));
						if (completionItems.Count > 0) {
							completionProviderManager.Dismiss();
						}
						break;
					case GestureType.SCALE:
						tapFallbackArmed = false;
						ClearAuthorizedDestructiveSelection();
						SyncPlatformScale(result.ViewScale);
						ScaleChanged?.Invoke(this, new ScaleChangedEventArgs(result.ViewScale));
						break;
					case GestureType.DRAG_SELECT:
						tapFallbackArmed = false;
						UpdateDestructiveSelectionAuthorization(result.HasSelection, explicitSelectionSource: result.HasSelection, result.Selection);
						SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(result.HasSelection, result.HasSelection ? result.Selection : (TextRange?)null, result.CursorPosition));
						break;
					case GestureType.CONTEXT_MENU:
						tapFallbackArmed = false;
						if (ShouldRaiseContextMenuEvent()) {
							ContextMenu?.Invoke(this, new ContextMenuEventArgs(result.CursorPosition, sp));
						}
						break;
				}
			}

		private bool TryApplyTapFallbackDoubleTap(GestureResult result, PointF point) {
			if (platformBehavior.Kind != EditorPlatformKind.Android) {
				return false;
			}
			if (result.HasSelection || result.HitTarget.Type != HitTargetType.NONE) {
				tapFallbackArmed = false;
				return false;
			}

			long now = Environment.TickCount64;
			if (tapFallbackArmed && (now - lastTapFallbackTickMs) <= platformBehavior.DefaultDoubleTapTimeout) {
				float dx = point.X - lastTapFallbackPoint.X;
				float dy = point.Y - lastTapFallbackPoint.Y;
				float maxDistance = TapFallbackDoubleTapDistanceDip;
				if ((dx * dx + dy * dy) <= (maxDistance * maxDistance)) {
					tapFallbackArmed = false;
					if (TryGetPreferredDoubleTapSelection(result.CursorPosition, out TextRange range)) {
						TryApplyValidatedSelection(range, out _);
						var selection = editorCore.GetSelection();
						DoubleTap?.Invoke(this, new DoubleTapEventArgs(
							editorCore.GetCursorPosition(),
							selection.hasSelection,
							selection.hasSelection ? selection.range : (TextRange?)null,
							point));
						ScheduleSelectionMenuShow();
						return true;
					}
				}
			}

			tapFallbackArmed = true;
			lastTapFallbackTickMs = now;
			lastTapFallbackPoint = point;
			return false;
		}

		private bool ShouldDeferLargeDocumentDoubleTap() {
			if (platformBehavior.Kind != EditorPlatformKind.Android) {
				return false;
			}

			Document? document = editorCore.GetDocument();
			return document != null && document.GetLineCount() >= 12000;
		}

		private void ScheduleDeferredLargeDocumentDoubleTap(TextPosition cursorPosition, PointF screenPoint) {
			Console.Error.WriteLine($"Deferred large-document double tap at {cursorPosition.Line}:{cursorPosition.Column}");
			Dispatcher.UIThread.Post(() => {
				if (disposed) {
					return;
				}

				TextPosition effectiveCursor = cursorPosition;
				TextRange? appliedSelection = null;
				if (TryGetPreferredDoubleTapSelection(cursorPosition, out TextRange requestedRange) &&
					TryApplyValidatedSelection(requestedRange, out TextRange appliedRange)) {
					appliedSelection = appliedRange;
					effectiveCursor = editorCore.GetCursorPosition();
				} else {
					editorCore.SetCursorPosition(cursorPosition);
					effectiveCursor = editorCore.GetCursorPosition();
				}

				bool hasSelection = appliedSelection.HasValue;
				TextRange selectedRange = appliedSelection ?? default;
				Console.Error.WriteLine(
					hasSelection
						? $"Applied deferred large-document selection {selectedRange.Start.Line}:{selectedRange.Start.Column}-{selectedRange.End.Line}:{selectedRange.End.Column}"
						: $"Deferred large-document double tap collapsed to cursor {effectiveCursor.Line}:{effectiveCursor.Column}");
				UpdateDestructiveSelectionAuthorization(hasSelection, explicitSelectionSource: hasSelection, selectedRange);
				DoubleTap?.Invoke(this, new DoubleTapEventArgs(effectiveCursor, hasSelection, appliedSelection, screenPoint));
				CursorChanged?.Invoke(this, new CursorChangedEventArgs(effectiveCursor));
				if (hasSelection) {
					SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(true, appliedSelection, effectiveCursor));
				}
			}, DispatcherPriority.Background);
		}

		private void NormalizeDoubleTapSelection(ref GestureResult result) {
			if (!result.HasSelection) {
				if (TryGetPreferredDoubleTapSelection(result.CursorPosition, out TextRange fallbackRange)) {
					if (TryApplyValidatedSelection(fallbackRange, out _)) {
						var selection = editorCore.GetSelection();
						result.HasSelection = selection.hasSelection;
						result.Selection = selection.range;
						result.CursorPosition = editorCore.GetCursorPosition();
					}
				}
				return;
			}

			if (IsReasonableDoubleTapSelection(result.Selection, result.CursorPosition)) {
				return;
			}

			if (TryGetPreferredDoubleTapSelection(result.CursorPosition, out TextRange correctedRange)) {
				Console.Error.WriteLine(
					$"Corrected invalid double-tap selection: {result.Selection.Start.Line}:{result.Selection.Start.Column}-{result.Selection.End.Line}:{result.Selection.End.Column}");
				if (TryApplyValidatedSelection(correctedRange, out _)) {
					var selection = editorCore.GetSelection();
					result.HasSelection = selection.hasSelection;
					result.Selection = selection.range;
					result.CursorPosition = editorCore.GetCursorPosition();
					return;
				}
			}

			Console.Error.WriteLine(
				$"Collapsed invalid double-tap selection: {result.Selection.Start.Line}:{result.Selection.Start.Column}-{result.Selection.End.Line}:{result.Selection.End.Column}");
			editorCore.SetCursorPosition(result.CursorPosition);
			result.HasSelection = false;
			result.Selection = default;
		}

		private void NormalizeImplicitGestureSelection(ref GestureResult result) {
			if (platformBehavior.Kind != EditorPlatformKind.Android) {
				return;
			}

			if (result.Type == GestureType.DOUBLE_TAP) {
				NormalizeDoubleTapSelection(ref result);
				return;
			}

			if (result.Type == GestureType.LONG_PRESS && !result.HasSelection) {
				if (TryGetPreferredDoubleTapSelection(result.CursorPosition, out TextRange fallbackRange)) {
					Console.Error.WriteLine(
						$"Applied fallback long-press selection at {result.CursorPosition.Line}:{result.CursorPosition.Column}");
					if (TryApplyValidatedSelection(fallbackRange, out _)) {
						var selection = editorCore.GetSelection();
						result.HasSelection = selection.hasSelection;
						result.Selection = selection.range;
						result.CursorPosition = editorCore.GetCursorPosition();
					}
				}
				return;
			}

			if (!result.HasSelection) {
				return;
			}

			if (result.Type == GestureType.LONG_PRESS &&
				!IsReasonableDoubleTapSelection(result.Selection, result.CursorPosition) &&
				TryGetPreferredDoubleTapSelection(result.CursorPosition, out TextRange correctedRange)) {
				Console.Error.WriteLine(
					$"Corrected invalid long-press selection: {result.Selection.Start.Line}:{result.Selection.Start.Column}-{result.Selection.End.Line}:{result.Selection.End.Column}");
				if (TryApplyValidatedSelection(correctedRange, out _)) {
					var selection = editorCore.GetSelection();
					result.HasSelection = selection.hasSelection;
					result.Selection = selection.range;
					result.CursorPosition = editorCore.GetCursorPosition();
					return;
				}
			}

			if (!IsSuspiciousImplicitTailSelection(result.Selection, result.CursorPosition)) {
				return;
			}

			Console.Error.WriteLine(
				$"Collapsed suspicious implicit gesture selection: {result.Selection.Start.Line}:{result.Selection.Start.Column}-{result.Selection.End.Line}:{result.Selection.End.Column}");
			editorCore.SetCursorPosition(result.CursorPosition);
			result.HasSelection = false;
			result.Selection = default;
		}

		private bool TryGetPreferredDoubleTapSelection(TextPosition cursor, out TextRange range) {
			if (platformBehavior.Kind == EditorPlatformKind.Android &&
				TryBuildLocalWordSelection(cursor, out range)) {
				return true;
			}

			TextRange coreRange = editorCore.GetWordRangeAtCursor();
			if (IsReasonableDoubleTapSelection(coreRange, cursor)) {
				range = coreRange;
				return true;
			}

			if (platformBehavior.Kind == EditorPlatformKind.Android) {
				Console.Error.WriteLine(
					$"Invalid core word range at {cursor.Line}:{cursor.Column}: {coreRange.Start.Line}:{coreRange.Start.Column}-{coreRange.End.Line}:{coreRange.End.Column}");
			}

			return TryBuildLocalWordSelection(cursor, out range);
		}

		private bool TryApplyValidatedSelection(TextRange requestedRange, out TextRange appliedRange) {
			appliedRange = default;
			TextRange normalized = NormalizeRange(requestedRange);
			if (normalized.Start.Line == normalized.End.Line && normalized.Start.Column < normalized.End.Column) {
				return TryApplySelectionByCursorMovement(normalized, out appliedRange);
			}

			editorCore.SetSelection(normalized.Start.Line, normalized.Start.Column, normalized.End.Line, normalized.End.Column);
			var selection = editorCore.GetSelection();
			if (TryGetMatchingSelectionRange(selection, normalized, out appliedRange)) {
				return true;
			}

			Console.Error.WriteLine(
				$"editorCore.SetSelection mismatch: requested {normalized.Start.Line}:{normalized.Start.Column}-{normalized.End.Line}:{normalized.End.Column}, actual {selection.range.Start.Line}:{selection.range.Start.Column}-{selection.range.End.Line}:{selection.range.End.Column}");

			if (TryApplySelectionByCursorMovement(normalized, out appliedRange)) {
				return true;
			}

			return false;
		}

		private bool TryApplySelectionByCursorMovement(TextRange requestedRange, out TextRange appliedRange) {
			appliedRange = default;
			TextRange normalized = NormalizeRange(requestedRange);
			if (normalized.Start.Line != normalized.End.Line || normalized.Start.Column >= normalized.End.Column) {
				return false;
			}

			if (!TryPositionCursorForSelectionStart(normalized.Start)) {
				return false;
			}

			int steps = normalized.End.Column - normalized.Start.Column;
			for (int i = 0; i < steps; i++) {
				editorCore.MoveCursorRight(true);
			}

			var selection = editorCore.GetSelection();
			if (!TryGetMatchingSelectionRange(selection, normalized, out appliedRange)) {
				return false;
			}

			Console.Error.WriteLine(
				$"Recovered same-line selection with cursor movement: {appliedRange.Start.Line}:{appliedRange.Start.Column}-{appliedRange.End.Line}:{appliedRange.End.Column}");
			return true;
		}

		private bool TryPositionCursorForSelectionStart(TextPosition start) {
			editorCore.SetCursorPosition(start);
			if (AreSamePosition(editorCore.GetCursorPosition(), start)) {
				return true;
			}

			Document? document = editorCore.GetDocument();
			string lineText = document?.GetLineText(start.Line) ?? string.Empty;
			editorCore.SetCursorPosition(new TextPosition { Line = start.Line, Column = 0 });
			if (lineText.Length > 0) {
				editorCore.MoveCursorRight(false);
				editorCore.MoveCursorLeft(false);
			}
			for (int i = 0; i < start.Column; i++) {
				editorCore.MoveCursorRight(false);
			}

			return AreSamePosition(editorCore.GetCursorPosition(), start);
		}

		private bool TryGetMatchingSelectionRange((bool hasSelection, TextRange range) selection, TextRange requestedRange, out TextRange matchingRange) {
			matchingRange = default;
			if (!selection.hasSelection) {
				return false;
			}

			TextRange actual = NormalizeRange(selection.range);
			if (!AreSamePosition(actual.Start, requestedRange.Start) || !AreSamePosition(actual.End, requestedRange.End)) {
				return false;
			}

			matchingRange = actual;
			return true;
		}

		private bool IsReasonableDoubleTapSelection(TextRange range, TextPosition cursor) {
			Document? document = editorCore.GetDocument();
			if (document == null) {
				return false;
			}
			if (cursor.Line < 0 || cursor.Line >= document.GetLineCount()) {
				return false;
			}

			string lineText = document.GetLineText(cursor.Line) ?? string.Empty;
			if (range.Start.Line != cursor.Line || range.End.Line != cursor.Line) {
				return false;
			}
			if (range.Start.Column < 0 || range.End.Column < 0 || range.Start.Column >= range.End.Column) {
				return false;
			}
			if (range.End.Column > lineText.Length) {
				return false;
			}

			int clampedCursor = Math.Clamp(cursor.Column, 0, lineText.Length);
			return clampedCursor >= range.Start.Column && clampedCursor <= range.End.Column;
		}

		private bool TryBuildLocalWordSelection(TextPosition cursor, out TextRange range) {
			range = default;
			Document? document = editorCore.GetDocument();
			if (document == null) {
				return false;
			}
			if (cursor.Line < 0 || cursor.Line >= document.GetLineCount()) {
				return false;
			}

			string lineText = document.GetLineText(cursor.Line) ?? string.Empty;
			if (lineText.Length == 0) {
				return false;
			}

			int lineLength = lineText.Length;
			int probe = Math.Clamp(cursor.Column, 0, lineLength);
			if (probe == lineLength) {
				probe--;
			}
			if (probe < 0) {
				return false;
			}

			if (!IsDoubleTapWordChar(lineText[probe])) {
				if (cursor.Column > 0 && cursor.Column - 1 < lineLength && IsDoubleTapWordChar(lineText[cursor.Column - 1])) {
					probe = cursor.Column - 1;
				} else if (cursor.Column < lineLength && IsDoubleTapWordChar(lineText[cursor.Column])) {
					probe = cursor.Column;
				} else {
					return false;
				}
			}

			int start = probe;
			while (start > 0 && IsDoubleTapWordChar(lineText[start - 1])) {
				start--;
			}
			int end = probe + 1;
			while (end < lineLength && IsDoubleTapWordChar(lineText[end])) {
				end++;
			}
			if (start >= end) {
				return false;
			}

			range = new TextRange {
				Start = new TextPosition { Line = cursor.Line, Column = start },
				End = new TextPosition { Line = cursor.Line, Column = end }
			};
			return true;
		}

		private static bool IsDoubleTapWordChar(char ch) => char.IsLetterOrDigit(ch) || ch == '_';

		private void FireKeyEventChanges(KeyEventResult result, TextChangeAction action, bool explicitSelectionSource = false) {
			if (result.ContentChanged || result.CursorChanged) {
				DismissInlineSuggestionInternal(emitDismissedCallback: true);
			}
			if (result.ContentChanged) {
				ClearAuthorizedDestructiveSelection();
				selectionMenuController.OnTextChanged();
				if (result.EditResult?.Changes != null && result.EditResult.Changes.Count > 0) {
					TextChanged?.Invoke(this, new TextChangedEventArgs(action, result.EditResult.Changes));
					decorationProviderManager.OnTextChanged(result.EditResult.Changes);
				} else {
					TextChanged?.Invoke(this, new TextChangedEventArgs(action));
					decorationProviderManager.OnTextChanged(null);
				}
				HandleCompletionAfterEdit(result.EditResult);
			}

			if (result.CursorChanged) {
				CursorChanged?.Invoke(this, new CursorChangedEventArgs(editorCore.GetCursorPosition()));
				if (!result.SelectionChanged) {
					NotifySelectionMenuSelectionChanged(editorCore.GetSelection().hasSelection);
				}
			}
			if (result.SelectionChanged) {
				var selection = editorCore.GetSelection();
				UpdateDestructiveSelectionAuthorization(selection.hasSelection, explicitSelectionSource, selection.range);
				SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(selection.hasSelection, selection.hasSelection ? selection.range : (TextRange?)null, editorCore.GetCursorPosition()));
				NotifySelectionMenuSelectionChanged(selection.hasSelection);
			}
		}

		private void FireTextChanged(TextChangeAction action, TextEditResult? editResult = null) {
			DismissInlineSuggestionInternal(emitDismissedCallback: true);
			ClearAuthorizedDestructiveSelection();
			selectionMenuController.OnTextChanged();
			if (editResult?.Changes != null && editResult.Changes.Count > 0) {
				TextChanged?.Invoke(this, new TextChangedEventArgs(action, editResult.Changes));
				decorationProviderManager.OnTextChanged(editResult.Changes);
			} else {
				TextChanged?.Invoke(this, new TextChangedEventArgs(action));
				decorationProviderManager.OnTextChanged(null);
			}

			CursorChanged?.Invoke(this, new CursorChangedEventArgs(editorCore.GetCursorPosition()));
			var selection = editorCore.GetSelection();
			SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(selection.hasSelection, selection.hasSelection ? selection.range : (TextRange?)null, editorCore.GetCursorPosition()));
			NotifySelectionMenuSelectionChanged(selection.hasSelection);
			HandleCompletionAfterEdit(editResult);
		}

		private void HandleCompletionAfterEdit(TextEditResult? editResult) {
			if (disposed || editorCore.IsInLinkedEditing()) {
				return;
			}

			TextChange? primaryChange = null;
			if (editResult?.Changes != null && editResult.Changes.Count > 0) {
				primaryChange = editResult.Changes[0];
			}

			bool completionShowing = completionItems.Count > 0;
			bool hasDeletion = false;
			if (editResult?.Changes != null) {
				foreach (TextChange change in editResult.Changes) {
					if (string.IsNullOrEmpty(change.NewText)) {
						hasDeletion = true;
						break;
					}
				}
			}

			if (completionShowing && hasDeletion) {
				completionProviderManager.Dismiss();
				return;
			}

			string newText = primaryChange?.NewText ?? string.Empty;
			if (newText.Length == 1) {
				if (completionProviderManager.IsTriggerCharacter(newText)) {
					completionProviderManager.TriggerCompletion(CompletionTriggerKind.Character, newText);
					return;
				}
				if (completionShowing) {
					completionProviderManager.TriggerCompletion(CompletionTriggerKind.Retrigger, null);
					return;
				}
				char ch = newText[0];
				if (char.IsLetterOrDigit(ch) || ch == '_') {
					completionProviderManager.TriggerCompletion(CompletionTriggerKind.Invoked, null);
				}
				return;
			}

			if (!completionShowing) {
				return;
			}

			completionProviderManager.TriggerCompletion(CompletionTriggerKind.Retrigger, null);
		}

		private void AcceptInlineSuggestionInternal() {
			if (disposed || inlineSuggestion == null) {
				return;
			}

			var accepted = inlineSuggestion;
			inlineSuggestion = null;
			HideInlineSuggestionActionBar();
			decorationProviderManager.RequestRefresh();

			try {
				inlineSuggestionListener?.OnSuggestionAccepted(accepted);
			} catch (Exception ex) {
				Console.Error.WriteLine($"Inline suggestion accept callback error: {ex.Message}");
			}
			InlineSuggestionAccepted?.Invoke(accepted);

			editorCore.SetCursorPosition(new TextPosition { Line = accepted.Line, Column = accepted.Column });
			var result = editorCore.InsertText(accepted.Text);
			FireTextChanged(TextChangeAction.Key, result);
			Flush();
		}

			private void DismissInlineSuggestionInternal(bool emitDismissedCallback) {
			if (inlineSuggestion == null) {
				HideInlineSuggestionActionBar();
				return;
			}

			var dismissed = inlineSuggestion;
			inlineSuggestion = null;
			HideInlineSuggestionActionBar();
			decorationProviderManager.RequestRefresh();

				if (emitDismissedCallback) {
				try {
					inlineSuggestionListener?.OnSuggestionDismissed(dismissed);
				} catch (Exception ex) {
					Console.Error.WriteLine($"Inline suggestion dismiss callback error: {ex.Message}");
				}
				InlineSuggestionDismissed?.Invoke(dismissed);
				}
				if (!editorCore.GetSelection().hasSelection) {
					selectionMenuController.Dismiss();
				}

				Flush();
			}

			private void EnsureInlineSuggestionActionBar() {
				if (inlineSuggestionPopup != null) {
					return;
				}

				var acceptButton = new Button {
					Content = "Accept (Tab)",
					Padding = new Thickness(8, 4),
					ClickMode = ClickMode.Press,
				};
				acceptButton.Click += (_, _) => AcceptInlineSuggestionInternal();
				acceptButton.AddHandler(InputElement.PointerPressedEvent, (_, e) => {
					if (!IsPrimaryPointerPress(acceptButton, e)) {
						return;
					}
					e.Handled = true;
					AcceptInlineSuggestionInternal();
				}, RoutingStrategies.Tunnel);

				var dismissButton = new Button {
					Content = "Dismiss (Esc)",
					Padding = new Thickness(8, 4),
					ClickMode = ClickMode.Press,
				};
				dismissButton.Click += (_, _) => DismissInlineSuggestionInternal(emitDismissedCallback: true);
				dismissButton.AddHandler(InputElement.PointerPressedEvent, (_, e) => {
					if (!IsPrimaryPointerPress(dismissButton, e)) {
						return;
					}
					e.Handled = true;
					DismissInlineSuggestionInternal(emitDismissedCallback: true);
				}, RoutingStrategies.Tunnel);

			var actions = new StackPanel {
				Orientation = Orientation.Horizontal,
				Spacing = 6,
			};
			actions.Children.Add(acceptButton);
			actions.Children.Add(dismissButton);

			inlineSuggestionPopup = new Popup {
				PlacementTarget = this,
				Placement = PlacementMode.AnchorAndGravity,
				PlacementAnchor = PopupAnchor.BottomLeft,
				PlacementGravity = PopupGravity.BottomLeft,
				HorizontalOffset = 8,
				VerticalOffset = 8,
				IsLightDismissEnabled = true,
				OverlayDismissEventPassThrough = true,
				Topmost = true,
				Child = new Border {
					Padding = new Thickness(8),
					CornerRadius = new CornerRadius(8),
					BorderThickness = new Thickness(1),
					BorderBrush = new SolidColorBrush(Color.Parse("#405A6B86")),
					Background = new SolidColorBrush(Color.Parse("#F0182231")),
					Child = actions,
				},
			};
		}

		private bool ShouldUpdateSelectionMenuPopupPosition() {
			return !selectionMenuHostManaged && selectionMenuController.IsShowing;
		}

		private bool ShouldUpdateInlineSuggestionPopupPosition() {
			return !selectionMenuHostManaged &&
				inlineSuggestionPopup?.IsOpen == true &&
				inlineSuggestion != null;
		}

		private void UpdateInlineSuggestionActionBarPosition() {
			if (!ShouldUpdateInlineSuggestionPopupPosition() || disposed) {
				return;
			}

			InlineSuggestion suggestion = inlineSuggestion!;
			Popup popup = inlineSuggestionPopup!;
			var anchor = editorCore.GetPositionRect(suggestion.Line, suggestion.Column);
			Rect viewport = GetPopupViewportRect();
			Size popupSize = MeasurePopupChild(popup);
			double popupWidth = Math.Max(1, popupSize.Width);
			double popupHeight = Math.Max(1, popupSize.Height);
			double maxX = Math.Max(viewport.X, viewport.Right - popupWidth - popup.HorizontalOffset);
			double maxY = Math.Max(viewport.Y, viewport.Bottom - popupHeight - popup.VerticalOffset - Math.Max(1f, anchor.Height));
			double anchorX = Math.Clamp(anchor.X, viewport.X, maxX);
			double anchorY = Math.Clamp(anchor.Y, viewport.Y, maxY);
			popup.PlacementTarget = this;
			popup.PlacementRect = new Rect(anchorX, anchorY, 1, Math.Max(1f, anchor.Height));
			if (attached && !popup.IsOpen) {
				popup.IsOpen = true;
			}
		}

		private void HideInlineSuggestionActionBar() {
			if (inlineSuggestionPopup != null) {
				inlineSuggestionPopup.IsOpen = false;
			}
		}

		private void EnsureRenderModelUpToDate() {
			if (disposed) {
				lastFrameBuildMs = 0f;
				return;
			}

			if (renderModelDirty == false) {
				lastFrameBuildMs = 0f;
				return;
			}

			renderer.BeginFrameMeasureStats();
			long buildStart = Stopwatch.GetTimestamp();
			ProtocolDecoder.RecycleRenderModel(renderModel);
			renderModel = null;
			renderModel = editorCore.BuildRenderModel();
			if (renderModel.HasValue && ShouldOptimizeRenderModelForDrawing(renderModel.Value)) {
				EditorRenderModel optimizedModel = renderModel.Value;
				OptimizeRenderModelForDrawing(ref optimizedModel);
				renderModel = optimizedModel;
			}
			lastFrameBuildMs = (float)((Stopwatch.GetTimestamp() - buildStart) * 1000.0 / Stopwatch.Frequency);
			renderModelDirty = false;
			LogRenderModelDebugOnce(renderModel);
			UpdateVisibleLineRangeCache(renderModel);
			if (pendingViewportDecorationRefresh && cachedVisibleEndLine >= cachedVisibleStartLine) {
				pendingViewportDecorationRefresh = false;
				Dispatcher.UIThread.Post(() => {
					if (!disposed) {
						decorationProviderManager.RequestRefresh();
					}
				}, DispatcherPriority.Background);
			}
		}

		private void LogRenderModelDebugOnce(EditorRenderModel? model) {
			if (renderModelDebugLogged || model == null || model.Value.VisualLines == null) {
				return;
			}
			if (!string.Equals(Environment.GetEnvironmentVariable("SWEETEDITOR_RENDER_DEBUG"), "1", StringComparison.Ordinal)) {
				renderModelDebugLogged = true;
				return;
			}

			if (model.Value.VisualLines.Count == 0) {
				return;
			}

			try {
				int coloredRunCount = 0;
				var samples = new List<string>();
				foreach (VisualLine line in model.Value.VisualLines) {
					if (line.Runs == null) {
						continue;
					}

					foreach (VisualRun run in line.Runs) {
						if (run.Style.Color != 0) {
							coloredRunCount++;
						}

						if (samples.Count >= 12) {
							continue;
						}

						string text = (run.Text ?? string.Empty).Replace("\r", "\\r").Replace("\n", "\\n");
						if (text.Length > 24) {
							text = text[..24];
						}
						samples.Add($"line={line.LogicalLine} wrap={line.WrapIndex} type={run.Type} color=0x{run.Style.Color:X8} font={run.Style.FontStyle} text={text}");
					}
				}

				string logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "sweeteditor-render.log");
				File.WriteAllLines(logPath, new[] {
					$"visibleLines={model.Value.VisualLines.Count} coloredRuns={coloredRunCount}",
				}.Concat(samples));
				renderModelDebugLogged = true;
			} catch {
				// Ignore diagnostics failures.
			}
		}

		private static void OptimizeRenderModelForDrawing(ref EditorRenderModel model) {
			List<VisualLine>? visualLines = model.VisualLines;
			if (visualLines == null || visualLines.Count == 0) {
				return;
			}

			for (int i = 0; i < visualLines.Count; i++) {
				VisualLine line = visualLines[i];
				List<VisualRun>? runs = line.Runs;
				if (runs == null || runs.Count < 2) {
					continue;
				}

				if (!TryMergeRenderableRuns(runs, out List<VisualRun>? mergedRuns)) {
					continue;
				}

				line.Runs = mergedRuns!;
				visualLines[i] = line;
				ProtocolDecoder.RecycleVisualRunList(runs);
			}
		}

		private bool ShouldOptimizeRenderModelForDrawing(EditorRenderModel model) {
			List<VisualLine>? visualLines = model.VisualLines;
			if (visualLines == null || visualLines.Count == 0) {
				return false;
			}

			if (platformBehavior.Kind != EditorPlatformKind.Android) {
				return true;
			}

			if (visualLines.Count > 144) {
				return false;
			}

			int totalRunCount = 0;
			for (int i = 0; i < visualLines.Count; i++) {
				totalRunCount += visualLines[i].Runs?.Count ?? 0;
				if (totalRunCount > 2400) {
					return false;
				}
			}

			if (totalRunCount < AndroidMergeMinTotalRuns) {
				return false;
			}

			if (totalRunCount < visualLines.Count * AndroidMergeMinAverageRunsPerLine) {
				return false;
			}

			return totalRunCount > 0;
		}

		private static bool TryMergeRenderableRuns(List<VisualRun> runs, out List<VisualRun>? mergedRuns) {
			mergedRuns = null;
			if (runs.Count < 2) {
				return false;
			}

			if (!HasMergeableRenderableRuns(runs)) {
				return false;
			}

			List<VisualRun> optimized = ProtocolDecoder.RentVisualRunList(runs.Count);
			VisualRun current = runs[0];
			System.Text.StringBuilder? mergedText = null;
			bool changed = false;

			for (int i = 1; i < runs.Count; i++) {
				VisualRun next = runs[i];
				if (CanMergeRenderableRuns(current, next)) {
					changed = true;
					if (mergedText == null) {
						mergedText = new System.Text.StringBuilder(current.Text ?? string.Empty);
					}
					if (!string.IsNullOrEmpty(next.Text)) {
						mergedText.Append(next.Text);
					}
					current.Type = VisualRunType.TEXT;
					current.Width = Math.Max(0f, (next.X + next.Width) - current.X);
					continue;
				}

				if (mergedText != null) {
					current.Text = mergedText.ToString();
					mergedText = null;
				}

				optimized.Add(current);
				current = next;
			}

			if (mergedText != null) {
				current.Text = mergedText.ToString();
			}
			optimized.Add(current);

			if (!changed) {
				ProtocolDecoder.RecycleVisualRunList(optimized);
				return false;
			}

			mergedRuns = optimized;
			return true;
		}

		private static bool HasMergeableRenderableRuns(List<VisualRun> runs) {
			for (int i = 1; i < runs.Count; i++) {
				if (CanMergeRenderableRuns(runs[i - 1], runs[i])) {
					return true;
				}
			}

			return false;
		}

		private static bool CanMergeRenderableRuns(VisualRun current, VisualRun next) {
			if (!CanMergeRenderableRun(current) || !CanMergeRenderableRun(next)) {
				return false;
			}

			int currentLength = current.Text?.Length ?? 0;
			int nextLength = next.Text?.Length ?? 0;
			if (currentLength + nextLength > MaxMergedRenderRunTextLength) {
				return false;
			}

			if (current.Style.Color != next.Style.Color ||
				current.Style.BackgroundColor != next.Style.BackgroundColor ||
				current.Style.FontStyle != next.Style.FontStyle) {
				return false;
			}

			if (Math.Abs(current.Y - next.Y) > 0.01f) {
				return false;
			}

			float expectedX = current.X + current.Width;
			return Math.Abs(expectedX - next.X) <= 1.0f;
		}

		private static bool CanMergeRenderableRun(VisualRun run) {
			if (run.Type != VisualRunType.TEXT && run.Type != VisualRunType.WHITESPACE) {
				return false;
			}

			return !string.IsNullOrEmpty(run.Text);
		}

		private void ScheduleViewportUpdate(Size size, bool force = false) {
			if (disposed) {
				return;
			}

			pendingViewportSize = size;
			if (force) {
				forceViewportUpdate = true;
			}
			if (viewportUpdateScheduled) {
				return;
			}

			viewportUpdateScheduled = true;
			Dispatcher.UIThread.Post(ApplyViewportUpdate, DispatcherPriority.Background);
		}

		private void ApplyViewportUpdate() {
			viewportUpdateScheduled = false;
			if (disposed || !attached) {
				return;
			}

			Size size = pendingViewportSize;
			if (size.Width <= 0 || size.Height <= 0) {
				return;
			}

			if (!forceViewportUpdate && size == appliedViewportSize) {
				return;
			}

			appliedViewportSize = size;
			forceViewportUpdate = false;
			editorCore.SetViewport((int)Math.Max(0, size.Width), (int)Math.Max(0, size.Height));
			if (pendingCursorViewportSync) {
				TextPosition cursor = editorCore.GetCursorPosition();
				editorCore.ScrollToLine(Math.Max(0, cursor.Line), (int)ScrollBehavior.TOP);
				pendingCursorViewportSync = false;
			}
			pendingViewportDecorationRefresh = true;
			NotifyTextInputStateChanged(textViewChanged: true);
			Flush();
		}

		private void UpdateVisibleLineRangeCache(EditorRenderModel? model) {
			int previousStart = cachedVisibleStartLine;
			int previousEnd = cachedVisibleEndLine;
			bool changed;

			var visualLines = model?.VisualLines;
			if (visualLines == null || visualLines.Count == 0) {
				cachedVisibleStartLine = 0;
				cachedVisibleEndLine = -1;
				changed = previousStart != cachedVisibleStartLine || previousEnd != cachedVisibleEndLine;
				if (changed) {
					decorationProviderManager.OnScrollChanged();
				}
				return;
			}

			VisualLine firstLine = visualLines[0];
			VisualLine lastLine = visualLines[visualLines.Count - 1];
			cachedVisibleStartLine = Math.Min(firstLine.LogicalLine, lastLine.LogicalLine);
			cachedVisibleEndLine = Math.Max(firstLine.LogicalLine, lastLine.LogicalLine);
			changed = previousStart != cachedVisibleStartLine || previousEnd != cachedVisibleEndLine;
			if (changed) {
				decorationProviderManager.OnScrollChanged();
			}
		}

		private void AttachTopLevelHooks() {
			TopLevel? topLevel = TopLevel.GetTopLevel(this);
			if (ReferenceEquals(attachedTopLevel, topLevel)) {
				return;
			}

			DetachTopLevelHooks();
			if (topLevel == null) {
				return;
			}

			attachedTopLevel = topLevel;
			attachedTopLevel.ScalingChanged += OnHostTopLevelScalingChanged;
			attachedTopLevel.BackRequested += OnHostTopLevelBackRequested;

			attachedInputPane = topLevel.InputPane;
			if (attachedInputPane != null) {
				attachedInputPane.StateChanged += OnHostInputPaneStateChanged;
			}

			attachedInsetsManager = topLevel.InsetsManager;
			if (attachedInsetsManager != null) {
				attachedInsetsManager.SafeAreaChanged += OnHostSafeAreaChanged;
			}

			ApplyHostTopLevelScale(topLevel);
			RefreshHostInsetsState();
		}

		private void DetachTopLevelHooks() {
			if (attachedTopLevel != null) {
				attachedTopLevel.ScalingChanged -= OnHostTopLevelScalingChanged;
				attachedTopLevel.BackRequested -= OnHostTopLevelBackRequested;
				attachedTopLevel = null;
			}

			if (attachedInputPane != null) {
				attachedInputPane.StateChanged -= OnHostInputPaneStateChanged;
				attachedInputPane = null;
			}

			if (attachedInsetsManager != null) {
				attachedInsetsManager.SafeAreaChanged -= OnHostSafeAreaChanged;
				attachedInsetsManager = null;
			}

			lastKnownInputPaneOccludedRect = default;
			lastKnownSafeAreaPadding = default;
		}

		private void OnHostTopLevelScalingChanged(object? sender, EventArgs e) {
			if (disposed) {
				return;
			}

			TopLevel? topLevel = attachedTopLevel ?? TopLevel.GetTopLevel(this);
			if (topLevel == null) {
				return;
			}

			ApplyHostTopLevelScale(topLevel);
			pendingCursorViewportSync = true;
			ScheduleViewportUpdate(Bounds.Size, force: true);
			if (ShouldUpdateSelectionMenuPopupPosition()) {
				selectionMenuController.UpdatePosition();
			}
			if (ShouldUpdateInlineSuggestionPopupPosition()) {
				UpdateInlineSuggestionActionBarPosition();
			}
		}

		private void OnHostTopLevelBackRequested(object? sender, RoutedEventArgs e) {
			if (disposed || e.Handled) {
				return;
			}

			if (completionItems.Count > 0) {
				completionProviderManager.Dismiss();
				e.Handled = true;
				return;
			}

			if (inlineSuggestion != null) {
				DismissInlineSuggestionInternal(emitDismissedCallback: true);
				e.Handled = true;
				return;
			}

			if (selectionMenuController.IsShowing) {
				selectionMenuController.Dismiss();
				e.Handled = true;
				return;
			}

			if (editorCore.IsComposing()) {
				editorCore.CompositionCancel();
				NotifyTextInputStateChanged(force: true);
				Flush();
				e.Handled = true;
				return;
			}

			var selection = editorCore.GetSelection();
			if (selection.hasSelection) {
				TextPosition cursor = editorCore.GetCursorPosition();
				SetSelection(cursor.Line, cursor.Column, cursor.Line, cursor.Column);
				e.Handled = true;
			}
		}

		private void OnHostInputPaneStateChanged(object? sender, InputPaneStateEventArgs e) {
			if (disposed) {
				return;
			}

			lastKnownInputPaneOccludedRect = e.EndRect;
			RefreshHostInsetsDependentUi(ensureCursorVisible: IsFocused);
		}

		private void OnHostSafeAreaChanged(object? sender, SafeAreaChangedArgs e) {
			if (disposed) {
				return;
			}

			lastKnownSafeAreaPadding = e.SafeAreaPadding;
			RefreshHostInsetsDependentUi(ensureCursorVisible: false);
		}

		private void ApplyHostTopLevelScale(TopLevel topLevel) {
			float density = (float)Math.Max(0.5, topLevel.RenderScaling);
			renderer.SetPlatformDensity(density);
			editorCore.SetHandleConfig(EditorRenderer.ComputeHandleHitConfig(platformBehavior.HandleHitScale * density));
			editorCore.OnFontMetricsChanged();
			NotifyTextInputStateChanged(textViewChanged: true, force: true);
		}

		private void RefreshHostInsetsState() {
			if (attachedInputPane != null) {
				lastKnownInputPaneOccludedRect = attachedInputPane.OccludedRect;
			}
			if (attachedInsetsManager != null) {
				lastKnownSafeAreaPadding = attachedInsetsManager.SafeAreaPadding;
			}

			RefreshHostInsetsDependentUi(ensureCursorVisible: false);
		}

		private void RefreshHostInsetsDependentUi(bool ensureCursorVisible) {
			if (disposed || !attached) {
				return;
			}

			// Do not align the caret line to viewport top when IME state changes.
			// Android host code performs a minimal scroll only when the IME actually occludes the caret.
			bool scrolled = false;
			if (ensureCursorVisible) {
				scrolled = EnsureCursorVisibleInAvailableViewport();
			}
			if (ShouldUpdateSelectionMenuPopupPosition()) {
				selectionMenuController.UpdatePosition();
			}
			if (ShouldUpdateInlineSuggestionPopupPosition()) {
				UpdateInlineSuggestionActionBarPosition();
			}
			NotifyTextInputStateChanged(textViewChanged: true, force: true);
			if (!scrolled && (ShouldUpdateSelectionMenuPopupPosition() || ShouldUpdateInlineSuggestionPopupPosition())) {
				RequestVisualInvalidate();
			}
		}

		private bool EnsureCursorVisibleInAvailableViewport() {
			Rect viewport = GetPopupViewportRect();
			if (viewport.Width <= 0 || viewport.Height <= 0) {
				return false;
			}

			CursorRect cursor = editorCore.GetCursorRect();
			ScrollMetrics scroll = editorCore.GetScrollMetrics();
			double cursorTop = cursor.Y;
			double cursorBottom = cursor.Y + Math.Max(1f, cursor.Height);
			double topPadding = Math.Min(12d, Math.Max(4d, viewport.Height * 0.08d));
			double bottomPadding = topPadding + (platformBehavior.Kind == EditorPlatformKind.Android ? 8d : 0d);
			float targetScrollY = scroll.ScrollY;

			if (cursorBottom > viewport.Bottom - bottomPadding) {
				targetScrollY += (float)(cursorBottom - (viewport.Bottom - bottomPadding));
			} else if (cursorTop < viewport.Top + topPadding) {
				targetScrollY -= (float)((viewport.Top + topPadding) - cursorTop);
			}

			if (Math.Abs(targetScrollY - scroll.ScrollY) < 0.5f) {
				return false;
			}

			SetScroll(scroll.ScrollX, Math.Max(0f, targetScrollY));
			return true;
		}

		private void SyncPlatformScale(float scale) {
			renderer.SetScale(scale);
			editorCore.OnFontMetricsChanged();
			NotifyTextInputStateChanged(textViewChanged: true);
		}

		private void OnTextInputMethodClientRequested(object? sender, TextInputMethodClientRequestedEventArgs e) {
			e.Client = textInputClient;
		}

		private void NotifyTextInputStateChanged(bool textViewChanged = false, bool force = false) {
			if (!force && (imeSuppressedByTouch || !IsFocused)) {
				return;
			}
			textInputClient.NotifyStateChanged(textViewChanged);
			lastTextInputNotificationTickMs = Environment.TickCount64;
		}

		private void ScheduleTextInputStateChanged() {
			if (textInputNotificationScheduled || disposed) {
				return;
			}

			textInputNotificationScheduled = true;
			long delayMs = 0;
			if (platformBehavior.Kind == EditorPlatformKind.Android) {
				long elapsed = Environment.TickCount64 - lastTextInputNotificationTickMs;
				if (elapsed < AndroidScheduledTextInputNotifyMinIntervalMs) {
					delayMs = AndroidScheduledTextInputNotifyMinIntervalMs - elapsed;
				}
			}

			DispatcherTimer.RunOnce(() => {
				textInputNotificationScheduled = false;
				if (disposed) {
					return;
				}

				NotifyTextInputStateChanged();
			}, TimeSpan.FromMilliseconds(delayMs), DispatcherPriority.Background);
		}

			private void SetImeSuppressedByTouch(bool suppressed) {
				if (imeSuppressedByTouch == suppressed) {
					return;
				}
				imeSuppressedByTouch = suppressed;
				InputMethod.SetIsInputMethodEnabled(this, !suppressed);
			}

		private void ApplyPlatformInteractionDefaults() {
			double renderScaling = TopLevel.GetTopLevel(this)?.RenderScaling ?? 1.0;
			float density = (float)Math.Max(0.5, renderScaling);
			renderer.SetPlatformDensity(density);

			// Core/event coordinates are DIP in Avalonia, so handle hit config must stay in DIP.
			editorCore.SetHandleConfig(EditorRenderer.ComputeHandleHitConfig(platformBehavior.HandleHitScale));
			if (!platformBehavior.TouchFirst) {
				return;
			}

			if (settings.IsGutterSticky()) {
				settings.SetGutterSticky(false);
			}

			editorCore.SetScrollbarConfig(new ScrollbarConfig {
				// Align closer to Android demo geometry for finger drag usability.
				Thickness = 7.0f,
				MinThumb = 40.0f,
				ThumbHitPadding = 16.0f,
				Mode = ScrollbarMode.TRANSIENT,
				ThumbDraggable = true,
				TrackTapMode = ScrollbarTrackTapMode.DISABLED,
				FadeDelayMs = 700,
				FadeDurationMs = 300,
			});
		}

		private Rect GetTextInputCursorRectangle() {
			CursorRect cursor = editorCore.GetCursorRect();
			return new Rect(cursor.X, cursor.Y, 1, Math.Max(1f, cursor.Height));
		}

		internal Rect GetPopupViewportRect() {
			double left = 0;
			double top = 0;
			double right = Math.Max(0, Bounds.Width);
			double bottom = Math.Max(0, Bounds.Height);

			TopLevel? topLevel = attachedTopLevel ?? TopLevel.GetTopLevel(this);
			if (topLevel != null) {
				Point origin = this.TranslatePoint(new Point(0, 0), topLevel) ?? default;
				if (lastKnownSafeAreaPadding.Left > 0) {
					left = Math.Max(left, lastKnownSafeAreaPadding.Left - origin.X);
				}
				if (lastKnownSafeAreaPadding.Top > 0) {
					top = Math.Max(top, lastKnownSafeAreaPadding.Top - origin.Y);
				}
				if (lastKnownSafeAreaPadding.Right > 0) {
					right = Math.Min(right, topLevel.Bounds.Width - lastKnownSafeAreaPadding.Right - origin.X);
				}
				if (lastKnownSafeAreaPadding.Bottom > 0) {
					bottom = Math.Min(bottom, topLevel.Bounds.Height - lastKnownSafeAreaPadding.Bottom - origin.Y);
				}
				if (lastKnownInputPaneOccludedRect.Width > 0 && lastKnownInputPaneOccludedRect.Height > 0) {
					double occludedTopLocal = lastKnownInputPaneOccludedRect.Top - origin.Y;
					if (!double.IsNaN(occludedTopLocal) && !double.IsInfinity(occludedTopLocal)) {
						bottom = Math.Min(bottom, occludedTopLocal);
					}
				}
			}

			left = Math.Clamp(left, 0d, Math.Max(0d, Bounds.Width));
			top = Math.Clamp(top, 0d, Math.Max(0d, Bounds.Height));
			right = Math.Clamp(right, left, Math.Max(left, Bounds.Width));
			bottom = Math.Clamp(bottom, top, Math.Max(top, Bounds.Height));
			return new Rect(left, top, Math.Max(0d, right - left), Math.Max(0d, bottom - top));
		}

		private bool IsTouchMovementBeyondFocusThreshold(Point current, Point origin) {
			double dx = current.X - origin.X;
			double dy = current.Y - origin.Y;
			double threshold = platformBehavior.TouchFocusThreshold;
			return (dx * dx + dy * dy) >= threshold * threshold;
		}

		private bool IsTouchMovementBeyondImeTapThreshold(Point current, Point origin) {
			double dx = current.X - origin.X;
			double dy = current.Y - origin.Y;
			double threshold = platformBehavior.TouchImeTapMaxMovementDip;
			return (dx * dx + dy * dy) >= threshold * threshold;
		}

		private static float NormalizeDirectScale(float scale) {
			if (float.IsNaN(scale) || float.IsInfinity(scale)) {
				return 1f;
			}
			return Math.Clamp(scale, 0.25f, 4f);
		}

		private static float NormalizeDirectScrollDelta(double delta) {
			if (double.IsNaN(delta) || double.IsInfinity(delta)) {
				return 0f;
			}
			return (float)Math.Clamp(delta, -4096d, 4096d);
		}

		private static bool IsIntrinsicTouchLikePointer(PointerType pointerType) {
			return pointerType is PointerType.Touch or PointerType.Pen;
		}

		private static bool HasPressedMouseButton(PointerPointProperties properties) {
			return properties.IsLeftButtonPressed || properties.IsRightButtonPressed || properties.IsMiddleButtonPressed;
		}

		private bool ShouldTreatPointerAsTouch(Control target, PointerEventArgs e, bool allowButtonlessMouseFallback) {
			if (IsIntrinsicTouchLikePointer(e.Pointer.Type)) {
				return true;
			}
			if (!platformBehavior.TouchFirst || !allowButtonlessMouseFallback) {
				return false;
			}

			PointerPoint point = e.GetCurrentPoint(target);
			return !HasPressedMouseButton(point.Properties);
		}

		internal bool IsPrimaryPointerPress(Control target, PointerPressedEventArgs e) {
			if (ShouldTreatPointerAsTouch(target, e, allowButtonlessMouseFallback: true)) {
				return true;
			}

			PointerPoint point = e.GetCurrentPoint(target);
			return point.Properties.IsLeftButtonPressed;
		}

		private void CancelActiveTouchSequence(bool fireEvents, bool notifyViewportSettled, bool flushAfterCancel) {
			if (!touchSequenceActive) {
				return;
			}

			touchSequenceActive = false;
			touchPendingFocus = false;
			touchPointerMoved = false;
			touchGestureHadScroll = false;

			var point = lastPointerPosition;
			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.TOUCH_CANCEL,
				Points = [ToPointF(point)],
				Modifiers = Modifier.NONE,
				DirectScale = 1,
			});
			if (fireEvents) {
				FireGestureEvents(result, point);
			}
			if (notifyViewportSettled) {
				NotifyViewportGestureSettled();
			}
			if (flushAfterCancel) {
				FlushAfterGesture(result);
			}
			UpdateAnimationTimer(result.NeedsAnimation);
		}

		private static Size MeasurePopupChild(Popup popup) {
			if (popup.Child == null) {
				return default;
			}

			popup.Child.Measure(Size.Infinity);
			return popup.Child.DesiredSize;
		}

		private void FlushTouchMove(GestureResult result) {
			long now = Environment.TickCount64;
			long elapsed = now - lastTouchMoveFlushTickMs;
			if (elapsed >= platformBehavior.TouchMoveFlushMinIntervalMs) {
				lastTouchMoveFlushTickMs = now;
				FlushAfterGesture(result);
				return;
			}
			ScheduleTouchMoveFlush(result);
		}

			private void ScheduleTouchMoveFlush(GestureResult result) {
			if (disposed || touchMoveFlushScheduled) {
				return;
			}

				touchMoveFlushScheduled = true;
				Dispatcher.UIThread.Post(() => {
					touchMoveFlushScheduled = false;
					if (!disposed) {
						lastTouchMoveFlushTickMs = Environment.TickCount64;
						FlushAfterGesture(result);
					}
				}, DispatcherPriority.Render);
			}

		private static bool ShouldNotifyTextInputAfterGesture(GestureResult result) {
			return result.Type is not (GestureType.SCROLL or GestureType.FAST_SCROLL or GestureType.SCALE);
		}

		private void FlushAfterGesture(GestureResult result) {
			if (ShouldNotifyTextInputAfterGesture(result)) {
				Flush();
				return;
			}

			FlushWithoutTextInputState();
		}

		private bool ExecuteKeyMapCommand(int commandId) {
			if (keyMap.TryInvokeHostCommand(this, commandId)) {
				return true;
			}

			return EditorKeyMap.GetCommandRoute(commandId) switch {
				EditorCommandRoute.Core => ExecuteCoreKeyMapCommand((EditorCommand)commandId),
				EditorCommandRoute.Host => ExecuteHostKeyMapCommand((EditorCommand)commandId),
				_ => false,
			};
		}

		private bool ExecuteCoreKeyMapCommand(EditorCommand command) {
			switch (command) {
				case EditorCommand.INSERT_TAB:
					if (inlineSuggestion != null) {
						AcceptInlineSuggestionInternal();
						return true;
					}
					if (TryHandleConfiguredTab(KeyModifiers.None)) {
						return true;
					}
					return ExecuteCoreKeyCommand(KeyCode.TAB, KeyModifier.NONE);

				case EditorCommand.INSERT_NEWLINE: {
					var action = newLineActionProviderManager.ProvideNewLineAction();
					if (action != null) {
						var editResult = editorCore.InsertText(action.Text);
						FireTextChanged(TextChangeAction.Key, editResult);
						Flush();
						return true;
					}
					return ExecuteCoreKeyCommand(KeyCode.ENTER, KeyModifier.NONE);
				}

				case EditorCommand.SELECT_ALL:
					editorCore.SelectAll();
					FireCursorAndSelectionStateChanged(explicitSelectionSource: true);
					Flush();
					return true;

				case EditorCommand.UNDO: {
					var editResult = editorCore.Undo();
					if (editResult == null) {
						return false;
					}
					FireTextChanged(TextChangeAction.Key, editResult);
					Flush();
					return true;
				}

				case EditorCommand.REDO: {
					var editResult = editorCore.Redo();
					if (editResult == null) {
						return false;
					}
					FireTextChanged(TextChangeAction.Key, editResult);
					Flush();
					return true;
				}

				case EditorCommand.MOVE_LINE_UP:
					return ExecuteCoreEditCommand(editorCore.MoveLineUp());

				case EditorCommand.MOVE_LINE_DOWN:
					return ExecuteCoreEditCommand(editorCore.MoveLineDown());

				case EditorCommand.COPY_LINE_UP:
					return ExecuteCoreEditCommand(editorCore.CopyLineUp());

				case EditorCommand.COPY_LINE_DOWN:
					return ExecuteCoreEditCommand(editorCore.CopyLineDown());

				case EditorCommand.DELETE_LINE:
					return ExecuteCoreEditCommand(editorCore.DeleteLine());

				case EditorCommand.INSERT_LINE_ABOVE:
					return ExecuteCoreEditCommand(editorCore.InsertLineAbove());

				case EditorCommand.INSERT_LINE_BELOW:
					return ExecuteCoreEditCommand(editorCore.InsertLineBelow());
			}

			if (TryMapCoreEditorCommandToKeyGesture(command, out KeyCode keyCode, out KeyModifier modifiers)) {
				return ExecuteCoreKeyCommand(keyCode, modifiers);
			}

			return false;
		}

		private bool ExecuteCoreEditCommand(TextEditResult editResult) {
			ClearAuthorizedDestructiveSelection();
			FireTextChanged(TextChangeAction.Key, editResult);
			Flush();
			return true;
		}

		private void FireCursorAndSelectionStateChanged(bool explicitSelectionSource = false) {
			CursorChanged?.Invoke(this, new CursorChangedEventArgs(editorCore.GetCursorPosition()));
			var selection = editorCore.GetSelection();
			UpdateDestructiveSelectionAuthorization(selection.hasSelection, explicitSelectionSource, selection.range);
			SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(selection.hasSelection, selection.hasSelection ? selection.range : (TextRange?)null, editorCore.GetCursorPosition()));
			NotifySelectionMenuSelectionChanged(selection.hasSelection);
		}

		private static bool TryMapCoreEditorCommandToKeyGesture(EditorCommand command, out KeyCode keyCode, out KeyModifier modifiers) {
			switch (command) {
				case EditorCommand.CURSOR_LEFT:
					keyCode = KeyCode.LEFT;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_RIGHT:
					keyCode = KeyCode.RIGHT;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_UP:
					keyCode = KeyCode.UP;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_DOWN:
					keyCode = KeyCode.DOWN;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_LINE_START:
					keyCode = KeyCode.HOME;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_LINE_END:
					keyCode = KeyCode.END;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_PAGE_UP:
					keyCode = KeyCode.PAGE_UP;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.CURSOR_PAGE_DOWN:
					keyCode = KeyCode.PAGE_DOWN;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.SELECT_LEFT:
					keyCode = KeyCode.LEFT;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_RIGHT:
					keyCode = KeyCode.RIGHT;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_UP:
					keyCode = KeyCode.UP;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_DOWN:
					keyCode = KeyCode.DOWN;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_LINE_START:
					keyCode = KeyCode.HOME;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_LINE_END:
					keyCode = KeyCode.END;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_PAGE_UP:
					keyCode = KeyCode.PAGE_UP;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.SELECT_PAGE_DOWN:
					keyCode = KeyCode.PAGE_DOWN;
					modifiers = KeyModifier.SHIFT;
					return true;
				case EditorCommand.BACKSPACE:
					keyCode = KeyCode.BACKSPACE;
					modifiers = KeyModifier.NONE;
					return true;
				case EditorCommand.DELETE_FORWARD:
					keyCode = KeyCode.DELETE_KEY;
					modifiers = KeyModifier.NONE;
					return true;
				default:
					keyCode = KeyCode.NONE;
					modifiers = KeyModifier.NONE;
					return false;
			}
		}

		private bool ExecuteHostKeyMapCommand(EditorCommand command) {
			switch (command) {
				case EditorCommand.COPY:
					CopyToClipboard();
					return true;
				case EditorCommand.PASTE:
					PasteFromClipboard();
					return true;
				case EditorCommand.CUT:
					CutToClipboard();
					return true;
				case EditorCommand.TRIGGER_COMPLETION:
					TriggerCompletion();
					return true;
				default:
					return false;
			}
		}

		private bool ExecuteCoreKeyCommand(KeyCode keyCode, KeyModifier modifiers) {
			bool explicitSelectionSource = IsSelectionGestureKey(keyCode, modifiers);
			if (IsDestructiveKey(keyCode)) {
				NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			}
			if (TryHandleAndroidPlainDeletionKey(keyCode, modifiers)) {
				return true;
			}
			if (keyCode == KeyCode.BACKSPACE && modifiers == KeyModifier.NONE && TryHandleBackspaceUnindent()) {
				return true;
			}
			var result = editorCore.HandleKeyEvent((ushort)keyCode, null, (byte)modifiers);
			if (!result.Handled) {
				return false;
			}

			FireKeyEventChanges(result, TextChangeAction.Key, explicitSelectionSource);
			Flush();
			return true;
		}

		private bool TryHandleAndroidPlainDeletionKey(Key key, KeyModifiers modifiers) {
			if (platformBehavior.Kind != EditorPlatformKind.Android || modifiers != KeyModifiers.None) {
				return false;
			}

			return key switch {
				Key.Back => ExecuteAndroidPlainDeletion(isBackspace: true),
				Key.Delete => ExecuteAndroidPlainDeletion(isBackspace: false),
				_ => false,
			};
		}

		private bool TryHandleAndroidPlainDeletionKey(KeyCode keyCode, KeyModifier modifiers) {
			if (platformBehavior.Kind != EditorPlatformKind.Android || modifiers != KeyModifier.NONE) {
				return false;
			}

			return keyCode switch {
				KeyCode.BACKSPACE => ExecuteAndroidPlainDeletion(isBackspace: true),
				KeyCode.DELETE_KEY => ExecuteAndroidPlainDeletion(isBackspace: false),
				_ => false,
			};
		}

		private bool ExecuteAndroidPlainDeletion(bool isBackspace) {
			NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			bool restoreBackspaceUnindent = false;
			if (isBackspace && editorCore.IsBackspaceUnindent()) {
				editorCore.SetBackspaceUnindent(false);
				restoreBackspaceUnindent = true;
			}

			TextEditResult result;
			try {
				result = isBackspace
					? editorCore.Backspace()
					: editorCore.DeleteForward();
			} finally {
				if (restoreBackspaceUnindent) {
					editorCore.SetBackspaceUnindent(true);
				}
			}

			if (result.Changes != null && result.Changes.Count > 0) {
				FireTextChanged(TextChangeAction.Key, result);
			}
			Flush();
			return true;
		}

		private static PointF ToPointF(Point point) => new((float)point.X, (float)point.Y);

		private static Point ToPoint(PointF point) => new(point.X, point.Y);

		private static Modifier ToModifiers(KeyModifiers modifiers) {
			Modifier result = Modifier.NONE;
			if ((modifiers & KeyModifiers.Shift) != 0) {
				result |= Modifier.SHIFT;
			}
			if ((modifiers & KeyModifiers.Control) != 0) {
				result |= Modifier.CTRL;
			}
			if ((modifiers & KeyModifiers.Alt) != 0) {
				result |= Modifier.ALT;
			}
			if ((modifiers & KeyModifiers.Meta) != 0) {
				result |= Modifier.META;
			}
			return result;
		}

		private static byte ToModifierMask(KeyModifiers modifiers) {
			byte result = 0;
			if ((modifiers & KeyModifiers.Shift) != 0) {
				result |= 1;
			}
			if ((modifiers & KeyModifiers.Control) != 0) {
				result |= 2;
			}
			if ((modifiers & KeyModifiers.Alt) != 0) {
				result |= 4;
			}
			if ((modifiers & KeyModifiers.Meta) != 0) {
				result |= 8;
			}
			return result;
		}

		private static ushort MapKeyToKeyCode(Key key) {
			return key switch {
				Key.Back => 8,
				Key.Tab => 9,
				Key.Enter => 13,
				Key.Escape => 27,
				Key.Delete => 46,
				Key.Left => 37,
				Key.Up => 38,
				Key.Right => 39,
				Key.Down => 40,
				Key.Home => 36,
				Key.End => 35,
				Key.PageUp => 33,
				Key.PageDown => 34,
				_ => 0,
			};
		}

		private static bool TryMapShortcut(Key key, out ushort keyCode) {
			switch (key) {
				case Key.A:
					keyCode = (ushort)'A';
					return true;
				case Key.C:
					keyCode = (ushort)'C';
					return true;
				case Key.V:
					keyCode = (ushort)'V';
					return true;
				case Key.X:
					keyCode = (ushort)'X';
					return true;
				case Key.Z:
					keyCode = (ushort)'Z';
					return true;
				case Key.Y:
					keyCode = (ushort)'Y';
					return true;
				default:
					keyCode = 0;
					return false;
			}
		}

		private static bool IsDestructiveKey(ushort keyCode) {
			return keyCode is 8 or 46;
		}

		private static bool IsDestructiveKey(KeyCode keyCode) {
			return keyCode is KeyCode.BACKSPACE or KeyCode.DELETE_KEY;
		}

		private static bool IsSelectionGestureKey(ushort keyCode, KeyModifiers modifiers) {
			if ((modifiers & KeyModifiers.Shift) == 0) {
				return false;
			}

			return keyCode is 33 or 34 or 35 or 36 or 37 or 38 or 39 or 40;
		}

		private static bool IsSelectionGestureKey(KeyCode keyCode, KeyModifier modifiers) {
			if ((modifiers & KeyModifier.SHIFT) == 0) {
				return false;
			}

			return keyCode is KeyCode.PAGE_UP or KeyCode.PAGE_DOWN or KeyCode.HOME or KeyCode.END or KeyCode.LEFT or KeyCode.UP or KeyCode.RIGHT or KeyCode.DOWN;
		}


		public LayoutMetrics GetLayoutMetrics() => editorCore.GetLayoutMetrics();

		private int GetIndentUnit() => languageConfiguration?.TabSize is int tabSize && tabSize > 0 ? tabSize : 4;

		private TextEditResult InsertConfiguredText(string text) {
			if (string.IsNullOrEmpty(text)) {
				return TextEditResult.Empty;
			}

			if (TryInsertAutoClosingPair(text, out TextEditResult? autoClosingResult)) {
				return autoClosingResult ?? TextEditResult.Empty;
			}

			return editorCore.InsertText(text);
		}

		private bool TryInsertAutoClosingPair(string text, out TextEditResult? result) {
			result = null;
			if (text.Length != 1) {
				return false;
			}
			var selection = editorCore.GetSelection();
			if (selection.hasSelection) {
				return false;
			}
			char typed = text[0];
			BracketPair? pair = editorCore.GetAutoClosingPairs().FirstOrDefault(p => p.Open?.Length == 1 && p.Close?.Length == 1 && p.Open[0] == typed);
			if (pair == null) {
				return false;
			}
			TextPosition cursor = editorCore.GetCursorPosition();
			Document? document = editorCore.GetDocument();
			string lineText = document?.GetLineText(cursor.Line) ?? string.Empty;
			char nextChar = cursor.Column >= 0 && cursor.Column < lineText.Length ? lineText[cursor.Column] : '\0';
			if (nextChar != '\0' && !char.IsWhiteSpace(nextChar) && nextChar != pair.Close[0]) {
				return false;
			}
			result = editorCore.InsertText(pair.Open + pair.Close);
			editorCore.SetCursorPosition(new TextPosition { Line = cursor.Line, Column = cursor.Column + pair.Open.Length });
			return true;
		}

		private bool TryHandleConfiguredTab(KeyModifiers modifiers) {
			if (modifiers != KeyModifiers.None) {
				return false;
			}
			if (!editorCore.IsInsertSpaces()) {
				return false;
			}
			int indentUnit = Math.Max(1, GetIndentUnit());
			TextPosition cursor = editorCore.GetCursorPosition();
			int remainder = cursor.Column % indentUnit;
			int spacesToInsert = remainder == 0 ? indentUnit : indentUnit - remainder;
			var result = editorCore.InsertText(new string(' ', spacesToInsert));
			FireTextChanged(TextChangeAction.Key, result);
			Flush();
			return true;
		}

		private bool TryHandleBackspaceUnindent() {
			if (platformBehavior.Kind == EditorPlatformKind.Android) {
				return false;
			}
			if (!editorCore.IsBackspaceUnindent()) {
				return false;
			}
			var selection = editorCore.GetSelection();
			if (selection.hasSelection) {
				return false;
			}
			TextPosition cursor = editorCore.GetCursorPosition();
			if (cursor.Column <= 0) {
				return false;
			}
			Document? document = editorCore.GetDocument();
			string lineText = document?.GetLineText(cursor.Line) ?? string.Empty;
			if (cursor.Column > lineText.Length) {
				return false;
			}
			string prefix = lineText.Substring(0, cursor.Column);
			if (prefix.Length == 0 || prefix.Any(ch => ch != ' ')) {
				return false;
			}
			int indentUnit = Math.Max(1, GetIndentUnit());
			int targetColumn = Math.Max(0, ((cursor.Column - 1) / indentUnit) * indentUnit);
			if (targetColumn == cursor.Column) {
				return false;
			}
			var result = editorCore.DeleteText(new TextRange {
				Start = new TextPosition { Line = cursor.Line, Column = targetColumn },
				End = new TextPosition { Line = cursor.Line, Column = cursor.Column }
			});
			FireTextChanged(TextChangeAction.Key, result);
			Flush();
			return true;
		}

		private string SafeGetTextInputSurroundingText() {
			try {
				return GetTextInputSurroundingText();
			} catch {
				return string.Empty;
			}
		}

		private TextSelection SafeGetTextInputSelection() {
			try {
				return GetTextInputSelection();
			} catch {
				return new TextSelection(0, 0);
			}
		}

		private void SafeApplyTextInputSelection(TextSelection selection) {
			if (platformBehavior.Kind == EditorPlatformKind.Android) {
				return;
			}
			try {
				ApplyTextInputSelection(selection);
			} catch {
			}
		}

		private void SafeApplyPreeditText(string? preeditText, int? cursorPos) {
			try {
				ApplyPreeditText(preeditText, cursorPos);
			} catch {
			}
		}


		private string GetTextInputSurroundingText() {
			if (disposed || platformBehavior.Kind == EditorPlatformKind.Android) {
				return string.Empty;
			}

			Document? document = editorCore.GetDocument();
			if (document == null) {
				return string.Empty;
			}

			TextPosition cursor = editorCore.GetCursorPosition();
			int lineCount = document.GetLineCount();
			if (cursor.Line < 0 || cursor.Line >= lineCount) {
				return string.Empty;
			}

			return document.GetLineText(cursor.Line) ?? string.Empty;
		}

		private TextSelection GetTextInputSelection() {
			string surroundingText = GetTextInputSurroundingText();
			int max = surroundingText.Length;
			TextPosition cursor = editorCore.GetCursorPosition();
			var selection = editorCore.GetSelection();

			if (!selection.hasSelection ||
				selection.range.Start.Line != cursor.Line ||
				selection.range.End.Line != cursor.Line) {
				int caret = Math.Clamp(cursor.Column, 0, max);
				return new TextSelection(caret, caret);
			}

			int start = Math.Clamp(Math.Min(selection.range.Start.Column, selection.range.End.Column), 0, max);
			int end = Math.Clamp(Math.Max(selection.range.Start.Column, selection.range.End.Column), 0, max);
			return new TextSelection(start, end);
		}

		private void ApplyTextInputSelection(TextSelection selection) {
			if (disposed) {
				return;
			}

			// Android IMEs can issue aggressive selection updates during composing.
			// Applying them directly causes accidental auto-selection and can race with touch selection handles.
			if (platformBehavior.Kind == EditorPlatformKind.Android) {
				return;
			}

			Document? document = editorCore.GetDocument();
			if (document == null) {
				return;
			}

			TextPosition cursor = editorCore.GetCursorPosition();
			int lineCount = document.GetLineCount();
			if (cursor.Line < 0 || cursor.Line >= lineCount) {
				return;
			}

			string lineText = document.GetLineText(cursor.Line) ?? string.Empty;
			int max = lineText.Length;
			int start = Math.Clamp(selection.Start, 0, max);
			int end = Math.Clamp(selection.End, 0, max);
			if (start == end && !editorCore.GetSelection().hasSelection) {
				return;
			}
			SetSelection(cursor.Line, start, cursor.Line, end);
		}

		private void ApplyPreeditText(string? preeditText, int? cursorPos) {
			if (disposed || !editorCore.IsCompositionEnabled()) {
				return;
			}

			string text = preeditText ?? string.Empty;
			if (string.IsNullOrEmpty(text)) {
				if (editorCore.IsComposing()) {
					editorCore.CompositionCancel();
					NotifyTextInputStateChanged();
					Flush();
				}
				return;
			}

			if (!editorCore.IsComposing()) {
				editorCore.CompositionStart();
			}
			editorCore.CompositionUpdate(text);
			NotifyTextInputStateChanged();
			Flush();
		}

		private sealed class EditorTextInputClient : TextInputMethodClient {
			private readonly SweetEditorControl owner;

			public EditorTextInputClient(SweetEditorControl owner) {
				this.owner = owner;
			}

			public override global::Avalonia.Visual TextViewVisual => owner;

			public override bool SupportsPreedit => owner.editorCore.IsCompositionEnabled();

			public override bool SupportsSurroundingText => owner.platformBehavior.Kind != EditorPlatformKind.Android;

			public override string SurroundingText => owner.SafeGetTextInputSurroundingText();

			public override Rect CursorRectangle => owner.GetTextInputCursorRectangle();

			public override TextSelection Selection {
				get => owner.SafeGetTextInputSelection();
				set => owner.SafeApplyTextInputSelection(value);
			}

			public override void SetPreeditText(string? preeditText) {
				SetPreeditText(preeditText, null);
			}

			public override void SetPreeditText(string? preeditText, int? cursorPos) {
				owner.SafeApplyPreeditText(preeditText, cursorPos);
			}

			public void NotifyStateChanged(bool textViewChanged) {
				if (textViewChanged) {
					RaiseTextViewVisualChanged();
				}

				RaiseCursorRectangleChanged();
				RaiseSelectionChanged();
				RaiseSurroundingTextChanged();
			}
		}
	}
}
