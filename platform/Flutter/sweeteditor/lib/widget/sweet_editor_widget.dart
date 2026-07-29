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
    this.fontSize,
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
  final double? fontSize;
  final bool autofocus;

  @override
  State<SweetEditorWidget> createState() => _SweetEditorWidgetState();
}

class _SweetEditorWidgetState extends State<SweetEditorWidget>
    with TickerProviderStateMixin, DeltaTextInputClient {
  late EditorSession _session;
  late EditorOverlayCoordinator _overlayCoordinator;
  late EditorInteractionController _interactionController;
  late final EditorPlatformBehavior _platformBehavior;
  late final FocusNode _focusNode;
  final GlobalKey _editorKey = GlobalKey();
  TextInputConnection? _textInputConnection;
  TextEditingValue _textEditingValue = TextEditingValue.empty;
  int _imeSessionId = 0;
  int _imeStateRevision = 0;
  bool _imeSessionRebindScheduled = false;
  bool _pendingShowTextInput = false;
  Size? _pendingViewportSize;
  bool _viewportUpdateScheduled = false;
  bool _editorResourcesReleased = false;
  bool _pendingDocumentLoadedNotification = false;
  Ticker? _animationTicker;
  Timer? _animationDelayTimer;
  core.PointerCursorType _pointerCursorType = core.PointerCursorType.text;

  EditorEventBus get _eventBus => widget.controller._eventBus;

  double get _resolvedFontSize {
    final configuredSize = widget.fontSize;
    if (configuredSize != null) return configuredSize;
    final pixelRatio =
        WidgetsBinding
            .instance
            .platformDispatcher
            .implicitView
            ?.devicePixelRatio ??
        1.0;
    return 28.0 / (pixelRatio.isFinite && pixelRatio > 0 ? pixelRatio : 1.0);
  }

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
      fontSize: _resolvedFontSize,
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
    _session.bindSettings();
    _applyDeclarativeInputs();
    widget.controller._attach(this);
    _interactionController.startCursorBlink();
  }

  void _initSubsystems() {
    _session = EditorSession(
      eventBus: _eventBus,
      hostCallbacks: EditorSessionHostCallbacks(
        onRenderModelUpdated: _handleRenderModelUpdated,
        onTextInputStyleInvalidated: _updateTextInputStyle,
        onHostActionResult: _handleEditorActionResult,
        onAnimationScheduleChanged: _setAnimationSchedule,
      ),
      theme: widget.theme ?? EditorTheme.dark(),
      initialSettings: widget.settings,
      fontFamily: widget.fontFamily,
      fontSize: _resolvedFontSize,
      gutterSticky: _platformBehavior.gutterStickyDefault,
      platformBehavior: _platformBehavior,
      initialKeyMap: widget.keyMap ?? EditorKeyMap.defaultKeyMap(),
      initialIconProvider: widget.iconProvider,
      initialLanguageConfiguration: widget.languageConfiguration,
      initialMetadata: widget.metadata,
    );

    _overlayCoordinator = EditorOverlayCoordinator(session: _session);
    _interactionController = EditorInteractionController(session: _session);

    _session.completionPopupController.setConfirmHandler(
      _interactionController.onCompletionItemConfirmed,
    );
  }

  void _handleRenderModelUpdated(core.EditorRenderModel model) {
    final pointerCursorChanged = model.pointerCursorType != _pointerCursorType;
    _pointerCursorType = model.pointerCursorType;
    _overlayCoordinator.onRenderModelUpdated(model);
    _updateTextInputGeometry();
    if (pointerCursorChanged && mounted) {
      setState(() {});
    }
    _dispatchPendingDocumentLoaded();
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
    _pendingDocumentLoadedNotification = true;
  }

  void _dispatchPendingDocumentLoaded() {
    if (!_pendingDocumentLoadedNotification || !mounted) return;
    _pendingDocumentLoadedNotification = false;
    _session.decorationProviderManager.onDocumentLoaded();
    _eventBus.publish(DocumentLoadedEvent());
  }

  void _flush() {
    if (!mounted) return;
    _session.requestFlush();
  }

  void _setAnimationSchedule(int? delayMs) {
    if (_editorResourcesReleased) return;
    _animationDelayTimer?.cancel();
    _animationDelayTimer = null;
    if (delayMs == null) {
      _animationTicker?.stop();
      return;
    }

    if (delayMs <= 0) {
      _animationTicker ??= createTicker(_onAnimationTick);
      if (!_animationTicker!.isActive) {
        _animationTicker!.start();
      }
      return;
    }

    _animationTicker?.stop();
    _animationDelayTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_editorResourcesReleased) return;
      _session.tickAnimations();
    });
  }

  void _onAnimationTick(Duration elapsed) {
    if (_editorResourcesReleased) return;
    _session.tickAnimations();
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
      }
    });
  }

  void _applyTheme(EditorTheme theme) {
    _session.applyTheme(theme);
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
    _session.decorationProviderManager.requestRefresh();
  }

  void _applyMetadata(EditorMetadata? metadata) {
    _session.applyMetadata(metadata);
  }

  void _releaseEditorResources() {
    if (_editorResourcesReleased) return;
    _setAnimationSchedule(null);
    _editorResourcesReleased = true;
    _animationTicker?.dispose();
    _animationTicker = null;
    _interactionController.dispose();
    _overlayCoordinator.dispose();
    widget.controller._detach();
    _session.dispose();
  }

  @override
  TextEditingValue? get currentTextEditingValue => _textEditingValue;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValue(TextEditingValue value) {
    if (_platformBehavior.usesDeltaTextInputModel) {
      if (value != _textEditingValue) {
        _recoverFromTextInputProtocolError();
      }
      return;
    }
    if (value == _textEditingValue ||
        _isAffinityOnlyEditingValueUpdate(_textEditingValue, value)) {
      return;
    }

    final previousValue = _textEditingValue;
    final replacement = _minimalTextReplacement(previousValue.text, value.text);
    final step = core.ImeTextUpdateStep(
      oldText: previousValue.text,
      patchRange: replacement == null
          ? const core.ImeOffsetRange()
          : core.ImeOffsetRange(
              coordinateSpace: core.ImeCoordinateSpace.editingBuffer,
              startUtf16: replacement.range.start,
              endUtf16: replacement.range.end,
            ),
      replacementText: replacement?.text ?? '',
      selectionAfter: _imeSelectionFromFlutter(value.selection, value.text),
      compositionAfter: _imeCompositionFromFlutter(value.composing, value.text),
    );
    _applyImeTextUpdateSteps([step], value);
  }

  ({TextRange range, String text})? _minimalTextReplacement(
    String oldText,
    String newText,
  ) {
    if (oldText == newText) {
      return null;
    }

    final sharedLength = math.min(oldText.length, newText.length);
    var start = 0;
    while (start < sharedLength &&
        oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
      start++;
    }
    if (_isUtf16SurrogateBoundary(oldText, start) ||
        _isUtf16SurrogateBoundary(newText, start)) {
      start--;
    }

    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > start &&
        newEnd > start &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    if (_isUtf16SurrogateBoundary(oldText, oldEnd)) {
      oldEnd++;
    }
    if (_isUtf16SurrogateBoundary(newText, newEnd)) {
      newEnd++;
    }

    return (
      range: TextRange(start: start, end: oldEnd),
      text: newText.substring(start, newEnd),
    );
  }

  bool _isUtf16SurrogateBoundary(String text, int offset) {
    if (offset <= 0 || offset >= text.length) {
      return false;
    }
    final previous = text.codeUnitAt(offset - 1);
    final next = text.codeUnitAt(offset);
    return previous >= 0xD800 &&
        previous <= 0xDBFF &&
        next >= 0xDC00 &&
        next <= 0xDFFF;
  }

  bool _isAffinityOnlyEditingValueUpdate(
    TextEditingValue before,
    TextEditingValue after,
  ) {
    return before.text == after.text &&
        before.selection.baseOffset == after.selection.baseOffset &&
        before.selection.extentOffset == after.selection.extentOffset &&
        before.selection.affinity != after.selection.affinity &&
        before.composing == after.composing;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (textEditingDeltas.isEmpty) {
      return;
    }

    var probedValue = _textEditingValue;
    final steps = <core.ImeTextUpdateStep>[];
    for (final delta in textEditingDeltas) {
      if (delta.oldText != probedValue.text) {
        _recoverFromTextInputProtocolError();
        return;
      }
      final appliedValue = delta.apply(probedValue);
      if (!_isAffinityOnlyUpdate(delta, probedValue, appliedValue)) {
        steps.add(
          core.ImeTextUpdateStep(
            oldText: delta.oldText,
            patchRange: _patchRangeFromDelta(delta),
            replacementText: _replacementTextFromDelta(delta),
            selectionAfter: _imeSelectionFromFlutter(
              appliedValue.selection,
              appliedValue.text,
            ),
            compositionAfter: _imeCompositionFromFlutter(
              appliedValue.composing,
              appliedValue.text,
            ),
          ),
        );
      }
      probedValue = appliedValue;
    }

    if (steps.isEmpty) {
      return;
    }

    _applyImeTextUpdateSteps(steps, probedValue);
  }

  bool _applyImeTextUpdateSteps(
    List<core.ImeTextUpdateStep> steps,
    TextEditingValue platformValue,
  ) {
    final editorCore = _session.editorCore;
    final sessionId = _imeSessionId;
    if (editorCore == null || sessionId == 0 || steps.isEmpty) {
      return false;
    }
    final result = editorCore.applyImeTextUpdates(
      core.ImeTextUpdateBatch(
        sessionId: sessionId,
        expectedStateRevision: _imeStateRevision,
        steps: steps,
      ),
    );
    final state = result.imeState;
    final acceptedPlatformValue =
        (result.imeHostAction == core.ImeHostAction.none ||
            result.imeHostAction == core.ImeHostAction.syncEditingState) &&
        state.resultCode == core.ImeResultCode.ok &&
        state.sessionId == sessionId &&
        _imeSessionId == sessionId;
    if (acceptedPlatformValue) {
      // The platform has already applied this editing state, so Core syncs should only
      // write back when the authoritative state actually differs.
      _textEditingValue = platformValue;
      _imeStateRevision = state.stateRevision;
    }
    _dispatchEditorActionResult(result);
    return acceptedPlatformValue;
  }

  core.ImeOffsetRange _patchRangeFromDelta(TextEditingDelta delta) {
    if (delta is TextEditingDeltaInsertion) {
      return core.ImeOffsetRange(
        coordinateSpace: core.ImeCoordinateSpace.editingBuffer,
        startUtf16: delta.insertionOffset,
        endUtf16: delta.insertionOffset,
      );
    }
    if (delta is TextEditingDeltaDeletion) {
      return core.ImeOffsetRange(
        coordinateSpace: core.ImeCoordinateSpace.editingBuffer,
        startUtf16: delta.deletedRange.start,
        endUtf16: delta.deletedRange.end,
      );
    }
    if (delta is TextEditingDeltaReplacement) {
      return core.ImeOffsetRange(
        coordinateSpace: core.ImeCoordinateSpace.editingBuffer,
        startUtf16: delta.replacedRange.start,
        endUtf16: delta.replacedRange.end,
      );
    }
    return const core.ImeOffsetRange();
  }

  String _replacementTextFromDelta(TextEditingDelta delta) {
    if (delta is TextEditingDeltaInsertion) {
      return delta.textInserted;
    }
    if (delta is TextEditingDeltaReplacement) {
      return delta.replacementText;
    }
    return '';
  }

  core.ImeSelection _imeSelectionFromFlutter(
    TextSelection selection,
    String text,
  ) {
    if (!_isValidSelection(selection, text)) {
      return const core.ImeSelection();
    }
    final affinity = selection.isCollapsed
        ? _imeAffinityFromFlutter(selection.affinity)
        : selection.extentOffset < selection.baseOffset
        ? core.CaretAffinity.downstream
        : core.CaretAffinity.upstream;
    return core.ImeSelection(
      coordinateSpace: core.ImeCoordinateSpace.editingBuffer,
      anchorUtf16: selection.baseOffset,
      activeUtf16: selection.extentOffset,
      affinity: affinity,
    );
  }

  core.ImeOffsetRange _imeCompositionFromFlutter(
    TextRange composing,
    String text,
  ) {
    if (!_isValidTextRange(composing, text) || composing.isCollapsed) {
      return const core.ImeOffsetRange();
    }
    return core.ImeOffsetRange(
      coordinateSpace: core.ImeCoordinateSpace.editingBuffer,
      startUtf16: composing.start,
      endUtf16: composing.end,
    );
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
    final connection = _textInputConnection;
    if (connection == null) {
      return;
    }
    connection.connectionClosedReceived();
    _textInputConnection = null;
    _finishLocalImeSession();
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
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
      inputAction: _platformBehavior.usesTextInputNewlineAction
          ? TextInputAction.newline
          : TextInputAction.none,
      readOnly: _session.settings.isReadOnly(),
      autocorrect: true,
      enableSuggestions: true,
      enableDeltaModel: _platformBehavior.usesDeltaTextInputModel,
    );
    if (_textInputConnection?.attached ?? false) {
      final needsSessionBinding = _imeSessionId == 0;
      if (needsSessionBinding && !_beginLocalImeSession()) {
        _closeTextInputConnection(endSession: false);
        return;
      }
      _textInputConnection!.updateConfig(configuration);
      _updateTextInputStyle();
      if (needsSessionBinding) {
        _textInputConnection!.setEditingState(_textEditingValue);
      }
      _updateTextInputGeometry();
      if (show || !_platformBehavior.showsSoftKeyboard) {
        _textInputConnection!.show();
      }
      return;
    }

    if (!_beginLocalImeSession()) {
      return;
    }

    try {
      _textInputConnection = TextInput.attach(this, configuration);
      _updateTextInputStyle();
      _textInputConnection!.setEditingState(_textEditingValue);
      _updateTextInputGeometry();
      if (show || !_platformBehavior.showsSoftKeyboard) {
        _textInputConnection!.show();
      }
    } catch (_) {
      _textInputConnection?.close();
      _textInputConnection = null;
      _finishLocalImeSession();
      rethrow;
    }
  }

  bool _beginLocalImeSession() {
    if (_imeSessionId != 0) {
      return true;
    }
    final editorCore = _session.editorCore;
    if (editorCore == null) {
      return false;
    }
    final state = editorCore.beginImeSession(core.ImeMutationModel.textUpdate);
    if (state.resultCode != core.ImeResultCode.ok || state.sessionId == 0) {
      return false;
    }
    final context = editorCore.getImeContext(
      state.sessionId,
      core.ImeTextSource.editingBuffer,
      0,
      -1,
    );
    final value = _buildEditingValueFromContext(context);
    if (value == null) {
      _dispatchEditorActionResult(editorCore.endImeSession(state.sessionId));
      return false;
    }
    _imeSessionId = state.sessionId;
    _imeStateRevision = state.stateRevision;
    _textEditingValue = value;
    return true;
  }

  void _closeTextInputConnection({bool endSession = true}) {
    _textInputConnection?.close();
    _textInputConnection = null;
    if (endSession) {
      _finishLocalImeSession();
    } else {
      _clearLocalImeSession();
    }
  }

  void _finishLocalImeSession() {
    final sessionId = _imeSessionId;
    _clearLocalImeSession();
    final editorCore = _session.editorCore;
    if (sessionId != 0 && editorCore != null) {
      _dispatchEditorActionResult(editorCore.endImeSession(sessionId));
    }
  }

  void _clearLocalImeSession() {
    _imeSessionId = 0;
    _imeStateRevision = 0;
    _textEditingValue = TextEditingValue.empty;
  }

  void _updateTextInputStyle() {
    if (!(_textInputConnection?.attached ?? false)) {
      return;
    }
    _textInputConnection!.setStyle(
      fontFamily: _session.effectiveFontFamily,
      fontSize: _session.settings.getEditorTextSize() * _session.effectiveScale,
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

  TextEditingValue? _buildEditingValueFromContext(core.ImeTextContext context) {
    if (context.resultCode != core.ImeResultCode.ok ||
        context.selection.coordinateSpace !=
            core.ImeCoordinateSpace.contextSlice ||
        !_isValidImeSelection(context.selection, context.text)) {
      return null;
    }
    final selection = TextSelection(
      baseOffset: context.selection.anchorUtf16,
      extentOffset: context.selection.activeUtf16,
      affinity: _flutterAffinityFromIme(context.selection.affinity),
    );
    final range = context.compositionRange;
    final composing = range.startUtf16 == -1 && range.endUtf16 == -1
        ? TextRange.empty
        : range.coordinateSpace == core.ImeCoordinateSpace.contextSlice &&
              _isValidImeRange(range, context.text)
        ? TextRange(start: range.startUtf16, end: range.endUtf16)
        : null;
    if (composing == null) {
      return null;
    }
    return TextEditingValue(
      text: context.text,
      selection: selection,
      composing: composing,
    );
  }

  bool _isValidImeSelection(core.ImeSelection selection, String text) {
    return selection.anchorUtf16 >= 0 &&
        selection.activeUtf16 >= 0 &&
        selection.anchorUtf16 <= text.length &&
        selection.activeUtf16 <= text.length;
  }

  bool _isValidImeRange(core.ImeOffsetRange range, String text) {
    return range.startUtf16 >= 0 &&
        range.endUtf16 >= range.startUtf16 &&
        range.endUtf16 <= text.length;
  }

  bool _isValidTextRange(TextRange range, String text) {
    return range.isValid &&
        range.start >= 0 &&
        range.end >= range.start &&
        range.end <= text.length;
  }

  bool _isValidSelection(TextSelection selection, String text) {
    return selection.isValid &&
        selection.start >= 0 &&
        selection.end >= 0 &&
        selection.start <= text.length &&
        selection.end <= text.length;
  }

  core.CaretAffinity _imeAffinityFromFlutter(TextAffinity affinity) {
    return affinity == TextAffinity.upstream
        ? core.CaretAffinity.upstream
        : core.CaretAffinity.downstream;
  }

  TextAffinity _flutterAffinityFromIme(core.CaretAffinity affinity) {
    return affinity == core.CaretAffinity.upstream
        ? TextAffinity.upstream
        : TextAffinity.downstream;
  }

  bool _isAffinityOnlyUpdate(
    TextEditingDelta delta,
    TextEditingValue before,
    TextEditingValue after,
  ) {
    return delta is TextEditingDeltaNonTextUpdate &&
        before.text == after.text &&
        before.selection.baseOffset == after.selection.baseOffset &&
        before.selection.extentOffset == after.selection.extentOffset &&
        before.selection.affinity != after.selection.affinity &&
        before.composing == after.composing;
  }

  void _recoverFromTextInputProtocolError() {
    _finishLocalImeSession();
    _scheduleImeSessionRebind();
  }

  void _handleImeHostAction(core.EditorActionResult result) {
    final action = result.imeHostAction;
    if (action == core.ImeHostAction.none) {
      return;
    }
    if (action == core.ImeHostAction.syncEditingState) {
      final editorCore = _session.editorCore;
      final state = result.imeState;
      if (editorCore == null ||
          _textInputConnection == null ||
          state.resultCode != core.ImeResultCode.ok ||
          state.sessionId == 0 ||
          state.sessionId != _imeSessionId) {
        _recoverFromTextInputProtocolError();
        return;
      }
      final context = editorCore.getImeContext(
        state.sessionId,
        core.ImeTextSource.editingBuffer,
        0,
        -1,
      );
      final value = _buildEditingValueFromContext(context);
      if (value == null) {
        _recoverFromTextInputProtocolError();
        return;
      }
      final changed = value != _textEditingValue;
      _textEditingValue = value;
      _imeStateRevision = state.stateRevision;
      if (changed) {
        _textInputConnection!.setEditingState(value);
      }
      return;
    }
    _clearLocalImeSession();
    if (action == core.ImeHostAction.closeSession) {
      _closeTextInputConnection(endSession: false);
    } else if (action == core.ImeHostAction.restartSession) {
      _scheduleImeSessionRebind();
    }
  }

  void _scheduleImeSessionRebind() {
    if (_imeSessionRebindScheduled) {
      return;
    }
    _imeSessionRebindScheduled = true;
    scheduleMicrotask(() {
      _imeSessionRebindScheduled = false;
      if (_editorResourcesReleased ||
          !_focusNode.hasFocus ||
          _session.settings.isReadOnly() ||
          _imeSessionId != 0) {
        return;
      }
      final connection = _textInputConnection;
      if (connection == null || !connection.attached) {
        return;
      }
      if (!_beginLocalImeSession()) {
        _closeTextInputConnection(endSession: false);
        return;
      }
      connection.setEditingState(_textEditingValue);
      _updateTextInputStyle();
      _updateTextInputGeometry();
    });
  }

  void _handleEditorActionResult(core.EditorActionResult result) {
    if (_editorResourcesReleased) return;
    _handleImeHostAction(result);
    if (result.imeHostAction != core.ImeHostAction.none) {
      _pendingShowTextInput = false;
      return;
    }
    if (result.gestureType == core.GestureType.undefined) {
      return;
    }
    if (result.gestureType != core.GestureType.tap) {
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
    if (_platformBehavior.usesPlatformTextInput) {
      _openTextInputConnection(show: shouldShowKeyboard);
    }
  }

  void _dispatchEditorActionResult(core.EditorActionResult? result) {
    if (result == null) return;
    _interactionController.resetCursorBlink();
    _session.handleEditorActionResult(result);
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
                        _overlayCoordinator.completionOverlay.value;
                    final inlineSuggestionOverlay =
                        _overlayCoordinator.inlineSuggestionOverlay.value;
                    final selectionMenuOverlay =
                        _overlayCoordinator.selectionMenuOverlay.value;

                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned.fill(child: child!),
                        if (completionOverlay != null)
                          CompletionPopupWidget(
                            items: completionOverlay.items,
                            selectedIndex: completionOverlay.selectedIndex,
                            position: completionOverlay.position,
                            theme: _session.theme,
                            itemBuilder:
                                _session.completionPopupController.itemBuilder,
                            viewportSize: newSize,
                            onItemTap: (index) => _session
                                .completionPopupController
                                .confirmItem(index),
                          ),
                        if (inlineSuggestionOverlay != null)
                          InlineSuggestionBarWidget(
                            x: inlineSuggestionOverlay.x,
                            y: inlineSuggestionOverlay.y,
                            cursorHeight: inlineSuggestionOverlay.cursorHeight,
                            theme: _session.theme,
                            onAccept: () =>
                                _session.inlineSuggestionController.accept(),
                            onDismiss: () =>
                                _session.inlineSuggestionController.dismiss(),
                          ),
                        if (selectionMenuOverlay != null &&
                            selectionMenuOverlay.isNotEmpty)
                          SelectionMenuWidget(
                            position: _overlayCoordinator
                                .computeSelectionMenuPosition(
                                  newSize,
                                  selectionMenuOverlay,
                                ),
                            items: selectionMenuOverlay,
                            theme: _session.theme,
                            onItemTap:
                                _interactionController.onSelectionMenuItemTap,
                          ),
                      ],
                    );
                  },
                  child: Listener(
                    onPointerDown: _interactionController.onPointerDown,
                    onPointerMove: _interactionController.onPointerMove,
                    onPointerHover: _interactionController.onPointerHover,
                    onPointerUp: _interactionController.onPointerUp,
                    onPointerCancel: _interactionController.onPointerCancel,
                    onPointerSignal: _interactionController.onPointerSignal,
                    onPointerPanZoomStart:
                        _interactionController.onPointerPanZoomStart,
                    onPointerPanZoomUpdate:
                        _interactionController.onPointerPanZoomUpdate,
                    onPointerPanZoomEnd:
                        _interactionController.onPointerPanZoomEnd,
                    child: SizedBox.expand(
                      key: _editorKey,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: newSize,
                          painter: _session.painter,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
