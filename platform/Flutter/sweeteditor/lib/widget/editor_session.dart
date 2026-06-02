part of '../sweeteditor.dart';

class EditorSession {
  EditorSession({
    required this.controller,
    required EditorTheme theme,
    EditorSettings? initialSettings,
    required String fontFamily,
    required double fontSize,
    required bool gutterSticky,
    required this.platformBehavior,
    required EditorKeyMap initialKeyMap,
    EditorIconProvider? initialIconProvider,
    LanguageConfiguration? initialLanguageConfiguration,
    EditorMetadata? initialMetadata,
  }) : _theme = theme {
    _settings = (initialSettings ?? EditorSettings()).copy()
      ..seedDefaults(
        textSize: fontSize,
        fontFamily: fontFamily,
        gutterSticky: gutterSticky,
      );
    _platformScale = _settings.getScale();
    _measurer = EditorTextMeasurer(
      fontFamily: platformBehavior.resolveFontFamily(_settings.getFontFamily()),
      fontSize: _settings.getEditorTextSize() * _platformScale,
    );
    _iconProvider = initialIconProvider;
    _painter = EditorCanvasPainter(
      theme: _theme,
      measurer: _measurer,
      iconProvider: _iconProvider,
      showSelectionHandles: platformBehavior.showsSelectionHandles,
    );
    final nativeMeasurer = _measurer.buildNativeMeasurer();
    _editorCore = core.EditorCore(
      measurer: nativeMeasurer,
      options: core.EditorOptions(
        revealSelectionEndOnSelectAll:
            platformBehavior.revealSelectionEndOnSelectAll,
      ),
    );
    _keyMap = initialKeyMap;
    _editorCore!.setHandleConfig(platformBehavior.handleConfig);
    _editorCore!.setScrollbarConfig(platformBehavior.scrollbarConfig);
    _editorCore!.setKeyMap(_keyMap.bindings);
    _languageConfiguration = initialLanguageConfiguration;
    _metadata = initialMetadata;
    completionPopupController = CompletionPopupController();
    selectionMenuController = SelectionMenuController(
      enabled: platformBehavior.showsFloatingSelectionMenu,
      buildContext: _buildSelectionMenuContext,
    );
    completionProviderManager = CompletionProviderManager(session: this);
    decorationProviderManager = DecorationProviderManager(session: this);
    inlineSuggestionController = InlineSuggestionController(session: this);
    newLineActionProviderManager = NewLineActionProviderManager();
    _setEditorRenderColors();
    _editorCore!.registerBatchTextStyles(_theme.textStyles);
    _applyInitialLanguageConfiguration(_languageConfiguration);
  }

  final SweetEditorController controller;
  final EditorPlatformBehavior platformBehavior;
  late final CompletionProviderManager completionProviderManager;
  late final CompletionPopupController completionPopupController;
  late final DecorationProviderManager decorationProviderManager;
  late final NewLineActionProviderManager newLineActionProviderManager;
  late final SelectionMenuController selectionMenuController;
  late final InlineSuggestionController inlineSuggestionController;

  late final EditorTextMeasurer _measurer;
  late final EditorCanvasPainter _painter;
  late final EditorSettings _settings;
  core.EditorCore? _editorCore;
  core.Document? _document;
  bool _ownsDocument = false;
  core.EditorRenderModel _renderModel = const core.EditorRenderModel();
  EditorTheme _theme;
  late EditorKeyMap _keyMap;
  EditorIconProvider? _iconProvider;
  LanguageConfiguration? _languageConfiguration;
  EditorMetadata? _metadata;
  Size _viewportSize = Size.zero;
  bool _viewportReady = false;
  bool _cursorVisible = true;
  bool _renderModelDirty = false;
  bool _flushScheduled = false;
  bool _disposed = false;
  double _platformScale = 1.0;

  void Function(core.EditorRenderModel model)? onRenderModelUpdated;
  VoidCallback? onPlatformScaleChanged;
  void Function(core.EditorActionResult? result)? onEditorActionResult;

