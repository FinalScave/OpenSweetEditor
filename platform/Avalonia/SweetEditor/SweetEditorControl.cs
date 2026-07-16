using System;
using System.Collections.Generic;
using System.Diagnostics;
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
using AvaloniaRect = Avalonia.Rect;
using AvaloniaSize = Avalonia.Size;
using Button = Avalonia.Controls.Button;
using InputMethod = Avalonia.Input.InputMethod;
using Orientation = Avalonia.Layout.Orientation;

namespace SweetEditor {
	public sealed class DocumentLoadedEventArgs : EditorEventArgs {
		public DocumentLoadedEventArgs() : base(EditorEventType.DocumentLoaded) {
		}
	}

	public class SweetEditorControl : Control, IDisposable {
		private const int MaxMergedRenderRunTextLength = 192;
		private const int MobileMergeMinTotalRuns = 512;
		private const int MobileMergeMinAverageRunsPerLine = 10;

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
		public event EventHandler<LinkClickEventArgs>? LinkClick;
		public event EventHandler<FoldToggleEventArgs>? FoldToggle;
		public event EventHandler<SelectionMenuItemClickEventArgs>? SelectionMenuItemClick;
		public event Action<IReadOnlyList<CompletionItem>>? CompletionItemsUpdated;
		public event Action? CompletionDismissed;
		public event Action<InlineSuggestion>? InlineSuggestionAccepted;
		public event Action<InlineSuggestion>? InlineSuggestionDismissed;

		private const int DesktopAnimationIntervalMs = 16;
		private const int MobileScheduledTextInputNotifyMinIntervalMs = 48;
		private const float DefaultContentStartPadding = 3.0f;
		private const float TapFallbackDoubleTapDistanceDip = 18f;
		private const float InputFrameLinkMaxMs = 250f;
		private static readonly double PerfTickToMs = 1000.0 / Stopwatch.Frequency;

		private readonly EditorCore editorCore;
		private readonly EditorRenderer renderer;
		private readonly EditorSettings settings;
		private readonly DecorationProviderManager decorationProviderManager;
		private readonly CompletionProviderManager completionProviderManager;
		private readonly CompletionPopupController completionPopupController;
		private readonly NewLineActionProviderManager newLineActionProviderManager;
		private readonly SelectionMenuController selectionMenuController;
		private readonly DispatcherTimer desktopAnimationTimer;
		private readonly List<CompletionItem> completionItems = new();
		private readonly Dictionary<int, Point> activeTouchPoints = new();
		private readonly EditorTextInputClient textInputClient;
		private readonly EditorPlatformBehavior platformBehavior;
		private EditorKeyMap keyMap = CreateDefaultEditorKeyMap();
		private KeyChord pendingKeyChord = KeyChord.Empty;
		private TopLevel? attachedTopLevel;
		private IInputPane? attachedInputPane;
		private IInsetsManager? attachedInsetsManager;
		private AvaloniaRect lastKnownInputPaneOccludedRect;
		private Thickness lastKnownSafeAreaPadding;

		private readonly InlineSuggestionDecorationProvider inlineSuggestionDecorationProvider;
		private InlineSuggestion? inlineSuggestion;
		private IInlineSuggestionListener? inlineSuggestionListener;
		private Popup? inlineSuggestionPopup;

		private EditorRenderModel? renderModel;
		private EditorTheme currentTheme = EditorTheme.Dark();
		private LanguageConfiguration? languageConfiguration;
		private IEditorMetadata? metadata;
		private bool animationActive;
		private bool animationWaiting;
		private bool viewportMotionAnimationActive;
		private bool renderModelDirty = true;
		private bool visualInvalidationPending;
		private bool visualFrameRequestPending;
		private bool animationFrameTickPending;
		private float lastFrameBuildMs;
		private string activeInputPerfTag = string.Empty;
		private long activeInputPerfStartTick;
		private string latestInputPerfTag = string.Empty;
		private long latestInputPerfStartTick;
		private string pendingFrameInputPerfTag = string.Empty;
		private long pendingFrameInputStartTick;
		private long pendingFrameRequestTick;
		private long lastRenderStartTick;
		private bool attached;
		private bool disposed;
		private int cachedVisibleStartLine;
		private int cachedVisibleEndLine = -1;
		private bool pendingViewportDecorationRefresh = true;
		private bool pendingCursorViewportSync;
		private bool viewportUpdateScheduled;
		private bool forceViewportUpdate;
		private AvaloniaSize pendingViewportSize;
		private AvaloniaSize appliedViewportSize;
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
		private PointF lastTapFallbackPoint = new();
		private bool touchMoveFlushScheduled;
		private long lastTouchMoveFlushTickMs;
		private float lastDirectPinchScale = 1f;
		private bool hasAuthorizedDestructiveSelection;
		private TextRange authorizedDestructiveSelection = new();

		private static EditorKeyMap CreateDefaultEditorKeyMap() {
			return EditorKeyMap.DefaultKeyMap();
		}

		public SweetEditorControl() {
			Focusable = true;
			ClipToBounds = true;
			InputMethod.SetIsInputMethodEnabled(this, true);
			TextInputOptions.SetMultiline(this, true);
			if (OperatingSystem.IsAndroid()) {
				TextOptions.SetTextRenderingMode(this, TextRenderingMode.Alias);
			}

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
			completionPopupController = new CompletionPopupController(this, currentTheme);
			newLineActionProviderManager = new NewLineActionProviderManager(this);
			selectionMenuController = new SelectionMenuController(this);
			settings = new EditorSettings(this);
			textInputClient = new EditorTextInputClient(this);
			if (platformBehavior.EnableDirectPinch) {
				GestureRecognizers.Add(new PinchGestureRecognizer());
			}
			if (!platformBehavior.TouchFirst) {
				var scrollGestureRecognizer = new ScrollGestureRecognizer {
					CanHorizontallyScroll = true,
					CanVerticallyScroll = true,
					IsScrollInertiaEnabled = true,
				};
				GestureRecognizers.Add(scrollGestureRecognizer);
			}
			editorCore.SetKeyMap(keyMap.Bindings);

			decorationProviderManager.AddProvider(inlineSuggestionDecorationProvider);
			TextInputMethodClientRequested += OnTextInputMethodClientRequested;
			AddHandler(InputElement.PinchEvent, OnPinchGesture);
			AddHandler(InputElement.PinchEndedEvent, OnPinchEnded);
			AddHandler(InputElement.ScrollGestureEvent, OnScrollGesture);
			AddHandler(InputElement.ScrollGestureEndedEvent, OnScrollGestureEnded);
			AddHandler(InputElement.ScrollGestureInertiaStartingEvent, OnScrollGestureInertiaStarting);
			AddHandler(InputElement.PointerTouchPadGestureMagnifyEvent, OnPointerTouchPadGestureMagnify);

			completionProviderManager.ItemsUpdated += OnCompletionItemsUpdated;
			completionProviderManager.Dismissed += OnCompletionDismissed;
			completionPopupController.Confirmed += ApplyCompletionItem;
			selectionMenuController.CustomItemSelected += OnSelectionMenuCustomItemSelected;

			editorCore.SetEditorRenderColors(BuildEditorRenderColors(currentTheme));
			editorCore.SetEditorRangeEffectStyles(BuildEditorRangeEffectStyles(currentTheme));
			editorCore.RegisterBatchTextStyles(currentTheme.TextStyles);
			settings.SetContentStartPadding(DefaultContentStartPadding);

			desktopAnimationTimer = new DispatcherTimer {
				Interval = TimeSpan.FromMilliseconds(DesktopAnimationIntervalMs),
			};
			desktopAnimationTimer.Tick += (_, _) => {
				desktopAnimationTimer.Stop();
				animationWaiting = false;
				TickAnimations();
			};

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

		internal IEditorMetadata? MetadataInternal => metadata;

		public EditorSettings Settings => settings;

		internal EditorRenderer RendererInternal => renderer;

		internal EditorCore EditorCoreInternal => editorCore;

		internal bool IsMounted => attached && !disposed;

		public override void Render(DrawingContext context) {
			base.Render(context);
			long renderStartTick = renderer.IsPerfOverlayEnabled() ? Stopwatch.GetTimestamp() : 0;
			RecordRenderTiming(renderStartTick);
			visualInvalidationPending = false;
			if (disposed) {
				return;
			}

			EnsureRenderModelUpToDate();
			if (renderModel != null) {
				renderer.Render(context, renderModel, Bounds.Size, lastFrameBuildMs);
			}
		}

		private void RecordRenderTiming(long renderStartTick) {
			if (renderStartTick == 0) {
				return;
			}

			if (lastRenderStartTick != 0) {
				renderer.RecordRenderIntervalPerf((float)((renderStartTick - lastRenderStartTick) * PerfTickToMs));
			}
			lastRenderStartTick = renderStartTick;

			if (pendingFrameInputStartTick == 0) {
				return;
			}

			float inputToRenderMs = (float)((renderStartTick - pendingFrameInputStartTick) * PerfTickToMs);
			float requestToRenderMs = pendingFrameRequestTick != 0
				                          ? (float)((renderStartTick - pendingFrameRequestTick) * PerfTickToMs)
				                          : 0f;
			renderer.RecordFrameLatencyPerf(pendingFrameInputPerfTag, inputToRenderMs, requestToRenderMs);
			pendingFrameInputPerfTag = string.Empty;
			pendingFrameInputStartTick = 0;
			pendingFrameRequestTick = 0;
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
			animationWaiting = false;
			viewportMotionAnimationActive = false;
			desktopAnimationTimer.Stop();
			visualInvalidationPending = false;
			visualFrameRequestPending = false;
			animationFrameTickPending = false;
			controller?.Unbind(this);
			DetachTopLevelHooks();
			CancelActiveTouchSequence(notifyViewportSettled: false);
			SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
			selectionMenuController.Dismiss();
			completionPopupController.Dismiss();
			DismissInlineSuggestionInternal(emitDismissedCallback: false);
			pendingKeyChord = KeyChord.Empty;
			base.OnDetachedFromVisualTree(e);
		}

		protected override void OnPropertyChanged(AvaloniaPropertyChangedEventArgs change) {
			base.OnPropertyChanged(change);
			if (disposed || change.Property != BoundsProperty) {
				return;
			}

			var rect = change.GetNewValue<AvaloniaRect>();
			ScheduleViewportUpdate(rect.Size);
		}

		protected override AvaloniaSize ArrangeOverride(AvaloniaSize finalSize) {
			AvaloniaSize arranged = base.ArrangeOverride(finalSize);
			ScheduleViewportUpdate(arranged);
			return arranged;
		}

		protected override void OnGotFocus(FocusChangedEventArgs e) {
			base.OnGotFocus(e);
			if (disposed) {
				return;
			}
			if (imeSuppressedByTouch) {
				return;
			}

			NotifyTextInputStateChanged(textViewChanged: true);
		}

		protected override void OnLostFocus(FocusChangedEventArgs e) {
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
			using InputPerfScope perf = BeginInputPerf(touchLike ? "touch.down" : "pointer.down");
			if (touchLike && platformBehavior.SuppressImeOnTouchDown) {
				SetImeSuppressedByTouch(!IsFocused || imeSuppressedByTouch);
			} else {
				SetImeSuppressedByTouch(false);
			}
			if (!touchLike) {
				base.OnPointerPressed(e);
			}
			if (disposed) {
				return;
			}

			if (touchLike) {
				bool startingTouchSequence = activeTouchPoints.Count == 0;
				touchSequenceActive = true;
				touchPendingFocus = startingTouchSequence;
				touchPointerMoved = !startingTouchSequence;
				touchGestureHadScroll = !startingTouchSequence;
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

				activeTouchPoints[e.Pointer.Id] = point;
				EventType touchEventType = activeTouchPoints.Count > 1 ? EventType.TOUCH_POINTER_DOWN : EventType.TOUCH_DOWN;
				var touchResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = touchEventType,
					Points = GetActiveTouchPoints(),
					Modifiers = (int)modifiers,
					DirectScale = 1,
				});
				DispatchEditorActionResult(touchResult);
				e.Handled = true;
				return;
			}

