part of '../sweeteditor.dart';

class _ProviderState {
  DecorationResult? snapshot;
  _ManagedDecorationReceiver? activeReceiver;
}

/// Decoration provider manager.
/// Handles provider registration, refresh scheduling, debounce, scroll throttle,
/// overscan, result merging, and applying decorations to the editor.
class DecorationProviderManager {
  DecorationProviderManager({required this.session});

  final EditorSession session;

  final List<DecorationProvider> _providers = [];
  final Map<DecorationProvider, _ProviderState> _providerStates = {};
  final List<core.TextChange> _pendingTextChanges = [];
  int _generation = 0;
  bool _applyScheduled = false;
  core.IntRange _lastContextLineRange = const core.IntRange(start: 0, end: -1);
  List<core.IndentGuide> _appliedIndentGuides = const [];
  List<core.BracketGuide> _appliedBracketGuides = const [];
  List<core.FlowGuide> _appliedFlowGuides = const [];
  List<core.SeparatorGuide> _appliedSeparatorGuides = const [];
  List<core.FoldRegion> _appliedFoldRegions = const [];
  bool _pendingScrollRefresh = false;
  int _lastScrollRefreshTimeMs = 0;
  bool _disposed = false;
  Timer? _refreshTimer;
  Timer? _scrollRefreshTimer;
  Timer? _applyTimer;

  void addProvider(DecorationProvider provider) {
    if (_disposed) return;
    if (!_providers.contains(provider)) {
      _providers.add(provider);
      _providerStates[provider] = _ProviderState();
      requestRefresh();
    }
  }

  void removeProvider(DecorationProvider provider) {
    final removed = _providers.remove(provider);
    if (!removed) return;
    final state = _providerStates[provider];
    state?.activeReceiver?.cancel();
    _providerStates.remove(provider);
    provider.dispose();
    _scheduleApply();
  }

  void requestRefresh() {
    if (_disposed) return;
    _scheduleRefresh(0, null);
  }

  void onDocumentLoaded() {
    if (_disposed) return;
    _scheduleRefresh(0, null);
  }

  void onTextChanged(List<core.TextChange> changes) {
    if (_disposed) return;
    _scheduleRefresh(50, changes);
  }

  void onScrollChanged() {
    if (_disposed) return;
    _scheduleScrollRefresh();
  }

  int get generation => _generation;

  void _scheduleRefresh(int delayMs, List<core.TextChange>? changes) {
    if (_disposed) return;
    if (changes != null) {
      _pendingTextChanges.addAll(changes);
    }
    _refreshTimer?.cancel();
    _refreshTimer = Timer(
      Duration(milliseconds: delayMs > 0 ? delayMs : 0),
      () {
        _refreshTimer = null;
        if (_disposed) return;
        _doRefresh();
      },
    );
  }

  void _scheduleScrollRefresh() {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastScrollRefreshTimeMs;
    final minInterval = session.settings
        .getDecorationScrollRefreshMinIntervalMs();
    final delay = elapsed >= minInterval ? 0 : (minInterval - elapsed);
    _pendingScrollRefresh = true;
    _scrollRefreshTimer?.cancel();
    _scrollRefreshTimer = Timer(Duration(milliseconds: delay), () {
      _scrollRefreshTimer = null;
      if (_disposed) {
        _pendingScrollRefresh = false;
        return;
      }
      if (!_pendingScrollRefresh) return;
      _pendingScrollRefresh = false;
      _doRefresh();
      _lastScrollRefreshTimeMs = DateTime.now().millisecondsSinceEpoch;
    });
  }

