part of '../sweeteditor.dart';

class EditorPlatformBehavior {
  const EditorPlatformBehavior._({
    required this.usesPlatformTextInput,
    required this.showsSoftKeyboard,
    required this.usesMouseCursor,
    required this.showsSelectionHandles,
    required this.showsFloatingSelectionMenu,
    required this.revealSelectionEndOnSelectAll,
    required this.supportsTouchScale,
    required this.supportsCtrlWheelScale,
    required this.supportsTrackpadPanZoom,
    required this.gutterStickyDefault,
    required this.handleConfig,
    required this.scrollbarConfig,
    required this.selectionMenuHandleClearance,
  });

  factory EditorPlatformBehavior.resolve() {
    final isMobileStyle =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final usesPlatformTextInput = !kIsWeb;
    return EditorPlatformBehavior._(
      usesPlatformTextInput: usesPlatformTextInput,
      showsSoftKeyboard: isMobileStyle,
      usesMouseCursor: !isMobileStyle,
      showsSelectionHandles: isMobileStyle,
      showsFloatingSelectionMenu: isMobileStyle,
      revealSelectionEndOnSelectAll: isMobileStyle,
      supportsTouchScale: isMobileStyle,
      supportsCtrlWheelScale: !isMobileStyle,
      supportsTrackpadPanZoom: !isMobileStyle,
      gutterStickyDefault: !isMobileStyle,
      handleConfig: isMobileStyle
          ? _buildMobileHandleConfig()
          : _buildDisabledHandleConfig(),
      scrollbarConfig: _buildScrollbarConfig(isMobileStyle: isMobileStyle),
      selectionMenuHandleClearance: isMobileStyle ? 32.0 : 0.0,
    );
  }

  final bool usesPlatformTextInput;
  final bool showsSoftKeyboard;
  final bool usesMouseCursor;
  final bool showsSelectionHandles;
  final bool showsFloatingSelectionMenu;
  final bool revealSelectionEndOnSelectAll;
  final bool supportsTouchScale;
  final bool supportsCtrlWheelScale;
  final bool supportsTrackpadPanZoom;
  final bool gutterStickyDefault;
  final core.HandleConfig handleConfig;
  final core.ScrollbarConfig scrollbarConfig;
  final double selectionMenuHandleClearance;

  static core.HandleConfig _buildMobileHandleConfig() {
    const r = 10.0;
    const d = 24.0;
    const angle = 45.0 * math.pi / 180.0;
    final cos = math.cos(angle);
    final sin = math.sin(angle);

    final points = <List<double>>[
      [0, 0],
      [-r, d],
      [r, d],
      [0, d + r],
      [0, d - r * 0.8],
    ];

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in points) {
      final rx = p[0] * cos - p[1] * sin;
      final ry = p[0] * sin + p[1] * cos;
      minX = math.min(minX, rx);
      minY = math.min(minY, ry);
      maxX = math.max(maxX, rx);
      maxY = math.max(maxY, ry);
    }

    const pad = 8.0;
    return core.HandleConfig(
      startLeft: minX - pad,
      startTop: minY - pad,
      startRight: maxX + pad,
      startBottom: maxY + pad,
      endLeft: -maxX - pad,
      endTop: minY - pad,
      endRight: -minX + pad,
      endBottom: maxY + pad,
    );
  }

  static core.HandleConfig _buildDisabledHandleConfig() {
    return const core.HandleConfig(
      startLeft: 1,
      startTop: 1,
      startRight: -1,
      startBottom: -1,
      endLeft: 1,
      endTop: 1,
      endRight: -1,
      endBottom: -1,
    );
  }

  static core.ScrollbarConfig _buildScrollbarConfig({
    required bool isMobileStyle,
  }) {
    return core.ScrollbarConfig(
      thickness: isMobileStyle ? 8.0 : 6.0,
      minThumb: isMobileStyle ? 40.0 : 32.0,
      thumbHitPadding: isMobileStyle ? 20.0 : 0.0,
      mode: core.ScrollbarMode.transient,
      thumbDraggable: true,
      trackTapMode: core.ScrollbarTrackTapMode.disabled,
      fadeDelayMs: 700,
      fadeDurationMs: 300,
    );
  }
}
