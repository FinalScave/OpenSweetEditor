import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../sweeteditor_bindings_generated.dart' as bindings;

part 'core_action.dart';
part 'core_config.dart';
part 'core_foundation.dart';
part 'core_adornments.dart';
part 'core_ime.dart';
part 'core_interaction.dart';
part 'core_keymap.dart';
part 'core_linked_editing.dart';
part 'core_visual.dart';
part 'core_protocol.dart';

class SweetEditorException implements Exception {
  SweetEditorException(this.message);

  final String message;

  @override
  String toString() => 'SweetEditorException: $message';
}

ffi.Pointer<ffi.Char> _toNativeUtf8(String value, ffi.Allocator allocator) {
  return value.toNativeUtf8(allocator: allocator).cast<ffi.Char>();
}

ffi.Pointer<ffi.Uint16> _toNativeUtf16(String value, ffi.Allocator allocator) {
  final units = value.codeUnits;
  final ptr = allocator.allocate<ffi.Uint16>(
    (units.length + 1) * ffi.sizeOf<ffi.Uint16>(),
  );
  final list = ptr.asTypedList(units.length + 1);
  list.setAll(0, units);
  list[units.length] = 0;
  return ptr;
}

String _readNativeUtf8(ffi.Pointer<ffi.Char> ptr) {
  if (ptr == ffi.nullptr) return '';
  try {
    return ptr.cast<Utf8>().toDartString();
  } finally {
    bindings.free_u8_string(ptr.address);
  }
}

String _readNativeUtf16(ffi.Pointer<ffi.Uint16> ptr) {
  if (ptr == ffi.nullptr) return '';
  try {
    var len = 0;
    while (ptr[len] != 0) {
      len++;
    }
    if (len == 0) return '';
    return String.fromCharCodes(ptr.asTypedList(len));
  } finally {
    bindings.free_u16_string(ptr.address);
  }
}

T _callAndParse<T>(
  T emptyValue,
  ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Size> outSize) nativeCall,
  T Function(ffi.Pointer<ffi.Uint8> ptr, int size) parser,
) {
  return using((arena) {
    final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
    final ptr = nativeCall(outSize);
    if (ptr == ffi.nullptr) return emptyValue;
    final size = outSize.value;
    try {
      return parser(ptr, size);
    } finally {
      bindings.free_binary_data(ptr.address);
    }
  });
}

EditorActionResult _callAndParseAction(
  ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Size> outSize) nativeCall,
) {
  return _callAndParse(
    const EditorActionResult(),
    nativeCall,
    CoreProtocol.decodeEditorActionResultFromPointer,
  );
}

