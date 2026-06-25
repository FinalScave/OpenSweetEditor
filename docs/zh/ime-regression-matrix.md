# IME 回归矩阵

这份矩阵是 SweetEditor IME 行为的统一验收清单，用来补充[平台实现标准](platform-implementation-standard.md)。core 测试负责验证协议语义，平台适配层仍然需要验证各操作系统输入法实际发出的原生事件序列。

## 协议不变量

- 每次原生 IME 更新只能通过一条语义路径进入 core：命令式操作使用 `ImeCommandMessage`，原生文本窗口 snapshot / patch 使用 `ImeTextUpdateMessage`。
- `ImeMarkedRangeRole::PREEDIT` 只表示真实可编辑的平台 composition / marked / preedit 文本。
- `ImeMarkedRangeRole::SYSTEM_MARK` 只表示平台候选、纠错、高亮或当前词目标范围。
- surrounding text 请求、候选上下文请求、光标矩形请求、键盘语言、光标进入单词，都不能自动创建 editor preedit。
- document range 使用文档坐标。input-context 和 text-update offset 相对于对应的 `documentStartOffset`。
- IME handler 返回的每个非空 `EditorActionResult` 都必须且只通过一次平台统一结果分发入口。
- read-only 模式阻止文本变更，并 finish 或 cancel 任何活跃平台 composition；不能用禁用系统 IME 支持来实现。

## 覆盖标签

| 标签 | 含义 |
|---|---|
| Core 自动化 | 由 `tests/core/editor` 下的 core 回归测试或 C API smoke 测试覆盖 |
| 平台验收 | 必须通过平台适配层的原生 IME 路径验证，可以手测，也可以做平台自动化 |
| Trace 证据 | 平台存在事件顺序差异或复现问题时，应保留原生 before/after 事件证据 |

## 语义矩阵

