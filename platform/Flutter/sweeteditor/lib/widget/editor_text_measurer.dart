import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';

import '../editor_core.dart' as core;
import '../sweeteditor_bindings_generated.dart' as bindings;

/// TextPainter-based text measurement for the native editor engine.
class EditorTextMeasurer {
  EditorTextMeasurer({required String fontFamily, required double fontSize})
    : _fontFamily = fontFamily,
      _fontSize = fontSize {
    _buildCallbackPointers();
    _nativeMeasurerPtr = calloc<bindings.text_measurer_t>();
    _nativeMeasurerPtr.ref.measure_text_width =
        _measureTextWidthCallable.nativeFunction;
    _nativeMeasurerPtr.ref.measure_inlay_hint_width =
        _measureInlayHintWidthCallable.nativeFunction;
    _nativeMeasurerPtr.ref.measure_icon_width =
        _measureIconWidthCallable.nativeFunction;
    _nativeMeasurerPtr.ref.get_font_metrics =
        _getFontMetricsCallable.nativeFunction;
  }

  String _fontFamily;
  double _fontSize;
  final Map<int, TextStyle> _flutterStyleCache = {};
  final Map<int, ({double lineHeight, double ascent, double descent})>
  _fontMetricsCache = {};
  ({double lineHeight, double ascent, double descent})? _inlayHintFontMetrics;
  late final ffi.Pointer<bindings.text_measurer_t> _nativeMeasurerPtr;

  late final ffi.NativeCallable<
    ffi.Float Function(ffi.Pointer<ffi.Uint16>, ffi.Int32)
  >
  _measureTextWidthCallable;
  late final ffi.NativeCallable<ffi.Float Function(ffi.Pointer<ffi.Uint16>)>
  _measureInlayHintWidthCallable;
  late final ffi.NativeCallable<ffi.Float Function(ffi.Int32)>
  _measureIconWidthCallable;
  late final ffi.NativeCallable<
    ffi.Void Function(ffi.Pointer<ffi.Float>, ffi.Size)
  >
  _getFontMetricsCallable;

  void _buildCallbackPointers() {
    _measureTextWidthCallable = ffi.NativeCallable<
      ffi.Float Function(ffi.Pointer<ffi.Uint16>, ffi.Int32)
    >.isolateLocal(_nativeMeasureTextWidth, exceptionalReturn: 0.0);
    _measureInlayHintWidthCallable = ffi.NativeCallable<
      ffi.Float Function(ffi.Pointer<ffi.Uint16>)
    >.isolateLocal(_nativeMeasureInlayHintWidth, exceptionalReturn: 0.0);
    _measureIconWidthCallable =
        ffi.NativeCallable<ffi.Float Function(ffi.Int32)>.isolateLocal(
          _nativeMeasureIconWidth,
          exceptionalReturn: 0.0,
        );
    _getFontMetricsCallable = ffi.NativeCallable<
      ffi.Void Function(ffi.Pointer<ffi.Float>, ffi.Size)
    >.isolateLocal(_nativeGetFontMetrics);
  }

  /// Build the native text_measurer_t struct for EditorCore.
  bindings.text_measurer_t buildNativeMeasurer() {
    return _nativeMeasurerPtr.ref;
  }

  void updateFont(String fontFamily, double fontSize) {
    _fontFamily = fontFamily;
    _fontSize = fontSize;
    _flutterStyleCache.clear();
    _fontMetricsCache.clear();
    _inlayHintFontMetrics = null;
  }

  String get fontFamily => _fontFamily;
  double get fontSize => _fontSize;

  void dispose() {
    _measureTextWidthCallable.close();
    _measureInlayHintWidthCallable.close();
    _measureIconWidthCallable.close();
    _getFontMetricsCallable.close();
    calloc.free(_nativeMeasurerPtr);
  }

