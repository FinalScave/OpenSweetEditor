part of '../sweeteditor.dart';

class EditorSessionHostCallbacks {
  const EditorSessionHostCallbacks({
    required this.onRenderModelUpdated,
    required this.onTextInputStyleInvalidated,
    required this.onHostActionResult,
    required this.onAnimationScheduleChanged,
  });

  final void Function(core.EditorRenderModel model) onRenderModelUpdated;
  final VoidCallback onTextInputStyleInvalidated;
  final void Function(core.EditorActionResult result) onHostActionResult;
  final void Function(int? delayMs) onAnimationScheduleChanged;
}

class EditorSession {
  EditorSession({
    required this.eventBus,
    required this.hostCallbacks,
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
    _declarativeSettings = initialSettings;
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
      showSelectionHandles: platformBehavior.isMobileStyle,
      visualScale: _platformScale,
    );
    final nativeMeasurer = _measurer.buildNativeMeasurer();
    _editorCore = core.EditorCore(
      measurer: nativeMeasurer,
      options: core.EditorOptions(
        revealSelectionEndOnSelectAll: platformBehavior.isMobileStyle,
      ),
    );
    _keyMap = initialKeyMap;
    _editorCore!.setHandleConfig(
      _buildHandleConfig(isMobileStyle: platformBehavior.isMobileStyle),
    );
    _editorCore!.setScrollbarConfig(
      _buildScrollbarConfig(isMobileStyle: platformBehavior.isMobileStyle),
    );
    _editorCore!.setKeyMap(_keyMap.bindings);
    _languageConfiguration = initialLanguageConfiguration;
    _metadata = initialMetadata;
    completionPopupController = CompletionPopupController();
    selectionMenuController = SelectionMenuController(
      enabled: platformBehavior.isMobileStyle,
      buildContext: _buildSelectionMenuContext,
    );
    completionProviderManager = CompletionProviderManager(session: this);
    decorationProviderManager = DecorationProviderManager(session: this);
    inlineSuggestionController = InlineSuggestionController(session: this);
    newLineActionProviderManager = NewLineActionProviderManager();
    _setEditorRenderColors();
    _setEditorRangeEffectStyles();
    _editorCore!.registerBatchTextStyles(_theme.textStyles);
    _applyInitialLanguageConfiguration(_languageConfiguration);
  }

