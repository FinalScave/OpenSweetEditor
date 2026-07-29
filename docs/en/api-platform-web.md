# Web Platform API

This document describes the current SweetEditor Web API.

## Scope

- Supported runtime: `sweeteditor_c_abi.js` with `sweeteditor_c_abi.wasm`
- Toolchain: Emscripten
- Binary format: WebAssembly
- Module style: modular ES module
- Environments: browser, Web Worker, and Node.js

The complete `include/sweeteditor/c_api.h` header is not the Web API boundary. Only symbols in `WASM_C_ABI_EXPORTED_FUNCTIONS` in `cmake/platform/Emscripten.cmake` are exported. The current list contains 139 symbols, including `_malloc` and `_free`.

Treat that CMake list as authoritative. A checked-in or locally cached Wasm artifact may have been produced from an older export list and must not be used to infer the supported Web boundary; rebuild the artifacts before publishing.

## Module Initialization

~~~javascript
import createSweetEditorCAbi from '../../prebuilt/wasm/sweeteditor_c_abi.js';

const sweetEditor = await createSweetEditorCAbi();
~~~

The module factory resolves after the Wasm runtime is initialized. Exported C functions use an underscore prefix, for example `_create_editor` and `_editor_insert_text`.

## Exported C ABI

The groups below enumerate the current exported boundary. Function signatures, structures, and binary payload layouts are defined in `include/sweeteditor/c_api.h` and the C++ Core / C API reference.

### Memory

    _malloc
    _free
    _free_u16_string
    _free_u8_string
    _free_binary_data

### Documents

    _create_document_from_utf8
    _create_document_from_utf16
    _create_document_from_file
    _free_document
    _get_document_utf8
    _get_document_utf16
    _get_document_line_count
    _get_document_line_utf8
    _get_document_line_utf16

File-backed documents read from the Emscripten filesystem.

### Editor Lifecycle and Document Attachment

    _create_editor
    _free_editor
    _editor_set_document

`create_editor` consumes the `text_measurer_t` callback set defined by the C ABI together with an `EditorOptions` payload. The current Wasm calling convention for `_create_editor` is `(measurerPtr, optionsPtr, optionsSize) -> editorHandle`. `measurerPtr` points to four consecutive 32-bit Wasm table indexes in this order:

| Offset | Callback | `addFunction` signature |
| ---: | --- | --- |
| 0 | `measure_text_width(const U16Char*, int32_t) -> float` | `fii` |
| 4 | `measure_inlay_hint_width(const U16Char*) -> float` | `fi` |
| 8 | `measure_icon_width(int32_t) -> float` | `fi` |
| 12 | `get_font_metrics(float*, size_t) -> void` | `vii` |

The text pointers are null-terminated UTF-16 code units. `get_font_metrics` writes ascent at byte offset 0 and descent at byte offset 4 when the supplied length permits it. Ascent uses the core convention and is normally negative; descent is normally positive.

The following example creates an editor with default `EditorOptions` and returns an explicit destructor:

~~~javascript
function readU16Z(module, ptr) {
  let text = '';
  for (let offset = 0; ; offset += 2) {
    const codeUnit = module.getValue(ptr + offset, 'i16') & 0xffff;
    if (codeUnit === 0) return text;
    text += String.fromCharCode(codeUnit);
  }
}

function createEditor(module, host) {
  const callbacks = [];
  let editor = 0;
  try {
    callbacks.push(module.addFunction(
      (textPtr, fontStyle) => host.measureText(readU16Z(module, textPtr), fontStyle),
      'fii'
    ));
    callbacks.push(module.addFunction(
      textPtr => host.measureInlayHint(readU16Z(module, textPtr)),
      'fi'
    ));
    callbacks.push(module.addFunction(iconId => host.measureIcon(iconId), 'fi'));
    callbacks.push(module.addFunction((metricsPtr, length) => {
      if (length >= 1) module.setValue(metricsPtr, host.fontAscent, 'float');
      if (length >= 2) module.setValue(metricsPtr + 4, host.fontDescent, 'float');
    }, 'vii'));

    const measurerPtr = module._malloc(16);
    if (!measurerPtr) throw new Error('Failed to allocate text_measurer_t');
    try {
      callbacks.forEach((callback, index) => {
        module.setValue(measurerPtr + index * 4, callback, 'i32');
      });
      editor = module._create_editor(measurerPtr, 0, 0);
    } finally {
      module._free(measurerPtr);
    }

    if (!editor) throw new Error('Failed to create SweetEditor');

    return {
      handle: editor,
      destroy() {
        if (!editor) return;
        module._free_editor(editor);
        editor = 0;
        callbacks.forEach(callback => module.removeFunction(callback));
      }
    };
  } catch (error) {
    callbacks.forEach(callback => module.removeFunction(callback));
    throw error;
  }
}
~~~

