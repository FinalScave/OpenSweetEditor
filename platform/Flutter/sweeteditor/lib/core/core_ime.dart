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

class ImeInputContext {
  const ImeInputContext({
    this.id = 0,
    this.revision = 0,
    this.documentStartOffset = 0,
    this.text = '',
    this.selection = const ImeTextRange(),
    this.hasComposition = false,
    this.composition = const ImeTextRange(),
    this.kind = ImeInputContextKind.none,
  });

  final int id;
  final int revision;
  final int documentStartOffset;
  final String text;
  final ImeTextRange selection;
  final bool hasComposition;
  final ImeTextRange composition;
  final ImeInputContextKind kind;
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

class ImeTextRange {
  const ImeTextRange({
    this.start = 0,
    this.end = 0,
  });

  final int start;
  final int end;
}
