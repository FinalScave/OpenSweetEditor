part of '../editor_core.dart';

class SweetEditorException implements Exception {
  SweetEditorException(this.message);

  final String message;

  @override
  String toString() => 'SweetEditorException: $message';
}

/// Gesture event types.
class EventType {
  EventType._();

  static const int undefined = 0;
  static const int touchDown = 1;
  static const int touchPointerDown = 2;
  static const int touchMove = 3;
  static const int touchPointerUp = 4;
  static const int touchUp = 5;
  static const int touchCancel = 6;
  static const int mouseDown = 7;
  static const int mouseMove = 8;
  static const int mouseUp = 9;
  static const int mouseWheel = 10;
  static const int mouseRightDown = 11;
  static const int directScale = 12;
  static const int directScroll = 13;
}

/// Modifier key flags.
class Modifier {
  Modifier._();

  static const int none = 0;
  static const int shift = 1;
  static const int ctrl = 2;
  static const int alt = 4;
  static const int meta = 8;
}

/// Gesture type (result type, not input event type).
enum GestureType {
  undefined(0),
  tap(1),
  doubleTap(2),
  longPress(3),
  scale(4),
  scroll(5),
  fastScroll(6),
  dragSelect(7),
  contextMenu(8);

  const GestureType(this.value);
  final int value;

  static GestureType fromValue(int value) => GestureType.values.firstWhere(
    (e) => e.value == value,
    orElse: () => undefined,
  );
}

/// Hit target type.
enum HitTargetType {
  none(0),
  inlayHintText(1),
  inlayHintIcon(2),
  gutterIcon(3),
  foldPlaceholder(4),
  foldGutter(5),
  inlayHintColor(6),
  codelens(7),
  link(8);

  const HitTargetType(this.value);
  final int value;

  static HitTargetType fromValue(int value) => HitTargetType.values.firstWhere(
    (e) => e.value == value,
    orElse: () => none,
  );
}

/// Scrollbar mode.
enum ScrollbarMode {
  always(0),
  transient(1),
  never(2);

  const ScrollbarMode(this.value);
  final int value;
}

/// Scrollbar track tap mode.
enum ScrollbarTrackTapMode {
  jump(0),
  disabled(1);

  const ScrollbarTrackTapMode(this.value);
  final int value;
}

/// Key code definitions matching the C++ enum.
enum KeyCode {
  none(0),
  backspace(8),
  tab(9),
  enter(13),
  escape(27),
  deleteKey(46),
  left(37),
  up(38),
  right(39),
  down(40),
  home(36),
  end(35),
  pageUp(33),
  pageDown(34),
  a(65),
  c(67),
  d(68),
  v(86),
  x(88),
  z(90),
  y(89),
  k(75),
  space(32);

  const KeyCode(this.value);
  final int value;
}

/// A single text change from an edit operation.
class TextChange {
  const TextChange(this.range, this.newText);

  final TextRange range;
  final String newText;
}

enum EditorActionReason {
  none(0),
  setup(1),
  textEdit(2),
  keyInput(3),
  ime(4),
  gesture(5),
  animation(6),
  programmatic(7),
  decoration(8),
  folding(9),
  linkedEditing(10),
  textInsert(11),
  textReplace(12),
  textDelete(13),
  textUndo(14),
  textRedo(15);

  const EditorActionReason(this.value);
  final int value;

  static EditorActionReason fromValue(int value) => EditorActionReason.values
      .firstWhere((e) => e.value == value, orElse: () => none);
}

/// Hit target from a gesture.
class HitTarget {
  const HitTarget({
    this.type = HitTargetType.none,
    this.line = 0,
    this.column = 0,
    this.iconId = 0,
    this.colorValue = 0,
  });

  final HitTargetType type;
  final int line;
  final int column;
  final int iconId;
  final int colorValue;
}

class EditorActionResult {
  const EditorActionResult({
    this.handled = false,
    this.needsRedraw = false,
    this.reason = EditorActionReason.none,
    this.contentChanged = false,
    this.cursorChanged = false,
    this.selectionChanged = false,
    this.scrollChanged = false,
    this.scaleChanged = false,
    this.pointerCursorChanged = false,
    this.compositionChanged = false,
    this.decorationChanged = false,
    this.needsImeSync = false,
    this.needsEdgeScroll = false,
    this.needsFling = false,
    this.needsAnimation = false,
    this.isHandleDrag = false,
    this.changes = const <TextChange>[],
    this.cursorBefore = const TextPosition(0, 0),
    this.cursorAfter = const TextPosition(0, 0),
    this.hasSelectionBefore = false,
    this.selectionBefore = const TextRange(
      TextPosition(0, 0),
      TextPosition(0, 0),
    ),
    this.hasSelectionAfter = false,
    this.selectionAfter = const TextRange(
      TextPosition(0, 0),
      TextPosition(0, 0),
    ),
    this.scrollXBefore = 0,
    this.scrollYBefore = 0,
    this.scrollXAfter = 0,
    this.scrollYAfter = 0,
    this.scaleBefore = 1,
    this.scaleAfter = 1,
    this.pointerCursorBefore = PointerCursorType.text,
    this.pointerCursorAfter = PointerCursorType.text,
    this.imeSync = ImeSyncSnapshot.empty,
    this.gestureType = GestureType.undefined,
    this.gestureEventType = EventType.undefined,
    this.tapPoint = const PointF(),
    this.hitTarget = const HitTarget(),
    this.modifiers = Modifier.none,
    this.command = EditorCommand.none,
  });

  static const EditorActionResult empty = EditorActionResult();