  void _doRefresh() {
    if (_disposed) return;
    _generation++;
    final currentGeneration = _generation;

    final visible = session.controller.getVisibleLineRange();
    final total = session.document?.lineCount ?? 0;
    final changes = List<core.TextChange>.of(_pendingTextChanges);
    _pendingTextChanges.clear();

    var contextStart = visible.start;
    var contextEnd = visible.end;
    if (total > 0 && visible.end >= visible.start) {
      final overscanLines = _calculateOverscanLines(visible.start, visible.end);
      contextStart = (visible.start - overscanLines).clamp(0, total - 1);
      contextEnd = (visible.end + overscanLines).clamp(0, total - 1);
    }
    _lastContextLineRange = core.IntRange(start: contextStart, end: contextEnd);

    final context = DecorationContext(
      visibleLineRange: _lastContextLineRange,
      totalLineCount: total,
      textChanges: changes,
      languageConfiguration: session.languageConfiguration,
      editorMetadata: session.metadata,
    );

    for (final provider in _providers) {
      var state = _providerStates[provider];
      if (state == null) {
        state = _ProviderState();
        _providerStates[provider] = state;
      }
      state.activeReceiver?.cancel();
      final receiver = _ManagedDecorationReceiver(
        provider,
        currentGeneration,
        this,
      );
      state.activeReceiver = receiver;
      try {
        provider.provideDecorations(context, receiver);
      } catch (_) {}
    }
  }

  void _scheduleApply() {
    if (_disposed) return;
    if (_applyScheduled) return;
    _applyScheduled = true;
    _applyTimer = Timer(Duration.zero, () {
      _applyTimer = null;
      if (_disposed) {
        _applyScheduled = false;
        return;
      }
      _applyMerged();
    });
  }

