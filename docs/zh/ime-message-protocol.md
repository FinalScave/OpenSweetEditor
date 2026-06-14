# SweetEditor IME 消息协议设计

本文描述当前收敛后的 IME 协议。目标是让平台侧只做原生事件到协议消息的映射，把真实 preedit、系统候选/纠错标记、文本模型同步和坐标换算统一交给 core 判定。

## 设计目标

- C API 输入入口按语义分成两条：`ImeCommandMessage` 和 `ImeTextUpdateMessage`。
- 不再保留 `ImeMessageKind`。通道由 C API 函数名决定，不再由 payload 里的额外 kind 决定。
- 不再保留分散的旧 IME 输入 API，例如 update preedit、replace text、text model delta 等旧入口。
- 平台侧必须保存最近一次 IME text window 的 `context_id` 和 `context_revision`，因为系统回调给的是局部 editable offset；平台侧不负责把局部 offset 换算成 document 坐标。
- `ImeInputContext.document_start_offset` 由 core 维护，用于 core 将 context-local UTF-16 offset 映射回文档坐标。
- 真实 preedit 和系统候选/纠错标记显式分离，避免 Android `setComposingRegion` 这类系统 marked range 被后续输入当成可替换 composition。

## C API

输入入口只有两条：

```cpp
EDITOR_API const uint8_t* editor_ime_handle_command_message(
    intptr_t editor_handle,
    const uint8_t* data,
    size_t size,
    size_t* out_size);

EDITOR_API const uint8_t* editor_ime_handle_text_update_message(
    intptr_t editor_handle,
    const uint8_t* data,
    size_t size,
    size_t* out_size);
```

查询和同步入口：

```cpp
EDITOR_API int editor_ime_is_composing(intptr_t editor_handle);
EDITOR_API void editor_ime_get_composing_range(...);
EDITOR_API void editor_ime_get_composing_session_range(...);
EDITOR_API int editor_ime_get_keyboard_script_class(intptr_t editor_handle);
EDITOR_API const uint8_t* editor_ime_get_sync_snapshot(intptr_t editor_handle, size_t* out_size);
EDITOR_API const uint8_t* editor_ime_get_command_input_context(
    intptr_t editor_handle,
    size_t before_length,
    size_t after_length,
    size_t* out_size);
EDITOR_API const uint8_t* editor_ime_get_text_update_input_context(
    intptr_t editor_handle,
    int scope,
    size_t before_length,
    size_t after_length,
    size_t* out_size);
```

## 坐标规则

`ImeOffsetRange` 表示当前 IME context 内的 UTF-16 offset range：

```cpp
struct ImeOffsetRange {
  int32_t start;
  int32_t end;
};
```

`ImeCommandMessage` 和 `ImeTextUpdateMessage` 直接携带：

```cpp
uint64_t context_id;
int32_t context_revision;
```

平台侧只需要把从 core 拿到的 `context_id/context_revision` 回传给后续 IME 消息。core 根据这两个字段判断消息是否对应当前 text window；如果过期，core 会要求平台重新同步，而不是执行错误替换。

## Marked Range

marked range 使用 role 区分语义：

```cpp
enum class ImeMarkedRangeRole {
  NONE = 0,
  PREEDIT = 1,
  SYSTEM_MARK = 2,
};
```

- `PREEDIT` 表示真实 IME 预编辑文本或真实 composition range。core 拥有它的 composition 生命周期，commit、finish、cancel 和 preedit replacement 只消费这个范围。
- `SYSTEM_MARK` 表示系统输入法报告的候选、纠错、下划线、高亮或当前词目标范围。core 可以保存、显示和同步它，但不能把它当成可隐式替换的 preedit。
- 只有显式 `REPLACE_TEXT` 命令允许替换指定范围。单纯 `SYSTEM_MARK` 不会让后续输入替换该范围。

## Command Message

`ImeCommandMessage` 表示平台输入系统发来的明确命令：

```cpp
enum class ImeCommandKind {
  SET_SELECTION = 0,
  SET_PREEDIT_TEXT = 1,
  COMMIT_TEXT = 2,
  FINISH_PREEDIT = 3,
  CANCEL_PREEDIT = 4,
  SET_MARKED_RANGE = 5,
  CLEAR_MARKED_RANGE = 6,
  REPLACE_TEXT = 7,
  DELETE_SURROUNDING_TEXT = 8,
  SET_KEYBOARD_SCRIPT = 9,
};
```

`SET_SELECTION` 同时覆盖光标和选择区；光标就是 `selection.start == selection.end`。不再单独提供 `SET_CURSOR`。

`SET_PREEDIT_TEXT` 同时覆盖设置 preedit 文本和 preedit 内 selection。平台有明确 selection 时填 `selection`，否则使用 `cursor_offset`。不再单独提供 `SET_PREEDIT_SELECTION`。

字段语义：

