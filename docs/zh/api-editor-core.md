# EditorCore / C API 参考

本文描述 [`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h) 当前声明的外部核心契约。若本文与实现不一致，以头文件为准。

接入 API 文档：

- [Android 平台 API](api-platform-android.md)
- [Avalonia API](api-platform-avalonia.md)
- [Flutter API](api-platform-flutter.md)
- [OHOS 平台 API](api-platform-ohos.md)
- [Swing API](api-platform-swing.md)
- [WinForms API](api-platform-winforms.md)
- [Apple 平台 API](api-platform-apple.md)
- [Web 平台 API](api-platform-web.md)

## 契约边界

- 跨平台 ABI 使用 `extern "C"`、`EDITOR_API`、`EDITOR_CALL`、`intptr_t` handle 和 CoreProtocol 二进制 payload。
- `EditorCore`、`Document`、`TextLayout` 等 C++ 类型属于实现细节。
- Android 主要通过 JNI 直接调用 C++；Swing 和 WinForms 通过 FFM 与 P/Invoke 使用 C API；Apple 使用手工维护且公开 Swift 形态不同的 C bridge；Web 只导出 `WASM_C_ABI_EXPORTED_FUNCTIONS` 明确列出的子集。

## 数据、编码与内存

- 行号和列号均从 0 开始。
- 所有 CoreProtocol payload 固定使用 little-endian 编码，与宿主字节序无关。
- `U8String` 为 `u32 byte_length`，随后是 UTF-8 字节。
- `List<T>` 为 `u32 count`，随后是编码后的元素。
- Map 类 payload 为 `u32 entry_count`，随后按插入顺序排列键值对。
- `bool_u8` 占 1 字节；`bool_i32` 是 little-endian `i32`。
- `PointF` 为 `f32 x, f32 y`。
- `TextPosition` 为 `i32 line, i32 column`；`TextRange` 为 `TextPosition start, TextPosition end`。
- 所有返回 `const uint8_t*` 且接收 `size_t* out_size` 的函数都会返回由调用者持有的二进制 buffer。读取恰好 `out_size` 字节后必须调用一次 `free_binary_data`。空指针表示失败或头文件说明的无 payload 情况。
- `get_document_utf8`、`get_document_line_utf8`、`editor_get_selected_text`、`editor_get_word_at_cursor`、`editor_get_link_target_at` 返回由调用者持有的 UTF-8 字符串，使用 `free_u8_string` 释放。
- `get_document_utf16` 和 `get_document_line_utf16` 返回由调用者持有的 UTF-16 字符串，使用 `free_u16_string` 释放。
- Document 与 Editor handle 分别使用 `free_document` 和 `free_editor` 释放。

## 文本测量回调

必须使用头文件定义的调用约定宏，不要硬编码某个平台的调用约定：

```c
typedef struct {
    float (EDITOR_CALL* measure_text_width)(const U16Char* text, int32_t font_style);
    float (EDITOR_CALL* measure_inlay_hint_width)(const U16Char* text);
    float (EDITOR_CALL* measure_icon_width)(int32_t icon_id);
    void  (EDITOR_CALL* get_font_metrics)(float* arr, size_t length);
} text_measurer_t;
```

`get_font_metrics` 写入当前核心所需的字体度量。回调存储和平台 trampoline 必须至少保持到 Editor 被释放。

## 标准 Wire Layout

### `EditorOptions`

`create_editor` 按以下顺序读取字段：

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

除非特别说明了其他返回 payload，修改状态的 API 都返回以下布局：

```text
bool_i32 handled
bool_i32 needs_redraw
enum_i32 source
enum_i32 text_change_kind
bool_i32 content_changed
bool_i32 cursor_changed
bool_i32 selection_changed
bool_i32 scroll_changed
bool_i32 scale_changed
bool_i32 pointer_cursor_changed
bool_i32 composition_changed
bool_i32 decoration_changed
bool_i32 needs_ime_sync
bool_i32 needs_edge_scroll
bool_i32 needs_fling
bool_i32 needs_animation
bool_i32 is_handle_drag
List<TextChange> changes
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
ImeSyncSnapshot ime_sync
enum_i32 gesture_type
enum_i32 gesture_event_type
PointF tap_point
HitTarget hit_target
enum_i32 modifiers
enum_i32 command
```

`TextChange` 为 `TextRange range, U8String new_text`。`HitTarget` 为 `enum_i32 type, i32 line, i32 column, i32 icon_id, i32 color_value`。

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

嵌套的 render-model 类型遵循 `c_api.h` 中 `editor_build_render_model` 旁边记录的字段顺序。

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

### 通用输入 Payload

- `HandleConfig`：两个 `HandleHitArea`；每个 hit area 为 `f32 left, f32 top, f32 right, f32 bottom`。
- `ScrollbarConfig`：`f32 thickness, f32 min_thumb, f32 thumb_hit_padding, enum_i32 mode, bool_u8 thumb_draggable, enum_i32 track_tap_mode, u16 fade_delay_ms, u16 fade_duration_ms`。
- `EditorRenderColors`：按文本、链接、激活链接、CodeLens、激活 CodeLens 的顺序排列 5 个 `i32` 颜色。
- `GestureEvent`：`enum_i32 type, List<PointF> points, i32 modifiers, f32 wheel_delta_x, f32 wheel_delta_y, f32 direct_scale`。
- `SetKeyMapPayload`：`List<KeyBinding>`；每项为 `KeyChord first, KeyChord second, u32 command`，每个 chord 为 `u8 modifiers, u16 key_code`。
- `ApplyTextEditsPayload`：`List<TextEdit>`；每项为 `TextRange range, U8String new_text`。
- `SearchRequest`：`U8String pattern, SearchOptions options`；options 是表示大小写、全词、正则和循环查找的 4 个 `bool_i32`，随后是 `u32 max_matches`。
- 替换 payload 是一个 `U8String`。

### 样式、装饰、结构线与折叠

- `TextStyle`：`i32 color, i32 background_color, i32 font_style`。
- `StyleSpan`：`u32 column, u32 length, u32 style_id`。
- `SetLineSpansPayload`：`u32 line, enum_i32 layer, List<StyleSpan> spans`。
- `SetBatchLineSpansPayload`：`enum_i32 layer, u32 entry_count`，随后重复 `u32 line, List<StyleSpan> spans`。
- `RegisterBatchTextStylesPayload`：`u32 entry_count`，随后重复 `u32 style_id, TextStyle style`。
- 对 inlay、phantom text、gutter icon、CodeLens、link、diagnostic 和 document highlight 类 payload，单行形式以 `u32 line` 开始并跟随 `List<T>`；批量形式以 `u32 entry_count` 开始，随后重复 `u32 line, List<T>`。
- `InlayHint`：`enum_i32 type, u32 column, i32 int_value, U8String text`。
- `PhantomText`：`u32 column, U8String text`。
- `GutterIcon`：`i32 icon_id`。
- `CodeLensItem`：`i32 column, i32 command_id, U8String text`。
- `LinkSpan`：`u32 column, u32 length, U8String target`。
- `Diagnostic`：`u32 column, u32 length, enum_i32 severity`，当前 payload 没有 color 字段。
- `DocumentHighlight`：`u32 column, u32 length, enum_i32 kind`。
- `IndentGuide` 和 `FlowGuide`：`TextPosition start, TextPosition end`。
- `BracketGuide`：`TextPosition parent, TextPosition end, List<TextPosition> children`。
- `SeparatorGuide`：`i32 line, enum_i32 style, i32 count, u32 text_end_column`。
- `FoldRegion`：`u32 start_line, u32 end_line, bool_u8 collapsed`。

### Linked Editing

`StartLinkedEditingPayload` 包含一个 `LinkedEditingModel`：

```text
LinkedEditingModel = List<TabStopGroup> groups
TabStopGroup = u32 index, List<TextRange> ranges, U8String default_text
```

当前布局没有全局 range table 或 string blob。

## 完整 C API

以下声明对应当前头文件中的全部 153 个函数。

### 文档与 Editor 生命周期

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

### 视口、外观、渲染与事件

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

常用数值包括：`FoldArrowMode` 为 `0=AUTO, 1=ALWAYS, 2=HIDDEN`；`WrapMode` 为 `0=NONE, 1=CHAR_BREAK, 2=WORD_BREAK`；`WhitespaceRenderMode` 为 `0=NONE, 1=BOUNDARY, 2=SELECTION, 3=TRAILING, 4=ALL`；当前行模式为 `0=BACKGROUND, 1=BORDER, 2=NONE`。

### 文本编辑、行操作、撤销与搜索

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

`editor_get_search_state` 返回 `SearchState` 而不是 `EditorActionResult`。字段顺序为 `enum_i32 status, U8String pattern, SearchOptions options, u64 generation, u32 match_count, i32 current_index, bool_i32 has_current_match, TextRange current_range, U8String error_message`。

### 光标、选区、只读与缩进

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

`AutoIndentMode` 为 `0=NONE, 1=KEEP_INDENT`。

### 导航与坐标

```c
EDITOR_API const uint8_t* editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior, size_t* out_size);
EDITOR_API const uint8_t* editor_goto_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size);
EDITOR_API const uint8_t* editor_ensure_cursor_visible(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y, size_t* out_size);
EDITOR_API const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size);
EDITOR_API void editor_get_position_rect(intptr_t editor_handle, size_t line, size_t column, float* out_x, float* out_y, float* out_height);
EDITOR_API void editor_get_cursor_rect(intptr_t editor_handle, float* out_x, float* out_y, float* out_height);
```

`ScrollBehavior` 为 `0=GOTO_TOP, 1=GOTO_CENTER, 2=GOTO_BOTTOM`。`editor_get_scroll_metrics` 返回 `ScrollMetrics`，不是 `EditorActionResult`。

### 样式与高亮层

```c
EDITOR_API const uint8_t* editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style, size_t* out_size);
EDITOR_API const uint8_t* editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_register_batch_text_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer, size_t* out_size);
EDITOR_API const uint8_t* editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer, size_t* out_size);
```

`SpanLayer` 为 `0=SYNTAX, 1=SEMANTIC, 2=OVERLAY`。`font_style` 可组合 `BOLD=1`、`ITALIC=2`、`STRIKETHROUGH=4`。

### 装饰与结构线

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

### 括号、折叠与整体清理

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

### Snippet 与 Linked Editing

```c
EDITOR_API const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);
EDITOR_API const uint8_t* editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API int editor_is_in_linked_editing(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_linked_editing_next(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_linked_editing_prev(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_cancel_linked_editing(intptr_t editor_handle, size_t* out_size);
```

### IME 协议

```c
EDITOR_API int editor_ime_has_preedit(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_ime_handle_command_message(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_handle_text_update_message(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);
EDITOR_API int editor_ime_get_keyboard_script_class(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_ime_get_sync_snapshot(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_get_command_input_context(intptr_t editor_handle, size_t before_length, size_t after_length, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_get_text_update_input_context(intptr_t editor_handle, int scope, size_t before_length, size_t after_length, size_t* out_size);
```

两个 message handler 返回 `EditorActionResult`。快照与输入上下文查询返回 `ImeSyncSnapshot` 或 `ImeInputContext` payload，并遵循相同的 buffer 所有权规则。

### 内存工具与 Windows 专用初始化

```c
EDITOR_API void free_u16_string(intptr_t string_ptr);
EDITOR_API void free_u8_string(intptr_t string_ptr);
EDITOR_API void free_binary_data(intptr_t data_ptr);

#ifdef _WIN32
EDITOR_API void init_unhandled_exception_handler();
#endif
```

`init_unhandled_exception_handler` 不存在于非 Windows 构建中，不能通过加入 Web 导出列表来启用。

## 同步规则

C API 变化时，应同时更新本文、`c_api.h`、`c_api.cpp`、平台 bridge 和生成的 CoreProtocol codec。任何 wire 类型、字段顺序、整数宽度、布尔宽度或枚举表示变化，都必须同步所有平台解码器。
