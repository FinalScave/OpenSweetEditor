import '../core/editor_core.dart' as core;

export '../core/editor_core.dart'
    show EditorBuiltinCommand, KeyBinding, KeyChord, KeyModifier, KeyCode;

typedef EditorCommandHandler = bool Function();

class EditorKeyMap {
  EditorKeyMap({Iterable<core.KeyBinding>? bindings}) {
    if (bindings != null) {
      for (final binding in bindings) {
        addBinding(binding);
      }
    }
  }

  final List<core.KeyBinding> _bindings = <core.KeyBinding>[];
  final Map<int, EditorCommandHandler> _handlers =
      <int, EditorCommandHandler>{};
  int _nextCustomCommandId =
      core.EditorBuiltinCommand.triggerCompletion.value + 1;

  List<core.KeyBinding> get bindings =>
      List<core.KeyBinding>.unmodifiable(_bindings);

  void addBinding(core.KeyBinding binding) {
    if (binding.first.keyCode == core.KeyCode.none) return;
    _bindings.removeWhere(
      (existing) =>
          _sameChord(existing.first, binding.first) &&
          _sameChord(existing.second, binding.second),
    );
    _bindings.add(binding);
  }

  void removeBinding(core.KeyBinding binding) {
    _bindings.removeWhere(
      (existing) =>
          _sameChord(existing.first, binding.first) &&
          _sameChord(existing.second, binding.second),
    );
  }

  static bool _sameChord(core.KeyChord a, core.KeyChord b) {
    return a.modifiers == b.modifiers && a.keyCode == b.keyCode;
  }

  factory EditorKeyMap.defaultKeyMap() => EditorKeyMap.vscode();

  static void _bind(
    EditorKeyMap keyMap,
    int modifiers,
    int keyCode,
    int command,
  ) {
    keyMap.addBinding(
      core.KeyBinding(
        first: core.KeyChord(modifiers: modifiers, keyCode: keyCode),
        command: command,
      ),
    );
  }

  static void _addCommonBindings(EditorKeyMap keyMap) {
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.left,
      core.EditorBuiltinCommand.cursorLeft.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.right,
      core.EditorBuiltinCommand.cursorRight.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.up,
      core.EditorBuiltinCommand.cursorUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.down,
      core.EditorBuiltinCommand.cursorDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.home,
      core.EditorBuiltinCommand.cursorLineStart.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.end,
      core.EditorBuiltinCommand.cursorLineEnd.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.pageUp,
      core.EditorBuiltinCommand.cursorPageUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.pageDown,
      core.EditorBuiltinCommand.cursorPageDown.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.left,
      core.EditorBuiltinCommand.selectLeft.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.right,
      core.EditorBuiltinCommand.selectRight.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorBuiltinCommand.selectUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorBuiltinCommand.selectDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.home,
      core.EditorBuiltinCommand.selectLineStart.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.end,
      core.EditorBuiltinCommand.selectLineEnd.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.pageUp,
      core.EditorBuiltinCommand.selectPageUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.pageDown,
      core.EditorBuiltinCommand.selectPageDown.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.backspace,
      core.EditorBuiltinCommand.backspace.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.deleteKey,
      core.EditorBuiltinCommand.deleteForward.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.tab,
      core.EditorBuiltinCommand.insertTab.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertNewline.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.a,
      core.EditorBuiltinCommand.selectAll.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.a,
      core.EditorBuiltinCommand.selectAll.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.z,
      core.EditorBuiltinCommand.undo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.z,
      core.EditorBuiltinCommand.undo.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.c,
      core.EditorBuiltinCommand.copy.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.c,
      core.EditorBuiltinCommand.copy.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.v,
      core.EditorBuiltinCommand.paste.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.v,
      core.EditorBuiltinCommand.paste.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.x,
      core.EditorBuiltinCommand.cut.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.x,
      core.EditorBuiltinCommand.cut.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.space,
      core.EditorBuiltinCommand.triggerCompletion.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.space,
      core.EditorBuiltinCommand.triggerCompletion.value,
    );
  }

  factory EditorKeyMap.vscode() {
    final keyMap = EditorKeyMap();
    _addCommonBindings(keyMap);

    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.y,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.y,
      core.EditorBuiltinCommand.redo.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineBelow.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineBelow.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineAbove.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineAbove.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.alt,
      core.KeyCode.up,
      core.EditorBuiltinCommand.moveLineUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt,
      core.KeyCode.down,
      core.EditorBuiltinCommand.moveLineDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorBuiltinCommand.copyLineUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorBuiltinCommand.copyLineDown.value,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorBuiltinCommand.deleteLine.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorBuiltinCommand.deleteLine.value,
    );

    return keyMap;
  }

  factory EditorKeyMap.jetbrains() {
    final keyMap = EditorKeyMap();
    _addCommonBindings(keyMap);

    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineBelow.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.alt,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineAbove.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.alt,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineAbove.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorBuiltinCommand.moveLineUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorBuiltinCommand.moveLineDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.d,
      core.EditorBuiltinCommand.copyLineDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.d,
      core.EditorBuiltinCommand.copyLineDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.y,
      core.EditorBuiltinCommand.deleteLine.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.y,
      core.EditorBuiltinCommand.deleteLine.value,
    );

    return keyMap;
  }

  factory EditorKeyMap.sublime() {
    final keyMap = EditorKeyMap();
    _addCommonBindings(keyMap);

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.y,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.y,
      core.EditorBuiltinCommand.redo.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineBelow.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineBelow.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineAbove.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorBuiltinCommand.insertLineAbove.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorBuiltinCommand.moveLineUp.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorBuiltinCommand.moveLineDown.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorBuiltinCommand.deleteLine.value,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorBuiltinCommand.deleteLine.value,
    );

    return keyMap;
  }

  int registerCommand(core.KeyBinding binding, EditorCommandHandler handler) {
    var resolvedBinding = binding;
    var command = binding.command;
    if (command == core.EditorBuiltinCommand.none.value) {
      command = _nextCustomCommandId++;
      resolvedBinding = core.KeyBinding(
        first: binding.first,
        second: binding.second,
        command: command,
      );
    } else if (command >= _nextCustomCommandId) {
      _nextCustomCommandId = command + 1;
    }

    addBinding(resolvedBinding);
    _handlers[command] = handler;
    return command;
  }

  bool invokeHandler(int command) => _handlers[command]?.call() ?? false;
}
