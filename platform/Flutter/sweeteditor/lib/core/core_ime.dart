// ignore_for_file: unused_element

part of 'editor_core.dart';

enum CaretAffinity {
  downstream(0),
  upstream(1);

  const CaretAffinity(this.value);
  final int value;

  static CaretAffinity fromValue(int value) {
    switch (value) {
      case 0: return downstream;
      case 1: return upstream;
      default: throw ArgumentError.value(value, 'value', 'Unknown CaretAffinity value');
    }
  }
}

enum ImeCommandKind {
  setSelection(0),
  beginComposition(1),
  updateComposition(2),
  commitText(3),
  finishComposition(4),
  cancelComposition(5),
  deleteSurrounding(6);

  const ImeCommandKind(this.value);
  final int value;

  static ImeCommandKind fromValue(int value) {
    switch (value) {
      case 0: return setSelection;
      case 1: return beginComposition;
      case 2: return updateComposition;
      case 3: return commitText;
      case 4: return finishComposition;
      case 5: return cancelComposition;
      case 6: return deleteSurrounding;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeCommandKind value');
    }
  }
}

enum ImeCoordinateSpace {
  document(0),
  editingBuffer(1),
  contextSlice(2),
  composition(3);

  const ImeCoordinateSpace(this.value);
  final int value;

  static ImeCoordinateSpace fromValue(int value) {
    switch (value) {
      case 0: return document;
      case 1: return editingBuffer;
      case 2: return contextSlice;
      case 3: return composition;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeCoordinateSpace value');
    }
  }
}

enum ImeHostAction {
  none(0),
  closeSession(1),
  restartSession(2);

  const ImeHostAction(this.value);
  final int value;

  static ImeHostAction fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return closeSession;
      case 2: return restartSession;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeHostAction value');
    }
  }
}

enum ImeMutationModel {
  command(0),
  textUpdate(1);

  const ImeMutationModel(this.value);
  final int value;

  static ImeMutationModel fromValue(int value) {
    switch (value) {
      case 0: return command;
      case 1: return textUpdate;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeMutationModel value');
    }
  }
}

enum ImeResultCode {
  ok(0),
  sessionMismatch(1),
  rejected(2),
  readOnly(3);

  const ImeResultCode(this.value);
  final int value;

  static ImeResultCode fromValue(int value) {
    switch (value) {
      case 0: return ok;
      case 1: return sessionMismatch;
      case 2: return rejected;
      case 3: return readOnly;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeResultCode value');
    }
  }
}

enum ImeTextSource {
  editing(0),
  committed(1),
  editingBuffer(2);

  const ImeTextSource(this.value);
  final int value;

  static ImeTextSource fromValue(int value) {
    switch (value) {
      case 0: return editing;
      case 1: return committed;
      case 2: return editingBuffer;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeTextSource value');
    }
  }
}

enum ImeTextUnit {
  utf16CodeUnit(0),
  unicodeCodePoint(1);

  const ImeTextUnit(this.value);
  final int value;

  static ImeTextUnit fromValue(int value) {
    switch (value) {
      case 0: return utf16CodeUnit;
      case 1: return unicodeCodePoint;
      default: throw ArgumentError.value(value, 'value', 'Unknown ImeTextUnit value');
    }
  }
}

class ImeCommand {
  const ImeCommand({
    this.kind = ImeCommandKind.setSelection,
    this.targetRange = const ImeOffsetRange(),
    this.selectionAfter = const ImeSelection(),
    this.text = '',
    this.deleteBefore = 0,
    this.deleteAfter = 0,
    this.textUnit = ImeTextUnit.utf16CodeUnit,
  });

  final ImeCommandKind kind;
  final ImeOffsetRange targetRange;
  final ImeSelection selectionAfter;
  final String text;
  final int deleteBefore;
  final int deleteAfter;
  final ImeTextUnit textUnit;
}

class ImeCommandBatch {
  const ImeCommandBatch({
    this.sessionId = 0,
    this.commands = const [],
  });

  final int sessionId;
  final List<ImeCommand> commands;
}

class ImeOffsetRange {
  const ImeOffsetRange({
    this.coordinateSpace = ImeCoordinateSpace.document,
    this.startUtf16 = -1,
    this.endUtf16 = -1,
  });

  final ImeCoordinateSpace coordinateSpace;
  final int startUtf16;
  final int endUtf16;
}

class ImeSelection {
  const ImeSelection({
    this.coordinateSpace = ImeCoordinateSpace.document,
    this.anchorUtf16 = -1,
    this.activeUtf16 = -1,
    this.affinity = CaretAffinity.downstream,
  });

  final ImeCoordinateSpace coordinateSpace;
  final int anchorUtf16;
  final int activeUtf16;
  final CaretAffinity affinity;
}

class ImeState {
  const ImeState({
    this.resultCode = ImeResultCode.ok,
    this.sessionId = 0,
    this.stateRevision = 0,
    this.selection = const ImeSelection(),
    this.compositionRange = const ImeOffsetRange(),
  });

  final ImeResultCode resultCode;
  final int sessionId;
  final int stateRevision;
  final ImeSelection selection;
  final ImeOffsetRange compositionRange;
}

class ImeTextContext {
  const ImeTextContext({
    this.resultCode = ImeResultCode.ok,
    this.sliceStartUtf16 = 0,
    this.totalLengthUtf16 = 0,
    this.text = '',
    this.selection = const ImeSelection(),
    this.compositionRange = const ImeOffsetRange(),
  });

  final ImeResultCode resultCode;
  final int sliceStartUtf16;
  final int totalLengthUtf16;
  final String text;
  final ImeSelection selection;
  final ImeOffsetRange compositionRange;
}

class ImeTextUpdateBatch {
  const ImeTextUpdateBatch({
    this.sessionId = 0,
    this.expectedStateRevision = 0,
    this.steps = const [],
  });

  final int sessionId;
  final int expectedStateRevision;
  final List<ImeTextUpdateStep> steps;
}

class ImeTextUpdateStep {
  const ImeTextUpdateStep({
    this.oldText = '',
    this.patchRange = const ImeOffsetRange(),
    this.replacementText = '',
    this.selectionAfter = const ImeSelection(),
    this.compositionAfter = const ImeOffsetRange(),
  });

  final String oldText;
  final ImeOffsetRange patchRange;
  final String replacementText;
  final ImeSelection selectionAfter;
  final ImeOffsetRange compositionAfter;
}
