# EditorCore / C API Reference

This document follows `src/include/c_api.h` and describes the current external core contract of SweetEditor (2026-03).

Platform API docs:

- `docs/en/api-platform-android.md`
- `docs/en/api-platform-swing.md`
- `docs/en/api-platform-winforms.md`
- `docs/en/api-platform-apple.md`

## Contract Boundary

- Stable cross-platform ABI: `extern "C"` + `intptr_t` handles + binary payload (render / event / edit result).
- Internal C++ classes (`EditorCore`/`Document`/`TextLayout`) are implementation details.
- If document and code conflict, use `c_api.h`/`c_api.cpp`.

Current bridge status:

- Android: main path is JNI direct to C++ (not through `c_api.h`).
- Swing / WinForms: through C API (FFM / PInvoke).
- Apple: through manually maintained C bridge (API shape differs from `c_api.h`, requires explicit cross-check).

## Data and Memory Conventions

- Objects are created/freed through `intptr_t` handles.
- Complex return values like render model, gesture result, key result, text edit result, scroll metrics are usually returned as `const uint8_t* + out_size` binary payload, and caller frees with `free_binary_data`.
- `get_layout_metrics` returns `LayoutMetrics` binary payload (`const uint8_t* + out_size`), also freed by `free_binary_data`.
- `get_document_line_text` returns UTF-16 text, caller frees with `free_u16_string`.
- A few text queries return UTF-8 `const char*` (for example `get_document_text`, `editor_get_selected_text`, `editor_get_word_at_cursor`); platform wrappers usually copy immediately, and current C API does not export a dedicated UTF-8 free function.

## Callback Struct

### `text_measurer_t`

```c
typedef struct {
    float (__stdcall* measure_text_width)(const U16Char* text, int32_t font_style);
    float (__stdcall* measure_inlay_hint_width)(const U16Char* text);
    float (__stdcall* measure_icon_width)(int32_t icon_id);
    void  (__stdcall* get_font_metrics)(float* arr, size_t length);
} text_measurer_t;
```

## C API Groups

### 1) Document

```c
intptr_t        create_document_from_utf16(const U16Char* text);
intptr_t        create_document_from_file(const char* path);
void            free_document(intptr_t document_handle);
const char*     get_document_text(intptr_t document_handle);
size_t          get_document_line_count(intptr_t document_handle);
const U16Char*  get_document_line_text(intptr_t document_handle, size_t line);
```

### 2) Editor lifecycle

```c
intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size);
void     free_editor(intptr_t editor_handle);
void     set_editor_document(intptr_t editor_handle, intptr_t document_handle);
```

- `create_editor` uses LE `EditorOptions` payload: `f32 touch_slop`, `i64 double_tap_timeout`, `i64 long_press_ms`, `u64 max_undo_stack_size`.

### 3) Viewport / appearance

```c
void set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height);
void reset_editor_text_measurer(intptr_t editor_handle);
void editor_set_fold_arrow_mode(intptr_t editor_handle, int mode);
void editor_set_wrap_mode(intptr_t editor_handle, int mode);
void editor_set_line_spacing(intptr_t editor_handle, float add, float mult);
```

Numeric conventions:

- `FoldArrowMode`: `0=AUTO`, `1=ALWAYS`, `2=HIDDEN`
- `WrapMode`: `0=NONE`, `1=CHAR_BREAK`, `2=WORD_BREAK`

### 4) Rendering

```c
const uint8_t* build_editor_render_model(intptr_t editor_handle, size_t* out_size);
const uint8_t* get_layout_metrics(intptr_t editor_handle, size_t* out_size);
```

- `build_editor_render_model`: returns native-endian binary payload; all currently supported platforms are little-endian.
- `get_layout_metrics`: returns `LayoutMetrics` binary payload (native-endian; all currently supported platforms are little-endian).

`get_layout_metrics` payload layout (in order):

1. `f32 font_height`
2. `f32 font_ascent`
3. `f32 line_spacing_add`
4. `f32 line_spacing_mult`
5. `f32 line_number_margin`
6. `f32 line_number_width`
7. `i32 max_gutter_icons`
8. `f32 inlay_hint_padding`
9. `f32 inlay_hint_margin`
10. `i32 fold_arrow_mode` (`0=AUTO`, `1=ALWAYS`, `2=HIDDEN`)
11. `i32 has_fold_regions` (`0=false`, `1=true`)

### 5) Gesture / key

```c
const uint8_t* handle_editor_gesture_event(
    intptr_t editor_handle, uint8_t type, uint8_t pointer_count, float* points, size_t* out_size);

const uint8_t* handle_editor_gesture_event_ex(
    intptr_t editor_handle, uint8_t type, uint8_t pointer_count, float* points,
    uint8_t modifiers, float wheel_delta_x, float wheel_delta_y, float direct_scale, size_t* out_size);

const uint8_t* handle_editor_key_event(
    intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size);
```

