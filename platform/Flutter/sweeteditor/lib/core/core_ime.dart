// ignore_for_file: unused_element

part of 'editor_core.dart';

enum ImeCommandKind {
  setSelection(0),
  setPreeditText(1),
  commitText(2),
  finishPreedit(3),
  cancelPreedit(4),
  setMarkedRange(5),
  clearMarkedRange(6),
  replaceText(7),
  deleteSurroundingText(8),
  setKeyboardScript(9);

  const ImeCommandKind(this.value);
  final int value;

  static ImeCommandKind fromValue(int value) {
    switch (value) {
      case 0: return setSelection;
      case 1: return setPreeditText;
      case 2: return commitText;
      case 3: return finishPreedit;
      case 4: return cancelPreedit;
      case 5: return setMarkedRange;
      case 6: return clearMarkedRange;
      case 7: return replaceText;
      case 8: return deleteSurroundingText;
      case 9: return setKeyboardScript;
      default: return setSelection;
    }
  }
}

enum ImeContextPolicy {
  none(0),
  limitedForCandidates(1);

  const ImeContextPolicy(this.value);
  final int value;

  static ImeContextPolicy fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return limitedForCandidates;
      default: return none;
    }
  }
}

enum ImeInputContextKind {
  none(0),
  selectionOnly(1),
  documentWindow(2),
  transientInput(3);

  const ImeInputContextKind(this.value);
  final int value;

  static ImeInputContextKind fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return selectionOnly;
      case 2: return documentWindow;
      case 3: return transientInput;
      default: return none;
    }
  }
}

enum ImeMarkedRangeRole {
  none(0),
  preedit(1),
  systemMark(2);

  const ImeMarkedRangeRole(this.value);
  final int value;

  static ImeMarkedRangeRole fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return preedit;
      case 2: return systemMark;
      default: return none;
    }
  }
}

enum ImeScriptClass {
  unknown(0),
  latin(1),
  cjk(2),
  kana(3),
  hangul(4);

  const ImeScriptClass(this.value);
  final int value;

  static ImeScriptClass fromValue(int value) {
    switch (value) {
      case 0: return unknown;
      case 1: return latin;
      case 2: return cjk;
      case 3: return kana;
      case 4: return hangul;
      default: return unknown;
    }
  }
}

enum ImeTextUnit {
  grapheme(0),
  codePoint(1);

  const ImeTextUnit(this.value);
  final int value;

  static ImeTextUnit fromValue(int value) {
    switch (value) {
      case 0: return grapheme;
      case 1: return codePoint;
      default: return grapheme;
    }
  }
}

enum ImeTextUpdateKind {
  snapshot(0),
  patch(1);

  const ImeTextUpdateKind(this.value);
  final int value;

  static ImeTextUpdateKind fromValue(int value) {
    switch (value) {
      case 0: return snapshot;
      case 1: return patch;
      default: return snapshot;
    }
  }
}

enum ImeTextUpdateScope {
  documentWindow(0),
  transientInput(1);

  const ImeTextUpdateScope(this.value);
  final int value;

  static ImeTextUpdateScope fromValue(int value) {
    switch (value) {
      case 0: return documentWindow;
      case 1: return transientInput;
      default: return documentWindow;
    }
  }
}

class ImeCommandMessage {
  const ImeCommandMessage({
    this.kind = ImeCommandKind.setSelection,
    this.contextId = 0,
    this.contextRevision = 0,
    this.documentStartOffset = 0,
    this.range = const ImeOffsetRange(),
    this.selection = const ImeOffsetRange(),
    this.text = '',
    this.cursorOffset = 1,
    this.deleteBefore = 0,
    this.deleteAfter = 0,
    this.textUnit = ImeTextUnit.grapheme,
    this.markedRole = ImeMarkedRangeRole.none,
    this.scriptClass = ImeScriptClass.unknown,
  });

  final ImeCommandKind kind;
  final int contextId;
  final int contextRevision;
  final int documentStartOffset;
  final ImeOffsetRange range;
  final ImeOffsetRange selection;
  final String text;
  final int cursorOffset;
  final int deleteBefore;
  final int deleteAfter;
  final ImeTextUnit textUnit;
  final ImeMarkedRangeRole markedRole;
  final ImeScriptClass scriptClass;
}

class ImeInputContext {
  const ImeInputContext({
    this.id = 0,
    this.revision = 0,
    this.documentStartOffset = 0,
    this.text = '',
    this.selection = const ImeOffsetRange(),
    this.hasPreeditRange = false,
    this.preeditRange = const ImeOffsetRange(),
    this.hasSystemMarkRange = false,
    this.systemMarkRange = const ImeOffsetRange(),
    this.kind = ImeInputContextKind.none,
  });

  final int id;
  final int revision;
  final int documentStartOffset;
  final String text;
  final ImeOffsetRange selection;
  final bool hasPreeditRange;
  final ImeOffsetRange preeditRange;
  final bool hasSystemMarkRange;
  final ImeOffsetRange systemMarkRange;
  final ImeInputContextKind kind;
}

class ImeMarkedRange {
  const ImeMarkedRange({
    this.role = ImeMarkedRangeRole.none,
    this.range = const ImeOffsetRange(),
  });

  final ImeMarkedRangeRole role;
  final ImeOffsetRange range;
}

class ImeOffsetRange {
  const ImeOffsetRange({
    this.start = 0,
    this.end = 0,
  });

  final int start;
  final int end;
}

class ImeSyncSnapshot {
  const ImeSyncSnapshot({
    this.cursor = const TextPosition(),
    this.selection = const TextRange(),
    this.hasSelection = false,
    this.hasPreeditRange = false,
    this.preeditRange = const TextRange(),
    this.hasSystemMarkRange = false,
    this.systemMarkRange = const TextRange(),
    this.contextPolicy = ImeContextPolicy.none,
    this.clearSystemMark = false,
  });

  final TextPosition cursor;
  final TextRange selection;
  final bool hasSelection;
  final bool hasPreeditRange;
  final TextRange preeditRange;
  final bool hasSystemMarkRange;
  final TextRange systemMarkRange;
  final ImeContextPolicy contextPolicy;
  final bool clearSystemMark;
}

class ImeTextPatch {
  const ImeTextPatch({
    this.range = const ImeOffsetRange(),
    this.text = '',
  });

  final ImeOffsetRange range;
  final String text;
}

class ImeTextUpdateMessage {
  const ImeTextUpdateMessage({
    this.kind = ImeTextUpdateKind.snapshot,
    this.scope = ImeTextUpdateScope.documentWindow,
    this.contextId = 0,
    this.contextRevision = 0,
    this.documentStartOffset = 0,
    this.text = '',
    this.patch = const ImeTextPatch(),
    this.selection = const ImeOffsetRange(),
    this.markedRange = const ImeMarkedRange(),
    this.scriptClass = ImeScriptClass.unknown,
  });

  final ImeTextUpdateKind kind;
  final ImeTextUpdateScope scope;
  final int contextId;
  final int contextRevision;
  final int documentStartOffset;
  final String text;
  final ImeTextPatch patch;
  final ImeOffsetRange selection;
  final ImeMarkedRange markedRange;
  final ImeScriptClass scriptClass;
}
