import '../core/editor_core.dart' as core;
import '../editor_types.dart';

enum DecorationType {
  syntaxHighlight,
  semanticHighlight,
  overlayHighlight,
  inlayHint,
  diagnostic,
  documentHighlight,
  foldRegion,
  indentGuide,
  bracketGuide,
  flowGuide,
  separatorGuide,
  gutterIcon,
  phantomText,
  codeLens,
  link,
}

class DecorationContext {
  const DecorationContext({
    required this.visibleLineRange,
    required this.totalLineCount,
    required this.textChanges,
    this.languageConfiguration,
    this.editorMetadata,
  });

  final core.IntRange visibleLineRange;
  final int totalLineCount;
  final List<core.TextChange> textChanges;
  final LanguageConfiguration? languageConfiguration;
  final EditorMetadata? editorMetadata;
}

abstract class DecorationReceiver {
  bool accept(DecorationResult result);
  bool isCancelled();
}

abstract class DecorationProvider {
  Set<DecorationType> getCapabilities();
  void provideDecorations(
    DecorationContext context,
    DecorationReceiver receiver,
  );
  void dispose();
}

enum ApplyMode { merge, replaceAll, replaceRange }

/// Decoration result returned by a provider.
class DecorationResult {
  Map<int, List<core.StyleSpan>>? syntaxSpans;
  Map<int, List<core.StyleSpan>>? semanticSpans;
  Map<int, List<core.StyleSpan>>? overlaySpans;
  Map<int, List<core.InlayHint>>? inlayHints;
  Map<int, List<core.Diagnostic>>? diagnostics;
  Map<int, List<core.DocumentHighlight>>? documentHighlights;
  List<core.IndentGuide>? indentGuides;
  List<core.BracketGuide>? bracketGuides;
  List<core.FlowGuide>? flowGuides;
  List<core.SeparatorGuide>? separatorGuides;
  List<core.FoldRegion>? foldRegions;
  Map<int, List<core.GutterIcon>>? gutterIcons;
  Map<int, List<core.PhantomText>>? phantomTexts;
  Map<int, List<core.CodeLensItem>>? codeLensItems;
  Map<int, List<core.LinkSpan>>? links;
  ApplyMode syntaxSpansMode = ApplyMode.merge;
  ApplyMode semanticSpansMode = ApplyMode.merge;
  ApplyMode overlaySpansMode = ApplyMode.merge;
  ApplyMode inlayHintsMode = ApplyMode.merge;
  ApplyMode diagnosticsMode = ApplyMode.merge;
  ApplyMode documentHighlightsMode = ApplyMode.merge;
  ApplyMode indentGuidesMode = ApplyMode.merge;
  ApplyMode bracketGuidesMode = ApplyMode.merge;
  ApplyMode flowGuidesMode = ApplyMode.merge;
  ApplyMode separatorGuidesMode = ApplyMode.merge;
  ApplyMode foldRegionsMode = ApplyMode.merge;
  ApplyMode gutterIconsMode = ApplyMode.merge;
  ApplyMode phantomTextsMode = ApplyMode.merge;
  ApplyMode codeLensItemsMode = ApplyMode.merge;
  ApplyMode linksMode = ApplyMode.merge;

  DecorationResult copy() {
    final out = DecorationResult()
      ..syntaxSpans = _copyMap(syntaxSpans)
      ..semanticSpans = _copyMap(semanticSpans)
      ..overlaySpans = _copyMap(overlaySpans)
      ..inlayHints = _copyMap(inlayHints)
      ..diagnostics = _copyMap(diagnostics)
      ..documentHighlights = _copyMap(documentHighlights)
      ..indentGuides = indentGuides != null ? List.of(indentGuides!) : null
      ..bracketGuides = bracketGuides != null ? List.of(bracketGuides!) : null
      ..flowGuides = flowGuides != null ? List.of(flowGuides!) : null
      ..separatorGuides = separatorGuides != null
          ? List.of(separatorGuides!)
          : null
      ..foldRegions = foldRegions != null ? List.of(foldRegions!) : null
      ..gutterIcons = _copyMap(gutterIcons)
      ..phantomTexts = _copyMap(phantomTexts)
      ..codeLensItems = _copyMap(codeLensItems)
      ..links = _copyMap(links)
      ..syntaxSpansMode = syntaxSpansMode
      ..semanticSpansMode = semanticSpansMode
      ..overlaySpansMode = overlaySpansMode
      ..inlayHintsMode = inlayHintsMode
      ..diagnosticsMode = diagnosticsMode
      ..documentHighlightsMode = documentHighlightsMode
      ..indentGuidesMode = indentGuidesMode
      ..bracketGuidesMode = bracketGuidesMode
      ..flowGuidesMode = flowGuidesMode
      ..separatorGuidesMode = separatorGuidesMode
      ..foldRegionsMode = foldRegionsMode
      ..gutterIconsMode = gutterIconsMode
      ..phantomTextsMode = phantomTextsMode
      ..codeLensItemsMode = codeLensItemsMode
      ..linksMode = linksMode;
    return out;
  }

