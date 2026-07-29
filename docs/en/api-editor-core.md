# EditorCore / C API Reference

This document describes the current external core contract declared by [`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h). The header is authoritative when this document and the implementation differ.

Integration API documents:

- [Android Platform API](api-platform-android.md)
- [Avalonia API](api-platform-avalonia.md)
- [Flutter API](api-platform-flutter.md)
- [OHOS Platform API](api-platform-ohos.md)
- [Swing API](api-platform-swing.md)
- [WinForms API](api-platform-winforms.md)
- [Apple Platform API](api-platform-apple.md)
- [Web Platform API](api-platform-web.md)

## Contract Boundary

- The cross-platform ABI uses `extern "C"`, `EDITOR_API`, `EDITOR_CALL`, `intptr_t` handles, and CoreProtocol binary payloads.
- Internal C++ types such as `EditorCore`, `Document`, and `TextLayout` are implementation details.
- Android primarily calls C++ through JNI. Swing and WinForms use the C API through FFM and P/Invoke. Apple uses a manually maintained C bridge whose public Swift surface differs from this header. Web exposes only the subset listed in `WASM_C_ABI_EXPORTED_FUNCTIONS`.

## Data, Encoding, and Memory

- Lines and columns are zero-based.
- All CoreProtocol payloads use little-endian encoding, independent of host byte order.
- `U8String` is `u32 byte_length` followed by UTF-8 bytes.
- `List<T>` is `u32 count` followed by the encoded items.
- Map-like payloads are `u32 entry_count` followed by key/value pairs in insertion order.
- `bool_u8` uses one byte; `bool_i32` uses a little-endian `i32`.
- `PointF` is `f32 x, f32 y`.
- `TextPosition` is `i32 line, i32 column`; `TextRange` is `TextPosition start, TextPosition end`.
- Every function returning `const uint8_t*` with `size_t* out_size` returns an owned binary buffer. Read exactly `out_size` bytes, then call `free_binary_data` once. A null pointer indicates failure or no payload as documented by the header.
- `get_document_utf8`, `get_document_line_utf8`, `editor_get_selected_text`, `editor_get_word_at_cursor`, and `editor_get_link_target_at` return owned UTF-8 strings released with `free_u8_string`.
- `get_document_utf16` and `get_document_line_utf16` return owned UTF-16 strings released with `free_u16_string`.
- Release document and editor handles with `free_document` and `free_editor` respectively.

## Text Measurement Callbacks

Use the calling-convention macro from the header rather than hard-coding a platform convention:

```c
typedef struct {
    float (EDITOR_CALL* measure_text_width)(const U16Char* text, int32_t font_style);
    float (EDITOR_CALL* measure_inlay_hint_width)(const U16Char* text);
    float (EDITOR_CALL* measure_icon_width)(int32_t icon_id);
    void  (EDITOR_CALL* get_font_metrics)(float* arr, size_t length);
} text_measurer_t;
```

`get_font_metrics` writes the font metrics expected by the current core implementation. Callback storage and any platform trampoline must remain valid until the editor is freed.

## Canonical Wire Layouts

### `EditorOptions`

`create_editor` consumes the following fields in order:

1. `f32 touch_slop`
2. `i64 double_tap_timeout`
3. `i64 long_press_ms`
4. `f32 fling_friction`
5. `f32 fling_min_velocity`
6. `f32 fling_max_velocity`
7. `u64 max_undo_stack_size`
8. `i64 key_chord_timeout_ms`
9. `bool_u8 reveal_selection_end_on_select_all`

### `EditorActionResult`

State-changing APIs return this layout unless a more specific return payload is stated:

```text
bool_i32 handled
bool_i32 needs_redraw
enum_i32 source
enum_i32 text_change_kind
bool_i32 cursor_changed
bool_i32 selection_changed
bool_i32 scroll_changed
bool_i32 scale_changed
bool_i32 pointer_cursor_changed
bool_i32 composition_changed
bool_i32 decoration_changed
u32 animation_flags
u32 next_animation_delay_ms
u32 interaction_flags
List<TextChange> text_changes
TextPosition cursor_before
TextPosition cursor_after
bool_i32 has_selection_before
bool_i32 has_selection_after
TextRange selection_before
TextRange selection_after
f32 scroll_x_before
f32 scroll_y_before
f32 scroll_x_after
f32 scroll_y_after
f32 scale_before
f32 scale_after
enum_i32 pointer_cursor_before
enum_i32 pointer_cursor_after
enum_i32 ime_host_action
ImeState ime_state
enum_i32 gesture_type
enum_i32 gesture_event_type
PointF tap_point
HitTarget hit_target
enum_i32 modifiers
enum_i32 command
```

`text_changes` contains the exact edits applied to `Document` by this call; a non-empty list means that text changed. IME composition start, update, and cancellation are reported immediately whenever they modify the current text.

`TextChange` is `TextRange range, U8String new_text`. `HitTarget` is `enum_i32 type, i32 line, i32 column, i32 icon_id, i32 color_value`.

`animation_flags` is an `AnimationFlag` bit set: `EDGE_SCROLL=1`, `FLING=2`, and `TRANSIENT_SCROLLBAR=4`. A zero value stops scheduling. For nonzero flags, `next_animation_delay_ms=0` requests the next display frame; a positive value requests another `editor_tick_animations` call after that delay.

`interaction_flags` is an `InteractionFlag` bit set: `PRIMARY_POINTER=1`, `SELECTION_DRAG=2`, and `VIEWPORT_GESTURE=4`. It describes active input lifecycles and is independent of animation scheduling.

### `EditorRenderModel`

```text
f32 split_x
bool_i32 split_line_visible
f32 scroll_x
f32 scroll_y
Size viewport_size
PointF current_line
enum_i32 current_line_render_mode
List<VisualLine> lines
Cursor cursor
List<RangeEffectRenderItem> range_effects
SelectionHandle selection_start_handle
SelectionHandle selection_end_handle
List<GuideSegment> guide_segments
u32 max_gutter_icons
List<GutterIconRenderItem> gutter_icons
List<FoldMarkerRenderItem> fold_markers
ScrollbarModel vertical_scrollbar
ScrollbarModel horizontal_scrollbar
bool_i32 gutter_sticky
bool_i32 gutter_visible
enum_i32 pointer_cursor_type
```

Nested render-model types follow the field order documented beside `editor_build_render_model` in `c_api.h`.

### `LayoutMetrics`

```text
f32 font_height
f32 font_ascent
f32 line_spacing_add
f32 line_spacing_mult
f32 line_number_margin
f32 line_number_width
f32 content_start_padding
u32 max_gutter_icons
f32 inlay_hint_padding
f32 inlay_hint_margin
enum_i32 fold_arrow_mode
bool_i32 has_fold_regions
bool_i32 gutter_sticky
bool_i32 gutter_visible
```

### `ScrollMetrics`

```text
f32 scale
f32 scroll_x
f32 scroll_y
f32 max_scroll_x
f32 max_scroll_y
Size content_size
Size viewport_size
f32 text_area_x
f32 text_area_width
bool_i32 can_scroll_x
bool_i32 can_scroll_y
```

### Common Input Payloads

- `HandleConfig`: two `HandleHitArea` values; each hit area is `f32 left, f32 top, f32 right, f32 bottom`.
- `ScrollbarConfig`: `f32 thickness, f32 min_thumb, f32 thumb_hit_padding, enum_i32 mode, bool_u8 thumb_draggable, enum_i32 track_tap_mode, u16 fade_delay_ms, u16 fade_duration_ms`.
- `EditorRenderColors`: five `i32` colors in this order: text, link, active link, CodeLens, active CodeLens.
- `GestureEvent`: `enum_i32 type, List<PointF> points, i32 modifiers, f32 wheel_delta_x, f32 wheel_delta_y, f32 direct_scale`.
- `SetKeyMapPayload`: `List<KeyBinding>`; each binding is `KeyChord first, KeyChord second, u32 command`, and each chord is `u8 modifiers, u16 key_code`.
- `ApplyTextEditsPayload`: `List<TextEdit>`; each edit is `TextRange range, U8String new_text`.
- `SearchRequest`: `U8String pattern, SearchOptions options`; options are four `bool_i32` values for case-sensitive, whole-word, regex, and wrap-around followed by `u32 max_matches`.
- Replacement payloads are one `U8String`.

### Styles, Decorations, Guides, and Folding

- `TextStyle`: `i32 color, i32 background_color, i32 font_style`.
- `StyleSpan`: `u32 column, u32 length, u32 style_id`.
- `SetLineSpansPayload`: `u32 line, enum_i32 layer, List<StyleSpan> spans`.
- `SetBatchLineSpansPayload`: `enum_i32 layer, u32 entry_count`, then repeat `u32 line, List<StyleSpan> spans`.
- `RegisterBatchTextStylesPayload`: `u32 entry_count`, then repeat `u32 style_id, TextStyle style`.
- For inlay, phantom-text, gutter-icon, CodeLens, link, diagnostic, and document-highlight families, single-line payloads start with `u32 line` followed by `List<T>`. Their batch payloads start with `u32 entry_count`, then repeat `u32 line, List<T>`.
- `InlayHint`: `enum_i32 type, u32 column, i32 int_value, U8String text`.
- `PhantomText`: `u32 column, U8String text`.
- `GutterIcon`: `i32 icon_id`.
- `CodeLensItem`: `i32 column, i32 command_id, U8String text`.
- `LinkSpan`: `u32 column, u32 length, U8String target`.
- `Diagnostic`: `u32 column, u32 length, enum_i32 severity`. There is no color field in this payload.
- `DocumentHighlight`: `u32 column, u32 length, enum_i32 kind`.
- `IndentGuide` and `FlowGuide`: `TextPosition start, TextPosition end`.
- `BracketGuide`: `TextPosition parent, TextPosition end, List<TextPosition> children`.
- `SeparatorGuide`: `i32 line, enum_i32 style, i32 count, u32 text_end_column`.
- `FoldRegion`: `u32 start_line, u32 end_line, bool_u8 collapsed`.

### Linked Editing

`StartLinkedEditingPayload` directly contains the tab stop groups:

```text
List<TabStopGroup> groups
TabStopGroup = u32 index, List<TextRange> ranges, U8String default_text
```

There is no global range table or string blob in the current layout.

## Complete C API

The declarations below mirror all 153 functions in the current header.

### Documents and Editor Lifecycle

```c
EDITOR_API intptr_t create_document_from_utf8(const char* text);
EDITOR_API intptr_t create_document_from_utf16(const U16Char* text);
EDITOR_API intptr_t create_document_from_file(const char* path);
EDITOR_API void free_document(intptr_t document_handle);
EDITOR_API char* get_document_utf8(intptr_t document_handle);
EDITOR_API U16Char* get_document_utf16(intptr_t document_handle);
EDITOR_API size_t get_document_line_count(intptr_t document_handle);
EDITOR_API char* get_document_line_utf8(intptr_t document_handle, size_t line);
EDITOR_API U16Char* get_document_line_utf16(intptr_t document_handle, size_t line);

EDITOR_API intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size);
EDITOR_API void free_editor(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_set_document(intptr_t editor_handle, intptr_t document_handle, size_t* out_size);
```

### Viewport, Appearance, Rendering, and Events

```c
EDITOR_API const uint8_t* editor_set_viewport(intptr_t editor_handle, int32_t width, int32_t height, size_t* out_size);
EDITOR_API const uint8_t* editor_on_font_metrics_changed(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_fold_arrow_mode(intptr_t editor_handle, int mode, size_t* out_size);
EDITOR_API const uint8_t* editor_set_wrap_mode(intptr_t editor_handle, int mode, size_t* out_size);
EDITOR_API const uint8_t* editor_set_tab_size(intptr_t editor_handle, int tab_size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_scale(intptr_t editor_handle, float scale, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_spacing(intptr_t editor_handle, float add, float mult, size_t* out_size);
EDITOR_API const uint8_t* editor_set_content_start_padding(intptr_t editor_handle, float padding, size_t* out_size);
EDITOR_API const uint8_t* editor_set_show_split_line(intptr_t editor_handle, int show, size_t* out_size);
EDITOR_API const uint8_t* editor_set_current_line_render_mode(intptr_t editor_handle, int mode, size_t* out_size);
EDITOR_API const uint8_t* editor_set_render_whitespace(intptr_t editor_handle, int mode, size_t* out_size);
EDITOR_API const uint8_t* editor_set_render_line_breaks(intptr_t editor_handle, int enabled, size_t* out_size);
EDITOR_API const uint8_t* editor_set_gutter_sticky(intptr_t editor_handle, int sticky, size_t* out_size);
EDITOR_API const uint8_t* editor_set_gutter_visible(intptr_t editor_handle, int visible, size_t* out_size);
EDITOR_API const uint8_t* editor_set_handle_config(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_scrollbar_config(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_editor_render_colors(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_editor_range_effect_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_build_render_model(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_get_layout_metrics(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_handle_gesture_event(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_update_pointer_modifiers(intptr_t editor_handle, uint8_t modifiers, size_t* out_size);
EDITOR_API const uint8_t* editor_tick_animations(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_handle_key_event(intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size);
EDITOR_API const uint8_t* editor_set_keymap(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
```

Numeric values include `FoldArrowMode` `0=AUTO, 1=ALWAYS, 2=HIDDEN`; `WrapMode` `0=NONE, 1=CHAR_BREAK, 2=WORD_BREAK`; `WhitespaceRenderMode` `0=NONE, 1=BOUNDARY, 2=SELECTION, 3=TRAILING, 4=ALL`; and current-line mode `0=BACKGROUND, 1=BORDER, 2=NONE`.

### Text Editing, Line Actions, Undo, and Search

```c
EDITOR_API const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size);
EDITOR_API const uint8_t* editor_replace_text(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column, const char* text, size_t* out_size);
EDITOR_API const uint8_t* editor_delete_text(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column, size_t* out_size);
EDITOR_API const uint8_t* editor_apply_text_edits(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_delete_forward(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size);
EDITOR_API int editor_can_undo(intptr_t editor_handle);
EDITOR_API int editor_can_redo(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_search(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_find_next_search_match(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_find_previous_search_match(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_replace_current_search_match(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_replace_all_search_matches(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_search(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_get_search_state(intptr_t editor_handle, size_t* out_size);
```

`editor_get_search_state` returns a `SearchState` buffer rather than `EditorActionResult`. Its ordered fields are `enum_i32 status, U8String pattern, SearchOptions options, u64 generation, u32 match_count, i32 current_index, bool_i32 has_current_match, TextRange current_range, U8String error_message`.

### Cursor, Selection, Read-only State, and Indentation

```c
EDITOR_API const uint8_t* editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size);
EDITOR_API void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column);
EDITOR_API const uint8_t* editor_select_all(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_selection(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column, size_t* out_size);
EDITOR_API int editor_get_selection(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column);
EDITOR_API const char* editor_get_selected_text(intptr_t editor_handle);
EDITOR_API void editor_get_word_range_at_cursor(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column);
EDITOR_API const char* editor_get_word_at_cursor(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_move_cursor_left(intptr_t editor_handle, int extend_selection, size_t* out_size);
EDITOR_API const uint8_t* editor_move_cursor_right(intptr_t editor_handle, int extend_selection, size_t* out_size);
EDITOR_API const uint8_t* editor_move_cursor_up(intptr_t editor_handle, int extend_selection, size_t* out_size);
EDITOR_API const uint8_t* editor_move_cursor_down(intptr_t editor_handle, int extend_selection, size_t* out_size);
EDITOR_API const uint8_t* editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection, size_t* out_size);
EDITOR_API const uint8_t* editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection, size_t* out_size);
EDITOR_API const uint8_t* editor_set_read_only(intptr_t editor_handle, int read_only, size_t* out_size);
EDITOR_API int editor_is_read_only(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_set_auto_indent_mode(intptr_t editor_handle, int mode, size_t* out_size);
EDITOR_API int editor_get_auto_indent_mode(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_set_backspace_unindent(intptr_t editor_handle, int enabled, size_t* out_size);
EDITOR_API const uint8_t* editor_set_insert_spaces(intptr_t editor_handle, int enabled, size_t* out_size);
```

`AutoIndentMode` uses `0=NONE, 1=KEEP_INDENT`.

### Navigation and Coordinates

```c
EDITOR_API const uint8_t* editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior, size_t* out_size);
EDITOR_API const uint8_t* editor_goto_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size);
EDITOR_API const uint8_t* editor_ensure_cursor_visible(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y, size_t* out_size);
EDITOR_API const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size);
EDITOR_API void editor_get_position_rect(intptr_t editor_handle, size_t line, size_t column, float* out_x, float* out_y, float* out_height);
EDITOR_API void editor_get_cursor_rect(intptr_t editor_handle, float* out_x, float* out_y, float* out_height);
```

`ScrollBehavior` uses `0=GOTO_TOP, 1=GOTO_CENTER, 2=GOTO_BOTTOM`. `editor_get_scroll_metrics` returns `ScrollMetrics`, not `EditorActionResult`.

### Styles and Highlight Layers

```c
EDITOR_API const uint8_t* editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_register_batch_text_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer, size_t* out_size);
```

`SpanLayer` uses `0=SYNTAX, 1=SEMANTIC, 2=OVERLAY`. `font_style` combines `BOLD=1`, `ITALIC=2`, and `STRIKETHROUGH=4`.

### Decorations and Guides

```c
EDITOR_API const uint8_t* editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_gutter_icons(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_codelens(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_links(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_links(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_links(intptr_t editor_handle, size_t* out_size);
EDITOR_API const char* editor_get_link_target_at(intptr_t editor_handle, size_t line, size_t column);
EDITOR_API const uint8_t* editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_diagnostics(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_document_highlights(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_document_highlights(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_document_highlights(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_guides(intptr_t editor_handle, size_t* out_size);
```

### Brackets, Folding, and Aggregate Clearing

```c
EDITOR_API const uint8_t* editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count, size_t* out_size);
EDITOR_API const uint8_t* editor_set_auto_closing_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count, size_t* out_size);
EDITOR_API const uint8_t* editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_matched_brackets(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_toggle_fold(intptr_t editor_handle, size_t line, size_t* out_size);
EDITOR_API const uint8_t* editor_fold_at(intptr_t editor_handle, size_t line, size_t* out_size);
EDITOR_API const uint8_t* editor_unfold_at(intptr_t editor_handle, size_t line, size_t* out_size);
EDITOR_API const uint8_t* editor_fold_all(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_unfold_all(intptr_t editor_handle, size_t* out_size);
EDITOR_API int editor_is_line_visible(intptr_t editor_handle, size_t line);
EDITOR_API void editor_get_visible_line_range(intptr_t editor_handle, int32_t* out_start_line, int32_t* out_end_line);
EDITOR_API const uint8_t* editor_clear_highlights(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_inlay_hints(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_phantom_texts(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_all_decorations(intptr_t editor_handle, size_t* out_size);
```

### Snippets and Linked Editing

```c
EDITOR_API const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);
EDITOR_API const uint8_t* editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API int editor_is_in_linked_editing(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_linked_editing_next(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_linked_editing_prev(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_cancel_linked_editing(intptr_t editor_handle, size_t* out_size);
```

### IME Protocol

```c
EDITOR_API const uint8_t* editor_ime_begin_session(intptr_t editor_handle, int mutation_model, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_end_session(intptr_t editor_handle, uint64_t session_id, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_apply_commands(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_apply_text_updates(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_get_state(intptr_t editor_handle, uint64_t session_id, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_get_context(intptr_t editor_handle, uint64_t session_id, int source, int64_t start_utf16, int64_t length_utf16, size_t* out_size);
```

`begin_session` and `get_state` return `ImeState`; `get_context` returns `ImeTextContext`; session end and both batch mutation APIs return `EditorActionResult`. `ImeMutationModel` is fixed for the lifetime of a session: command-style adapters send `ImeCommandBatch`, while Flutter delta adapters send `ImeTextUpdateBatch`.

### Memory Utilities and Windows-only Setup

```c
EDITOR_API void free_u16_string(intptr_t string_ptr);
EDITOR_API void free_u8_string(intptr_t string_ptr);
EDITOR_API void free_binary_data(intptr_t data_ptr);

#ifdef _WIN32
EDITOR_API void init_unhandled_exception_handler();
#endif
```

`init_unhandled_exception_handler` does not exist in non-Windows builds and cannot be enabled by adding it to a Web export list.

## Synchronization Rule

When the C API changes, update this document together with `c_api.h`, `c_api.cpp`, platform bridges, and generated CoreProtocol codecs. Any change to a wire type, field order, integer width, boolean width, or enum representation requires matching decoder updates on every consuming platform.
