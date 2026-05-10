part of '../sweeteditor.dart';

/// A Flutter widget that wraps the native SweetEditor engine.
///
/// Renders a full code editor with syntax highlighting, cursor, selection,
/// completion popup, inline suggestions, decorations, guides, and scrollbars.
///
/// Usage:
/// ```
/// final controller = SweetEditorController();
/// SweetEditorWidget(
///   controller: controller,
///   text: 'hello world',
/// );
/// ```
class SweetEditorWidget extends StatefulWidget {
  const SweetEditorWidget({
    super.key,
    required this.controller,
    this.document,
    this.text,
    this.theme,
    this.settings,
    this.keyMap,
    this.iconProvider,
    this.languageConfiguration,
    this.metadata,
    this.fontFamily = 'monospace',
    this.fontSize = 14,
    this.autofocus = true,
  });

  final SweetEditorController controller;
  final core.Document? document;
  final String? text;
  final EditorTheme? theme;
  final EditorSettings? settings;
  final EditorKeyMap? keyMap;
  final EditorIconProvider? iconProvider;
  final LanguageConfiguration? languageConfiguration;
  final EditorMetadata? metadata;
  final String fontFamily;
  final double fontSize;
  final bool autofocus;

  @override
  State<SweetEditorWidget> createState() => _SweetEditorWidgetState();
}

