export class KeyModifier {
  static readonly NONE: number = 0;
  static readonly SHIFT: number = 1;
  static readonly CTRL: number = 2;
  static readonly ALT: number = 4;
  static readonly META: number = 8;
}

export class EditorCommand {
  static readonly NONE: number = 0;
  static readonly CURSOR_LEFT: number = 1;
  static readonly CURSOR_RIGHT: number = 2;
  static readonly CURSOR_UP: number = 3;
  static readonly CURSOR_DOWN: number = 4;
  static readonly CURSOR_LINE_START: number = 5;
  static readonly CURSOR_LINE_END: number = 6;
  static readonly CURSOR_PAGE_UP: number = 7;
  static readonly CURSOR_PAGE_DOWN: number = 8;
  static readonly SELECT_LEFT: number = 9;
  static readonly SELECT_RIGHT: number = 10;
  static readonly SELECT_UP: number = 11;
  static readonly SELECT_DOWN: number = 12;
  static readonly SELECT_LINE_START: number = 13;
  static readonly SELECT_LINE_END: number = 14;
  static readonly SELECT_PAGE_UP: number = 15;
  static readonly SELECT_PAGE_DOWN: number = 16;
  static readonly SELECT_ALL: number = 17;
  static readonly BACKSPACE: number = 18;
  static readonly DELETE_FORWARD: number = 19;
  static readonly INSERT_TAB: number = 20;
  static readonly INSERT_NEWLINE: number = 21;
  static readonly INSERT_LINE_ABOVE: number = 22;
  static readonly INSERT_LINE_BELOW: number = 23;
  static readonly UNDO: number = 24;
  static readonly REDO: number = 25;
  static readonly MOVE_LINE_UP: number = 26;
  static readonly MOVE_LINE_DOWN: number = 27;
  static readonly COPY_LINE_UP: number = 28;
  static readonly COPY_LINE_DOWN: number = 29;
  static readonly DELETE_LINE: number = 30;
  static readonly COPY: number = 31;
  static readonly PASTE: number = 32;
  static readonly CUT: number = 33;
  static readonly TRIGGER_COMPLETION: number = 34;
  static readonly BUILT_IN_MAX: number = EditorCommand.TRIGGER_COMPLETION;

  static isBuiltIn(command: number): boolean {
    return command > EditorCommand.NONE && command <= EditorCommand.BUILT_IN_MAX;
  }

  static isPlatformHandled(command: number): boolean {
    return command === EditorCommand.COPY ||
      command === EditorCommand.PASTE ||
      command === EditorCommand.CUT ||
      command === EditorCommand.TRIGGER_COMPLETION;
  }
}

export enum KeyCode {
  NONE = 0,
  BACKSPACE = 8,
  TAB = 9,
  ENTER = 13,
  ESCAPE = 27,
  SPACE = 32,
  PAGE_UP = 33,
  PAGE_DOWN = 34,
  END = 35,
  HOME = 36,
  LEFT = 37,
  UP = 38,
  RIGHT = 39,
  DOWN = 40,
  DELETE_KEY = 46,
  A = 65,
  C = 67,
  D = 68,
  K = 75,
  V = 86,
  X = 88,
  Y = 89,
  Z = 90,
}

export class KeyChord {
  readonly modifiers: number;
  readonly keyCode: KeyCode;

  constructor(modifiers: number = KeyModifier.NONE, keyCode: KeyCode = KeyCode.NONE) {
    this.modifiers = modifiers;
    this.keyCode = keyCode;
  }

  isEmpty(): boolean {
    return this.keyCode === KeyCode.NONE;
  }
}

export class KeyBinding {
  readonly first: KeyChord;
  readonly second: KeyChord;
  readonly command: number;

  constructor(first: KeyChord, second: KeyChord = new KeyChord(), command: number = EditorCommand.NONE) {
    this.first = first;
    this.second = second;
    this.command = command;
  }

  withCommand(command: number): KeyBinding {
    return new KeyBinding(this.first, this.second, command);
  }
}

export class KeyMap {
  protected readonly bindingsInternal: KeyBinding[] = [];

  constructor(bindings?: KeyBinding[]) {
    if (bindings) {
      for (const binding of bindings) {
        this.addBinding(binding);
      }
    }
  }

  getBindings(): KeyBinding[] {
    return [...this.bindingsInternal];
  }

  addBinding(binding: KeyBinding): void {
    if (binding.first.isEmpty()) {
      return;
    }
    for (let i = this.bindingsInternal.length - 1; i >= 0; i--) {
      const existing = this.bindingsInternal[i];
      if (sameChord(existing.first, binding.first) && sameChord(existing.second, binding.second)) {
        this.bindingsInternal.splice(i, 1);
      }
    }
    this.bindingsInternal.push(binding);
  }

  toArrayBuffer(): ArrayBuffer {
    const buffer = new ArrayBuffer(4 + this.bindingsInternal.length * 10);
    const view = new DataView(buffer);
    let offset = 0;
    view.setUint32(offset, this.bindingsInternal.length, true);
    offset += 4;
    for (const binding of this.bindingsInternal) {
      view.setUint8(offset, binding.first.modifiers);
      offset += 1;
      view.setUint16(offset, binding.first.keyCode as number, true);
      offset += 2;
      view.setUint8(offset, binding.second.modifiers);
      offset += 1;
      view.setUint16(offset, binding.second.keyCode as number, true);
      offset += 2;
      view.setUint32(offset, binding.command, true);
      offset += 4;
    }
    return buffer;
  }
}

function sameChord(a: KeyChord, b: KeyChord): boolean {
  return a.modifiers === b.modifiers && a.keyCode === b.keyCode;
}