`modifiers` bit flags: `SHIFT=1`, `CTRL=2`, `ALT=4`, `META=8`.

### 6) Text edit (atomic)

```c
const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size);
const uint8_t* editor_replace_text(
    intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    const char* text,
    size_t* out_size);
const uint8_t* editor_delete_text(
    intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    size_t* out_size);
const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_delete_forward(intptr_t editor_handle, size_t* out_size);
```

### 7) Line actions (new)

```c
const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size);
```

### 8) Undo / redo

```c
const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size);
int            editor_can_undo(intptr_t editor_handle);
int            editor_can_redo(intptr_t editor_handle);
```

### 9) Cursor / selection / word

```c
void       editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column);
void       editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column);
void       editor_select_all(intptr_t editor_handle);
void       editor_set_selection(
    intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column);
int        editor_get_selection(
    intptr_t editor_handle,
    size_t* out_start_line, size_t* out_start_column,
    size_t* out_end_line, size_t* out_end_column);
const char* editor_get_selected_text(intptr_t editor_handle);
void       editor_get_word_range_at_cursor(
    intptr_t editor_handle,
    size_t* out_start_line, size_t* out_start_column,
    size_t* out_end_line, size_t* out_end_column);
const char* editor_get_word_at_cursor(intptr_t editor_handle);
```

### 10) Cursor movement

```c
void editor_move_cursor_left(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_right(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_up(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_down(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection);
```

### 11) IME composition

```c
void           editor_composition_start(intptr_t editor_handle);
void           editor_composition_update(intptr_t editor_handle, const char* text);
const uint8_t* editor_composition_end(intptr_t editor_handle, const char* committed_text, size_t* out_size);
void           editor_composition_cancel(intptr_t editor_handle);
int            editor_is_composing(intptr_t editor_handle);
void           editor_set_composition_enabled(intptr_t editor_handle, int enabled);
int            editor_is_composition_enabled(intptr_t editor_handle);
```

### 12) Read-only, auto indent, and handle config

```c
void editor_set_read_only(intptr_t editor_handle, int read_only);
int  editor_is_read_only(intptr_t editor_handle);
void editor_set_auto_indent_mode(intptr_t editor_handle, int mode);
int  editor_get_auto_indent_mode(intptr_t editor_handle);
void editor_set_handle_config(
    intptr_t editor_handle,
    float radius, float center_dist, float line_width,
    float touch_padding, float drag_y_offset);
```

`AutoIndentMode`: `0=NONE`, `1=KEEP_INDENT`.

### 13) Coordinates and navigation

```c
void editor_get_position_rect(
    intptr_t editor_handle,
    size_t line, size_t column,
    float* out_x, float* out_y, float* out_height);
void editor_get_cursor_rect(
    intptr_t editor_handle,
    float* out_x, float* out_y, float* out_height);
void editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior);
void editor_goto_position(intptr_t editor_handle, size_t line, size_t column);
void editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y);
const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size);
```

`ScrollBehavior`: `0=GOTO_TOP`, `1=GOTO_CENTER`, `2=GOTO_BOTTOM`.

### 14) Style / highlight

```c
void editor_register_style(
    intptr_t editor_handle,
    uint32_t style_id,
    int32_t color,
    int32_t background_color,
    int32_t font_style);
void editor_set_line_spans(
    intptr_t editor_handle,
    const uint8_t* data,
    size_t size);
void editor_set_batch_line_spans(
    intptr_t editor_handle,
    const uint8_t* data,
    size_t size);
void editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer);
void editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer);
```

- `SpanLayer`: `0=SYNTAX`, `1=SEMANTIC`
- `font_style` bit flags: `BOLD=1`, `ITALIC=2`, `STRIKETHROUGH=4`
- `editor_set_line_spans` payload (LE):
  - `u32 line, u32 layer, u32 span_count`
  - repeat `span_count` groups: `[u32 column, u32 length, u32 style_id]`
- `editor_set_batch_line_spans` payload (LE):
  - `u32 layer, u32 entry_count`
  - repeat `entry_count` groups: `[u32 line, u32 span_count, [u32 column, u32 length, u32 style_id] × span_count]`

### 15) Inlay / Phantom / Gutter / Diagnostics

```c
void editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size);

void editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_gutter_icons(intptr_t editor_handle);
void editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count);

void editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_diagnostics(intptr_t editor_handle);
```

- `editor_set_line_inlay_hints` payload (LE):
  - `u32 line, u32 hint_count`
  - repeat `hint_count` groups: `[u32 type, u32 column, i32 int_value, u32 text_len, u8[text_len] text_utf8]`
