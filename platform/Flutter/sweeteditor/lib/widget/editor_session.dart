part of '../sweeteditor.dart';

class EditorSession implements EditorSettingsHost {
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
    required this.completionPopupController,
    required this.selectionMenuController,
  }) : _theme = theme {
    _settings = (initialSettings ?? EditorSettings()).copy()
      ..seedDefaults(
        textSize: fontSize,
        fontFamily: fontFamily,
        gutterSticky: gutterSticky,
      );
    _platformScale = _settings.getScale();
    _measurer = EditorTextMeasurer(
      fontFamily: _settings.getFontFamily(),
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
    _editorCore!.setKeyMap(_keyMap);
    _languageConfiguration = initialLanguageConfiguration;
    _metadata = initialMetadata;
    completionProviderManager = CompletionProviderManager(session: this);
    decorationProviderManager = DecorationProviderManager(session: this);
    inlineSuggestionController = InlineSuggestionController(session: this);
    newLineActionProviderManager = NewLineActionProviderManager();
    _registerTextStyles();
    applyLanguageConfiguration(_languageConfiguration);
  }

  final SweetEditorController controller;
  final EditorPlatformBehavior platformBehavior;
  late final CompletionProviderManager completionProviderManager;
  final CompletionPopupController completionPopupController;
  late final DecorationProviderManager decorationProviderManager;
  late final NewLineActionProviderManager newLineActionProviderManager;
  final SelectionMenuController selectionMenuController;
  late final InlineSuggestionController inlineSuggestionController;

  late final EditorTextMeasurer _measurer;
  late final EditorCanvasPainter _painter;
  late final EditorSettings _settings;
  core.EditorCore? _editorCore;
  core.Document? _document;
  bool _ownsDocument = false;
  core.EditorRenderModel _renderModel = core.EditorRenderModel.empty;
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
  VoidCallback? onRequestDecorationRefresh;
  VoidCallback? onPlatformScaleChanged;

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
  double get effectiveScale => _platformScale;
  LanguageConfiguration? get languageConfiguration => _languageConfiguration;
  EditorMetadata? get metadata => _metadata;

  void bindSettings() {
    _settings.bind(this);
  }

  void dispose() {
    _disposed = true;
    _settings.unbind(this);
    inlineSuggestionController.dispose();
    _editorCore?.close();
    _releaseDocument();
    _measurer.dispose();
    _painter.dispose();
  }

  void setHandleConfig(core.HandleConfig config) {
    _editorCore?.setHandleConfig(config);
  }

  void setScrollbarConfig(core.ScrollbarConfig config) {
    _editorCore?.setScrollbarConfig(config);
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
    _editorCore?.setKeyMap(keyMap);
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
    _editorCore?.setViewport(size.width.toInt(), size.height.toInt());
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
    _editorCore?.loadDocument(document);
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

  void flush() {
    requestFlush();
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
    _registerTextStyles();
  }

  void _registerTextStyles() {
    final ec = _editorCore;
    if (ec == null) return;
    for (final entry in _theme.textStyles.entries) {
      ec.registerTextStyle(
        entry.key,
        entry.value.color,
        backgroundColor: entry.value.backgroundColor,
        fontStyle: entry.value.fontStyle,
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

  @override
  void applyTypography({
    required double textSize,
    required String fontFamily,
    required double scale,
  }) {
    final ec = _editorCore;
    if (ec == null) return;
    _platformScale = scale;
    _measurer.updateFont(fontFamily, textSize * scale);
    ec.setScale(scale);
    ec.onFontMetricsChanged();
    onPlatformScaleChanged?.call();
  }

  void syncPlatformScale(double scale) {
    final ec = _editorCore;
    if (ec == null) return;
    _platformScale = scale;
    _measurer.updateFont(
      _settings.getFontFamily(),
      _settings.getEditorTextSize() * scale,
    );
    ec.onFontMetricsChanged();
    onPlatformScaleChanged?.call();
  }

  @override
  void applyFoldArrowMode(core.FoldArrowMode mode) {
    _editorCore?.setFoldArrowMode(mode);
  }

  @override
  void applyWrapMode(core.WrapMode mode) {
    _editorCore?.setWrapMode(mode);
  }

  @override
  void applyLineSpacing(double add, double mult) {
    _editorCore?.setLineSpacing(add: add, mult: mult);
  }

  @override
  void applyContentStartPadding(double padding) {
    _editorCore?.setContentStartPadding(padding);
  }

  @override
  void applyShowSplitLine(bool show) {
    _editorCore?.setShowSplitLine(show);
  }

  @override
  void applyGutterSticky(bool sticky) {
    _editorCore?.setGutterSticky(sticky);
  }

  @override
  void applyGutterVisible(bool visible) {
    _editorCore?.setGutterVisible(visible);
  }

  @override
  void applyCurrentLineRenderMode(core.CurrentLineRenderMode mode) {
    _editorCore?.setCurrentLineRenderMode(mode);
  }

  @override
  void applyAutoIndentMode(core.AutoIndentMode mode) {
    _editorCore?.setAutoIndentMode(mode);
  }

  @override
  void applyBackspaceUnindent(bool enabled) {
    _editorCore?.setBackspaceUnindent(enabled);
  }

  @override
  void applyReadOnly(bool readOnly) {
    _editorCore?.setReadOnly(readOnly);
  }

  @override
  void applyMaxGutterIcons(int count) {
    _editorCore?.setMaxGutterIcons(count);
  }

  @override
  void requestDecorationRefresh() {
    onRequestDecorationRefresh?.call();
  }

  @override
  void flushEditor() {
    requestFlush();
  }
}
