import {
  EditorCommand,
  KeyBinding,
  KeyChord,
  KeyCode,
  KeyMap,
  KeyModifier
} from './core/CoreKeymap';
import { SweetEditor } from './SweetEditor';

export { EditorCommand, KeyBinding, KeyChord, KeyCode, KeyMap, KeyModifier };

export type EditorCommandHandler = (binding: KeyBinding, editor: SweetEditor) => boolean;

export class EditorKeyMap extends KeyMap {
  private readonly handlers: Map<number, EditorCommandHandler> = new Map();
  private nextCustomCommandId: number = EditorCommand.BUILT_IN_MAX + 1;

  private static bind(keyMap: EditorKeyMap, modifiers: number, keyCode: KeyCode, command: number): void {
    keyMap.addBinding(new KeyBinding(new KeyChord(modifiers, keyCode), new KeyChord(), command));
  }

  private static addCommonBindings(keyMap: EditorKeyMap): void {
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.LEFT, EditorCommand.CURSOR_LEFT);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.RIGHT, EditorCommand.CURSOR_RIGHT);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.UP, EditorCommand.CURSOR_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.DOWN, EditorCommand.CURSOR_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.HOME, EditorCommand.CURSOR_LINE_START);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.END, EditorCommand.CURSOR_LINE_END);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.PAGE_UP, EditorCommand.CURSOR_PAGE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.PAGE_DOWN, EditorCommand.CURSOR_PAGE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.LEFT, EditorCommand.SELECT_LEFT);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.RIGHT, EditorCommand.SELECT_RIGHT);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.UP, EditorCommand.SELECT_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.DOWN, EditorCommand.SELECT_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.HOME, EditorCommand.SELECT_LINE_START);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.END, EditorCommand.SELECT_LINE_END);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.PAGE_UP, EditorCommand.SELECT_PAGE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.PAGE_DOWN, EditorCommand.SELECT_PAGE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.BACKSPACE, EditorCommand.BACKSPACE);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.DELETE_KEY, EditorCommand.DELETE_FORWARD);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.TAB, EditorCommand.INSERT_TAB);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.ENTER, EditorCommand.INSERT_NEWLINE);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.A, EditorCommand.SELECT_ALL);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.A, EditorCommand.SELECT_ALL);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Z, EditorCommand.UNDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Z, EditorCommand.UNDO);

    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.CTRL, KeyCode.C), new KeyChord(), EditorCommand.COPY),
      (_binding, editor) => {
        editor.copyToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.META, KeyCode.C), new KeyChord(), EditorCommand.COPY),
      (_binding, editor) => {
        editor.copyToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.CTRL, KeyCode.V), new KeyChord(), EditorCommand.PASTE),
      (_binding, editor) => {
        editor.pasteFromClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.META, KeyCode.V), new KeyChord(), EditorCommand.PASTE),
      (_binding, editor) => {
        editor.pasteFromClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.CTRL, KeyCode.X), new KeyChord(), EditorCommand.CUT),
      (_binding, editor) => {
        editor.cutToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.META, KeyCode.X), new KeyChord(), EditorCommand.CUT),
      (_binding, editor) => {
        editor.cutToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.CTRL, KeyCode.SPACE), new KeyChord(), EditorCommand.TRIGGER_COMPLETION),
      (_binding, editor) => {
        editor.triggerCompletion();
        return true;
      }
    );
    keyMap.registerCommand(
      new KeyBinding(new KeyChord(KeyModifier.META, KeyCode.SPACE), new KeyChord(), EditorCommand.TRIGGER_COMPLETION),
      (_binding, editor) => {
        editor.triggerCompletion();
        return true;
      }
    );
  }

  static defaultKeyMap(): EditorKeyMap {
    return EditorKeyMap.vscode();
  }

  static vscode(): EditorKeyMap {
    const keyMap = new EditorKeyMap();
    EditorKeyMap.addCommonBindings(keyMap);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Y, EditorCommand.REDO);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.ENTER, EditorCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.ENTER, EditorCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorCommand.INSERT_LINE_ABOVE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorCommand.INSERT_LINE_ABOVE);

    EditorKeyMap.bind(keyMap, KeyModifier.ALT, KeyCode.UP, EditorCommand.MOVE_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT, KeyCode.DOWN, EditorCommand.MOVE_LINE_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP, EditorCommand.COPY_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorCommand.COPY_LINE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorCommand.DELETE_LINE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorCommand.DELETE_LINE);

    return keyMap;
  }

  static jetbrains(): EditorKeyMap {
    const keyMap = new EditorKeyMap();
    EditorKeyMap.addCommonBindings(keyMap);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorCommand.REDO);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorCommand.DELETE_LINE);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Y, EditorCommand.DELETE_LINE);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.D, EditorCommand.COPY_LINE_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.D, EditorCommand.COPY_LINE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.ENTER, EditorCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.ALT, KeyCode.ENTER, EditorCommand.INSERT_LINE_ABOVE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.ALT, KeyCode.ENTER, EditorCommand.INSERT_LINE_ABOVE);

    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP, EditorCommand.MOVE_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorCommand.MOVE_LINE_DOWN);

    return keyMap;
  }

  static sublime(): EditorKeyMap {
    const keyMap = new EditorKeyMap();
    EditorKeyMap.addCommonBindings(keyMap);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Y, EditorCommand.REDO);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.ENTER, EditorCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.ENTER, EditorCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorCommand.INSERT_LINE_ABOVE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorCommand.INSERT_LINE_ABOVE);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.UP, EditorCommand.MOVE_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.DOWN, EditorCommand.MOVE_LINE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorCommand.DELETE_LINE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorCommand.DELETE_LINE);

    return keyMap;
  }

  registerCommand(binding: KeyBinding, handler: EditorCommandHandler): number {
    let resolved = binding;
    let command = binding.command;
    if (command === EditorCommand.NONE) {
      command = this.nextCustomCommandId++;
      resolved = binding.withCommand(command);
    } else if (command >= this.nextCustomCommandId) {
      this.nextCustomCommandId = command + 1;
    }
    this.addBinding(resolved);
    this.handlers.set(command, handler);
    return command;
  }

  getCommand(command: number): EditorCommandHandler | undefined {
    return this.handlers.get(command);
  }
}

