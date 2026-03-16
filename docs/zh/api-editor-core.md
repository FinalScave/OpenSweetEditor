# EditorCore / C API 参考

本文档以 `src/include/c_api.h` 为准，描述当前 SweetEditor 核心对外契约（2026-03）。

平台 API 文档：

- `docs/zh/api-platform-android.md`
- `docs/zh/api-platform-swing.md`
- `docs/zh/api-platform-winforms.md`
- `docs/zh/api-platform-apple.md`

## 契约边界

- 稳定跨平台 ABI：`extern "C"` + `intptr_t` 句柄 + 二进制 payload（渲染 / 事件 / 编辑结果）。
- C++ 内部类（`EditorCore`/`Document`/`TextLayout`）属于实现细节。
- 文档与代码冲突时，以 `c_api.h`/`c_api.cpp` 为准。

当前桥接现状：

- Android：主路径是 JNI 直连 C++（不直接走 `c_api.h`）。
- Swing / WinForms：通过 C API（FFM / PInvoke）。
- Apple：通过手工维护的 C bridge（接口形态与 `c_api.h` 存在差异，需显式校对）。

## 数据与内存约定

- 对象通过 `intptr_t` 句柄创建/释放。
- 渲染模型、手势结果、键盘结果、文本编辑结果、滚动度量等复杂返回值通常为 `const uint8_t* + out_size` 二进制 payload，调用方用 `free_binary_data` 释放。
- `get_layout_metrics` 返回 `LayoutMetrics` 二进制 payload（`const uint8_t* + out_size`），同样用 `free_binary_data` 释放。
- `get_document_line_text` 返回 UTF-16 文本，调用方用 `free_u16_string` 释放。
- 少量文本查询返回 UTF-8 `const char*`（如 `get_document_text`、`editor_get_selected_text`、`editor_get_word_at_cursor`）；平台封装层通常会立即复制，当前 C API 未单独导出 UTF-8 free 函数。

## 回调结构

### `text_measurer_t`

```c
typedef struct {
    float (__stdcall* measure_text_width)(const U16Char* text, int32_t font_style);
    float (__stdcall* measure_inlay_hint_width)(const U16Char* text);
    float (__stdcall* measure_icon_width)(int32_t icon_id);
    void  (__stdcall* get_font_metrics)(float* arr, size_t length);
} text_measurer_t;
```

## C API 分组

### 1) Document

```c
intptr_t        create_document_from_utf16(const U16Char* text);
intptr_t        create_document_from_file(const char* path);
void            free_document(intptr_t document_handle);
const char*     get_document_text(intptr_t document_handle);
size_t          get_document_line_count(intptr_t document_handle);
const U16Char*  get_document_line_text(intptr_t document_handle, size_t line);
```

### 2) Editor 生命周期

```c
intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size);
void     free_editor(intptr_t editor_handle);
void     set_editor_document(intptr_t editor_handle, intptr_t document_handle);
```

- `create_editor` 使用 LE `EditorOptions` payload：`f32 touch_slop`、`i64 double_tap_timeout`、`i64 long_press_ms`、`u64 max_undo_stack_size`。

### 3) 视口 / 外观

```c
void set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height);
void reset_editor_text_measurer(intptr_t editor_handle);
void editor_set_fold_arrow_mode(intptr_t editor_handle, int mode);
void editor_set_wrap_mode(intptr_t editor_handle, int mode);
void editor_set_line_spacing(intptr_t editor_handle, float add, float mult);
```

数值约定：

- `FoldArrowMode`: `0=AUTO`, `1=ALWAYS`, `2=HIDDEN`
- `WrapMode`: `0=NONE`, `1=CHAR_BREAK`, `2=WORD_BREAK`

### 4) 渲染

```c
const uint8_t* build_editor_render_model(intptr_t editor_handle, size_t* out_size);
const uint8_t* get_layout_metrics(intptr_t editor_handle, size_t* out_size);
```

