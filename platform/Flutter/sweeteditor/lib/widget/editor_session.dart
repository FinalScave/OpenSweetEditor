part of '../sweeteditor.dart';

class EditorSession implements EditorSettingsHost {
  EditorSession({
    required this.controller,
    required EditorTheme theme,
    required String fontFamily,
    required double fontSize,
    required this.completionPopupController,
    required this.selectionMenuController,
  }) : _theme = theme {
    controller.settings.seedDefaults(textSize: fontSize, fontFamily: fontFamily);
    _measurer = EditorTextMeasurer(
      fontFamily: controller.settings.getFontFamily(),
      fontSize:
          controller.settings.getEditorTextSize() *
          controller.settings.getScale(),
    );
    _painter = EditorCanvasPainter(theme: _theme, measurer: _measurer);
    final nativeMeasurer = _measurer.buildNativeMeasurer();
    _editorCore = core.EditorCore(measurer: nativeMeasurer);
    completionProviderManager = CompletionProviderManager(session: this);
    decorationProviderManager = DecorationProviderManager(session: this);
    inlineSuggestionController = InlineSuggestionController(session: this);
    newLineActionProviderManager = NewLineActionProviderManager();
    _registerTextStyles();
  }

  final SweetEditorController controller;
  late final CompletionProviderManager completionProviderManager;
  final CompletionPopupController completionPopupController;
  late final DecorationProviderManager decorationProviderManager;
  late final NewLineActionProviderManager newLineActionProviderManager;
  final SelectionMenuController selectionMenuController;
  late final InlineSuggestionController inlineSuggestionController;

  late final EditorTextMeasurer _measurer;
  late final EditorCanvasPainter _painter;
  core.EditorCore? _editorCore;
  core.Document? _document;
  core.EditorRenderModel _renderModel = core.EditorRenderModel.empty;
  EditorTheme _theme;
  Size _viewportSize = Size.zero;
  bool _viewportReady = false;
  bool _cursorVisible = true;
  bool _renderModelDirty = false;
  bool _flushScheduled = false;
  bool _disposed = false;

  void Function(core.EditorRenderModel model)? onRenderModelUpdated;
  VoidCallback? onRequestDecorationRefresh;

  EditorEventBus get eventBus => controller._eventBus;
  EditorSettings get settings => controller.settings;
  core.EditorCore? get editorCore => _editorCore;
  core.Document? get document => _document;
  core.EditorRenderModel get renderModel => _renderModel;
  EditorTheme get theme => _theme;
  EditorTextMeasurer get measurer => _measurer;
  EditorCanvasPainter get painter => _painter;
  Size get viewportSize => _viewportSize;
  bool get viewportReady => _viewportReady;
  LanguageConfiguration? get languageConfiguration =>
      controller.languageConfiguration;
  EditorMetadata? get metadata => controller.metadata;

  void bindSettings() {
    controller.settings.bind(this);
  }

  void dispose() {
    _disposed = true;
    controller.settings.unbind(this);
    inlineSuggestionController.dispose();
    _editorCore?.close();
    _document?.close();
    _measurer.dispose();
    _painter.dispose();
  }

  void setHandleConfig(core.HandleConfig config) {
    _editorCore?.setHandleConfig(config);
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
    _document?.close();
    _document = core.Document.fromString(text);
    _editorCore?.setDocument(_document!);
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

  @override
  void applyTypography({
    required double textSize,
    required String fontFamily,
    required double scale,
  }) {
    final ec = _editorCore;
    if (ec == null) return;
    _measurer.updateFont(fontFamily, textSize * scale);
    ec.setScale(scale);
    ec.onFontMetricsChanged();
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
