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
  int _lastVisibleStartLine = 0;
  int _lastVisibleEndLine = -1;
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
    _refreshTimer = null;
    if (delayMs > 0) {
      _refreshTimer = Timer(Duration(milliseconds: delayMs), () {
        _refreshTimer = null;
        if (_disposed) return;
        _doRefresh();
      });
    } else {
      _doRefresh();
    }
  }

  void _scheduleScrollRefresh() {
    if (_disposed) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - _lastScrollRefreshTimeMs;
    final minInterval =
        session.settings.getDecorationScrollRefreshMinIntervalMs();
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

    final visualLines = session.renderModel.visualLines;
    final visible = visualLines.isEmpty
        ? [0, -1]
        : [visualLines.first.logicalLine, visualLines.last.logicalLine];
    _lastVisibleStartLine = visible[0];
    _lastVisibleEndLine = visible[1];
    final total = session.document?.lineCount ?? 0;
    final changes = List<core.TextChange>.of(_pendingTextChanges);
    _pendingTextChanges.clear();

    var contextStart = visible[0];
    var contextEnd = visible[1];
    if (total > 0 && visible[1] >= visible[0]) {
      final overscanLines = _calculateOverscanLines(visible[0], visible[1]);
      contextStart = (visible[0] - overscanLines).clamp(0, total - 1);
      contextEnd = (visible[1] + overscanLines).clamp(0, total - 1);
    }

    final context = DecorationContext(
      visibleStartLine: contextStart,
      visibleEndLine: contextEnd,
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
    final inlayHints = <int, List<core.InlayHint>>{};
    final diagnostics = <int, List<core.DiagnosticItem>>{};
    List<core.IndentGuide>? indentGuides;
    List<core.BracketGuide>? bracketGuides;
    List<core.FlowGuide>? flowGuides;
    List<core.SeparatorGuide>? separatorGuides;
    final foldRegions = <core.FoldRegion>[];
    final gutterIcons = <int, List<core.GutterIcon>>{};
    final phantomTexts = <int, List<core.PhantomText>>{};

    var syntaxMode = ApplyMode.merge;
    var semanticMode = ApplyMode.merge;
    var inlayMode = ApplyMode.merge;
    var diagnosticMode = ApplyMode.merge;
    var indentMode = ApplyMode.merge;
    var bracketMode = ApplyMode.merge;
    var flowMode = ApplyMode.merge;
    var separatorMode = ApplyMode.merge;
    var foldMode = ApplyMode.merge;
    var gutterMode = ApplyMode.merge;
    var phantomMode = ApplyMode.merge;

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
      inlayMode = _mergeMode(inlayMode, r.inlayHintsMode);
      if (r.inlayHints != null) {
        _appendMapOfArrays(inlayHints, r.inlayHints!);
      }
      diagnosticMode = _mergeMode(diagnosticMode, r.diagnosticsMode);
      if (r.diagnostics != null) {
        _appendMapOfArrays(diagnostics, r.diagnostics!);
      }
      gutterMode = _mergeMode(gutterMode, r.gutterIconsMode);
      if (r.gutterIcons != null) {
        _appendMapOfArrays(gutterIcons, r.gutterIcons!);
      }
      phantomMode = _mergeMode(phantomMode, r.phantomTextsMode);
      if (r.phantomTexts != null) {
        _appendMapOfArrays(phantomTexts, r.phantomTexts!);
      }

      indentMode = _mergeMode(indentMode, r.indentGuidesMode);
      if (r.indentGuides != null) indentGuides = List.of(r.indentGuides!);
      bracketMode = _mergeMode(bracketMode, r.bracketGuidesMode);
      if (r.bracketGuides != null) bracketGuides = List.of(r.bracketGuides!);
      flowMode = _mergeMode(flowMode, r.flowGuidesMode);
      if (r.flowGuides != null) flowGuides = List.of(r.flowGuides!);
      separatorMode = _mergeMode(separatorMode, r.separatorGuidesMode);
      if (r.separatorGuides != null) {
        separatorGuides = List.of(r.separatorGuides!);
      }
      foldMode = _mergeMode(foldMode, r.foldRegionsMode);
      if (r.foldRegions != null) foldRegions.addAll(r.foldRegions!);
    }

    _applySpanMode(0, syntaxMode);
    _applySpanMode(1, semanticMode);
    _setBatchLineSpans(0, syntaxSpans);
    _setBatchLineSpans(1, semanticSpans);

    _applyInlayMode(inlayMode);
    _setBatchLineInlayHints(inlayHints);

    _applyDiagnosticMode(diagnosticMode);
    _setBatchLineDiagnostics(diagnostics);

    _applyGuidesMode(indentMode, indentGuides, 0);
    _applyGuidesMode(bracketMode, bracketGuides, 1);
    _applyGuidesMode(flowMode, flowGuides, 2);
    _applyGuidesMode(separatorMode, separatorGuides, 3);

    if (foldMode == ApplyMode.replaceAll ||
        foldMode == ApplyMode.replaceRange) {
      _setFoldRegions(foldRegions);
    } else if (foldRegions.isNotEmpty) {
      _setFoldRegions(foldRegions);
    }

    _applyGutterMode(gutterMode);
    _setBatchLineGutterIcons(gutterIcons);

    _applyPhantomMode(phantomMode);
    _setBatchLinePhantomTexts(phantomTexts);

    session.requestFlush();
  }

  void _applySpanMode(int layer, ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearHighlights(layer);
    } else if (mode == ApplyMode.replaceRange) {
      _clearSpanRange(layer, _lastVisibleStartLine, _lastVisibleEndLine);
    }
  }

  void _applyInlayMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearInlayHints();
    } else if (mode == ApplyMode.replaceRange) {
      _clearInlayRange(_lastVisibleStartLine, _lastVisibleEndLine);
    }
  }

  void _applyDiagnosticMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearDiagnostics();
    } else if (mode == ApplyMode.replaceRange) {
      _clearDiagnosticRange(_lastVisibleStartLine, _lastVisibleEndLine);
    }
  }

  void _applyGutterMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearGutterIcons();
    } else if (mode == ApplyMode.replaceRange) {
      _clearGutterRange(_lastVisibleStartLine, _lastVisibleEndLine);
    }
  }

  void _applyPhantomMode(ApplyMode mode) {
    if (mode == ApplyMode.replaceAll) {
      _clearPhantomTexts();
    } else if (mode == ApplyMode.replaceRange) {
      _clearPhantomRange(_lastVisibleStartLine, _lastVisibleEndLine);
    }
  }

  void _applyGuidesMode(ApplyMode mode, List<Object>? data, int guideType) {
    final shouldReplace =
        mode == ApplyMode.replaceAll || mode == ApplyMode.replaceRange;
    final items = data ?? [];
    switch (guideType) {
      case 0:
        if (shouldReplace || items.isNotEmpty) {
          _setIndentGuides(items.cast<core.IndentGuide>());
        }
      case 1:
        if (shouldReplace || items.isNotEmpty) {
          _setBracketGuides(items.cast<core.BracketGuide>());
        }
      case 2:
        if (shouldReplace || items.isNotEmpty) {
          _setFlowGuides(items.cast<core.FlowGuide>());
        }
      case 3:
        if (shouldReplace || items.isNotEmpty) {
          _setSeparatorGuides(items.cast<core.SeparatorGuide>());
        }
    }
  }

  int _calculateOverscanLines(int visibleStart, int visibleEnd) {
    final viewportLineCount = visibleEnd >= visibleStart
        ? (visibleEnd - visibleStart + 1)
        : 0;
    if (viewportLineCount <= 0) return 0;
    final multiplier = (session.settings
            .getDecorationOverscanViewportMultiplier())
        .clamp(0.0, double.infinity);
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
    final empty = _buildEmptyMapRange<core.DiagnosticItem>(startLine, endLine);
    if (empty.isEmpty) return;
    _setBatchLineDiagnostics(empty);
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

  void _clearHighlights(int layer) {
    session.editorCore?.clearHighlightsLayer(core.SpanLayer.values[layer]);
  }

  void _setBatchLineSpans(int layer, Map<int, List<core.StyleSpan>> spans) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packBatchLineSpans(layer, spans);
    ec.setBatchLineSpans(data);
  }

  void _clearInlayHints() {
    session.editorCore?.clearInlayHints();
  }

  void _setBatchLineInlayHints(Map<int, List<core.InlayHint>> hints) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packBatchLineInlayHints(hints);
    ec.setBatchLineInlayHints(data);
  }

  void _clearDiagnostics() {
    session.editorCore?.clearDiagnostics();
  }

  void _setBatchLineDiagnostics(Map<int, List<core.DiagnosticItem>> items) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packBatchLineDiagnostics(items);
    ec.setBatchLineDiagnostics(data);
  }

  void _clearGutterIcons() {
    session.editorCore?.clearGutterIcons();
  }

  void _setBatchLineGutterIcons(Map<int, List<core.GutterIcon>> icons) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packBatchLineGutterIcons(icons);
    ec.setBatchLineGutterIcons(data);
  }

  void _clearPhantomTexts() {
    session.editorCore?.clearPhantomTexts();
  }

  void _setBatchLinePhantomTexts(Map<int, List<core.PhantomText>> texts) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packBatchLinePhantomTexts(texts);
    ec.setBatchLinePhantomTexts(data);
  }

  void _setIndentGuides(List<core.IndentGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packIndentGuides(guides);
    ec.setIndentGuides(data);
  }

  void _setBracketGuides(List<core.BracketGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packBracketGuides(guides);
    ec.setBracketGuides(data);
  }

  void _setFlowGuides(List<core.FlowGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packFlowGuides(guides);
    ec.setFlowGuides(data);
  }

  void _setSeparatorGuides(List<core.SeparatorGuide> guides) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packSeparatorGuides(guides);
    ec.setSeparatorGuides(data);
  }

  void _setFoldRegions(List<core.FoldRegion> regions) {
    final ec = session.editorCore;
    if (ec == null) return;
    final data = core.ProtocolEncoder.packFoldRegions(regions);
    ec.setFoldRegions(data);
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