- `build_editor_render_model`：返回本机字节序二进制 payload；当前支持平台均为 little-endian。
- `get_layout_metrics`：返回 `LayoutMetrics` 二进制 payload（本机字节序，当前支持平台均为 little-endian）。

`get_layout_metrics` payload 布局（按顺序）：

1. `f32 font_height`
2. `f32 font_ascent`
3. `f32 line_spacing_add`
4. `f32 line_spacing_mult`
5. `f32 line_number_margin`
6. `f32 line_number_width`
7. `i32 max_gutter_icons`
8. `f32 inlay_hint_padding`
9. `f32 inlay_hint_margin`
10. `i32 fold_arrow_mode`（`0=AUTO`, `1=ALWAYS`, `2=HIDDEN`）
11. `i32 has_fold_regions`（`0=false`, `1=true`）

### 5) 手势 / 键盘

```c
const uint8_t* handle_editor_gesture_event(
    intptr_t editor_handle, uint8_t type, uint8_t pointer_count, float* points, size_t* out_size);

const uint8_t* handle_editor_gesture_event_ex(
    intptr_t editor_handle, uint8_t type, uint8_t pointer_count, float* points,
    uint8_t modifiers, float wheel_delta_x, float wheel_delta_y, float direct_scale, size_t* out_size);

const uint8_t* handle_editor_key_event(
    intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size);
```

`modifiers` 位标志：`SHIFT=1`, `CTRL=2`, `ALT=4`, `META=8`。

### 6) 文本编辑（原子）

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

### 7) 行操作（新增）

```c
const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size);
```

### 8) 撤销 / 重做

```c
const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size);
int            editor_can_undo(intptr_t editor_handle);
int            editor_can_redo(intptr_t editor_handle);
```

### 9) 光标 / 选区 / 单词

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

### 10) 光标移动

```c
void editor_move_cursor_left(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_right(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_up(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_down(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection);
void editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection);
```

### 11) IME 组合输入

```c
void           editor_composition_start(intptr_t editor_handle);
void           editor_composition_update(intptr_t editor_handle, const char* text);
const uint8_t* editor_composition_end(intptr_t editor_handle, const char* committed_text, size_t* out_size);
void           editor_composition_cancel(intptr_t editor_handle);
int            editor_is_composing(intptr_t editor_handle);
void           editor_set_composition_enabled(intptr_t editor_handle, int enabled);
int            editor_is_composition_enabled(intptr_t editor_handle);
```

### 12) 只读、自动缩进与手柄配置

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

`AutoIndentMode`: `0=NONE`, `1=KEEP_INDENT`。

### 13) 坐标与导航

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

`ScrollBehavior`: `0=GOTO_TOP`, `1=GOTO_CENTER`, `2=GOTO_BOTTOM`。

### 14) 样式 / 高亮

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
- `font_style` 位标志：`BOLD=1`, `ITALIC=2`, `STRIKETHROUGH=4`
- `editor_set_line_spans` payload（LE）：
  - `u32 line, u32 layer, u32 span_count`
  - 重复 `span_count` 组：`[u32 column, u32 length, u32 style_id]`
- `editor_set_batch_line_spans` payload（LE）：
  - `u32 layer, u32 entry_count`
  - 重复 `entry_count` 组：`[u32 line, u32 span_count, [u32 column, u32 length, u32 style_id] × span_count]`

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

- `editor_set_line_inlay_hints` payload（LE）：
  - `u32 line, u32 hint_count`
  - 重复 `hint_count` 组：`[u32 type, u32 column, i32 int_value, u32 text_len, u8[text_len] text_utf8]`
- `editor_set_batch_line_inlay_hints` payload（LE）：
  - `u32 entry_count`
  - 重复 `entry_count` 组：`[u32 line, u32 hint_count, hint_items...]`
