// ignore_for_file: unused_element

part of 'editor_core.dart';

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

enum ImePreeditStorage {
  none(0),
  visibleDocumentComposition(1),
  shadowOnly(2);

  const ImePreeditStorage(this.value);
  final int value;

  static ImePreeditStorage fromValue(int value) {
    switch (value) {
      case 0: return none;
      case 1: return visibleDocumentComposition;
      case 2: return shadowOnly;
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

enum ImeTextModelMode {
  documentWindow(0),
  transientInput(1);

  const ImeTextModelMode(this.value);
  final int value;

  static ImeTextModelMode fromValue(int value) {
    switch (value) {
      case 0: return documentWindow;
      case 1: return transientInput;
      default: return documentWindow;
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

class ImeDocumentTextReplacement {
  const ImeDocumentTextReplacement({
    this.startOffset = 0,
    this.endOffset = 0,
    this.text = '',
    this.cursorOffset = 1,
    this.scriptClass = ImeScriptClass.unknown,
  });

  final int startOffset;
  final int endOffset;
  final String text;
  final int cursorOffset;
  final ImeScriptClass scriptClass;
}

class ImeInputContext {
  const ImeInputContext({
    this.id = 0,
    this.revision = 0,
    this.documentStartOffset = 0,
    this.text = '',
    this.selection = const ImeOffsetRange(),
    this.hasComposition = false,
    this.composition = const ImeOffsetRange(),
    this.kind = ImeInputContextKind.none,
  });

  final int id;
  final int revision;
  final int documentStartOffset;
  final String text;
  final ImeOffsetRange selection;
  final bool hasComposition;
  final ImeOffsetRange composition;
  final ImeInputContextKind kind;
}

class ImeInputContextTextReplacement {
  const ImeInputContextTextReplacement({
    this.startOffset = 0,
    this.endOffset = 0,
    this.text = '',
    this.cursorOffset = 1,
    this.scriptClass = ImeScriptClass.unknown,
  });

  final int startOffset;
  final int endOffset;
  final String text;
  final int cursorOffset;
  final ImeScriptClass scriptClass;
}

class ImeInputStateTextReplacement {
  const ImeInputStateTextReplacement({
    this.contextId = 0,
    this.documentStartOffset = 0,
    this.startOffset = 0,
    this.endOffset = 0,
    this.text = '',
    this.cursorOffset = 1,
    this.scriptClass = ImeScriptClass.unknown,
  });

  final int contextId;
  final int documentStartOffset;
  final int startOffset;
  final int endOffset;
  final String text;
  final int cursorOffset;
  final ImeScriptClass scriptClass;
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
    this.hasComposingSession = false,
    this.hasVisibleCompositionRange = false,
    this.visibleCompositionRange = const TextRange(),
    this.hasPlatformMarkedRange = false,
    this.platformMarkedRange = const TextRange(),
    this.preeditStorage = ImePreeditStorage.none,
    this.contextPolicy = ImeContextPolicy.none,
    this.clearPlatformPreedit = false,
  });

  final TextPosition cursor;
  final TextRange selection;
  final bool hasSelection;
  final bool hasComposingSession;
  final bool hasVisibleCompositionRange;
  final TextRange visibleCompositionRange;
  final bool hasPlatformMarkedRange;
  final TextRange platformMarkedRange;
  final ImePreeditStorage preeditStorage;
  final ImeContextPolicy contextPolicy;
  final bool clearPlatformPreedit;
}

class ImeTextModelDelta {
  const ImeTextModelDelta({
    this.mode = ImeTextModelMode.documentWindow,
    this.contextId = 0,
    this.documentStartOffset = 0,
    this.oldText = '',
    this.delta = const ImeOffsetRange(),
    this.deltaText = '',
    this.selection = const ImeOffsetRange(),
    this.composition = const ImeOffsetRange(),
    this.scriptClass = ImeScriptClass.unknown,
  });

  final ImeTextModelMode mode;
  final int contextId;
  final int documentStartOffset;
  final String oldText;
  final ImeOffsetRange delta;
  final String deltaText;
  final ImeOffsetRange selection;
  final ImeOffsetRange composition;
  final ImeScriptClass scriptClass;
}

class ImeTextModelState {
  const ImeTextModelState({
    this.mode = ImeTextModelMode.documentWindow,
    this.contextId = 0,
    this.documentStartOffset = 0,
    this.text = '',
    this.selection = const ImeOffsetRange(),
    this.composition = const ImeOffsetRange(),
    this.scriptClass = ImeScriptClass.unknown,
  });

  final ImeTextModelMode mode;
  final int contextId;
  final int documentStartOffset;
  final String text;
  final ImeOffsetRange selection;
  final ImeOffsetRange composition;
  final ImeScriptClass scriptClass;
}

class ImeTextReplacement {
  const ImeTextReplacement({
    this.range = const TextRange(),
    this.text = '',
    this.scriptClass = ImeScriptClass.unknown,
  });

  final TextRange range;
  final String text;
  final ImeScriptClass scriptClass;
}
