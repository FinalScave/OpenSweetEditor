import {
  EditorBuiltinCommand,
  KeyBinding,
  KeyChord,
  KeyCode,
  KeyModifier
} from './core/CoreKeymap';
import { SweetEditor } from './SweetEditor';

export { EditorBuiltinCommand, KeyBinding, KeyChord, KeyCode, KeyModifier };

export type EditorCommandHandler = (binding: KeyBinding, editor: SweetEditor) => boolean;

const EDITOR_BUILTIN_COMMAND_MAX = EditorBuiltinCommand.TRIGGER_COMPLETION;

export class EditorKeyMap {
  private readonly bindings: KeyBinding[] = [];
  private readonly handlers: Map<number, EditorCommandHandler> = new Map();
  private nextCustomCommandId: number = EDITOR_BUILTIN_COMMAND_MAX + 1;

  private static chord(modifiers: number, keyCode: number): KeyChord {
    return { modifiers, keyCode };
  }

  private static emptyChord(): KeyChord {
    return EditorKeyMap.chord(KeyModifier.NONE, KeyCode.NONE);
  }

  private static keyBinding(modifiers: number, keyCode: number, command: number): KeyBinding {
    return {
      first: EditorKeyMap.chord(modifiers, keyCode),
      second: EditorKeyMap.emptyChord(),
      command
    };
  }

  private static sameChord(lhs: KeyChord, rhs: KeyChord): boolean {
    return lhs.modifiers === rhs.modifiers && lhs.keyCode === rhs.keyCode;
  }

  private static sameBindingPosition(lhs: KeyBinding, rhs: KeyBinding): boolean {
    return EditorKeyMap.sameChord(lhs.first, rhs.first) && EditorKeyMap.sameChord(lhs.second, rhs.second);
  }

  private static bind(keyMap: EditorKeyMap, modifiers: number, keyCode: number, command: number): void {
    keyMap.addBinding(EditorKeyMap.keyBinding(modifiers, keyCode, command));
  }

  addBinding(binding: KeyBinding): void {
    if (binding.first.keyCode === KeyCode.NONE) {
      return;
    }
    const index = this.bindings.findIndex((existing) => EditorKeyMap.sameBindingPosition(existing, binding));
    if (index >= 0) {
      this.bindings.splice(index, 1);
    }
    this.bindings.push(binding);
  }

  removeBinding(binding: KeyBinding): void {
    const index = this.bindings.findIndex((existing) => EditorKeyMap.sameBindingPosition(existing, binding));
    if (index >= 0) {
      this.bindings.splice(index, 1);
    }
  }

  getBindings(): KeyBinding[] {
    return this.bindings;
  }

  private static addCommonBindings(keyMap: EditorKeyMap): void {
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.LEFT, EditorBuiltinCommand.CURSOR_LEFT);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.RIGHT, EditorBuiltinCommand.CURSOR_RIGHT);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.UP, EditorBuiltinCommand.CURSOR_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.DOWN, EditorBuiltinCommand.CURSOR_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.HOME, EditorBuiltinCommand.CURSOR_LINE_START);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.END, EditorBuiltinCommand.CURSOR_LINE_END);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.PAGE_UP, EditorBuiltinCommand.CURSOR_PAGE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.PAGE_DOWN, EditorBuiltinCommand.CURSOR_PAGE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.LEFT, EditorBuiltinCommand.SELECT_LEFT);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.RIGHT, EditorBuiltinCommand.SELECT_RIGHT);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.SELECT_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.SELECT_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.HOME, EditorBuiltinCommand.SELECT_LINE_START);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.END, EditorBuiltinCommand.SELECT_LINE_END);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.PAGE_UP, EditorBuiltinCommand.SELECT_PAGE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.PAGE_DOWN, EditorBuiltinCommand.SELECT_PAGE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.BACKSPACE, EditorBuiltinCommand.BACKSPACE);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.DELETE_KEY, EditorBuiltinCommand.DELETE_FORWARD);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.TAB, EditorBuiltinCommand.INSERT_TAB);
    EditorKeyMap.bind(keyMap, KeyModifier.NONE, KeyCode.ENTER, EditorBuiltinCommand.INSERT_NEWLINE);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.A, EditorBuiltinCommand.SELECT_ALL);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.A, EditorBuiltinCommand.SELECT_ALL);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Z, EditorBuiltinCommand.UNDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Z, EditorBuiltinCommand.UNDO);

    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.CTRL, KeyCode.C, EditorBuiltinCommand.COPY),
      (_binding, editor) => {
        editor.copyToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.META, KeyCode.C, EditorBuiltinCommand.COPY),
      (_binding, editor) => {
        editor.copyToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.CTRL, KeyCode.V, EditorBuiltinCommand.PASTE),
      (_binding, editor) => {
        editor.pasteFromClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.META, KeyCode.V, EditorBuiltinCommand.PASTE),
      (_binding, editor) => {
        editor.pasteFromClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.CTRL, KeyCode.X, EditorBuiltinCommand.CUT),
      (_binding, editor) => {
        editor.cutToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.META, KeyCode.X, EditorBuiltinCommand.CUT),
      (_binding, editor) => {
        editor.cutToClipboard();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.CTRL, KeyCode.SPACE, EditorBuiltinCommand.TRIGGER_COMPLETION),
      (_binding, editor) => {
        editor.triggerCompletion();
        return true;
      }
    );
    keyMap.registerCommand(
      EditorKeyMap.keyBinding(KeyModifier.META, KeyCode.SPACE, EditorBuiltinCommand.TRIGGER_COMPLETION),
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

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.REDO);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE);

    EditorKeyMap.bind(keyMap, KeyModifier.ALT, KeyCode.UP, EditorBuiltinCommand.MOVE_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.COPY_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.COPY_LINE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE);

    return keyMap;
  }

  static jetbrains(): EditorKeyMap {
    const keyMap = new EditorKeyMap();
    EditorKeyMap.addCommonBindings(keyMap);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.DELETE_LINE);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.DELETE_LINE);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.D, EditorBuiltinCommand.COPY_LINE_DOWN);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.D, EditorBuiltinCommand.COPY_LINE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.ALT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.ALT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE);

    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.MOVE_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.ALT | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN);

    return keyMap;
  }

  static sublime(): EditorKeyMap {
    const keyMap = new EditorKeyMap();
    EditorKeyMap.addCommonBindings(keyMap);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.Z, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.Y, EditorBuiltinCommand.REDO);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.Y, EditorBuiltinCommand.REDO);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.META, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_BELOW);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.ENTER, EditorBuiltinCommand.INSERT_LINE_ABOVE);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.UP, EditorBuiltinCommand.MOVE_LINE_UP);
    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.DOWN, EditorBuiltinCommand.MOVE_LINE_DOWN);

    EditorKeyMap.bind(keyMap, KeyModifier.CTRL | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE);
    EditorKeyMap.bind(keyMap, KeyModifier.META | KeyModifier.SHIFT, KeyCode.K, EditorBuiltinCommand.DELETE_LINE);

    return keyMap;
  }

  registerCommand(binding: KeyBinding, handler: EditorCommandHandler): number {
    let resolved = binding;
    let command = binding.command;
    if (command === EditorBuiltinCommand.NONE) {
      command = this.nextCustomCommandId++;
      resolved = {
        first: binding.first,
        second: binding.second,
        command
      };
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

