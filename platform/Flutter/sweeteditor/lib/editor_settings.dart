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
  void applyBackspaceUnindent(bool enabled);
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
  core.AutoIndentMode _autoIndentMode = core.AutoIndentMode.keepIndent;
  bool _backspaceUnindent = true;
  bool _readOnly = false;
  int _maxGutterIcons = 0;
  int _decorationScrollRefreshMinIntervalMs = 16;
  double _decorationOverscanViewportMultiplier = 1.5;
  bool _textSizeCustomized = false;
  bool _fontFamilyCustomized = false;
  bool _gutterStickyCustomized = false;
  EditorSettingsHost? _host;

  EditorSettings copy() {
    final copy = EditorSettings();
    copy._textSize = _textSize;
    copy._fontFamily = _fontFamily;
    copy._scale = _scale;
    copy._foldArrowMode = _foldArrowMode;
    copy._wrapMode = _wrapMode;
    copy._lineSpacingAdd = _lineSpacingAdd;
    copy._lineSpacingMult = _lineSpacingMult;
    copy._contentStartPadding = _contentStartPadding;
    copy._showSplitLine = _showSplitLine;
    copy._gutterSticky = _gutterSticky;
    copy._gutterVisible = _gutterVisible;
    copy._currentLineRenderMode = _currentLineRenderMode;
    copy._autoIndentMode = _autoIndentMode;
    copy._backspaceUnindent = _backspaceUnindent;
    copy._readOnly = _readOnly;
    copy._maxGutterIcons = _maxGutterIcons;
    copy._decorationScrollRefreshMinIntervalMs =
        _decorationScrollRefreshMinIntervalMs;
    copy._decorationOverscanViewportMultiplier =
        _decorationOverscanViewportMultiplier;
    copy._textSizeCustomized = _textSizeCustomized;
    copy._fontFamilyCustomized = _fontFamilyCustomized;
    copy._gutterStickyCustomized = _gutterStickyCustomized;
    return copy;
  }

  void replaceFrom(EditorSettings other) {
    _textSize = other._textSize;
    _fontFamily = other._fontFamily;
    _scale = other._scale;
    _foldArrowMode = other._foldArrowMode;
    _wrapMode = other._wrapMode;
    _lineSpacingAdd = other._lineSpacingAdd;
    _lineSpacingMult = other._lineSpacingMult;
    _contentStartPadding = other._contentStartPadding;
    _showSplitLine = other._showSplitLine;
    _gutterSticky = other._gutterSticky;
    _gutterVisible = other._gutterVisible;
    _currentLineRenderMode = other._currentLineRenderMode;
    _autoIndentMode = other._autoIndentMode;
    _backspaceUnindent = other._backspaceUnindent;
    _readOnly = other._readOnly;
    _maxGutterIcons = other._maxGutterIcons;
    _decorationScrollRefreshMinIntervalMs =
        other._decorationScrollRefreshMinIntervalMs;
    _decorationOverscanViewportMultiplier =
        other._decorationOverscanViewportMultiplier;
    _textSizeCustomized = other._textSizeCustomized;
    _fontFamilyCustomized = other._fontFamilyCustomized;
    _gutterStickyCustomized = other._gutterStickyCustomized;
    final host = _host;
    if (host != null) {
      _applyAll(host);
    }
  }

  void seedDefaults({
    required double textSize,
    required String fontFamily,
    bool? gutterSticky,
  }) {
    if (!_textSizeCustomized) {
      _textSize = textSize;
    }
    if (!_fontFamilyCustomized) {
      _fontFamily = fontFamily;
    }
    if (!_gutterStickyCustomized && gutterSticky != null) {
      _gutterSticky = gutterSticky;
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
    _gutterStickyCustomized = true;
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

  void setBackspaceUnindent(bool enabled) {
    _backspaceUnindent = enabled;
    _host?.applyBackspaceUnindent(enabled);
  }

  bool isBackspaceUnindent() => _backspaceUnindent;

  void setReadOnly(bool readOnly) {
    _readOnly = readOnly;
    _host?.applyReadOnly(readOnly);
  }

  bool isReadOnly() => _readOnly;

  void setMaxGutterIcons(int count) {
    _maxGutterIcons = count;
    _host?.applyMaxGutterIcons(count);
    _host?.flushEditor();
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
    host.applyBackspaceUnindent(_backspaceUnindent);
    host.applyReadOnly(_readOnly);
    host.applyMaxGutterIcons(_maxGutterIcons);
    host.requestDecorationRefresh();
    host.flushEditor();
  }
}