  final bool handled;
  final bool needsRedraw;
  final EditorActionReason reason;
  final bool contentChanged;
  final bool cursorChanged;
  final bool selectionChanged;
  final bool scrollChanged;
  final bool scaleChanged;
  final bool pointerCursorChanged;
  final bool compositionChanged;
  final bool decorationChanged;
  final bool needsImeSync;
  final bool needsEdgeScroll;
  final bool needsFling;
  final bool needsAnimation;
  final bool isHandleDrag;
  final List<TextChange> changes;
  final TextPosition cursorBefore;
  final TextPosition cursorAfter;
  final bool hasSelectionBefore;
  final TextRange selectionBefore;
  final bool hasSelectionAfter;
  final TextRange selectionAfter;
  final double scrollXBefore;
  final double scrollYBefore;
  final double scrollXAfter;
  final double scrollYAfter;
  final double scaleBefore;
  final double scaleAfter;
  final PointerCursorType pointerCursorBefore;
  final PointerCursorType pointerCursorAfter;
  final ImeSyncSnapshot imeSync;
  final GestureType gestureType;
  final int gestureEventType;
  final PointF tapPoint;
  final HitTarget hitTarget;
  final int modifiers;
  final int command;
}

/// Editor options passed to create_editor as binary payload.
class EditorOptions {
  const EditorOptions({
    this.touchSlop = 10,
    this.doubleTapTimeout = 300,
    this.longPressMs = 500,
    this.flingFriction = 3.5,
    this.flingMinVelocity = 50,
    this.flingMaxVelocity = 8000,
    this.maxUndoStackSize = 512,
    this.keyChordTimeoutMs = 2000,
    this.revealSelectionEndOnSelectAll = false,
  });

  final double touchSlop;
  final int doubleTapTimeout;
  final int longPressMs;
  final double flingFriction;
  final double flingMinVelocity;
  final double flingMaxVelocity;
  final int maxUndoStackSize;
  final int keyChordTimeoutMs;
  final bool revealSelectionEndOnSelectAll;

  /// Serialize to LE binary payload matching C API EditorOptions layout.
  Uint8List toBytes() {
    final data = ByteData(4 + 8 + 8 + 4 + 4 + 4 + 8 + 8 + 1);
    var offset = 0;
    data.setFloat32(offset, touchSlop, Endian.little);
    offset += 4;
    data.setInt64(offset, doubleTapTimeout, Endian.little);
    offset += 8;
    data.setInt64(offset, longPressMs, Endian.little);
    offset += 8;
    data.setFloat32(offset, flingFriction, Endian.little);
    offset += 4;
    data.setFloat32(offset, flingMinVelocity, Endian.little);
    offset += 4;
    data.setFloat32(offset, flingMaxVelocity, Endian.little);
    offset += 4;
    data.setUint64(offset, maxUndoStackSize, Endian.little);
    offset += 8;
    data.setInt64(offset, keyChordTimeoutMs, Endian.little);
    offset += 8;
    data.setUint8(offset, revealSelectionEndOnSelectAll ? 1 : 0);
    return data.buffer.asUint8List();
  }
}

/// Handle hit-test configuration.
class HandleConfig {
  const HandleConfig({
    this.startLeft = -32.1,
    this.startTop = -8.0,
    this.startRight = 8.0,
    this.startBottom = 32.1,
    this.endLeft = -8.0,
    this.endTop = -8.0,
    this.endRight = 32.1,
    this.endBottom = 32.1,
  });

  final double startLeft;
  final double startTop;
  final double startRight;
  final double startBottom;
  final double endLeft;
  final double endTop;
  final double endRight;
  final double endBottom;
}

/// Scrollbar configuration.
class ScrollbarConfig {
  const ScrollbarConfig({
    this.thickness = 10.0,
    this.minThumb = 24.0,
    this.thumbHitPadding = 0.0,
    this.mode = ScrollbarMode.always,
    this.thumbDraggable = true,
    this.trackTapMode = ScrollbarTrackTapMode.jump,
    this.fadeDelayMs = 1500,
    this.fadeDurationMs = 300,
  });

  final double thickness;
  final double minThumb;
  final double thumbHitPadding;
  final ScrollbarMode mode;
  final bool thumbDraggable;
  final ScrollbarTrackTapMode trackTapMode;
  final int fadeDelayMs;
  final int fadeDurationMs;
}

/// Gesture event input.
class GestureEvent {
  const GestureEvent({
    required this.type,
    required this.points,
    this.modifiers = Modifier.none,
    this.wheelDeltaX = 0,
    this.wheelDeltaY = 0,
    this.directScale = 1,
  });

  final int type;
  final List<PointF> points;
  final int modifiers;
  final double wheelDeltaX;
  final double wheelDeltaY;
  final double directScale;
}

class EditorCore {
  /// Create an EditorCore with the given text measurer callbacks and options.
  EditorCore({
    required bindings.text_measurer_t measurer,
    EditorOptions options = const EditorOptions(),
  }) : _handle = _createEditor(measurer, options) {
    if (_handle == 0) {
      throw SweetEditorException('Failed to create EditorCore');
    }
  }

  static int _createEditor(
    bindings.text_measurer_t measurer,
    EditorOptions options,
  ) {
    return using((arena) {
      final bytes = options.toBytes();
      final optionsPtr = arena.allocate<ffi.Uint8>(bytes.length);
      optionsPtr.asTypedList(bytes.length).setAll(0, bytes);
      return bindings.create_editor(measurer, optionsPtr, bytes.length);
    });
  }

  final int _handle;
  bool _closed = false;

  int get handle => _handle;

