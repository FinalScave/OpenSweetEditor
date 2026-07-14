# Web 平台 API

本文档描述 SweetEditor 当前的 Web API。

## 范围

- 受支持运行时：`sweeteditor_c_abi.js` 与 `sweeteditor_c_abi.wasm`
- 工具链：Emscripten
- 二进制格式：WebAssembly
- 模块形式：模块化 ES Module
- 运行环境：浏览器、Web Worker 和 Node.js

完整的 `include/sweeteditor/c_api.h` 不是 Web API 边界。只有 `cmake/platform/Emscripten.cmake` 中 `WASM_C_ABI_EXPORTED_FUNCTIONS` 列出的符号会被导出。当前列表包含 139 个符号，其中包括 `_malloc` 和 `_free`。

应以该 CMake 列表为权威依据。仓库中已有或本地缓存的 Wasm 产物可能来自旧导出列表，不能据此推断受支持的 Web 边界；发布前应重新构建产物。

## 模块初始化

~~~javascript
import createSweetEditorCAbi from '../../prebuilt/wasm/sweeteditor_c_abi.js';

const sweetEditor = await createSweetEditorCAbi();
~~~

模块工厂会在 Wasm runtime 初始化完成后返回。导出的 C 函数使用下划线前缀，例如 `_create_editor` 和 `_editor_insert_text`。

## 导出的 C ABI

以下分组完整列出当前 Web 导出边界。函数签名、结构体和二进制 payload 布局以 `include/sweeteditor/c_api.h` 与 C++ 核心 / C API 文档为准。

### 内存

    _malloc
    _free
    _free_u16_string
    _free_u8_string
    _free_binary_data

### 文档

    _create_document_from_utf8
    _create_document_from_utf16
    _create_document_from_file
    _free_document
    _get_document_utf8
    _get_document_utf16
    _get_document_line_count
    _get_document_line_utf8
    _get_document_line_utf16

基于文件的文档从 Emscripten 文件系统读取。

### Editor 生命周期与文档挂载

    _create_editor
    _free_editor
    _editor_set_document

`create_editor` 接收 C ABI 定义的 `text_measurer_t` callback 集合以及 `EditorOptions` payload。当前 Wasm 中 `_create_editor` 的调用约定为 `(measurerPtr, optionsPtr, optionsSize) -> editorHandle`。`measurerPtr` 指向 4 个连续的 32 位 Wasm 函数表索引，顺序如下：

| 偏移 | 回调 | `addFunction` 签名 |
| ---: | --- | --- |
| 0 | `measure_text_width(const U16Char*, int32_t) -> float` | `fii` |
| 4 | `measure_inlay_hint_width(const U16Char*) -> float` | `fi` |
| 8 | `measure_icon_width(int32_t) -> float` | `fi` |
| 12 | `get_font_metrics(float*, size_t) -> void` | `vii` |

文本指针指向以空字符结尾的 UTF-16 code unit。`get_font_metrics` 在传入长度允许时，将 ascent 写到字节偏移 0，将 descent 写到字节偏移 4。Ascent 使用核心约定，通常为负值；descent 通常为正值。

以下示例使用默认 `EditorOptions` 创建 editor，并返回显式析构入口：

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

`_create_editor` 调用期间会复制这 16 字节的 `text_measurer_t` 存储，因此调用返回后即可释放该临时内存。Editor 会继续持有 4 个函数表入口，所以必须等 `_free_editor` 完成后再对它们调用 `removeFunction`。

传入 `optionsPtr = 0`、`optionsSize = 0` 会使用核心默认值。当前协议中的自定义 options buffer 固定为 49 字节：`touch_slop` 是偏移 0 的 `f32`；`double_tap_timeout` 和 `long_press_ms` 是偏移 4、12 的 `i64`；3 个 fling 值是偏移 20、24、28 的 `f32`；`max_undo_stack_size` 是偏移 32 的 `u64`；`key_chord_timeout_ms` 是偏移 40 的 `i64`；`reveal_selection_end_on_select_all` 是偏移 48 的单字节布尔值。所有字段都按 little-endian 编码，将这 49 字节复制到 `_malloc` 分配的内存后，把指针和长度传给 `_create_editor`，调用返回后释放临时内存。该协议 payload 不使用原生结构体对齐填充。

### Viewport、外观与渲染

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

浏览器渲染由宿主负责。SweetEditor 返回二进制 render model，不创建 DOM，也不直接绘制 canvas。

### 输入与动画

    _editor_handle_gesture_event
    _editor_update_pointer_modifiers
    _editor_tick_animations
    _editor_handle_key_event
    _editor_set_keymap

宿主需要将浏览器事件转换为共享协议，并在 `EditorActionResult` 请求动画时驱动 `_editor_tick_animations`。

### 文本与行编辑

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

