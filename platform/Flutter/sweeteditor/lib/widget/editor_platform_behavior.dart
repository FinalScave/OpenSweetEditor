part of '../sweeteditor.dart';

class EditorPlatformBehavior {
  const EditorPlatformBehavior._({
    required this.isMobileStyle,
    required this.usesPlatformTextInput,
    required this.usesDeltaTextInputModel,
    required this.textInputAction,
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
    return EditorPlatformBehavior._(
      isMobileStyle: isMobileStyle,
      usesPlatformTextInput: supportsFlutterIme,
      usesDeltaTextInputModel: supportsFlutterIme && !isAndroid,
      textInputAction: isWindows
          ? TextInputAction.none
          : TextInputAction.newline,
    );
  }

  final bool isMobileStyle;
  final bool usesPlatformTextInput;
  final bool usesDeltaTextInputModel;
  final TextInputAction textInputAction;

  String resolveFontFamily(String fontFamily) {
    final family = fontFamily.trim();
    if (family.isEmpty || family.toLowerCase() == 'monospace') {
      return _resolveMonospaceFontFamily();
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
}
