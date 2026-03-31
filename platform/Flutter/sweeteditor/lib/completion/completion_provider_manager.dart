part of '../sweeteditor.dart';

const int _debounceCharacterMs = 50;
const int _debounceInvokedMs = 0;

/// Listener for completion item updates and dismissals.
abstract class CompletionUpdateListener {
  void onCompletionItemsUpdated(List<CompletionItem> items);
  void onCompletionDismissed();
}

/// Completion provider manager.
/// Handles provider registration/removal, debounce, context building,
/// dispatching requests, merging/sorting/filtering results, and driving panel updates.
class CompletionProviderManager {
  CompletionProviderManager({required this.session});

  final EditorSession session;

  final List<CompletionProvider> _providers = [];
  final Map<CompletionProvider, _ManagedCompletionReceiver> _activeReceivers =
      {};
  CompletionUpdateListener? _listener;
  int _generation = 0;
  List<CompletionItem> _mergedItems = [];
  CompletionTriggerKind _lastTriggerKind = CompletionTriggerKind.invoked;
  String? _lastTriggerChar;
  bool _disposed = false;
  Timer? _debounceTimer;

  void setListener(CompletionUpdateListener? listener) {
    _listener = listener;
  }

  void addProvider(CompletionProvider provider) {
    if (_disposed) return;
    if (!_providers.contains(provider)) {
      _providers.add(provider);
    }
  }

  void removeProvider(CompletionProvider provider) {
    final removed = _providers.remove(provider);
    if (!removed) return;
    _activeReceivers[provider]?.cancel();
    _activeReceivers.remove(provider);
    provider.dispose();
  }

  void triggerCompletion(
    CompletionTriggerKind triggerKind,
    String? triggerCharacter,
  ) {
    if (_disposed) return;
    if (_providers.isEmpty) return;
    _lastTriggerKind = triggerKind;
    _lastTriggerChar = triggerCharacter;
    _clearDebounce();
    final delay = triggerKind == CompletionTriggerKind.invoked
        ? _debounceInvokedMs
        : _debounceCharacterMs;
    if (delay > 0) {
      _debounceTimer = Timer(Duration(milliseconds: delay), () {
        _debounceTimer = null;
        if (_disposed) return;
        _executeRefresh(_lastTriggerKind, _lastTriggerChar);
      });
    } else {
      _executeRefresh(triggerKind, triggerCharacter);
    }
  }

  void dismiss() {
    if (_disposed) return;
    _clearDebounce();
    _generation++;
    _cancelAllReceivers();
    _mergedItems = [];
    _listener?.onCompletionDismissed();
  }

  bool isTriggerCharacter(String ch) {
    for (final provider in _providers) {
      if (provider.isTriggerCharacter(ch)) return true;
    }
    return false;
  }

  void showItems(List<CompletionItem> items) {
    if (_disposed) return;
    _clearDebounce();
    _generation++;
    _cancelAllReceivers();
    _mergedItems = List.of(items);
    _listener?.onCompletionItemsUpdated(List.of(_mergedItems));
  }

  void _executeRefresh(
    CompletionTriggerKind triggerKind,
    String? triggerCharacter,
  ) {
    if (_disposed) return;
    final currentGen = ++_generation;
    _cancelAllReceivers();
    _mergedItems = [];

    final context = _buildContext(triggerKind, triggerCharacter);
    if (context == null) {
      dismiss();
      return;
    }

    for (final provider in _providers) {
      final receiver = _ManagedCompletionReceiver(provider, currentGen, this);
      _activeReceivers[provider] = receiver;
      try {
        provider.provideCompletions(context, receiver);
      } catch (_) {}
    }
  }

  void _cancelAllReceivers() {
    for (final receiver in _activeReceivers.values) {
      receiver.cancel();
    }
    _activeReceivers.clear();
  }

  CompletionContext? _buildContext(
    CompletionTriggerKind triggerKind,
    String? triggerCharacter,
  ) {
    final editorCore = session.editorCore;
    final cursor = editorCore?.getCursorPosition();
    if (cursor == null) return null;
    final lineText = session.document?.getLineText(cursor.line) ?? '';
    final wordRange = core.TextRange(
      core.TextPosition(cursor.line, cursor.column),
      core.TextPosition(cursor.line, cursor.column),
    );
    return CompletionContext(
      triggerKind: triggerKind,
      triggerCharacter: triggerCharacter,
      cursorPosition: cursor,
      lineText: lineText,
      wordRange: wordRange,
      languageConfiguration: session.languageConfiguration,
      editorMetadata: session.metadata,
    );
  }

  void _onProviderResult(
    CompletionProvider provider,
    CompletionResult result,
    int receiverGeneration,
  ) {
    if (_disposed) return;
    if (receiverGeneration != _generation) return;
    _mergedItems.addAll(result.items);
    _mergedItems.sort((a, b) {
      final sa = a.sortKey ?? a.label;
      final sb = b.sortKey ?? b.label;
      return sa.compareTo(sb);
    });
    if (_mergedItems.isEmpty) {
      _listener?.onCompletionDismissed();
    } else {
      _listener?.onCompletionItemsUpdated(List.of(_mergedItems));
    }
  }

  int get generation => _generation;

  void _clearDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _clearDebounce();
    _cancelAllReceivers();
    final providers = List<CompletionProvider>.of(_providers);
    _providers.clear();
    for (final provider in providers) {
      provider.dispose();
    }
    _mergedItems = [];
    _listener = null;
  }
}

class _ManagedCompletionReceiver implements CompletionReceiver {
  _ManagedCompletionReceiver(
    this._provider,
    this._receiverGeneration,
    this._manager,
  );

  final CompletionProvider _provider;
  final int _receiverGeneration;
  final CompletionProviderManager _manager;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
  }

  @override
  bool accept(CompletionResult result) {
    if (_cancelled || _receiverGeneration != _manager.generation) return false;
    _manager._onProviderResult(_provider, result, _receiverGeneration);
    return true;
  }

  @override
  bool isCancelled() =>
      _cancelled || _receiverGeneration != _manager.generation;
}
