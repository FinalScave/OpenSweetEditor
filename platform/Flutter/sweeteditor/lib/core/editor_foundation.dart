part of '../editor_core.dart';

/// Text position in document (0-based line/column).
class TextPosition {
  const TextPosition(this.line, this.column);

  final int line;
  final int column;

  @override
  String toString() => 'TextPosition(line: $line, column: $column)';
}

/// Text range in document.
class TextRange {
  const TextRange(this.start, this.end);

  final TextPosition start;
  final TextPosition end;

  @override
  String toString() => 'TextRange(start: $start, end: $end)';
}

/// Inclusive integer range.
class IntRange {
  const IntRange(this.start, this.end);

  final int start;
  final int end;

  bool get isEmpty => end < start;

  bool contains(int value) => !isEmpty && value >= start && value <= end;

  int get length => isEmpty ? 0 : (end - start + 1);

  @override
  String toString() => 'IntRange(start: $start, end: $end)';
}

/// Fold arrow display mode.
enum FoldArrowMode {
  auto_(0),
  always(1),
  hidden(2);

  const FoldArrowMode(this.value);
  final int value;
}

/// Wrap mode.
enum WrapMode {
  none(0),
  charBreak(1),
  wordBreak(2);

  const WrapMode(this.value);
  final int value;
}

/// Auto indent mode.
enum AutoIndentMode {
  none(0),
  keepIndent(1);

  const AutoIndentMode(this.value);
  final int value;
}

/// Current line render mode.
enum CurrentLineRenderMode {
  background(0),
  border(1),
  none(2);

  const CurrentLineRenderMode(this.value);
  final int value;
}

/// Scroll behavior.
enum ScrollBehavior {
  top(0),
  center(1),
  bottom(2);

  const ScrollBehavior(this.value);
  final int value;
}

/// Unit used by IME delete requests.
enum ImeTextUnit {
  grapheme(0),
  codePoint(1);

  const ImeTextUnit(this.value);
  final int value;
}

/// Platform text model shape used by IME state synchronization.
enum ImeTextModelMode {
  documentWindow(0),
  transientInput(1);

  const ImeTextModelMode(this.value);
  final int value;
}

/// Shape of an IME input context returned by the core.
enum ImeInputContextKind {
  none(0),
  selectionOnly(1),
  documentWindow(2),
  transientInput(3);

  const ImeInputContextKind(this.value);
  final int value;

  static ImeInputContextKind fromValue(int value) => ImeInputContextKind.values
      .firstWhere((e) => e.value == value, orElse: () => none);
}

class ImeTextRange {
  const ImeTextRange(this.start, this.end);

  static const empty = ImeTextRange(0, 0);
  static const none = ImeTextRange(-1, -1);

  final int start;
  final int end;
}

/// Script class hint reported by platform IMEs.
enum ImeScriptClass {
  unknown(0),
  latin(1),
  cjk(2),
  kana(3),
  hangul(4);

  const ImeScriptClass(this.value);
  final int value;

  static ImeScriptClass fromValue(int value) => ImeScriptClass.values
      .firstWhere((e) => e.value == value, orElse: () => unknown);
}

/// Where the current IME preedit is stored.
enum ImePreeditStorage {
  none(0),
  visibleDocumentComposition(1),
  shadowOnly(2);

  const ImePreeditStorage(this.value);
  final int value;

  static ImePreeditStorage fromValue(int value) => ImePreeditStorage.values
      .firstWhere((e) => e.value == value, orElse: () => none);
}

/// Platform text context policy requested by the core IME state.
enum ImeContextPolicy {
  none(0),
  limitedForCandidates(1);

  const ImeContextPolicy(this.value);
  final int value;

  static ImeContextPolicy fromValue(int value) => ImeContextPolicy.values
      .firstWhere((e) => e.value == value, orElse: () => none);
}

/// Snapshot used to synchronize Flutter's platform text input state.
class ImeSyncSnapshot {
  const ImeSyncSnapshot({
    this.cursor = const TextPosition(0, 0),
    this.hasSelection = false,
    this.selection = const TextRange(TextPosition(0, 0), TextPosition(0, 0)),
    this.hasComposingSession = false,
    this.hasVisibleCompositionRange = false,
    this.visibleCompositionRange = const TextRange(
      TextPosition(0, 0),
      TextPosition(0, 0),
    ),
    this.hasPlatformMarkedRange = false,
    this.platformMarkedRange = const TextRange(
      TextPosition(0, 0),
      TextPosition(0, 0),
    ),
    this.platformTextWindowText = '',
    this.platformTextWindowStartOffset = 0,
    this.platformTextWindowSelectionStartOffset = 0,
    this.platformTextWindowSelectionEndOffset = 0,
    this.platformTextWindowComposingStartOffset = -1,
    this.platformTextWindowComposingEndOffset = -1,
    this.preeditStorage = ImePreeditStorage.none,
    this.contextPolicy = ImeContextPolicy.none,
    this.clearPlatformPreedit = false,
  });

  static const ImeSyncSnapshot empty = ImeSyncSnapshot();

  final TextPosition cursor;
  final bool hasSelection;
  final TextRange selection;
  final bool hasComposingSession;
  final bool hasVisibleCompositionRange;
  final TextRange visibleCompositionRange;
  final bool hasPlatformMarkedRange;
  final TextRange platformMarkedRange;
  final String platformTextWindowText;
  final int platformTextWindowStartOffset;
  final int platformTextWindowSelectionStartOffset;
  final int platformTextWindowSelectionEndOffset;
  final int platformTextWindowComposingStartOffset;
  final int platformTextWindowComposingEndOffset;
  final ImePreeditStorage preeditStorage;
  final ImeContextPolicy contextPolicy;
  final bool clearPlatformPreedit;
}

class ImeInputContext {
  const ImeInputContext({
    this.id = 0,
    this.revision = 0,
    this.documentStartOffset = 0,
    this.text = '',
    this.selection = ImeTextRange.empty,
    this.hasComposition = false,
    this.composition = ImeTextRange.none,
    this.kind = ImeInputContextKind.none,
  });

  static const empty = ImeInputContext();

  final int id;
  final int revision;
  final int documentStartOffset;
  final String text;
  final ImeTextRange selection;
  final bool hasComposition;
  final ImeTextRange composition;
  final ImeInputContextKind kind;
}

/// Result of a semantic IME action handled by the native editor core.
class ImeActionResult {
  const ImeActionResult({
    this.handled = false,
    this.contentChanged = false,
    this.cursorChanged = false,
    this.selectionChanged = false,
    this.editResult = TextEditResult.empty,
    this.sync = ImeSyncSnapshot.empty,
  });

  static const ImeActionResult empty = ImeActionResult();

  final bool handled;
  final bool contentChanged;
  final bool cursorChanged;
  final bool selectionChanged;
  final TextEditResult editResult;
  final ImeSyncSnapshot sync;
}
