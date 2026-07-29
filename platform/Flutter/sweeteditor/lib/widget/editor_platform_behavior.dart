part of '../sweeteditor.dart';

class EditorPlatformBehavior {
  const EditorPlatformBehavior._({
    required this.usesPlatformTextInput,
    required this.showsSoftKeyboard,
    required this.usesMouseCursor,
    required this.showsSelectionHandles,
    required this.showsFloatingSelectionMenu,
    required this.revealSelectionEndOnSelectAll,
    required this.usesDeltaTextInputModel,
    required this.usesTextInputNewlineAction,
    required this.supportsTouchScale,
    required this.supportsCtrlWheelScale,
    required this.supportsTrackpadPanZoom,
    required this.gutterStickyDefault,
    required this.handleConfig,
    required this.scrollbarConfig,
    required this.selectionMenuHandleClearance,
    required this.monospaceFontFamily,
  });

  factory EditorPlatformBehavior.resolve() {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final isMacOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
    final supportsFlutterIme = isAndroid || isIOS || isMacOS || isWindows;
    final isMobileStyle = !kIsWeb && (isAndroid || isIOS);
    final monospaceFontFamily = _resolveMonospaceFontFamily();
    return EditorPlatformBehavior._(
      usesPlatformTextInput: supportsFlutterIme,
      showsSoftKeyboard: isMobileStyle,
      usesMouseCursor: !isMobileStyle,
      showsSelectionHandles: isMobileStyle,
      showsFloatingSelectionMenu: isMobileStyle,
      revealSelectionEndOnSelectAll: isMobileStyle,
      usesDeltaTextInputModel: supportsFlutterIme && !isAndroid,
      usesTextInputNewlineAction: !isWindows,
      supportsTouchScale: isMobileStyle,
      supportsCtrlWheelScale: !isMobileStyle,
      supportsTrackpadPanZoom: !isMobileStyle,
      gutterStickyDefault: !isMobileStyle,
      handleConfig: isMobileStyle
          ? _buildMobileHandleConfig()
          : _buildDisabledHandleConfig(),
      scrollbarConfig: _buildScrollbarConfig(isMobileStyle: isMobileStyle),
      selectionMenuHandleClearance: isMobileStyle ? 32.0 : 0.0,
      monospaceFontFamily: monospaceFontFamily,
    );
  }

  final bool usesPlatformTextInput;
  final bool showsSoftKeyboard;
  final bool usesMouseCursor;
  final bool showsSelectionHandles;
  final bool showsFloatingSelectionMenu;
  final bool revealSelectionEndOnSelectAll;
  final bool usesDeltaTextInputModel;
  final bool usesTextInputNewlineAction;
  final bool supportsTouchScale;
  final bool supportsCtrlWheelScale;
  final bool supportsTrackpadPanZoom;
  final bool gutterStickyDefault;
  final core.HandleConfig handleConfig;
  final core.ScrollbarConfig scrollbarConfig;
  final double selectionMenuHandleClearance;
  final String monospaceFontFamily;

  String resolveFontFamily(String fontFamily) {
    final family = fontFamily.trim();
    if (family.isEmpty || family.toLowerCase() == 'monospace') {
      return monospaceFontFamily;
    }
    return family;
  }

  static String _resolveMonospaceFontFamily() {
    if (kIsWeb) return 'monospace';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Consolas';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'Menlo';
      default:
        return 'monospace';
    }
  }

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
      startHitArea: core.HandleHitArea(
        left: minX - pad,
        top: minY - pad,
        right: maxX + pad,
        bottom: maxY + pad,
      ),
      endHitArea: core.HandleHitArea(
        left: -maxX - pad,
        top: minY - pad,
        right: -minX + pad,
        bottom: maxY + pad,
      ),
    );
  }

  static core.HandleConfig _buildDisabledHandleConfig() {
    return const core.HandleConfig(
      startHitArea: core.HandleHitArea(left: 1, top: 1, right: -1, bottom: -1),
      endHitArea: core.HandleHitArea(left: 1, top: 1, right: -1, bottom: -1),
    );
  }

  static core.ScrollbarConfig _buildScrollbarConfig({
    required bool isMobileStyle,
  }) {
    return core.ScrollbarConfig(
      thickness: isMobileStyle ? 5.0 : 12.0,
      minThumb: isMobileStyle ? 40.0 : 32.0,
      thumbHitPadding: isMobileStyle ? 20.0 : 0.0,
      mode: isMobileStyle
          ? core.ScrollbarMode.transient
          : core.ScrollbarMode.always,
      thumbDraggable: true,
      trackTapMode: core.ScrollbarTrackTapMode.disabled,
      fadeDelayMs: 700,
      fadeDurationMs: 300,
    );
  }
}
