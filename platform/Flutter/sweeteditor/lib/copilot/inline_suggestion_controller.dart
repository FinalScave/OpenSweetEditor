part of '../sweeteditor.dart';

/// Callback for inline suggestion action bar Accept/Dismiss interaction.
abstract class InlineSuggestionActionCallback {
  void onAcceptClicked();
  void onDismissClicked();
}

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
class InlineSuggestionController implements InlineSuggestionActionCallback {
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
  EditorOverlayBinding<InlineSuggestionOverlayState>? _overlayBinding;
  StreamSubscription<TextChangedEvent>? _textChangedSub;
  StreamSubscription<CursorChangedEvent>? _cursorChangedSub;
  StreamSubscription<ScrollChangedEvent>? _scrollChangedSub;

  void _onTextChanged(TextChangedEvent _) => _autoDismiss();

  void _onCursorChanged(CursorChangedEvent _) => _autoDismiss();

  void _onScrollChanged(ScrollChangedEvent _) {
    if (_showing) {
      _overlayBinding?.update(_buildOverlayState());
    }
  }

  void setListener(InlineSuggestionListener? listener) {
    _listener = listener;
  }

  void bindOverlay(EditorOverlayBinding<InlineSuggestionOverlayState>? binding) {
    _overlayBinding = binding;
  }

  bool get isShowing => _showing;

  void show(InlineSuggestion suggestion) {
    if (_showing) _clearQuietly();
    _currentSuggestion = suggestion;
    _injectPhantomText(suggestion);

    final cursor = _session.renderModel.cursor;
    _cachedCursorX = cursor.position.x - _session.renderModel.scrollX;
    _cachedCursorY = cursor.position.y - _session.renderModel.scrollY;
    _cachedCursorHeight = cursor.height;

    _showing = true;
    _overlayBinding?.show(_buildOverlayState());
    _subscribeEvents();
    _session.requestFlush();
  }

  void accept() {
    if (_currentSuggestion == null) return;
    final suggestion = _currentSuggestion!;
    _withSuppressedAutoDismiss(() {
      _unsubscribeEvents();
      _session.editorCore?.clearPhantomTexts();
      final pos = core.TextPosition(suggestion.line, suggestion.column);
      _session.editorCore?.replaceText(
        pos.line,
        pos.column,
        pos.line,
        pos.column,
        suggestion.text,
      );
      _showing = false;
      _overlayBinding?.hide();
      _currentSuggestion = null;
      _session.requestFlush();
    });
    _listener?.onSuggestionAccepted(suggestion);
  }

  void dismiss() {
    if (_currentSuggestion == null) return;
    final suggestion = _currentSuggestion!;
    _withSuppressedAutoDismiss(() {
      _unsubscribeEvents();
      _session.editorCore?.clearPhantomTexts();
      _session.requestFlush();
      _showing = false;
      _overlayBinding?.hide();
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
      _overlayBinding?.update(_buildOverlayState());
    }
  }

  @override
  void onAcceptClicked() => accept();

  @override
  void onDismissClicked() => dismiss();

  void dispose() {
    _unsubscribeEvents();
    _overlayBinding = null;
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
      _session.editorCore?.clearPhantomTexts();
      _showing = false;
      _overlayBinding?.hide();
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
    _session.editorCore?.clearPhantomTexts();
    final data = core.ProtocolEncoder.packBatchLinePhantomTexts({
      suggestion.line: [
        core.PhantomText(column: suggestion.column, text: suggestion.text),
      ],
    });
    _session.editorCore?.setBatchLinePhantomTexts(data);
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
    _cursorChangedSub ??=
        _eventBus.on<CursorChangedEvent>().listen(_onCursorChanged);
    _scrollChangedSub ??=
        _eventBus.on<ScrollChangedEvent>().listen(_onScrollChanged);
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