- `editor_set_line_phantom_texts` payload（LE）：
  - `u32 line, u32 phantom_count`
  - 重复 `phantom_count` 组：`[u32 column, u32 text_len, u8[text_len] text_utf8]`
- `editor_set_batch_line_phantom_texts` payload（LE）：
  - `u32 entry_count`
  - 重复 `entry_count` 组：`[u32 line, u32 phantom_count, phantom_items...]`
- `editor_set_line_gutter_icons` payload（LE）：
  - `u32 line, u32 icon_count`
  - 重复 `icon_count` 组：`[i32 icon_id]`
- `editor_set_batch_line_gutter_icons` payload（LE）：
  - `u32 entry_count`
  - 重复 `entry_count` 组：`[u32 line, u32 icon_count, [i32 icon_id] × icon_count]`
- `editor_set_line_diagnostics` payload（LE）：
- `u32 line, u32 diag_count`
- 重复 `diag_count` 组：`[u32 column, u32 length, i32 severity, i32 color]`
- `editor_set_batch_line_diagnostics` payload（LE）：
  - `u32 entry_count`
  - 重复 `entry_count` 组：`[u32 line, u32 diag_count, [u32 column, u32 length, i32 severity, i32 color] × diag_count]`

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

- `editor_set_indent_guides` payload（LE）：
  - `u32 count`
  - 重复 `count` 组：`[u32 start_line, u32 start_column, u32 end_line, u32 end_column]`
- `editor_set_bracket_guides` payload（LE）：
  - `u32 count`
  - 重复 `count` 组：`[u32 parent_line, u32 parent_column, u32 end_line, u32 end_column, u32 child_count, child_items...]`
- `editor_set_flow_guides` payload（LE）：
  - `u32 count`
  - 重复 `count` 组：`[u32 start_line, u32 start_column, u32 end_line, u32 end_column]`
- `editor_set_separator_guides` payload（LE）：
  - `u32 count`
  - 重复 `count` 组：`[i32 line, i32 style, i32 count, u32 text_end_column]`
- `editor_set_fold_regions` payload（LE）：
  - `u32 region_count`
  - 重复 `region_count` 组：`[u32 start_line, u32 end_line, u32 collapsed]`
- `separator style`: `0=single`, `1=double`

### 17) 清除操作

```c
void editor_clear_highlights(intptr_t editor_handle);
void editor_clear_inlay_hints(intptr_t editor_handle);
void editor_clear_phantom_texts(intptr_t editor_handle);
void editor_clear_all_decorations(intptr_t editor_handle);
```

### 18) 联动编辑（LinkedEditing）

```c
const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);
void           editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size);
int            editor_is_in_linked_editing(intptr_t editor_handle);
int            editor_linked_editing_next(intptr_t editor_handle);
int            editor_linked_editing_prev(intptr_t editor_handle);
void           editor_cancel_linked_editing(intptr_t editor_handle);
```

`editor_start_linked_editing` payload（LE）：
- `u32 group_count, u32 range_count, u32 string_blob_size`
- `group_count` 组：`[u32 index, u32 default_text_offset, u32 default_text_len]`
- `range_count` 组：`[u32 group_ordinal, u32 start_line, u32 start_col, u32 end_line, u32 end_col]`
- UTF-8 string blob（`default_text_offset=0xFFFFFFFF` 表示 `null`）

### 19) 工具 / 内存管理

```c
void free_u16_string(intptr_t string_ptr);
void free_binary_data(intptr_t data_ptr);
```

Windows 额外导出：

```c
void init_unhandled_exception_handler();
```

## 同步建议

- 任何公共能力变更，先改 `c_api.h` + `c_api.cpp`，再同步 Android JNI / Swing FFM / WinForms PInvoke / Apple bridge。
- 只要 `visual.h` 渲染模型布局、二进制 payload 布局或枚举值变化，平台解码器也要同步更新（包含 `LayoutMetrics` payload）。