EditorActionResult _callWithBinaryActionData(
  Uint8List data,
  ffi.Pointer<ffi.Uint8> Function(
    ffi.Pointer<ffi.Uint8>,
    int,
    ffi.Pointer<ffi.Size>,
  )
  fn,
) {
  return using((arena) {
    final ptr = arena.allocate<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
    final resultPtr = fn(ptr, data.length, outSize);
    if (resultPtr == ffi.nullptr) return const EditorActionResult();
    try {
      return CoreProtocol.decodeEditorActionResultFromPointer(
        resultPtr,
        outSize.value,
      );
    } finally {
      bindings.free_binary_data(resultPtr.address);
    }
  });
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
      final bytes = CoreProtocol.encodeEditorOptions(options);
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
          bindings.editor_set_document(_handle, document._handle, outSize),
    );
  }

  EditorActionResult setViewport(int width, int height) {
    _ensureOpen();
    return _callAndParseAction(
      (outSize) =>
          bindings.editor_set_viewport(_handle, width, height, outSize),
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

  EditorActionResult setKeyMap(List<KeyBinding> keyBindings) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeSetKeyMapPayload(keyBindings);
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
    return _callWithBinaryActionData(
      CoreProtocol.encodeHandleConfig(config),
      (data, size, outSize) =>
          bindings.editor_set_handle_config(_handle, data, size, outSize),
    );
  }

  EditorActionResult setScrollbarConfig(ScrollbarConfig config) {
    _ensureOpen();
    return _callWithBinaryActionData(
      CoreProtocol.encodeScrollbarConfig(config),
      (data, size, outSize) =>
          bindings.editor_set_scrollbar_config(_handle, data, size, outSize),
    );
  }

  /// Build render model. Returns parsed [EditorRenderModel].
  EditorRenderModel buildRenderModel() {
    _ensureOpen();
    return _callAndParse(
      const EditorRenderModel(),
      (outSize) => bindings.editor_build_render_model(_handle, outSize),
      CoreProtocol.decodeEditorRenderModelFromPointer,
    );
  }

  /// Build render model and return raw bytes (for custom parsing).
  Uint8List? buildRenderModelRaw() {
    _ensureOpen();
    return using((arena) {
      final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ptr = bindings.editor_build_render_model(_handle, outSize);
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
      const LayoutMetrics(),
      (outSize) => bindings.editor_get_layout_metrics(_handle, outSize),
      CoreProtocol.decodeLayoutMetricsFromPointer,
    );
  }

  EditorActionResult handleGestureEvent(GestureEvent event) {
    _ensureOpen();
    return _callWithBinaryActionData(
      CoreProtocol.encodeGestureEvent(event),
      (data, size, outSize) =>
          bindings.editor_handle_gesture_event(_handle, data, size, outSize),
    );
  }

  EditorActionResult updatePointerModifiers(int modifiers) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) =>
          bindings.editor_update_pointer_modifiers(_handle, modifiers, outSize),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult tickAnimations() {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_tick_animations(_handle, outSize),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult handleKeyEvent(
    int keyCode, {
    String? text,
    int modifiers = 0,
  }) {
    _ensureOpen();
    return using((arena) {
      final textPtr = text != null
          ? _toNativeUtf8(text, arena)
          : ffi.nullptr.cast<ffi.Char>();
      final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
      final ptr = bindings.editor_handle_key_event(
        _handle,
        keyCode,
        textPtr,
        modifiers,
        outSize,
      );
      if (ptr == ffi.nullptr) return const EditorActionResult();
      final size = outSize.value;
      try {
        return CoreProtocol.decodeEditorActionResultFromPointer(ptr, size);
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
        const EditorActionResult(),
        (outSize) => bindings.editor_insert_text(_handle, textPtr, outSize),
        CoreProtocol.decodeEditorActionResultFromPointer,
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
        const EditorActionResult(),
        (outSize) => bindings.editor_replace_text(
          _handle,
          startLine,
          startColumn,
          endLine,
          endColumn,
          textPtr,
          outSize,
        ),
        CoreProtocol.decodeEditorActionResultFromPointer,
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
      const EditorActionResult(),
      (outSize) => bindings.editor_delete_text(
        _handle,
        startLine,
        startColumn,
        endLine,
        endColumn,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
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
      const EditorActionResult(),
      fn,
      CoreProtocol.decodeEditorActionResultFromPointer,
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
      return TextPosition(line: outLine.value, column: outColumn.value);
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
        start: TextPosition(line: sl.value, column: sc.value),
        end: TextPosition(line: el.value, column: ec.value),
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
        start: TextPosition(line: sl.value, column: sc.value),
        end: TextPosition(line: el.value, column: ec.value),
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
        const EditorActionResult(),
        (outSize) => bindings.editor_ime_update_preedit(
          _handle,
          textPtr,
          scriptClass.value,
          outSize,
        ),
        CoreProtocol.decodeEditorActionResultFromPointer,
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
        const EditorActionResult(),
        (outSize) => bindings.editor_ime_set_composing_text(
          _handle,
          textPtr,
          cursorOffset,
          scriptClass.value,
          outSize,
        ),
        CoreProtocol.decodeEditorActionResultFromPointer,
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
        const EditorActionResult(),
        (outSize) => bindings.editor_ime_set_composing_text_selection(
          _handle,
          textPtr,
          selectionStartOffset,
          selectionEndOffset,
          scriptClass.value,
          outSize,
        ),
        CoreProtocol.decodeEditorActionResultFromPointer,
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
        const EditorActionResult(),
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
        CoreProtocol.decodeEditorActionResultFromPointer,
      );
    });
  }

  EditorActionResult finishImePreedit() {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_finish_preedit(_handle, outSize),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult cancelImePreedit() {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_cancel_preedit(_handle, outSize),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult markImeDocumentRange(
    TextRange range, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_mark_document_range(
        _handle,
        range.start.line,
        range.start.column,
        range.end.line,
        range.end.column,
        scriptClass.value,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult markImeDocumentRangeByOffset(
    int startOffset,
    int endOffset, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_mark_document_range_by_offset(
        _handle,
        startOffset,
        endOffset,
        scriptClass.value,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult replaceImeText(ImeTextReplacement replacement) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeImeTextReplacement(replacement);
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) =>
          bindings.editor_ime_replace_text(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult replaceImeDocumentText(
    ImeDocumentTextReplacement replacement,
  ) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeImeDocumentTextReplacement(replacement);
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) => bindings.editor_ime_replace_document_text(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult replaceImeInputContextText(
    ImeInputContextTextReplacement replacement,
  ) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeImeInputContextTextReplacement(replacement);
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) => bindings.editor_ime_replace_input_context_text(
        _handle,
        ptr,
        len,
        outSize,
      ),
    );
  }

  EditorActionResult markImeInputContextRange(
    int startOffset,
    int endOffset, {
    ImeScriptClass scriptClass = ImeScriptClass.unknown,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_mark_input_context_range(
        _handle,
        startOffset,
        endOffset,
        scriptClass.value,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult notifyImeDocumentSelectionChanged(
    int startOffset,
    int endOffset,
  ) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_notify_document_selection_changed(
        _handle,
        startOffset,
        endOffset,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult notifyImeInputContextSelectionChanged(
    int startOffset,
    int endOffset,
  ) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_notify_input_context_selection_changed(
        _handle,
        startOffset,
        endOffset,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult updateImeTextModelState(ImeTextModelState state) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeImeTextModelState(state);
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) =>
          bindings.editor_ime_update_text_model_state(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult updateImeTextModelDelta(ImeTextModelDelta delta) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeImeTextModelDelta(delta);
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) =>
          bindings.editor_ime_update_text_model_delta(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult updateImeInputStateSelection({
    required int contextId,
    required int documentStartOffset,
    required int selectionStartOffset,
    required int selectionEndOffset,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_update_input_state_selection(
        _handle,
        contextId,
        documentStartOffset,
        selectionStartOffset,
        selectionEndOffset,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult replaceImeInputStateText(
    ImeInputStateTextReplacement replacement,
  ) {
    _ensureOpen();
    final bytes = CoreProtocol.encodeImeInputStateTextReplacement(replacement);
    return _callWithBinaryActionData(
      bytes,
      (ptr, len, outSize) =>
          bindings.editor_ime_replace_input_state_text(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult deleteImeBackward({
    int beforeLength = 1,
    ImeTextUnit textUnit = ImeTextUnit.grapheme,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_delete_backward(
        _handle,
        beforeLength,
        textUnit.value,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult deleteImeForward({
    int afterLength = 1,
    ImeTextUnit textUnit = ImeTextUnit.grapheme,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_delete_forward(
        _handle,
        afterLength,
        textUnit.value,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult deleteImeSurrounding({
    required int beforeLength,
    required int afterLength,
    ImeTextUnit textUnit = ImeTextUnit.grapheme,
  }) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_delete_surrounding(
        _handle,
        beforeLength,
        afterLength,
        textUnit.value,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult notifyImeSelectionChanged(TextRange range) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_notify_selection_changed(
        _handle,
        range.start.line,
        range.start.column,
        range.end.line,
        range.end.column,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
    );
  }

  EditorActionResult notifyImeCursorChanged(TextPosition cursor) {
    _ensureOpen();
    return _callAndParse(
      const EditorActionResult(),
      (outSize) => bindings.editor_ime_notify_cursor_changed(
        _handle,
        cursor.line,
        cursor.column,
        outSize,
      ),
      CoreProtocol.decodeEditorActionResultFromPointer,
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
      const ImeSyncSnapshot(),
      (outSize) => bindings.editor_get_ime_sync_snapshot(_handle, outSize),
      CoreProtocol.decodeImeSyncSnapshotFromPointer,
    );
  }

  ImeInputContext getImeInputContext(int beforeLength, int afterLength) {
    _ensureOpen();
    return _callAndParse(
      const ImeInputContext(),
      (outSize) => bindings.editor_get_ime_input_context(
        _handle,
        beforeLength,
        afterLength,
        outSize,
      ),
      CoreProtocol.decodeImeInputContextFromPointer,
    );
  }

  ImeInputContext getImeTextModelInputContext(
    ImeTextModelMode mode,
    int beforeLength,
    int afterLength,
  ) {
    _ensureOpen();
    return _callAndParse(
      const ImeInputContext(),
      (outSize) => bindings.editor_get_ime_text_model_input_context(
        _handle,
        mode.value,
        beforeLength,
        afterLength,
        outSize,
      ),
      CoreProtocol.decodeImeInputContextFromPointer,
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
      start: TextPosition(line: startLine, column: startColumn),
      end: TextPosition(line: endLine, column: endColumn),
    );
  }

  EditorActionResult scrollToLine(
    int line, {
    ScrollBehavior behavior = ScrollBehavior.gotoCenter,
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
      const ScrollMetrics(),
      (outSize) => bindings.editor_get_scroll_metrics(_handle, outSize),
      CoreProtocol.decodeScrollMetricsFromPointer,
    );
  }

  IntRange getVisibleLineRange() {
    _ensureOpen();
    return using((arena) {
      final outStartLine = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      final outEndLine = arena.allocate<ffi.Int32>(ffi.sizeOf<ffi.Int32>());
      bindings.editor_get_visible_line_range(_handle, outStartLine, outEndLine);
      return IntRange(start: outStartLine.value, end: outEndLine.value);
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
      CoreProtocol.encodeSetLineSpansPayload(line, layer, spans),
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

  EditorActionResult? setBatchLineSpans(
    SpanLayer layer,
    Map<int, List<StyleSpan>> spansByLine,
  ) {
    if (spansByLine.isEmpty) return null;
    return setBatchLineSpansRaw(
      CoreProtocol.encodeSetBatchLineSpansPayload(layer, spansByLine),
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
      CoreProtocol.encodeSetLineInlayHintsPayload(line, hints),
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

  EditorActionResult? setBatchLineInlayHints(
    Map<int, List<InlayHint>> hintsByLine,
  ) {
    if (hintsByLine.isEmpty) return null;
    return setBatchLineInlayHintsRaw(
      CoreProtocol.encodeSetBatchLineInlayHintsPayload(hintsByLine),
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
      CoreProtocol.encodeSetLinePhantomTextsPayload(line, phantoms),
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

  EditorActionResult? setBatchLinePhantomTexts(
    Map<int, List<PhantomText>> phantomsByLine,
  ) {
    if (phantomsByLine.isEmpty) return null;
    return setBatchLinePhantomTextsRaw(
      CoreProtocol.encodeSetBatchLinePhantomTextsPayload(phantomsByLine),
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
      CoreProtocol.encodeSetLineGutterIconsPayload(line, icons),
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

  EditorActionResult? setBatchLineGutterIcons(
    Map<int, List<GutterIcon>> iconsByLine,
  ) {
    if (iconsByLine.isEmpty) return null;
    return setBatchLineGutterIconsRaw(
      CoreProtocol.encodeSetBatchLineGutterIconsPayload(iconsByLine),
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
    return setLineCodeLensRaw(
      CoreProtocol.encodeSetLineCodeLensPayload(line, items),
    );
  }

  EditorActionResult setLineCodeLensRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_codelens(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult? setBatchLineCodeLens(
    Map<int, List<CodeLensItem>> itemsByLine,
  ) {
    if (itemsByLine.isEmpty) return null;
    return setBatchLineCodeLensRaw(
      CoreProtocol.encodeSetBatchLineCodeLensPayload(itemsByLine),
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
    return setLineLinksRaw(CoreProtocol.encodeSetLineLinksPayload(line, links));
  }

  EditorActionResult setLineLinksRaw(Uint8List data) {
    _ensureOpen();
    return _callWithBinaryActionData(
      data,
      (ptr, len, outSize) =>
          bindings.editor_set_line_links(_handle, ptr, len, outSize),
    );
  }

  EditorActionResult? setBatchLineLinks(Map<int, List<LinkSpan>> linksByLine) {
    if (linksByLine.isEmpty) return null;
    return setBatchLineLinksRaw(
      CoreProtocol.encodeSetBatchLineLinksPayload(linksByLine),
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
      CoreProtocol.encodeSetLineDiagnosticsPayload(line, items),
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

  EditorActionResult? setBatchLineDiagnostics(
    Map<int, List<Diagnostic>> itemsByLine,
  ) {
    if (itemsByLine.isEmpty) return null;
    return setBatchLineDiagnosticsRaw(
      CoreProtocol.encodeSetBatchLineDiagnosticsPayload(itemsByLine),
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
    return setIndentGuidesRaw(
      CoreProtocol.encodeSetIndentGuidesPayload(guides),
    );
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
    return setBracketGuidesRaw(
      CoreProtocol.encodeSetBracketGuidesPayload(guides),
    );
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
    return setFlowGuidesRaw(CoreProtocol.encodeSetFlowGuidesPayload(guides));
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
    return setSeparatorGuidesRaw(
      CoreProtocol.encodeSetSeparatorGuidesPayload(guides),
    );
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
      CoreProtocol.encodeRegisterBatchTextStylesPayload(stylesById),
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
    return setFoldRegionsRaw(CoreProtocol.encodeSetFoldRegionsPayload(regions));
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
        const EditorActionResult(),
        (outSize) =>
            bindings.editor_insert_snippet(_handle, templatePtr, outSize),
        CoreProtocol.decodeEditorActionResultFromPointer,
      );
    });
  }

  EditorActionResult startLinkedEditing(LinkedEditingModel model) {
    _ensureOpen();
    return startLinkedEditingRaw(
      CoreProtocol.encodeStartLinkedEditingPayload(model),
    );
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