### 撤销与重做

    _editor_undo
    _editor_redo
    _editor_can_undo
    _editor_can_redo

### 光标、选区与单词

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

### 只读与缩进

    _editor_set_read_only
    _editor_is_read_only
    _editor_set_auto_indent_mode
    _editor_get_auto_indent_mode
    _editor_set_backspace_unindent
    _editor_set_insert_spaces

### 滚动与坐标

    _editor_scroll_to_line
    _editor_goto_position
    _editor_ensure_cursor_visible
    _editor_set_scroll
    _editor_get_scroll_metrics
    _editor_get_position_rect
    _editor_get_cursor_rect

### 文本样式与高亮层

    _editor_register_text_style
    _editor_register_batch_text_styles
    _editor_set_line_spans
    _editor_set_batch_line_spans
    _editor_clear_line_spans
    _editor_clear_highlights_layer
    _editor_clear_highlights

### Inlay、Phantom Text、Gutter、CodeLens 与 Link

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

### 诊断与结构线

    _editor_set_line_diagnostics
    _editor_set_batch_line_diagnostics
    _editor_clear_diagnostics
    _editor_set_indent_guides
    _editor_set_bracket_guides
    _editor_set_flow_guides
    _editor_set_separator_guides
    _editor_clear_guides

### 括号与折叠

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

### 装饰整体清理

    _editor_clear_all_decorations

### Snippet 与 Linked Editing

    _editor_insert_snippet
    _editor_start_linked_editing
    _editor_is_in_linked_editing
    _editor_linked_editing_next
    _editor_linked_editing_prev
    _editor_cancel_linked_editing

### IME 协议

    _editor_ime_has_preedit
    _editor_ime_handle_command_message
    _editor_ime_handle_text_update_message
    _editor_ime_get_keyboard_script_class
    _editor_ime_get_sync_snapshot
    _editor_ime_get_command_input_context
    _editor_ime_get_text_update_input_context

SweetEditor 只提供共享 IME 协议。宿主仍需把浏览器 composition、beforeinput、键盘、选区和候选 UI 行为接入这些消息。

## 导出的 Emscripten Runtime Methods

C ABI 模块额外导出：

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

模块启用可增长 Wasm 内存、可增长 callback table、常驻 runtime 和 Emscripten 文件系统。

## 二进制 Payload

复杂参数和返回值使用与原生 C API 相同的二进制协议，重要 payload 包括：

- `EditorActionResult`
- `EditorRenderModel`
- `LayoutMetrics`
- `ScrollMetrics`
- 与搜索无关的装饰和折叠模型
- Linked Editing 模型
- IME 消息、同步快照和输入上下文

返回的二进制数据必须通过 `_free_binary_data` 释放。返回的 UTF-8 和 UTF-16 字符串必须通过各自匹配的 free 函数释放。

## 内存所有权

- 文档 handle 使用 `_free_document` 释放。
- Editor handle 使用 `_free_editor` 释放。
- 通过 `_malloc` 分配的 buffer 使用 `_free` 释放。
- C API 返回的 UTF-8 字符串使用 `_free_u8_string` 释放。
- C API 返回的 UTF-16 字符串使用 `_free_u16_string` 释放。
- 二进制协议结果使用 `_free_binary_data` 释放。
- JavaScript 文本测量 callback 必须在 Editor 整个生命周期内保持有效；先调用 `_free_editor`，再通过 `removeFunction` 注销。

可能触发 Wasm 内存增长的操作之后，不要继续持有旧 typed-array view；应基于当前 module heap 重新创建 view。

## 未导出到 Web 的 C API

以下函数存在于完整 C API 中，但不属于当前 Web 导出列表：

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

如需使用这些跨平台函数中的某个函数，必须先将其加入 `WASM_C_ABI_EXPORTED_FUNCTIONS` 并重新构建 Web 产物。函数出现在 `c_api.h` 中不代表 JavaScript 可以调用。

`init_unhandled_exception_handler` 也未导出，但它只在 `_WIN32` 构建中声明。它不是 Emscripten 函数，不能仅通过加入 Web 导出列表启用。

## Embind 边界

`sweeteditor_bindings.cpp` 当前只有空的 `EMSCRIPTEN_BINDINGS` 注册块。因此 `sweeteditor_embind` 产物可以初始化 Wasm module 和文件系统，但不会通过 Embind 暴露任何 SweetEditor class、function 或 value type。

## 参考

- Web 接入与构建说明：[`platform/Emscripten/README.md`](../../platform/Emscripten/README.md)
- 权威导出列表：[`cmake/platform/Emscripten.cmake`](../../cmake/platform/Emscripten.cmake)
- 完整 C ABI 声明：[`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h)
- 二进制协议与 C API 文档：[`docs/zh/api-editor-core.md`](api-editor-core.md)