  void _applyMerged() {
    if (_disposed) return;
    _applyScheduled = false;

    final syntaxSpans = <int, List<core.StyleSpan>>{};
    final semanticSpans = <int, List<core.StyleSpan>>{};
    final overlaySpans = <int, List<core.StyleSpan>>{};
    final inlayHints = <int, List<core.InlayHint>>{};
    final diagnostics = <int, List<core.Diagnostic>>{};
    final documentHighlights = <int, List<core.DocumentHighlight>>{};
    List<core.IndentGuide>? indentGuides;
    List<core.BracketGuide>? bracketGuides;
    List<core.FlowGuide>? flowGuides;
    List<core.SeparatorGuide>? separatorGuides;
    List<core.FoldRegion>? foldRegions;
    final gutterIcons = <int, List<core.GutterIcon>>{};
    final phantomTexts = <int, List<core.PhantomText>>{};
    final codeLensItems = <int, List<core.CodeLensItem>>{};
    final links = <int, List<core.LinkSpan>>{};

    var syntaxMode = ApplyMode.merge;
    var semanticMode = ApplyMode.merge;
    var overlayMode = ApplyMode.merge;
    var inlayMode = ApplyMode.merge;
    var diagnosticMode = ApplyMode.merge;
    var documentHighlightMode = ApplyMode.merge;
    var indentMode = ApplyMode.merge;
    var bracketMode = ApplyMode.merge;
    var flowMode = ApplyMode.merge;
    var separatorMode = ApplyMode.merge;
    var foldMode = ApplyMode.merge;
    var gutterMode = ApplyMode.merge;
    var phantomMode = ApplyMode.merge;
    var codeLensMode = ApplyMode.merge;
    var linksMode = ApplyMode.merge;

    for (final provider in _providers) {
      final state = _providerStates[provider];
      if (state == null || state.snapshot == null) continue;
      final r = state.snapshot!;

      syntaxMode = _mergeMode(syntaxMode, r.syntaxSpansMode);
      if (r.syntaxSpans != null) {
        _appendMapOfArrays(syntaxSpans, r.syntaxSpans!);
      }
      semanticMode = _mergeMode(semanticMode, r.semanticSpansMode);
      if (r.semanticSpans != null) {
        _appendMapOfArrays(semanticSpans, r.semanticSpans!);
      }
      overlayMode = _mergeMode(overlayMode, r.overlaySpansMode);
      if (r.overlaySpans != null) {
        _appendMapOfArrays(overlaySpans, r.overlaySpans!);
      }
      inlayMode = _mergeMode(inlayMode, r.inlayHintsMode);
      if (r.inlayHints != null) {
        _appendMapOfArrays(inlayHints, r.inlayHints!);
      }
      diagnosticMode = _mergeMode(diagnosticMode, r.diagnosticsMode);
      if (r.diagnostics != null) {
        _appendMapOfArrays(diagnostics, r.diagnostics!);
      }
      documentHighlightMode = _mergeMode(
        documentHighlightMode,
        r.documentHighlightsMode,
      );
      if (r.documentHighlights != null) {
        _appendMapOfArrays(documentHighlights, r.documentHighlights!);
      }
      gutterMode = _mergeMode(gutterMode, r.gutterIconsMode);
      if (r.gutterIcons != null) {
        _appendMapOfArrays(gutterIcons, r.gutterIcons!);
      }
      phantomMode = _mergeMode(phantomMode, r.phantomTextsMode);
      if (r.phantomTexts != null) {
        _appendMapOfArrays(phantomTexts, r.phantomTexts!);
      }
      codeLensMode = _mergeMode(codeLensMode, r.codeLensItemsMode);
      if (r.codeLensItems != null) {
        _appendMapOfArrays(codeLensItems, r.codeLensItems!);
      }
      linksMode = _mergeMode(linksMode, r.linksMode);
      if (r.links != null) {
        _appendMapOfArrays(links, r.links!);
      }

      indentMode = _mergeMode(indentMode, r.indentGuidesMode);
      if (r.indentGuides != null) {
        (indentGuides ??= <core.IndentGuide>[]).addAll(r.indentGuides!);
      }
      bracketMode = _mergeMode(bracketMode, r.bracketGuidesMode);
      if (r.bracketGuides != null) {
        (bracketGuides ??= <core.BracketGuide>[]).addAll(r.bracketGuides!);
      }
      flowMode = _mergeMode(flowMode, r.flowGuidesMode);
      if (r.flowGuides != null) {
        (flowGuides ??= <core.FlowGuide>[]).addAll(r.flowGuides!);
      }
      separatorMode = _mergeMode(separatorMode, r.separatorGuidesMode);
      if (r.separatorGuides != null) {
        (separatorGuides ??= <core.SeparatorGuide>[]).addAll(
          r.separatorGuides!,
        );
      }
      foldMode = _mergeMode(foldMode, r.foldRegionsMode);
      if (r.foldRegions != null) {
        (foldRegions ??= <core.FoldRegion>[]).addAll(r.foldRegions!);
      }
    }

    _applySpanMode(0, syntaxMode);
    _applySpanMode(1, semanticMode);
    _applySpanMode(2, overlayMode);
    _setBatchLineSpans(0, syntaxSpans);
    _setBatchLineSpans(1, semanticSpans);
    _setBatchLineSpans(2, overlaySpans);

    _applyInlayMode(inlayMode);
    _setBatchLineInlayHints(inlayHints);

    _applyDiagnosticMode(diagnosticMode);
    _setBatchLineDiagnostics(diagnostics);

    _applyDocumentHighlightMode(documentHighlightMode);
    _setBatchLineDocumentHighlights(documentHighlights);

    _applyGuidesMode(indentMode, indentGuides, 0);
    _applyGuidesMode(bracketMode, bracketGuides, 1);
    _applyGuidesMode(flowMode, flowGuides, 2);
    _applyGuidesMode(separatorMode, separatorGuides, 3);

    final nextFoldRegions = _resolveRangeAppliedList(
      previous: _appliedFoldRegions,
      incoming: foldRegions,
      mode: foldMode,
      overlapsRange: _foldRegionOverlapsRange,
    );
    if (nextFoldRegions != null) {
      _appliedFoldRegions = nextFoldRegions;
      _setFoldRegions(nextFoldRegions);
    }

    _applyGutterMode(gutterMode);
    _setBatchLineGutterIcons(gutterIcons);

    _applyPhantomMode(phantomMode);
    _setBatchLinePhantomTexts(phantomTexts);

    _applyCodeLensMode(codeLensMode);
    _setBatchLineCodeLens(codeLensItems);

    _applyLinksMode(linksMode);
    _setBatchLineLinks(links);
  }