| ID | 场景 | 原生信号 | Core 路径 | 期望行为 | 必要覆盖 |
|---|---|---|---|---|---|
| IME-01 | 普通文本提交 | 直接文本输入或等价 `commitText` | `COMMIT_TEXT` command 或 text-update insert | 文本只在报告的 selection 处插入一次；除非平台报告，否则不残留 preedit 或 system mark | Core 自动化，平台验收 |
| IME-02 | 可见 preedit 生命周期 | 平台声明 composing / marked / preedit 文本 | `SET_PREEDIT_TEXT`、marked range command 或 text-update preedit | 可见 IME composition 范围跟随平台文本和 selection；更新会替换上一段 preedit | Core 自动化，平台验收 |
| IME-03 | 提交活跃 preedit | preedit 活跃时平台提交文本 | `COMMIT_TEXT` 或 text-update commit/clear | commit 只替换活跃 preedit 一次，清除可见 preedit，并把光标留在平台报告位置 | Core 自动化，平台验收 |
| IME-04 | finish 或 cancel composition | 原生 finish/cancel 事件 | finish/cancel command 或 text-update clear | 平台 composition 结束后不残留 preedit 渲染或 system mark 状态 | Core 自动化，平台验收 |
| IME-05 | 文本窗口 snapshot 替换 | 原生完整 editing value 或 surrounding text window 变化 | `ImeTextUpdateMessage` snapshot 或 patch | 替换相对于 `documentStartOffset` 解析；stale context 请求重同步，不破坏文档文本 | Core 自动化，平台验收 |
| IME-06 | 候选确认后连续删除到空 | 输入 `hello`，确认候选，然后连续删除 | 取决于平台，可为 command 或 text-update | 文本按 `hello` -> `hell` -> `hel` -> `he` -> `h` -> 空变化；删除不能只移动光标，不能重新插入前缀文本，不能留下无法删除的字符 | Core 自动化，平台验收，回归时保留 trace |
| IME-07 | 候选替换 system-marked word | 点击 `enabled`，接受 `enables` | `SYSTEM_MARK` 加后续 commit 或 text-update replacement | 只替换目标词，例如 `boolean enabled()` -> `boolean enables()`；不能变成 `booleaenables()`，不能重复前缀、后缀、括号，也不能残留高亮 | Core 自动化，平台验收，回归时保留 trace |
| IME-08 | 单字符候选替换 | 候选把 system-marked range 替换成一个字符 | commit 或 text-update replacement over `SYSTEM_MARK` | 替换只消费目标范围一次；平台报告结束后清除 mark | Core 自动化 |
| IME-09 | 单词中间输入和候选更新 | 光标位于单词中间时启动 composition 或候选替换 | 带显式 range/context 的 command 或 text-update | core 不能假设光标在词尾；前缀和后缀文本保持正确 | Core 自动化，平台验收 |
| IME-10 | preedit 或 system mark 上删除 | marked range 存在时 backspace/delete | delete command 或 text-update deletion | preedit 根据平台事件收缩或替换；system mark 只辅助定位目标，不能变成隐藏已提交文本 | Core 自动化，平台验收 |
| IME-11 | selection 和 cursor 同步 | 原生 IME 移动 selection 或 cursor | selection command 或 text-update selection | core selection 匹配报告的坐标空间，后续 commit/delete 使用该 selection，而不是 stale local state | Core 自动化，平台验收 |
| IME-12 | stale input context | 平台发送旧的 context id/revision | 带 stale context 的 command 或 text-update | core 请求重同步，避免把旧编辑当成当前文档目标来应用 | Core 自动化 |
| IME-13 | 无 composition 的候选上下文 | IME 请求 surrounding text、候选上下文或光标矩形 | query API，只有平台声明目标时才可附带 `SYSTEM_MARK` | 不能仅因上下文请求而创建 editor preedit | Core 自动化，平台验收 |
| IME-14 | read-only 切换时有活跃 IME | 原生 composition 活跃时编辑器进入 read-only | 平台 finish/cancel 加被阻止的 edit command | 活跃平台 composition 被结束；之后 IME edit request 不修改文档 | 平台验收 |
| IME-15 | composition 渲染 | 活跃 preedit 出现在 render model | render model range effects | `PREEDIT` 渲染为 `IME_COMPOSITION`；`SYSTEM_MARK` 不渲染成可见 composition 下划线 | Core 自动化，平台验收 |
| IME-16 | composition 撤销边界 | 多次 preedit 更新后提交 | preedit update sequence 加 commit | 中间 preedit 更新折叠成预期的一次可撤销编辑，而不是多次已提交编辑 | Core 自动化 |

## 平台验收矩阵

| 平台 | 原生 API 面 | 最低验收证据 |
|---|---|---|
| Android | `InputConnection`、extracted text、surrounding text | 验证 `setComposingText`、`setComposingRegion`、`commitText`、`deleteSurroundingText`、`setSelection` 在 IME-02、IME-06、IME-07、IME-10、IME-11 中的行为 |
| Flutter | `TextInputClient`、`TextEditingValue`、启用时的 text delta | 验证 snapshot/patch owner、composing role 选择、统一结果分发，以及 IME-02、IME-06、IME-07、IME-11 中没有 stale session/widget 状态 |
| OHOS | IME Kit | 验证 composing/preedit callback range 与候选替换坐标映射，至少覆盖 IME-02、IME-07、IME-09、IME-11；遇到平台键盘候选行为差异时保留原生证据 |
| Swing | `InputMethodEvent`、`InputMethodRequests` | 验证 composed-text segment、committed-character count、候选上下文、光标矩形，至少覆盖 IME-02、IME-03、IME-10、IME-13 |
| WinForms | TSF / IMM | 验证 composition range、committed string、删除、finish/cancel 行为，至少覆盖 IME-02、IME-03、IME-04、IME-10 |
| Apple | `UITextInput` / `NSTextInputClient` | 验证 marked text range、selected range、replacement range、坐标空间转换，至少覆盖 IME-02、IME-03、IME-09、IME-11 |

IME 改动具有平台特异性时，变更记录应说明已验证的矩阵 case、手测使用的 OS 和输入法，以及适配层最终通过 `ImeCommandMessage` 还是 `ImeTextUpdateMessage` 进入 core。