  /// Measure text width for a given font style bitmask (0=normal, 1=bold, 2=italic, 3=bold+italic).
  double measureText(String text, int fontStyle) {
    if (text.isEmpty) return 0;
    final style = _getFlutterStyleForFontStyle(fontStyle);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  double measureInlayHintText(String text) {
    if (text.isEmpty) return 0;
    final style = TextStyle(
      fontFamily: 'sans-serif',
      fontSize: _fontSize * 0.9,
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  double measureIcon(int iconId) => 16.0;

  /// Get font metrics: (lineHeight, ascent, descent).
  ({double lineHeight, double ascent, double descent}) getFontMetrics([
    int fontStyle = 0,
  ]) {
    return _fontMetricsCache.putIfAbsent(fontStyle, () {
      return _measureFontMetrics(_getFlutterStyleForFontStyle(fontStyle));
    });
  }

  ({double ascent, double descent}) getNativeFontMetrics([int fontStyle = 0]) {
    final metrics = getFontMetrics(fontStyle);
    return (ascent: -metrics.ascent, descent: metrics.descent);
  }

  ({double lineHeight, double ascent, double descent})
  getInlayHintFontMetrics() {
    return _inlayHintFontMetrics ??= _measureFontMetrics(buildInlayHintStyle());
  }

  ({double lineHeight, double ascent, double descent}) _measureFontMetrics(
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: 'Mg', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    return (
      lineHeight: painter.height,
      ascent: baseline,
      descent: (painter.height - baseline).clamp(0.0, double.infinity),
    );
  }

  TextStyle _getFlutterStyleForFontStyle(int fontStyle) {
    return _flutterStyleCache.putIfAbsent(fontStyle, () {
      return TextStyle(
        fontFamily: _fontFamily,
        fontSize: _fontSize,
        fontWeight: (fontStyle & 1) != 0 ? FontWeight.bold : FontWeight.normal,
        fontStyle: (fontStyle & 2) != 0 ? FontStyle.italic : FontStyle.normal,
        height: 1.0,
      );
    });
  }

  TextStyle buildRunStyle(core.TextStyle runStyle, int defaultTextColor) {
    final color = runStyle.color != 0
        ? Color(runStyle.color)
        : Color(defaultTextColor);
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      color: color,
      fontWeight: (runStyle.fontStyle & 1) != 0
          ? FontWeight.bold
          : FontWeight.normal,
      fontStyle: (runStyle.fontStyle & 2) != 0
          ? FontStyle.italic
          : FontStyle.normal,
      height: 1.0,
    );
  }

  TextStyle buildPhantomTextStyle(int phantomColor) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: _fontSize,
      color: Color(phantomColor),
      fontStyle: FontStyle.italic,
      height: 1.0,
    );
  }

  TextStyle buildInlayHintStyle() {
    return TextStyle(
      fontFamily: 'sans-serif',
      fontSize: _fontSize * 0.9,
      height: 1.0,
    );
  }

  double _nativeMeasureTextWidth(ffi.Pointer<ffi.Uint16> text, int fontStyle) {
    if (text == ffi.nullptr) return 0;
    var length = 0;
    while ((text + length).value != 0) {
      length++;
    }
    if (length == 0) return 0;
    final dartString = String.fromCharCodes(text.asTypedList(length));
    return measureText(dartString, fontStyle);
  }

  double _nativeMeasureInlayHintWidth(ffi.Pointer<ffi.Uint16> text) {
    if (text == ffi.nullptr) return 0;
    var length = 0;
    while ((text + length).value != 0) {
      length++;
    }
    if (length == 0) return 0;
    final dartString = String.fromCharCodes(text.asTypedList(length));
    return measureInlayHintText(dartString);
  }

  double _nativeMeasureIconWidth(int iconId) {
    return measureIcon(iconId);
  }

  void _nativeGetFontMetrics(ffi.Pointer<ffi.Float> arr, int length) {
    final metrics = getNativeFontMetrics();
    if (length >= 1) (arr + 0).value = metrics.ascent;
    if (length >= 2) (arr + 1).value = metrics.descent;
  }
}
