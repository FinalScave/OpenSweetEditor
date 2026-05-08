# SweetEditor IME Composition 标准

本文定义 SweetEditor 各平台 IME 接入的统一语义。标准优先级高于任何单个平台的临时实现；如果平台 API 和本文冲突，平台层必须做适配，而不是改变 core 语义。

## 核心结论

SweetEditor 的 IME composition 只能来自平台 IME 明确声明的 composing / marked / preedit 状态。Core 不得因为光标进入 Latin 单词、候选栏可能需要上下文、或输入法 subtype 看起来支持 ASCII，就自行创建 IME composition。

`compositionEnabled` 不再是标准能力开关。可编辑状态下编辑器必须始终支持平台 IME composition；只读状态负责阻止文本变更。历史 API 可以暂时保留为兼容 no-op，但不能改变 IME 行为，也不能让平台进入另一套输入路径。

## 术语

| 术语 | 含义 |
|---|---|
| Platform composing / marked / preedit | 系统 IME 通过原生 API 明确声明的组合文本或组合范围 |
| Editor composition | Core 为平台 composing / marked / preedit 建立的可见组合状态 |
| Candidate context | 输入法请求的 surrounding text、cursor rect、selection、当前行或 token 上下文 |
| Candidate replacement | 输入法通过 commit / replace API 明确提交的文本替换 |
| Shadow preedit | 平台需要临时持有但不应进入文档渲染的 preedit 状态 |

Candidate context 不是 composition。输入法需要上下文做候选、联想、纠错或替换时，平台层可以返回 surrounding text 和光标信息，但不能因此创建 editor composition 或绘制下划线。

## 标准行为

### 平台声明 composition

当平台 IME 调用 composing / marked / preedit API 时，平台层必须把它归一化为 core IME 事件：

| 语义事件 | 触发来源 | Core 行为 |
|---|---|---|
| `updatePreedit(text, script)` | 平台提供新的 composing / marked text | 建立或更新 editor composition |
| `markDocumentRange(range, script, PLATFORM_PREFIX_PREEDIT)` | 平台声明文档内已有文本属于 composing / marked range | 建立 editor composition，范围由平台负责声明 |
| `commitText(text, script)` | 平台提交文本 | 替换当前 composition；没有 composition 时按普通插入 |
| `replaceText(range, text, script)` | 平台明确请求替换范围 | 按平台声明范围替换，不隐式扩展到整词 |
| `finishPreedit()` | 平台结束 composition | 结束当前 composition，不创建新 composition |
| `cancelPreedit()` | 平台取消 composition | 回滚或清理当前 composition |
| `deleteSurrounding(...)` | 平台请求删除周围文本 | 按当前 selection / composition / cursor 语义删除 |
| `notifySelectionChanged(range)` | IME 驱动选区变化 | 同步 selection，必要时结束当前 composition |

一旦平台声明了非 collapsed composing / marked / preedit range，后续 `updatePreedit` 和 `commitText` 的目标就是该平台 range，而不是当前 cursor。只有没有活动 composition 时，`commitText` 才按普通插入处理。平台层必须保存原生 composing range 并同步给 core；core 必须负责替换范围、维护可见下划线和最终 commit，平台层不得把候选文本自行插入到 cursor 或扩展为整词。

### 平台未声明 composition

如果平台只调用 `commitText`、`replaceText`、`deleteSurroundingText`、`getTextBeforeCursor`、`getSurroundingText`、`getCursorCapsMode`、`updateSelection` 或等价 API，而没有声明 composing / marked / preedit，则 SweetEditor 不应显示 composition 下划线。

典型例子：

| 场景 | 期望 |
|---|---|
| 搜狗中文键盘点击 Latin 单词，只请求 surrounding text 或直接 commit 候选 | 不显示 editor composition |
| 系统 TextView / EditText 在同场景下不显示下划线 | SweetEditor 也不显示下划线 |
| Gboard / 搜狗显式调用 `setComposingText` 或 `setComposingRegion` | 显示 editor composition |
| 光标移动到单词中间 | 只同步 selection / cursor，不自动标记整词 |
| 词中或词尾点击候选替换 | 只有平台明确 `replaceText` 或 composing range 时才替换对应范围 |

## 跨平台 API 映射

### Android

Android 平台层必须以 `InputConnection` 为事实来源：

| Android API | SweetEditor 事件 |
|---|---|
| `setComposingText(text, newCursorPosition)` | `updatePreedit(text, script)` |
| `setComposingRegion(start, end)` | `markDocumentRange(range, script, PLATFORM_PREFIX_PREEDIT)` |
| `commitText(text, newCursorPosition)` | `commitText(text, script)` |
| `replaceText(start, end, text, ...)` | `replaceText(range, text, script)` |
| `finishComposingText()` | `finishPreedit()` |
| `deleteSurroundingText(...)` | `deleteSurrounding(...)` |
| `setSelection(start, end)` | `notifySelectionChanged(range)` |
| `getSurroundingText(...)` / `getTextBeforeCursor(...)` | 返回 candidate context，不创建 composition |

`InputMethodSubtype.isAsciiCapable()` 只表示 subtype 能输入 ASCII，不能单独推断为 Latin 输入态。`setComposingRegion` 传入的范围是平台 composition 声明，不得被 core 或平台层提升成整词候选目标。

