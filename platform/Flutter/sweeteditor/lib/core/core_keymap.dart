// ignore_for_file: unused_element

part of 'editor_core.dart';

enum EditorBuiltinCommand {
  none(0),
  cursorLeft(1),
  cursorRight(2),
  cursorUp(3),
  cursorDown(4),
  cursorLineStart(5),
  cursorLineEnd(6),
  cursorPageUp(7),
  cursorPageDown(8),
  selectLeft(9),
  selectRight(10),
  selectUp(11),
  selectDown(12),
  selectLineStart(13),
  selectLineEnd(14),
  selectPageUp(15),
  selectPageDown(16),
  selectAll(17),
  backspace(18),
  deleteForward(19),
  insertTab(20),
  insertNewline(21),
  insertLineAbove(22),
  insertLineBelow(23),
  undo(24),
  redo(25),
  moveLineUp(26),
  moveLineDown(27),
  copyLineUp(28),
  copyLineDown(29),
  deleteLine(30),
  copy(31),
  paste(32),
  cut(33),
  triggerCompletion(34);

  const EditorBuiltinCommand(this.value);
  final int value;

  static EditorBuiltinCommand fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return cursorLeft;
      case 2: return cursorRight;
      case 3: return cursorUp;
      case 4: return cursorDown;
      case 5: return cursorLineStart;
      case 6: return cursorLineEnd;
      case 7: return cursorPageUp;
      case 8: return cursorPageDown;
      case 9: return selectLeft;
      case 10: return selectRight;
      case 11: return selectUp;
      case 12: return selectDown;
      case 13: return selectLineStart;
      case 14: return selectLineEnd;
      case 15: return selectPageUp;
      case 16: return selectPageDown;
      case 17: return selectAll;
      case 18: return backspace;
      case 19: return deleteForward;
      case 20: return insertTab;
      case 21: return insertNewline;
      case 22: return insertLineAbove;
      case 23: return insertLineBelow;
      case 24: return undo;
      case 25: return redo;
      case 26: return moveLineUp;
      case 27: return moveLineDown;
      case 28: return copyLineUp;
      case 29: return copyLineDown;
      case 30: return deleteLine;
      case 31: return copy;
      case 32: return paste;
      case 33: return cut;
      case 34: return triggerCompletion;
      default: return none;
    }
  }
}

class KeyCode {
  KeyCode._();
  static const int none = 0;
  static const int backspace = 8;
  static const int tab = 9;
  static const int enter = 13;
  static const int escape = 27;
  static const int deleteKey = 46;
  static const int left = 37;
  static const int up = 38;
  static const int right = 39;
  static const int down = 40;
  static const int home = 36;
  static const int end = 35;
  static const int pageUp = 33;
  static const int pageDown = 34;
  static const int a = 65;
  static const int c = 67;
  static const int d = 68;
  static const int v = 86;
  static const int x = 88;
  static const int z = 90;
  static const int y = 89;
  static const int k = 75;
  static const int space = 32;
}

class KeyModifier {
  KeyModifier._();
  static const int none = 0;
  static const int shift = 1;
  static const int ctrl = 2;
  static const int alt = 4;
  static const int meta = 8;
}

class KeyBinding {
  const KeyBinding({
    this.first = const KeyChord(),
    this.second = const KeyChord(),
    this.command = 0,
  });

  final KeyChord first;
  final KeyChord second;
  final int command;
}

class KeyChord {
  const KeyChord({
    this.modifiers = 0,
    this.keyCode = 0,
  });

  final int modifiers;
  final int keyCode;
}
