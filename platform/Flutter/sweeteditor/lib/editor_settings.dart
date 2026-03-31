import 'editor_core.dart' as core;

abstract class EditorSettingsHost {
  void applyTypography({
    required double textSize,
    required String fontFamily,
    required double scale,
  });

  void applyFoldArrowMode(core.FoldArrowMode mode);
  void applyWrapMode(core.WrapMode mode);
  void applyLineSpacing(double add, double mult);
  void applyContentStartPadding(double padding);
  void applyShowSplitLine(bool show);
  void applyGutterSticky(bool sticky);
  void applyGutterVisible(bool visible);
  void applyCurrentLineRenderMode(core.CurrentLineRenderMode mode);
  void applyAutoIndentMode(core.AutoIndentMode mode);
  void applyReadOnly(bool readOnly);
  void applyMaxGutterIcons(int count);
  void requestDecorationRefresh();
  void flushEditor();
}

/// Settings wrapper for the editor.
class EditorSettings {
  EditorSettings();

  double _textSize = 14;
  String _fontFamily = 'monospace';
  double _scale = 1.0;
  core.FoldArrowMode _foldArrowMode = core.FoldArrowMode.always;
  core.WrapMode _wrapMode = core.WrapMode.none;
  double _lineSpacingAdd = 0;
  double _lineSpacingMult = 1.0;
  double _contentStartPadding = 0;
  bool _showSplitLine = true;
  bool _gutterSticky = true;
  bool _gutterVisible = true;
  core.CurrentLineRenderMode _currentLineRenderMode =
      core.CurrentLineRenderMode.background;
  core.AutoIndentMode _autoIndentMode = core.AutoIndentMode.none;
  bool _readOnly = false;
  int _maxGutterIcons = 0;
  int _decorationScrollRefreshMinIntervalMs = 16;
  double _decorationOverscanViewportMultiplier = 1.5;
  bool _textSizeCustomized = false;
  bool _fontFamilyCustomized = false;
  EditorSettingsHost? _host;

  void seedDefaults({required double textSize, required String fontFamily}) {
    if (!_textSizeCustomized) {
      _textSize = textSize;
    }
    if (!_fontFamilyCustomized) {
      _fontFamily = fontFamily;
    }
  }

  void bind(EditorSettingsHost host) {
    _host = host;
    _applyAll(host);
  }

  void unbind(EditorSettingsHost host) {
    if (identical(_host, host)) {
      _host = null;
    }
  }

  void setEditorTextSize(double size) {
    _textSize = size;
    _textSizeCustomized = true;
    _host?.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
    _host?.flushEditor();
  }

  double getEditorTextSize() => _textSize;

  void setFontFamily(String fontFamily) {
    _fontFamily = fontFamily;
    _fontFamilyCustomized = true;
    _host?.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
    _host?.flushEditor();
  }

  String getFontFamily() => _fontFamily;

  void setScale(double scale) {
    _scale = scale;
    _host?.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
    _host?.flushEditor();
  }

  double getScale() => _scale;

  void setFoldArrowMode(core.FoldArrowMode mode) {
    _foldArrowMode = mode;
    _host?.applyFoldArrowMode(mode);
    _host?.flushEditor();
  }

  core.FoldArrowMode getFoldArrowMode() => _foldArrowMode;

  void setWrapMode(core.WrapMode mode) {
    _wrapMode = mode;
    _host?.applyWrapMode(mode);
    _host?.flushEditor();
  }

  core.WrapMode getWrapMode() => _wrapMode;

  void setLineSpacing(double add, double mult) {
    _lineSpacingAdd = add;
    _lineSpacingMult = mult;
    _host?.applyLineSpacing(add, mult);
    _host?.flushEditor();
  }

  double getLineSpacingAdd() => _lineSpacingAdd;
  double getLineSpacingMult() => _lineSpacingMult;

  void setContentStartPadding(double padding) {
    _contentStartPadding = padding.clamp(0, double.infinity);
    _host?.applyContentStartPadding(_contentStartPadding);
    _host?.flushEditor();
  }

  double getContentStartPadding() => _contentStartPadding;

  void setShowSplitLine(bool show) {
    _showSplitLine = show;
    _host?.applyShowSplitLine(show);
    _host?.flushEditor();
  }

  bool isShowSplitLine() => _showSplitLine;

  void setGutterSticky(bool sticky) {
    _gutterSticky = sticky;
    _host?.applyGutterSticky(sticky);
    _host?.flushEditor();
  }

  bool isGutterSticky() => _gutterSticky;

  void setGutterVisible(bool visible) {
    _gutterVisible = visible;
    _host?.applyGutterVisible(visible);
    _host?.flushEditor();
  }

  bool isGutterVisible() => _gutterVisible;

  void setCurrentLineRenderMode(core.CurrentLineRenderMode mode) {
    _currentLineRenderMode = mode;
    _host?.applyCurrentLineRenderMode(mode);
    _host?.flushEditor();
  }

  core.CurrentLineRenderMode getCurrentLineRenderMode() =>
      _currentLineRenderMode;

  void setAutoIndentMode(core.AutoIndentMode mode) {
    _autoIndentMode = mode;
    _host?.applyAutoIndentMode(mode);
  }

  core.AutoIndentMode getAutoIndentMode() => _autoIndentMode;

  void setReadOnly(bool readOnly) {
    _readOnly = readOnly;
    _host?.applyReadOnly(readOnly);
  }

  bool isReadOnly() => _readOnly;

  void setMaxGutterIcons(int count) {
    _maxGutterIcons = count;
    _host?.applyMaxGutterIcons(count);
  }

  int getMaxGutterIcons() => _maxGutterIcons;

  void setDecorationScrollRefreshMinIntervalMs(int intervalMs) {
    _decorationScrollRefreshMinIntervalMs = intervalMs.clamp(0, 1 << 30);
    _host?.requestDecorationRefresh();
  }

  int getDecorationScrollRefreshMinIntervalMs() =>
      _decorationScrollRefreshMinIntervalMs;

  void setDecorationOverscanViewportMultiplier(double multiplier) {
    _decorationOverscanViewportMultiplier = multiplier.clamp(
      0,
      double.infinity,
    );
    _host?.requestDecorationRefresh();
  }

  double getDecorationOverscanViewportMultiplier() =>
      _decorationOverscanViewportMultiplier;

  void _applyAll(EditorSettingsHost host) {
    host.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
    host.applyFoldArrowMode(_foldArrowMode);
    host.applyWrapMode(_wrapMode);
    host.applyLineSpacing(_lineSpacingAdd, _lineSpacingMult);
    host.applyContentStartPadding(_contentStartPadding);
    host.applyShowSplitLine(_showSplitLine);
    host.applyGutterSticky(_gutterSticky);
    host.applyGutterVisible(_gutterVisible);
    host.applyCurrentLineRenderMode(_currentLineRenderMode);
    host.applyAutoIndentMode(_autoIndentMode);
    host.applyReadOnly(_readOnly);
    host.applyMaxGutterIcons(_maxGutterIcons);
    host.requestDecorationRefresh();
    host.flushEditor();
  }
}