			if (pointer.Properties.IsRightButtonPressed) {
				var result = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_RIGHT_DOWN,
					Points = [ToPointF(point)],
					Modifiers = (int)modifiers,
					DirectScale = 1,
				});
				DispatchEditorActionResult(result);
				e.Handled = true;
				return;
			}

			if (pointer.Properties.IsLeftButtonPressed) {
				var result = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.MOUSE_DOWN,
					Points = [ToPointF(point)],
					Modifiers = (int)modifiers,
					DirectScale = 1,
				});
				DispatchEditorActionResult(result);
				e.Handled = true;
			}
		}

		protected override void OnPointerMoved(PointerEventArgs e) {
			bool touchLike = ShouldTreatPointerAsTouch(this, e, allowButtonlessMouseFallback: touchSequenceActive);
			using InputPerfScope perf = BeginInputPerf(touchLike ? "touch.move" : "pointer.move");
			if (!touchLike) {
				base.OnPointerMoved(e);
			}
			if (disposed) {
				return;
			}

			var point = e.GetPosition(this);
			lastPointerPosition = point;
			if (touchLike) {
				// Avalonia can occasionally miss the first DOWN in gesture dispatch.
				// Recover by lazily starting the touch sequence on the first MOVE.
				if (!touchSequenceActive) {
					activeTouchPoints.Clear();
					activeTouchPoints[e.Pointer.Id] = point;
					touchSequenceActive = true;
					touchPendingFocus = false;
					touchPointerMoved = true;
					touchGestureHadScroll = false;
					touchDownPosition = point;
					touchDownTickMs = Environment.TickCount64;
					var touchDownResult = editorCore.HandleGestureEvent(new GestureEvent {
						Type = EventType.TOUCH_DOWN,
						Points = GetActiveTouchPoints(),
						Modifiers = (int)ToModifiers(e.KeyModifiers),
						DirectScale = 1,
					});
					DispatchEditorActionResult(touchDownResult);
				} else if (!activeTouchPoints.ContainsKey(e.Pointer.Id) && activeTouchPoints.Count > 0) {
					activeTouchPoints[e.Pointer.Id] = point;
					touchPendingFocus = false;
					touchPointerMoved = true;
					touchGestureHadScroll = true;
					var touchPointerDownResult = editorCore.HandleGestureEvent(new GestureEvent {
						Type = EventType.TOUCH_POINTER_DOWN,
						Points = GetActiveTouchPoints(),
						Modifiers = (int)ToModifiers(e.KeyModifiers),
						DirectScale = 1,
					});
					DispatchEditorActionResult(touchPointerDownResult);
				}

				SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
				if (touchPendingFocus && !touchPointerMoved &&
				    IsTouchMovementBeyondFocusThreshold(point, touchDownPosition)) {
					touchPointerMoved = true;
				}

				activeTouchPoints[e.Pointer.Id] = point;
				var touchResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.TOUCH_MOVE,
					Points = GetActiveTouchPoints(),
					Modifiers = (int)ToModifiers(e.KeyModifiers),
					DirectScale = 1,
				});
				if (touchResult.GestureType is GestureType.SCROLL or GestureType.FAST_SCROLL or GestureType.SCALE or GestureType.DRAG_SELECT) {
					touchGestureHadScroll = true;
				}
				DispatchEditorActionResult(touchResult);
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
				Modifiers = (int)ToModifiers(e.KeyModifiers),
				DirectScale = 1,
			});
			DispatchEditorActionResult(result);
			e.Handled = true;
		}

		protected override void OnPointerReleased(PointerReleasedEventArgs e) {
			bool touchLike = ShouldTreatPointerAsTouch(this, e, allowButtonlessMouseFallback: touchSequenceActive);
			using InputPerfScope perf = BeginInputPerf(touchLike ? "touch.up" : "pointer.up");
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

				activeTouchPoints[e.Pointer.Id] = point;
				if (activeTouchPoints.Count > 1) {
					activeTouchPoints.Remove(e.Pointer.Id);
					touchPendingFocus = false;
					touchPointerMoved = true;
					touchGestureHadScroll = true;
					List<PointF> remainingPoints = GetActiveTouchPoints();
					var touchPointerUpResult = editorCore.HandleGestureEvent(new GestureEvent {
						Type = EventType.TOUCH_POINTER_UP,
						Points = remainingPoints.Count > 0 ? remainingPoints : [ToPointF(point)],
						Modifiers = (int)ToModifiers(e.KeyModifiers),
						DirectScale = 1,
					});
					DispatchEditorActionResult(touchPointerUpResult);
					e.Handled = true;
					return;
				}

				activeTouchPoints.Remove(e.Pointer.Id);
				touchSequenceActive = false;
				if (!platformBehavior.TouchFirst) {
					e.Pointer.Capture(null);
				}
				var touchResult = editorCore.HandleGestureEvent(new GestureEvent {
					Type = EventType.TOUCH_UP,
					Points = [ToPointF(point)],
					Modifiers = (int)ToModifiers(e.KeyModifiers),
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
					    touchResult.GestureType == GestureType.SCROLL ||
					    touchResult.GestureType == GestureType.FAST_SCROLL ||
					    touchResult.GestureType == GestureType.SCALE ||
					    touchResult.GestureType == GestureType.DRAG_SELECT;
					bool textTap =
					    touchResult.GestureType == GestureType.TAP &&
					    touchResult.HitTarget.Type == HitTargetType.NONE &&
					    !touchResult.HasSelectionAfter;
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
						bool needsImeActivation = imeSuppressedByTouch || !IsFocused;
						if (needsImeActivation) {
							SetImeSuppressedByTouch(false);
							Focus();
							NotifyTextInputStateChanged(textViewChanged: true);
						}
					} else {
						SetImeSuppressedByTouch(platformBehavior.SuppressImeOnTouchDown);
					}
				}
				touchPendingFocus = false;
				touchPointerMoved = false;
				touchGestureHadScroll = false;

				DispatchEditorActionResult(touchResult);
				NotifyViewportGestureSettled();
				e.Handled = true;
				return;
			}

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.MOUSE_UP,
				Points = [ToPointF(point)],
				Modifiers = (int)ToModifiers(e.KeyModifiers),
				DirectScale = 1,
			});
			DispatchEditorActionResult(result);
			NotifyViewportGestureSettled();
			e.Handled = true;
		}

		protected override void OnPointerWheelChanged(PointerWheelEventArgs e) {
			base.OnPointerWheelChanged(e);
			using InputPerfScope perf = BeginInputPerf("wheel");
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
				Modifiers = (int)ToModifiers(e.KeyModifiers),
				WheelDeltaX = (float)e.Delta.X * 120f,
				WheelDeltaY = (float)e.Delta.Y * 120f,
				DirectScale = 1,
			});
			DispatchEditorActionResult(result);
			e.Handled = true;
		}

		protected override void OnPointerCaptureLost(PointerCaptureLostEventArgs e) {
			base.OnPointerCaptureLost(e);
			if (disposed || !touchSequenceActive) {
				return;
			}

			CancelActiveTouchSequence(notifyViewportSettled: true);
		}

		private void OnPinchGesture(object? sender, PinchEventArgs e) {
			using InputPerfScope perf = BeginInputPerf("direct.scale");
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
			float currentScale = NormalizeDirectScale((float)e.Scale);
			float directScale = lastDirectPinchScale > 0f ? currentScale / lastDirectPinchScale : currentScale;
			lastDirectPinchScale = currentScale;
			directScale = NormalizeDirectScale(directScale);
			if (Math.Abs(directScale - 1f) < 0.0001f) {
				return;
			}

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.DIRECT_SCALE,
				Points = [ToPointF(origin)],
				Modifiers = (int)KeyModifier.NONE,
				DirectScale = directScale,
			});
			DispatchEditorActionResult(result);
			e.Handled = true;
		}

		private void OnPinchEnded(object? sender, PinchEndedEventArgs e) {
			if (disposed || !platformBehavior.EnableDirectPinch) {
				return;
			}

			NotifyViewportGestureSettled();
			lastDirectPinchScale = 1f;
			e.Handled = true;
		}

		private void OnScrollGesture(object? sender, ScrollGestureEventArgs e) {
			using InputPerfScope perf = BeginInputPerf("direct.scroll");
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

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.DIRECT_SCROLL,
				Points = [ToPointF(point)],
				Modifiers = (int)KeyModifier.NONE,
				WheelDeltaX = deltaX,
				WheelDeltaY = deltaY,
				DirectScale = 1f,
			});
			DispatchEditorActionResult(result);
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
			using InputPerfScope perf = BeginInputPerf("touchpad.scale");
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

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.DIRECT_SCALE,
				Points = [ToPointF(point)],
				Modifiers = (int)ToModifiers(e.KeyModifiers),
				DirectScale = directScale,
			});
			DispatchEditorActionResult(result);
			e.Handled = true;
		}

		protected override void OnKeyDown(KeyEventArgs e) {
			base.OnKeyDown(e);
			using InputPerfScope perf = BeginInputPerf("key.down");
			if (disposed) {
				return;
			}
			if (imeSuppressedByTouch) {
				SetImeSuppressedByTouch(false);
			}
			RefreshPointerModifiers(e.KeyModifiers);

			if (completionPopupController.IsShowing) {
				if (e.Key == Key.Escape) {
					completionProviderManager.Dismiss();
					e.Handled = true;
					return;
				}
				if (completionPopupController.HandleKey(e.Key)) {
					e.Handled = true;
					return;
				}
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

			if (EditorKeyMap.TryFromAvalonia(e.Key, e.KeyModifiers, out KeyChord incomingChord)) {
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
				DispatchEditorActionResult(result);
				e.Handled = true;
			}
		}

		protected override void OnKeyUp(KeyEventArgs e) {
			base.OnKeyUp(e);
			if (disposed) {
				return;
			}
			RefreshPointerModifiers(e.KeyModifiers);
		}

		protected override void OnTextInput(TextInputEventArgs e) {
			base.OnTextInput(e);
			using InputPerfScope perf = BeginInputPerf("text.input");
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

			var result = ShouldCommitTextInputThroughIme()
				             ? CommitImeText(e.Text)
				             : InsertConfiguredText(e.Text);
			DispatchEditorActionResult(result);
			e.Handled = true;
		}

		public void LoadDocument(Document document) {
			if (disposed || document == null) {
				return;
			}

			ClearAuthorizedDestructiveSelection();
			EditorActionResult loadResult = editorCore.LoadDocument(document);
			EditorActionResult cursorResult = editorCore.SetCursorPosition(new TextPosition { Line = 0, Column = 0 });
			EditorActionResult scrollResult = editorCore.SetScroll(0, 0);
			decorationProviderManager.OnDocumentLoaded();
			pendingViewportDecorationRefresh = true;
			pendingCursorViewportSync = true;
			ScheduleViewportUpdate(Bounds.Size, force: true);
			DocumentLoaded?.Invoke(this, new DocumentLoadedEventArgs());
			DispatchEditorActionResult(loadResult);
			DispatchEditorActionResult(cursorResult);
			DispatchEditorActionResult(scrollResult);
		}

		public Document? GetDocument() => disposed ? null : editorCore.GetDocument();

		public EditorTheme GetTheme() => currentTheme;

		public void ApplyTheme(EditorTheme theme) {
			if (disposed || theme == null) {
				return;
			}

			currentTheme = theme;
			renderer.ApplyTheme(theme);
			completionPopupController.ApplyTheme(theme);
			DispatchEditorActionResult(editorCore.SetEditorRenderColors(BuildEditorRenderColors(theme)));
			DispatchEditorActionResult(editorCore.SetEditorRangeEffectStyles(BuildEditorRangeEffectStyles(theme)));
			DispatchEditorActionResult(editorCore.RegisterBatchTextStyles(theme.TextStyles));
		}

		private static EditorRenderColors BuildEditorRenderColors(EditorTheme theme) {
			uint codeLensColor = theme.CodeLensColor != 0 ? theme.CodeLensColor : theme.InlayHintTextColor;
			uint activeCodeLensColor = theme.CodeLensActiveColor != 0
			                               ? theme.CodeLensActiveColor
			                           : theme.CurrentLineNumberColor != 0 ? theme.CurrentLineNumberColor
			                                                               : theme.LineNumberColor;
			uint linkColor = theme.LinkColor != 0 ? theme.LinkColor : codeLensColor;
			uint activeLinkColor = theme.LinkActiveColor != 0 ? theme.LinkActiveColor : linkColor;
			return new EditorRenderColors {
				TextForeground = (int)theme.TextColor,
				LinkForeground = (int)linkColor,
				ActiveLinkForeground = (int)activeLinkColor,
				CodelensForeground = (int)codeLensColor,
				ActiveCodelensForeground = (int)activeCodeLensColor
			};
		}

		private static EditorRangeEffectStyles BuildEditorRangeEffectStyles(EditorTheme theme) {
			int linkedActive = (int)theme.LinkedEditingActiveColor;
			return new EditorRangeEffectStyles {
				Selection = new RangeEffectStyle {
					ForegroundColor = (int)theme.SelectionTextColor,
					BackgroundColor = (int)theme.SelectionColor
				},
				SearchMatch = new RangeEffectStyle { BackgroundColor = (int)theme.SearchMatchBgColor }, SearchCurrent = new RangeEffectStyle { BackgroundColor = (int)theme.SearchCurrentBgColor, BorderColor = (int)theme.SearchCurrentBorderColor }, DocumentHighlightText = new RangeEffectStyle { BackgroundColor = (int)theme.DocumentHighlightTextBgColor }, DocumentHighlightRead = new RangeEffectStyle { BackgroundColor = (int)theme.DocumentHighlightReadBgColor }, DocumentHighlightWrite = new RangeEffectStyle { BackgroundColor = (int)theme.DocumentHighlightWriteBgColor }, ImeComposition = new RangeEffectStyle { UnderlineColor = (int)theme.CompositionUnderlineColor, UnderlineStyle = RangeEffectUnderlineStyle.SOLID }, DiagnosticError = DiagnosticStyle(theme.DiagnosticErrorColor, RangeEffectUnderlineStyle.WAVY), DiagnosticWarning = DiagnosticStyle(theme.DiagnosticWarningColor, RangeEffectUnderlineStyle.WAVY), DiagnosticInfo = DiagnosticStyle(theme.DiagnosticInfoColor, RangeEffectUnderlineStyle.WAVY), DiagnosticHint = DiagnosticStyle(theme.DiagnosticHintColor, RangeEffectUnderlineStyle.DASHED), LinkedEditingActive = new RangeEffectStyle { BackgroundColor = WithAlpha(linkedActive, 0x20), BorderColor = linkedActive }, LinkedEditingInactive = new RangeEffectStyle { BorderColor = (int)theme.LinkedEditingInactiveColor }, BracketMatch = new RangeEffectStyle { BackgroundColor = (int)theme.BracketHighlightBgColor, BorderColor = (int)theme.BracketHighlightBorderColor }
			};
		}

		private static RangeEffectStyle DiagnosticStyle(uint color, RangeEffectUnderlineStyle underlineStyle) {
			return new RangeEffectStyle {
				UnderlineColor = (int)color,
				UnderlineStyle = underlineStyle
			};
		}

		private static int WithAlpha(int color, int alpha) {
			return color == 0 ? 0 : (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
		}

		public EditorSettings GetSettings() => settings;

		public void SetKeyMap(EditorKeyMap map) {
			if (map == null) {
				map = EditorKeyMap.DefaultKeyMap();
			}
			keyMap = map.Clone();
			DispatchEditorActionResult(editorCore.SetKeyMap(keyMap.Bindings));
			pendingKeyChord = KeyChord.Empty;
		}

		public EditorKeyMap GetKeyMap() {
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
					DispatchEditorActionResult(editorCore.SetBracketPairs(opens, closes));
				}
				if (config.TabSize.HasValue && config.TabSize.Value > 0) {
					DispatchEditorActionResult(editorCore.SetTabSize(config.TabSize.Value));
				}
				if (config.InsertSpaces.HasValue) {
					DispatchEditorActionResult(editorCore.SetInsertSpaces(config.InsertSpaces.Value));
				}
			}
		}

		public LanguageConfiguration? GetLanguageConfiguration() => languageConfiguration;

		public void SetMetadata<T>(T? metadata)
		    where T : class, IEditorMetadata {
			this.metadata = metadata;
			decorationProviderManager.RequestRefresh();
		}

		public T? GetMetadata<T>()
		    where T : class, IEditorMetadata => metadata as T;

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

		private void ApplyCompletionItem(CompletionItem item) {
			if (disposed || item == null) {
				return;
			}

			bool isSnippet = item.InsertTextFormat == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
			string text = item.InsertText ?? item.Label;
			if (item.TextEdit != null) {
				text = item.TextEdit.NewText;
				var edits = new List<TextEdit>(item.AdditionalTextEdits.Count + 1);
				edits.Add(isSnippet ? new TextEdit(item.TextEdit.Range, string.Empty) : item.TextEdit);
				edits.AddRange(item.AdditionalTextEdits);
				ApplyTextEdits(edits);
				if (isSnippet) {
					InsertSnippet(text);
				}
			} else if (item.AdditionalTextEdits.Count == 0) {
				if (isSnippet) {
					InsertSnippet(text);
				} else {
					InsertText(text);
				}
			} else {
				TextPosition cursor = GetCursorPosition();
				TextEdit primaryEdit = new(new TextRange(cursor, cursor), isSnippet ? string.Empty : text);
				var edits = new List<TextEdit>(item.AdditionalTextEdits.Count + 1);
				edits.Add(primaryEdit);
				edits.AddRange(item.AdditionalTextEdits);
				ApplyTextEdits(edits);
				if (isSnippet) {
					InsertSnippet(text);
				}
			}

			DismissCompletion();
		}

		public void SetCompletionItemRenderer(ICompletionItemRenderer? renderer) {
			completionPopupController.SetRenderer(renderer);
		}

		public void ShowInlineSuggestion(InlineSuggestion suggestion) {
			if (disposed || suggestion == null || string.IsNullOrEmpty(suggestion.Text)) {
				return;
			}

			inlineSuggestion = suggestion;
			EnsureInlineSuggestionActionBar();
			if (inlineSuggestionPopup != null) {
				inlineSuggestionPopup.IsOpen = attached;
			}
			UpdateInlineSuggestionActionBarPosition();
			ScheduleSelectionMenuShow();

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
			DispatchEditorActionResult(result);
		}

		/// <summary>Inserts text at the specified document position.</summary>
		/// <param name="position">Insertion position.</param>
		/// <param name="text">Text content.</param>
		public void InsertTextAt(TextPosition position, string text) {
			if (disposed || position == null || text == null) {
				return;
			}
			ReplaceText(new TextRange(position, position), text);
		}

		public void ReplaceText(TextRange range, string newText) {
			if (disposed || newText == null) {
				return;
			}
			var result = editorCore.ReplaceText(range, newText);
			DispatchEditorActionResult(result);
		}

		public void DeleteText(TextRange range) {
			if (disposed) {
				return;
			}
			var result = editorCore.DeleteText(range);
			DispatchEditorActionResult(result);
		}

		/// <summary>Applies multiple text edits as one undoable operation.</summary>
		/// <param name="edits">Text edits using the original document coordinates. The first edit is the primary edit.</param>
		public void ApplyTextEdits(IReadOnlyList<TextEdit> edits) {
			if (disposed || edits == null) {
				return;
			}
			var result = editorCore.ApplyTextEdits(edits);
			DispatchEditorActionResult(result);
		}

		public void MoveLineUp() {
			var result = editorCore.MoveLineUp();
			DispatchEditorActionResult(result);
		}

		public void MoveLineDown() {
			var result = editorCore.MoveLineDown();
			DispatchEditorActionResult(result);
		}

		public void CopyLineUp() {
			var result = editorCore.CopyLineUp();
			DispatchEditorActionResult(result);
		}

		public void CopyLineDown() {
			var result = editorCore.CopyLineDown();
			DispatchEditorActionResult(result);
		}

		public void DeleteLine() {
			var result = editorCore.DeleteLine();
			DispatchEditorActionResult(result);
		}

		public void InsertLineAbove() {
			var result = editorCore.InsertLineAbove();
			DispatchEditorActionResult(result);
		}

		public void InsertLineBelow() {
			var result = editorCore.InsertLineBelow();
			DispatchEditorActionResult(result);
		}

		public bool Undo() {
			var result = editorCore.Undo();
			if (result == null) {
				return false;
			}
			DispatchEditorActionResult(result);
			return true;
		}

		public bool Redo() {
			var result = editorCore.Redo();
			if (result == null) {
				return false;
			}
			DispatchEditorActionResult(result);
			return true;
		}

		public bool CanUndo() => !disposed && editorCore.CanUndo();

		public bool CanRedo() => !disposed && editorCore.CanRedo();

		public void Search(SearchRequest request) {
			if (disposed)
				return;
			DispatchEditorActionResult(editorCore.Search(request));
		}

		public void FindNextSearchMatch() {
			if (disposed)
				return;
			DispatchEditorActionResult(editorCore.FindNextSearchMatch());
		}

		public void FindPreviousSearchMatch() {
			if (disposed)
				return;
			DispatchEditorActionResult(editorCore.FindPreviousSearchMatch());
		}

		public void ReplaceCurrentSearchMatch(string replacement) {
			if (disposed)
				return;
			DispatchEditorActionResult(editorCore.ReplaceCurrentSearchMatch(replacement));
		}

		public void ReplaceAllSearchMatches(string replacement) {
			if (disposed)
				return;
			DispatchEditorActionResult(editorCore.ReplaceAllSearchMatches(replacement));
		}

		public void ClearSearch() {
			if (disposed)
				return;
			DispatchEditorActionResult(editorCore.ClearSearch());
		}

		public SearchState GetSearchState() => disposed ? new SearchState() : editorCore.GetSearchState();

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
			DispatchEditorActionResult(editorCore.SelectAll());
			ScheduleSelectionMenuShow();
		}

		public string GetSelectedText() => disposed ? string.Empty : editorCore.GetSelectedText();

		public void SetSelection(int startLine, int startColumn, int endLine, int endColumn) {
			DispatchEditorActionResult(editorCore.SetSelection(startLine, startColumn, endLine, endColumn));
		}

		public (bool hasSelection, TextRange range) GetSelection() => disposed ? (false, new TextRange()) : editorCore.GetSelection();

		public void SetCursorPosition(TextPosition position) {
			ClearAuthorizedDestructiveSelection();
			DispatchEditorActionResult(editorCore.SetCursorPosition(position));
		}

		public TextPosition GetCursorPosition() => disposed ? new TextPosition() : editorCore.GetCursorPosition();

		public TextRange? GetWordRangeAtCursor() => disposed ? null : editorCore.GetWordRangeAtCursor();

		public string GetWordAtCursor() => disposed ? string.Empty : editorCore.GetWordAtCursor();

		public void GotoPosition(int line, int column = 0) {
			ClearAuthorizedDestructiveSelection();
			DispatchEditorActionResult(editorCore.GotoPosition(line, column));
		}

		public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.GOTO_CENTER) {
			DispatchEditorActionResult(editorCore.ScrollToLine(line, (int)behavior));
		}

		public void SetScroll(float scrollX, float scrollY) {
			DispatchEditorActionResult(editorCore.SetScroll(scrollX, scrollY));
		}

		public ScrollMetrics GetScrollMetrics() => disposed ? new ScrollMetrics() : editorCore.GetScrollMetrics();

		public CursorRect GetPositionRect(int line, int column) => disposed ? new CursorRect() : editorCore.GetPositionRect(line, column);

		public CursorRect GetCursorRect() => disposed ? new CursorRect() : editorCore.GetCursorRect();

		public bool ToggleFold(int line) {
			EditorActionResult result = editorCore.ToggleFold(line);
			DispatchEditorActionResult(result);
			return result.Handled;
		}

		public bool FoldAt(int line) {
			EditorActionResult result = editorCore.FoldAt(line);
			DispatchEditorActionResult(result);
			return result.Handled;
		}

		public bool UnfoldAt(int line) {
			EditorActionResult result = editorCore.UnfoldAt(line);
			DispatchEditorActionResult(result);
			return result.Handled;
		}

		public bool IsLineVisible(int line) => !disposed && editorCore.IsLineVisible(line);

		public void FoldAll() {
			DispatchEditorActionResult(editorCore.FoldAll());
		}

		public void UnfoldAll() {
			DispatchEditorActionResult(editorCore.UnfoldAll());
		}

		public void RegisterTextStyle(uint styleId, int color, int backgroundColor, int fontStyle) =>
		    DispatchEditorActionResult(editorCore.RegisterTextStyle(styleId, color, backgroundColor, fontStyle));

		public void RegisterBatchTextStyles(IReadOnlyDictionary<int, TextStyle> stylesById) =>
		    DispatchEditorActionResult(editorCore.RegisterBatchTextStyles(stylesById));

		public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans) =>
		    DispatchEditorActionResult(editorCore.SetLineSpans(line, (int)layer, spans));

		public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineSpans((int)layer, spansByLine));

		public void ClearLineSpans(int line, SpanLayer layer) {
			DispatchEditorActionResult(editorCore.ClearLineSpans(line, (int)layer));
		}

		public void SetLineInlayHints(int line, IList<InlayHint> hints) =>
		    DispatchEditorActionResult(editorCore.SetLineInlayHints(line, hints));

		public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineInlayHints(hintsByLine));

		public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms) =>
		    DispatchEditorActionResult(editorCore.SetLinePhantomTexts(line, phantoms));

		public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLinePhantomTexts(phantomsByLine));

		public void SetLineGutterIcons(int line, IList<GutterIcon> icons) =>
		    DispatchEditorActionResult(editorCore.SetLineGutterIcons(line, icons));

		public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineGutterIcons(iconsByLine));

		public void SetMaxGutterIcons(int count) => settings.SetMaxGutterIcons(count);

		public int GetMaxGutterIcons() => settings.GetMaxGutterIcons();

		public void SetLineCodeLens(int line, IList<CodeLensItem> items) =>
		    DispatchEditorActionResult(editorCore.SetLineCodeLens(line, items));

		public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineCodeLens(itemsByLine));

		public void SetLineLinks(int line, IList<LinkSpan> links) =>
		    DispatchEditorActionResult(editorCore.SetLineLinks(line, links));

		public void SetBatchLineLinks(Dictionary<int, IList<LinkSpan>> linksByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineLinks(linksByLine));

		public string GetLinkTargetAt(int line, int column) =>
		    disposed ? string.Empty : editorCore.GetLinkTargetAt(line, column);

		public void SetLineDiagnostics(int line, IList<Diagnostic> items) =>
		    DispatchEditorActionResult(editorCore.SetLineDiagnostics(line, items));

		public void SetBatchLineDiagnostics(Dictionary<int, IList<Diagnostic>> diagsByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineDiagnostics(diagsByLine));

		public void SetLineDocumentHighlights(int line, IList<DocumentHighlight> items) =>
		    DispatchEditorActionResult(editorCore.SetLineDocumentHighlights(line, items));

		public void SetBatchLineDocumentHighlights(Dictionary<int, IList<DocumentHighlight>> highlightsByLine) =>
		    DispatchEditorActionResult(editorCore.SetBatchLineDocumentHighlights(highlightsByLine));

		public void SetIndentGuides(IList<IndentGuide> guides) =>
		    DispatchEditorActionResult(editorCore.SetIndentGuides(guides));

		public void SetBracketGuides(IList<BracketGuide> guides) =>
		    DispatchEditorActionResult(editorCore.SetBracketGuides(guides));

		public void SetFlowGuides(IList<FlowGuide> guides) =>
		    DispatchEditorActionResult(editorCore.SetFlowGuides(guides));

		public void SetSeparatorGuides(IList<SeparatorGuide> guides) =>
		    DispatchEditorActionResult(editorCore.SetSeparatorGuides(guides));

		public void SetFoldRegions(IList<FoldRegion> regions) =>
		    DispatchEditorActionResult(editorCore.SetFoldRegions(regions));

		public void ClearHighlights() => DispatchEditorActionResult(editorCore.ClearHighlights());

		public void ClearHighlights(SpanLayer layer) => DispatchEditorActionResult(editorCore.ClearHighlights((int)layer));

		public void ClearInlayHints() => DispatchEditorActionResult(editorCore.ClearInlayHints());

		public void ClearPhantomTexts() => DispatchEditorActionResult(editorCore.ClearPhantomTexts());

		public void ClearGutterIcons() => DispatchEditorActionResult(editorCore.ClearGutterIcons());

		public void ClearCodeLens() => DispatchEditorActionResult(editorCore.ClearCodeLens());

		public void ClearLinks() => DispatchEditorActionResult(editorCore.ClearLinks());

		public void ClearGuides() => DispatchEditorActionResult(editorCore.ClearGuides());

		public void ClearDiagnostics() => DispatchEditorActionResult(editorCore.ClearDiagnostics());

		public void ClearDocumentHighlights() => DispatchEditorActionResult(editorCore.ClearDocumentHighlights());

		public void ClearAllDecorations() {
			DispatchEditorActionResult(editorCore.ClearAllDecorations());
		}

		public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn) {
			DispatchEditorActionResult(editorCore.SetMatchedBrackets(openLine, openColumn, closeLine, closeColumn));
		}

		public void ClearMatchedBrackets() {
			DispatchEditorActionResult(editorCore.ClearMatchedBrackets());
		}

		public EditorActionResult InsertSnippet(string snippetTemplate) {
			NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit();
			var result = editorCore.InsertSnippet(snippetTemplate);
			DispatchEditorActionResult(result);
			return result;
		}

		public void StartLinkedEditing(LinkedEditingModel model) {
			DispatchEditorActionResult(editorCore.StartLinkedEditing(model));
		}

		public bool IsInLinkedEditing() => editorCore.IsInLinkedEditing();

		public bool LinkedEditingNext() {
			EditorActionResult result = editorCore.LinkedEditingNext();
			DispatchEditorActionResult(result);
			return result.Handled;
		}

		public bool LinkedEditingPrev() {
			EditorActionResult result = editorCore.LinkedEditingPrev();
			DispatchEditorActionResult(result);
			return result.Handled;
		}

		public void CancelLinkedEditing() {
			DispatchEditorActionResult(editorCore.CancelLinkedEditing());
		}

		public void Flush() {
			FlushCore(scheduleTextInputState: true);
		}

		private void FlushWithoutTextInputState() {
			FlushCore(scheduleTextInputState: false);
		}

		internal void DispatchEditorActionResult(EditorActionResult result) {
			if (disposed) {
				return;
			}

			if (result.GestureType != GestureType.UNDEFINED) {
				FireGestureEvents(result, ToPoint(result.TapPoint));
			}
			UpdateAnimationTimer(result);
			DispatchStateEvents(result);

			if (result.NeedsRedraw) {
				bool scheduleTextInputState = ShouldScheduleTextInputStateAfterResult(result);
				if (ShouldThrottleTouchMoveFlush(result)) {
					ScheduleTouchMoveFlush(scheduleTextInputState);
				} else {
					FlushCore(scheduleTextInputState);
				}
			} else if (result.NeedsImeSync) {
				ScheduleTextInputStateChanged();
			}
		}

		private void DispatchStateEvents(EditorActionResult result) {
			bool keyInput = result.Source == EditorActionSource.KEYBOARD;
			if (keyInput && (result.ContentChanged || result.CursorChanged)) {
				DismissInlineSuggestionInternal(emitDismissedCallback: true);
			}
			if (result.ContentChanged) {
				FireTextChanged(result);
			}

			TextPosition cursor = result.NeedsImeSync ? result.ImeSync.Cursor : result.CursorAfter;
			TextRange? selection = result.NeedsImeSync
			                           ? (result.ImeSync.HasSelection ? result.ImeSync.Selection : (TextRange?)null)
			                           : (result.HasSelectionAfter ? result.SelectionAfter : (TextRange?)null);
			if (result.CursorChanged) {
				CursorChanged?.Invoke(this, new CursorChangedEventArgs(cursor));
			}
			if (result.SelectionChanged) {
				bool hasSelection = selection != null;
				bool explicitSelectionSource = keyInput
				                                   ? IsExplicitKeySelectionSource(result)
				                                   : hasSelection;
				UpdateDestructiveSelectionAuthorization(hasSelection, explicitSelectionSource, selection ?? new TextRange());
				SelectionChanged?.Invoke(this, new SelectionChangedEventArgs(hasSelection, selection, cursor));
				NotifySelectionMenuSelectionChanged(hasSelection);
			}
			if (result.ScrollChanged) {
				ScrollChanged?.Invoke(this, new ScrollChangedEventArgs(result.ScrollXAfter, result.ScrollYAfter));
				if (completionPopupController.IsShowing) {
					completionPopupController.UpdatePosition();
				}
				if (ShouldUpdateSelectionMenuPopupPosition()) {
					selectionMenuController.UpdatePosition();
				}
			}
			if (result.ScaleChanged) {
				SyncPlatformScale(result.ScaleAfter);
				ScaleChanged?.Invoke(this, new ScaleChangedEventArgs(result.ScaleAfter));
			}
		}

		private static bool ShouldScheduleTextInputStateAfterResult(EditorActionResult result) {
			if (result.NeedsImeSync) {
				return true;
			}
			if (result.GestureType is GestureType.SCROLL or GestureType.FAST_SCROLL or GestureType.SCALE) {
				return false;
			}
			return result.Source is not(EditorActionSource.DECORATION or EditorActionSource.FOLDING or EditorActionSource.SETUP);
		}

		private bool ShouldThrottleTouchMoveFlush(EditorActionResult result) {
			return result.GestureEventType == EventType.TOUCH_MOVE &&
			       result.GestureType is GestureType.SCROLL or GestureType.FAST_SCROLL or GestureType.SCALE or GestureType.DRAG_SELECT &&
			       platformBehavior.TouchMoveFlushMinIntervalMs > 0;
		}

		private static bool IsExplicitKeySelectionSource(EditorActionResult result) {
			return (EditorBuiltinCommand)result.Command is
				EditorBuiltinCommand.SELECT_LEFT or
				EditorBuiltinCommand.SELECT_RIGHT or
				EditorBuiltinCommand.SELECT_UP or
				EditorBuiltinCommand.SELECT_DOWN or
				EditorBuiltinCommand.SELECT_LINE_START or
				EditorBuiltinCommand.SELECT_LINE_END or
				EditorBuiltinCommand.SELECT_PAGE_UP or
				EditorBuiltinCommand.SELECT_PAGE_DOWN or
				EditorBuiltinCommand.SELECT_ALL;
		}

		internal void FlushDecorationUpdate() {
			FlushWithoutTextInputState();
		}

		internal void RecordDecorationApplyPerf(float applyMs) {
			renderer.RecordDecorationApplyPerf(applyMs);
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
			CaptureFrameLatencyRequest();
			if (visualInvalidationPending) {
				RequestMobileVisualFrame();
				return;
			}

			visualInvalidationPending = true;
			InvalidateVisual();
			RequestMobileVisualFrame();
		}

		private InputPerfScope BeginInputPerf(string tag) {
			if (!renderer.IsPerfOverlayEnabled()) {
				return default;
			}

			long startTick = Stopwatch.GetTimestamp();
			activeInputPerfTag = tag;
			activeInputPerfStartTick = startTick;
			return new InputPerfScope(this, tag, startTick);
		}

		private void EndInputPerf(string tag, long startTick) {
			if (startTick == 0) {
				return;
			}
			if (!renderer.IsPerfOverlayEnabled()) {
				if (activeInputPerfStartTick == startTick) {
					activeInputPerfTag = string.Empty;
					activeInputPerfStartTick = 0;
				}
				return;
			}

			long now = Stopwatch.GetTimestamp();
			renderer.RecordInputPerf(tag, (float)((now - startTick) * PerfTickToMs));
			latestInputPerfTag = tag;
			latestInputPerfStartTick = startTick;
			if (activeInputPerfStartTick == startTick) {
				activeInputPerfTag = string.Empty;
				activeInputPerfStartTick = 0;
			}
		}

		private void CaptureFrameLatencyRequest() {
			if (!renderer.IsPerfOverlayEnabled()) {
				return;
			}

			long now = Stopwatch.GetTimestamp();
			bool hasActiveInput = activeInputPerfStartTick != 0;
			long inputStartTick = hasActiveInput ? activeInputPerfStartTick : latestInputPerfStartTick;
			if (inputStartTick == 0) {
				return;
			}

			if (!hasActiveInput && (now - inputStartTick) * PerfTickToMs > InputFrameLinkMaxMs) {
				return;
			}

			pendingFrameInputPerfTag = hasActiveInput ? activeInputPerfTag : latestInputPerfTag;
			pendingFrameInputStartTick = inputStartTick;
			pendingFrameRequestTick = now;
		}

		private void RequestMobileVisualFrame() {
			if (!platformBehavior.IsMobile || visualFrameRequestPending || disposed || !attached) {
				return;
			}

			TopLevel? topLevel = attachedTopLevel ?? TopLevel.GetTopLevel(this);
			if (topLevel == null) {
				return;
			}

			visualFrameRequestPending = true;
			topLevel.RequestAnimationFrame(_ => {
				visualFrameRequestPending = false;
				if (disposed || !attached) {
					return;
				}
				if (renderModelDirty || visualInvalidationPending || animationActive) {
					InvalidateVisual();
				}
			});
		}

		public (int start, int end) GetVisibleLineRange() {
			EnsureRenderModelUpToDate();
			return (cachedVisibleStartLine, cachedVisibleEndLine);
		}

		internal (int start, int end) GetCachedVisibleLineRange() {
			return (cachedVisibleStartLine, cachedVisibleEndLine);
		}

		public int GetTotalLineCount() => editorCore.GetDocument()?.GetLineCount() ?? -1;

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
			animationWaiting = false;
			viewportMotionAnimationActive = false;
			desktopAnimationTimer.Stop();
			visualFrameRequestPending = false;
			animationFrameTickPending = false;
			DismissInlineSuggestionInternal(emitDismissedCallback: false);

			controller?.Unbind(this);
			controller = null;

			selectionMenuController.CustomItemSelected -= OnSelectionMenuCustomItemSelected;
			selectionMenuController.Dispose();
			completionPopupController.Confirmed -= ApplyCompletionItem;
			completionPopupController.Dispose();

			completionProviderManager.Dispose();
			decorationProviderManager.Dispose();
			newLineActionProviderManager.Dispose();

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

		private void ClearAuthorizedDestructiveSelection() {
			hasAuthorizedDestructiveSelection = false;
			authorizedDestructiveSelection = new TextRange();
		}

		private void UpdateDestructiveSelectionAuthorization(bool hasSelection, bool explicitSelectionSource, TextRange range) {
			if (!hasSelection || !explicitSelectionSource) {
				ClearAuthorizedDestructiveSelection();
				return;
			}

			hasAuthorizedDestructiveSelection = true;
			authorizedDestructiveSelection = range.Normalized();
		}

		private bool IsAuthorizedDestructiveSelection(TextRange range) {
			return hasAuthorizedDestructiveSelection && AreSameRange(authorizedDestructiveSelection, range.Normalized());
		}

		private bool NormalizeSuspiciousImplicitSelectionBeforeDestructiveEdit() {
			if (disposed || !platformBehavior.IsMobile) {
				return false;
			}

			var selection = editorCore.GetSelection();
			if (!selection.hasSelection) {
				ClearAuthorizedDestructiveSelection();
				return false;
			}

			TextRange normalized = selection.range.Normalized();
			if (IsAuthorizedDestructiveSelection(normalized) || !IsSuspiciousImplicitTailSelection(normalized)) {
				return false;
			}

			TextPosition cursor = editorCore.GetCursorPosition();
			ClearAuthorizedDestructiveSelection();
			DispatchEditorActionResult(editorCore.SetCursorPosition(cursor));
			return true;
		}

		private bool IsSuspiciousImplicitTailSelection(TextRange range, TextPosition? cursorOverride = null) {
			Document? document = editorCore.GetDocument();
			if (document == null) {
				return false;
			}

			TextRange normalized = range.Normalized();
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
			bool viewportMotionSettled = viewportMotionAnimationActive && !result.NeedsViewportMotion;
			DispatchEditorActionResult(result);
			if (viewportMotionSettled) {
				NotifyViewportGestureSettled();
			}
		}

		private void UpdateAnimationTimer(EditorActionResult result) {
			desktopAnimationTimer.Stop();
			if (!result.NeedsAnimation) {
				animationActive = false;
				animationWaiting = false;
				viewportMotionAnimationActive = false;
				return;
			}

			animationActive = true;
			viewportMotionAnimationActive = result.NeedsViewportMotion;

			if (platformBehavior.IsMobile && result.NextAnimationDelayMs <= 0) {
				animationWaiting = false;
				RequestMobileAnimationFrameTick();
				return;
			}

			int delayMs = result.NextAnimationDelayMs <= 0
				              ? DesktopAnimationIntervalMs
				              : result.NextAnimationDelayMs;
			animationWaiting = result.NextAnimationDelayMs > 0;
			desktopAnimationTimer.Interval = TimeSpan.FromMilliseconds(Math.Max(1, delayMs));
			desktopAnimationTimer.Start();
		}

		private void RequestMobileAnimationFrameTick() {
			if (animationFrameTickPending || disposed || !attached) {
				return;
			}

			TopLevel? topLevel = attachedTopLevel ?? TopLevel.GetTopLevel(this);
			if (topLevel == null) {
				return;
			}

			animationFrameTickPending = true;
			topLevel.RequestAnimationFrame(_ => {
				animationFrameTickPending = false;
				if (!animationActive || animationWaiting || disposed || !attached) {
					return;
				}
				TickAnimations();
			});
		}

		private void OnCompletionItemsUpdated(IReadOnlyList<CompletionItem> items) {
			completionItems.Clear();
			completionItems.AddRange(items);
			completionPopupController.UpdateItems(items);
			CompletionItemsUpdated?.Invoke(items);
		}

		private void OnCompletionDismissed() {
			completionItems.Clear();
			completionPopupController.Dismiss();
			CompletionDismissed?.Invoke();
		}

		private bool ShouldAutoShowSelectionMenu() {
			return platformBehavior.UseSelectionMenuByDefault;
		}

		private bool ShouldRaiseContextMenuEvent() {
			return platformBehavior.UseContextMenuByDefault;
		}

		private bool ShouldRaiseLongPressEvent() {
			return platformBehavior.IsMobile;
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

		private void NotifySelectionMenuEditorActionResult(EditorActionResult result) {
			if (!ShouldAutoShowSelectionMenu()) {
				if (!result.HasSelectionAfter && !IsInlineSuggestionShowing()) {
					selectionMenuController.Dismiss();
				}
				return;
			}

			if (result.GestureType == GestureType.LONG_PRESS && !platformBehavior.UseLongPressForContextMenu) {
				if (!result.HasSelectionAfter && !IsInlineSuggestionShowing()) {
					selectionMenuController.Dismiss();
				}
				return;
			}

			selectionMenuController.OnEditorActionResult(result);
		}

		private void OnSelectionMenuCustomItemSelected(SelectionMenuItem item) {
			SelectionMenuItemClick?.Invoke(this, new SelectionMenuItemClickEventArgs(item));
		}

		private void FireGestureEvents(EditorActionResult result, Point screenPoint) {
			var sp = new PointF((float)screenPoint.X, (float)screenPoint.Y);
			bool deferLargeDocumentDoubleTap = result.GestureType == GestureType.DOUBLE_TAP && ShouldDeferLargeDocumentDoubleTap();
			if (!deferLargeDocumentDoubleTap) {
				NormalizeImplicitGestureSelection(ref result);
			}

			if ((result.GestureType == GestureType.SCROLL || result.GestureType == GestureType.FAST_SCROLL) &&
			    ShouldUpdateInlineSuggestionPopupPosition()) {
				UpdateInlineSuggestionActionBarPosition();
			} else if (inlineSuggestion != null &&
			           (result.GestureType == GestureType.TAP || result.GestureType == GestureType.DOUBLE_TAP || result.GestureType == GestureType.LONG_PRESS || result.GestureType == GestureType.DRAG_SELECT)) {
				bool dismissInlineSuggestion = result.GestureType == GestureType.DRAG_SELECT;
				if (!dismissInlineSuggestion) {
					bool cursorMovedAway =
					    result.CursorAfter.Line != inlineSuggestion.Line ||
					    result.CursorAfter.Column != inlineSuggestion.Column;
					dismissInlineSuggestion = cursorMovedAway || result.HasSelectionAfter;
				}
				if (dismissInlineSuggestion) {
					DismissInlineSuggestionInternal(emitDismissedCallback: true);
				}
			}

			if (!deferLargeDocumentDoubleTap && result.GestureType == GestureType.DOUBLE_TAP) {
				NormalizeDoubleTapSelection(ref result);
			}

			if (!deferLargeDocumentDoubleTap) {
				NotifySelectionMenuEditorActionResult(result);
			}

			switch (result.GestureType) {
			case GestureType.LONG_PRESS:
				tapFallbackArmed = false;
				UpdateDestructiveSelectionAuthorization(result.HasSelectionAfter, explicitSelectionSource: result.HasSelectionAfter, result.SelectionAfter);
				if (ShouldRaiseLongPressEvent()) {
					LongPress?.Invoke(this, new LongPressEventArgs(result.CursorAfter, sp));
				}
				break;
			case GestureType.DOUBLE_TAP:
				tapFallbackArmed = false;
				if (deferLargeDocumentDoubleTap) {
					ScheduleDeferredLargeDocumentDoubleTap(result.CursorAfter, sp);
					break;
				}
				UpdateDestructiveSelectionAuthorization(result.HasSelectionAfter, explicitSelectionSource: result.HasSelectionAfter, result.SelectionAfter);
				DoubleTap?.Invoke(this, new DoubleTapEventArgs(result.CursorAfter, result.HasSelectionAfter, result.HasSelectionAfter ? result.SelectionAfter : (TextRange?)null, sp));
				break;
			case GestureType.TAP:
				ClearAuthorizedDestructiveSelection();
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
						                                 result.HitTarget.Type == HitTargetType.INLAY_HINT_ICON ? InlayType.ICON : InlayType.TEXT,
						                                 result.HitTarget.Type == HitTargetType.INLAY_HINT_ICON ? result.HitTarget.IconId : 0,
						                                 null,
						                                 sp));
						break;
					case HitTargetType.INLAY_HINT_COLOR:
						InlayHintClick?.Invoke(this, new InlayHintClickEventArgs(
						                                 result.HitTarget.Line,
						                                 result.HitTarget.Column,
						                                 InlayType.COLOR,
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
					case HitTargetType.LINK:
						LinkClick?.Invoke(this, new LinkClickEventArgs(
						                            result.HitTarget.Line,
						                            result.HitTarget.Column,
						                            GetLinkTargetAt(result.HitTarget.Line, result.HitTarget.Column),
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
				break;
			case GestureType.SCROLL:
			case GestureType.FAST_SCROLL:
				tapFallbackArmed = false;
				ClearAuthorizedDestructiveSelection();
				if (completionItems.Count > 0) {
					completionProviderManager.Dismiss();
				}
				break;
			case GestureType.SCALE:
				tapFallbackArmed = false;
				ClearAuthorizedDestructiveSelection();
				break;
			case GestureType.DRAG_SELECT:
				tapFallbackArmed = false;
				UpdateDestructiveSelectionAuthorization(result.HasSelectionAfter, explicitSelectionSource: result.HasSelectionAfter, result.SelectionAfter);
				break;
			case GestureType.CONTEXT_MENU:
				tapFallbackArmed = false;
				if (ShouldRaiseContextMenuEvent()) {
					ContextMenu?.Invoke(this, new ContextMenuEventArgs(result.CursorAfter, sp));
				}
				break;
			}
		}

		private bool TryApplyTapFallbackDoubleTap(EditorActionResult result, PointF point) {
			if (!platformBehavior.IsMobile) {
				return false;
			}
			if (result.HasSelectionAfter || result.HitTarget.Type != HitTargetType.NONE) {
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
					if (TryGetPreferredDoubleTapSelection(result.CursorAfter, out TextRange range)) {
						TryApplyValidatedSelection(range, out _);
						RefreshGestureResultFromCoreSelection(result);
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
			if (!platformBehavior.IsMobile) {
				return false;
			}

			Document? document = editorCore.GetDocument();
			return document != null && document.GetLineCount() >= 12000;
		}

		private void ScheduleDeferredLargeDocumentDoubleTap(TextPosition cursorPosition, PointF screenPoint) {
			Dispatcher.UIThread.Post(() =>
			                         {
				                         if (disposed) {
					                         return;
				                         }

				                         TextPosition effectiveCursor = cursorPosition;
				                         TextRange? appliedSelection = null;
				                         TextPosition cursorBefore = editorCore.GetCursorPosition();
				                         var selectionBefore = editorCore.GetSelection();
				                         if (TryGetPreferredDoubleTapSelection(cursorPosition, out TextRange requestedRange) &&
				                             TryApplyValidatedSelection(requestedRange, out TextRange appliedRange)) {
					                         appliedSelection = appliedRange;
					                         effectiveCursor = editorCore.GetCursorPosition();
				                         } else {
					                         editorCore.SetCursorPosition(cursorPosition);
					                         effectiveCursor = editorCore.GetCursorPosition();
				                         }

				                         bool hasSelection = appliedSelection != null;
				                         TextRange selectedRange = appliedSelection ?? new TextRange();
				                         UpdateDestructiveSelectionAuthorization(hasSelection, explicitSelectionSource: hasSelection, selectedRange);
				                         DoubleTap?.Invoke(this, new DoubleTapEventArgs(effectiveCursor, hasSelection, appliedSelection, screenPoint));
				                         DispatchEditorActionResult(CreateSelectionStateResult(cursorBefore, selectionBefore.hasSelection, selectionBefore.range));
			                         },
			                         DispatcherPriority.Background);
		}

		private void NormalizeDoubleTapSelection(ref EditorActionResult result) {
			if (!result.HasSelectionAfter) {
				if (TryGetPreferredDoubleTapSelection(result.CursorAfter, out TextRange fallbackRange)) {
					if (TryApplyValidatedSelection(fallbackRange, out _)) {
						RefreshGestureResultFromCoreSelection(result);
					}
				}
				return;
			}

			if (IsReasonableDoubleTapSelection(result.SelectionAfter, result.CursorAfter)) {
				return;
			}

			if (TryGetPreferredDoubleTapSelection(result.CursorAfter, out TextRange correctedRange)) {
				if (TryApplyValidatedSelection(correctedRange, out _)) {
					RefreshGestureResultFromCoreSelection(result);
					return;
				}
			}

			editorCore.SetCursorPosition(result.CursorAfter);
			RefreshGestureResultFromCoreSelection(result);
		}

		private void NormalizeImplicitGestureSelection(ref EditorActionResult result) {
			if (!platformBehavior.IsMobile) {
				return;
			}

			if (result.GestureType == GestureType.DOUBLE_TAP) {
				NormalizeDoubleTapSelection(ref result);
				return;
			}

			if (result.GestureType == GestureType.LONG_PRESS && !result.HasSelectionAfter) {
				if (TryGetPreferredDoubleTapSelection(result.CursorAfter, out TextRange fallbackRange)) {
					if (TryApplyValidatedSelection(fallbackRange, out _)) {
						RefreshGestureResultFromCoreSelection(result);
					}
				}
				return;
			}

			if (!result.HasSelectionAfter) {
				return;
			}

			if (result.GestureType == GestureType.LONG_PRESS &&
			    !IsReasonableDoubleTapSelection(result.SelectionAfter, result.CursorAfter) &&
			    TryGetPreferredDoubleTapSelection(result.CursorAfter, out TextRange correctedRange)) {
				if (TryApplyValidatedSelection(correctedRange, out _)) {
					RefreshGestureResultFromCoreSelection(result);
					return;
				}
			}

			if (!IsSuspiciousImplicitTailSelection(result.SelectionAfter, result.CursorAfter)) {
				return;
			}

			editorCore.SetCursorPosition(result.CursorAfter);
			RefreshGestureResultFromCoreSelection(result);
		}

		private void RefreshGestureResultFromCoreSelection(EditorActionResult result) {
			var selection = editorCore.GetSelection();
			TextPosition cursor = editorCore.GetCursorPosition();
			result.CursorAfter = cursor;
			result.HasSelectionAfter = selection.hasSelection;
			result.SelectionAfter = selection.hasSelection ? selection.range : new TextRange();
			result.CursorChanged = true;
			result.SelectionChanged = true;
			result.NeedsImeSync = true;
			result.ImeSync.Cursor = cursor;
			result.ImeSync.HasSelection = selection.hasSelection;
			result.ImeSync.Selection = selection.hasSelection ? selection.range : new TextRange();
		}

		private EditorActionResult CreateSelectionStateResult(TextPosition cursorBefore, bool hasSelectionBefore, TextRange selectionBefore) {
			var selection = editorCore.GetSelection();
			TextPosition cursor = editorCore.GetCursorPosition();
			bool cursorChanged = !AreSamePosition(cursorBefore, cursor);
			bool selectionChanged = hasSelectionBefore != selection.hasSelection ||
			                        (selection.hasSelection && !AreSameRange(selectionBefore, selection.range));

			return new EditorActionResult {
				Handled = true,
				Source = EditorActionSource.PROGRAMMATIC,
				CursorChanged = cursorChanged,
				SelectionChanged = selectionChanged,
				NeedsRedraw = cursorChanged || selectionChanged,
				NeedsImeSync = cursorChanged || selectionChanged,
				CursorBefore = cursorBefore,
				CursorAfter = cursor,
				HasSelectionBefore = hasSelectionBefore,
				SelectionBefore = hasSelectionBefore ? selectionBefore : new TextRange(),
				HasSelectionAfter = selection.hasSelection,
				SelectionAfter = selection.hasSelection ? selection.range : new TextRange(),
				ImeSync = new ImeSyncSnapshot {
					Cursor = cursor,
					HasSelection = selection.hasSelection,
					Selection = selection.hasSelection ? selection.range : new TextRange()
				}
			};
		}

		private bool TryGetPreferredDoubleTapSelection(TextPosition cursor, out TextRange range) {
			if (platformBehavior.IsMobile &&
			    TryBuildLocalWordSelection(cursor, out range)) {
				return true;
			}

			TextRange coreRange = editorCore.GetWordRangeAtCursor();
			if (IsReasonableDoubleTapSelection(coreRange, cursor)) {
				range = coreRange;
				return true;
			}

			return TryBuildLocalWordSelection(cursor, out range);
		}

		private bool TryApplyValidatedSelection(TextRange requestedRange, out TextRange appliedRange) {
			appliedRange = new TextRange();
			TextRange normalized = requestedRange.Normalized();
			if (normalized.Start.Line == normalized.End.Line && normalized.Start.Column < normalized.End.Column) {
				return TryApplySelectionByCursorMovement(normalized, out appliedRange);
			}

			editorCore.SetSelection(normalized.Start.Line, normalized.Start.Column, normalized.End.Line, normalized.End.Column);
			var selection = editorCore.GetSelection();
			if (TryGetMatchingSelectionRange(selection, normalized, out appliedRange)) {
				return true;
			}

			if (TryApplySelectionByCursorMovement(normalized, out appliedRange)) {
				return true;
			}

			return false;
		}

		private bool TryApplySelectionByCursorMovement(TextRange requestedRange, out TextRange appliedRange) {
			appliedRange = new TextRange();
			TextRange normalized = requestedRange.Normalized();
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

		private bool TryGetMatchingSelectionRange((bool hasSelection, TextRange range)selection, TextRange requestedRange, out TextRange matchingRange) {
			matchingRange = new TextRange();
			if (!selection.hasSelection) {
				return false;
			}

			TextRange actual = selection.range.Normalized();
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
			range = new TextRange();
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

		private void FireTextChanged(EditorActionResult? editResult = null) {
			DismissInlineSuggestionInternal(emitDismissedCallback: true);
			ClearAuthorizedDestructiveSelection();
			selectionMenuController.OnTextChanged();
			if (editResult?.Changes != null && editResult.Changes.Count > 0) {
				TextChanged?.Invoke(this, new TextChangedEventArgs(editResult.TextChangeKind, editResult.Source, editResult.Changes));
				decorationProviderManager.OnTextChanged(editResult.Changes);
			}

			HandleCompletionAfterEdit(editResult);
		}

		private void HandleCompletionAfterEdit(EditorActionResult? editResult) {
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

			DispatchEditorActionResult(editorCore.SetCursorPosition(new TextPosition { Line = accepted.Line, Column = accepted.Column }));
			var result = editorCore.InsertText(accepted.Text);
			DispatchEditorActionResult(result);
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
			return selectionMenuController.IsShowing;
		}

		private bool ShouldUpdateInlineSuggestionPopupPosition() {
			return inlineSuggestionPopup?.IsOpen == true &&
			       inlineSuggestion != null;
		}

		private void UpdateInlineSuggestionActionBarPosition() {
			if (!ShouldUpdateInlineSuggestionPopupPosition() || disposed) {
				return;
			}

			InlineSuggestion suggestion = inlineSuggestion!;
			Popup popup = inlineSuggestionPopup!;
			var anchor = editorCore.GetPositionRect(suggestion.Line, suggestion.Column);
			AvaloniaRect viewport = GetPopupViewportRect();
			AvaloniaSize popupSize = MeasurePopupChild(popup);
			double popupWidth = Math.Max(1, popupSize.Width);
			double popupHeight = Math.Max(1, popupSize.Height);
			double maxX = Math.Max(viewport.X, viewport.Right - popupWidth - popup.HorizontalOffset);
			double maxY = Math.Max(viewport.Y, viewport.Bottom - popupHeight - popup.VerticalOffset - Math.Max(1f, anchor.Height));
			double anchorX = Math.Clamp(anchor.X, viewport.X, maxX);
			double anchorY = Math.Clamp(anchor.Y, viewport.Y, maxY);
			popup.PlacementTarget = this;
			popup.PlacementRect = new AvaloniaRect(anchorX, anchorY, 1, Math.Max(1f, anchor.Height));
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
			renderModel = null;
			renderModel = editorCore.BuildRenderModel();
			if (renderModel != null && ShouldOptimizeRenderModelForDrawing(renderModel)) {
				EditorRenderModel optimizedModel = renderModel;
				OptimizeRenderModelForDrawing(ref optimizedModel);
				renderModel = optimizedModel;
			}
			lastFrameBuildMs = (float)((Stopwatch.GetTimestamp() - buildStart) * 1000.0 / Stopwatch.Frequency);
			renderModelDirty = false;
			UpdateVisibleLineRangeCache(renderModel);
			if (pendingViewportDecorationRefresh && cachedVisibleEndLine >= cachedVisibleStartLine) {
				pendingViewportDecorationRefresh = false;
				Dispatcher.UIThread.Post(() =>
				                         {
					                         if (!disposed) {
						                         decorationProviderManager.RequestRefresh();
					                         }
				                         },
				                         DispatcherPriority.Background);
			}
		}

		private static void OptimizeRenderModelForDrawing(ref EditorRenderModel model) {
			List<VisualLine>? visualLines = model.Lines;
			if (visualLines == null || visualLines.Count == 0) {
				return;
			}

			for (int i = 0; i < visualLines.Count; i++) {
				VisualLine line = visualLines[i];
				List<VisualRun>? runs = line.Runs;
				if (runs == null || runs.Count < 2) {
					continue;
				}

				if (!TryMergeRenderableRuns(runs, out List<VisualRun>? mergedRuns))
                {
					continue;
				}

				line.Runs = mergedRuns!;
				visualLines[i] = line;
			}
		}

		private bool ShouldOptimizeRenderModelForDrawing(EditorRenderModel model) {
			List<VisualLine>? visualLines = model.Lines;
			if (visualLines == null || visualLines.Count == 0) {
				return false;
			}

			if (!platformBehavior.IsMobile) {
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

			if (totalRunCount < MobileMergeMinTotalRuns) {
				return false;
			}

			if (totalRunCount < visualLines.Count * MobileMergeMinAverageRunsPerLine) {
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

			List<VisualRun> optimized = new(runs.Count);
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

		private void ScheduleViewportUpdate(AvaloniaSize size, bool force = false) {
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

			AvaloniaSize size = pendingViewportSize;
			if (size.Width <= 0 || size.Height <= 0) {
				return;
			}

			if (!forceViewportUpdate && size == appliedViewportSize) {
				return;
			}

			appliedViewportSize = size;
			forceViewportUpdate = false;
			DispatchEditorActionResult(editorCore.SetViewport((int)Math.Max(0, size.Width), (int)Math.Max(0, size.Height)));
			if (pendingCursorViewportSync) {
				TextPosition cursor = editorCore.GetCursorPosition();
				DispatchEditorActionResult(editorCore.ScrollToLine(Math.Max(0, cursor.Line), (int)ScrollBehavior.GOTO_TOP));
				pendingCursorViewportSync = false;
			}
			pendingViewportDecorationRefresh = true;
			NotifyTextInputStateChanged(textViewChanged: true);
		}

		private void UpdateVisibleLineRangeCache(EditorRenderModel? model) {
			int previousStart = cachedVisibleStartLine;
			int previousEnd = cachedVisibleEndLine;
			bool changed;

			var visualLines = model?.Lines;
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
			if (completionPopupController.IsShowing) {
				completionPopupController.UpdatePosition();
			}
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

			if (editorCore.HasPreedit()) {
				DispatchEditorActionResult(editorCore.HandleImeCommandMessage(new ImeCommandMessage {
					Kind = ImeCommandKind.CANCEL_PREEDIT
				}));
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
			DispatchEditorActionResult(editorCore.SetHandleConfig(EditorRenderer.ComputeHandleHitConfig(platformBehavior.HandleHitScale * density)));
			DispatchEditorActionResult(editorCore.OnFontMetricsChanged());
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
			if (completionPopupController.IsShowing) {
				completionPopupController.UpdatePosition();
			}
			if (ShouldUpdateInlineSuggestionPopupPosition()) {
				UpdateInlineSuggestionActionBarPosition();
			}
			NotifyTextInputStateChanged(textViewChanged: true, force: true);
			if (!scrolled && (completionPopupController.IsShowing || ShouldUpdateSelectionMenuPopupPosition() || ShouldUpdateInlineSuggestionPopupPosition())) {
				RequestVisualInvalidate();
			}
		}

		private bool EnsureCursorVisibleInAvailableViewport() {
			AvaloniaRect viewport = GetPopupViewportRect();
			if (viewport.Width <= 0 || viewport.Height <= 0) {
				return false;
			}

			CursorRect cursor = editorCore.GetCursorRect();
			ScrollMetrics scroll = editorCore.GetScrollMetrics();
			double cursorTop = cursor.Y;
			double cursorBottom = cursor.Y + Math.Max(1f, cursor.Height);
			double topPadding = Math.Min(12d, Math.Max(4d, viewport.Height * 0.08d));
			double bottomPadding = topPadding + (platformBehavior.IsMobile ? 8d : 0d);
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
			DispatchEditorActionResult(editorCore.OnFontMetricsChanged());
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
			if (platformBehavior.IsMobile) {
				long elapsed = Environment.TickCount64 - lastTextInputNotificationTickMs;
				if (elapsed < MobileScheduledTextInputNotifyMinIntervalMs) {
					delayMs = MobileScheduledTextInputNotifyMinIntervalMs - elapsed;
				}
			}

			DispatcherTimer.RunOnce(() =>
			                        {
				                        textInputNotificationScheduled = false;
				                        if (disposed) {
					                        return;
				                        }

				                        NotifyTextInputStateChanged();
			                        },
			                        TimeSpan.FromMilliseconds(delayMs), DispatcherPriority.Background);
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
				settings.SetGutterStickyCoreOnly(false);
			}

			editorCore.SetScrollbarConfig(new ScrollbarConfig {
				// Match Android scrollbar thickness while retaining the Avalonia touch hit area.
				Thickness = 5.0f,
				MinThumb = 40.0f,
				ThumbHitPadding = 16.0f,
				Mode = ScrollbarMode.TRANSIENT,
				ThumbDraggable = true,
				TrackTapMode = ScrollbarTrackTapMode.DISABLED,
				FadeDelayMs = 700,
				FadeDurationMs = 300,
			});
		}

		private AvaloniaRect GetTextInputCursorRectangle() {
			CursorRect cursor = editorCore.GetCursorRect();
			return new AvaloniaRect(cursor.X, cursor.Y, 1, Math.Max(1f, cursor.Height));
		}

		internal AvaloniaRect GetPopupViewportRect() {
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
			return new AvaloniaRect(left, top, Math.Max(0d, right - left), Math.Max(0d, bottom - top));
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

		private void CancelActiveTouchSequence(bool notifyViewportSettled) {
			if (!touchSequenceActive) {
				return;
			}

			List<PointF> points = GetActiveTouchPoints();
			if (points.Count == 0) {
				points = [ToPointF(lastPointerPosition)];
			}
			activeTouchPoints.Clear();
			touchSequenceActive = false;
			touchPendingFocus = false;
			touchPointerMoved = false;
			touchGestureHadScroll = false;

			var result = editorCore.HandleGestureEvent(new GestureEvent {
				Type = EventType.TOUCH_CANCEL,
				Points = points,
				Modifiers = (int)KeyModifier.NONE,
				DirectScale = 1,
			});
			DispatchEditorActionResult(result);
			if (notifyViewportSettled) {
				NotifyViewportGestureSettled();
			}
		}

		private static AvaloniaSize MeasurePopupChild(Popup popup) {
			if (popup.Child == null) {
				return default;
			}

			popup.Child.Measure(AvaloniaSize.Infinity);
			return popup.Child.DesiredSize;
		}

		private void ScheduleTouchMoveFlush(bool scheduleTextInputState) {
			long now = Environment.TickCount64;
			long elapsed = now - lastTouchMoveFlushTickMs;
			if (elapsed >= platformBehavior.TouchMoveFlushMinIntervalMs) {
				lastTouchMoveFlushTickMs = now;
				FlushCore(scheduleTextInputState);
				return;
			}
			if (disposed || touchMoveFlushScheduled) {
				return;
			}

			touchMoveFlushScheduled = true;
			Dispatcher.UIThread.Post(() =>
			                         {
				                         touchMoveFlushScheduled = false;
				                         if (!disposed) {
					                         lastTouchMoveFlushTickMs = Environment.TickCount64;
					                         FlushCore(scheduleTextInputState);
				                         }
			                         },
			                         DispatcherPriority.Render);
		}

		private bool ExecuteKeyMapCommand(int commandId) {
			if (keyMap.TryInvokeHostCommand(this, commandId)) {
				return true;
			}

			return EditorKeyMap.GetCommandRoute(commandId) switch {
				EditorCommandRoute.Core => ExecuteCoreKeyMapCommand((EditorBuiltinCommand)commandId),
				EditorCommandRoute.Host => ExecuteHostKeyMapCommand((EditorBuiltinCommand)commandId),
				_ => false,
			};
		}

		private bool ExecuteCoreKeyMapCommand(EditorBuiltinCommand command) {
			switch (command) {
			case EditorBuiltinCommand.INSERT_TAB:
				if (inlineSuggestion != null) {
					AcceptInlineSuggestionInternal();
					return true;
				}
				if (TryHandleConfiguredTab(KeyModifiers.None)) {
					return true;
				}
				return ExecuteCoreKeyCommand(KeyCode.TAB, KeyModifier.NONE);

			case EditorBuiltinCommand.INSERT_NEWLINE: {
				var action = newLineActionProviderManager.ProvideNewLineAction();
				if (action != null) {
					var editResult = editorCore.HandleKeyEvent((ushort)KeyCode.NONE, action.Text, 0);
					DispatchEditorActionResult(editResult);
					return true;
				}
				return ExecuteCoreKeyCommand(KeyCode.ENTER, KeyModifier.NONE);
			}

			case EditorBuiltinCommand.SELECT_ALL:
				DispatchEditorActionResult(editorCore.SelectAll());
				ScheduleSelectionMenuShow();
				return true;

			case EditorBuiltinCommand.UNDO: {
				var editResult = editorCore.Undo();
				if (editResult == null) {
					return false;
				}
				DispatchEditorActionResult(editResult);
				return true;
			}

			case EditorBuiltinCommand.REDO: {
				var editResult = editorCore.Redo();
				if (editResult == null) {
					return false;
				}
				DispatchEditorActionResult(editResult);
				return true;
			}

			case EditorBuiltinCommand.MOVE_LINE_UP:
				return ExecuteCoreEditCommand(editorCore.MoveLineUp());

			case EditorBuiltinCommand.MOVE_LINE_DOWN:
				return ExecuteCoreEditCommand(editorCore.MoveLineDown());

			case EditorBuiltinCommand.COPY_LINE_UP:
				return ExecuteCoreEditCommand(editorCore.CopyLineUp());

			case EditorBuiltinCommand.COPY_LINE_DOWN:
				return ExecuteCoreEditCommand(editorCore.CopyLineDown());

			case EditorBuiltinCommand.DELETE_LINE:
				return ExecuteCoreEditCommand(editorCore.DeleteLine());

			case EditorBuiltinCommand.INSERT_LINE_ABOVE:
				return ExecuteCoreEditCommand(editorCore.InsertLineAbove());

			case EditorBuiltinCommand.INSERT_LINE_BELOW:
				return ExecuteCoreEditCommand(editorCore.InsertLineBelow());
			}

			if (TryMapCoreEditorBuiltinCommandToKeyGesture(command, out int keyCode, out KeyModifier modifiers)) {
				return ExecuteCoreKeyCommand(keyCode, modifiers);
			}

			return false;
		}

		private bool ExecuteCoreEditCommand(EditorActionResult editResult) {
			ClearAuthorizedDestructiveSelection();
			DispatchEditorActionResult(editResult);
			return true;
		}

		private static bool TryMapCoreEditorBuiltinCommandToKeyGesture(EditorBuiltinCommand command, out int keyCode, out KeyModifier modifiers) {
			switch (command) {
			case EditorBuiltinCommand.CURSOR_LEFT:
				keyCode = KeyCode.LEFT;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_RIGHT:
				keyCode = KeyCode.RIGHT;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_UP:
				keyCode = KeyCode.UP;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_DOWN:
				keyCode = KeyCode.DOWN;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_LINE_START:
				keyCode = KeyCode.HOME;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_LINE_END:
				keyCode = KeyCode.END;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_PAGE_UP:
				keyCode = KeyCode.PAGE_UP;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.CURSOR_PAGE_DOWN:
				keyCode = KeyCode.PAGE_DOWN;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.SELECT_LEFT:
				keyCode = KeyCode.LEFT;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_RIGHT:
				keyCode = KeyCode.RIGHT;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_UP:
				keyCode = KeyCode.UP;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_DOWN:
				keyCode = KeyCode.DOWN;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_LINE_START:
				keyCode = KeyCode.HOME;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_LINE_END:
				keyCode = KeyCode.END;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_PAGE_UP:
				keyCode = KeyCode.PAGE_UP;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.SELECT_PAGE_DOWN:
				keyCode = KeyCode.PAGE_DOWN;
				modifiers = KeyModifier.SHIFT;
				return true;
			case EditorBuiltinCommand.BACKSPACE:
				keyCode = KeyCode.BACKSPACE;
				modifiers = KeyModifier.NONE;
				return true;
			case EditorBuiltinCommand.DELETE_FORWARD:
				keyCode = KeyCode.DELETE_KEY;
				modifiers = KeyModifier.NONE;
				return true;
			default:
				keyCode = KeyCode.NONE;
				modifiers = KeyModifier.NONE;
				return false;
			}
		}

		private bool ExecuteHostKeyMapCommand(EditorBuiltinCommand command) {
			switch (command) {
			case EditorBuiltinCommand.COPY:
				CopyToClipboard();
				return true;
			case EditorBuiltinCommand.PASTE:
				PasteFromClipboard();
				return true;
			case EditorBuiltinCommand.CUT:
				CutToClipboard();
				return true;
			case EditorBuiltinCommand.TRIGGER_COMPLETION:
				TriggerCompletion();
				return true;
			default:
				return false;
			}
		}

		private bool ExecuteCoreKeyCommand(int keyCode, KeyModifier modifiers) {
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

			DispatchEditorActionResult(result);
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

		private bool TryHandleAndroidPlainDeletionKey(int keyCode, KeyModifier modifiers) {
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

			EditorActionResult result;
			try {
				result = isBackspace
				             ? editorCore.Backspace()
				             : editorCore.DeleteForward();
			} finally {
				if (restoreBackspaceUnindent) {
					editorCore.SetBackspaceUnindent(true);
				}
			}

			DispatchEditorActionResult(result);
			return true;
		}

		private void RefreshPointerModifiers(KeyModifiers modifiers) {
			DispatchEditorActionResult(editorCore.UpdatePointerModifiers(ToModifierMask(modifiers)));
		}

		private static PointF ToPointF(Point point) => new((float)point.X, (float)point.Y);

		private static Point ToPoint(PointF point) => new(point.X, point.Y);

		private List<PointF> GetActiveTouchPoints() {
			var points = new List<PointF>(activeTouchPoints.Count);
			foreach (Point point in activeTouchPoints.Values) {
				points.Add(ToPointF(point));
			}
			return points;
		}

		private static KeyModifier ToModifiers(KeyModifiers modifiers) {
			KeyModifier result = KeyModifier.NONE;
			if ((modifiers & KeyModifiers.Shift) != 0) {
				result |= KeyModifier.SHIFT;
			}
			if ((modifiers & KeyModifiers.Control) != 0) {
				result |= KeyModifier.CTRL;
			}
			if ((modifiers & KeyModifiers.Alt) != 0) {
				result |= KeyModifier.ALT;
			}
			if ((modifiers & KeyModifiers.Meta) != 0) {
				result |= KeyModifier.META;
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

		private static bool IsDestructiveKey(int keyCode) {
			return keyCode is KeyCode.BACKSPACE or KeyCode.DELETE_KEY;
		}

		private static bool IsSelectionGestureKey(ushort keyCode, KeyModifiers modifiers) {
			if ((modifiers & KeyModifiers.Shift) == 0) {
				return false;
			}

			return keyCode is 33 or 34 or 35 or 36 or 37 or 38 or 39 or 40;
		}

		private static bool IsSelectionGestureKey(int keyCode, KeyModifier modifiers) {
			if ((modifiers & KeyModifier.SHIFT) == 0) {
				return false;
			}

			return keyCode is KeyCode.PAGE_UP or KeyCode.PAGE_DOWN or KeyCode.HOME or KeyCode.END or KeyCode.LEFT or KeyCode.UP or KeyCode.RIGHT or KeyCode.DOWN;
		}

		public LayoutMetrics GetLayoutMetrics() => editorCore.GetLayoutMetrics();

		private int GetIndentUnit() => languageConfiguration?.TabSize is int tabSize && tabSize > 0 ? tabSize : 4;

		private EditorActionResult InsertConfiguredText(string text) {
			if (string.IsNullOrEmpty(text)) {
				return EditorActionResult.Empty;
			}

			if (TryInsertAutoClosingPair(text, out EditorActionResult? autoClosingResult)) {
				return autoClosingResult ?? EditorActionResult.Empty;
			}

			return editorCore.InsertText(text);
		}

		private bool ShouldCommitTextInputThroughIme() {
			return editorCore.IsCompositionEnabled() &&
			       (platformBehavior.Kind == EditorPlatformKind.Android || editorCore.HasPreedit());
		}

		private EditorActionResult CommitImeText(string text) {
			return editorCore.HandleImeCommandMessage(new ImeCommandMessage {
				Kind = ImeCommandKind.COMMIT_TEXT,
				Text = text,
			});
		}

		private bool TryInsertAutoClosingPair(string text, out EditorActionResult? result) {
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
			DispatchEditorActionResult(editorCore.InsertText(pair.Open + pair.Close));
			result = editorCore.SetCursorPosition(new TextPosition { Line = cursor.Line, Column = cursor.Column + pair.Open.Length });
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
			var result = editorCore.HandleKeyEvent((ushort)KeyCode.NONE, new string(' ', spacesToInsert), 0);
			DispatchEditorActionResult(result);
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
			DispatchEditorActionResult(result);
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
			if (disposed) {
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
				if (editorCore.HasPreedit()) {
					DispatchEditorActionResult(editorCore.HandleImeCommandMessage(new ImeCommandMessage {
						Kind = ImeCommandKind.CANCEL_PREEDIT
					}));
				}
				return;
			}

			ImeCommandMessage message = new ImeCommandMessage {
				Kind = ImeCommandKind.SET_PREEDIT_TEXT,
				Text = text
			};
			if (cursorPos.HasValue) {
				int safeCursor = Math.Clamp(cursorPos.Value, 0, text.Length);
				message.Selection = new ImeOffsetRange { Start = safeCursor, End = safeCursor };
			}
			DispatchEditorActionResult(editorCore.HandleImeCommandMessage(message));
		}

		private void ExecuteTextInputContextMenuAction(ContextMenuAction action) {
			switch (action) {
				case ContextMenuAction.Copy:
					CopyToClipboard();
					break;
				case ContextMenuAction.Cut:
					CutToClipboard();
					break;
				case ContextMenuAction.Paste:
					PasteFromClipboard();
					break;
				case ContextMenuAction.SelectAll:
					SelectAll();
					break;
			}
		}

		private readonly struct InputPerfScope : IDisposable {
			private readonly SweetEditorControl? owner;
			private readonly string tag;
			private readonly long startTick;

			public InputPerfScope(SweetEditorControl owner, string tag, long startTick) {
				this.owner = owner;
				this.tag = tag;
				this.startTick = startTick;
			}

			public void Dispose() {
				owner?.EndInputPerf(tag, startTick);
			}
		}

		private sealed class EditorTextInputClient : TextInputMethodClient {
			private readonly SweetEditorControl owner;

			public EditorTextInputClient(SweetEditorControl owner) {
				this.owner = owner;
			}

			public override global::Avalonia.Visual TextViewVisual => owner;

			public override bool SupportsPreedit => owner.editorCore.IsCompositionEnabled();

			public override bool SupportsSurroundingText => owner.editorCore.IsCompositionEnabled();

			public override string SurroundingText => owner.SafeGetTextInputSurroundingText();

			public override AvaloniaRect CursorRectangle => owner.GetTextInputCursorRectangle();

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

			public override void ExecuteContextMenuAction(ContextMenuAction action) {
				owner.ExecuteTextInputContextMenuAction(action);
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
