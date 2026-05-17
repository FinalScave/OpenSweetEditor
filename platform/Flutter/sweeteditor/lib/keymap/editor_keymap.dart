import '../editor_core.dart' as core;

export '../editor_core.dart'
    show EditorCommand, KeyBinding, KeyChord, KeyMap, KeyModifier;

typedef EditorCommandHandler = bool Function();

class EditorKeyMap extends core.KeyMap {
  EditorKeyMap({Iterable<core.KeyBinding>? bindings}) : super(bindings);

  final Map<int, EditorCommandHandler> _handlers =
      <int, EditorCommandHandler>{};
  int _nextCustomCommandId = core.EditorCommand.builtInMax + 1;

  factory EditorKeyMap.defaultKeyMap() => EditorKeyMap.vscode();

  static void _bind(
    EditorKeyMap keyMap,
    int modifiers,
    core.KeyCode keyCode,
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
      core.EditorCommand.cursorLeft,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.right,
      core.EditorCommand.cursorRight,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.up,
      core.EditorCommand.cursorUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.down,
      core.EditorCommand.cursorDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.home,
      core.EditorCommand.cursorLineStart,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.end,
      core.EditorCommand.cursorLineEnd,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.pageUp,
      core.EditorCommand.cursorPageUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.pageDown,
      core.EditorCommand.cursorPageDown,
    );

    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.left,
      core.EditorCommand.selectLeft,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.right,
      core.EditorCommand.selectRight,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorCommand.selectUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorCommand.selectDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.home,
      core.EditorCommand.selectLineStart,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.end,
      core.EditorCommand.selectLineEnd,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.pageUp,
      core.EditorCommand.selectPageUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.pageDown,
      core.EditorCommand.selectPageDown,
    );

    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.backspace,
      core.EditorCommand.backspace,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.deleteKey,
      core.EditorCommand.deleteForward,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.tab,
      core.EditorCommand.insertTab,
    );
    _bind(
      keyMap,
      core.KeyModifier.none,
      core.KeyCode.enter,
      core.EditorCommand.insertNewline,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.a,
      core.EditorCommand.selectAll,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.a,
      core.EditorCommand.selectAll,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.z,
      core.EditorCommand.undo,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.z,
      core.EditorCommand.undo,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.c,
      core.EditorCommand.copy,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.c,
      core.EditorCommand.copy,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.v,
      core.EditorCommand.paste,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.v,
      core.EditorCommand.paste,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.x,
      core.EditorCommand.cut,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.x,
      core.EditorCommand.cut,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.space,
      core.EditorCommand.triggerCompletion,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.space,
      core.EditorCommand.triggerCompletion,
    );
  }

  factory EditorKeyMap.vscode() {
    final keyMap = EditorKeyMap();
    _addCommonBindings(keyMap);

    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.y,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.y,
      core.EditorCommand.redo,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.enter,
      core.EditorCommand.insertLineBelow,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.enter,
      core.EditorCommand.insertLineBelow,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorCommand.insertLineAbove,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorCommand.insertLineAbove,
    );

    _bind(
      keyMap,
      core.KeyModifier.alt,
      core.KeyCode.up,
      core.EditorCommand.moveLineUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt,
      core.KeyCode.down,
      core.EditorCommand.moveLineDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorCommand.copyLineUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorCommand.copyLineDown,
    );

    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorCommand.deleteLine,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorCommand.deleteLine,
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
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorCommand.insertLineBelow,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.alt,
      core.KeyCode.enter,
      core.EditorCommand.insertLineAbove,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.alt,
      core.KeyCode.enter,
      core.EditorCommand.insertLineAbove,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorCommand.moveLineUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.alt | core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorCommand.moveLineDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.d,
      core.EditorCommand.copyLineDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.d,
      core.EditorCommand.copyLineDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.y,
      core.EditorCommand.deleteLine,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.y,
      core.EditorCommand.deleteLine,
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
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.z,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.y,
      core.EditorCommand.redo,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl,
      core.KeyCode.enter,
      core.EditorCommand.insertLineBelow,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta,
      core.KeyCode.enter,
      core.EditorCommand.insertLineBelow,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorCommand.insertLineAbove,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.enter,
      core.EditorCommand.insertLineAbove,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.up,
      core.EditorCommand.moveLineUp,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.down,
      core.EditorCommand.moveLineDown,
    );
    _bind(
      keyMap,
      core.KeyModifier.ctrl | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorCommand.deleteLine,
    );
    _bind(
      keyMap,
      core.KeyModifier.meta | core.KeyModifier.shift,
      core.KeyCode.k,
      core.EditorCommand.deleteLine,
    );

    return keyMap;
  }

  int registerCommand(core.KeyBinding binding, EditorCommandHandler handler) {
    var resolvedBinding = binding;
    var command = binding.command;
    if (command == core.EditorCommand.none) {
      command = _nextCustomCommandId++;
      resolvedBinding = binding.copyWith(command: command);
    } else if (command >= _nextCustomCommandId) {
      _nextCustomCommandId = command + 1;
    }

    addBinding(resolvedBinding);
    _handlers[command] = handler;
    return command;
  }

  bool invokeHandler(int command) => _handlers[command]?.call() ?? false;
}