The 16-byte `text_measurer_t` storage is copied during `_create_editor` and can be freed immediately afterward. The four table entries are retained by the editor and must not be passed to `removeFunction` until after `_free_editor` completes.

Passing `optionsPtr = 0` and `optionsSize = 0` selects the core defaults. A custom options buffer is exactly 49 bytes in the current protocol: `touch_slop` is `f32` at offset 0; `double_tap_timeout` and `long_press_ms` are `i64` at offsets 4 and 12; the three fling values are `f32` at offsets 20, 24, and 28; `max_undo_stack_size` is `u64` at offset 32; `key_chord_timeout_ms` is `i64` at offset 40; and `reveal_selection_end_on_select_all` is a one-byte boolean at offset 48. Encode every field little-endian, copy the 49 bytes into `_malloc` storage, pass that pointer and size to `_create_editor`, and free the temporary storage after the call. Do not use aligned native-struct padding for this protocol payload.

### Viewport, Appearance, and Rendering

    _editor_set_viewport
    _editor_on_font_metrics_changed
    _editor_set_fold_arrow_mode
    _editor_set_wrap_mode
    _editor_set_tab_size
    _editor_set_scale
    _editor_set_line_spacing
    _editor_set_content_start_padding
    _editor_set_show_split_line
    _editor_set_current_line_render_mode
    _editor_set_gutter_sticky
    _editor_set_gutter_visible
    _editor_set_handle_config
    _editor_set_scrollbar_config
    _editor_build_render_model
    _editor_get_layout_metrics

The host owns browser rendering. SweetEditor returns a binary render model; it does not create DOM elements or draw to canvas.

### Input and Animation

    _editor_handle_gesture_event
    _editor_update_pointer_modifiers
    _editor_tick_animations
    _editor_handle_key_event
    _editor_set_keymap

The host must translate browser events into the shared protocol and drive `_editor_tick_animations` when an action result requests animation.

### Text and Line Editing

    _editor_insert_text
    _editor_replace_text
    _editor_delete_text
    _editor_backspace
    _editor_delete_forward
    _editor_move_line_up
    _editor_move_line_down
    _editor_copy_line_up
    _editor_copy_line_down
    _editor_delete_line
    _editor_insert_line_above
    _editor_insert_line_below

### Undo and Redo

    _editor_undo
    _editor_redo
    _editor_can_undo
    _editor_can_redo

### Cursor, Selection, and Words

    _editor_set_cursor_position
    _editor_get_cursor_position
    _editor_select_all
    _editor_set_selection
    _editor_get_selection
    _editor_get_selected_text
    _editor_get_word_range_at_cursor
    _editor_get_word_at_cursor
    _editor_move_cursor_left
    _editor_move_cursor_right
    _editor_move_cursor_up
    _editor_move_cursor_down
    _editor_move_cursor_to_line_start
    _editor_move_cursor_to_line_end

### Read-only and Indentation

    _editor_set_read_only
    _editor_is_read_only
    _editor_set_auto_indent_mode
    _editor_get_auto_indent_mode
    _editor_set_backspace_unindent
    _editor_set_insert_spaces

### Scrolling and Coordinates

    _editor_scroll_to_line
    _editor_goto_position
    _editor_ensure_cursor_visible
    _editor_set_scroll
    _editor_get_scroll_metrics
    _editor_get_position_rect
    _editor_get_cursor_rect

### Text Styles and Highlight Layers

    _editor_register_text_style
    _editor_register_batch_text_styles
    _editor_set_line_spans
    _editor_set_batch_line_spans
    _editor_clear_line_spans
    _editor_clear_highlights_layer
    _editor_clear_highlights

### Inlays, Phantom Text, Gutter, CodeLens, and Links

    _editor_set_line_inlay_hints
    _editor_set_batch_line_inlay_hints
    _editor_clear_inlay_hints
    _editor_set_line_phantom_texts
    _editor_set_batch_line_phantom_texts
    _editor_clear_phantom_texts
    _editor_set_line_gutter_icons
    _editor_set_batch_line_gutter_icons
    _editor_set_max_gutter_icons
    _editor_clear_gutter_icons
    _editor_set_line_codelens
    _editor_set_batch_line_codelens
    _editor_clear_codelens
    _editor_set_line_links
    _editor_set_batch_line_links
    _editor_clear_links
    _editor_get_link_target_at