- `range`：context-local 操作范围，用于 `SET_MARKED_RANGE` 和 `REPLACE_TEXT`。
- `selection`：context-local selection，用于 `SET_SELECTION`，也可随 `SET_PREEDIT_TEXT` 描述 preedit 内选择。
- `text`：preedit、commit 或 replacement 文本。
- `cursor_offset`：插入或替换后的光标偏移，沿用原生 IME 常见 cursor offset 语义。
- `delete_before/delete_after`：`DELETE_SURROUNDING_TEXT` 删除光标前后的长度。
- `text_unit`：删除长度单位，稳定值为 `GRAPHEME` 或 `CODE_POINT`。
- `marked_role`：`SET_MARKED_RANGE` 或 `CLEAR_MARKED_RANGE` 的范围语义。
- `script_class`：输入脚本分类提示。

## Text Update Message

`ImeTextUpdateMessage` 表示平台文本模型同步。Flutter 是主要使用者；其他平台如果只能拿到文本框状态或 delta，也走这条通道。

```cpp
enum class ImeTextUpdateKind {
  SNAPSHOT = 0,
  PATCH = 1,
};

enum class ImeTextUpdateScope {
  DOCUMENT_WINDOW = 0,
  TRANSIENT_INPUT = 1,
};
```

- `SNAPSHOT`：`text` 是当前 text window 的完整内容；`selection` 和 `marked_range` 是该窗口内的局部 UTF-16 offset。
- `PATCH`：`text` 是 patch 前的基准文本；`patch.range` 和 `patch.text` 描述替换；core 合成 next text 后再应用 selection 和 marked range。
- `DOCUMENT_WINDOW` 对应 core 提供的文档窗口 context。
- `TRANSIENT_INPUT` 对应平台只能提供临时输入缓冲的场景。

## Core 状态机

core 内部维护两条独立状态：

- `preedit_range`：真实预编辑范围，拥有 composition 生命周期。
- `system_mark_range`：系统候选、纠错、下划线或高亮范围，不拥有 composition 生命周期。

处理规则：

- `SET_PREEDIT_TEXT`、`COMMIT_TEXT`、`FINISH_PREEDIT`、`CANCEL_PREEDIT` 只消费或更新真实 preedit。
- `SET_MARKED_RANGE` 携带 `PREEDIT` 时更新 preedit，携带 `SYSTEM_MARK` 时只更新 system mark。
- `CLEAR_MARKED_RANGE` 按 `marked_role` 清理对应范围；`NONE` 可以清理所有 marked range。
- `ImeTextUpdateMessage.marked_range.role` 决定该范围进入 preedit 还是 system mark。
- 真实 preedit 开始时，旧 system mark 可以被清理，并通过 sync snapshot 通知平台清除下划线或高亮。

## 平台映射

- Android：`setComposingText` -> `SET_PREEDIT_TEXT`；`commitText` -> `COMMIT_TEXT`；`finishComposingText` -> `FINISH_PREEDIT`；`deleteSurroundingText` -> `DELETE_SURROUNDING_TEXT`；`setComposingRegion` -> `SET_MARKED_RANGE / SYSTEM_MARK`。
- iOS/macOS：真实 marked/preedit 文本 -> `SET_PREEDIT_TEXT`；插入 -> `COMMIT_TEXT`；结束 -> `FINISH_PREEDIT`；候选或纠错目标范围 -> `SYSTEM_MARK`。
- WinForms/Swing/Avalonia/Qt：拿到原生 composition event 时走 command；只能拿到文本状态或 delta 时走 text update。
- Flutter：`TextEditingValue` -> `TEXT_UPDATE / SNAPSHOT`；`TextEditingDelta` -> `TEXT_UPDATE / PATCH`；Flutter composing 默认映射为 `SYSTEM_MARK`，除非平台能证明它是真实 preedit ownership。

## 平台侧职责

平台侧保留：

- 获取 core 提供的 command/text-update input context。
- 保存最新 `context_id/context_revision` 并回填到后续消息。
- 把原生 IME 事件编码成 `ImeCommandMessage` 或 `ImeTextUpdateMessage`。
- 调用对应 C API。
- 根据 `EditorActionResult.imeSync` 更新平台 selection、marked range、keyboard/input connection 状态。

平台侧不负责：

- 把 context-local offset 换算成 document offset。
- 判断 system mark 是否应该升级成真实 composition。
- 在多个旧 C API 之间选择调用路径。
- 维护额外的 preedit/system mark 状态机。

## 回归场景

- Android 点击候选或系统标记一个词后，继续输入应插入文本，不应替换该词。
- Android `setComposingText` 的真实 preedit 应能正常下划线、移动 selection、commit、finish、cancel。
- Flutter Android 候选点击、下划线和高亮行为保持正常。
- Flutter Windows snapshot 和 delta 都能稳定同步。
- `SYSTEM_MARK` 清除不应误清真实 preedit。
- context stale 时 core 返回 resync，不执行错误替换。
