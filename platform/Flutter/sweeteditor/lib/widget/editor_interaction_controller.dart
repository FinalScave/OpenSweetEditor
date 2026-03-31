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

  void onPointerDown(PointerDownEvent event) {
    final isTouch = event.kind == PointerDeviceKind.touch;
    final gestureEvent = core.GestureEvent(
      type: isTouch ? core.EventType.touchDown : core.EventType.mouseDown,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
    );
    _processGestureResult(_session.editorCore?.handleGestureEvent(gestureEvent));
  }

  void onPointerMove(PointerMoveEvent event) {
    final isTouch = event.kind == PointerDeviceKind.touch;
    final gestureEvent = core.GestureEvent(
      type: isTouch ? core.EventType.touchMove : core.EventType.mouseMove,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
    );
    _processGestureResult(_session.editorCore?.handleGestureEvent(gestureEvent));
  }

  void onPointerUp(PointerUpEvent event) {
    final isTouch = event.kind == PointerDeviceKind.touch;
    final gestureEvent = core.GestureEvent(
      type: isTouch ? core.EventType.touchUp : core.EventType.mouseUp,
      points: [
        core.PointF(x: event.localPosition.dx, y: event.localPosition.dy),
      ],
    );
    _processGestureResult(_session.editorCore?.handleGestureEvent(gestureEvent));
  }

  void onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final gestureEvent = core.GestureEvent(
      type: core.EventType.mouseWheel,
      points: [core.PointF(x: event.localPosition.dx, y: event.localPosition.dy)],
      wheelDeltaX: event.scrollDelta.dx,
      wheelDeltaY: event.scrollDelta.dy,
    );
    _processGestureResult(_session.editorCore?.handleGestureEvent(gestureEvent));
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
        _resetCursorBlink();
        _flush();
        return KeyEventResult.handled;
      }
    }

    if (keyCode == core.KeyCode.enter && _tryHandleNewLineAction()) {
      _resetCursorBlink();
      _flush();
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
        _session.editorCore?.selectAll();
        _flush();
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
    if (item.textEdit != null) {
      final edit = item.textEdit!;
      editorCore.replaceText(
        edit.range.start.line,
        edit.range.start.column,
        edit.range.end.line,
        edit.range.end.column,
        edit.newText,
      );
    } else {
      editorCore.insertText(item.insertText ?? item.label);
    }
    _flush();
  }

  void _processGestureResult(core.GestureResult? result) {
    if (result == null) return;
    _fireGestureEvents(result);
    _flush();
    _session.selectionMenuController.onGestureResult(result, result.hasSelection);
    _updateAnimationState(result);
    _resetCursorBlink();
  }

  void _fireGestureEvents(core.GestureResult result) {
    final pos = result.cursorPosition;
    switch (result.type) {
      case core.GestureType.tap:
        _session.eventBus.publish(CursorChangedEvent(cursorPosition: pos));
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
      case core.GestureType.scroll:
        _session.eventBus.publish(
          ScrollChangedEvent(
            scrollX: result.viewScrollX,
            scrollY: result.viewScrollY,
          ),
        );
        _session.decorationProviderManager.onScrollChanged();
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
    final editorCore = _session.editorCore;
    if (editorCore == null) return false;
    switch (keyCode) {
      case core.KeyCode.z:
        if (modifiers & core.Modifier.shift != 0) {
          editorCore.redo();
        } else {
          editorCore.undo();
        }
        return true;
      case core.KeyCode.y:
        editorCore.redo();
        return true;
      case core.KeyCode.a:
        editorCore.selectAll();
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
      editorCore?.backspace();
    }
  }

  void _pasteFromClipboard() {
    Clipboard.getData(Clipboard.kTextPlain).then((data) {
      if (data?.text != null &&
          data!.text!.isNotEmpty &&
          _session.controller.isAttached) {
        _session.editorCore?.insertText(data.text!);
        _flush();
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
      editorCore?.insertText(action.text);
      return true;
    }
    return false;
  }

  void _dispatchKeyEventResult(core.KeyEventResult result, String? typedText) {
    final editorCore = _session.editorCore;
    if (result.contentChanged) {
      final changes = result.editResult?.changes ?? [];
      for (final change in changes) {
        _session.eventBus.publish(
          TextChangedEvent(
            action: TextChangeAction.key,
            changeRange: change.range,
            text: change.newText,
          ),
        );
      }
      if (changes.isNotEmpty) {
        _session.decorationProviderManager.onTextChanged(changes);
      }
      if (typedText != null &&
          _session.completionProviderManager.isTriggerCharacter(typedText)) {
        _session.completionProviderManager.triggerCompletion(
          CompletionTriggerKind.character,
          typedText,
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