### Diagnostics and Guides

    _editor_set_line_diagnostics
    _editor_set_batch_line_diagnostics
    _editor_clear_diagnostics
    _editor_set_indent_guides
    _editor_set_bracket_guides
    _editor_set_flow_guides
    _editor_set_separator_guides
    _editor_clear_guides

### Brackets and Folding

    _editor_set_bracket_pairs
    _editor_set_auto_closing_pairs
    _editor_set_matched_brackets
    _editor_clear_matched_brackets
    _editor_set_fold_regions
    _editor_toggle_fold
    _editor_fold_at
    _editor_unfold_at
    _editor_fold_all
    _editor_unfold_all
    _editor_is_line_visible
    _editor_get_visible_line_range

### Aggregate Decoration Clearing

    _editor_clear_all_decorations

### Snippets and Linked Editing

    _editor_insert_snippet
    _editor_start_linked_editing
    _editor_is_in_linked_editing
    _editor_linked_editing_next
    _editor_linked_editing_prev
    _editor_cancel_linked_editing

### IME Protocol

    _editor_ime_begin_session
    _editor_ime_end_session
    _editor_ime_apply_commands
    _editor_ime_apply_text_updates
    _editor_ime_get_state
    _editor_ime_get_context

SweetEditor exposes the shared session-based IME protocol only. The host remains responsible for mapping browser composition, beforeinput, keyboard, selection, lifecycle, and candidate UI behavior to command or text-update batches.

## Exported Emscripten Runtime Methods

The C ABI module exports:

    ccall
    cwrap
    UTF8ToString
    stringToUTF8
    lengthBytesUTF8
    getValue
    setValue
    addFunction
    removeFunction
    FS

The module enables growable memory, a growable callback table, a persistent runtime, and the Emscripten filesystem.

## Binary Payloads

Complex parameters and return values use the same binary protocol as the native C API. Important payloads include:

- `EditorActionResult`
- `EditorRenderModel`
- `LayoutMetrics`
- `ScrollMetrics`
- search-independent decoration and folding models
- linked-editing models
- IME command/text-update batches, authoritative state, and finite text contexts

Returned binary data must be released with `_free_binary_data`. Returned UTF-8 and UTF-16 strings must be released with their matching free functions.

## Memory Ownership

- Release document handles with `_free_document`.
- Release editor handles with `_free_editor`.
- Release buffers allocated with `_malloc` by calling `_free`.
- Release UTF-8 strings returned by the C API with `_free_u8_string`.
- Release UTF-16 strings returned by the C API with `_free_u16_string`.
- Release binary protocol results with `_free_binary_data`.
- Keep registered JavaScript measurement callbacks alive for the editor lifetime. Call `_free_editor` before removing them with `removeFunction`.

Do not keep typed-array views across operations that may grow Wasm memory. Recreate views from the current module heap after growth.

## C API Functions Not Exported to Web

The following functions exist in the complete C API but are not in the current Web export list:

    editor_apply_text_edits
    editor_search
    editor_find_next_search_match
    editor_find_previous_search_match
    editor_replace_current_search_match
    editor_replace_all_search_matches
    editor_clear_search
    editor_get_search_state
    editor_set_line_document_highlights
    editor_set_batch_line_document_highlights
    editor_clear_document_highlights
    editor_set_editor_range_effect_styles
    editor_set_editor_render_colors
    editor_set_render_whitespace
    editor_set_render_line_breaks

Code that needs one of these cross-platform functions must first add it to `WASM_C_ABI_EXPORTED_FUNCTIONS` and rebuild the Web artifacts. Presence in `c_api.h` alone does not make a symbol callable from JavaScript.

`init_unhandled_exception_handler` is also absent, but it is declared only for `_WIN32` builds. It is not an Emscripten function and cannot be enabled merely by adding it to the Web export list.

## Embind Boundary

`sweeteditor_bindings.cpp` currently contains an empty `EMSCRIPTEN_BINDINGS` block. The `sweeteditor_embind` artifacts therefore initialize a Wasm module and filesystem but expose no SweetEditor classes, functions, or value types through Embind.

## References

- Web integration and build guide: [`platform/Emscripten/README.md`](../../platform/Emscripten/README.md)
- Authoritative export list: [`cmake/platform/Emscripten.cmake`](../../cmake/platform/Emscripten.cmake)
- Complete C ABI declarations: [`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h)
- Binary protocol and C API reference: [`docs/en/api-editor-core.md`](api-editor-core.md)
