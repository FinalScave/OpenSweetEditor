part of 'sweeteditor.dart';

/// Settings wrapper for the editor.
class EditorSettings {
  EditorSettings();

  double _textSize = 14;
  String _fontFamily = 'monospace';
  double _scale = 1.0;
  core.FoldArrowMode _foldArrowMode = core.FoldArrowMode.always;
  core.WrapMode _wrapMode = core.WrapMode.none;
  core.WhitespaceRenderMode _renderWhitespace = core.WhitespaceRenderMode.none;
  bool _renderLineBreaks = false;
  double _lineSpacingAdd = 0;
  double _lineSpacingMult = 1.2;
  double _contentStartPadding = 3.0;
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
  EditorSession? _session;

  EditorSettings copy() {
    final copy = EditorSettings();
    copy._textSize = _textSize;
    copy._fontFamily = _fontFamily;
    copy._scale = _scale;
    copy._foldArrowMode = _foldArrowMode;
    copy._wrapMode = _wrapMode;
    copy._renderWhitespace = _renderWhitespace;
    copy._renderLineBreaks = _renderLineBreaks;
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
    _renderWhitespace = other._renderWhitespace;
    _renderLineBreaks = other._renderLineBreaks;
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
    final session = _session;
    if (session != null) {
      _applyAll(session);
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

  void bind(EditorSession session) {
    _session = session;
  }

  void unbind(EditorSession session) {
    if (identical(_session, session)) {
      _session = null;
    }
  }

  void setEditorTextSize(double size) {
    _textSize = size;
    _textSizeCustomized = true;
    _session?.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
  }

  double getEditorTextSize() => _textSize;

  void setFontFamily(String fontFamily) {
    _fontFamily = fontFamily;
    _fontFamilyCustomized = true;
    _session?.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
  }

  String getFontFamily() => _fontFamily;

  void setScale(double scale) {
    _scale = scale;
    _session?.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
  }

  double getScale() => _scale;

  void setFoldArrowMode(core.FoldArrowMode mode) {
    _foldArrowMode = mode;
    _session?.applyFoldArrowMode(mode);
  }

  core.FoldArrowMode getFoldArrowMode() => _foldArrowMode;

  void setWrapMode(core.WrapMode mode) {
    _wrapMode = mode;
    _session?.applyWrapMode(mode);
  }

  core.WrapMode getWrapMode() => _wrapMode;

  void setRenderWhitespace(core.WhitespaceRenderMode mode) {
    _renderWhitespace = mode;
    _session?.applyRenderWhitespace(mode);
  }

  core.WhitespaceRenderMode getRenderWhitespace() => _renderWhitespace;

  void setRenderLineBreaks(bool enabled) {
    _renderLineBreaks = enabled;
    _session?.applyRenderLineBreaks(enabled);
  }

  bool isRenderLineBreaks() => _renderLineBreaks;

  void setLineSpacing(double add, double mult) {
    _lineSpacingAdd = add;
    _lineSpacingMult = mult;
    _session?.applyLineSpacing(add, mult);
  }

  double getLineSpacingAdd() => _lineSpacingAdd;
  double getLineSpacingMult() => _lineSpacingMult;

  void setContentStartPadding(double padding) {
    _contentStartPadding = padding.clamp(0, double.infinity);
    _session?.applyContentStartPadding(_contentStartPadding);
  }

  double getContentStartPadding() => _contentStartPadding;

  void setShowSplitLine(bool show) {
    _showSplitLine = show;
    _session?.applyShowSplitLine(show);
  }

  bool isShowSplitLine() => _showSplitLine;

  void setGutterSticky(bool sticky) {
    _gutterSticky = sticky;
    _gutterStickyCustomized = true;
    _session?.applyGutterSticky(sticky);
  }

  bool isGutterSticky() => _gutterSticky;

  void setGutterVisible(bool visible) {
    _gutterVisible = visible;
    _session?.applyGutterVisible(visible);
  }

  bool isGutterVisible() => _gutterVisible;

  void setCurrentLineRenderMode(core.CurrentLineRenderMode mode) {
    _currentLineRenderMode = mode;
    _session?.applyCurrentLineRenderMode(mode);
  }

  core.CurrentLineRenderMode getCurrentLineRenderMode() =>
      _currentLineRenderMode;

  void setAutoIndentMode(core.AutoIndentMode mode) {
    _autoIndentMode = mode;
    _session?.applyAutoIndentMode(mode);
  }

  core.AutoIndentMode getAutoIndentMode() => _autoIndentMode;

  void setBackspaceUnindent(bool enabled) {
    _backspaceUnindent = enabled;
    _session?.applyBackspaceUnindent(enabled);
  }

  bool isBackspaceUnindent() => _backspaceUnindent;

  void setReadOnly(bool readOnly) {
    _readOnly = readOnly;
    _session?.applyReadOnly(readOnly);
  }

  bool isReadOnly() => _readOnly;

  void setMaxGutterIcons(int count) {
    _maxGutterIcons = count;
    _session?.applyMaxGutterIcons(count);
  }

  int getMaxGutterIcons() => _maxGutterIcons;

  void setDecorationScrollRefreshMinIntervalMs(int intervalMs) {
    _decorationScrollRefreshMinIntervalMs = intervalMs.clamp(0, 1 << 30);
    _session?.decorationProviderManager.requestRefresh();
  }

  int getDecorationScrollRefreshMinIntervalMs() =>
      _decorationScrollRefreshMinIntervalMs;

  void setDecorationOverscanViewportMultiplier(double multiplier) {
    _decorationOverscanViewportMultiplier = multiplier.clamp(
      0,
      double.infinity,
    );
    _session?.decorationProviderManager.requestRefresh();
  }

  double getDecorationOverscanViewportMultiplier() =>
      _decorationOverscanViewportMultiplier;

  void _applyAll(EditorSession session) {
    session.applyTypography(
      textSize: _textSize,
      fontFamily: _fontFamily,
      scale: _scale,
    );
    session.applyFoldArrowMode(_foldArrowMode);
    session.applyWrapMode(_wrapMode);
    session.applyRenderWhitespace(_renderWhitespace);
    session.applyRenderLineBreaks(_renderLineBreaks);
    session.applyLineSpacing(_lineSpacingAdd, _lineSpacingMult);
    session.applyContentStartPadding(_contentStartPadding);
    session.applyShowSplitLine(_showSplitLine);
    session.applyGutterSticky(_gutterSticky);
    session.applyGutterVisible(_gutterVisible);
    session.applyCurrentLineRenderMode(_currentLineRenderMode);
    session.applyAutoIndentMode(_autoIndentMode);
    session.applyBackspaceUnindent(_backspaceUnindent);
    session.applyReadOnly(_readOnly);
    session.applyMaxGutterIcons(_maxGutterIcons);
    session.decorationProviderManager.requestRefresh();
  }
}