  EditorEventBus get eventBus => controller._eventBus;
  EditorSettings get settings => _settings;
  core.EditorCore? get editorCore => _editorCore;
  core.Document? get document => _document;
  core.EditorRenderModel get renderModel => _renderModel;
  EditorTheme get theme => _theme;
  EditorKeyMap get keyMap => _keyMap;
  EditorIconProvider? get iconProvider => _iconProvider;
  EditorTextMeasurer get measurer => _measurer;
  EditorCanvasPainter get painter => _painter;
  Size get viewportSize => _viewportSize;
  bool get viewportReady => _viewportReady;
  String get effectiveFontFamily => _measurer.fontFamily;
  double get effectiveScale => _platformScale;
  LanguageConfiguration? get languageConfiguration => _languageConfiguration;
  EditorMetadata? get metadata => _metadata;

  void bindSettings() {
    _settings.bind(this);
    final ec = _editorCore;
    if (ec == null) return;
    _platformScale = _settings.getScale();
    _measurer.updateFont(
      platformBehavior.resolveFontFamily(_settings.getFontFamily()),
      _settings.getEditorTextSize() * _platformScale,
    );
    ec.setScale(_platformScale);
    ec.onFontMetricsChanged();
    onPlatformScaleChanged?.call();
    ec.setFoldArrowMode(_settings.getFoldArrowMode());
    ec.setWrapMode(_settings.getWrapMode());
    ec.setLineSpacing(
      add: _settings.getLineSpacingAdd(),
      mult: _settings.getLineSpacingMult(),
    );
    ec.setContentStartPadding(_settings.getContentStartPadding());
    ec.setShowSplitLine(_settings.isShowSplitLine());
    ec.setGutterSticky(_settings.isGutterSticky());
    ec.setGutterVisible(_settings.isGutterVisible());
    ec.setCurrentLineRenderMode(_settings.getCurrentLineRenderMode());
    ec.setAutoIndentMode(_settings.getAutoIndentMode());
    ec.setBackspaceUnindent(_settings.isBackspaceUnindent());
    ec.setReadOnly(_settings.isReadOnly());
    ec.setMaxGutterIcons(_settings.getMaxGutterIcons());
    decorationProviderManager.requestRefresh();
  }

  void dispose() {
    _disposed = true;
    _settings.unbind(this);
    inlineSuggestionController.dispose();
    selectionMenuController.dispose();
    _editorCore?.close();
    _releaseDocument();
    _measurer.dispose();
    _painter.dispose();
  }

  void applyLanguageConfiguration(LanguageConfiguration? config) {
    _languageConfiguration = config;
    final ec = _editorCore;
    if (ec == null) return;

    final brackets = config?.brackets;
    if (brackets != null) {
      final opens = brackets
          .map((pair) => pair.open.runes.isEmpty ? 0 : pair.open.runes.first)
          .toList(growable: false);
      final closes = brackets
          .map((pair) => pair.close.runes.isEmpty ? 0 : pair.close.runes.first)
          .toList(growable: false);
      dispatchEditorActionResult(ec.setBracketPairs(opens, closes));
    }

    final autoClosingPairs = config?.autoClosingPairs;
    if (autoClosingPairs != null) {
      final opens = autoClosingPairs
          .map((pair) => pair.open.runes.isEmpty ? 0 : pair.open.runes.first)
          .toList(growable: false);
      final closes = autoClosingPairs
          .map((pair) => pair.close.runes.isEmpty ? 0 : pair.close.runes.first)
          .toList(growable: false);
      dispatchEditorActionResult(ec.setAutoClosingPairs(opens, closes));
    }

    if (config != null) {
      if (config.tabSize > 0) {
        dispatchEditorActionResult(ec.setTabSize(config.tabSize));
      }
      dispatchEditorActionResult(ec.setInsertSpaces(config.insertSpaces));
    }
  }

