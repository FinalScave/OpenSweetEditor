namespace SweetEditor {
	internal enum EditorPlatformKind {
		Desktop,
		Android,
		IOS,
	}

	internal readonly record struct EditorPlatformBehavior(
		EditorPlatformKind Kind,
		bool TouchFirst,
		bool SuppressImeOnTouchDown,
		bool UseSelectionMenuByDefault,
		bool UseContextMenuByDefault,
		bool EnableDirectPinch,
		bool EnableTouchPadMagnify,
		bool UseLongPressForContextMenu,
		float HandleHitScale,
		float DefaultTouchSlop,
		int DefaultDoubleTapTimeout,
		float TouchFocusThreshold,
		float TouchImeTapMaxMovementDip,
		int TouchImeTapMaxDurationMs,
		int TouchMoveFlushMinIntervalMs
	) {
		public bool IsMobile => Kind is EditorPlatformKind.Android or EditorPlatformKind.IOS;

		public static EditorPlatformBehavior DetectCurrent() {
			if (OperatingSystem.IsAndroid()) {
				return Android();
			}
			if (OperatingSystem.IsIOS()) {
				return IOS();
			}

			return Desktop();
		}

		public static EditorPlatformBehavior Desktop() {
			return new EditorPlatformBehavior(
				Kind: EditorPlatformKind.Desktop,
				TouchFirst: false,
				SuppressImeOnTouchDown: false,
				UseSelectionMenuByDefault: false,
				UseContextMenuByDefault: true,
				EnableDirectPinch: true,
				EnableTouchPadMagnify: true,
				UseLongPressForContextMenu: false,
				HandleHitScale: 1.0f,
				DefaultTouchSlop: 8.0f,
				DefaultDoubleTapTimeout: 380,
				TouchFocusThreshold: 5.5f,
				TouchImeTapMaxMovementDip: 2.5f,
				TouchImeTapMaxDurationMs: 260,
				TouchMoveFlushMinIntervalMs: 10
			);
		}

		public static EditorPlatformBehavior Android() {
			return Mobile(EditorPlatformKind.Android);
		}

		public static EditorPlatformBehavior IOS() {
			return Mobile(EditorPlatformKind.IOS);
		}

		private static EditorPlatformBehavior Mobile(EditorPlatformKind kind) {
			return new EditorPlatformBehavior(
				Kind: kind,
				TouchFirst: true,
				SuppressImeOnTouchDown: true,
				UseSelectionMenuByDefault: true,
				UseContextMenuByDefault: false,
				EnableDirectPinch: false,
				EnableTouchPadMagnify: false,
				UseLongPressForContextMenu: true,
				HandleHitScale: 1.35f,
				DefaultTouchSlop: 4.5f,
				DefaultDoubleTapTimeout: 320,
				TouchFocusThreshold: 5.5f,
				TouchImeTapMaxMovementDip: 2.5f,
				TouchImeTapMaxDurationMs: 260,
				TouchMoveFlushMinIntervalMs: 0
			);
		}
	}
}
