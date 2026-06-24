part of '../sweeteditor.dart';

class InlineSuggestionOverlayState {
  const InlineSuggestionOverlayState({
    required this.x,
    required this.y,
    required this.cursorHeight,
  });

  final double x;
  final double y;
  final double cursorHeight;
}

/// Manages inline suggestion lifecycle: phantom text injection, event subscriptions,
/// Tab/Esc key interception, and action bar state.
class InlineSuggestionController {
  InlineSuggestionController({required EditorSession session})
    : _session = session,
      _eventBus = session.eventBus;

  final EditorSession _session;
  final EditorEventBus _eventBus;

  InlineSuggestion? _currentSuggestion;
  InlineSuggestionListener? _listener;
  bool _showing = false;
  bool _suppressAutoDismiss = false;
  double _cachedCursorX = 0;
  double _cachedCursorY = 0;
  double _cachedCursorHeight = 0;
  EditorOverlayUpdater<InlineSuggestionOverlayState>? _overlayUpdater;
  StreamSubscription<TextChangedEvent>? _textChangedSub;
  StreamSubscription<CursorChangedEvent>? _cursorChangedSub;
  StreamSubscription<ScrollChangedEvent>? _scrollChangedSub;

  void _onTextChanged(TextChangedEvent _) => _autoDismiss();

  void _onCursorChanged(CursorChangedEvent _) => _autoDismiss();

  void _onScrollChanged(ScrollChangedEvent _) {
    if (_showing) {
      _overlayUpdater?.call(_buildOverlayState());
    }
  }

  void setListener(InlineSuggestionListener? listener) {
    _listener = listener;
  }

  void bindOverlay(
    EditorOverlayUpdater<InlineSuggestionOverlayState>? updater,
  ) {
    _overlayUpdater = updater;
  }

  bool get isShowing => _showing;

  void show(InlineSuggestion suggestion) {
    if (_showing) _clearQuietly();
    _currentSuggestion = suggestion;
    _injectPhantomText(suggestion);

    final cursor = _session.renderModel.cursor;
    _cachedCursorX = cursor.position.x;
    _cachedCursorY = cursor.position.y;
    _cachedCursorHeight = cursor.height;

    _showing = true;
    _overlayUpdater?.call(_buildOverlayState());
    _subscribeEvents();
  }

  void accept() {
    if (_currentSuggestion == null) return;
    final suggestion = _currentSuggestion!;
    _withSuppressedAutoDismiss(() {
      _unsubscribeEvents();
      _session.handleEditorActionResult(
        _session.editorCore?.clearPhantomTexts(),
      );
      final pos = core.TextPosition(
        line: suggestion.line,
        column: suggestion.column,
      );
      _session.handleEditorActionResult(
        _session.editorCore?.replaceText(
          pos.line,
          pos.column,
          pos.line,
          pos.column,
          suggestion.text,
        ),
      );
      _showing = false;
      _overlayUpdater?.call(null);
      _currentSuggestion = null;
    });
    _listener?.onSuggestionAccepted(suggestion);
  }

  void dismiss() {
    if (_currentSuggestion == null) return;
    final suggestion = _currentSuggestion!;
    _withSuppressedAutoDismiss(() {
      _unsubscribeEvents();
      _session.handleEditorActionResult(
        _session.editorCore?.clearPhantomTexts(),
      );
      _showing = false;
      _overlayUpdater?.call(null);
      _currentSuggestion = null;
    });
    _listener?.onSuggestionDismissed(suggestion);
  }

  /// Handle key codes. Returns true if consumed.
  /// Tab -> accept, Escape -> dismiss.
  bool handleKeyCode(int keyCode) {
    if (!_showing) return false;
    if (keyCode == 9) {
      accept();
      return true;
    }
    if (keyCode == 27) {
      dismiss();
      return true;
    }
    return false;
  }

  void updatePosition(double cursorX, double cursorY, double cursorHeight) {
    _cachedCursorX = cursorX;
    _cachedCursorY = cursorY;
    _cachedCursorHeight = cursorHeight;
    if (_showing) {
      _overlayUpdater?.call(_buildOverlayState());
    }
  }

  void dispose() {
    _unsubscribeEvents();
    _overlayUpdater = null;
    _currentSuggestion = null;
    _showing = false;
  }

  void _autoDismiss() {
    if (_suppressAutoDismiss) return;
    dismiss();
  }

  void _clearQuietly() {
    _withSuppressedAutoDismiss(() {
      _unsubscribeEvents();
      _session.handleEditorActionResult(
        _session.editorCore?.clearPhantomTexts(),
      );
      _showing = false;
      _overlayUpdater?.call(null);
      _currentSuggestion = null;
    });
  }

  void _withSuppressedAutoDismiss(void Function() action) {
    _suppressAutoDismiss = true;
    try {
      action();
    } finally {
      _suppressAutoDismiss = false;
    }
  }

  void _injectPhantomText(InlineSuggestion suggestion) {
    _session.handleEditorActionResult(
      _session.editorCore?.clearPhantomTexts(),
    );
    _session.handleEditorActionResult(
      _session.editorCore?.setBatchLinePhantomTexts({
        suggestion.line: [
          core.PhantomText(column: suggestion.column, text: suggestion.text),
        ],
      }),
    );
  }

  InlineSuggestionOverlayState _buildOverlayState() {
    return InlineSuggestionOverlayState(
      x: _cachedCursorX,
      y: _cachedCursorY,
      cursorHeight: _cachedCursorHeight,
    );
  }

  void _subscribeEvents() {
    _textChangedSub ??= _eventBus.on<TextChangedEvent>().listen(_onTextChanged);
    _cursorChangedSub ??= _eventBus.on<CursorChangedEvent>().listen(
      _onCursorChanged,
    );
    _scrollChangedSub ??= _eventBus.on<ScrollChangedEvent>().listen(
      _onScrollChanged,
    );
  }

  void _unsubscribeEvents() {
    _textChangedSub?.cancel();
    _textChangedSub = null;
    _cursorChangedSub?.cancel();
    _cursorChangedSub = null;
    _scrollChangedSub?.cancel();
    _scrollChangedSub = null;
  }
}
