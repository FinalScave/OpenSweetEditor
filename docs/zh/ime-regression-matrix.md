# IME 回归矩阵

这份矩阵是 SweetEditor IME 行为的统一验收清单，用来补充[接入实现标准](platform-implementation-standard.md)。Core 测试负责验证协议语义，接入适配层仍需验证各操作系统输入法实际产生的原生事件序列。

## 协议不变量

- 一个Core session内的mutation model固定不变：命令式适配层提交`ImeCommandBatch`，Flutter delta input提交`ImeTextUpdateBatch`。Core session是逻辑输入代际，不要求与原生connection一一对应。
- Core统一持有document text、selection、composition、history、session生命周期与恢复策略。接入层持有当前Core binding；`TEXT_UPDATE`额外持有一个有限editing-buffer shadow。
- 一个原生 callback 或 Flutter delta list 只组装为一个有序原子 batch，并且只分发一次。
- 所有 IME 文本 offset 均使用 UTF-16 code unit，并携带显式 `ImeCoordinateSpace`。`DOCUMENT`、`EDITING_BUFFER`、`CONTEXT_SLICE` 与 `COMPOSITION` 坐标不得隐式混用。
- stale session id 与 stale text-update revision 必须零应用。接入层执行 `ImeHostAction`，不得重放、猜测或改写被拒绝的输入。
- `ImeState` 是操作后的权威状态；`ImeTextContext` 只是有限只读查询，不能创建 composition。
- 完整editing-value snapshot只用于初始化Flutter connection、Core session rebind或明确同步，不能diff成mutation；启用Flutter输入的目标必须使用原生delta并保留patch identity。
- 缺失 range 与 selection 使用 canonical `(-1, -1)`；合法 collapsed composition range 与缺失 range 不是同一状态。
- 普通编辑器 Backspace/Delete 使用 grapheme 语义；只有原生 surrounding-delete command 使用其显式 `ImeTextUnit`。
- 切换read-only时Core关闭可编辑session和原生connection；外部Core action改变TextUpdate editing state时优先通过`SYNC_EDITING_STATE`保留session。`RESTART_SESSION`只替换Core binding，除具体原生协议要求外不重建connection。

## 覆盖标签

| 标签 | 含义 |
|---|---|
| Core 自动化 | 由 `tests/core/editor` 下的 Core 回归测试或 C API smoke 测试覆盖 |
| 接入验收 | 必须通过接入适配层的原生 IME 路径验证，可以手测，也可以做目标自动化 |
| Trace 证据 | 目标的事件顺序、rebind 或候选行为存在差异时，必须保留原生 before/after 事件证据 |

## 语义矩阵