  static Map<int, List<T>>? _copyMap<T>(Map<int, List<T>>? source) {
    if (source == null) return null;
    return {for (final e in source.entries) e.key: List.of(e.value)};
  }
}

/// Builder for constructing a [DecorationResult].
class DecorationResultBuilder {
  final DecorationResult _result = DecorationResult();

  DecorationResultBuilder syntaxSpans(
    Map<int, List<core.StyleSpan>>? value,
    ApplyMode mode,
  ) {
    _result.syntaxSpans = value;
    _result.syntaxSpansMode = mode;
    return this;
  }

  DecorationResultBuilder semanticSpans(
    Map<int, List<core.StyleSpan>>? value,
    ApplyMode mode,
  ) {
    _result.semanticSpans = value;
    _result.semanticSpansMode = mode;
    return this;
  }

  DecorationResultBuilder overlaySpans(
    Map<int, List<core.StyleSpan>>? value,
    ApplyMode mode,
  ) {
    _result.overlaySpans = value;
    _result.overlaySpansMode = mode;
    return this;
  }

  DecorationResultBuilder inlayHints(
    Map<int, List<core.InlayHint>>? value,
    ApplyMode mode,
  ) {
    _result.inlayHints = value;
    _result.inlayHintsMode = mode;
    return this;
  }

  DecorationResultBuilder diagnostics(
    Map<int, List<core.Diagnostic>>? value,
    ApplyMode mode,
  ) {
    _result.diagnostics = value;
    _result.diagnosticsMode = mode;
    return this;
  }

  DecorationResultBuilder documentHighlights(
    Map<int, List<core.DocumentHighlight>>? value,
    ApplyMode mode,
  ) {
    _result.documentHighlights = value;
    _result.documentHighlightsMode = mode;
    return this;
  }

  DecorationResultBuilder indentGuides(
    List<core.IndentGuide>? value,
    ApplyMode mode,
  ) {
    _result.indentGuides = value;
    _result.indentGuidesMode = mode;
    return this;
  }

  DecorationResultBuilder bracketGuides(
    List<core.BracketGuide>? value,
    ApplyMode mode,
  ) {
    _result.bracketGuides = value;
    _result.bracketGuidesMode = mode;
    return this;
  }

  DecorationResultBuilder flowGuides(
    List<core.FlowGuide>? value,
    ApplyMode mode,
  ) {
    _result.flowGuides = value;
    _result.flowGuidesMode = mode;
    return this;
  }

  DecorationResultBuilder separatorGuides(
    List<core.SeparatorGuide>? value,
    ApplyMode mode,
  ) {
    _result.separatorGuides = value;
    _result.separatorGuidesMode = mode;
    return this;
  }

  DecorationResultBuilder foldRegions(
    List<core.FoldRegion>? value,
    ApplyMode mode,
  ) {
    _result.foldRegions = value;
    _result.foldRegionsMode = mode;
    return this;
  }

  DecorationResultBuilder gutterIcons(
    Map<int, List<core.GutterIcon>>? value,
    ApplyMode mode,
  ) {
    _result.gutterIcons = value;
    _result.gutterIconsMode = mode;
    return this;
  }

  DecorationResultBuilder phantomTexts(
    Map<int, List<core.PhantomText>>? value,
    ApplyMode mode,
  ) {
    _result.phantomTexts = value;
    _result.phantomTextsMode = mode;
    return this;
  }

  DecorationResultBuilder codeLensItems(
    Map<int, List<core.CodeLensItem>>? value,
    ApplyMode mode,
  ) {
    _result.codeLensItems = value;
    _result.codeLensItemsMode = mode;
    return this;
  }

  DecorationResultBuilder links(
    Map<int, List<core.LinkSpan>>? value,
    ApplyMode mode,
  ) {
    _result.links = value;
    _result.linksMode = mode;
    return this;
  }

  DecorationResult build() => _result;
}
