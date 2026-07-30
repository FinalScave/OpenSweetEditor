part of '../sweeteditor.dart';

const double _kDirectScaleEpsilon = 0.0001;
const double _kDirectScrollEpsilon = 0.0001;

class EditorInteractionController {
  EditorInteractionController({required EditorSession session})
    : _session = session;

  final EditorSession _session;

  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  final Map<int, core.PointF> _activeTouchPoints = <int, core.PointF>{};
  final Map<int, double> _activePanZoomScales = <int, double>{};

  void startCursorBlink() {
    _stopCursorBlink();
    _cursorVisible = true;
    _session.setCursorVisible(true);
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _cursorVisible = !_cursorVisible;
      _session.setCursorVisible(_cursorVisible);
    });
  }

  void stopCursorBlink({bool keepCursorVisible = true}) {
    _stopCursorBlink();
    _cursorVisible = keepCursorVisible;
    _session.setCursorVisible(keepCursorVisible);
  }

  void resetCursorBlink() {
    _resetCursorBlink();
  }

  void dispose() {
    _stopCursorBlink();
    _activeTouchPoints.clear();
    _activePanZoomScales.clear();
  }

  core.EditorActionResult? onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return _handleTouchDown(event);
    }
    return _sendGestureEvent(
      type: (event.buttons & kSecondaryMouseButton) != 0
          ? core.EventType.mouseRightDown
          : core.EventType.mouseDown,
      points: [_pointFromEvent(event)],
    );
  }

  core.EditorActionResult? onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return _handleTouchMove(event);
    }
    return _sendGestureEvent(
      type: core.EventType.mouseMove,
      points: [_pointFromEvent(event)],
    );
  }

  core.EditorActionResult? onPointerHover(PointerHoverEvent event) {
    return _sendGestureEvent(
      type: core.EventType.mouseMove,
      points: [_pointFromEvent(event)],
    );
  }

  core.EditorActionResult? onPointerExit(PointerExitEvent event) {
    return _sendGestureEvent(
      type: core.EventType.mouseMove,
      points: const [core.PointF(x: -1, y: -1)],
    );
  }

  core.EditorActionResult? onPointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return _handleTouchUp(event);
    }
    return _sendGestureEvent(
      type: core.EventType.mouseUp,
      points: [_pointFromEvent(event)],
    );
  }

  core.EditorActionResult? onPointerCancel(PointerCancelEvent event) {
    if (event.kind != PointerDeviceKind.touch) {
      return null;
    }
    _activeTouchPoints[event.pointer] = _pointFromEvent(event);
    final result = _sendGestureEvent(
      type: core.EventType.touchCancel,
      points: _touchPoints(),
    );
    _activeTouchPoints.clear();
    return result;
  }

  core.EditorActionResult? onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return null;
    final point = _pointFromEvent(event);
    final modifiers = _currentGestureModifiers(
      allowCtrl: !_session.platformBehavior.isMobileStyle,
    );
    _sendGestureEvent(
      type: core.EventType.directGestureBegin,
      points: [point],
      modifiers: modifiers,
    );
    _sendGestureEvent(
      type: core.EventType.mouseWheel,
      points: [point],
      modifiers: modifiers,
      wheelDeltaX: -event.scrollDelta.dx,
      wheelDeltaY: -event.scrollDelta.dy,
    );
    return _sendGestureEvent(
      type: core.EventType.directGestureEnd,
      points: [point],
      modifiers: modifiers,
    );
  }

  core.EditorActionResult? onPointerPanZoomStart(
    PointerPanZoomStartEvent event,
  ) {
    if (_session.platformBehavior.isMobileStyle) {
      return null;
    }
    if (_activePanZoomScales.containsKey(event.pointer)) {
      return null;
    }
    _activePanZoomScales[event.pointer] = 1.0;
    return _sendGestureEvent(
      type: core.EventType.directGestureBegin,
      points: [_pointFromEvent(event)],
    );
  }

  core.EditorActionResult? onPointerPanZoomUpdate(
    PointerPanZoomUpdateEvent event,
  ) {
    if (_session.platformBehavior.isMobileStyle) {
      return null;
    }
    final previousScale = _activePanZoomScales[event.pointer];
    if (previousScale == null) {
      return null;
    }
    final point = _pointFromEvent(event);
    core.EditorActionResult? result;

    final currentScale = _normalizeDirectScale(event.scale);
    _activePanZoomScales[event.pointer] = currentScale;
    final directScale = previousScale == 0
        ? currentScale
        : currentScale / previousScale;
    if ((directScale - 1.0).abs() > _kDirectScaleEpsilon) {
      result = _sendGestureEvent(
        type: core.EventType.directScale,
        points: [point],
        directScale: _normalizeDirectScale(directScale),
      );
    }

    final deltaX = _normalizeDirectScrollDelta(event.localPanDelta.dx);
    final deltaY = _normalizeDirectScrollDelta(event.localPanDelta.dy);
    if (deltaX.abs() > _kDirectScrollEpsilon ||
        deltaY.abs() > _kDirectScrollEpsilon) {
      result = _sendGestureEvent(
        type: core.EventType.directScroll,
        points: [point],
        wheelDeltaX: deltaX,
        wheelDeltaY: deltaY,
      );
    }

    return result;
  }

  core.EditorActionResult? onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    if (_session.platformBehavior.isMobileStyle) {
      return null;
    }
    if (_activePanZoomScales.remove(event.pointer) == null) {
      return null;
    }
    return _sendGestureEvent(
      type: core.EventType.directGestureEnd,
      points: [_pointFromEvent(event)],
    );
  }

  core.EditorActionResult? _handleTouchDown(PointerDownEvent event) {
    if (!_session.platformBehavior.isMobileStyle &&
        _activeTouchPoints.isNotEmpty) {
      return null;
    }
    _activeTouchPoints[event.pointer] = _pointFromEvent(event);
    return _sendGestureEvent(
      type: _activeTouchPoints.length > 1
          ? core.EventType.touchPointerDown
          : core.EventType.touchDown,
      points: _touchPoints(),
    );
  }

  core.EditorActionResult? _handleTouchMove(PointerMoveEvent event) {
    if (!_activeTouchPoints.containsKey(event.pointer) &&
        !_session.platformBehavior.isMobileStyle &&
        _activeTouchPoints.isNotEmpty) {
      return null;
    }
    _activeTouchPoints[event.pointer] = _pointFromEvent(event);
    return _sendGestureEvent(
      type: core.EventType.touchMove,
      points: _touchPoints(),
    );
  }

  core.EditorActionResult? _handleTouchUp(PointerUpEvent event) {
    if (!_activeTouchPoints.containsKey(event.pointer) &&
        !_session.platformBehavior.isMobileStyle &&
        _activeTouchPoints.isNotEmpty) {
      _activeTouchPoints.remove(event.pointer);
      return null;
    }
    final point = _pointFromEvent(event);
    _activeTouchPoints[event.pointer] = point;
    final wasMultiTouch = _activeTouchPoints.length > 1;
    if (wasMultiTouch) {
      _activeTouchPoints.remove(event.pointer);
      final points = _touchPoints();
      return _sendGestureEvent(
        type: core.EventType.touchPointerUp,
        points: points.isEmpty ? [point] : points,
      );
    }
    final result = _sendGestureEvent(
      type: core.EventType.touchUp,
      points: [point],
    );
    _activeTouchPoints.remove(event.pointer);
    return result;
  }

  core.PointF _pointFromEvent(PointerEvent event) {
    return core.PointF(x: event.localPosition.dx, y: event.localPosition.dy);
  }

  List<core.PointF> _touchPoints() {
    return _activeTouchPoints.values.toList(growable: false);
  }

  core.EditorActionResult? _sendGestureEvent({
    required core.EventType type,
    required List<core.PointF> points,
    int? modifiers,
    double wheelDeltaX = 0,
    double wheelDeltaY = 0,
    double directScale = 1,
  }) {
    final gestureEvent = core.GestureEvent(
      type: type,
      points: points,
      modifiers: modifiers ?? _currentGestureModifiers(),
      wheelDeltaX: wheelDeltaX,
      wheelDeltaY: wheelDeltaY,
      directScale: directScale,
    );
    return _processGestureActionResult(
      _session.editorCore?.handleGestureEvent(gestureEvent),
    );
  }

  int _currentGestureModifiers({bool allowCtrl = true}) {
    final keyboard = HardwareKeyboard.instance;
    var modifiers = core.KeyModifier.none;
    if (keyboard.isShiftPressed) {
      modifiers |= core.KeyModifier.shift;
    }
    if (allowCtrl && keyboard.isControlPressed) {
      modifiers |= core.KeyModifier.ctrl;
    }
    if (keyboard.isAltPressed) {
      modifiers |= core.KeyModifier.alt;
    }
    if (keyboard.isMetaPressed) {
      modifiers |= core.KeyModifier.meta;
    }
    return modifiers;
  }

  double _normalizeDirectScale(double scale) {
    if (!scale.isFinite) return 1.0;
    return scale.clamp(0.25, 4.0).toDouble();
  }

  double _normalizeDirectScrollDelta(double delta) {
    if (!delta.isFinite) return 0.0;
    return delta.clamp(-4096.0, 4096.0).toDouble();
  }

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    final editorCore = _session.editorCore;
    if (editorCore == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyUpEvent) {
      _refreshPointerModifiers(editorCore);
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final logicalKey = event.logicalKey;
    int modifiers = core.KeyModifier.none;
    if (HardwareKeyboard.instance.isShiftPressed) {
      modifiers |= core.KeyModifier.shift;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      modifiers |= core.KeyModifier.ctrl;
    }
    if (HardwareKeyboard.instance.isAltPressed) {
      modifiers |= core.KeyModifier.alt;
    }
    if (HardwareKeyboard.instance.isMetaPressed) {
      modifiers |= core.KeyModifier.meta;
    }

    var keyCode = _mapLogicalKey(logicalKey);
    String? text;

    if (event.character != null && event.character!.isNotEmpty) {
      text = event.character;
    }

    if (keyCode == core.KeyCode.none && text == null) {
      return KeyEventResult.ignored;
    }

    if (_session.inlineSuggestionController.isShowing) {
      final androidCode = keyCode;
      if (androidCode != 0 &&
          _session.inlineSuggestionController.handleKeyCode(androidCode)) {
        _flush();
        return KeyEventResult.handled;
      }
    }

    if (_session.completionPopupController.isShowing) {
      final androidCode = keyCode;
      if (androidCode != 0 &&
          _session.completionPopupController.handleKeyCode(androidCode)) {
        return KeyEventResult.handled;
      }
    }

    if (keyCode == core.KeyCode.enter && _tryHandleNewLineAction()) {
      return KeyEventResult.handled;
    }

    final result = editorCore.handleKeyEvent(
      keyCode,
      text: _session.platformBehavior.usesPlatformTextInput ? null : text,
      modifiers: modifiers,
    );
    final handledByPlatformCommand =
        result.handled &&
        result.command != core.EditorBuiltinCommand.none.value &&
        _handleResolvedCommand(result.command);

    if (handledByPlatformCommand) {
      _resetCursorBlink();
      _dispatchEditorActionResult(result);
      return KeyEventResult.handled;
    }

    _resetCursorBlink();
    _dispatchEditorActionResult(result);

    return result.handled || handledByPlatformCommand
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  void _refreshPointerModifiers(core.EditorCore editorCore) {
    _dispatchEditorActionResult(
      editorCore.updatePointerModifiers(_currentGestureModifiers()),
    );
  }

  bool performSelector(String selectorName) {
    switch (selectorName) {
      case 'copy':
      case 'copy:':
        _copyToClipboard();
        return true;
      case 'cut':
      case 'cut:':
        _cutToClipboard();
        return true;
      case 'paste':
      case 'paste:':
        _pasteFromClipboard();
        return true;
      case 'selectAll':
      case 'selectAll:':
        selectAll();
        return true;
      default:
        return false;
    }
  }

  void onSelectionMenuItemTap(SelectionMenuItem item) {
    switch (item.id) {
      case SelectionMenuItem.actionCut:
        _cutToClipboard();
        _session.selectionMenuController.hide();
      case SelectionMenuItem.actionCopy:
        _copyToClipboard();
        _session.selectionMenuController.hide();
      case SelectionMenuItem.actionPaste:
        _pasteFromClipboard();
        _session.selectionMenuController.hide();
      case SelectionMenuItem.actionSelectAll:
        selectAll();
      default:
        _session.eventBus.publish(SelectionMenuItemClickEvent(item: item));
        _session.selectionMenuController.hide();
    }
  }

  void onCompletionItemConfirmed(CompletionItem item) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    var text = item.insertText ?? item.label;
    final isSnippet =
        item.insertTextFormat == CompletionItem.insertTextFormatSnippet;
    if (item.textEdit != null) {
      text = item.textEdit!.newText;
      final edits = <core.TextEdit>[];
      edits.add(
        isSnippet ? core.TextEdit(range: item.textEdit!.range) : item.textEdit!,
      );
      edits.addAll(item.additionalTextEdits);
      applyTextEdits(edits);
      if (isSnippet) {
        insertSnippet(text);
      }
    } else if (item.additionalTextEdits.isEmpty) {
      if (isSnippet) {
        insertSnippet(text);
      } else {
        insertText(text);
      }
    } else {
      final cursor = editorCore.getCursorPosition();
      final primaryEdit = core.TextEdit(
        range: core.TextRange(start: cursor, end: cursor),
        newText: isSnippet ? '' : text,
      );
      final edits = <core.TextEdit>[];
      edits.add(primaryEdit);
      edits.addAll(item.additionalTextEdits);
      applyTextEdits(edits);
      if (isSnippet) {
        insertSnippet(text);
      }
    }
  }

  core.EditorActionResult? _processGestureActionResult(
    core.EditorActionResult? result,
  ) {
    if (result == null) return null;
    _dispatchEditorActionResult(result);
    _resetCursorBlink();
    return result;
  }

  bool _handleResolvedCommand(int command) {
    if (command > core.EditorBuiltinCommand.triggerCompletion.value) {
      return _session.keyMap.invokeHandler(command);
    }
    if (!_isPlatformHandledCommand(command)) {
      return false;
    }
    if (_session.keyMap.invokeHandler(command)) {
      return true;
    }
    if (command == core.EditorBuiltinCommand.copy.value) {
      _copyToClipboard();
      return true;
    }
    if (command == core.EditorBuiltinCommand.paste.value) {
      _pasteFromClipboard();
      return true;
    }
    if (command == core.EditorBuiltinCommand.cut.value) {
      _cutToClipboard();
      return true;
    }
    if (command == core.EditorBuiltinCommand.triggerCompletion.value) {
      _session.completionProviderManager.triggerCompletion(
        CompletionTriggerKind.invoked,
        null,
      );
      return true;
    }
    return false;
  }

  bool _isPlatformHandledCommand(int command) {
    return command == core.EditorBuiltinCommand.copy.value ||
        command == core.EditorBuiltinCommand.paste.value ||
        command == core.EditorBuiltinCommand.cut.value ||
        command == core.EditorBuiltinCommand.triggerCompletion.value;
  }

  void _copyToClipboard() {
    final text = _session.editorCore?.getSelectedText() ?? '';
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
    }
  }

  void _cutToClipboard() {
    final editorCore = _session.editorCore;
    final text = editorCore?.getSelectedText() ?? '';
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      final result = editorCore?.backspace();
      if (result != null) {
        _resetCursorBlink();
        _dispatchEditorActionResult(result);
      }
    }
  }

  void _pasteFromClipboard() {
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (data?.text != null && data!.text!.isNotEmpty && _session.isActive) {
        insertText(data.text!);
      }
    });
  }

  bool _tryHandleNewLineAction() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return false;
    final pos = editorCore.getCursorPosition();
    final lineText = _session.document?.getLineText(pos.line) ?? '';
    final action = _session.newLineActionProviderManager.provideNewLineAction(
      pos.line,
      pos.column,
      lineText,
      _session.languageConfiguration,
      _session.metadata,
    );
    if (action != null) {
      final result = editorCore.handleKeyEvent(
        core.KeyCode.none,
        text: action.text,
      );
      _resetCursorBlink();
      _dispatchEditorActionResult(result);
      return true;
    }
    return false;
  }

  void insertText(String text) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.insertText(text);
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  /// Inserts text at the specified document position.
  void insertTextAt(core.TextPosition position, String text) {
    replaceText(core.TextRange(start: position, end: position), text);
  }

  void replaceText(core.TextRange range, String text) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.replaceText(
      range.start.line,
      range.start.column,
      range.end.line,
      range.end.column,
      text,
    );
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  void deleteText(core.TextRange range) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.deleteText(
      range.start.line,
      range.start.column,
      range.end.line,
      range.end.column,
    );
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  /// Applies multiple text edits as one undoable operation.
  ///
  /// Edits use the original document coordinates. The first edit is the primary edit.
  void applyTextEdits(List<core.TextEdit> edits) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.applyTextEdits(edits);
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  void insertSnippet(String snippetTemplate) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.insertSnippet(snippetTemplate);
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  void undo() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.undo();
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  void redo() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.redo();
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  void selectAll() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.selectAll();
    _resetCursorBlink();
    _dispatchEditorActionResult(result);
  }

  void _dispatchEditorActionResult(core.EditorActionResult? result) {
    _session.handleEditorActionResult(result);
  }

  void _flush() {
    if (_session.isActive) {
      _session.requestFlush();
    }
  }

  void _resetCursorBlink() {
    _cursorVisible = true;
    _session.setCursorVisible(true);
    _stopCursorBlink();
    startCursorBlink();
  }

  void _stopCursorBlink() {
    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimer = null;
  }

  static int _mapLogicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.backspace) return core.KeyCode.backspace;
    if (key == LogicalKeyboardKey.delete) return core.KeyCode.deleteKey;
    if (key == LogicalKeyboardKey.enter) return core.KeyCode.enter;
    if (key == LogicalKeyboardKey.tab) return core.KeyCode.tab;
    if (key == LogicalKeyboardKey.escape) return core.KeyCode.escape;
    if (key == LogicalKeyboardKey.arrowLeft) return core.KeyCode.left;
    if (key == LogicalKeyboardKey.arrowRight) return core.KeyCode.right;
    if (key == LogicalKeyboardKey.arrowUp) return core.KeyCode.up;
    if (key == LogicalKeyboardKey.arrowDown) return core.KeyCode.down;
    if (key == LogicalKeyboardKey.home) return core.KeyCode.home;
    if (key == LogicalKeyboardKey.end) return core.KeyCode.end;
    if (key == LogicalKeyboardKey.pageUp) return core.KeyCode.pageUp;
    if (key == LogicalKeyboardKey.pageDown) return core.KeyCode.pageDown;
    if (key == LogicalKeyboardKey.keyA) return core.KeyCode.a;
    if (key == LogicalKeyboardKey.keyC) return core.KeyCode.c;
    if (key == LogicalKeyboardKey.keyD) return core.KeyCode.d;
    if (key == LogicalKeyboardKey.keyK) return core.KeyCode.k;
    if (key == LogicalKeyboardKey.keyV) return core.KeyCode.v;
    if (key == LogicalKeyboardKey.keyX) return core.KeyCode.x;
    if (key == LogicalKeyboardKey.keyY) return core.KeyCode.y;
    if (key == LogicalKeyboardKey.keyZ) return core.KeyCode.z;
    if (key == LogicalKeyboardKey.space) return core.KeyCode.space;
    return core.KeyCode.none;
  }
}