Android 的 `setComposingRegion` 不要求 cursor 位于 composing range 内，也不改变文本内容、selection 或 cursor。平台层和 core MUST 接受合法的非 collapsed composing range，并保持当前 selection / cursor 语义；不得因为 range 不包含 cursor 就丢弃平台 composition。后续 `setComposingText` 和 `commitText` MUST 优先替换当前 Android composing span；没有 composing span 时才使用 selection / cursor。点击文本后平台层 SHOULD 通知系统 IME 发生 view click，并同步 selection / surrounding text，让 IME 有机会按 TextView 等原生编辑框行为声明 composing range。

Android API 33 起的 `setComposingText(..., TextAttribute)`、`setComposingRegion(..., TextAttribute)`、`commitText(..., TextAttribute)` 与无 `TextAttribute` 重载拥有同一文本语义。`TextAttribute` 只携带额外属性，不能让平台层绕过 core composition 状态。

Android 平台层可以向 IME 暴露有限的 surrounding text、当前行窗口或初始 surrounding subtext。由于部分输入法会把后续 `setComposingRegion` / `replaceText` 的 offset 解释为最近一次文本窗口内的 offset，而不是完整文档 offset，平台层 MUST 在进入 core 前完成坐标空间归一化：如果原生回调 offset 与最近暴露的文本窗口、selection 或 composing span 匹配，先转换为文档 offset；否则按平台文档定义的绝对 offset 处理。Core 只接收文档坐标，不负责猜测 Android 文本窗口坐标。

### iOS / macOS

iOS 以 `UITextInput` 为事实来源：

| Apple API | SweetEditor 事件 |
|---|---|
| `setMarkedText(_:selectedRange:)` | `updatePreedit` 或 `markDocumentRange` |
| `unmarkText()` | `finishPreedit()` |
| `insertText(_:)` | `commitText` |
| `markedTextRange` | 平台 marked range，同步到 core snapshot |

macOS 以 `NSTextInputClient` 为事实来源。`setMarkedText(_:selectedRange:replacementRange:)` 如果带 replacement range，应映射为平台声明的 marked range 或显式 replace；不得扩展为整词替换。

### Swing / AWT

Swing 以 `InputMethodEvent` 为事实来源。`committedCharacterCount` 之前的文本是 commit，之后的 `AttributedCharacterIterator` 文本是 composed/preedit。`InputMethodRequests` 只提供候选上下文与位置信息，不能触发 editor composition。

### WinForms / Windows

Windows 平台应优先以 TSF composition 为事实来源；IMM 路径以 `WM_IME_COMPOSITION`、`GCS_COMPSTR`、`GCS_RESULTSTR` 等组合字符串状态为事实来源。candidate window、reconversion context、surrounding text 请求不等于 composition。WinForms 当前实现暂不随本轮 Android 验证一起改动，但后续必须遵循同一标准。

### OHOS

OHOS 应以 text input client 的 preview / composing API 为事实来源，例如 `setPreviewText` 映射为 `updatePreedit`，`finishTextPreview` 映射为 `finishPreedit`。周围文本与光标矩形只作为 candidate context。

### Flutter

Flutter 以 `TextEditingValue.composing` 为事实来源。`composing` range 有效时同步为 editor composition；range 无效或 collapsed 时不得显示 composition。`TextInputClient.updateEditingValue` 中的 text / selection 变化不能自动推导整词 composition。

## Core 与平台职责

Core 负责：

- 维护平台声明的 composition 生命周期。
- 对 commit / replace / delete / selection 事件给出一致文本编辑结果。
- 生成 IME snapshot，包括 selection、platform marked range、surrounding text window、是否需要清理平台 preedit。
- 渲染 editor composition 装饰，但只渲染真实平台 composition。

平台层负责：

- 完整实现原生 IME 接口，保留 batch edit、selection、surrounding text、cursor rect、newCursorPosition 等平台细节。
- 把平台 composing / marked / preedit 映射到 core 语义事件。
- 把 core snapshot 同步回平台输入框模型。
- 保留原生输入框模型中的 composing span / marked range，作为后续 composing text 与 commit 的替换目标。
- 不在平台层自行扩展、收缩或发明 composition range。

## 不允许的行为

- 光标进入 Latin 单词后自动把整词标记为 IME composition。
- 把 candidate context 当作 composition 下划线。
- 把 `isAsciiCapable()`、键盘语言、候选栏状态单独当作 composition 证据。
- 在没有平台 composing / marked / preedit 的情况下，为了“看起来像其他编辑器”绘制 composition。
- 禁用 composition 时走独立 shadow editable 路径来提交中文候选。
- 平台层直接替换整词，除非平台 IME 明确给出 replacement range。

## 兼容迁移

历史 API 暂时按下列方式兼容：

| API / 概念 | 新语义 |
|---|---|
| `compositionEnabled` | 废弃；设置为 no-op，查询固定视为支持 composition |
| `WORD_TARGET` | 废弃；不再作为 IME composition 标准角色 |
| `refreshCompositionAtCursor` | 废弃；不得创建新的 Latin word composition |
| `PLATFORM_PREFIX_PREEDIT` | 保留；表示平台声明的文档 range composition |

如果后续需要拼写纠错、整词替换、补全或重命名目标，应定义独立的 editor replacement / completion / linked-editing API，不应复用 IME composition。