  static core.HandleConfig _buildHandleConfig({required bool isMobileStyle}) {
    if (!isMobileStyle) {
      return const core.HandleConfig(
        startHitArea: core.HandleHitArea(
          left: 1,
          top: 1,
          right: -1,
          bottom: -1,
        ),
        endHitArea: core.HandleHitArea(left: 1, top: 1, right: -1, bottom: -1),
      );
    }

    // Matches the 10px radius, 24px offset, and 45-degree handle geometry.
    const extent = 32.04163056034262;
    return const core.HandleConfig(
      startHitArea: core.HandleHitArea(
        left: -extent,
        top: -8,
        right: 8,
        bottom: extent,
      ),
      endHitArea: core.HandleHitArea(
        left: -8,
        top: -8,
        right: extent,
        bottom: extent,
      ),
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

  final EditorEventBus eventBus;
  final EditorSessionHostCallbacks hostCallbacks;
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
  EditorSettings? _declarativeSettings;
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
  bool _animationActive = false;
  double _platformScale = 1.0;
  double? _pendingPlatformScale;

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
  bool get isActive => !_disposed;
  String get effectiveFontFamily => _measurer.fontFamily;
  double get effectiveScale => _platformScale;
  LanguageConfiguration? get languageConfiguration => _languageConfiguration;
  EditorMetadata? get metadata => _metadata;

  void updateDevicePixelRatio(double devicePixelRatio) {
    _painter.updateDevicePixelRatio(devicePixelRatio);
  }

  void bindSettings() {
    _settings.bind(this);
    final ec = _editorCore;
    if (ec == null) return;
    _platformScale = _settings.getScale();
    if (_platformScale != 1.0) {
      ec.setScale(_platformScale);
    }
    if (_settings.getFoldArrowMode() != core.FoldArrowMode.always) {
      ec.setFoldArrowMode(_settings.getFoldArrowMode());
    }
    if (_settings.getWrapMode() != core.WrapMode.none) {
      ec.setWrapMode(_settings.getWrapMode());
    }
    if (_settings.getRenderWhitespace() != core.WhitespaceRenderMode.none) {
      ec.setRenderWhitespace(_settings.getRenderWhitespace());
    }
    if (_settings.isRenderLineBreaks()) {
      ec.setRenderLineBreaks(true);
    }
    if (_settings.getLineSpacingAdd() != 0.0 ||
        _settings.getLineSpacingMult() != 1.2) {
      ec.setLineSpacing(
        add: _settings.getLineSpacingAdd(),
        mult: _settings.getLineSpacingMult(),
      );
    }
    if (_settings.getContentStartPadding() != 0.0) {
      ec.setContentStartPadding(_settings.getContentStartPadding());
    }
    if (!_settings.isShowSplitLine()) {
      ec.setShowSplitLine(false);
    }
    if (!_settings.isGutterSticky()) {
      ec.setGutterSticky(false);
    }
    if (!_settings.isGutterVisible()) {
      ec.setGutterVisible(false);
    }
    if (_settings.getCurrentLineRenderMode() !=
        core.CurrentLineRenderMode.background) {
      ec.setCurrentLineRenderMode(_settings.getCurrentLineRenderMode());
    }
    if (_settings.getAutoIndentMode() != core.AutoIndentMode.keepIndent) {
      ec.setAutoIndentMode(_settings.getAutoIndentMode());
    }
    if (!_settings.isBackspaceUnindent()) {
      ec.setBackspaceUnindent(false);
    }
    if (_settings.isReadOnly()) {
      ec.setReadOnly(true);
    }
    if (_settings.getMaxGutterIcons() != 0) {
      ec.setMaxGutterIcons(_settings.getMaxGutterIcons());
    }
    decorationProviderManager.requestRefresh();
  }

  void dispose() {
    _disposed = true;
    _pendingPlatformScale = null;
    _settings.unbind(this);
    completionProviderManager.dispose();
    decorationProviderManager.dispose();
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
      handleEditorActionResult(ec.setBracketPairs(opens, closes));
    }

    final autoClosingPairs = config?.autoClosingPairs;
    if (autoClosingPairs != null) {
      final opens = autoClosingPairs
          .map((pair) => pair.open.runes.isEmpty ? 0 : pair.open.runes.first)
          .toList(growable: false);
      final closes = autoClosingPairs
          .map((pair) => pair.close.runes.isEmpty ? 0 : pair.close.runes.first)
          .toList(growable: false);
      handleEditorActionResult(ec.setAutoClosingPairs(opens, closes));
    }

    if (config != null) {
      if (config.tabSize > 0) {
        handleEditorActionResult(ec.setTabSize(config.tabSize));
      }
      handleEditorActionResult(ec.setInsertSpaces(config.insertSpaces));
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
    handleEditorActionResult(_editorCore?.setKeyMap(keyMap.bindings));
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
    _declarativeSettings = snapshot;
    final sourceSettings =
        snapshot ?? (EditorSettings().._setScaleFromPlatform(_platformScale));
    final nextSettings = sourceSettings.copy()
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
    handleEditorActionResult(
      _editorCore?.setViewport(size.width.toInt(), size.height.toInt()),
    );
    _viewportReady = true;
  }

  void setCursorVisible(bool visible) {
    _cursorVisible = visible;
    _painter.updateCursorVisible(visible);
  }

  core.IntRange getVisibleLineRange() {
    final ec = _editorCore;
    if (ec == null) {
      return const core.IntRange(start: 0, end: -1);
    }
    if (_renderModel.lines.isEmpty) {
      ec.buildRenderModel();
    }
    return ec.getVisibleLineRange();
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
    handleEditorActionResult(_editorCore?.loadDocument(document));
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

  void handleEditorActionResult(core.EditorActionResult? result) {
    if (_disposed || result == null) return;
    if (result.gestureType != core.GestureType.undefined) {
      _fireGestureEvents(result);
    }
    selectionMenuController.onEditorActionResult(result);

    _updateAnimationSchedule(result);
    _dispatchStateEvents(result);
    hostCallbacks.onHostActionResult(result);
    if (result.needsRedraw) {
      requestFlush();
    }
  }

  void tickAnimations() {
    final ec = _editorCore;
    if (_disposed || ec == null || !_animationActive) return;
    handleEditorActionResult(ec.tickAnimations());
  }

  void _dispatchTextChanged(core.EditorActionResult result) {
    if (result.textChanges.isEmpty) return;
    eventBus.publish(
      TextChangedEvent(
        changes: result.textChanges,
        kind: result.textChangeKind,
        source: result.source,
      ),
    );
    decorationProviderManager.onTextChanged(result.textChanges);
  }

  void _updateCompletion(core.EditorActionResult result) {
    final ec = _editorCore;
    if (ec == null) {
      return;
    }
    if (result.imeHostAction != core.ImeHostAction.none ||
        ec.isInLinkedEditing) {
      completionProviderManager.dismiss();
      return;
    }

    final textChanged = result.textChanges.isNotEmpty;
    final contextChanged =
        textChanged ||
        result.compositionChanged ||
        result.cursorChanged ||
        result.selectionChanged;
    if (!contextChanged) {
      return;
    }

    if (!textChanged) {
      if (completionPopupController.isShowing) {
        completionProviderManager.dismiss();
      }
      return;
    }
    if (result.textChanges.length != 1) {
      completionProviderManager.dismiss();
      return;
    }

    final composition = result.imeState.compositionRange;
    final compositionActive =
        result.imeState.sessionId != 0 &&
        composition.startUtf16 >= 0 &&
        composition.endUtf16 >= composition.startUtf16;
    if (compositionActive) {
      completionProviderManager.triggerCompletion(
        CompletionTriggerKind.retrigger,
        null,
      );
      return;
    }

    final change = result.textChanges.first;
    if (change.newText.length == 1) {
      final ch = change.newText;
      if (completionProviderManager.isTriggerCharacter(ch)) {
        completionProviderManager.triggerCompletion(
          CompletionTriggerKind.character,
          ch,
        );
      } else if (completionPopupController.isShowing) {
        completionProviderManager.triggerCompletion(
          CompletionTriggerKind.retrigger,
          null,
        );
      }
    } else if (completionPopupController.isShowing) {
      completionProviderManager.triggerCompletion(
        CompletionTriggerKind.retrigger,
        null,
      );
    }
  }

  void _dispatchStateEvents(core.EditorActionResult result) {
    if (result.textChanges.isNotEmpty) {
      _dispatchTextChanged(result);
    }
    _updateCompletion(result);
    if (result.cursorChanged) {
      eventBus.publish(CursorChangedEvent(cursorPosition: result.cursorAfter));
    }
    if (result.selectionChanged) {
      eventBus.publish(
        SelectionChangedEvent(
          hasSelection: result.hasSelectionAfter,
          selection: result.hasSelectionAfter ? result.selectionAfter : null,
          cursorPosition: result.cursorAfter,
        ),
      );
    }
    if (result.scrollChanged) {
      _handleScrollChanged(result);
    }
    if (result.scaleChanged) {
      _pendingPlatformScale = result.scaleAfter;
    }
  }

  void _fireGestureEvents(core.EditorActionResult result) {
    final pos = result.cursorAfter;
    switch (result.gestureType) {
      case core.GestureType.tap:
        _publishHitTargetEvent(result.hitTarget, result.tapPoint);
        completionProviderManager.dismiss();
      case core.GestureType.doubleTap:
        eventBus.publish(
          DoubleTapEvent(
            cursorPosition: pos,
            hasSelection: result.hasSelectionAfter,
            selection: result.hasSelectionAfter ? result.selectionAfter : null,
            locationInEditor: result.tapPoint,
          ),
        );
      case core.GestureType.longPress:
        eventBus.publish(
          LongPressEvent(
            cursorPosition: pos,
            locationInEditor: result.tapPoint,
          ),
        );
      case core.GestureType.contextMenu:
        eventBus.publish(
          ContextMenuEvent(
            cursorPosition: pos,
            locationInEditor: result.tapPoint,
          ),
        );
      case core.GestureType.scroll:
      case core.GestureType.fastScroll:
      case core.GestureType.scale:
      case core.GestureType.dragSelect:
      default:
        break;
    }
  }

  void _handleScrollChanged(core.EditorActionResult result) {
    eventBus.publish(
      ScrollChangedEvent(
        scrollX: result.scrollXAfter,
        scrollY: result.scrollYAfter,
      ),
    );
    decorationProviderManager.onScrollChanged();
    completionProviderManager.dismiss();
  }

  void _publishHitTargetEvent(
    core.HitTarget hitTarget,
    core.PointF locationInEditor,
  ) {
    switch (hitTarget.type) {
      case core.HitTargetType.gutterIcon:
        eventBus.publish(
          GutterIconClickEvent(
            line: hitTarget.line,
            iconId: hitTarget.iconId,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.inlayHintText:
        eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.text,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.inlayHintIcon:
        eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.icon,
            intValue: hitTarget.iconId,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.inlayHintColor:
        eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.color,
            intValue: hitTarget.colorValue,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.none:
        break;
      case core.HitTargetType.foldPlaceholder:
      case core.HitTargetType.foldGutter:
        eventBus.publish(
          FoldToggleEvent(
            line: hitTarget.line,
            isGutter: hitTarget.type == core.HitTargetType.foldGutter,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.codelens:
        eventBus.publish(
          CodeLensClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            commandId: hitTarget.iconId,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.link:
        eventBus.publish(
          LinkClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            target:
                _editorCore?.getLinkTargetAt(
                  hitTarget.line,
                  hitTarget.column,
                ) ??
                '',
            locationInEditor: locationInEditor,
          ),
        );
    }
  }

  void _updateAnimationSchedule(core.EditorActionResult result) {
    _animationActive = result.needsAnimation;
    hostCallbacks.onAnimationScheduleChanged(
      _animationActive ? math.max(0, result.nextAnimationDelayMs) : null,
    );
  }

  void _handleFlushFrame(Duration _) {
    _runPendingPlatformScaleSync();
    _flushScheduled = false;
    _performFlush();
  }

  void _runPendingPlatformScaleSync() {
    if (_disposed) {
      _pendingPlatformScale = null;
      return;
    }
    final scale = _pendingPlatformScale;
    _pendingPlatformScale = null;
    if (scale == null) return;
    _syncPlatformScaleNow(scale);
    eventBus.publish(ScaleChangedEvent(scale: scale));
  }

  void _performFlush() {
    if (_disposed || !_renderModelDirty) return;
    if (_editorCore == null || !_viewportReady) return;
    _renderModelDirty = false;
    _renderModel = _editorCore!.buildRenderModel();
    _painter.updateModel(_renderModel, _cursorVisible);
    hostCallbacks.onRenderModelUpdated(_renderModel);
  }

  void applyTheme(EditorTheme theme) {
    _theme = theme;
    _painter.updateTheme(theme);
    final renderColorResult = _setEditorRenderColors();
    if (renderColorResult != null) {
      handleEditorActionResult(renderColorResult);
    }
    final rangeEffectResult = _setEditorRangeEffectStyles();
    if (rangeEffectResult != null) {
      handleEditorActionResult(rangeEffectResult);
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
        linkForeground: linkForeground,
        activeLinkForeground: activeLinkForeground,
        codelensForeground: codeLensForeground,
        activeCodelensForeground: activeCodeLensForeground,
        diffAddedLineBackground: _theme.diffAddedLineBackgroundColor,
        diffRemovedLineBackground: _theme.diffRemovedLineBackgroundColor,
        diffAddedGutterBackground: _theme.diffAddedGutterBackgroundColor,
        diffRemovedGutterBackground: _theme.diffRemovedGutterBackgroundColor,
      ),
    );
  }

  core.EditorActionResult? _setEditorRangeEffectStyles() {
    final ec = _editorCore;
    if (ec == null) return null;
    return ec.setEditorRangeEffectStyles(
      core.EditorRangeEffectStyles(
        selection: core.RangeEffectStyle(
          foregroundColor: _theme.selectionTextColor,
          backgroundColor: _theme.selectionColor,
        ),
        searchMatch: core.RangeEffectStyle(
          backgroundColor: _theme.searchMatchBgColor,
        ),
        searchCurrent: core.RangeEffectStyle(
          backgroundColor: _theme.searchCurrentBgColor,
          borderColor: _theme.searchCurrentBorderColor,
        ),
        documentHighlightText: core.RangeEffectStyle(
          backgroundColor: _theme.documentHighlightTextBgColor,
        ),
        documentHighlightRead: core.RangeEffectStyle(
          backgroundColor: _theme.documentHighlightReadBgColor,
        ),
        documentHighlightWrite: core.RangeEffectStyle(
          backgroundColor: _theme.documentHighlightWriteBgColor,
        ),
        imeComposition: core.RangeEffectStyle(
          underlineColor: _theme.compositionUnderlineColor,
          underlineStyle: core.RangeEffectUnderlineStyle.solid,
        ),
        diagnosticError: _diagnosticStyle(
          _theme.diagnosticErrorColor,
          core.RangeEffectUnderlineStyle.wavy,
        ),
        diagnosticWarning: _diagnosticStyle(
          _theme.diagnosticWarningColor,
          core.RangeEffectUnderlineStyle.wavy,
        ),
        diagnosticInfo: _diagnosticStyle(
          _theme.diagnosticInfoColor,
          core.RangeEffectUnderlineStyle.wavy,
        ),
        diagnosticHint: _diagnosticStyle(
          _theme.diagnosticHintColor,
          core.RangeEffectUnderlineStyle.dashed,
        ),
        linkedEditingActive: core.RangeEffectStyle(
          backgroundColor: _withAlpha(_theme.linkedEditingActiveColor, 0x20),
          borderColor: _theme.linkedEditingActiveColor,
        ),
        linkedEditingInactive: core.RangeEffectStyle(
          borderColor: _theme.linkedEditingInactiveColor,
        ),
        bracketMatch: core.RangeEffectStyle(
          backgroundColor: _theme.bracketHighlightBgColor,
          borderColor: _theme.bracketHighlightBorderColor,
        ),
      ),
    );
  }

  core.RangeEffectStyle _diagnosticStyle(
    int color,
    core.RangeEffectUnderlineStyle underlineStyle,
  ) {
    return core.RangeEffectStyle(
      underlineColor: color,
      underlineStyle: underlineStyle,
    );
  }

  int _withAlpha(int color, int alpha) {
    if (color == 0) return 0;
    return (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
  }

  void _registerTextStyles() {
    final ec = _editorCore;
    if (ec == null) return;
    for (final entry in _theme.textStyles.entries) {
      handleEditorActionResult(
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
      handleEditorActionResult(scaleResult);
      return;
    }
    _platformScale = scale;
    _settings._setScaleFromPlatform(scale);
    _declarativeSettings?._setScaleFromPlatform(scale);
    _painter.updateVisualScale(scale);
    _measurer.updateFont(
      platformBehavior.resolveFontFamily(fontFamily),
      textSize * scale,
    );
    final metricsResult = ec.onFontMetricsChanged();
    hostCallbacks.onTextInputStyleInvalidated();
    handleEditorActionResult(scaleResult);
    handleEditorActionResult(metricsResult);
  }

  void _syncPlatformScaleNow(double scale) {
    final ec = _editorCore;
    if (ec == null) return;
    _platformScale = scale;
    _settings._setScaleFromPlatform(scale);
    _declarativeSettings?._setScaleFromPlatform(scale);
    _painter.updateVisualScale(scale);
    _measurer.updateFont(
      platformBehavior.resolveFontFamily(_settings.getFontFamily()),
      _settings.getEditorTextSize() * scale,
    );
    handleEditorActionResult(ec.onFontMetricsChanged());
    hostCallbacks.onTextInputStyleInvalidated();
  }

  void applyFoldArrowMode(core.FoldArrowMode mode) {
    handleEditorActionResult(_editorCore?.setFoldArrowMode(mode));
  }

  void applyWrapMode(core.WrapMode mode) {
    handleEditorActionResult(_editorCore?.setWrapMode(mode));
  }

  void applyRenderWhitespace(core.WhitespaceRenderMode mode) {
    handleEditorActionResult(_editorCore?.setRenderWhitespace(mode));
  }

  void applyRenderLineBreaks(bool enabled) {
    handleEditorActionResult(_editorCore?.setRenderLineBreaks(enabled));
  }

  void applyLineSpacing(double add, double mult) {
    handleEditorActionResult(_editorCore?.setLineSpacing(add: add, mult: mult));
  }

  void applyContentStartPadding(double padding) {
    handleEditorActionResult(_editorCore?.setContentStartPadding(padding));
  }

  void applyShowSplitLine(bool show) {
    handleEditorActionResult(_editorCore?.setShowSplitLine(show));
  }

  void applyGutterSticky(bool sticky) {
    handleEditorActionResult(_editorCore?.setGutterSticky(sticky));
  }

  void applyGutterVisible(bool visible) {
    handleEditorActionResult(_editorCore?.setGutterVisible(visible));
  }

  void applyCurrentLineRenderMode(core.CurrentLineRenderMode mode) {
    handleEditorActionResult(_editorCore?.setCurrentLineRenderMode(mode));
  }

  void applyAutoIndentMode(core.AutoIndentMode mode) {
    handleEditorActionResult(_editorCore?.setAutoIndentMode(mode));
  }

  void applyBackspaceUnindent(bool enabled) {
    handleEditorActionResult(_editorCore?.setBackspaceUnindent(enabled));
  }

  void applyReadOnly(bool readOnly) {
    handleEditorActionResult(_editorCore?.setReadOnly(readOnly));
  }

  void applyMaxGutterIcons(int count) {
    handleEditorActionResult(_editorCore?.setMaxGutterIcons(count));
  }
}