  void _applySpanMode(int layer, ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearHighlights(layer);
    } else if (mode == ApplyMode.replaceRange) {
      _clearSpanRange(
        layer,
        _lastContextLineRange.start,
        _lastContextLineRange.end,
      );
    }
  }

  void _applyInlayMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearInlayHints();
    } else if (mode == ApplyMode.replaceRange) {
      _clearInlayRange(_lastContextLineRange.start, _lastContextLineRange.end);
    }
  }

  void _applyDiagnosticMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearDiagnostics();
    } else if (mode == ApplyMode.replaceRange) {
      _clearDiagnosticRange(
        _lastContextLineRange.start,
        _lastContextLineRange.end,
      );
    }
  }

  void _applyDocumentHighlightMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearDocumentHighlights();
    } else if (mode == ApplyMode.replaceRange) {
      _clearDocumentHighlightRange(
        _lastContextLineRange.start,
        _lastContextLineRange.end,
      );
    }
  }

  void _applyGutterMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearGutterIcons();
    } else if (mode == ApplyMode.replaceRange) {
      _clearGutterRange(_lastContextLineRange.start, _lastContextLineRange.end);
    }
  }

  void _applyPhantomMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearPhantomTexts();
    } else if (mode == ApplyMode.replaceRange) {
      _clearPhantomRange(
        _lastContextLineRange.start,
        _lastContextLineRange.end,
      );
    }
  }

  void _applyCodeLensMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearCodeLens();
    } else if (mode == ApplyMode.replaceRange) {
      _clearCodeLensRange(
        _lastContextLineRange.start,
        _lastContextLineRange.end,
      );
    }
  }

  void _applyLinksMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearLinks();
    } else if (mode == ApplyMode.replaceRange) {
      _clearLinksRange(_lastContextLineRange.start, _lastContextLineRange.end);
    }
  }

  void _applyGuidesMode(ApplyMode mode, List<Object>? data, int guideType) {
    switch (guideType) {
      case 0:
        final nextIndentGuides = _resolveRangeAppliedList(
          previous: _appliedIndentGuides,
          incoming: data?.cast<core.IndentGuide>(),
          mode: mode,
          overlapsRange: _indentGuideOverlapsRange,
        );
        if (nextIndentGuides != null) {
          _appliedIndentGuides = nextIndentGuides;
          _setIndentGuides(nextIndentGuides);
        }
        break;
      case 1:
        final nextBracketGuides = _resolveRangeAppliedList(
          previous: _appliedBracketGuides,
          incoming: data?.cast<core.BracketGuide>(),
          mode: mode,
          overlapsRange: _bracketGuideOverlapsRange,
        );
        if (nextBracketGuides != null) {
          _appliedBracketGuides = nextBracketGuides;
          _setBracketGuides(nextBracketGuides);
        }
        break;
      case 2:
        final nextFlowGuides = _resolveRangeAppliedList(
          previous: _appliedFlowGuides,
          incoming: data?.cast<core.FlowGuide>(),
          mode: mode,
          overlapsRange: _flowGuideOverlapsRange,
        );
        if (nextFlowGuides != null) {
          _appliedFlowGuides = nextFlowGuides;
          _setFlowGuides(nextFlowGuides);
        }
        break;
      case 3:
        final nextSeparatorGuides = _resolveRangeAppliedList(
          previous: _appliedSeparatorGuides,
          incoming: data?.cast<core.SeparatorGuide>(),
          mode: mode,
          overlapsRange: _separatorGuideOverlapsRange,
        );
        if (nextSeparatorGuides != null) {
          _appliedSeparatorGuides = nextSeparatorGuides;
          _setSeparatorGuides(nextSeparatorGuides);
        }
        break;
    }
  }

  int _calculateOverscanLines(int visibleStart, int visibleEnd) {
    final viewportLineCount = visibleEnd >= visibleStart
        ? (visibleEnd - visibleStart + 1)
        : 0;
    if (viewportLineCount <= 0) return 0;
    final multiplier =
        (session.settings.getDecorationOverscanViewportMultiplier()).clamp(
          0.0,
          double.infinity,
        );
    return (viewportLineCount * multiplier).ceil().clamp(0, 1 << 30);
  }

  void _clearSpanRange(int layer, int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.StyleSpan>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineSpans(layer, empty);
  }

  void _clearInlayRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.InlayHint>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineInlayHints(empty);
  }

  void _clearDiagnosticRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.Diagnostic>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineDiagnostics(empty);
  }

  void _clearDocumentHighlightRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.DocumentHighlight>(
      startLine,
      endLine,
    );
    if (empty.isEmpty) return;
    _setBatchLineDocumentHighlights(empty);
  }

  void _clearGutterRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.GutterIcon>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineGutterIcons(empty);
  }

  void _clearPhantomRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.PhantomText>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLinePhantomTexts(empty);
  }

  void _clearCodeLensRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.CodeLensItem>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineCodeLens(empty);
  }

  void _clearLinksRange(int startLine, int endLine) {
    final empty = _buildEmptyMapRange<core.LinkSpan>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineLinks(empty);
  }

  void onProviderResult(
    DecorationProvider provider,
    DecorationResult result,
    int receiverGeneration,
  ) {
    if (_disposed) return;
    if (receiverGeneration != _generation) return;
    var state = _providerStates[provider];
    if (state == null) {
      state = _ProviderState();
      _providerStates[provider] = state;
    }
    _mergePatch(state, result);
    _scheduleApply();
  }

  void _mergePatch(_ProviderState state, DecorationResult patch) {
    state.snapshot ??= DecorationResult();
    final target = state.snapshot!;

    if (patch.syntaxSpans != null) {
      target.syntaxSpans = patch.syntaxSpans;
      target.syntaxSpansMode = patch.syntaxSpansMode;
    } else if (patch.syntaxSpansMode != ApplyMode.merge) {
      target.syntaxSpans = null;
      target.syntaxSpansMode = patch.syntaxSpansMode;
    }
    if (patch.semanticSpans != null) {
      target.semanticSpans = patch.semanticSpans;
      target.semanticSpansMode = patch.semanticSpansMode;
    } else if (patch.semanticSpansMode != ApplyMode.merge) {
      target.semanticSpans = null;
      target.semanticSpansMode = patch.semanticSpansMode;
    }
    if (patch.overlaySpans != null) {
      target.overlaySpans = patch.overlaySpans;
      target.overlaySpansMode = patch.overlaySpansMode;
    } else if (patch.overlaySpansMode != ApplyMode.merge) {
      target.overlaySpans = null;
      target.overlaySpansMode = patch.overlaySpansMode;
    }
    if (patch.inlayHints != null) {
      target.inlayHints = patch.inlayHints;
      target.inlayHintsMode = patch.inlayHintsMode;
    } else if (patch.inlayHintsMode != ApplyMode.merge) {
      target.inlayHints = null;
      target.inlayHintsMode = patch.inlayHintsMode;
    }
    if (patch.diagnostics != null) {
      target.diagnostics = patch.diagnostics;
      target.diagnosticsMode = patch.diagnosticsMode;
    } else if (patch.diagnosticsMode != ApplyMode.merge) {
      target.diagnostics = null;
      target.diagnosticsMode = patch.diagnosticsMode;
    }
    if (patch.documentHighlights != null) {
      target.documentHighlights = patch.documentHighlights;
      target.documentHighlightsMode = patch.documentHighlightsMode;
    } else if (patch.documentHighlightsMode != ApplyMode.merge) {
      target.documentHighlights = null;
      target.documentHighlightsMode = patch.documentHighlightsMode;
    }
    if (patch.indentGuides != null) {
      target.indentGuides = patch.indentGuides;
      target.indentGuidesMode = patch.indentGuidesMode;
    } else if (patch.indentGuidesMode != ApplyMode.merge) {
      target.indentGuides = null;
      target.indentGuidesMode = patch.indentGuidesMode;
    }
    if (patch.bracketGuides != null) {
      target.bracketGuides = patch.bracketGuides;
      target.bracketGuidesMode = patch.bracketGuidesMode;
    } else if (patch.bracketGuidesMode != ApplyMode.merge) {
      target.bracketGuides = null;
      target.bracketGuidesMode = patch.bracketGuidesMode;
    }
    if (patch.flowGuides != null) {
      target.flowGuides = patch.flowGuides;
      target.flowGuidesMode = patch.flowGuidesMode;
    } else if (patch.flowGuidesMode != ApplyMode.merge) {
      target.flowGuides = null;
      target.flowGuidesMode = patch.flowGuidesMode;
    }
    if (patch.separatorGuides != null) {
      target.separatorGuides = patch.separatorGuides;
      target.separatorGuidesMode = patch.separatorGuidesMode;
    } else if (patch.separatorGuidesMode != ApplyMode.merge) {
      target.separatorGuides = null;
      target.separatorGuidesMode = patch.separatorGuidesMode;
    }
    if (patch.foldRegions != null) {
      target.foldRegions = patch.foldRegions;
      target.foldRegionsMode = patch.foldRegionsMode;
    } else if (patch.foldRegionsMode != ApplyMode.merge) {
      target.foldRegions = null;
      target.foldRegionsMode = patch.foldRegionsMode;
    }
    if (patch.gutterIcons != null) {
      target.gutterIcons = patch.gutterIcons;
      target.gutterIconsMode = patch.gutterIconsMode;
    } else if (patch.gutterIconsMode != ApplyMode.merge) {
      target.gutterIcons = null;
      target.gutterIconsMode = patch.gutterIconsMode;
    }
    if (patch.phantomTexts != null) {
      target.phantomTexts = patch.phantomTexts;
      target.phantomTextsMode = patch.phantomTextsMode;
    } else if (patch.phantomTextsMode != ApplyMode.merge) {
      target.phantomTexts = null;
      target.phantomTextsMode = patch.phantomTextsMode;
    }
    if (patch.codeLensItems != null) {
      target.codeLensItems = patch.codeLensItems;
      target.codeLensItemsMode = patch.codeLensItemsMode;
    } else if (patch.codeLensItemsMode != ApplyMode.merge) {
      target.codeLensItems = null;
      target.codeLensItemsMode = patch.codeLensItemsMode;
    }
    if (patch.links != null) {
      target.links = patch.links;
      target.linksMode = patch.linksMode;
    } else if (patch.linksMode != ApplyMode.merge) {
      target.links = null;
      target.linksMode = patch.linksMode;
    }
  }

  static ApplyMode _mergeMode(ApplyMode current, ApplyMode next) {
    return _priority(next) > _priority(current) ? next : current;
  }

  static int _priority(ApplyMode mode) {
    switch (mode) {
      case ApplyMode.merge:
        return 0;
      case ApplyMode.replaceRange:
        return 1;
      case ApplyMode.replaceAll:
        return 2;
    }
  }

  List<T>? _resolveRangeAppliedList<T>({
    required List<T> previous,
    required List<T>? incoming,
    required ApplyMode mode,
    required bool Function(T item, core.IntRange range) overlapsRange,
  }) {
    switch (mode) {
      case ApplyMode.merge:
        return List<T>.of(incoming ?? <T>[]);
      case ApplyMode.replaceAll:
        return List<T>.of(incoming ?? <T>[]);
      case ApplyMode.replaceRange:
        final next = <T>[
          for (final item in previous)
            if (!overlapsRange(item, _lastContextLineRange)) item,
        ];
        if (incoming != null) {
          next.addAll(incoming);
        }
        return next;
    }
  }

  static bool _indentGuideOverlapsRange(
    core.IndentGuide guide,
    core.IntRange range,
  ) => _positionRangeOverlapsRange(guide.start.line, guide.end.line, range);

  static bool _bracketGuideOverlapsRange(
    core.BracketGuide guide,
    core.IntRange range,
  ) {
    var maxLine = guide.end.line;
    for (final child in guide.children) {
      if (child.line > maxLine) {
        maxLine = child.line;
      }
    }
    return _positionRangeOverlapsRange(guide.parent.line, maxLine, range);
  }

  static bool _flowGuideOverlapsRange(
    core.FlowGuide guide,
    core.IntRange range,
  ) => _positionRangeOverlapsRange(guide.start.line, guide.end.line, range);

  static bool _separatorGuideOverlapsRange(
    core.SeparatorGuide guide,
    core.IntRange range,
  ) => _lineOverlapsRange(guide.line, range);

  static bool _foldRegionOverlapsRange(
    core.FoldRegion region,
    core.IntRange range,
  ) => _positionRangeOverlapsRange(region.startLine, region.endLine, range);

  static bool _positionRangeOverlapsRange(
    int startLine,
    int endLine,
    core.IntRange range,
  ) {
    if (range.end < range.start) return false;
    return endLine >= range.start && startLine <= range.end;
  }

  static bool _lineOverlapsRange(int line, core.IntRange range) {
    if (range.end < range.start) return false;
    return line >= range.start && line <= range.end;
  }

  void _clearHighlights(int layer) {
    session.dispatchEditorActionResult(
      session.editorCore?.clearHighlights(core.SpanLayer.values[layer]),
    );
  }

  void _setBatchLineSpans(int layer, Map<int, List<core.StyleSpan>> spans) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(
      ec.setBatchLineSpans(core.SpanLayer.values[layer], spans),
    );
  }

  void _clearInlayHints() {
    session.dispatchEditorActionResult(session.editorCore?.clearInlayHints());
  }

  void _setBatchLineInlayHints(Map<int, List<core.InlayHint>> hints) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLineInlayHints(hints));
  }

  void _clearDiagnostics() {
    session.dispatchEditorActionResult(session.editorCore?.clearDiagnostics());
  }

  void _setBatchLineDiagnostics(Map<int, List<core.Diagnostic>> items) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLineDiagnostics(items));
  }

  void _clearDocumentHighlights() {
    session.dispatchEditorActionResult(
      session.editorCore?.clearDocumentHighlights(),
    );
  }

  void _setBatchLineDocumentHighlights(
    Map<int, List<core.DocumentHighlight>> items,
  ) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLineDocumentHighlights(items));
  }

  void _clearGutterIcons() {
    session.dispatchEditorActionResult(session.editorCore?.clearGutterIcons());
  }

  void _setBatchLineGutterIcons(Map<int, List<core.GutterIcon>> icons) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLineGutterIcons(icons));
  }

  void _clearPhantomTexts() {
    session.dispatchEditorActionResult(session.editorCore?.clearPhantomTexts());
  }

  void _setBatchLinePhantomTexts(Map<int, List<core.PhantomText>> texts) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLinePhantomTexts(texts));
  }

  void _clearCodeLens() {
    session.dispatchEditorActionResult(session.editorCore?.clearCodeLens());
  }

  void _setBatchLineCodeLens(Map<int, List<core.CodeLensItem>> items) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLineCodeLens(items));
  }

  void _clearLinks() {
    session.dispatchEditorActionResult(session.editorCore?.clearLinks());
  }

  void _setBatchLineLinks(Map<int, List<core.LinkSpan>> links) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBatchLineLinks(links));
  }

  void _setIndentGuides(List<core.IndentGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setIndentGuides(guides));
  }

  void _setBracketGuides(List<core.BracketGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setBracketGuides(guides));
  }

  void _setFlowGuides(List<core.FlowGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setFlowGuides(guides));
  }

  void _setSeparatorGuides(List<core.SeparatorGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setSeparatorGuides(guides));
  }

  void _setFoldRegions(List<core.FoldRegion> regions) {
    final ec = session.editorCore;
    if (ec == null) return;
    session.dispatchEditorActionResult(ec.setFoldRegions(regions));
  }

  static Map<int, List<T>> _buildEmptyMapRange<T>(int startLine, int endLine) {
    if (endLine < startLine) return {};
    return {for (var line = startLine; line <= endLine; line++) line: <T>[]};
  }

  static void _appendMapOfArrays<T>(
    Map<int, List<T>> out,
    Map<int, List<T>> patch,
  ) {
    for (final entry in patch.entries) {
      final target = out.putIfAbsent(entry.key, () => <T>[]);
      target.addAll(entry.value);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final state in _providerStates.values) {
      state.activeReceiver?.cancel();
    }
    final providers = List<DecorationProvider>.of(_providers);
    _providers.clear();
    _providerStates.clear();
    _pendingTextChanges.clear();
    _refreshTimer?.cancel();
    _scrollRefreshTimer?.cancel();
    _applyTimer?.cancel();
    _applyScheduled = false;
    _pendingScrollRefresh = false;
    for (final provider in providers) {
      provider.dispose();
    }
  }
}

class _ManagedDecorationReceiver implements DecorationReceiver {
  _ManagedDecorationReceiver(
    this._provider,
    this._receiverGeneration,
    this._manager,
  );

  final DecorationProvider _provider;
  final int _receiverGeneration;
  final DecorationProviderManager _manager;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  @override
  bool accept(DecorationResult result) {
    if (_cancelled || _receiverGeneration != _manager.generation) return false;
    final snapshot = result.copy();
    _manager.onProviderResult(_provider, snapshot, _receiverGeneration);
    return true;
  }

  @override
  bool isCancelled() =>
      _cancelled || _receiverGeneration != _manager.generation;
}