- `editor_set_batch_line_inlay_hints` payload (LE):
  - `u32 entry_count`
  - repeat `entry_count` groups: `[u32 line, u32 hint_count, hint_items...]`
- `editor_set_line_phantom_texts` payload (LE):
  - `u32 line, u32 phantom_count`
  - repeat `phantom_count` groups: `[u32 column, u32 text_len, u8[text_len] text_utf8]`
- `editor_set_batch_line_phantom_texts` payload (LE):
  - `u32 entry_count`
  - repeat `entry_count` groups: `[u32 line, u32 phantom_count, phantom_items...]`
- `editor_set_line_gutter_icons` payload (LE):
  - `u32 line, u32 icon_count`
  - repeat `icon_count` groups: `[i32 icon_id]`
- `editor_set_batch_line_gutter_icons` payload (LE):
  - `u32 entry_count`
  - repeat `entry_count` groups: `[u32 line, u32 icon_count, [i32 icon_id] × icon_count]`
- `editor_set_line_diagnostics` payload (LE):
  - `u32 line, u32 diag_count`
  - repeat `diag_count` groups: `[u32 column, u32 length, i32 severity, i32 color]`
- `editor_set_batch_line_diagnostics` payload (LE):
  - `u32 entry_count`
  - repeat `entry_count` groups: `[u32 line, u32 diag_count, [u32 column, u32 length, i32 severity, i32 color] × diag_count]`

### 16) Guide / Bracket Highlight / Fold

```c
void editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_guides(intptr_t editor_handle);

void editor_set_bracket_pairs(
    intptr_t editor_handle,
    const uint32_t* open_chars,
    const uint32_t* close_chars,
    size_t count);
void editor_set_matched_brackets(
    intptr_t editor_handle,
    size_t open_line, size_t open_col,
    size_t close_line, size_t close_col);
void editor_clear_matched_brackets(intptr_t editor_handle);

void editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size);
int  editor_toggle_fold(intptr_t editor_handle, size_t line);
int  editor_fold_at(intptr_t editor_handle, size_t line);
int  editor_unfold_at(intptr_t editor_handle, size_t line);
void editor_fold_all(intptr_t editor_handle);
void editor_unfold_all(intptr_t editor_handle);
int  editor_is_line_visible(intptr_t editor_handle, size_t line);
```

- `editor_set_indent_guides` payload (LE):
  - `u32 count`
  - repeat `count` groups: `[u32 start_line, u32 start_column, u32 end_line, u32 end_column]`
- `editor_set_bracket_guides` payload (LE):
  - `u32 count`
  - repeat `count` groups: `[u32 parent_line, u32 parent_column, u32 end_line, u32 end_column, u32 child_count, child_items...]`
- `editor_set_flow_guides` payload (LE):
  - `u32 count`
  - repeat `count` groups: `[u32 start_line, u32 start_column, u32 end_line, u32 end_column]`
- `editor_set_separator_guides` payload (LE):
  - `u32 count`
  - repeat `count` groups: `[i32 line, i32 style, i32 count, u32 text_end_column]`
- `editor_set_fold_regions` payload (LE):
  - `u32 region_count`
  - repeat `region_count` groups: `[u32 start_line, u32 end_line, u32 collapsed]`
- `separator style`: `0=single`, `1=double`

### 17) Clear operations

```c
void editor_clear_highlights(intptr_t editor_handle);
void editor_clear_inlay_hints(intptr_t editor_handle);
void editor_clear_phantom_texts(intptr_t editor_handle);
void editor_clear_all_decorations(intptr_t editor_handle);
```

### 18) Linked editing

```c
const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);
void           editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size);
int            editor_is_in_linked_editing(intptr_t editor_handle);
int            editor_linked_editing_next(intptr_t editor_handle);
int            editor_linked_editing_prev(intptr_t editor_handle);
void           editor_cancel_linked_editing(intptr_t editor_handle);
```

`editor_start_linked_editing` payload (LE):
- `u32 group_count, u32 range_count, u32 string_blob_size`
- `group_count` groups: `[u32 index, u32 default_text_offset, u32 default_text_len]`
- `range_count` groups: `[u32 group_ordinal, u32 start_line, u32 start_col, u32 end_line, u32 end_col]`
- UTF-8 string blob (`default_text_offset=0xFFFFFFFF` means `null`)

### 19) Utilities / memory management

```c
void free_u16_string(intptr_t string_ptr);
void free_binary_data(intptr_t data_ptr);
```

Extra export on Windows:

```c
void init_unhandled_exception_handler();
```

## Sync Advice

- For any public feature change, update `c_api.h` + `c_api.cpp` first, then sync Android JNI / Swing FFM / WinForms PInvoke / Apple bridge.
- If `visual.h` render model layout, binary payload layout, or enum values change, platform decoders must also be updated (including `LayoutMetrics` payload).