  EditorActionResult loadDocument(Document document) {
    _ensureOpen();
    document._ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.set_editor_document(_handle, document._handle, outSize),
    );
  }

  EditorActionResult setViewport(int width, int height) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.set_editor_viewport(_handle, width, height, outSize),
    );
  }

  EditorActionResult onFontMetricsChanged() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_on_font_metrics_changed(_handle, outSize),
    );
  }

  EditorActionResult setFoldArrowMode(FoldArrowMode mode) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_fold_arrow_mode(_handle, mode.value, outSize),
    );
  }

  EditorActionResult setWrapMode(WrapMode mode) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_wrap_mode(_handle, mode.value, outSize),
    );
  }

  EditorActionResult setTabSize(int tabSize) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_tab_size(_handle, tabSize, outSize),
    );
  }

  EditorActionResult setInsertSpaces(bool enabled) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_insert_spaces(_handle, enabled ? 1 : 0, outSize),
    );
  }

  EditorActionResult setKeyMap(KeyMap keyMap) {
    _ensureOpen();
    final bytes = keyMap.toBytes();
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) =>
          bindings.editor_set_keymap(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setScale(double scale) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_scale(_handle, scale, outSize),
    );
  }

  EditorActionResult setLineSpacing({double add = 0, double mult = 1.0}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_line_spacing(_handle, add, mult, outSize),
    );
  }

  EditorActionResult setContentStartPadding(double padding) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_content_start_padding(_handle, padding, outSize),
    );
  }

  EditorActionResult setShowSplitLine(bool show) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_show_split_line(_handle, show ? 1 : 0, outSize),
    );
  }

  EditorActionResult setCurrentLineRenderMode(CurrentLineRenderMode mode) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_current_line_render_mode(
        _handle,
        mode.value,
        outSize,
      ),
    );
  }

  EditorActionResult setGutterSticky(bool sticky) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_gutter_sticky(_handle, sticky ? 1 : 0, outSize),
    );
  }

  EditorActionResult setGutterVisible(bool visible) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_gutter_visible(_handle, visible ? 1 : 0, outSize),
    );
  }

  EditorActionResult setReadOnly(bool readOnly) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_read_only(_handle, readOnly ? 1 : 0, outSize),
    );
  }

  bool get isReadOnly {
    _ensureOpen();
    return bindings.editor_is_read_only(_handle) != 0;
  }

  EditorActionResult setAutoIndentMode(AutoIndentMode mode) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_auto_indent_mode(_handle, mode.value, outSize),
    );
  }

  AutoIndentMode get autoIndentMode {
    _ensureOpen();
    return AutoIndentMode.values.firstWhere(
      (m) => m.value == bindings.editor_get_auto_indent_mode(_handle),
      orElse: () => AutoIndentMode.none,
    );
  }

  EditorActionResult setBackspaceUnindent(bool enabled) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_backspace_unindent(
        _handle,
        enabled ? 1 : 0,
        outSize,
      ),
    );
  }

  EditorActionResult setHandleConfig(HandleConfig config) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_handle_config(
        _handle,
        config.startLeft,
        config.startTop,
        config.startRight,
        config.startBottom,
        config.endLeft,
        config.endTop,
        config.endRight,
        config.endBottom,
        outSize,
      ),
    );
  }

  EditorActionResult setScrollbarConfig(ScrollbarConfig config) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_scrollbar_config(
        _handle,
        config.thickness,
        config.minThumb,
        config.thumbHitPadding,
        config.mode.value,
        config.thumbDraggable ? 1 : 0,
        config.trackTapMode.value,
        config.fadeDelayMs,
        config.fadeDurationMs,
        outSize,
      ),
    );
  }

  /// Build render model. Returns parsed [EditorRenderModel].
  EditorRenderModel buildRenderModel() {
    _ensureOpen();
    return _callAndParse(
      EditorRenderModel.empty,
      (outSize) => bindings.build_editor_render_model(_handle, outSize),
      ProtocolDecoder.decodeRenderModel,
    );
  }

  /// Build render model and return raw bytes (for custom parsing).
  Uint8List? buildRenderModelRaw() {
    _ensureOpen();
    return using((arena) {
      final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ptr = bindings.build_editor_render_model(_handle, outSize);
      if (ptr == ffi.nullptr) return null;
      final size = outSize.value;
      final bytes = Uint8List.fromList(ptr.asTypedList(size));
      bindings.free_binary_data(ptr.address);
      return bytes;
    });
  }

  LayoutMetrics getLayoutMetrics() {
    _ensureOpen();
    return _callAndParse(
      LayoutMetrics.empty,
      (outSize) => bindings.get_layout_metrics(_handle, outSize),
      ProtocolDecoder.decodeLayoutMetrics,
    );
  }

  EditorActionResult handleGestureEvent(GestureEvent event) {
    return handleGestureEventEx(
      type: event.type,
      points: event.points,
      modifiers: event.modifiers,
      wheelDeltaX: event.wheelDeltaX,
      wheelDeltaY: event.wheelDeltaY,
      directScale: event.directScale,
    );
  }

  EditorActionResult handleGestureEventEx({
    required int type,
    required List<PointF> points,
    int modifiers = 0,
    double wheelDeltaX = 0,
    double wheelDeltaY = 0,
    double directScale = 0,
  }) {
    _ensureOpen();
    return using((arena) {
      final flatPoints = <double>[];
      for (final p in points) {
        flatPoints.add(p.x);
        flatPoints.add(p.y);
      }
      final pointsPtr = arena.allocate<ffi.Float>(
        flatPoints.length * ffi.sizeOf<ffi.Float>(),
      );
      for (var i = 0; i < flatPoints.length; i++) {
        (pointsPtr + i).value = flatPoints[i];
      }
      final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ptr = bindings.handle_editor_gesture_event_ex(
        _handle,
        type,
        points.length,
        pointsPtr,
        modifiers,
        wheelDeltaX,
        wheelDeltaY,
        directScale,
        outSize,
      );
      if (ptr == ffi.nullptr) return EditorActionResult.empty;
      final size = outSize.value;
      try {
        return ProtocolDecoder.decodeEditorActionResult(ptr, size);
      } finally {
        bindings.free_binary_data(ptr.address);
      }
    });
  }

  EditorActionResult tickEdgeScroll() {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_tick_edge_scroll(_handle, outSize),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult tickFling() {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_tick_fling(_handle, outSize),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult tickAnimations() {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_tick_animations(_handle, outSize),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult handleKeyEvent(
    KeyCode keyCode, {
    String? text,
    int modifiers = 0,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = text != null
          ? _toNativeUtf8(text, arena)
          : ffi.nullptr.cast<ffi.Char>();
      final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ptr = bindings.handle_editor_key_event(
        _handle,
        keyCode.value,
        textPtr,
        modifiers,
        outSize,
      );
      if (ptr == ffi.nullptr) return EditorActionResult.empty;
      final size = outSize.value;
      try {
        return ProtocolDecoder.decodeEditorActionResult(ptr, size);
      } finally {
        bindings.free_binary_data(ptr.address);
      }
    });
  }

  EditorActionResult insertText(String text) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_insert_text(_handle, textPtr, outSize),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult replaceText(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
    String text,
  ) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_replace_text(
          _handle,
          startLine,
          startColumn,
          endLine,
          endColumn,
          textPtr,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult deleteText(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
  ) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_delete_text(
        _handle,
        startLine,
        startColumn,
        endLine,
        endColumn,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult backspace() =>
      _simpleEdit((s) => bindings.editor_backspace(_handle, s));
  EditorActionResult deleteForward() =>
      _simpleEdit((s) => bindings.editor_delete_forward(_handle, s));
  EditorActionResult moveLineUp() =>
      _simpleEdit((s) => bindings.editor_move_line_up(_handle, s));
  EditorActionResult moveLineDown() =>
      _simpleEdit((s) => bindings.editor_move_line_down(_handle, s));
  EditorActionResult copyLineUp() =>
      _simpleEdit((s) => bindings.editor_copy_line_up(_handle, s));
  EditorActionResult copyLineDown() =>
      _simpleEdit((s) => bindings.editor_copy_line_down(_handle, s));
  EditorActionResult deleteLine() =>
      _simpleEdit((s) => bindings.editor_delete_line(_handle, s));
  EditorActionResult insertLineAbove() =>
      _simpleEdit((s) => bindings.editor_insert_line_above(_handle, s));
  EditorActionResult insertLineBelow() =>
      _simpleEdit((s) => bindings.editor_insert_line_below(_handle, s));
  EditorActionResult undo() =>
      _simpleEdit((s) => bindings.editor_undo(_handle, s));
  EditorActionResult redo() =>
      _simpleEdit((s) => bindings.editor_redo(_handle, s));

  EditorActionResult _simpleEdit(
    ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Size>) fn,
  ) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      fn,
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  bool get canUndo {
    _ensureOpen();
    return bindings.editor_can_undo(_handle) != 0;
  }

  bool get canRedo {
    _ensureOpen();
    return bindings.editor_can_redo(_handle) != 0;
  }

  EditorActionResult setCursorPosition(int line, int column) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_cursor_position(_handle, line, column, outSize),
    );
  }

  TextPosition getCursorPosition() {
    _ensureOpen();
    return using((arena) {
      final outLine = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final outColumn = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      bindings.editor_get_cursor_position(_handle, outLine, outColumn);
      return TextPosition(outLine.value, outColumn.value);
    });
  }

  EditorActionResult selectAll() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_select_all(_handle, outSize),
    );
  }

  EditorActionResult setSelection(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
  ) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_selection(
        _handle,
        startLine,
        startColumn,
        endLine,
        endColumn,
        outSize,
      ),
    );
  }

  TextRange? getSelection() {
    _ensureOpen();
    return using((arena) {
      final sl = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final sc = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final el = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ec = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      if (bindings.editor_get_selection(_handle, sl, sc, el, ec) == 0) {
        return null;
      }
      return TextRange(
        TextPosition(sl.value, sc.value),
        TextPosition(el.value, ec.value),
      );
    });
  }

  String getSelectedText() {
    _ensureOpen();
    return _readNativeUtf8(bindings.editor_get_selected_text(_handle));
  }

  TextRange getWordRangeAtCursor() {
    _ensureOpen();
    return using((arena) {
      final sl = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final sc = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final el = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ec = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      bindings.editor_get_word_range_at_cursor(_handle, sl, sc, el, ec);
      return TextRange(
        TextPosition(sl.value, sc.value),
        TextPosition(el.value, ec.value),
      );
    });
  }

  String getWordAtCursor() {
    _ensureOpen();
    return _readNativeUtf8(bindings.editor_get_word_at_cursor(_handle));
  }

  String getLinkTargetAt(int line, int column) {
    _ensureOpen();
    final ptr = bindings.editor_get_link_target_at(_handle, line, column);
    return _readNativeUtf8(ptr);
  }

  EditorActionResult moveCursorLeft({bool extendSelection = false}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_move_cursor_left(
        _handle,
        extendSelection ? 1 : 0,
        outSize,
      ),
    );
  }

  EditorActionResult moveCursorRight({bool extendSelection = false}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_move_cursor_right(
        _handle,
        extendSelection ? 1 : 0,
        outSize,
      ),
    );
  }

  EditorActionResult moveCursorUp({bool extendSelection = false}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_move_cursor_up(
        _handle,
        extendSelection ? 1 : 0,
        outSize,
      ),
    );
  }

  EditorActionResult moveCursorDown({bool extendSelection = false}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_move_cursor_down(
        _handle,
        extendSelection ? 1 : 0,
        outSize,
      ),
    );
  }

  EditorActionResult moveCursorToLineStart({bool extendSelection = false}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_move_cursor_to_line_start(
        _handle,
        extendSelection ? 1 : 0,
        outSize,
      ),
    );
  }

  EditorActionResult moveCursorToLineEnd({bool extendSelection = false}) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_move_cursor_to_line_end(
        _handle,
        extendSelection ? 1 : 0,
        outSize,
      ),
    );
  }

  bool get isComposing {
    _ensureOpen();
    return bindings.editor_is_composing(_handle) != 0;
  }

  TextRange? getComposingRange() {
    _ensureOpen();
    return using((arena) {
      final sl = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final sc = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final el = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final ec = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      bindings.editor_get_composing_range(_handle, sl, sc, el, ec);
      return _readNullableRange(sl.value, sc.value, el.value, ec.value);
    });
  }

  TextRange? getComposingSessionRange() {
    _ensureOpen();
    return using((arena) {
      final sl = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final sc = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final el = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final ec = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      bindings.editor_get_composing_session_range(_handle, sl, sc, el, ec);
      return _readNullableRange(sl.value, sc.value, el.value, ec.value);
    });
  }

  EditorActionResult updateImePreedit(
    String text, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_update_preedit(
          _handle,
          textPtr,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult setImeComposingText(
    String text, {
    int cursorOffset = 1,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_set_composing_text(
          _handle,
          textPtr,
          cursorOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult setImeComposingTextSelection(
    String text, {
    required int selectionStartOffset,
    required int selectionEndOffset,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_set_composing_text_selection(
          _handle,
          textPtr,
          selectionStartOffset,
          selectionEndOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult commitImeText(
    String text, {
    int? cursorOffset,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => cursorOffset == null
            ? bindings.editor_ime_commit_text(
                _handle,
                textPtr,
                scriptClass.value,
                outSize,
              )
            : bindings.editor_ime_commit_text_with_cursor(
                _handle,
                textPtr,
                cursorOffset,
                scriptClass.value,
                outSize,
              ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult finishImePreedit() {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_finish_preedit(_handle, outSize),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult cancelImePreedit() {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_cancel_preedit(_handle, outSize),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult markImeDocumentRange(
    TextRange range, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_mark_document_range(
        _handle,
        range.start.line,
        range.start.column,
        range.end.line,
        range.end.column,
        scriptClass.value,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult markImeDocumentRangeByOffset(
    int startOffset,
    int endOffset, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_mark_document_range_by_offset(
        _handle,
        startOffset,
        endOffset,
        scriptClass.value,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult replaceImeText(
    TextRange range,
    String text, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_replace_text(
          _handle,
          range.start.line,
          range.start.column,
          range.end.line,
          range.end.column,
          textPtr,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult replaceImeDocumentText(
    int startOffset,
    int endOffset,
    String text, {
    int cursorOffset = 1,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_replace_document_text(
          _handle,
          startOffset,
          endOffset,
          textPtr,
          cursorOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult replaceImeInputContextText(
    int startOffset,
    int endOffset,
    String text, {
    int cursorOffset = 1,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_replace_input_context_text(
          _handle,
          startOffset,
          endOffset,
          textPtr,
          cursorOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult markImeInputContextRange(
    int startOffset,
    int endOffset, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_mark_input_context_range(
        _handle,
        startOffset,
        endOffset,
        scriptClass.value,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult notifyImeDocumentSelectionChanged(
    int startOffset,
    int endOffset,
  ) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_notify_document_selection_changed(
        _handle,
        startOffset,
        endOffset,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult notifyImeInputContextSelectionChanged(
    int startOffset,
    int endOffset,
  ) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_notify_input_context_selection_changed(
        _handle,
        startOffset,
        endOffset,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult updateImeInputStateText({
    required int contextId,
    required int documentStartOffset,
    required String text,
    required int selectionStartOffset,
    required int selectionEndOffset,
    required int composingStartOffset,
    required int composingEndOffset,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_update_input_state_text(
          _handle,
          contextId,
          documentStartOffset,
          textPtr,
          selectionStartOffset,
          selectionEndOffset,
          composingStartOffset,
          composingEndOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult updateImeTextModelState({
    required ImeTextModelMode mode,
    required int contextId,
    required int documentStartOffset,
    required String text,
    required int selectionStartOffset,
    required int selectionEndOffset,
    required int composingStartOffset,
    required int composingEndOffset,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_update_text_model_state(
          _handle,
          mode.value,
          contextId,
          documentStartOffset,
          textPtr,
          selectionStartOffset,
          selectionEndOffset,
          composingStartOffset,
          composingEndOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult updateImeTextModelDelta({
    required ImeTextModelMode mode,
    required int contextId,
    required int documentStartOffset,
    required String oldText,
    required int deltaStartOffset,
    required int deltaEndOffset,
    required String deltaText,
    required int selectionStartOffset,
    required int selectionEndOffset,
    required int composingStartOffset,
    required int composingEndOffset,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final oldTextPtr = _toNativeUtf8(oldText, arena);
      final deltaTextPtr = _toNativeUtf8(deltaText, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_update_text_model_delta(
          _handle,
          mode.value,
          contextId,
          documentStartOffset,
          oldTextPtr,
          deltaStartOffset,
          deltaEndOffset,
          deltaTextPtr,
          selectionStartOffset,
          selectionEndOffset,
          composingStartOffset,
          composingEndOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult updateImeInputStateSelection({
    required int contextId,
    required int documentStartOffset,
    required int selectionStartOffset,
    required int selectionEndOffset,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_update_input_state_selection(
        _handle,
        contextId,
        documentStartOffset,
        selectionStartOffset,
        selectionEndOffset,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult replaceImeInputStateText(
    int contextId,
    int documentStartOffset,
    int startOffset,
    int endOffset,
    String text, {
    int cursorOffset = 1,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_replace_input_state_text(
          _handle,
          contextId,
          documentStartOffset,
          startOffset,
          endOffset,
          textPtr,
          cursorOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult commitImeInputStateTextReplacement(
    int contextId,
    int documentStartOffset,
    int startOffset,
    int endOffset,
    String text, {
    int cursorOffset = 1,
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = _toNativeUtf8(text, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) => bindings.editor_ime_commit_input_state_text_replacement(
          _handle,
          contextId,
          documentStartOffset,
          startOffset,
          endOffset,
          textPtr,
          cursorOffset,
          scriptClass.value,
          outSize,
        ),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult deleteImeBackward({
    int beforeLength = 1,
    ImeTextUnit textUnit = ImeTextUnit.grapheme,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_delete_backward(
        _handle,
        beforeLength,
        textUnit.value,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult deleteImeForward({
    int afterLength = 1,
    ImeTextUnit textUnit = ImeTextUnit.grapheme,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_delete_forward(
        _handle,
        afterLength,
        textUnit.value,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult deleteImeSurrounding({
    required int beforeLength,
    required int afterLength,
    ImeTextUnit textUnit = ImeTextUnit.grapheme,
  }) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_delete_surrounding(
        _handle,
        beforeLength,
        afterLength,
        textUnit.value,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult notifyImeSelectionChanged(TextRange range) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_notify_selection_changed(
        _handle,
        range.start.line,
        range.start.column,
        range.end.line,
        range.end.column,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult notifyImeCursorChanged(TextPosition cursor) {
    _ensureOpen();
    return _callAndParse(
      EditorActionResult.empty,
      (outSize) => bindings.editor_ime_notify_cursor_changed(
        _handle,
        cursor.line,
        cursor.column,
        outSize,
      ),
      ProtocolDecoder.decodeEditorActionResult,
    );
  }

  EditorActionResult setImeKeyboardScriptClass(ImeScriptClass scriptClass) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_ime_set_keyboard_script_class(
        _handle,
        scriptClass.value,
        outSize,
      ),
    );
  }

  ImeScriptClass getImeKeyboardScriptClass() {
    _ensureOpen();
    return ImeScriptClass.fromValue(
      bindings.editor_ime_get_keyboard_script_class(_handle),
    );
  }

  ImeSyncSnapshot getImeSyncSnapshot() {
    _ensureOpen();
    return _callAndParse(
      ImeSyncSnapshot.empty,
      (outSize) => bindings.editor_get_ime_sync_snapshot(_handle, outSize),
      ProtocolDecoder.decodeImeSyncSnapshot,
    );
  }

  ImeInputContext getImeInputContext(int beforeLength, int afterLength) {
    _ensureOpen();
    return _callAndParse(
      ImeInputContext.empty,
      (outSize) => bindings.editor_get_ime_input_context(
        _handle,
        beforeLength,
        afterLength,
        outSize,
      ),
      ProtocolDecoder.decodeImeInputContext,
    );
  }

  ImeInputContext getImeTextModelInputContext(
    ImeTextModelMode mode,
    int beforeLength,
    int afterLength,
  ) {
    _ensureOpen();
    return _callAndParse(
      ImeInputContext.empty,
      (outSize) => bindings.editor_get_ime_text_model_input_context(
        _handle,
        mode.value,
        beforeLength,
        afterLength,
        outSize,
      ),
      ProtocolDecoder.decodeImeInputContext,
    );
  }

  TextRange? _readNullableRange(
    int startLine,
    int startColumn,
    int endLine,
    int endColumn,
  ) {
    if (startLine < 0 || startColumn < 0 || endLine < 0 || endColumn < 0) {
      return null;
    }
    return TextRange(
      TextPosition(startLine, startColumn),
      TextPosition(endLine, endColumn),
    );
  }

  EditorActionResult scrollToLine(
    int line, {
    ScrollBehavior behavior = ScrollBehavior.center,
  }) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_scroll_to_line(
        _handle,
        line,
        behavior.value,
        outSize,
      ),
    );
  }

  EditorActionResult gotoPosition(int line, int column) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_goto_position(_handle, line, column, outSize),
    );
  }

  EditorActionResult ensureCursorVisible() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_ensure_cursor_visible(_handle, outSize),
    );
  }

  EditorActionResult setScroll(double scrollX, double scrollY) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_scroll(_handle, scrollX, scrollY, outSize),
    );
  }

  ScrollMetrics getScrollMetrics() {
    _ensureOpen();
    return _callAndParse(
      ScrollMetrics.empty,
      (outSize) => bindings.editor_get_scroll_metrics(_handle, outSize),
      ProtocolDecoder.decodeScrollMetrics,
    );
  }

  IntRange getVisibleLineRange() {
    _ensureOpen();
    return using((arena) {
      final outStartLine = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final outEndLine = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      bindings.editor_get_visible_line_range(_handle, outStartLine, outEndLine);
      return IntRange(outStartLine.value, outEndLine.value);
    });
  }

  CursorRect getPositionRect(int line, int column) {
    _ensureOpen();
    return using((arena) {
      final outX = arena.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      final outY = arena.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      final outHeight = arena.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      bindings.editor_get_position_rect(
        _handle,
        line,
        column,
        outX,
        outY,
        outHeight,
      );
      return CursorRect(x: outX.value, y: outY.value, height: outHeight.value);
    });
  }

  CursorRect getCursorRect() {
    _ensureOpen();
    return using((arena) {
      final outX = arena.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      final outY = arena.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      final outHeight = arena.allocate<ffi.Float>(ffi.sizeOf<ffi.Float>());
      bindings.editor_get_cursor_rect(_handle, outX, outY, outHeight);
      return CursorRect(x: outX.value, y: outY.value, height: outHeight.value);
    });
  }

  EditorActionResult registerTextStyle(
    int styleId,
    int color, {
    int backgroundColor = 0,
    int fontStyle = 0,
  }) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_register_text_style(
        _handle,
        styleId,
        color,
        backgroundColor,
        fontStyle,
        outSize,
      ),
    );
  }

  EditorActionResult setLineSpans(
    int line,
    SpanLayer layer,
    List<StyleSpan> spans,
  ) {
    return setLineSpansRaw(
      ProtocolEncoder.packLineSpans(line, layer.value, spans),
    );
  }

  EditorActionResult setLineSpansRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_spans(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLineSpans(
    SpanLayer layer,
    Map<int, List<StyleSpan>> spansByLine,
  ) {
    return setBatchLineSpansRaw(
      ProtocolEncoder.packBatchLineSpans(layer.value, spansByLine),
    );
  }

  EditorActionResult setBatchLineSpansRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_batch_line_spans(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setLineInlayHints(int line, List<InlayHint> hints) {
    return setLineInlayHintsRaw(
      ProtocolEncoder.packLineInlayHints(line, hints),
    );
  }

  EditorActionResult setLineInlayHintsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_inlay_hints(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLineInlayHints(
    Map<int, List<InlayHint>> hintsByLine,
  ) {
    return setBatchLineInlayHintsRaw(
      ProtocolEncoder.packBatchLineInlayHints(hintsByLine),
    );
  }

  EditorActionResult setBatchLineInlayHintsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) => bindings.editor_set_batch_line_inlay_hints(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult setLinePhantomTexts(int line, List<PhantomText> phantoms) {
    return setLinePhantomTextsRaw(
      ProtocolEncoder.packLinePhantomTexts(line, phantoms),
    );
  }

  EditorActionResult setLinePhantomTextsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_phantom_texts(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLinePhantomTexts(
    Map<int, List<PhantomText>> phantomsByLine,
  ) {
    return setBatchLinePhantomTextsRaw(
      ProtocolEncoder.packBatchLinePhantomTexts(phantomsByLine),
    );
  }

  EditorActionResult setBatchLinePhantomTextsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) => bindings.editor_set_batch_line_phantom_texts(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult setLineGutterIcons(int line, List<GutterIcon> icons) {
    return setLineGutterIconsRaw(
      ProtocolEncoder.packLineGutterIcons(line, icons),
    );
  }

  EditorActionResult setLineGutterIconsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_gutter_icons(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLineGutterIcons(
    Map<int, List<GutterIcon>> iconsByLine,
  ) {
    return setBatchLineGutterIconsRaw(
      ProtocolEncoder.packBatchLineGutterIcons(iconsByLine),
    );
  }

  EditorActionResult setBatchLineGutterIconsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) => bindings.editor_set_batch_line_gutter_icons(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult setLineCodeLens(int line, List<CodeLensItem> items) {
    return setLineCodeLensRaw(ProtocolEncoder.packLineCodeLens(line, items));
  }

  EditorActionResult setLineCodeLensRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_codelens(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLineCodeLens(
    Map<int, List<CodeLensItem>> itemsByLine,
  ) {
    return setBatchLineCodeLensRaw(
      ProtocolEncoder.packBatchLineCodeLens(itemsByLine),
    );
  }

  EditorActionResult setBatchLineCodeLensRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_batch_line_codelens(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setLineLinks(int line, List<LinkSpan> links) {
    return setLineLinksRaw(ProtocolEncoder.packLineLinks(line, links));
  }

  EditorActionResult setLineLinksRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_links(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLineLinks(Map<int, List<LinkSpan>> linksByLine) {
    return setBatchLineLinksRaw(
      ProtocolEncoder.packBatchLineLinks(linksByLine),
    );
  }

  EditorActionResult setBatchLineLinksRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_batch_line_links(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setLineDiagnostics(int line, List<Diagnostic> items) {
    return setLineDiagnosticsRaw(
      ProtocolEncoder.packLineDiagnostics(line, items),
    );
  }

  EditorActionResult setLineDiagnosticsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_diagnostics(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBatchLineDiagnostics(
    Map<int, List<Diagnostic>> itemsByLine,
  ) {
    return setBatchLineDiagnosticsRaw(
      ProtocolEncoder.packBatchLineDiagnostics(itemsByLine),
    );
  }

  EditorActionResult setBatchLineDiagnosticsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) => bindings.editor_set_batch_line_diagnostics(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult setIndentGuides(List<IndentGuide> guides) {
    return setIndentGuidesRaw(ProtocolEncoder.packIndentGuides(guides));
  }

  EditorActionResult setIndentGuidesRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_indent_guides(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setBracketGuides(List<BracketGuide> guides) {
    return setBracketGuidesRaw(ProtocolEncoder.packBracketGuides(guides));
  }

  EditorActionResult setBracketGuidesRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_bracket_guides(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setFlowGuides(List<FlowGuide> guides) {
    return setFlowGuidesRaw(ProtocolEncoder.packFlowGuides(guides));
  }

  EditorActionResult setFlowGuidesRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_flow_guides(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setSeparatorGuides(List<SeparatorGuide> guides) {
    return setSeparatorGuidesRaw(ProtocolEncoder.packSeparatorGuides(guides));
  }

  EditorActionResult setSeparatorGuidesRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_separator_guides(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult setMaxGutterIcons(int count) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_max_gutter_icons(_handle, count, outSize),
    );
  }

  EditorActionResult registerBatchTextStyles(Map<int, TextStyle> stylesById) {
    return registerBatchTextStylesRaw(
      ProtocolEncoder.packBatchTextStyles(stylesById),
    );
  }

  EditorActionResult registerBatchTextStylesRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) => bindings.editor_register_batch_text_styles(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult clearLineSpans(int line, SpanLayer layer) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_clear_line_spans(_handle, line, layer.value, outSize),
    );
  }

  EditorActionResult clearHighlights([SpanLayer? layer]) {
    _ensureOpen();
    if (layer == null) {
      return _callAndParseAction(
        (outSize) => bindings.editor_clear_highlights(_handle, outSize),
      );
    } else {
      return _callAndParseAction(
        (outSize) => bindings.editor_clear_highlights_layer(
          _handle,
          layer.value,
          outSize,
        ),
      );
    }
  }

  EditorActionResult clearInlayHints() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_inlay_hints(_handle, outSize),
    );
  }

  EditorActionResult clearPhantomTexts() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_phantom_texts(_handle, outSize),
    );
  }

  EditorActionResult clearAllDecorations() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_all_decorations(_handle, outSize),
    );
  }

  EditorActionResult clearDiagnostics() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_diagnostics(_handle, outSize),
    );
  }

  EditorActionResult clearGutterIcons() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_gutter_icons(_handle, outSize),
    );
  }

  EditorActionResult clearCodeLens() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_codelens(_handle, outSize),
    );
  }

  EditorActionResult clearLinks() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_links(_handle, outSize),
    );
  }

  EditorActionResult clearGuides() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_guides(_handle, outSize),
    );
  }

  EditorActionResult setBracketPairs(
    List<int> openChars,
    List<int> closeChars,
  ) {
    _ensureOpen();
    assert(openChars.length == closeChars.length);
    return using((arena) {
      final openPtr = arena.allocate<ffi.Uint32>(openChars.length);
      final closePtr = arena.allocate<ffi.Uint32>(closeChars.length);
      openPtr.asTypedList(openChars.length).setAll(0, openChars);
      closePtr.asTypedList(closeChars.length).setAll(0, closeChars);
      return _callAndParseAction(
        (outSize) => bindings.editor_set_bracket_pairs(
          _handle,
          openPtr,
          closePtr,
          openChars.length,
          outSize,
        ),
      );
    });
  }

  EditorActionResult setAutoClosingPairs(
    List<int> openChars,
    List<int> closeChars,
  ) {
    _ensureOpen();
    assert(openChars.length == closeChars.length);
    return using((arena) {
      final openPtr = arena.allocate<ffi.Uint32>(openChars.length);
      final closePtr = arena.allocate<ffi.Uint32>(closeChars.length);
      openPtr.asTypedList(openChars.length).setAll(0, openChars);
      closePtr.asTypedList(closeChars.length).setAll(0, closeChars);
      return _callAndParseAction(
        (outSize) => bindings.editor_set_auto_closing_pairs(
          _handle,
          openPtr,
          closePtr,
          openChars.length,
          outSize,
        ),
      );
    });
  }

  EditorActionResult setMatchedBrackets(
    int openLine,
    int openColumn,
    int closeLine,
    int closeColumn,
  ) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_set_matched_brackets(
        _handle,
        openLine,
        openColumn,
        closeLine,
        closeColumn,
        outSize,
      ),
    );
  }

  EditorActionResult clearMatchedBrackets() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_clear_matched_brackets(_handle, outSize),
    );
  }

  EditorActionResult setFoldRegions(List<FoldRegion> regions) {
    return setFoldRegionsRaw(ProtocolEncoder.packFoldRegions(regions));
  }

  EditorActionResult setFoldRegionsRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_fold_regions(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult toggleFoldAt(int line) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_toggle_fold(_handle, line, outSize),
    );
  }

  EditorActionResult foldAt(int line) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_fold_at(_handle, line, outSize),
    );
  }

  EditorActionResult unfoldAt(int line) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_unfold_at(_handle, line, outSize),
    );
  }

  EditorActionResult foldAll() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_fold_all(_handle, outSize),
    );
  }

  EditorActionResult unfoldAll() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_unfold_all(_handle, outSize),
    );
  }

  bool isLineVisible(int line) {
    _ensureOpen();
    return bindings.editor_is_line_visible(_handle, line) != 0;
  }

  EditorActionResult insertSnippet(String snippetTemplate) {
    _ensureOpen();
    return using((arena) {
      final templatePtr = _toNativeUtf8(snippetTemplate, arena);
      return _callAndParse(
        EditorActionResult.empty,
        (outSize) =>
            bindings.editor_insert_snippet(_handle, templatePtr, outSize),
        ProtocolDecoder.decodeEditorActionResult,
      );
    });
  }

  EditorActionResult startLinkedEditing(LinkedEditingModel model) {
    _ensureOpen();
    return startLinkedEditingRaw(ProtocolEncoder.packLinkedEditingModel(model));
  }

  EditorActionResult startLinkedEditingRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_start_linked_editing(_handle, ptr, len, outSize),
    );
  }

  bool get isInLinkedEditing {
    _ensureOpen();
    return bindings.editor_is_in_linked_editing(_handle) != 0;
  }

  EditorActionResult linkedEditingNext() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_linked_editing_next(_handle, outSize),
    );
  }

  EditorActionResult linkedEditingPrev() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_linked_editing_prev(_handle, outSize),
    );
  }

  EditorActionResult cancelLinkedEditing() {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) => bindings.editor_cancel_linked_editing(_handle, outSize),
    );
  }

  void close() {
    if (_closed) return;
    _closed = true;
    bindings.free_editor(_handle);
  }

  void dispose() => close();

  void _ensureOpen() {
    if (_closed) throw StateError('EditorCore is already closed');
  }
}

class Document {
  /// Create a document from a Dart string.
  Document.fromString(String text)
    : _handle = using((arena) {
        final textPtr = _toNativeUtf16(text, arena);
        return bindings.create_document_from_utf16(textPtr);
      }) {
    if (_handle == 0) {
      throw SweetEditorException('Failed to create document from string');
    }
  }

  /// Create a document from a local file path.
  Document.fromFile(String path)
    : _handle = using((arena) {
        final pathPtr = _toNativeUtf8(path, arena);
        return bindings.create_document_from_file(pathPtr);
      }) {
    if (_handle == 0) {
      throw SweetEditorException('Failed to create document from file: $path');
    }
  }

  final int _handle;
  bool _closed = false;

  int get handle => _handle;

  /// Get document text as UTF8 string.
  String get text {
    _ensureOpen();
    final ptr = bindings.get_document_utf8(_handle);
    return _readNativeUtf8(ptr);
  }

  /// Get a single line's text (0-indexed).
  String getLineText(int line) {
    _ensureOpen();
    final ptr = bindings.get_document_line_utf16(_handle, line);
    return _readNativeUtf16(ptr);
  }

  /// Get total line count.
  int get lineCount {
    _ensureOpen();
    return bindings.get_document_line_count(_handle);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    bindings.free_document(_handle);
  }

  void dispose() => close();

  void _ensureOpen() {
    if (_closed) throw StateError('Document is already closed');
  }
}