  void _applyInitialLanguageConfiguration(LanguageConfiguration? config) {
    _languageConfiguration = config;
    final ec = _editorCore;
    if (ec == null) return;

    final brackets = config?.brackets;
    if (brackets != null) {
      final opens = brackets
          .map((pair) => pair.open.runes.isEmpty ? 0 : pair.open.runes.first)
          .toList(growable: false);
      final closes = brackets
          .map((pair) => pair.close.runes.isEmpty ? 0 : pair.close.runes.first)
          .toList(growable: false);
      ec.setBracketPairs(opens, closes);
    }

    final autoClosingPairs = config?.autoClosingPairs;
    if (autoClosingPairs != null) {
      final opens = autoClosingPairs
          .map((pair) => pair.open.runes.isEmpty ? 0 : pair.open.runes.first)
          .toList(growable: false);
      final closes = autoClosingPairs
          .map((pair) => pair.close.runes.isEmpty ? 0 : pair.close.runes.first)
          .toList(growable: false);
      ec.setAutoClosingPairs(opens, closes);
    }

    if (config != null) {
      if (config.tabSize > 0) {
        ec.setTabSize(config.tabSize);
      }
      ec.setInsertSpaces(config.insertSpaces);
    }
  }

  void applyMetadata(EditorMetadata? metadata) {
    _metadata = metadata;
  }

  void applyKeyMap(EditorKeyMap keyMap) {
    _keyMap = keyMap;
    dispatchEditorActionResult(_editorCore?.setKeyMap(keyMap.bindings));
  }

  void applyIconProvider(EditorIconProvider? provider) {
    _iconProvider = provider;
    _painter.updateIconProvider(provider);
  }

  void applyDeclarativeSettings(
    EditorSettings? snapshot, {
    required double fontSize,
    required String fontFamily,
    required bool gutterSticky,
  }) {
    final nextSettings = (snapshot ?? EditorSettings()).copy()
      ..seedDefaults(
        textSize: fontSize,
        fontFamily: fontFamily,
        gutterSticky: gutterSticky,
      );
    _settings.replaceFrom(nextSettings);
  }

  void setViewport(Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _viewportSize = size;
    dispatchEditorActionResult(
      _editorCore?.setViewport(size.width.toInt(), size.height.toInt()),
    );
    _viewportReady = true;
  }

  void setCursorVisible(bool visible) {
    _cursorVisible = visible;
    _painter.updateCursorVisible(visible);
  }

  void loadText(String text) {
    loadDocument(core.Document.fromString(text), takeOwnership: true);
  }

  void loadDocument(core.Document document, {required bool takeOwnership}) {
    if (!identical(_document, document)) {
      _releaseDocument();
    }
    _document = document;
    _ownsDocument = takeOwnership;
    dispatchEditorActionResult(_editorCore?.loadDocument(document));
  }

  String getContent() => _document?.text ?? '';

  void requestFlush() {
    if (_disposed) return;
    _renderModelDirty = true;
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_handleFlushFrame);
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void dispatchEditorActionResult(core.EditorActionResult? result) {
    onEditorActionResult?.call(result);
  }

  void _handleFlushFrame(Duration _) {
    _flushScheduled = false;
    _performFlush();
  }

  void _performFlush() {
    if (_disposed || !_renderModelDirty) return;
    if (_editorCore == null || !_viewportReady) return;
    _renderModelDirty = false;
    _renderModel = _editorCore!.buildRenderModel();
    _painter.updateModel(_renderModel, _cursorVisible);
    onRenderModelUpdated?.call(_renderModel);
  }

  void applyTheme(EditorTheme theme) {
    _theme = theme;
    _painter.updateTheme(theme);
    final renderColorResult = _setEditorRenderColors();
    if (renderColorResult != null) {
      dispatchEditorActionResult(renderColorResult);
    }
    _registerTextStyles();
  }

  core.EditorActionResult? _setEditorRenderColors() {
    final ec = _editorCore;
    if (ec == null) return null;
    final codeLensForeground = _theme.codeLensColor != 0
        ? _theme.codeLensColor
        : _theme.inlayHintTextColor;
    final activeCodeLensForeground = _theme.codeLensActiveColor != 0
        ? _theme.codeLensActiveColor
        : (_theme.currentLineNumberColor != 0
              ? _theme.currentLineNumberColor
              : _theme.lineNumberColor);
    final linkForeground = _theme.linkColor != 0
        ? _theme.linkColor
        : codeLensForeground;
    final activeLinkForeground = _theme.linkActiveColor != 0
        ? _theme.linkActiveColor
        : (_theme.linkColor != 0 ? _theme.linkColor : activeCodeLensForeground);
    return ec.setEditorRenderColors(
      core.EditorRenderColors(
        textForeground: _theme.textColor,
        selectionForeground: _theme.selectionTextColor,
        linkForeground: linkForeground,
        activeLinkForeground: activeLinkForeground,
        codelensForeground: codeLensForeground,
        activeCodelensForeground: activeCodeLensForeground,
      ),
    );
  }