class _SweetEditorWidgetState extends State<SweetEditorWidget>
    with TickerProviderStateMixin, DeltaTextInputClient {
  static const bool _debugImeDeltaTraceEnabled = bool.fromEnvironment(
    'SWEETEDITOR_DEBUG_IME',
  );

  late EditorSession _session;
  late EditorOverlayCoordinator _overlayCoordinator;
  late EditorInteractionController _interactionController;
  late final EditorPlatformBehavior _platformBehavior;
  late final FocusNode _focusNode;
  final GlobalKey _editorKey = GlobalKey();
  TextInputConnection? _textInputConnection;
  TextEditingValue _textEditingValue = TextEditingValue.empty;
  int _textInputWindowStartOffset = 0;
  bool _textInputMarkedDocumentRange = false;
  TextRange? _textInputMarkedRange;
  bool _textInputPlainInputLockActive = false;
  bool _textInputRetainedPlainContextActive = false;
  bool _handlingTextInputUpdate = false;
  bool _pendingShowTextInput = false;
  Size? _pendingViewportSize;
  bool _viewportUpdateScheduled = false;
  bool _editorResourcesReleased = false;
  core.PointerCursorType _pointerCursorType = core.PointerCursorType.text;

  EditorEventBus get _eventBus => widget.controller._eventBus;
  core.EditorCore? get _editorCore => _session.editorCore;
  core.Document? get _document => _session.document;
  EditorTheme get _theme => _session.theme;
  EditorCanvasPainter get _painter => _session.painter;
  CompletionProviderManager get _completionProviderManager =>
      _session.completionProviderManager;
  CompletionPopupController get _completionPopupController =>
      _session.completionPopupController;
  InlineSuggestionController get _inlineSuggestionController =>
      _session.inlineSuggestionController;
  DecorationProviderManager get _decorationProviderManager =>
      _session.decorationProviderManager;
  NewLineActionProviderManager get _newLineActionProviderManager =>
      _session.newLineActionProviderManager;
  SelectionMenuController get _selectionMenuController =>
      _session.selectionMenuController;
  EditorSettings get _settings => _session.settings;

  @override
  void initState() {
    super.initState();
    _platformBehavior = EditorPlatformBehavior.resolve();
    _focusNode = FocusNode(debugLabel: 'SweetEditor');
    _focusNode.addListener(_handleFocusChanged);
    _initEditor();
  }

  @override
  void didUpdateWidget(covariant SweetEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.controller, oldWidget.controller)) {
      throw StateError(
        'SweetEditorWidget cannot change controller after the editor is mounted',
      );
    }

    final defaultTheme = EditorTheme.dark();
    _applyTheme(widget.theme ?? defaultTheme);
    _session.applyDeclarativeSettings(
      widget.settings,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
      gutterSticky: _platformBehavior.gutterStickyDefault,
    );
    _applyKeyMap(widget.keyMap ?? EditorKeyMap.defaultKeyMap());
    _applyIconProvider(widget.iconProvider);
    _applyLanguageConfiguration(widget.languageConfiguration);
    _applyMetadata(widget.metadata);

    final documentChanged = !identical(widget.document, oldWidget.document);
    final textChanged = widget.text != oldWidget.text;
    if (widget.document != null) {
      if (documentChanged) {
        _loadDocument(widget.document!);
      }
    } else if (documentChanged || textChanged) {
      _loadText(widget.text ?? '');
    }
  }

  @override
  void dispose() {
    _closeTextInputConnection();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _releaseEditorResources();
    super.dispose();
  }

  void _initEditor() {
    _initSubsystems();
    _session.onRequestDecorationRefresh =
        _decorationProviderManager.requestRefresh;
    _session.onRenderModelUpdated = (model) {
      final pointerCursorChanged =
          model.pointerCursorType != _pointerCursorType;
      _pointerCursorType = model.pointerCursorType;
      _overlayCoordinator.onRenderModelUpdated(model);
      _updateTextInputGeometry();
      if (pointerCursorChanged && mounted) {
        setState(() {});
      }
    };
    _session.onPlatformScaleChanged = _updateTextInputStyle;
    _session.bindSettings();
    _session.setHandleConfig(_platformBehavior.handleConfig);
    _session.setScrollbarConfig(_platformBehavior.scrollbarConfig);
    _applyDeclarativeInputs();
    widget.controller._attach(this);
    _interactionController.startCursorBlink();
  }

  void _initSubsystems() {
    _session = EditorSession(
      controller: widget.controller,
      theme: widget.theme ?? EditorTheme.dark(),
      initialSettings: widget.settings,
      fontFamily: widget.fontFamily,
      fontSize: widget.fontSize,
      gutterSticky: _platformBehavior.gutterStickyDefault,
      platformBehavior: _platformBehavior,
      initialKeyMap: widget.keyMap ?? EditorKeyMap.defaultKeyMap(),
      initialIconProvider: widget.iconProvider,
      initialLanguageConfiguration: widget.languageConfiguration,
      initialMetadata: widget.metadata,
      completionPopupController: CompletionPopupController(
        panelBgColor:
            widget.theme?.completionBgColor ??
            EditorTheme.dark().completionBgColor,
        panelBorderColor:
            widget.theme?.completionBorderColor ??
            EditorTheme.dark().completionBorderColor,
        selectedBgColor:
            widget.theme?.completionSelectedBgColor ??
            EditorTheme.dark().completionSelectedBgColor,
        labelColor:
            widget.theme?.completionLabelColor ??
            EditorTheme.dark().completionLabelColor,
        detailColor:
            widget.theme?.completionDetailColor ??
            EditorTheme.dark().completionDetailColor,
      ),
      selectionMenuController: SelectionMenuController(
        enabled: _platformBehavior.showsFloatingSelectionMenu,
      ),
    );

    final completionProviderManager = _session.completionProviderManager;
    _overlayCoordinator = EditorOverlayCoordinator(
      session: _session,
      platformBehavior: _platformBehavior,
    );
    _interactionController = EditorInteractionController(
      session: _session,
      tickerProvider: this,
    );

    _session.completionPopupController.setConfirmHandler(
      _interactionController.onCompletionItemConfirmed,
    );
    completionProviderManager.setListener(_session.completionPopupController);
  }

  void _applyDeclarativeInputs() {
    final document = widget.document;
    if (document != null) {
      _loadDocument(document);
      return;
    }
    final text = widget.text;
    if (text != null) {
      _loadText(text);
    }
  }

  void _loadText(String text) {
    _session.loadText(text);
    _onDocumentLoaded();
  }

  void _loadDocument(core.Document document) {
    _session.loadDocument(document, takeOwnership: false);
    _onDocumentLoaded();
  }

  void _onDocumentLoaded() {
    _decorationProviderManager.onDocumentLoaded();
    _eventBus.publish(DocumentLoadedEvent());
    _flush();
  }

  String _getContent() => _session.getContent();

  void _flush() {
    if (!mounted) return;
    if (!_handlingTextInputUpdate) {
      _syncTextInputState();
    }
    _session.requestFlush();
  }

  void _scheduleViewportUpdate(Size size) {
    _pendingViewportSize = size;
    if (_viewportUpdateScheduled) return;
    _viewportUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewportUpdateScheduled = false;
      final pendingSize = _pendingViewportSize;
      _pendingViewportSize = null;
      if (!mounted || pendingSize == null) return;
      if (pendingSize.width <= 0 || pendingSize.height <= 0) return;
      if (pendingSize != _session.viewportSize) {
        _session.setViewport(pendingSize);
        _flush();
      }
    });
  }

  void _applyTheme(EditorTheme theme) {
    _session.applyTheme(theme);
    _overlayCoordinator.applyTheme(theme);
    if (mounted) {
      setState(() {});
    }
    _flush();
  }

  void _applyIconProvider(EditorIconProvider? provider) {
    _session.applyIconProvider(provider);
    _flush();
  }

  void _applyKeyMap(EditorKeyMap keyMap) {
    _session.applyKeyMap(keyMap);
  }

  void _applyLanguageConfiguration(LanguageConfiguration? config) {
    _session.applyLanguageConfiguration(config);
    _decorationProviderManager.requestRefresh();
    _flush();
  }

  void _applyMetadata(EditorMetadata? metadata) {
    _session.applyMetadata(metadata);
    _decorationProviderManager.requestRefresh();
    _flush();
  }

  void _releaseEditorResources() {
    if (_editorResourcesReleased) return;
    _editorResourcesReleased = true;
    _interactionController.dispose();
    _overlayCoordinator.dispose();
    _completionProviderManager.dispose();
    _decorationProviderManager.dispose();
    widget.controller._detach();
    _session.dispose();
  }

  @override
  TextEditingValue? get currentTextEditingValue => _textEditingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    final editorCore = _editorCore;
    if (editorCore == null) {
      _debugImeTrace(
        () =>
            'updateEditingValue core=null next=${_debugTextEditingValue(value)}',
      );
      _textEditingValue = value;
      _clearTextInputMarkedDocumentRange();
      _textInputPlainInputLockActive = false;
      _textInputRetainedPlainContextActive = false;
      return;
    }
    if (value == _textEditingValue) {
      return;
    }

    final previousValue = _textEditingValue;
    var forceTextInputStateSync = false;
    _debugImeTrace(
      () =>
          'updateEditingValue previous=${_debugTextEditingValue(previousValue)} '
          'next=${_debugTextEditingValue(value)}',
    );
    _handlingTextInputUpdate = true;
    try {
      forceTextInputStateSync = _applyImeEditingValue(
        editorCore,
        previousValue,
        value,
      );
    } finally {
      _handlingTextInputUpdate = false;
    }

    _textEditingValue = value;
    _debugImeTrace(
      () =>
          'updateEditingValue result forceSync=$forceTextInputStateSync '
          'stored=${_debugTextEditingValue(_textEditingValue)}',
    );
    if (forceTextInputStateSync) {
      _syncTextInputState(force: true);
    }
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (textEditingDeltas.isEmpty) {
      return;
    }
    final editorCore = _editorCore;
    var nextValue = _textEditingValue;
    _debugImeTrace(
      () =>
          'updateEditingValueWithDeltas count=${textEditingDeltas.length} '
          'base=${_debugTextEditingValue(nextValue)}',
    );
    if (editorCore == null) {
      for (final delta in textEditingDeltas) {
        nextValue = delta.apply(nextValue);
        _debugImeTrace(
          () =>
              'delta core=null ${_debugTextEditingDelta(delta)} '
              'next=${_debugTextEditingValue(nextValue)}',
        );
      }
      _textEditingValue = nextValue;
      _clearTextInputMarkedDocumentRange();
      _textInputPlainInputLockActive = false;
      _textInputRetainedPlainContextActive = false;
      return;
    }

    var forceTextInputStateSync = false;
    _handlingTextInputUpdate = true;
    try {
      var deltaIndex = 0;
      for (final delta in textEditingDeltas) {
        deltaIndex++;
        final previousValue = nextValue;
        nextValue = delta.apply(previousValue);
        final forceTextInputStateSyncFromDelta = _applyImeEditingDelta(
          editorCore,
          previousValue,
          nextValue,
          delta,
        );
        forceTextInputStateSync =
            forceTextInputStateSyncFromDelta || forceTextInputStateSync;
        _debugImeTrace(
          () =>
              'delta $deltaIndex/${textEditingDeltas.length} '
              '${_debugTextEditingDelta(delta)} '
              'previous=${_debugTextEditingValue(previousValue)} '
              'next=${_debugTextEditingValue(nextValue)} '
              'forceSync=$forceTextInputStateSyncFromDelta '
              'aggregateForceSync=$forceTextInputStateSync',
        );
      }
    } finally {
      _handlingTextInputUpdate = false;
    }

    _textEditingValue = nextValue;
    _debugImeTrace(
      () =>
          'updateEditingValueWithDeltas result '
          'forceSync=$forceTextInputStateSync '
          'stored=${_debugTextEditingValue(_textEditingValue)}',
    );
    if (forceTextInputStateSync) {
      _syncTextInputState(force: true);
    }
  }

  @override
  void performAction(TextInputAction action) {
    switch (action) {
      case TextInputAction.done:
      case TextInputAction.go:
      case TextInputAction.search:
      case TextInputAction.send:
        _focusNode.unfocus();
      default:
        break;
    }
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _textInputConnection = null;
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  void showToolbar() {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void performSelector(String selectorName) {
    _interactionController.performSelector(selectorName);
  }

  void _handleFocusChanged() {
    if (_editorResourcesReleased) {
      _pendingShowTextInput = false;
      _closeTextInputConnection();
      return;
    }
    if (_focusNode.hasFocus) {
      final show = _pendingShowTextInput;
      _pendingShowTextInput = false;
      _openTextInputConnection(show: show);
    } else {
      _pendingShowTextInput = false;
      _closeTextInputConnection();
    }
  }

  void _openTextInputConnection({required bool show}) {
    if (_editorResourcesReleased ||
        !_platformBehavior.usesPlatformTextInput ||
        !_focusNode.hasFocus ||
        !mounted) {
      return;
    }
    final configuration = TextInputConfiguration(
      viewId: View.of(context).viewId,
      inputType: TextInputType.multiline,
      inputAction: TextInputAction.newline,
      readOnly: _settings.isReadOnly(),
      autocorrect: true,
      enableSuggestions: true,
      enableDeltaModel: _platformBehavior.usesDeltaTextInputModel,
    );
    if (_textInputConnection?.attached ?? false) {
      _textInputConnection!.updateConfig(configuration);
    } else {
      _textInputConnection = TextInput.attach(this, configuration);
    }
    _updateTextInputStyle();
    _syncTextInputState(force: true);
    _updateTextInputGeometry();
    if (show || !_platformBehavior.showsSoftKeyboard) {
      _textInputConnection?.show();
    }
  }

  void _closeTextInputConnection() {
    _textInputConnection?.close();
    _textInputConnection = null;
    _clearTextInputMarkedDocumentRange();
    _textInputPlainInputLockActive = false;
    _textInputRetainedPlainContextActive = false;
  }

  void _syncTextInputState({bool force = false}) {
    final nextValue = _buildEditingValueFromEditor();
    if (!_isActiveTextRange(nextValue.composing, nextValue.text)) {
      _clearTextInputMarkedDocumentRange();
    }
    final usesRetainedPlainContext =
        _textInputRetainedPlainContextActive &&
        nextValue.text.isNotEmpty &&
        !_isActiveTextRange(nextValue.composing, nextValue.text);
    if (!usesRetainedPlainContext &&
        (nextValue.text.isNotEmpty ||
            _isActiveTextRange(nextValue.composing, nextValue.text))) {
      _textInputPlainInputLockActive = false;
    }
    if (!force && nextValue == _textEditingValue) {
      _debugImeTrace(
        () =>
            'syncTextInputState skip force=$force next=${_debugTextEditingValue(nextValue)}',
      );
      return;
    }
    _textEditingValue = nextValue;
    _debugImeTrace(
      () =>
          'syncTextInputState force=$force attached=${_textInputConnection?.attached ?? false} '
          'next=${_debugTextEditingValue(nextValue)}',
    );
    if (_textInputConnection?.attached ?? false) {
      _updateTextInputStyle();
      _textInputConnection!.setEditingState(nextValue);
    }
  }

  void _updateTextInputStyle() {
    if (!(_textInputConnection?.attached ?? false)) {
      return;
    }
    _textInputConnection!.setStyle(
      fontFamily: _settings.getFontFamily(),
      fontSize: _settings.getEditorTextSize() * _session.effectiveScale,
      fontWeight: FontWeight.w400,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
  }

  void _updateTextInputGeometry() {
    if (!(_textInputConnection?.attached ?? false)) {
      return;
    }
    final renderBox =
        _editorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      return;
    }
    _textInputConnection!.setEditableSizeAndTransform(
      renderBox.size,
      renderBox.getTransformTo(null),
    );

    final cursor = _session.renderModel.cursor;
    if (cursor.visible) {
      _textInputConnection!.setCaretRect(
        Rect.fromLTWH(cursor.position.x, cursor.position.y, 1, cursor.height),
      );
    }
  }

  TextEditingValue _buildEditingValueFromEditor() {
    final snapshot = _editorCore?.getImeSyncSnapshot();
    if (snapshot == null) {
      _textInputWindowStartOffset = 0;
      _textInputRetainedPlainContextActive = false;
      return TextEditingValue.empty;
    }
    final documentText = _getContent();
    final cursorOffset = _textPositionToOffset(documentText, snapshot.cursor);
    final exposesTextWindow =
        snapshot.contextPolicy != core.ImeContextPolicy.none ||
        snapshot.platformTextWindowText.isNotEmpty;
    final retainedPlainContext = exposesTextWindow
        ? null
        : _buildRetainedPlainTextInputContext(snapshot, documentText);
    final text = exposesTextWindow
        ? snapshot.platformTextWindowText
        : retainedPlainContext?.$1 ?? '';
    if (exposesTextWindow) {
      _textInputRetainedPlainContextActive = false;
    }
    _textInputWindowStartOffset = exposesTextWindow
        ? _normalizeDocumentOffset(
            snapshot.platformTextWindowStartOffset,
            documentText,
          )
        : retainedPlainContext?.$2 ?? cursorOffset;
    final selectionStart = _normalizeTextInputOffset(
      exposesTextWindow
          ? snapshot.platformTextWindowSelectionStartOffset
          : retainedPlainContext?.$3 ?? 0,
      text,
    );
    final selectionEnd = _normalizeTextInputOffset(
      exposesTextWindow
          ? snapshot.platformTextWindowSelectionEndOffset
          : retainedPlainContext?.$3 ?? 0,
      text,
    );
    final selection = TextSelection(
      baseOffset: selectionStart,
      extentOffset: selectionEnd,
    );
    var composing = TextRange.empty;
    if (exposesTextWindow &&
        snapshot.platformTextWindowComposingStartOffset >= 0 &&
        snapshot.platformTextWindowComposingEndOffset >= 0) {
      final composingStart = _normalizeTextInputOffset(
        snapshot.platformTextWindowComposingStartOffset,
        text,
      );
      final composingEnd = _normalizeTextInputOffset(
        snapshot.platformTextWindowComposingEndOffset,
        text,
      );
      if (composingEnd > composingStart) {
        composing = TextRange(start: composingStart, end: composingEnd);
      }
    }
    final editingValue = TextEditingValue(
      text: text,
      selection: selection,
      composing: composing,
    );
    _debugImeTrace(
      () =>
          'buildEditingValue context=${snapshot.contextPolicy} '
          'clear=${snapshot.clearPlatformPreedit} '
          'hasComposing=${snapshot.hasComposingSession} '
          'hasMarked=${snapshot.hasPlatformMarkedRange} '
          'retainedPlainContext=${retainedPlainContext != null} '
          'windowStart=$_textInputWindowStartOffset '
          'windowText=${_debugString(text)} '
          'value=${_debugTextEditingValue(editingValue)}',
    );
    return editingValue;
  }

  bool _applyImeEditingValue(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
  ) {
    var forceTextInputStateSync = false;
    final textChanged = value.text != previousValue.text;
    final composingActive = _isActiveTextRange(value.composing, value.text);
    final previousComposingActive = _isActiveTextRange(
      previousValue.composing,
      previousValue.text,
    );

    if (textChanged) {
      final change = _computeTextReplacement(previousValue.text, value.text);
      if (composingActive) {
        forceTextInputStateSync =
            _markDocumentRangeForComposingDeltaIfNeeded(
              editorCore,
              previousValue,
              value,
              change.$1,
              change.$2,
              change.$3,
            ) ||
            forceTextInputStateSync;
        forceTextInputStateSync =
            _markPreviousComposingRangeForTextDeltaIfNeeded(
              editorCore,
              previousValue,
            ) ||
            forceTextInputStateSync;
        if (_textInputMarkedDocumentRange) {
          forceTextInputStateSync =
              _commitMarkedDocumentRangeTextChange(
                editorCore,
                previousValue,
                value,
                change.$1,
                change.$2,
                change.$3,
              ) ||
              forceTextInputStateSync;
        } else {
          final preeditText = value.text.substring(
            value.composing.start,
            value.composing.end,
          );
          forceTextInputStateSync =
              _dispatchImeAction(editorCore.updateImePreedit(preeditText)) ||
              forceTextInputStateSync;
        }
      } else {
        final documentText = _getContent();
        final range = _textInputOffsetsToDocumentRange(
          documentText,
          change.$1,
          change.$2,
        );
        final replacingComposition =
            previousComposingActive || editorCore.isComposing;
        if (_textInputMarkedDocumentRange) {
          forceTextInputStateSync =
              _commitMarkedDocumentRangeTextChange(
                editorCore,
                previousValue,
                value,
                change.$1,
                change.$2,
                change.$3,
              ) ||
              forceTextInputStateSync;
        } else if (replacingComposition || change.$1 == change.$2) {
          _clearTextInputMarkedDocumentRange();
          forceTextInputStateSync =
              _dispatchImeCommitAction(
                editorCore.commitImeText(change.$3),
                change.$3,
              ) ||
              forceTextInputStateSync;
        } else {
          _clearTextInputMarkedDocumentRange();
          forceTextInputStateSync =
              _dispatchImeAction(editorCore.replaceImeText(range, change.$3)) ||
              forceTextInputStateSync;
        }
      }
    } else if (composingActive) {
      forceTextInputStateSync =
          _applyImeComposingStateUpdate(editorCore, previousValue, value) ||
          forceTextInputStateSync;
    } else if (previousComposingActive || editorCore.isComposing) {
      _clearTextInputMarkedDocumentRange();
      forceTextInputStateSync =
          _dispatchImeAction(editorCore.finishImePreedit()) ||
          forceTextInputStateSync;
    }

    if (!textChanged &&
        !composingActive &&
        !previousComposingActive &&
        !editorCore.isComposing &&
        value.selection != previousValue.selection) {
      _notifyImeSelectionFromTextInput(editorCore, value);
    }
    return forceTextInputStateSync;
  }

  bool _applyImeEditingDelta(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
    TextEditingDelta delta,
  ) {
    if (delta is TextEditingDeltaInsertion) {
      return _applyImeInsertionDelta(editorCore, previousValue, value, delta);
    }
    if (delta is TextEditingDeltaReplacement) {
      return _applyImeReplacementDelta(editorCore, previousValue, value, delta);
    }
    if (delta is TextEditingDeltaDeletion) {
      return _applyImeDeletionDelta(editorCore, previousValue, delta);
    }
    if (delta is TextEditingDeltaNonTextUpdate) {
      return _applyImeComposingStateUpdate(editorCore, previousValue, value);
    }
    return _applyImeEditingValue(editorCore, previousValue, value);
  }

  bool _applyImeInsertionDelta(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
    TextEditingDeltaInsertion delta,
  ) {
    final composingActive = _isActiveTextRange(value.composing, value.text);
    if (_shouldCommitPlainLockedDelta(
      previousValue,
      value,
      delta.textInserted,
      delta.insertionOffset,
      delta.insertionOffset,
    )) {
      _clearTextInputMarkedDocumentRange();
      _dispatchImeCommitAction(
        editorCore.commitImeText(delta.textInserted),
        delta.textInserted,
      );
      return true;
    }
    var forceTextInputStateSync = _markDocumentRangeForComposingDeltaIfNeeded(
      editorCore,
      previousValue,
      value,
      delta.insertionOffset,
      delta.insertionOffset,
      delta.textInserted,
    );
    forceTextInputStateSync =
        _markPreviousComposingRangeForTextDeltaIfNeeded(
          editorCore,
          previousValue,
        ) ||
        forceTextInputStateSync;

    if (_textInputMarkedDocumentRange) {
      return _commitMarkedDocumentRangeTextChange(
            editorCore,
            previousValue,
            value,
            delta.insertionOffset,
            delta.insertionOffset,
            delta.textInserted,
          ) ||
          forceTextInputStateSync;
    }
    if (composingActive) {
      final preeditText = value.text.substring(
        value.composing.start,
        value.composing.end,
      );
      return _dispatchImeAction(editorCore.updateImePreedit(preeditText)) ||
          forceTextInputStateSync;
    }

    _clearTextInputMarkedDocumentRange();
    return _dispatchImeCommitAction(
          editorCore.commitImeText(delta.textInserted),
          delta.textInserted,
        ) ||
        forceTextInputStateSync;
  }

  bool _applyImeReplacementDelta(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
    TextEditingDeltaReplacement delta,
  ) {
    final composingActive = _isActiveTextRange(value.composing, value.text);
    if (delta.replacementText.isEmpty &&
        _isActiveTextRange(delta.replacedRange, previousValue.text)) {
      return _applyImeDeletionRange(editorCore, delta.replacedRange);
    }
    if (_shouldCommitPlainLockedDelta(
      previousValue,
      value,
      delta.replacementText,
      delta.replacedRange.start,
      delta.replacedRange.end,
    )) {
      _clearTextInputMarkedDocumentRange();
      _dispatchImeCommitAction(
        editorCore.commitImeText(delta.replacementText),
        delta.replacementText,
      );
      return true;
    }
    final previousComposingActive = _isActiveTextRange(
      previousValue.composing,
      previousValue.text,
    );
    var forceTextInputStateSync = _markDocumentRangeForComposingDeltaIfNeeded(
      editorCore,
      previousValue,
      value,
      delta.replacedRange.start,
      delta.replacedRange.end,
      delta.replacementText,
    );
    forceTextInputStateSync =
        _markPreviousComposingRangeForTextDeltaIfNeeded(
          editorCore,
          previousValue,
        ) ||
        forceTextInputStateSync;

    if (_textInputMarkedDocumentRange) {
      return _commitMarkedDocumentRangeTextChange(
            editorCore,
            previousValue,
            value,
            delta.replacedRange.start,
            delta.replacedRange.end,
            delta.replacementText,
          ) ||
          forceTextInputStateSync;
    }
    if (composingActive) {
      final preeditText = value.text.substring(
        value.composing.start,
        value.composing.end,
      );
      return _dispatchImeAction(editorCore.updateImePreedit(preeditText)) ||
          forceTextInputStateSync;
    }

    _clearTextInputMarkedDocumentRange();
    if (previousComposingActive || editorCore.isComposing) {
      return _dispatchImeCommitAction(
            editorCore.commitImeText(delta.replacementText),
            delta.replacementText,
          ) ||
          forceTextInputStateSync;
    }
    final documentText = _getContent();
    final range = _textInputOffsetsToDocumentRange(
      documentText,
      delta.replacedRange.start,
      delta.replacedRange.end,
    );
    return _dispatchImeAction(
          editorCore.replaceImeText(range, delta.replacementText),
        ) ||
        forceTextInputStateSync;
  }

  bool _applyImeDeletionDelta(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingDeltaDeletion delta,
  ) {
    if (!_isActiveTextRange(delta.deletedRange, previousValue.text)) {
      return false;
    }
    return _applyImeDeletionRange(editorCore, delta.deletedRange);
  }

  bool _applyImeDeletionRange(
    core.EditorCore editorCore,
    TextRange deletedRange,
  ) {
    _clearTextInputMarkedDocumentRange();
    final documentText = _getContent();
    final range = _textInputOffsetsToDocumentRange(
      documentText,
      deletedRange.start,
      deletedRange.end,
    );
    return _dispatchImePlainEditAction(editorCore.replaceImeText(range, ''));
  }

  bool _applyImeComposingStateUpdate(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
  ) {
    final composingActive = _isActiveTextRange(value.composing, value.text);
    final previousComposingActive = _isActiveTextRange(
      previousValue.composing,
      previousValue.text,
    );

    if (composingActive) {
      if (previousComposingActive &&
          !_textInputMarkedDocumentRange &&
          !editorCore.isComposing) {
        return false;
      }
      final shouldMarkDocumentRange =
          _textInputMarkedDocumentRange ||
          (!previousComposingActive && !editorCore.isComposing);
      final core.ImeActionResult result;
      if (shouldMarkDocumentRange) {
        result = editorCore.markImeDocumentRange(
          _textInputOffsetsToDocumentRange(
            _getContent(),
            value.composing.start,
            value.composing.end,
          ),
        );
        _setTextInputMarkedDocumentRange(value.composing, result);
      } else {
        result = editorCore.updateImePreedit(
          value.text.substring(value.composing.start, value.composing.end),
        );
        _clearTextInputMarkedDocumentRange();
      }
      return _dispatchImeAction(result);
    }
    if (previousComposingActive || editorCore.isComposing) {
      _clearTextInputMarkedDocumentRange();
      return _dispatchImeAction(editorCore.finishImePreedit());
    }
    if (value.selection != previousValue.selection) {
      _notifyImeSelectionFromTextInput(editorCore, value);
    }
    return false;
  }

  bool _markDocumentRangeForComposingDeltaIfNeeded(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
    int replacedStart,
    int replacedEnd,
    String replacementText,
  ) {
    if (_textInputMarkedDocumentRange ||
        !_isActiveTextRange(value.composing, value.text) ||
        _isActiveTextRange(previousValue.composing, previousValue.text) ||
        editorCore.isComposing) {
      return false;
    }

    final previousRange = _transformTextInputRangeToPreviousValue(
      value.composing,
      replacedStart,
      replacedEnd,
      replacementText,
      previousValue.text,
    );
    if (!_isActiveTextRange(previousRange, previousValue.text)) {
      return false;
    }

    final result = editorCore.markImeDocumentRange(
      _textInputOffsetsToDocumentRange(
        _getContent(),
        previousRange.start,
        previousRange.end,
      ),
    );
    _setTextInputMarkedDocumentRange(previousRange, result);
    return _dispatchImeAction(result);
  }

  bool _markPreviousComposingRangeForTextDeltaIfNeeded(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
  ) {
    if (_textInputMarkedDocumentRange ||
        !_isActiveTextRange(previousValue.composing, previousValue.text) ||
        editorCore.isComposing) {
      return false;
    }

    final result = editorCore.markImeDocumentRange(
      _textInputOffsetsToDocumentRange(
        _getContent(),
        previousValue.composing.start,
        previousValue.composing.end,
      ),
    );
    _setTextInputMarkedDocumentRange(previousValue.composing, result);
    return _dispatchImeAction(result);
  }

  bool _commitMarkedDocumentRangeTextChange(
    core.EditorCore editorCore,
    TextEditingValue previousValue,
    TextEditingValue value,
    int replacedStart,
    int replacedEnd,
    String replacementText,
  ) {
    final plainInputAtCursor =
        replacementText.isNotEmpty &&
        replacementText.length <= 2 &&
        _isReplacementAtCollapsedSelection(
          previousValue.selection,
          replacedStart,
          replacedEnd,
        );
    if (plainInputAtCursor) {
      final documentText = _getContent();
      final range = _textInputOffsetsToDocumentRange(
        documentText,
        replacedStart,
        replacedEnd,
      );
      _clearTextInputMarkedDocumentRange();
      final forceTextInputStateSync = _dispatchImePlainEditAction(
        editorCore.replaceImeText(range, replacementText),
      );
      return forceTextInputStateSync || plainInputAtCursor;
    }

    var committedText = replacementText;
    final rangeSource =
        _isActiveTextRange(previousValue.composing, previousValue.text)
        ? previousValue.composing
        : _isActiveTextRange(value.composing, value.text)
        ? value.composing
        : _textInputMarkedRange;
    if (rangeSource != null &&
        rangeSource.isValid &&
        !rangeSource.isCollapsed) {
      final replacementRange = _transformTextInputRangeByReplacement(
        rangeSource,
        replacedStart,
        replacedEnd,
        replacementText,
        value.text,
      );
      committedText = value.text.substring(
        replacementRange.start,
        replacementRange.end,
      );
    }
    _clearTextInputMarkedDocumentRange();
    return _dispatchImeCommitAction(
      editorCore.commitImeText(committedText),
      committedText,
    );
  }

  void _setTextInputMarkedDocumentRange(
    TextRange range,
    core.ImeActionResult result,
  ) {
    if (result.handled && result.sync.hasPlatformMarkedRange) {
      _textInputMarkedDocumentRange = true;
      _textInputMarkedRange = range;
    } else {
      _clearTextInputMarkedDocumentRange();
    }
  }

  void _clearTextInputMarkedDocumentRange() {
    _textInputMarkedDocumentRange = false;
    _textInputMarkedRange = null;
  }

  bool _shouldCommitPlainLockedDelta(
    TextEditingValue previousValue,
    TextEditingValue value,
    String replacementText,
    int replacedStart,
    int replacedEnd,
  ) {
    if (!_textInputPlainInputLockActive ||
        !_isActiveTextRange(value.composing, value.text) ||
        replacementText.isEmpty ||
        replacementText.length > 2) {
      return false;
    }
    if (previousValue.text.isEmpty) {
      return true;
    }
    if (!_textInputRetainedPlainContextActive ||
        !_isSingleAsciiIdentifierText(replacementText) ||
        !_isReplacementAtCollapsedSelection(
          previousValue.selection,
          replacedStart,
          replacedEnd,
        )) {
      return false;
    }
    final insertedStart = _normalizeTextInputOffset(replacedStart, value.text);
    final insertedEnd = _normalizeTextInputOffset(
      replacedStart + replacementText.length,
      value.text,
    );
    return value.composing.start <= insertedStart &&
        value.composing.end >= insertedEnd;
  }

  void _notifyImeSelectionFromTextInput(
    core.EditorCore editorCore,
    TextEditingValue value,
  ) {
    if (!_isValidSelection(value.selection, value.text)) {
      return;
    }
    final documentText = _getContent();
    final start = _textInputOffsetToDocumentPosition(
      documentText,
      value.selection.start,
    );
    final end = _textInputOffsetToDocumentPosition(
      documentText,
      value.selection.end,
    );
    final result = value.selection.isCollapsed
        ? editorCore.notifyImeCursorChanged(end)
        : editorCore.notifyImeSelectionChanged(core.TextRange(start, end));
    _dispatchImeAction(result);
  }

  bool _dispatchImeAction(core.ImeActionResult result) {
    final plainInputLockBefore = _textInputPlainInputLockActive;
    final retainedPlainContextBefore = _textInputRetainedPlainContextActive;
    _interactionController.dispatchImeActionResult(result);
    if (result.sync.clearPlatformPreedit &&
        result.sync.contextPolicy == core.ImeContextPolicy.none) {
      _textInputPlainInputLockActive = true;
      _textInputRetainedPlainContextActive = false;
    } else if (result.sync.contextPolicy != core.ImeContextPolicy.none) {
      _textInputPlainInputLockActive = false;
      _textInputRetainedPlainContextActive = false;
    }
    _debugImeTrace(
      () =>
          'imeAction ${_debugImeActionResult(result)} '
          'plainLock=$plainInputLockBefore->$_textInputPlainInputLockActive '
          'retainedPlainContext=$retainedPlainContextBefore->$_textInputRetainedPlainContextActive',
    );
    return result.sync.clearPlatformPreedit;
  }

  bool _dispatchImeCommitAction(
    core.ImeActionResult result,
    String committedText,
  ) {
    final clearPlatformPreedit = _dispatchImeAction(result);
    _retainPlainTextInputContextAfterCommit(result, committedText);
    return clearPlatformPreedit;
  }

  bool _dispatchImePlainEditAction(core.ImeActionResult result) {
    final clearPlatformPreedit = _dispatchImeAction(result);
    _retainPlainTextInputContextAfterPlainEdit(result);
    return clearPlatformPreedit;
  }

  void _retainPlainTextInputContextAfterCommit(
    core.ImeActionResult result,
    String committedText,
  ) {
    if (!_platformBehavior.retainsPlainTextInputContextAfterPreeditClear ||
        !result.sync.clearPlatformPreedit ||
        result.sync.contextPolicy != core.ImeContextPolicy.none ||
        !_isSingleAsciiIdentifierText(committedText)) {
      return;
    }
    _retainPlainTextInputContextAfterPlainEdit(result);
  }

  void _retainPlainTextInputContextAfterPlainEdit(core.ImeActionResult result) {
    if (!_platformBehavior.retainsPlainTextInputContextAfterPreeditClear ||
        !result.sync.clearPlatformPreedit ||
        result.sync.contextPolicy != core.ImeContextPolicy.none) {
      return;
    }
    final documentText = _getContent();
    final lineContext = _lineTextInputContext(documentText, result.sync.cursor);
    if (lineContext == null ||
        !_isMidAsciiIdentifierTextInputOffset(lineContext.$1, lineContext.$3)) {
      return;
    }
    _textInputRetainedPlainContextActive = true;
    _debugImeTrace(
      () =>
          'retainPlainContext start=${lineContext.$2} '
          'cursor=${lineContext.$3} text=${_debugString(lineContext.$1)}',
    );
  }

  (String, int, int)? _buildRetainedPlainTextInputContext(
    core.ImeSyncSnapshot snapshot,
    String documentText,
  ) {
    if (!_textInputRetainedPlainContextActive ||
        !_platformBehavior.retainsPlainTextInputContextAfterPreeditClear) {
      return null;
    }
    if (snapshot.contextPolicy != core.ImeContextPolicy.none ||
        !snapshot.clearPlatformPreedit ||
        snapshot.hasComposingSession ||
        snapshot.hasPlatformMarkedRange) {
      _textInputRetainedPlainContextActive = false;
      return null;
    }
    final lineContext = _lineTextInputContext(documentText, snapshot.cursor);
    if (lineContext == null ||
        !_isMidAsciiIdentifierTextInputOffset(lineContext.$1, lineContext.$3)) {
      _textInputRetainedPlainContextActive = false;
      return null;
    }
    return lineContext;
  }

  void _debugImeTrace(String Function() messageBuilder) {
    if (!kDebugMode || !_debugImeDeltaTraceEnabled) {
      return;
    }
    debugPrint('[SweetEditorIME] ${messageBuilder()}');
  }

  String _debugTextEditingDelta(TextEditingDelta delta) {
    final base =
        'old=${_debugString(delta.oldText)} '
        'selection=${_debugSelection(delta.selection)} '
        'composing=${_debugTextRange(delta.composing)}';
    if (delta is TextEditingDeltaInsertion) {
      return 'Insertion(offset=${delta.insertionOffset}, '
          'text=${_debugString(delta.textInserted)}, $base)';
    }
    if (delta is TextEditingDeltaDeletion) {
      return 'Deletion(range=${_debugTextRange(delta.deletedRange)}, $base)';
    }
    if (delta is TextEditingDeltaReplacement) {
      return 'Replacement(range=${_debugTextRange(delta.replacedRange)}, '
          'text=${_debugString(delta.replacementText)}, $base)';
    }
    if (delta is TextEditingDeltaNonTextUpdate) {
      return 'NonTextUpdate($base)';
    }
    return '${delta.runtimeType}($base)';
  }

  String _debugTextEditingValue(TextEditingValue value) {
    return 'text=${_debugString(value.text)} '
        'selection=${_debugSelection(value.selection)} '
        'composing=${_debugTextRange(value.composing)}';
  }

  String _debugImeActionResult(core.ImeActionResult result) {
    final sync = result.sync;
    return 'handled=${result.handled} '
        'content=${result.contentChanged} '
        'cursor=${result.cursorChanged} '
        'selection=${result.selectionChanged} '
        'syncContext=${sync.contextPolicy} '
        'syncClear=${sync.clearPlatformPreedit} '
        'syncComposing=${sync.hasComposingSession} '
        'syncVisible=${sync.hasVisibleCompositionRange} '
        'syncMarked=${sync.hasPlatformMarkedRange} '
        'windowStart=${sync.platformTextWindowStartOffset} '
        'windowSelection=${sync.platformTextWindowSelectionStartOffset}:'
        '${sync.platformTextWindowSelectionEndOffset} '
        'windowComposing=${sync.platformTextWindowComposingStartOffset}:'
        '${sync.platformTextWindowComposingEndOffset} '
        'windowText=${_debugString(sync.platformTextWindowText)}';
  }

  String _debugSelection(TextSelection selection) {
    if (!selection.isValid) {
      return 'invalid(${selection.baseOffset}:${selection.extentOffset})';
    }
    return '${selection.baseOffset}:${selection.extentOffset}';
  }

  String _debugTextRange(TextRange range) {
    if (!range.isValid) {
      return 'invalid(${range.start}:${range.end})';
    }
    return '${range.start}:${range.end}';
  }

  String _debugString(String value) {
    final escaped = value
        .replaceAll('\r', r'\r')
        .replaceAll('\n', r'\n')
        .replaceAll('\t', r'\t');
    if (escaped.length <= 120) {
      return '"$escaped"';
    }
    return '"${escaped.substring(0, 120)}"...(${value.length})';
  }

  (String, int, int)? _lineTextInputContext(
    String documentText,
    core.TextPosition cursor,
  ) {
    var line = 0;
    var index = 0;
    var logicalOffset = 0;
    var lineStartIndex = 0;
    var lineStartOffset = 0;
    while (index < documentText.length && line < cursor.line) {
      final codeUnit = documentText.codeUnitAt(index++);
      if (codeUnit == 0x0D) {
        if (index < documentText.length &&
            documentText.codeUnitAt(index) == 0x0A) {
          index++;
        }
        line++;
        logicalOffset++;
        lineStartIndex = index;
        lineStartOffset = logicalOffset;
      } else if (codeUnit == 0x0A) {
        line++;
        logicalOffset++;
        lineStartIndex = index;
        lineStartOffset = logicalOffset;
      } else {
        logicalOffset++;
      }
    }
    if (line != cursor.line) {
      return null;
    }
    var lineEndIndex = lineStartIndex;
    while (lineEndIndex < documentText.length) {
      final codeUnit = documentText.codeUnitAt(lineEndIndex);
      if (codeUnit == 0x0D || codeUnit == 0x0A) {
        break;
      }
      lineEndIndex++;
    }
    final lineText = documentText.substring(lineStartIndex, lineEndIndex);
    final cursorOffset = _normalizeTextInputOffset(cursor.column, lineText);
    return (lineText, lineStartOffset, cursorOffset);
  }

  bool _isMidAsciiIdentifierTextInputOffset(String text, int offset) {
    return offset > 0 &&
        offset < text.length &&
        _isAsciiIdentifierCodeUnit(text.codeUnitAt(offset - 1)) &&
        _isAsciiIdentifierCodeUnit(text.codeUnitAt(offset));
  }

  bool _isSingleAsciiIdentifierText(String text) {
    return text.length == 1 && _isAsciiIdentifierCodeUnit(text.codeUnitAt(0));
  }

  bool _isAsciiIdentifierCodeUnit(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        codeUnit == 0x5F ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A);
  }

  bool _isActiveTextRange(TextRange range, String text) {
    return range.isValid &&
        !range.isCollapsed &&
        range.start >= 0 &&
        range.end <= text.length;
  }

  bool _isValidSelection(TextSelection selection, String text) {
    return selection.isValid &&
        selection.start >= 0 &&
        selection.end >= 0 &&
        selection.start <= text.length &&
        selection.end <= text.length;
  }

  bool _isReplacementAtCollapsedSelection(
    TextSelection selection,
    int replacementStart,
    int replacementEnd,
  ) {
    return selection.isValid &&
        selection.isCollapsed &&
        selection.extentOffset == replacementStart &&
        selection.extentOffset == replacementEnd;
  }

  int _normalizeTextInputOffset(int offset, String text) {
    return math.max(0, math.min(offset, text.length));
  }

  int _normalizeDocumentOffset(int offset, String documentText) {
    return math.max(0, math.min(offset, _logicalDocumentLength(documentText)));
  }

  int _logicalDocumentLength(String text) {
    var length = 0;
    var index = 0;
    while (index < text.length) {
      final codeUnit = text.codeUnitAt(index++);
      if (codeUnit == 0x0D &&
          index < text.length &&
          text.codeUnitAt(index) == 0x0A) {
        index++;
      }
      length++;
    }
    return length;
  }

  core.TextPosition _textInputOffsetToDocumentPosition(
    String documentText,
    int localOffset,
  ) {
    final documentOffset = _normalizeDocumentOffset(
      _textInputWindowStartOffset + localOffset,
      documentText,
    );
    return _offsetToTextPosition(documentText, documentOffset);
  }

  core.TextRange _textInputOffsetsToDocumentRange(
    String documentText,
    int localStart,
    int localEnd,
  ) {
    return core.TextRange(
      _textInputOffsetToDocumentPosition(documentText, localStart),
      _textInputOffsetToDocumentPosition(documentText, localEnd),
    );
  }

  (int, int, String) _computeTextReplacement(String oldText, String newText) {
    var prefix = 0;
    final maxPrefix = math.min(oldText.length, newText.length);
    while (prefix < maxPrefix &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }

    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }

    return (prefix, oldSuffix, newText.substring(prefix, newSuffix));
  }

  TextRange _transformTextInputRangeToPreviousValue(
    TextRange range,
    int replacedStart,
    int replacedEnd,
    String replacement,
    String previousText,
  ) {
    final normalizedStart = _normalizeTextInputOffset(
      math.min(replacedStart, replacedEnd),
      previousText,
    );
    final normalizedEnd = _normalizeTextInputOffset(
      math.max(replacedStart, replacedEnd),
      previousText,
    );
    final insertedEnd = normalizedStart + replacement.length;
    int start;
    int end;
    if (range.end <= normalizedStart) {
      start = range.start;
      end = range.end;
    } else if (range.start >= insertedEnd) {
      final replacementDelta =
          normalizedEnd - normalizedStart - replacement.length;
      start = range.start + replacementDelta;
      end = range.end + replacementDelta;
    } else {
      start = range.start < normalizedStart ? range.start : normalizedStart;
      final unchangedTail = range.end > insertedEnd
          ? range.end - insertedEnd
          : 0;
      end = normalizedEnd + unchangedTail;
    }
    start = _normalizeTextInputOffset(start, previousText);
    end = _normalizeTextInputOffset(end, previousText);
    if (end < start) {
      return TextRange(start: end, end: start);
    }
    return TextRange(start: start, end: end);
  }

  TextRange _transformTextInputRangeByReplacement(
    TextRange range,
    int replacedStart,
    int replacedEnd,
    String replacement,
    String text,
  ) {
    final replacedLength = replacedEnd > replacedStart
        ? replacedEnd - replacedStart
        : 0;
    final replacementDelta = replacement.length - replacedLength;
    int start;
    int end;
    if (replacedEnd < range.start) {
      start = range.start + replacementDelta;
      end = range.end + replacementDelta;
    } else if (replacedStart > range.end) {
      start = range.start;
      end = range.end;
    } else {
      start = range.start < replacedStart ? range.start : replacedStart;
      final unchangedTail = range.end > replacedEnd
          ? range.end - replacedEnd
          : 0;
      end = replacedStart + replacement.length + unchangedTail;
    }
    start = _normalizeTextInputOffset(start, text);
    end = _normalizeTextInputOffset(end, text);
    if (end < start) {
      return TextRange(start: end, end: start);
    }
    return TextRange(start: start, end: end);
  }

  int _textPositionToOffset(String text, core.TextPosition position) {
    var line = 0;
    var index = 0;
    var offset = 0;
    while (line < position.line && index < text.length) {
      final codeUnit = text.codeUnitAt(index++);
      if (codeUnit == 0x0D) {
        if (index < text.length && text.codeUnitAt(index) == 0x0A) {
          index++;
        }
        line++;
        offset++;
      } else if (codeUnit == 0x0A) {
        line++;
        offset++;
      } else {
        offset++;
      }
    }
    return _normalizeDocumentOffset(offset + position.column, text);
  }

  core.TextPosition _offsetToTextPosition(String text, int offset) {
    final clampedOffset = _normalizeDocumentOffset(offset, text);
    var line = 0;
    var column = 0;
    var index = 0;
    var logicalOffset = 0;
    while (index < text.length && logicalOffset < clampedOffset) {
      final codeUnit = text.codeUnitAt(index++);
      if (codeUnit == 0x0D) {
        if (index < text.length && text.codeUnitAt(index) == 0x0A) {
          index++;
        }
        line++;
        column = 0;
        logicalOffset++;
      } else if (codeUnit == 0x0A) {
        line++;
        column = 0;
        logicalOffset++;
      } else {
        column++;
        logicalOffset++;
      }
    }
    return core.TextPosition(line, column);
  }

  void _handleGestureInputResult(core.GestureResult? result) {
    if (_editorResourcesReleased) return;
    if (result == null) return;
    if (result.type != core.GestureType.tap) {
      _pendingShowTextInput = false;
      return;
    }

    final shouldShowKeyboard =
        _platformBehavior.showsSoftKeyboard &&
        result.hitTarget.type == core.HitTargetType.none;
    if (!_focusNode.hasFocus) {
      _pendingShowTextInput = shouldShowKeyboard;
      _focusNode.requestFocus();
      return;
    }

    _pendingShowTextInput = false;
    if (shouldShowKeyboard) {
      _openTextInputConnection(show: true);
    }
  }

  MouseCursor _resolveMouseCursor() {
    if (_editorResourcesReleased || !_platformBehavior.usesMouseCursor) {
      return SystemMouseCursors.basic;
    }
    switch (_pointerCursorType) {
      case core.PointerCursorType.default_:
        return SystemMouseCursors.basic;
      case core.PointerCursorType.text:
        return SystemMouseCursors.text;
      case core.PointerCursorType.hand:
        return SystemMouseCursors.click;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      canRequestFocus: !_editorResourcesReleased,
      skipTraversal: _editorResourcesReleased,
      onKeyEvent: _editorResourcesReleased
          ? (_, _) => KeyEventResult.ignored
          : _interactionController.handleKeyEvent,
      child: IgnorePointer(
        ignoring: _editorResourcesReleased,
        child: MouseRegion(
          cursor: _resolveMouseCursor(),
          onExit: (event) => _interactionController.onPointerExit(event),
          child: Listener(
            onPointerDown: _interactionController.onPointerDown,
            onPointerMove: _interactionController.onPointerMove,
            onPointerHover: _interactionController.onPointerHover,
            onPointerUp: (event) {
              final result = _interactionController.onPointerUp(event);
              _handleGestureInputResult(result);
            },
            onPointerCancel: _interactionController.onPointerCancel,
            onPointerSignal: _interactionController.onPointerSignal,
            onPointerPanZoomStart: _interactionController.onPointerPanZoomStart,
            onPointerPanZoomUpdate:
                _interactionController.onPointerPanZoomUpdate,
            onPointerPanZoomEnd: _interactionController.onPointerPanZoomEnd,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final newSize = constraints.biggest;
                if (newSize != _session.viewportSize &&
                    newSize.width > 0 &&
                    newSize.height > 0) {
                  _scheduleViewportUpdate(newSize);
                }

                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _overlayCoordinator.overlayListenable,
                    builder: (context, child) {
                      final completionOverlay =
                          _overlayCoordinator.completionOverlay.value.data;
                      final inlineSuggestionOverlay = _overlayCoordinator
                          .inlineSuggestionOverlay
                          .value
                          .data;
                      final selectionMenuOverlay =
                          _overlayCoordinator.selectionMenuOverlay.value.data;

                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(child: child!),
                          if (completionOverlay != null)
                            CompletionPopupWidget(
                              items: completionOverlay.items,
                              selectedIndex: completionOverlay.selectedIndex,
                              position: completionOverlay.position,
                              themeColors:
                                  _completionPopupController.themeColors,
                              viewportSize: newSize,
                              onItemTap: (index) =>
                                  _completionPopupController.confirmItem(index),
                            ),
                          if (inlineSuggestionOverlay != null)
                            InlineSuggestionBarWidget(
                              x: inlineSuggestionOverlay.x,
                              y: inlineSuggestionOverlay.y,
                              cursorHeight:
                                  inlineSuggestionOverlay.cursorHeight,
                              theme: _theme,
                              onAccept: () =>
                                  _inlineSuggestionController.accept(),
                              onDismiss: () =>
                                  _inlineSuggestionController.dismiss(),
                            ),
                          if (selectionMenuOverlay != null &&
                              selectionMenuOverlay.items.isNotEmpty)
                            SelectionMenuWidget(
                              position: _overlayCoordinator
                                  .computeSelectionMenuPosition(
                                    newSize,
                                    selectionMenuOverlay.items,
                                  ),
                              items: selectionMenuOverlay.items,
                              bgColor: _theme.completionBgColor,
                              textColor: _theme.completionLabelColor,
                              onItemTap:
                                  _interactionController.onSelectionMenuItemTap,
                            ),
                        ],
                      );
                    },
                    child: SizedBox.expand(
                      key: _editorKey,
                      child: CustomPaint(size: newSize, painter: _painter),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
