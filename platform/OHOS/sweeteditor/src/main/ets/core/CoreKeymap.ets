export enum EditorBuiltinCommand {
  NONE = 0,
  CURSOR_LEFT = 1,
  CURSOR_RIGHT = 2,
  CURSOR_UP = 3,
  CURSOR_DOWN = 4,
  CURSOR_LINE_START = 5,
  CURSOR_LINE_END = 6,
  CURSOR_PAGE_UP = 7,
  CURSOR_PAGE_DOWN = 8,
  SELECT_LEFT = 9,
  SELECT_RIGHT = 10,
  SELECT_UP = 11,
  SELECT_DOWN = 12,
  SELECT_LINE_START = 13,
  SELECT_LINE_END = 14,
  SELECT_PAGE_UP = 15,
  SELECT_PAGE_DOWN = 16,
  SELECT_ALL = 17,
  BACKSPACE = 18,
  DELETE_FORWARD = 19,
  INSERT_TAB = 20,
  INSERT_NEWLINE = 21,
  INSERT_LINE_ABOVE = 22,
  INSERT_LINE_BELOW = 23,
  UNDO = 24,
  REDO = 25,
  MOVE_LINE_UP = 26,
  MOVE_LINE_DOWN = 27,
  COPY_LINE_UP = 28,
  COPY_LINE_DOWN = 29,
  DELETE_LINE = 30,
  COPY = 31,
  PASTE = 32,
  CUT = 33,
  TRIGGER_COMPLETION = 34,
}

export function editorBuiltinCommandFromValue(value: number): EditorBuiltinCommand {
  switch (value) {
    case 0: return EditorBuiltinCommand.NONE;
    case 1: return EditorBuiltinCommand.CURSOR_LEFT;
    case 2: return EditorBuiltinCommand.CURSOR_RIGHT;
    case 3: return EditorBuiltinCommand.CURSOR_UP;
    case 4: return EditorBuiltinCommand.CURSOR_DOWN;
    case 5: return EditorBuiltinCommand.CURSOR_LINE_START;
    case 6: return EditorBuiltinCommand.CURSOR_LINE_END;
    case 7: return EditorBuiltinCommand.CURSOR_PAGE_UP;
    case 8: return EditorBuiltinCommand.CURSOR_PAGE_DOWN;
    case 9: return EditorBuiltinCommand.SELECT_LEFT;
    case 10: return EditorBuiltinCommand.SELECT_RIGHT;
    case 11: return EditorBuiltinCommand.SELECT_UP;
    case 12: return EditorBuiltinCommand.SELECT_DOWN;
    case 13: return EditorBuiltinCommand.SELECT_LINE_START;
    case 14: return EditorBuiltinCommand.SELECT_LINE_END;
    case 15: return EditorBuiltinCommand.SELECT_PAGE_UP;
    case 16: return EditorBuiltinCommand.SELECT_PAGE_DOWN;
    case 17: return EditorBuiltinCommand.SELECT_ALL;
    case 18: return EditorBuiltinCommand.BACKSPACE;
    case 19: return EditorBuiltinCommand.DELETE_FORWARD;
    case 20: return EditorBuiltinCommand.INSERT_TAB;
    case 21: return EditorBuiltinCommand.INSERT_NEWLINE;
    case 22: return EditorBuiltinCommand.INSERT_LINE_ABOVE;
    case 23: return EditorBuiltinCommand.INSERT_LINE_BELOW;
    case 24: return EditorBuiltinCommand.UNDO;
    case 25: return EditorBuiltinCommand.REDO;
    case 26: return EditorBuiltinCommand.MOVE_LINE_UP;
    case 27: return EditorBuiltinCommand.MOVE_LINE_DOWN;
    case 28: return EditorBuiltinCommand.COPY_LINE_UP;
    case 29: return EditorBuiltinCommand.COPY_LINE_DOWN;
    case 30: return EditorBuiltinCommand.DELETE_LINE;
    case 31: return EditorBuiltinCommand.COPY;
    case 32: return EditorBuiltinCommand.PASTE;
    case 33: return EditorBuiltinCommand.CUT;
    case 34: return EditorBuiltinCommand.TRIGGER_COMPLETION;
    default: return EditorBuiltinCommand.NONE;
  }
}

export class KeyCode {
  static readonly NONE: number = 0;
  static readonly BACKSPACE: number = 8;
  static readonly TAB: number = 9;
  static readonly ENTER: number = 13;
  static readonly ESCAPE: number = 27;
  static readonly DELETE_KEY: number = 46;
  static readonly LEFT: number = 37;
  static readonly UP: number = 38;
  static readonly RIGHT: number = 39;
  static readonly DOWN: number = 40;
  static readonly HOME: number = 36;
  static readonly END: number = 35;
  static readonly PAGE_UP: number = 33;
  static readonly PAGE_DOWN: number = 34;
  static readonly A: number = 65;
  static readonly C: number = 67;
  static readonly D: number = 68;
  static readonly V: number = 86;
  static readonly X: number = 88;
  static readonly Z: number = 90;
  static readonly Y: number = 89;
  static readonly K: number = 75;
  static readonly SPACE: number = 32;
}

export class KeyModifier {
  static readonly NONE: number = 0;
  static readonly SHIFT: number = 1;
  static readonly CTRL: number = 2;
  static readonly ALT: number = 4;
  static readonly META: number = 8;
}

export interface KeyBinding {
  first: KeyChord;
  second: KeyChord;
  command: number;
}

export interface KeyChord {
  modifiers: number;
  keyCode: number;
}