  void _registerTextStyles() {
    final ec = _editorCore;
    if (ec == null) return;
    for (final entry in _theme.textStyles.entries) {
      dispatchEditorActionResult(
        ec.registerTextStyle(
          entry.key,
          entry.value.color,
          backgroundColor: entry.value.backgroundColor,
          fontStyle: entry.value.fontStyle,
        ),
      );
    }
  }

  void _releaseDocument() {
    if (_ownsDocument) {
      _document?.close();
    }
    _document = null;
    _ownsDocument = false;
  }

  SelectionMenuContext _buildSelectionMenuContext(bool hasSelection) {
    final editorCore = _editorCore;
    final cursorPosition =
        editorCore?.getCursorPosition() ??
        const core.TextPosition(line: 0, column: 0);
    return SelectionMenuContext(
      hasSelection: hasSelection,
      cursorPosition: cursorPosition,
      selection: editorCore?.getSelection(),
      selectedText: editorCore?.getSelectedText() ?? '',
    );
  }

  void applyTypography({
    required double textSize,
    required String fontFamily,
    required double scale,
  }) {
    final ec = _editorCore;
    if (ec == null) return;
    final scaleResult = ec.setScale(scale);
    if (scaleResult.scaleChanged) {
      dispatchEditorActionResult(scaleResult);
      return;
    }
    _platformScale = scale;
    _measurer.updateFont(
      platformBehavior.resolveFontFamily(fontFamily),
      textSize * scale,
    );
    final metricsResult = ec.onFontMetricsChanged();
    onPlatformScaleChanged?.call();
    dispatchEditorActionResult(scaleResult);
    dispatchEditorActionResult(metricsResult);
  }

  void syncPlatformScale(double scale) {
    final ec = _editorCore;
    if (ec == null) return;
    _platformScale = scale;
    _measurer.updateFont(
      platformBehavior.resolveFontFamily(_settings.getFontFamily()),
      _settings.getEditorTextSize() * scale,
    );
    dispatchEditorActionResult(ec.onFontMetricsChanged());
    onPlatformScaleChanged?.call();
  }

  void applyFoldArrowMode(core.FoldArrowMode mode) {
    dispatchEditorActionResult(_editorCore?.setFoldArrowMode(mode));
  }

  void applyWrapMode(core.WrapMode mode) {
    dispatchEditorActionResult(_editorCore?.setWrapMode(mode));
  }

  void applyLineSpacing(double add, double mult) {
    dispatchEditorActionResult(
      _editorCore?.setLineSpacing(add: add, mult: mult),
    );
  }

  void applyContentStartPadding(double padding) {
    dispatchEditorActionResult(_editorCore?.setContentStartPadding(padding));
  }

  void applyShowSplitLine(bool show) {
    dispatchEditorActionResult(_editorCore?.setShowSplitLine(show));
  }

  void applyGutterSticky(bool sticky) {
    dispatchEditorActionResult(_editorCore?.setGutterSticky(sticky));
  }

  void applyGutterVisible(bool visible) {
    dispatchEditorActionResult(_editorCore?.setGutterVisible(visible));
  }

  void applyCurrentLineRenderMode(core.CurrentLineRenderMode mode) {
    dispatchEditorActionResult(_editorCore?.setCurrentLineRenderMode(mode));
  }

  void applyAutoIndentMode(core.AutoIndentMode mode) {
    dispatchEditorActionResult(_editorCore?.setAutoIndentMode(mode));
  }

  void applyBackspaceUnindent(bool enabled) {
    dispatchEditorActionResult(_editorCore?.setBackspaceUnindent(enabled));
  }

  void applyReadOnly(bool readOnly) {
    dispatchEditorActionResult(_editorCore?.setReadOnly(readOnly));
  }

  void applyMaxGutterIcons(int count) {
    dispatchEditorActionResult(_editorCore?.setMaxGutterIcons(count));
  }
}
