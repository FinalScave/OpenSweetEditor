part of '../sweeteditor.dart';

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

  void startCursorBlink() {
    _stopCursorBlink();
    _cursorVisible = true;
    _session.setCursorVisible(true);
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _cursorVisible = !_cursorVisible;
      _session.setCursorVisible(_cursorVisible);
    });
  }

  void dispose() {
    _stopCursorBlink();
    _animationTicker?.stop();
    _animationTicker?.dispose();
  }

  core.GestureResult? onPointerDown(PointerDownEvent event) {
    final isTouch = event.kind == PointerDeviceKind.touch;
    final gestureEvent = core.GestureEvent(
      type: isTouch
          ? core.EventType.touchDown
          : (event.buttons & kSecondaryMouseButton) != 0
          ? core.EventType.mouseRightDown
          : core.EventType.mouseDown,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
    );
    return _processGestureResult(
      _session.editorCore?.handleGestureEvent(gestureEvent),
    );
  }

  core.GestureResult? onPointerMove(PointerMoveEvent event) {
    final isTouch = event.kind == PointerDeviceKind.touch;
    final gestureEvent = core.GestureEvent(
      type: isTouch ? core.EventType.touchMove : core.EventType.mouseMove,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
    );
    return _processGestureResult(
      _session.editorCore?.handleGestureEvent(gestureEvent),
    );
  }

  core.GestureResult? onPointerUp(PointerUpEvent event) {
    final isTouch = event.kind == PointerDeviceKind.touch;
    final gestureEvent = core.GestureEvent(
      type: isTouch ? core.EventType.touchUp : core.EventType.mouseUp,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
    );
    return _processGestureResult(
      _session.editorCore?.handleGestureEvent(gestureEvent),
    );
  }

  core.GestureResult? onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return null;
    final gestureEvent = core.GestureEvent(
      type: core.EventType.mouseWheel,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
      wheelDeltaX: event.scrollDelta.dx,
      wheelDeltaY: event.scrollDelta.dy,
    );
    return _processGestureResult(
      _session.editorCore?.handleGestureEvent(gestureEvent),
    );
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

    final resolvedCommand = keyCode == core.KeyCode.none
        ? null
        : _session.keyMap.resolve(
            core.KeyChord(modifiers: modifiers, keyCode: keyCode),
          );

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

    final suppressTextForCore =
        resolvedCommand != null &&
        resolvedCommand.status == KeyResolveStatus.matched &&
        _isHostCommand(resolvedCommand.command);
    final result = editorCore.handleKeyEvent(
      keyCode,
      text: suppressTextForCore ? null : text,
      modifiers: modifiers,
    );
    final handledByPlatformCommand =
        resolvedCommand != null &&
        resolvedCommand.status == KeyResolveStatus.matched &&
        _handleResolvedCommand(resolvedCommand.command);

    if (handledByPlatformCommand) {
      _resetCursorBlink();
      _flush();
      return KeyEventResult.handled;
    }

    _dispatchKeyEventResult(result, text);
    _resetCursorBlink();
    _flush();

    return result.handled ? KeyEventResult.handled : KeyEventResult.ignored;
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
            screenPoint: result.tapPoint,
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
          LongPressEvent(cursorPosition: pos, screenPoint: result.tapPoint),
        );
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
      case core.GestureType.contextMenu:
        _session.eventBus.publish(
          ContextMenuEvent(cursorPosition: pos, screenPoint: result.tapPoint),
        );
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
      case core.GestureType.scroll:
      case core.GestureType.fastScroll:
        _session.eventBus.publish(
          ScrollChangedEvent(
            scrollX: result.viewScrollX,
            scrollY: result.viewScrollY,
          ),
        );
        _session.decorationProviderManager.onScrollChanged();
        _session.completionProviderManager.dismiss();
      case core.GestureType.scale:
        _session.eventBus.publish(ScaleChangedEvent(scale: result.viewScale));
      case core.GestureType.dragSelect:
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

  void _publishHitTargetEvent(
    core.HitTarget hitTarget,
    core.PointF screenPoint,
  ) {
    switch (hitTarget.type) {
      case core.HitTargetType.gutterIcon:
        _session.eventBus.publish(
          GutterIconClickEvent(
            line: hitTarget.line,
            iconId: hitTarget.iconId,
            screenPoint: screenPoint,
          ),
        );
      case core.HitTargetType.inlayHintText:
        _session.eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.text,
            screenPoint: screenPoint,
          ),
        );
      case core.HitTargetType.inlayHintIcon:
        _session.eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.icon,
            intValue: hitTarget.iconId,
            screenPoint: screenPoint,
          ),
        );
      case core.HitTargetType.inlayHintColor:
        _session.eventBus.publish(
          InlayHintClickEvent(
            line: hitTarget.line,
            column: hitTarget.column,
            type: core.InlayType.color,
            intValue: hitTarget.colorValue,
            screenPoint: screenPoint,
          ),
        );
      case core.HitTargetType.none:
      case core.HitTargetType.foldPlaceholder:
      case core.HitTargetType.foldGutter:
        break;
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

  bool _isHostCommand(int command) {
    return command > core.EditorCommand.builtInMax ||
        core.EditorCommand.isPlatformHandled(command);
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
    if (primaryChange.text.length == 1) {
      final ch = primaryChange.text;
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
      } else if (_isCompletionIdentifier(ch)) {
        _session.completionProviderManager.triggerCompletion(
          CompletionTriggerKind.invoked,
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
      _session.flush();
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

  static bool _isCompletionIdentifier(String text) {
    if (text.length != 1) return false;
    final code = text.codeUnitAt(0);
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        code == 95;
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
