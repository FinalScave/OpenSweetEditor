part of '../sweeteditor.dart';

const double _kDirectScaleEpsilon = 0.0001;
const double _kDirectScrollEpsilon = 0.0001;

class EditorInteractionController {
  EditorInteractionController({
    required EditorSession session,
    required TickerProvider tickerProvider,
  }) : _session = session,
       _tickerProvider = tickerProvider;

  final EditorSession _session;
  final TickerProvider _tickerProvider;

  Timer? _cursorBlinkTimer;
  bool _cursorVisible = true;
  Ticker? _animationTicker;
  bool _animating = false;
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

  void dispose() {
    _stopCursorBlink();
    _animationTicker?.stop();
    _animationTicker?.dispose();
    _activeTouchPoints.clear();
    _activePanZoomScales.clear();
  }

  core.GestureResult? onPointerDown(PointerDownEvent event) {
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

  core.GestureResult? onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return _handleTouchMove(event);
    }
    return _sendGestureEvent(
      type: core.EventType.mouseMove,
      points: [_pointFromEvent(event)],
    );
  }

  core.GestureResult? onPointerHover(PointerHoverEvent event) {
    return _sendGestureEvent(
      type: core.EventType.mouseMove,
      points: [_pointFromEvent(event)],
    );
  }

  core.GestureResult? onPointerExit(PointerExitEvent event) {
    return _sendGestureEvent(
      type: core.EventType.mouseMove,
      points: const [core.PointF(x: -1, y: -1)],
    );
  }

  core.GestureResult? onPointerUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.touch) {
      return _handleTouchUp(event);
    }
    return _sendGestureEvent(
      type: core.EventType.mouseUp,
      points: [_pointFromEvent(event)],
    );
  }

  core.GestureResult? onPointerCancel(PointerCancelEvent event) {
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

  core.GestureResult? onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return null;
    return _sendGestureEvent(
      type: core.EventType.mouseWheel,
      points: [_pointFromEvent(event)],
      modifiers: _currentGestureModifiers(
        allowCtrl: _session.platformBehavior.supportsCtrlWheelScale,
      ),
      wheelDeltaX: -event.scrollDelta.dx,
      wheelDeltaY: -event.scrollDelta.dy,
    );
  }

  core.GestureResult? onPointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (!_session.platformBehavior.supportsTrackpadPanZoom) {
      return null;
    }
    _activePanZoomScales[event.pointer] = 1.0;
    return null;
  }

  core.GestureResult? onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_session.platformBehavior.supportsTrackpadPanZoom) {
      return null;
    }
    final point = _pointFromEvent(event);
    core.GestureResult? result;

    final previousScale = _activePanZoomScales[event.pointer] ?? 1.0;
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

  core.GestureResult? onPointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _activePanZoomScales.remove(event.pointer);
    return null;
  }

  core.GestureResult? _handleTouchDown(PointerDownEvent event) {
    if (!_session.platformBehavior.supportsTouchScale &&
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

  core.GestureResult? _handleTouchMove(PointerMoveEvent event) {
    if (!_activeTouchPoints.containsKey(event.pointer) &&
        !_session.platformBehavior.supportsTouchScale &&
        _activeTouchPoints.isNotEmpty) {
      return null;
    }
    _activeTouchPoints[event.pointer] = _pointFromEvent(event);
    return _sendGestureEvent(
      type: core.EventType.touchMove,
      points: _touchPoints(),
    );
  }

  core.GestureResult? _handleTouchUp(PointerUpEvent event) {
    if (!_activeTouchPoints.containsKey(event.pointer) &&
        !_session.platformBehavior.supportsTouchScale &&
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

  core.GestureResult? _sendGestureEvent({
    required int type,
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
    return _processGestureResult(
      _session.editorCore?.handleGestureEvent(gestureEvent),
    );
  }

  int _currentGestureModifiers({bool allowCtrl = true}) {
    final keyboard = HardwareKeyboard.instance;
    var modifiers = core.Modifier.none;
    if (keyboard.isShiftPressed) {
      modifiers |= core.Modifier.shift;
    }
    if (allowCtrl && keyboard.isControlPressed) {
      modifiers |= core.Modifier.ctrl;
    }
    if (keyboard.isAltPressed) {
      modifiers |= core.Modifier.alt;
    }
    if (keyboard.isMetaPressed) {
      modifiers |= core.Modifier.meta;
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
    if (editorCore == null || event is! KeyDownEvent) {
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

    if (_tryHandleComposingKey(keyCode)) {
      return KeyEventResult.handled;
    }

    if (_session.inlineSuggestionController.isShowing) {
      final androidCode = keyCode.value;
      if (androidCode != 0 &&
          _session.inlineSuggestionController.handleKeyCode(androidCode)) {
        _flush();
        return KeyEventResult.handled;
      }
    }

    if (_session.completionPopupController.isShowing) {
      final androidCode = keyCode.value;
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
        result.command != core.EditorCommand.none &&
        _handleResolvedCommand(result.command);

    if (handledByPlatformCommand) {
      _resetCursorBlink();
      _flush();
      return KeyEventResult.handled;
    }

    _dispatchKeyEventResult(result, text);
    _resetCursorBlink();
    _flush();

    return result.handled || handledByPlatformCommand
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
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
    core.TextRange? replaceRange;
    var text = item.insertText ?? item.label;
    final isSnippet =
        item.insertTextFormat == CompletionItem.insertTextFormatSnippet;
    if (item.textEdit != null) {
      final edit = item.textEdit!;
      replaceRange = edit.range;
      text = edit.newText;
    } else {
      final wordRange = editorCore.getWordRangeAtCursor();
      if (!_isCollapsedRange(wordRange)) {
        replaceRange = wordRange;
      }
    }
    if (replaceRange != null) {
      deleteText(replaceRange, action: TextChangeAction.delete_);
    }
    if (isSnippet) {
      insertSnippet(text);
    } else {
      insertText(text);
    }
  }

  core.GestureResult? _processGestureResult(core.GestureResult? result) {
    if (result == null) return null;
    _fireGestureEvents(result);
    _flush();
    _session.selectionMenuController.onGestureResult(
      result,
      result.hasSelection,
    );
    _updateAnimationState(result);
    _resetCursorBlink();
    return result;
  }

  void _fireGestureEvents(core.GestureResult result) {
    final pos = result.cursorPosition;
    switch (result.type) {
      case core.GestureType.tap:
        _publishHitTargetEvent(result.hitTarget, result.tapPoint);
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
        _session.completionProviderManager.dismiss();
      case core.GestureType.doubleTap:
        _session.eventBus.publish(
          DoubleTapEvent(
            cursorPosition: pos,
            hasSelection: result.hasSelection,
            selection: result.hasSelection ? result.selection : null,
            locationInEditor: result.tapPoint,
          ),
        );
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
        if (result.hasSelection) {
          _session.eventBus.publish(
            SelectionChangedEvent(
              hasSelection: true,
              selection: result.selection,
              cursorPosition: pos,
            ),
          );
        }
      case core.GestureType.longPress:
        _session.eventBus.publish(
          LongPressEvent(
            cursorPosition: pos,
            locationInEditor: result.tapPoint,
          ),
        );
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
      case core.GestureType.contextMenu:
        _session.eventBus.publish(
          ContextMenuEvent(
            cursorPosition: pos,
            locationInEditor: result.tapPoint,
          ),
        );
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
      case core.GestureType.scroll:
      case core.GestureType.fastScroll:
        _handleScrollChanged(result);
      case core.GestureType.scale:
        _session.syncPlatformScale(result.viewScale);
        _session.eventBus.publish(ScaleChangedEvent(scale: result.viewScale));
      case core.GestureType.dragSelect:
        if (_didScrollSinceLastFrame(result)) {
          _handleScrollChanged(result);
        }
        if (result.hasSelection) {
          _session.eventBus.publish(
            SelectionChangedEvent(
              hasSelection: true,
              selection: result.selection,
              cursorPosition: pos,
            ),
          );
        }
      default:
        break;
    }
  }

  void _handleScrollChanged(core.GestureResult result) {
    _session.eventBus.publish(
      ScrollChangedEvent(
        scrollX: result.viewScrollX,
        scrollY: result.viewScrollY,
      ),
    );
    _session.decorationProviderManager.onScrollChanged();
    _session.completionProviderManager.dismiss();
  }

  bool _didScrollSinceLastFrame(core.GestureResult result) {
    final model = _session.renderModel;
    return model.scrollX != result.viewScrollX ||
        model.scrollY != result.viewScrollY;
  }

  void _publishHitTargetEvent(
    core.HitTarget hitTarget,
    core.PointF locationInEditor,
  ) {
    switch (hitTarget.type) {
      case core.HitTargetType.gutterIcon:
        _session.eventBus.publish(
          GutterIconClickEvent(
            line: hitTarget.line,
            iconId: hitTarget.iconId,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.inlayHintText:
        _session.eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.text,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.inlayHintIcon:
        _session.eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.icon,
            intValue: hitTarget.iconId,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.inlayHintColor:
        _session.eventBus.publish(
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
        _session.eventBus.publish(
          FoldToggleEvent(
            line: hitTarget.line,
            isGutter: hitTarget.type == core.HitTargetType.foldGutter,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.codelens:
        _session.eventBus.publish(
          CodeLensClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            commandId: hitTarget.iconId,
            locationInEditor: locationInEditor,
          ),
        );
      case core.HitTargetType.link:
        _session.eventBus.publish(
          LinkClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            target:
                _session.editorCore?.getLinkTargetAt(
                  hitTarget.line,
                  hitTarget.column,
                ) ??
                '',
            locationInEditor: locationInEditor,
          ),
        );
    }
  }

  bool _handleResolvedCommand(int command) {
    if (command > core.EditorCommand.builtInMax) {
      return _session.keyMap.invokeHandler(command);
    }
    if (!core.EditorCommand.isPlatformHandled(command)) {
      return false;
    }
    if (_session.keyMap.invokeHandler(command)) {
      return true;
    }
    switch (command) {
      case core.EditorCommand.copy:
        _copyToClipboard();
        return true;
      case core.EditorCommand.paste:
        _pasteFromClipboard();
        return true;
      case core.EditorCommand.cut:
        _cutToClipboard();
        return true;
      case core.EditorCommand.triggerCompletion:
        _session.completionProviderManager.triggerCompletion(
          CompletionTriggerKind.invoked,
          null,
        );
        return true;
      default:
        return false;
    }
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
        _dispatchTextChanged(TextChangeAction.delete_, result);
        _resetCursorBlink();
        _flush();
      }
    }
  }

  void _pasteFromClipboard() {
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (data?.text != null &&
          data!.text!.isNotEmpty &&
          _session.controller.isAttached) {
        insertText(data.text!);
      }
    });
  }

  bool _tryHandleNewLineAction() {
    final editorCore = _session.editorCore;
    final pos = editorCore?.getCursorPosition();
    if (pos == null) return false;
    final lineText = _session.document?.getLineText(pos.line) ?? '';
    final action = _session.newLineActionProviderManager.provideNewLineAction(
      pos.line,
      pos.column,
      lineText,
      _session.languageConfiguration,
      _session.metadata,
    );
    if (action != null) {
      insertText(action.text, action: TextChangeAction.key);
      return true;
    }
    return false;
  }

  bool _tryHandleComposingKey(core.KeyCode keyCode) {
    if (keyCode == core.KeyCode.none) return false;
    final editorCore = _session.editorCore;
    if (editorCore == null) return false;
    final snapshot = editorCore.getImeSyncSnapshot();
    if (!snapshot.hasComposingSession && !snapshot.hasPlatformMarkedRange) {
      return false;
    }
    switch (keyCode) {
      case core.KeyCode.backspace:
        dispatchImeActionResult(editorCore.deleteImeBackward());
        return true;
      case core.KeyCode.deleteKey:
        dispatchImeActionResult(editorCore.deleteImeForward());
        return true;
      case core.KeyCode.escape:
        dispatchImeActionResult(editorCore.cancelImePreedit());
        return true;
      default:
        return false;
    }
  }

  void insertText(
    String text, {
    TextChangeAction action = TextChangeAction.insert,
  }) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.insertText(text);
    _dispatchTextChanged(action, result);
    _resetCursorBlink();
    _flush();
  }

  void replaceText(
    core.TextRange range,
    String text, {
    TextChangeAction action = TextChangeAction.insert,
  }) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.replaceText(
      range.start.line,
      range.start.column,
      range.end.line,
      range.end.column,
      text,
    );
    _dispatchTextChanged(action, result);
    _resetCursorBlink();
    _flush();
  }

  void deleteText(
    core.TextRange range, {
    TextChangeAction action = TextChangeAction.delete_,
  }) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.deleteText(
      range.start.line,
      range.start.column,
      range.end.line,
      range.end.column,
    );
    _dispatchTextChanged(action, result);
    _resetCursorBlink();
    _flush();
  }

  void insertSnippet(
    String snippetTemplate, {
    TextChangeAction action = TextChangeAction.insert,
  }) {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.insertSnippet(snippetTemplate);
    _dispatchTextChanged(action, result);
    _resetCursorBlink();
    _flush();
  }

  void undo() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.undo();
    _dispatchTextChanged(TextChangeAction.undo, result);
    _resetCursorBlink();
    _flush();
  }

  void redo() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    final result = editorCore.redo();
    _dispatchTextChanged(TextChangeAction.redo, result);
    _resetCursorBlink();
    _flush();
  }

  void dispatchTextChangedForController(
    TextChangeAction action,
    core.TextEditResult result,
  ) {
    _dispatchTextChanged(action, result);
    _resetCursorBlink();
    _flush();
  }

  void dispatchImeActionResult(core.ImeActionResult result) {
    if (!result.handled &&
        !result.contentChanged &&
        !result.cursorChanged &&
        !result.selectionChanged) {
      return;
    }
    if (result.contentChanged) {
      _dispatchTextChanged(TextChangeAction.composition, result.editResult);
    }
    if (result.cursorChanged) {
      _session.eventBus.publish(
        CursorChangedEvent(cursorPosition: result.sync.cursor),
      );
    }
    if (result.selectionChanged) {
      _session.eventBus.publish(
        SelectionChangedEvent(
          hasSelection: result.sync.hasSelection,
          selection: result.sync.hasSelection ? result.sync.selection : null,
          cursorPosition: result.sync.cursor,
        ),
      );
    }
    _session.selectionMenuController.hide();
    _resetCursorBlink();
    _flush();
  }

  void selectAll() {
    final editorCore = _session.editorCore;
    if (editorCore == null) return;
    editorCore.selectAll();
    _session.selectionMenuController.onSelectAll();
    _resetCursorBlink();
    _flush();
  }

  void _dispatchTextChanged(
    TextChangeAction action,
    core.TextEditResult result,
  ) {
    if (!result.changed || result.changes.isEmpty) return;
    _session.eventBus.publish(
      TextChangedEvent(changes: result.changes, action: action),
    );
    _session.decorationProviderManager.onTextChanged(result.changes);
    _session.selectionMenuController.onTextChanged();

    final editorCore = _session.editorCore;
    if (editorCore == null || editorCore.isInLinkedEditing) {
      return;
    }

    final primaryChange = result.changes.first;
    if (primaryChange.newText.length == 1) {
      final ch = primaryChange.newText;
      if (_session.completionProviderManager.isTriggerCharacter(ch)) {
        _session.completionProviderManager.triggerCompletion(
          CompletionTriggerKind.character,
          ch,
        );
      } else if (_session.completionPopupController.isShowing) {
        _session.completionProviderManager.triggerCompletion(
          CompletionTriggerKind.retrigger,
          null,
        );
      }
    } else if (_session.completionPopupController.isShowing) {
      _session.completionProviderManager.triggerCompletion(
        CompletionTriggerKind.retrigger,
        null,
      );
    }
  }

  void _dispatchKeyEventResult(core.KeyEventResult result, String? typedText) {
    final editorCore = _session.editorCore;
    if (result.contentChanged) {
      final changes = result.editResult?.changes ?? [];
      if (changes.isNotEmpty) {
        _dispatchTextChanged(
          TextChangeAction.key,
          result.editResult ?? core.TextEditResult.empty,
        );
      } else if (_session.completionPopupController.isShowing) {
        _session.completionProviderManager.triggerCompletion(
          CompletionTriggerKind.retrigger,
          null,
        );
      }
    }
    if (result.cursorChanged) {
      final pos =
          editorCore?.getCursorPosition() ?? const core.TextPosition(0, 0);
      _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
    }
    if (result.selectionChanged) {
      final sel = editorCore?.getSelection();
      final pos =
          editorCore?.getCursorPosition() ?? const core.TextPosition(0, 0);
      _session.eventBus.publish(
        SelectionChangedEvent(
          hasSelection: sel != null,
          selection: sel,
          cursorPosition: pos,
        ),
      );
    }
  }

  void _flush() {
    if (_session.controller.isAttached) {
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

  void _updateAnimationState(core.GestureResult result) {
    if (result.needsAnimation && !_animating) {
      _animating = true;
      _animationTicker ??= _tickerProvider.createTicker(_onAnimationTick);
      _animationTicker!.start();
    } else if (!result.needsAnimation && _animating) {
      _animating = false;
      _animationTicker?.stop();
    }
  }

  void _onAnimationTick(Duration elapsed) {
    final editorCore = _session.editorCore;
    if (editorCore == null || !_animating) return;
    final result = editorCore.tickAnimations();
    _fireGestureEvents(result);
    _session.selectionMenuController.onGestureResult(
      result,
      result.hasSelection,
    );
    _flush();
    if (!result.needsAnimation) {
      _animating = false;
      _animationTicker?.stop();
    }
  }

  static bool _isCollapsedRange(core.TextRange range) {
    return range.start.line == range.end.line &&
        range.start.column == range.end.column;
  }

  static core.KeyCode _mapLogicalKey(LogicalKeyboardKey key) {
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