| ID | 场景 | 协议路径 | 期望行为 | 必要覆盖 |
|---|---|---|---|---|
| IME-01 | Session 生命周期 | 建立、查询、修改并结束一个固定 model 的 session | session id 非零且不复用；已结束或已被替换的 session 不能再修改编辑器 | Core 自动化，接入验收 |
| IME-02 | 普通文本提交 | `COMMIT_TEXT` command 或 insertion text-update step | 文本只在权威 selection 处插入一次；除非原生明确报告，否则不残留 composition | Core 自动化，接入验收 |
| IME-03 | 开始和更新 composition | `BEGIN_COMPOSITION` / `UPDATE_COMPOSITION`，或带有效 `composition_after` 的 delta step | provisional text 直接存在 Document 中；权威 composition range 跟随文本，更新只替换一次 | Core 自动化，接入验收 |
| IME-04 | 提交活跃 composition | commit command，或清除 composition 的 text-update step | 活跃 composition 只被替换一次，composition 变为缺失，selection 与返回的 `ImeState` 一致 | Core 自动化，接入验收 |
| IME-05 | Finish 与 Cancel | `FINISH_COMPOSITION` 或 `CANCEL_COMPOSITION` | Finish 保留当前文本为已提交文本；Cancel 恢复捕获的 baseline；两者都不能残留 composition effect | Core 自动化，接入验收 |
| IME-06 | 一个 callback 包含多步操作 | 有序 `ImeCommandBatch` 或 `ImeTextUpdateBatch` | 所有 step 作为一个 transaction 和一个 undo 边界应用；拒绝时不能残留部分 batch | Core 自动化 |
| IME-07 | 候选确认后连续删除 | 提交 `hello` 后连续删除 | 文本最终变为空；不能只移动光标、重新插入前缀、重复文本或留下不可删除的最后一个字符 | Core 自动化，接入验收；回归时保留 trace |
| IME-08 | 光标位于单词中间时替换候选 | 原生 API 提供显式 replacement patch/range | 只修改原生报告的目标；Core 与接入层都不能根据文本内容推测单词范围 | Core 自动化，接入验收；回归时保留 trace |
| IME-09 | Selection 方向与 affinity | selection command 或 non-text delta | anchor/active 方向和 collapsed caret affinity 可往返；后续 mutation 使用返回的权威 selection | Core 自动化，接入验收 |
| IME-10 | Collapsed active composition | 合法 `(n, n)` composition range | 在后续显式 transition 前 composition 保持活跃，不能与 canonical missing range 混淆 | Core 自动化，条件性接入验收 |
| IME-11 | Stale session 或 revision | 旧 session id，或 text-update batch 使用旧 `expected_state_revision` | Core 返回 mismatch/rejection、零应用，并提供恢复信息或 host action；接入层不得重放 | Core 自动化 |
| IME-12 | Text-update patch chain | 一个 Flutter callback 内包含多个 delta | 每个 step 的 `old_text` 等于上一个已接受 step 的输出；insert/delete/replace 身份和 list 顺序保持不变 | Core 自动化，Flutter 验收 |
| IME-13 | Flutter 活跃 session 收到完整 snapshot | 收到 text-changing `updateEditingValue`，而不是 delta | 适配层按协议异常处理，不计算 common-prefix/suffix diff，结束旧Core session并在同一connection安全rebind | Flutter 验收 |
| IME-14 | 有限 editing-buffer 边界 | 在任一 safe boundary 附近 query 或 delta | context 保持有界；不安全 edit 必须请求恢复，不能截断、偏移或复制 document text | Core 自动化，Flutter 验收 |
| IME-15 | Surrounding delete 单位 | 原生 `DELETE_SURROUNDING` 使用 UTF-16 或 Unicode code point | 严格按请求单位删除；普通硬件 Backspace/Delete 仍删除一个 grapheme | Core 自动化，接入验收 |
| IME-16 | Context slice | 对 `EDITING`、`COMMITTED` 或 `EDITING_BUFFER` 调用 `getImeContext` | slice start 与总 UTF-16 长度正确；selection/composition 只有完整落入 slice 才返回；查询不改变状态 | Core 自动化，接入验收 |
| IME-17 | Core 主动同步或结束session | TextUpdate下的外部编辑、selection移动、undo/redo返回Sync；read-only、document rebind或协议恢复返回Close/Restart | Sync保持同一session并回写权威有限buffer；Close/Restart的cleanup不重复end；Restart不能丢失焦点或要求用户重新点击：Android重建`InputConnection`，其他接入实现按各自原生API保留输入对象并重绑Core session | Core 自动化，接入验收，Trace 证据 |
| IME-18 | 渲染与 undo | 多行 composition 多次更新后 commit/cancel | composition effect 按权威 range 跨行更新，完整 composition 生命周期形成预期的单个 undo 边界 | Core 自动化，接入验收 |

## 接入验收矩阵

| 实现 | 原生 API 面 | 最低验收证据 |
|---|---|---|
| Android | `InputConnection`、extracted text、surrounding text | 验证 composing text/region、commit、selection、两种 surrounding-delete 单位 API、connection rebind、候选替换和前后台恢复 |
| Apple | `UITextInput` / `NSTextInputClient` | 验证 marked text、marked-relative 与 document-relative replacement、selection 方向、finish/cancel、geometry，以及Restart保持first responder并重绑Core session |
| Swing | `InputMethodEvent`、`InputMethodRequests` | 验证同一 event 的 committed/composed 混合 segment、committed-text context、selected text、cursor rectangle、cancel，以及Restart保持focus和`InputContext`并在EDT重绑 |
| WinForms | TSF / IMM | 验证 composition/result string、replacement range、selection、delete、finish/cancel、`CPS_CANCEL`，以及Restart保持`HWND/HIMC`并在下一次START重绑 |
| Avalonia | `TextInputMethodClient`、immutable input context | 验证 preedit callback、commit、nullable preedit cursor、selection/surrounding cache 一致性、context replacement、Android input-pane生命周期，以及Restart保留client并在Reset后重绑 |
| OHOS | IME Kit | 验证 attach/detach顺序、composition、commit、selection、surrounding text/delete、候选替换、前后台generation，以及idle Restart不detach/不重弹键盘 |
| Flutter | `DeltaTextInputClient`、`TextEditingDelta` | 验证有限buffer初始化、insert/delete/replace/non-text delta、多delta原子性、affinity、候选commit/delete、snapshot rejection、普通点击同connection同步，以及Restart同connection重绑Core session且不重弹键盘 |

Web 包导出六个 Core IME C API，但不包含浏览器输入适配器。浏览器 IME 由宿主适配器验收，负责把 composition、`beforeinput`、selection 与生命周期事件映射到一个共用 session model。

IME 改动具有实现特异性时，变更记录应说明已验证的 matrix case、OS 与输入法、mutation model、原生 callback 序列、session/revision 变化以及 `ImeHostAction`。
