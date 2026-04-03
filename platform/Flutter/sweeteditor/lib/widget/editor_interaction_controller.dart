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
    int modifiers = core.Modifier.none;
    if (HardwareKeyboard.instance.isShiftPressed) {
      modifiers |= core.Modifier.shift;
    }
    if (HardwareKeyboard.instance.isControlPressed) {
      modifiers |= core.Modifier.ctrl;
    }
    if (HardwareKeyboard.instance.isAltPressed) modifiers |= core.Modifier.alt;
    if (HardwareKeyboard.instance.isMetaPressed) {
      modifiers |= core.Modifier.meta;
    }

    var keyCode = _mapLogicalKey(logicalKey);
    String? text;

    if (keyCode == core.KeyCode.none &&
        event.character != null &&
        event.character!.isNotEmpty) {
      if (modifiers & core.Modifier.ctrl != 0 ||
          modifiers & core.Modifier.meta != 0) {
        keyCode = _mapCtrlChar(event.character!);
      } else {
        text = event.character;
      }
    }

    if (keyCode == core.KeyCode.none && text == null) {
      return KeyEventResult.ignored;
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

    if (modifiers & (core.Modifier.ctrl | core.Modifier.meta) != 0) {
      if (_handleCtrlShortcut(keyCode, modifiers)) {
        return KeyEventResult.handled;
      }
    }

    if (keyCode == core.KeyCode.enter && _tryHandleNewLineAction()) {
      return KeyEventResult.handled;
    }

    final result = editorCore.handleKeyEvent(
      keyCode,
      text: text,
      modifiers: modifiers,
    );
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
        _session.eventBus.publish(
          SelectionMenuItemClickEvent(itemId: item.id, itemLabel: item.label),
        );
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

  bool _handleCtrlShortcut(core.KeyCode keyCode, int modifiers) {
    switch (keyCode) {
      case core.KeyCode.z:
        if (modifiers & core.Modifier.shift != 0) {
          redo();
        } else {
          undo();
        }
        return true;
      case core.KeyCode.y:
        redo();
        return true;
      case core.KeyCode.a:
        selectAll();
        return true;
      case core.KeyCode.c:
        _copyToClipboard();
        return true;
      case core.KeyCode.x:
        _cutToClipboard();
        return true;
      case core.KeyCode.v:
        _pasteFromClipboard();
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
    for (final change in result.changes) {
      _session.eventBus.publish(
        TextChangedEvent(
          action: action,
          changeRange: change.range,
          text: change.newText,
        ),
      );
    }
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
    return core.KeyCode.none;
  }

  static core.KeyCode _mapCtrlChar(String ch) {
    switch (ch.toUpperCase()) {
      case 'Z':
        return core.KeyCode.z;
      case 'Y':
        return core.KeyCode.y;
      case 'A':
        return core.KeyCode.a;
      case 'C':
        return core.KeyCode.c;
      case 'X':
        return core.KeyCode.x;
      case 'V':
        return core.KeyCode.v;
      case 'K':
        return core.KeyCode.k;
      default:
        return core.KeyCode.none;
    }
  }
}
