# SweetEditor IME 架构重构临时设计

> 状态：临时设计草案，尚未实现。
>
> 本文用于固定下一轮 IME 重构的目标、边界和验收条件。重构完成前，现有代码和正式 API 文档仍描述当前行为。

## 设计结论

本轮采用以下唯一方案：

- Core 是文本、选区、composition、撤销和恢复策略的唯一权威。
- Core 的 IME 生命周期只有 `Idle` 和 `Composition`。实现上使用可选的 `CompositionState`，不增加阶段枚举。
- `SYSTEM_MARK`、键盘脚本分类、候选提交窗口、普通拉丁词锁定和其他候选词启发式全部删除。
- `ImeMutationModel` 是 per-session 入站协议，不是操作系统分类：Android 原生、Apple、Swing、WinForms、Avalonia 和 OHOS 使用 `ImeCommandBatch`；Flutter 五端使用 `ImeTextUpdateBatch`。两条路径保持类型分离，但进入同一个 reducer、`CompositionState` 和短期 `EditTransaction` 体系。
- Flutter 的 Core入站只接收 `ImeTextUpdateBatch`。Android、iOS、macOS 和 Windows 直接归一化 delta list；Linux 3.41.6 的 text-changing delta 存在确定性缺陷，不能靠 snapshot diff恢复 patch身份。Linux 新路径必须等待 engine修复或项目回补后复用同一 delta入口，否则不启用。整份 editing state不进入 C API mutation，也不在同一连接内承载 Core-originated同步。
- 每个 session 使用一个 `session_id` 隔离输入连接 generation。`TEXT_UPDATE` 额外使用单调递增的 `state_revision` 校验 Flutter buffer/shadow；`COMMAND` 不携带 expected revision。
- `TEXT_UPDATE` session在 begin时由 Core自动建立唯一有限 editing buffer；`COMMAND` 不绑定 mutation buffer，只通过纯 Context查询读取文本。editing/committed/buffer都只是明确的查询来源。
- Composition的 primary provisional文本直接写入当前 `Document`并实时可见；linked editing的 secondary target在 Finish/Commit时一次性应用。
- Core 主动返回关闭或重建 HostAction 时，必须先原子结束自己的 session；接入实现只执行 host 关闭或重建，不能再次调用 `end_session`。adapter-local 读取或生命周期失败则走单独定义的主动 `end_session` 路径。
- C API 保持六个职责明确的入口，不压成一个万能接口，也不为每种 command 拆函数。
- 所有 wire 文本 offset 直接使用 `int64_t`，单位为 UTF-16 code unit；所有 range 显式携带坐标空间，删除操作显式携带文本单位。
- `CaretAffinity` 是 Core 通用 caret/layout 状态，不是 IME 特有 mutation 元数据；IME selection 只负责把平台提供的视觉侧信息带入 Core。
- 新 IME wire 不使用 presence `has_*`。严格 canonical NONE 表示 range/selection 不存在，`session_id == 0` 表示 response 不携带存活 session state。
- 本次重构一次性切换，不保留旧 IME 协议兼容层。

## 目标与非目标

### 目标

- Android 原生、Flutter、Apple、Swing、WinForms、Avalonia 和 OHOS 的相同输入事实得到相同 Core 语义。
- 候选替换、连续输入、删除、取消、完成、失焦和外部编辑具有确定的 composition 与 undo 行为。
- 一个原生回调或一个 Flutter callback归一化后的 TextUpdate batch要么整体应用，要么完全不应用；必要的 session recovery作为随后独立的原子阶段执行。
- 旧连接、旧 revision、错误 oldText 和非法 range 不能修改当前文档。
- 文本查询覆盖 Android/Flutter surrounding text、Apple 任意 range、Swing committed text 和 committed length。

“轻接入实现”的边界固定为五项机械职责：解码原生事件与flags；把原生单位、range和相对坐标换成统一UTF-16坐标；在callback接收时捕获session/generation；保留一次原生callback的batch顺序；执行Core返回的Close/Restart以及文本、几何查询。composition baseline/current ownership、Finish/Cancel/recovery、选区与composition权威状态、range映射、有限buffer、revision/oldText校验、undo/event和原子提交全部属于Core。平台确实提供的相对坐标换算不算策略；任何需要判断词、脚本、候选阶段或“用户大概想替换哪里”的逻辑都不得进入adapter。

### 非目标

- 不保留旧 C API、旧协议类型、Core snapshot mutation或 adapter snapshot diff fallback。
- 不让 Core 识别具体输入法、语言、候选算法或自动纠错策略。
- 不在第一阶段建模 composition clause、attribute 或候选高亮。
- 不新增与 composition 无关的拼写检查、语法检查或系统纠错标记模型。
- 不在本轮补齐 Flutter Web 的 DOM 输入实现。

## 术语

| 术语 | 含义 |
|---|---|
| Session | 一次原生输入连接、Flutter `TextInputConnection` 或 first-responder generation |
| Composition | 输入法仍可继续修改的一段文本，可以是新插入文本，也可以覆盖既有文档范围 |
| Baseline | composition 开始前的 raw 文档片段与完整 caret state |
| Command | 原生 API 已明确给出的输入意图 |
| Text update | Flutter delta明确给出的 editing-state 事实变化 |
| Editing buffer | Flutter host 持有并用于 TextUpdate mutation 的有限文本缓冲区 |
| Committed source | 将当前 composition 替换回 baseline 后的只读文本投影 |
| Host action | Core 要求接入实现关闭或重建输入 session 的声明式结果 |

## Core 权威状态

Core 概念状态收敛为：

```cpp
struct ImeSessionState {
  uint64_t session_id;
  std::optional<CompositionState> composition;
  std::optional<EditingBufferState> editing_buffer;
};
```

`composition == null` 表示 `Idle`，有值表示 `Composition`。`editing_buffer` 存在就表示 `TEXT_UPDATE` session，缺失就表示 `COMMAND` session；它是 Flutter 协议基础设施，不是第三种编辑阶段。`state_revision` 只保存在 `EditingBufferState` 中，因此内部状态无法表达“Command 携带 revision”“TextUpdate 没有 buffer”等非法组合。

公开的 `ImeMutationModel` 仍是 `begin_session` 的必需参数。Core 在 begin 时就据此决定是否建立 editing buffer、是否校验 oldText/revision 以及允许哪个 apply 入口，不能等到第一次 mutation 再隐式推断，也不能在同一 session 内切换；session 建立后直接从 `editing_buffer` 是否存在派生 model，不再重复保存同一个事实。

对外的 `ImeState` 是扁平 wire response：直接携带 IME 业务结果码和接入实现真正需要的状态，不再外包一层 Result：

```cpp
enum class ImeResultCode {
  OK,
  SESSION_MISMATCH,
  REJECTED,
  READ_ONLY
};

struct ImeState {
  ImeResultCode result_code;
  uint64_t session_id;
  uint64_t state_revision;
  ImeSelection selection;
  ImeOffsetRange composition_range;
};
```

`ImeState.result_code` 始终可读，但它描述 IME 子系统在产生该 response 时的结果，不属于权威 session state，也不参与 state 等价比较；普通 `EditorActionResult` 中成功读取或更新 IME 状态同样使用 `OK`，调用方本来就知道当前调用是否属于 IME API，不再用额外枚举值重复编码来源。`session_id > 0` 表示其余 state 字段有效，`session_id == 0` 表示不携带存活 state。有效 `selection` 和 `composition_range` 使用 `DOCUMENT` 坐标。`state_revision` 只供 `TEXT_UPDATE` adapter 推进 shadow；`COMMAND` adapter 不把它作为入站前提。短期 edit transaction、baseline 和 undo 不进入 wire。

### 状态不变量

- `composition_range == NONE` 表示 Idle；有效 range 表示 Composition。
- 有效 collapsed range 可以表示活跃 Composition；Windows 的 compose begin 因此可以表达。
- Flutter `TextRange.empty(-1, -1)` 表示没有 composition；普通有效 `(n, n)` 不能自动当作 Idle。
- Composition 可以覆盖既有文档范围。它仍然是普通 Composition，不需要 `DOCUMENT_RANGE`、`PREEDIT` 或 `SYSTEM_MARK` kind。
- 当前 composition文本从 `Document` 的 `current_range` 读取，不额外保存一份可能漂移的 preedit字符串。
- Selection 与 composition 独立；selection 暂时移到 composition 外不等于已经 Finish。
- Composition 不跨 session 存活。
- 所有 IME mutation 和 session 状态只在编辑器 UI 线程修改。session/revision 用于 stale 防护，不提供跨线程并发安全。

## Composition 状态与短期编辑事务

`Document` 始终保存用户当前看见并正在编辑的文本，composition 的 provisional 文本也直接写入 `Document`。不再建立持久文本视图对象、overlay document 或另一份 preedit 文本。跨 callback 存活的 `CompositionState` 只保存无法从当前 `Document` 推导的三项信息：

```cpp
struct CompositionState {
  TextRange current_range;
  U8String baseline_text_raw;
  CaretState baseline_caret;
};
```

- `current_range` 位于当前 `Document`，直接圈定当前 composition 文本；composition 文本始终从该范围读取。
- `baseline_text_raw` 是 Begin 前被替换片段的原始字节快照，保留 CR、LF、CRLF，专用于 Cancel、Finish 的净变化判断和 Undo；它不是第二份当前文本。
- `baseline_caret` 是 Begin 前的完整 `CaretState`，包含 anchor、active 与 active endpoint affinity。composition 外的合法 committed edit 会按 committed projection 重定位它。
- 当前 caret/selection 继续由 EditorCore 的普通 `CaretState` 持有，不在 `CompositionState` 中复制。
- committed baseline range不单独存储：其 start始终是 committed projection中与 `current_range.start` 对应的同一概念位置，end由该 start前进 `logicalize(baseline_text_raw)` 的逻辑形状得到。composition外的 committed edit必须同时更新 document/committed两套映射以维持这个派生不变量。

Begin 只捕获上述 baseline 并建立 `current_range`，不改文本。Update/Commit 使用一个 Core-private provisional replace 原语直接替换 `Document` 的 `current_range`，然后把插入后的实际范围设为新的 `current_range`。这个原语不能调用当前带完整副作用的 `applyEdit`：它只允许修改 `Document`、当前 caret/composition、TextUpdate buffer，并统一失效 line index、line height、visual line、layout/render等派生 cache；不能更新持久 decoration/fold、search generation、undo/redo 或公开 committed change。

因此当前文本的消费者保持简单：layout、render、hit-test、caret geometry 和普通 editing query 都在 UI线程直接读取 `Document`。持久 decoration、fold、linked target 和 search数据仍使用 committed 坐标；由 committed content-change stream或异步分析产生的入参也必须按 committed line model校验，不能拿当前 provisional行列冒充 committed坐标。line-local effect内部要先归一到 committed line start加 column range或完整 line range，才能投影到当前 `Document`。基于当前视图坐标的点击 fold、选择 search match等用户动作则先经过 resolution gate，使 editing与 committed重合后再执行。

Composition 活跃时，位于 composition前后的持久范围通过单次 replacement的纯坐标映射投到当前 `Document`，受 composition replacement影响的 effect暂时隐藏或停用。这里不能直接复用普通半开区间 `overlaps`：derived baseline range非空时按普通 overlap；baseline为空时，任何严格跨越 insertion seam的范围都视为受影响，恰好位于 seam的 start/end/anchor按该 owner的明确 bias映射。start在 seam通常移到 current range之后，end在 seam通常保留在之前，零长度 anchor必须由 effect owner声明前/后粘性，不能让 provisional插入意外落进 committed style、fold或 search match。

editing→committed caret投影也不能依赖普通 overlap。collapsed caret位于 current range内部或任一边界时映射到 baseline start；non-collapsed selection endpoint严格位于内部或等于 current start时映射到 baseline start，等于 current end时映射到 baseline end，其余按 replacement map转换。current range为空时，与该点相等的 endpoint映射到 baseline start。active endpoint被折叠到 baseline start时 affinity规范化为 `DOWNSTREAM`。`COMMITTED` Context中的 active `composition_range`固定返回 rebase后的 derived baseline range；空 baseline返回合法 collapsed range，不返回 NONE。

`DecorationManager` 中的 fold region/collapsed state是持久 committed状态；`LogicalLine::is_fold_hidden`、line index、height和 visual lines只是 editing projection的派生 cache。每次 provisional结构修改以及 Finish/Cancel后，都必须从 committed fold状态重新投影可见性并统一失效受影响 cache，不能把这些 cache当作需要回滚的持久状态。

search snapshot、snapshot cursor、pending result安装、current-match选择和 line index全部基于 committed projection；provisional Update不推进 search generation。任何非零 committed effect都推进 generation、丢弃旧 pending result并把既有结果标为 stale。公开 `SearchState.current_range` 返回映射到当前 `Document` 的范围；与 composition相交时暂时返回无 current match，内部 committed result仍保留。find-next、replace等动作先经过 resolution gate。

Finish 才按 baseline→final 净 replacement更新上述持久范围一次，Cancel不回滚持久状态。

`COMMITTED` Context 也不需要长期文本视图对象。查询时将当前 `Document` 的 `current_range` 临时替换为 `baseline_text_raw`，只合成请求的 slice、总长度和端点映射；`EDITING` Context 直接读取 `Document`。

每个原生 callback或 Flutter TextUpdate batch使用一个短生命周期 `EditTransaction` 协调解析、验证和提交。UI线程保证没有并发写入；transaction先把同一 callback中的顺序 command/step解析成一个局部 replacement plan，完成语义验证后再修改真实 `Document`，同时提交 composition/caret/buffer state、持久 committed effects、history和结果标志。它不复制或长期持有第二份 Document。

`EditTransaction` 是唯一需要的 batch 协调抽象，不再派生 `DocumentTransaction`、effect hierarchy、journal 或长期 tracker。它只维护当前 callback的规范化 replacement plan和必要的局部查询结果：

- batch 中后一条 command/step按前一步已经解析出的局部 replacement plan解释，不能直接套用 callback开始时的旧坐标。
- 最终物理 replacements 相对 transaction pre-state 规范化为有序、互不重叠的净修改。`Document`接口只增加一个批量 replacement原语；LineArray与PieceTable都先验证全部range，再按位置逆序直接调用现有replace能力修改原Document，不复制Document。
- transaction在修改Document前完成payload语义验证，并预先构造`HistoryEntry`所需数据、public changes/result payload和持久effect计划。项目不为内存分配失败复制整个Document或提供强异常回滚；验收重点是业务拒绝路径不会在验证完成前修改live state。
- physical replacement set只负责把 staging editing text写入真实 `Document`；history、持久模型调整和 public changes独立地由 transaction的 committed pre-state/post-state生成。两者不能复用同一 diff。
- 是否写 history、清 redo、发布 `content_changed`，只由 committed projection 的净 effect决定。纯 provisional Update即使物理 `Document` 已变化也没有 committed effect；Finish即使不再执行物理 replacement，只要 baseline→final非零仍有 committed effect。
- 每个 transaction的 committed changes都使用同一个 committed pre-state坐标并保存 raw old/new text；外层两个 transaction的 changes再按执行顺序聚合。
- history基础设施统一为一个 `HistoryEntry`：`redo_replacements` 保存同一 committed pre-state坐标的正向替换，`undo_replacements` 保存同一 committed post-state坐标的逆向替换，同时保存完整 `CaretState before/after`及 merge/barrier元数据。`UndoManager`不再保留 single/compound分支或 `beginGroup/endGroup`；Undo和Redo都通过同一个 Document批量 replacement原语原子应用。IME transaction只负责从 committed净变化构造这一个既有结构，不再创建第二套 history中间类型。
- rejected payload在语义验证阶段不触碰真实状态；需要Finish的recovery使用另一个`EditTransaction`。
- 整个 transaction 只执行一次 layout/render 失效和一次不可重入的结果汇总。

本阶段不建设全局 `TrackedRange`、range registry、tracker handle 或 owner/stream 订阅体系。Core 只提供无注册、无长期状态的纯位置变换函数：给定同一局部 pre-state 的 position/range、互不重叠 replacement set 和明确的端点粘性，计算新 position/range。新 reducer 不得直接复用当前把 range end 当作包含端、或固定使用单一 insertion bias 的旧 helper。

边界规则必须由 owner 明确选择：composition 的 `current_range` 由 Begin/Update/`composition_after` 直接定义；non-collapsed owner外部在 start边界的插入使 start右移，在 end边界的插入不扩入 composition。collapsed active range遇到同点 insertion时两个端点必须整体移动，归属由显式 Command语义或 TextUpdate的 `composition_after` 决定；无法唯一判断在 owner前、owner内还是 owner后时整批拒绝，不能分别变换两个端点。editing buffer则包含本 session在自身边界产生的自然增长。普通 caret由 command/step的 selection-after或对应 action语义决定。`CaretAffinity` 只描述同一逻辑 offset的视觉侧，不能复用为编辑边界粘性。

### 转换语义

| 当前状态 | 操作 | 结果 |
|---|---|---|
| Idle | Begin(range) | 捕获 baseline，进入 Composition，可以是 collapsed range |
| Idle | Update(text, target) | 以 target 或当前 selection 建立 baseline，再更新 composition |
| Composition | Update(text, target) | 替换 target所指的 composition子区间；target缺失时替换整个 current range，保持同一 `CompositionState` |
| Composition | Commit(text) | provisional 替换 current range，再结算 baseline→final 净变化，进入 Idle |
| Idle | Commit(text, target) | 对 target 或 selection 执行普通 committed edit |
| Composition | Finish | 当前 Document 文本转为 committed，按净变化决定 undo，进入 Idle |
| Composition | Cancel | 用 raw baseline 替换 current range并恢复 baseline caret，无 undo，进入 Idle |
| Idle | Finish/Cancel | 有效 no-op，不递增 revision |

Begin 只负责建立 baseline，不承担 active composition retarget。active 时新的 Begin 必须由同一个 command batch 先明确 Finish 或 Cancel。Finish 在清除 `CompositionState` 前先读取 final raw slice；若 `logicalize(final_raw)` 与 `logicalize(baseline_text_raw)` 相同，先把 `current_range` 恢复成 `baseline_text_raw`，从而保留原始行尾并形成零 committed change；否则当前 `Document` 已经是 final text，无需再次重写。Cancel 始终用 raw baseline 恢复文本。

composition reducer内部按需提供私有 `rawRangeSlice([start,end))`，不扩展Document公共接口。它通过现有行文本与`LogicalLine.line_ending`拼接请求区间，保留实际的CR、LF或CRLF字节；端点不得落在行尾字节内部。`logicalize(raw)`是唯一行尾归一算法，把CR、LF、CRLF各转换为一个`\n`；baseline比较、UTF-16长度、committed projection、history和committed changes都复用它。

### Undo 与事件

- Begin、Update 和 Cancel 不新增 undo，也不清空 redo。
- 一个成功的 `EditTransaction` 最多产生一个 `HistoryEntry`。transaction 边界不是自动的 undo merge barrier：普通连续 typing/backspace/delete 仍可按显式 coalesce policy 跨 transaction 合并；Composition Finish/Commit、mixed delete、linked batch、recovery 和 resolution 固定不可与前后 history 合并。
- Begin、Cancel 和零净变化 Finish 虽然不写 undo，也必须切断旧 typing merge chain，避免 composition 前后的输入被合成一次 Undo。
- 同一个 transaction 内的 composition 外 committed edit 与 Finish/Commit 合并成一个 `HistoryEntry`；拒绝 payload 后的 recovery 使用第二个 transaction并单独形成一条 history。accepted guard resolution 与本批 delta 保持同一 transaction。
- Composition Finish/Commit 只在 `baseline_text_raw -> final raw text` 存在净变化时贡献 committed effect；与 baseline logical text 相同会先恢复 raw baseline，因此不创建 composition undo。Idle 的 `Commit(text, target)` 仍是普通 committed replacement。
- Undo entry 保存完整 `CaretState before` 与 `CaretState after`；Undo 恢复 before，Redo 恢复 after，不能在 Redo 时清空 selection或重新推导 affinity。
- active composition 下第一次 Undo/Redo 只执行 Cancel 并消费该用户命令，history cursor 不移动。
- Begin、Cancel 和无净文本变化的 Finish 仍触发视图失效，以正确移除 composition 装饰。
- `EditorActionResult.changes/content_changed` 永远只表示 committed 文本。provisional Update、Begin 和 Cancel 只设置必要的 `composition_changed`、`selection_changed`、`needs_redraw` 以及 Core 内部 layout invalidation，不新增 provisional event channel。
- composition外 committed edit与 Finish/Commit在 transaction最终提交后发布 committed changes；Finish虽然通常不再重写 `Document`，仍要以 committed pre-state中的 baseline range和 final raw text合成净 change。physical replacement plan绝不能用于生成 undo或公开 changes，因为 active transaction的物理 pre-state本来就可能含 provisional text。仅含 provisional effect/Cancel且没有 committed净变化时，不清 redo，也不发布 content change。Cancel不能抹掉同一 transaction中其他合法 committed effect。
- 一个外层 Core API 调用即使因 resolution gate 使用两个 transaction，也只返回一个聚合的 `EditorActionResult`。`HistoryEntry` 可以保持两条，公开 changes按执行顺序聚合，observer 只在完整 action finish path 后收到一次不可重入通知。
- reducer 和 batch 提交期间不派发可重入回调；二次编辑排入后续 UI task。

### Composition 编辑所有权

`CompositionState` 只拥有当前 `Document` 中的 `current_range`；其 committed projection 是在相同起点用 `baseline_text_raw` 替换该范围后得到的概念文本，不单独保存。

- `UPDATE_COMPOSITION` provisional 替换 `current_range`，插入后的实际多行范围直接成为新 `current_range`。范围端点必须通过 Document 的 offset/position 转换得到，不能用起点列加 UTF-16 长度推导。
- composition underline/effect使用通用多行 range rendering；不能继续用 `start.column + preedit_columns` 只画一条逻辑行。
- 同 session 的 surrounding delete 可以同时命中 owned range 内外。Core 必须从同一个 pre-command state 先解析全部删除范围，再在 staging 中拆成 composition 内 provisional 片段与 composition 外 committed 片段。
- 本次删除构造两个局部 map：`document_edits` 包含内部 provisional 与外部 committed 片段，`committed_edits` 只包含投到 committed projection 的外部片段。
- 内部片段只修改 `Document/current_range`；外部片段同时修改 `Document` 与持久模型，并用 committed map 重定位 `baseline_caret`、用 document map 重定位 `current_range`、当前 caret和 editing buffer。外部删除不并入 baseline，也不被 Cancel 恢复。
- 内部删除可以让 `current_range` 缩短为 collapsed；collapsed 仍是 active Composition，不会隐式 Finish。
- 无法唯一判定所有权时整批 payload 零应用，随后按固定策略恢复，不能按文本前后缀猜测。

混合删除的 undo 与事件必须固定：

- Composition 保持活跃时，外部 committed 片段在本批最终提交时形成一个批量 `HistoryEntry`；内部 provisional 片段已经体现在 `Document`，之后 Finish 再结算 composition 净变化，Cancel 只恢复 baseline-owned 片段。
- 同一 batch 内删除后立即 Finish/Commit 时，外部 committed 片段与 composition 的 baseline-to-final 净变化合并成一条原子 history。
- 同一 batch 内删除后立即 Cancel 时，外部 committed 净变化保留并形成该 transaction 的一个 `HistoryEntry`和change-set，provisional 片段恢复为 raw baseline，最终 caret 恢复为 committed map 重定位后的 `baseline_caret`。Cancel 本身不贡献 undo；只要外部存在 committed 净变化，redo 仍只清空一次。
- Composition 保持 active 时，外部 history 的 before/after caret 分别取 committed edit 前后的 `baseline_caret`；同批 Finish/Commit 时则取 composition 的 `baseline_caret` 与最终 Idle caret。不能把 provisional caret 直接写进 committed history。
- Composition 保持 active 时，committed listener 只收到外部 committed change-set；同批 Finish/Commit 时收到一个同时包含外部片段与 composition 净变化的原子 change-set。后续 callback 才 Finish 时再单独发布 composition change-set。

### Linked editing

Composition 活跃期间只把 primary provisional text 写入 `Document`，不实时创建 secondary edit。

- Finish/Commit 先解析 composition 所属的完整 linked primary target，并读取当前 `Document` 中已经包含 provisional edit 的完整 primary target 文本；不能把 composition 子范围文本误当作 linked replacement。
- 只有 linked primary target 仍可唯一解析时，才在同一个短期 `EditTransaction` 中以 composition baseline 为基础计算并应用 primary 与所有 secondary replacement。
- Finish时还必须确认 linked session仍 active且是同一 group，baseline/current composition只属于一个 primary，所有 primary/secondary range有效且互不碰撞。active期间任何 committed外部 edit若吞入、切开或合并 linked target，立即使该 linked session失效；普通位移只用纯 range transform更新。
- Primary不能先单独提交，也不能由既有linked edit再应用一次；Finish时重新验证primary与secondary target，在同一个transaction replacement plan中完成位置变换，最后只commit一次并生成一条undo。
- Cancel 不修改 secondary target。
- active 期间不需要 hidden secondary projection、linked target lease 或 collision rebind。
- active期间 linked的实时同步和呈现可以停用，但 committed primary/secondary记录仍保留。若 baseline composition range完整包含于 primary target，则用 primary起止两端向外的 owner-specific边界规则映射完整 primary；exact-equal时直接映射为 `current_range`。只有部分交叉或 target已被 committed edit破坏时才不可唯一解析。
- Finish 前 linked session 已失效时，终止该 linked session 并退化为 primary-only Finish，保留已经接受的 IME 文本；不能丢弃输入，也不能扩展 IME wire 协议。

该规则使 `Document`、当前渲染文本与 editing buffer 保持同一内容，同时避免 secondary target 在每次候选更新时反复抖动。

## 统一的 composition resolution gate

Composition 活跃时，所有可能改变文本或 selection 的来源都先经过同一个 gate；Idle 时无需解决 composition，只执行该来源自身的普通语义：

| 来源 | 固定策略 |
|---|---|
| 同 session IME selection/update | 保持 Composition |
| IME Commit/Finish/Cancel | 按显式输入执行 |
| Escape | Cancel，消费按键，结束 session并请求 Restart；adapter按实际焦点执行 |
| Undo/Redo | Cancel，消费当前命令，结束 session并请求 Restart；adapter按实际焦点执行 |
| 普通键盘输入、导航、鼠标重新定位 | Finish后执行用户操作，结束 session并请求 Restart；adapter按实际焦点执行 |
| 失去输入焦点 | Finish 后结束 session |
| 文档整体重置 | Cancel，结束 session，再重置文档并请求 Restart；adapter按实际焦点执行 |
| 切换 read-only | Finish，结束 session，关闭可编辑 host |
| 外部程序化文档修改 | Finish后修改，结束 session并请求 Restart；adapter按实际焦点执行 |
| 同 session surrounding delete | 按所有权拆分，原子执行 |
| 同 session 带 target 的 Commit | batch 先明确 Finish/Cancel，再按 Idle replacement 执行 |

Core 决定上述语义；各接入实现不能自行选择 Finish 或 Cancel。Host 自己发来的显式 Commit/Finish/Cancel 已经同步表达了原生状态，可以保留当前 session。由 Core 主动解决 active composition 时，第一阶段不要求各 host 实现“原地 Finish/Cancel”能力：Core 先完成内部语义并结束 generation，再统一返回 Restart 或 Close。这样不需要 capability 矩阵，也不会让 Core 与仍持有旧 composition 的 host 继续共用一个 session。

Core-originated active resolution 与随后未被消费的普通 action 固定使用两个 `EditTransaction`：第一个 transaction 单独 Finish/Cancel composition并结束 session，第二个 transaction 执行普通键盘输入、导航、鼠标、reset 或程序化编辑。两次 committed 文本净变化分别形成 `HistoryEntry`；导航等没有文本变化时第二个 transaction自然不产生文本 undo。两个 transaction 之间不派发可重入 observer，完整 action finish path结束后再返回一个聚合的 `EditorActionResult`。Escape 与 active 下的 Undo/Redo 已被 Cancel gate消费，不再执行第二个 action transaction。该规则不适用于 accepted TextUpdate guard；guard 明确把整批 delta 与最终 Finish 放在同一个 transaction。

第二个 action的参数不能在第一 transaction前解析后原样复用。键盘/navigation只保留动作意图并从 resolution后的 `CaretState`重新计算；pointer/gesture保留 screen point，等待新 layout后重新 hit-test。必须接收 pre-resolution `Document` range/position的程序化 action，用第一 transaction的 committed change-set按该 action专属 endpoint bias转换；linked secondary位于 target前方时也必须计入。与第一 transaction修改相交而无法唯一转换时，只拒绝第二 action，已经完成的 resolution仍保留；绝不能把旧 line/column或 `TextPosition`直接套到新 `Document`。

## 两条入站路径

### Command

Command 表达原生 API 已经给出的意图，适用于 Android 原生、Apple、Swing、WinForms、Avalonia 和 OHOS。

```cpp
enum class ImeCommandKind {
  SET_SELECTION,
  BEGIN_COMPOSITION,
  UPDATE_COMPOSITION,
  COMMIT_TEXT,
  FINISH_COMPOSITION,
  CANCEL_COMPOSITION,
  DELETE_SURROUNDING
};

struct ImeCommand {
  ImeCommandKind kind;
  ImeOffsetRange target_range;
  ImeSelection selection_after;
  U8String text;
  int64_t delete_before;
  int64_t delete_after;
  ImeTextUnit text_unit;
};

struct ImeCommandBatch {
  uint64_t session_id;
  std::vector<ImeCommand> commands;
};
```

`ImeCommand` 使用 `kind + 固定 payload 字段` 适配当前协议生成器，但解码后必须立即把 canonical NONE 转换成内部 optional 并构造类型安全 variant。每个 kind 只允许读取对应字段，并由类型安全 factory 构造。

Collapsed target 和 selection 都合法；缺失由严格 canonical NONE 表示，不能把 `(n, n)` 当作缺失。Command 不携带 expected revision；原生 callback 已经表达本次意图，generation 隔离由 `session_id` 完成。各 kind 的字段约束固定为：

| Kind | Target | Selection-after | Text | Delete fields |
|---|---|---|---|---|
| `SET_SELECTION` | 禁止 | 必需 | 禁止 | 禁止 |
| `BEGIN_COMPOSITION` | 必需 | 可选 | 禁止 | 禁止 |
| `UPDATE_COMPOSITION` | Idle 时可选 `DOCUMENT`，active 时可选 `COMPOSITION` | 可选 | 必需，允许空文本 | 禁止 |
| `COMMIT_TEXT` | Idle 时可选，active 时禁止 | 可选 | 必需，允许空文本 | 禁止 |
| `FINISH_COMPOSITION` | 禁止 | 禁止 | 禁止 | 禁止 |
| `CANCEL_COMPOSITION` | 禁止 | 禁止 | 禁止 | 禁止 |
| `DELETE_SURROUNDING` | 禁止 | 禁止 | 禁止 | before/after/unit 必需 |

`target_range == NONE` 或 `selection_after == NONE` 表示对应 optional 字段未提供；必需位置收到 NONE、禁止位置收到有效值都返回 `REJECTED`。Idle 下 Update/Commit 的 target NONE 固定使用 command pre-state 的当前 selection。active Update 的 target NONE替换整个 current composition；有效 target使用 `COMPOSITION` 坐标替换其子区间，替换后仍属于同一个 `CompositionState` 和原 baseline，新的 `current_range` 覆盖结果 composition全文。Composition 下 Commit 的 target 必须为 NONE并替换 current composition；需要替换其他 document range时，同一 batch先 Finish/Cancel，再以 Idle `COMMIT_TEXT(target,text)` 执行。Begin 的 selection-after NONE保留 command pre-state 的完整 selection；Update/Commit 的 selection-after NONE把 selection折叠到 replacement末尾。active subrange Update的 selection-after如使用 `COMPOSITION`，必须相对替换后的完整 composition；adapter只执行原生坐标到该坐标的机械换算。`delete_before/delete_after` 必须非负。所有未被当前 kind 使用的字段必须使用跨语言一致的 canonical wire 值并在 reducer 前验证：target/selection 使用各自 NONE，`text=""`，`delete_before=delete_after=0`，`text_unit=UTF16_CODE_UNIT`。不能依赖某个生成语言的 enum 零值推导“默认值”。

不定义 `MOVE_SELECTION`：原生 move/select-by-movement、实体方向键和菜单导航都是普通编辑器 action，统一经过 resolution gate并由现有 layout/navigation实现。不定义 `REPLACE_TEXT`：Idle 的 `COMMIT_TEXT(target,text,selection_after)` 已能表达任意 range replacement；active 下需要 finish-then-replace 的平台 API 发送原子 `FINISH_COMPOSITION + COMMIT_TEXT(target,text)`。

接入实现必须先把 Android `newCursorPosition`、Apple marked selection 等平台相对规则转换为普通 `ImeSelection`。Core 不实现平台专属位置算法。

整个 command batch 先在 staging state 中验证和执行，再一次性提交。后一条 command 的 range 相对前一条完成后的 staging state。`commands` 必须非空；空 batch 返回 `REJECTED` 并按 current-generation recovery 处理，具体诊断只进入 Core trace。原生 caret-null 等真正 no-op 由 adapter 直接不调用 apply，不能用空 batch 表示。

### Flutter TextUpdate

Flutter delta 保留 oldText、patch、selection-after 和 composition-after，不先翻译成 Command：

```cpp
struct ImeTextUpdateBatch {
  uint64_t session_id;
  uint64_t expected_state_revision;
  std::vector<ImeTextUpdateStep> steps;
};

struct ImeTextUpdateStep {
  U8String old_text;
  ImeOffsetRange patch_range;
  U8String replacement_text;
  ImeSelection selection_after;
  ImeOffsetRange composition_after;
};
```

不再单独定义 `ImeTextPatch`。`patch_range == NONE` 唯一表示 NonText delta，与 Flutter 原始 delta 中 `deltaStart == deltaEnd == -1` 的编码一致；有效 collapsed range 仍表示真实 insertion patch。

处理规则：

- 一次 `updateEditingValueWithDeltas(List<TextEditingDelta>)` 只调用一次 Core。
- batch 必须非空，而且 TextUpdate session 在 begin 时必须已经建立唯一 editing buffer。
- 第一步 `old_text` 必须逐字等于 `expected_state_revision` 下 editing buffer 的当前完整文本。
- 后续每一步 `old_text` 必须逐字等于前一步 staging after-text。
- `patch_range` 有效时必须使用 `EDITING_BUFFER` 坐标并相对本 step 的 `old_text`；`selection_after` 始终使用 `EDITING_BUFFER`，`composition_after` 有效时也使用 `EDITING_BUFFER`，二者都相对应用 patch 后的完整 after-text。NonText step 的 after-text 就是 oldText。
- `patch_range == NONE` 时 `replacement_text` 必须为空；`composition_after == NONE` 表示 after-state 没有 composition。NONE 必须逐字段匹配 canonical sentinel，不能在无效 range/selection 的其他字段中携带隐藏语义。
- 所有 step 全部通过后才提交文档、selection、composition、undo、revision 和 action result。
- 任一步失败时整个 batch payload 零应用；随后是否恢复 session 由统一 recovery 表决定。
- reducer 完成所有 step、linked editing 和坐标映射后，必须把 Core 最终 editing-buffer state 与规范化后的 host 最后一项 after-state逐字段比较。完全一致才保留 session并把它作为 Dart shadow；linked secondary replacement或其他 Core 语义使二者不一致时，本批输入仍成功提交，但在同一 transaction 中 Finish 最终 Composition、结束 generation并返回 Restart/Close，Dart 不得把 host after-state保存成新权威 shadow。
- 正常 accepted delta 不调用 `setEditingState` 回灌 host。
- Core API不接收 `updateEditingValue(snapshot)`；任何已启用的新 Flutter路径收到 text-changing snapshot都视为协议异常，不能在 Dart边界把两份字符串 diff成伪 TextUpdate step。
- `selection_after` 是必需字段。有效 selection 两端都非负；`selection_after == NONE` 表示 host 没有 selection，Core 必须整批零应用并恢复，不能沿用旧 selection 继续编辑。

TextUpdate 的 composition 转换为：

| before | after | Core 语义 |
|---|---|---|
| Idle | Idle | 普通 committed patch |
| Idle | Composition | 由 patch 前后映射建立 baseline，再 Begin/Update |
| Composition | Idle | 应用最终 patch 并 Finish；final 等于 baseline 时自然形成零 undo |
| Composition A | 同一 ownership A' | 更新当前 `CompositionState` |
| Composition A | 新 ownership B | 只有 patch 与 before/after range 几何关系能唯一拆分时才原子 Finish A、Begin B |

Idle→Composition 或 rollover 建立新 `CompositionState` 时，baseline 必须来自 patch 的 preimage，而不是直接把 after range `B` 当成原生文本：

- text patch 创建/替换 composing text 时，在应用 patch 前从其 preimage 对应的当前 `Document` range 读取 `baseline_text_raw` 与 `baseline_caret`；应用 patch 后，`B` 对应的 document range成为 `current_range`。纯插入因此得到空 baseline，Cancel 会删除插入的 provisional text。
- NonText step 只把既有文档范围标成 composing 时，直接读取 `B` 对应的 raw document片段作为 baseline，并把同一范围设为 `current_range`。
- 只要 patch preimage 与 `B` 无法形成唯一 owner，就拒绝；不能仅用 after range 或字符串公共前后缀反推 baseline。

active-to-active 不能只看 after range，也不能先用固定边界 stickiness 把 patch 机械分成“`A` 内/外”。对旧 composition `A`、本 step patch pre-range `P`、replacement after-span `I` 和新 composition `B`，Core 从 step pre-state 计算 patch 后保留的旧 owned span，再按以下顺序匹配；命中前一条后不再落入后续分类：

- `P == A` 且 `B == I` 时固定为同一 owner 的整段 replacement，即使旧 owned span 已全部消失；这条最高优先级特例不能再判成 rollover。
- `P` 完整位于 `A` 内，或 `P` 是 `A` 起止边界的 collapsed insertion，且 `B` 恰好覆盖变换后保留的旧 owned span与 `I`、没有吞入无关文本时，`I` 属于原 owner，owner 内 preimage只产生 provisional Document edit并直接定义新的 `current_range`。
- `P` 没有改写 `A` 内部、`B == I` 且 `I` 与保留的旧 owned span不相交时，原子 Finish `A` 再建立新 owner；本条明确排除 `P == A`。新 owner 复用 Idle→Composition 的 preimage规则：在 staging pre-state 捕获 `P` 的 raw preimage，inserted span成为新 `current_range`，不能先当作独立 committed edit结算。
- `P` 完整位于 `A` 外，或只是 `A` 边界的 collapsed insertion，且 `B` 恰好等于变换后保留的旧 owner并排除 `I` 时，patch 是 composition 外 committed edit，复用 document/committed 双 map、undo 与 event规则。非 collapsed 的外部 replacement若被 `B` 吸收到旧 owner中必须拒绝；当前 `CompositionState` 不扩张 baseline去吞入外部 committed fragment。
- `P` 横跨 `A` 内外时，第一阶段只接受 replacement 为空、`B` 恰好等于删除后保留 owner且可唯一切分的纯删除，并与 mixed `DELETE_SURROUNDING` 使用同一双 map。`B` 只决定 inserted text ownership；删除 preimage仍必须拆成 owner 内 provisional 与 owner 外 committed 片段。带非空 replacement 的跨边界 patch 整批拒绝并 Restart。
- NonText step 没有 patch时，`B == A` 是同 owner state；`A` 与 `B` 不相交是 Finish `A` + Begin document-backed `B`；部分重叠仍拒绝。
- 其余部分重叠、跨 ownership 边界、吞入无关文本或无法唯一还原的情况全部零应用并恢复。

因此，collapsed insertion 由 `B` 决定 inserted span ownership；replacement 为空时允许按 `P` 切分 provisional/committed 删除；`P` 非 collapsed且 replacement 非空时，删除 preimage与 inserted span必须属于同一 ownership，否则整批拒绝。第一阶段不把一次 replacement 拆成“删除 provisional、插入 committed”或相反的复合语义。

边界插入正是必须先看 ownership 的场景。例如旧 `[ab]` 在末端插入 `c` 后，after range `[abc]` 表示 `c` 被原 owner 吸收；`ab[c]` 表示先完成 `ab`，再以该 insertion 的 preimage 为 collapsed baseline 建立新 owner；如果 after 仍是 `[ab]c`，则 `c` 是 composition 外 committed text。这里的方括号表示 composition 范围，不能根据字符串公共前后缀猜测。

after 进入 Idle 且本 step 同时含外部 committed effect 时，外部 effect 与 composition Finish 在同一个 `EditTransaction` 中形成一个原子 history/change-set；after 仍 active 时，外部 effect本批结算，`current_range` 继续存活。

## 坐标、选区与文本单位

### 文本源与坐标

```cpp
enum class ImeTextSource {
  EDITING,
  COMMITTED,
  EDITING_BUFFER
};

enum class ImeCoordinateSpace {
  DOCUMENT,
  EDITING_BUFFER,
  CONTEXT_SLICE,
  COMPOSITION
};

struct ImeOffsetRange {
  ImeCoordinateSpace coordinate_space {ImeCoordinateSpace::DOCUMENT};
  int64_t start_utf16 {-1};
  int64_t end_utf16 {-1};
};

enum class CaretAffinity {
  DOWNSTREAM,
  UPSTREAM
};

struct ImeSelection {
  ImeCoordinateSpace coordinate_space {ImeCoordinateSpace::DOCUMENT};
  int64_t anchor_utf16 {-1};
  int64_t active_utf16 {-1};
  CaretAffinity affinity {CaretAffinity::DOWNSTREAM};
};
```

Range 和 selection 分离，因为 selection 必须保留 anchor/active 方向以及 active endpoint 的 caret affinity。anchor/active 本身已经完整表达方向，不再保留 `is_directional`。

`CaretAffinity` 是 Core 通用 caret/layout 状态。同一逻辑 offset位于软换行边界时，`UPSTREAM` 表示上一视觉行末尾，`DOWNSTREAM` 表示下一视觉行开头；本轮只验收软换行，不提前承诺完整 bidi。它必须进入 `CaretState`：状态收敛为始终有效的 anchor、active与 `active_affinity`，cursor和 `hasSelection()` 从中派生。两个既有hit-test入口直接返回`CaretHit { position, affinity }`，不额外保留只返回position的兼容入口。caret geometry、左右/上下移动、渲染、composition baseline、Undo/Redo和state equality都消费affinity；端点不变而affinity变化仍是caret state change。

affinity始终描述active endpoint的视觉侧，不参与offset变换、ownership或编辑边界粘性。Flutter和UIKit collapsed affinity可以机械映射；Flutter non-collapsed selection按active位置确定，UIKit/AppKit只有ordered range时在endpoint集合未变时保留Core方向，否则规范化为较小端到较大端；Swing只在 `TextHitInfo` 结合Core visual-line resolution后可唯一解释时保真。其他无affinity来源统一使用 `DOWNSTREAM`。水平移动可以先在同一offset切换视觉侧，纵向移动的preferred-x只保存在Core内部。

endpoint经普通平移映射时保留affinity；按composition专用caret规则折叠到baseline起点时规范化为 `DOWNSTREAM`。affinity-only变化只产生对应caret/selection change与redraw，不产生content change；Flutter明确的affinity-only echo no-op仍由adapter机械过滤。

Wire 只定义一种缺失表示。下文在 range/selection 语境中的 `NONE` 是规范符号化简称，与 `ImeHostAction::NONE` 无关；它不新增 enum、字段或跨语言静态常量，各生成语言的默认构造结果就是对应 NONE：

- `ImeOffsetRange` NONE 是严格的 `DOCUMENT + (-1,-1)`。
- `ImeSelection` NONE 是严格的 `DOCUMENT + (-1,-1) + DOWNSTREAM`。
- 默认构造必须逐字段生成上述 NONE；协议注解不能依赖某个目标语言对嵌套 aggregate 或 enum 的隐式默认值。
- 解码后先三分：严格 NONE 转内部 `optional.none`；两个端点均非负的值进入坐标和边界校验；混合负值、任一端 `< -1`，或带非 canonical 附属字段的伪 NONE 都返回 `REJECTED`。负数不能进入 reducer，具体 canonical 错误只进入 Core trace。
- 默认值只用于构造，不能用于容错解码。未知 coordinate space、affinity 或其他 enum raw value 必须由 codec 拒绝或原样交给业务校验，绝不能静默回退成 `DOCUMENT`/`DOWNSTREAM` 后绕过 canonical 检查。

规则：

- 所有 offset 是解码后逻辑文本的 UTF-16 code unit，不是 UTF-8 byte offset。
- 所有 range 统一使用半开区间 `[start_utf16, end_utf16)`；collapsed range满足两端相等，两个范围仅端点相接不算重叠。
- `ImeTextSource` 只选择查询文本源；`ImeCoordinateSpace` 只说明 range 的原点，二者不能混用。
- `EDITING` 直接读取包含当前 primary composition 的 `Document`；`COMMITTED` 按需将 `current_range` 投回 raw baseline；`EDITING_BUFFER` 读取 TextUpdate session 的有限 buffer。
- `DOCUMENT` 表示当前 `Document` 的绝对坐标。
- `EDITING_BUFFER` 只相对 TextUpdate session 的唯一持久 buffer，用于 TextUpdate mutation。
- `CONTEXT_SLICE` 只相对某个 `ImeTextContext.text`；具体文本源由发起该同步 `get_context` 调用时使用的 `source` 决定。任何 mutation 携带它都返回 `REJECTED`。
- `COMPOSITION` 相对当前 primary composition。
- `BEGIN_COMPOSITION`、Idle `UPDATE_COMPOSITION` 与 Idle `COMMIT_TEXT` 的有效 target使用 `DOCUMENT`；active `UPDATE_COMPOSITION` 的有效 target使用 `COMPOSITION` 相对 command pre-state 的 current range，其他 active command不允许 target。selection-after可使用 `DOCUMENT`；`SET_SELECTION` 在 active时还可用 `COMPOSITION` 相对当前 range，`BEGIN_COMPOSITION`相对该 command后的 range，`UPDATE_COMPOSITION`相对替换后的完整 composition，active `COMMIT_TEXT`相对 final replacement span解析后再进入 Idle。Idle或 Finish/Cancel不允许 `COMPOSITION`。TextUpdate的必需 selection以及有效 patch/composition range必须使用 `EDITING_BUFFER`；不存在字段使用 canonical NONE。
- 对外 `ImeState` 始终返回 `DOCUMENT`；`ImeTextContext` 的有效 range/selection 始终返回 `CONTEXT_SLICE`。接入实现不能把一次查询结果原样当作后续 mutation range 回传。
- 普通 range 必须已正规化且不能越界或切开 surrogate pair；Core 不静默 clamp。
- 原生 API 明确规定 swap/clamp 时，由接入实现先严格按原生规则归一化。
- selection 允许 anchor 大于 active。
- 有效 `ImeOffsetRange` 两端必须非负且 `start <= end`；有效 `ImeSelection` 两端必须非负但允许 anchor 大于 active。之后仍须校验 coordinate space、editing-buffer/context-slice/document 边界与 surrogate 完整性。
- Command optional target/selection 使用 NONE 表示未提供；必需字段收到 NONE、禁止字段收到有效值均为 `REJECTED`。
- TextUpdate 的 `selection_after` 是必需事实，收到 NONE 时必须整批零应用并恢复，不能沿用旧 caret；`patch_range == NONE` 表示 NonText step，`composition_after == NONE` 表示 after-state 为 Idle。
- 有效 session 的 `ImeState.selection` 永远有效；`composition_range == NONE` 表示 Idle。Context slice 无法完整表示 selection/composition 时返回对应 NONE。无 state 或 error response 的 inactive 字段也统一返回 NONE，不再使用 `(0,0)` dummy。
- 所有 offset、length 和 delete count 在 wire 中直接使用 `int64_t`，各接入实现先校验非负、边界、surrogate 完整性、Core 容器范围以及目标语言可精确表示范围，再转换成容器索引；不增加 `using ImeOffset = ...` 之类别名。ArkTS `number` 还要求值不超过 `2^53 - 1`，因此跨端契约不宣称可用完整 Int64 正数域。
- logical CR、LF、CRLF 在查询文本中统一为一个 `\n` offset；`baseline_text_raw` 与 history 保存原始行尾，以便 Cancel/Undo 精确恢复，range 本身不额外携带行尾数据。

### 删除单位

```cpp
enum class ImeTextUnit {
  UTF16_CODE_UNIT,
  UNICODE_CODE_POINT
};
```

- Android `deleteSurroundingText` 使用 `UTF16_CODE_UNIT`。
- Android `deleteSurroundingTextInCodePoints` 使用 `UNICODE_CODE_POINT`。
- IME wire 只保留已有平台契约明确要求的两种单位。实体 Backspace/Delete、Swing/WinForms 的物理按键和编辑器自身删除不发送 `DELETE_SURROUNDING`，而是走现有 Core action并按 grapheme cluster执行用户感知删除。
- OHOS/Avalonia 的 callback 单位必须先由真实 trace确认；若将来确实报告 grapheme count，再扩展 wire，不能提前用一个枚举值掩盖未知语义。
- `DELETE_SURROUNDING` 的 before/after 是 selection 两侧的长度，不包含 selection 本身；非空 selection 保留，并在两侧删除后映射到新坐标。
- Core 必须从同一个 pre-command state 解析 before range 与 after range，再作为一次原子范围删除提交。不能先删除一侧、观察中间状态后计算另一侧，也不能循环调用普通 Backspace/Delete。
- 每个单位保持精确语义：code-unit/code-point 删除不能为了用户感知效果向外扩成完整 grapheme。比如 `e + U+0301` 删除一个 code point 只删除组合标记，ZWJ emoji 删除一个 code point 也不等于删除整个 grapheme。
- 超过文档边界时按该命令定义裁剪；UTF-16 边界切开 surrogate pair 或结果形成无效 Unicode 时，整条 command payload 零应用并按固定策略恢复，不能静默扩到完整 grapheme。

## Session、revision 与文本上下文

### Session 配置

```cpp
enum class ImeMutationModel {
  COMMAND,
  TEXT_UPDATE
};
```

不建立 `SessionConfig`、capability flags 或 stateful-window mode。`begin_session` 只接收 mutation model；model 已经完整决定该 generation 的协议形态：

- mutation model 固定 session 的入站协议：`COMMAND` 只允许 `apply_commands`，`TEXT_UPDATE` 只允许 `apply_text_updates`。
- `TEXT_UPDATE` 在 begin 时自动创建唯一 editing buffer，并启用 oldText 与 revision 校验。
- `COMMAND` 不创建 editing buffer，也不要求 expected revision；需要文本时使用纯 Context 查询。
- 调错 apply 入口返回 `REJECTED`：payload 在 reducer 前零应用，并执行当前 generation 的固定 recovery；“model mismatch”只进入 Core trace。Core 不通过 payload 外形自动切换 model。
- mutation model 不进入对外 `ImeState`，整个 generation 内也不会改变。
- `session_id` 从 `1` 开始，在同一 EditorCore 生命周期内不复用，`0` 专用于表示response不携带存活session state。虽然 Core 字段是 `uint64_t`，跨语言 wire 的共同精确正整数域受 ArkTS `number` 限制，因此有效值固定为 `1..2^53-1`。最后一个 id 已使用后，下一次 `begin_session` 固定返回 `REJECTED` 且不创建 session；adapter关闭输入，若还要继续只能重建 EditorCore。不能回绕或复用旧 generation，内部 trace记录 counter exhaustion而不新增极低频专用 result code。

### Revision

`state_revision` 只属于 `TEXT_UPDATE` 的 Core buffer 与 Flutter shadow 同步协议。`COMMAND` session 的对外 revision 固定为 `0`，Command batch 不携带它。

TextUpdate begin 创建 editing buffer 后把 revision 初始化为 `1`。下列变化成功提交时整批只递增一次，不按 step 逐次递增：

- editing buffer 文本、selection endpoints 或 composition range 改变。
- Begin、Finish、Cancel 或 rollover 改变 composition baseline/ownership。

文本和 selection endpoints 最终相同但 composition baseline 已改变时仍递增。Flutter affinity-only NonText delta按 framework 的 echo 过滤语义规范化为 no-op，不覆盖 Core affinity，也不递增 revision。纯查询、被拒 payload、真正无副作用的 no-op 以及 editing buffer 外且不影响其坐标或内容的文档变化不递增。任何需要 Core 主动改变 Flutter editing state 的动作都结束旧 session并 Restart，不通过递增 revision 伪造同连接同步屏障。

revision 同样限制在 `1..2^53-1` 且不回绕。若一个完整验证成功的 batch 本应把 revision 增加到上界之外，Core 仍在原 batch `EditTransaction` 中应用全部 delta并 Finish 最终 active Composition，然后结束 session，返回 `ime_state.result_code == OK` 与 Restart（read-only 时 Close），且 `ime_state.session_id == 0`；新 generation 从 revision `1` 开始。合法输入不能因计数器轮换而丢失，也不能把溢出值写入 wire。

`ImeTextUpdateBatch` 必须携带 `session_id + expected_state_revision`；`ImeCommandBatch` 只携带 `session_id`。`get_state/get_context` 只需要目标 `session_id`；`end_session` 不要求 revision，避免 host 无法关闭 stale session。

Flutter callback已经位于 Dart UI isolate，TextUpdate adapter必须在 callback返回前同步调用 Core一次并推进 shadow/revision，不允许另建异步 mutation队列。Command adapter如需跨线程 marshal，则在接收 callback时至少捕获 session id，并在真正执行时使用捕获值，不能读取“当前 id”替换，否则旧任务会伪装成新请求。

### 唯一 editing buffer

Flutter 的 `TextEditingValue.text` 必须有限，不能把大文档整体复制给 engine。这个 buffer 是 TextUpdate session 的内部基础设施，不是可以由 host 重绑的 token，也不是第三份编辑器权威状态：

- `begin_session(TEXT_UPDATE)` 以当前 selection 为中心创建 buffer，完整包含 selection；常规目标是在两侧各提供 `1024` 个可用 surrounding UTF-16 code units，再各保留 `256` 个 guard。边界向外对齐到完整 Unicode scalar。
- buffer hard cap 固定为 `65536` 个 UTF-16 code units。创建时可以为完整 selection临时扩大常规窗口，但 selection 加两侧实际需要的 guard超过 hard cap时，不截断或伪造 selection：Core 以 `REJECTED` 拒绝 begin，保持 editor state不变，并在内部 trace记录 hard-cap原因。
- 超大 selection下，Flutter桌面端由 SweetEditor收到的实体键盘、Ctrl+A、Home/End、方向键、Backspace/Delete和快捷键仍走普通 Core action，不依赖 `TextInput`窗口；SweetEditor自己的移动端手势与菜单也走 Core，并在需要时先折叠或缩小 selection再建立 TextUpdate session。第一阶段不实现 virtual selection。
- 这不能拦截 stock Flutter embedding在原生 `InputConnection`/`UITextInput` 内部直接实现的系统全选、剪切、复制、粘贴等动作。Dart通常只看到事后的局部 selection/delta，copy甚至没有 delta，既无法恢复“全篇”意图，也无法撤回原生剪贴板副作用。因此有限 buffer下，这些原生系统动作明确只有窗口局部语义，不承诺全文正确；产品必须优先提供 SweetEditor自己的全局菜单/快捷键，并把系统 toolbar/IME同名动作列为已知限制。若未来要求它们具有全文语义，只能改变 host/engine接入或放弃有限 buffer，Core不能靠猜测补齐。
- `EditingBufferState` 保存当前 Document range、两侧 guard阈值和 TextUpdate专属 revision；selection在 `CaretState`，composition在 `CompositionState`。materialized text如为 oldText校验而缓存，只能在每次 `EditTransaction` 提交时原子刷新，不能成为第二份可独立修改的权威文本。
- Dart 只保存 Core 返回的一个规范化 `TextEditingValue` shadow以及 session id/revision，不保存 document start，不保留 raw/canonical两份 selection，也不能主动请求换区。
- buffer range不进入全局 tracker。每个 accepted batch用同一纯位置变换更新其起止与 guard；本 session 在边界产生的 insertion属于 buffer自然增长，确保 Core buffer与 Flutter shadow逐字一致。
- active composition期间不原地更换 buffer identity。入站 patch、selection或 composition越出 buffer是非法 payload；触及仍有隐藏文档一侧的 guard，或 post-step buffer长度超过 hard cap，则是“本批接受后换 generation”的信号。
- reducer 先 staging完整 delta list。每个 step在 pre-step buffer检查 patch pre-range，在 post-step buffer检查 selection、composition与 replacement after-span；命中 guard只设置 sticky restart flag，不能提前提交、Finish或忽略后续 step。
- 所有 step accepted后，若 sticky flag已设置，在同一个 `EditTransaction` 中提交整批 delta、Finish最终仍 active的 Composition并结束旧 session，返回 `RESTART_SESSION` 语义请求；read-only语义返回 `CLOSE_SESSION`，实际焦点由 adapter执行时判断。任一后续 step失败仍使整个 payload零应用，不能因为前项已触 guard而接受前缀。
- 单个 accepted delta可以让 materialized buffer短暂超过 hard cap，因为该 payload本身已经由 host送达；本批完成后必须按 guard路径结束 generation。新 session再围绕最终 caret创建正常大小窗口。
- Core-originated selection变化无论是否仍在 buffer内，都不在同一 Flutter connection调用 `setEditingState`：按 resolution gate结束旧 generation并 Restart/Close，防止迟到 NonText delta用相同 oldText回滚状态。

有限窗口有明确边界：Flutter delta只描述 host在已知 buffer内实际做出的变化，无法表达被隐藏上下文截断的原始意图。Core 接受这个具体 after-state并在触 guard后换区，但绝不把 `[0, buffer.length]` 猜成全选文档，也不猜测边界删除本来还想跨出多少字符。SweetEditor可控的全局编辑语义必须由自己的键盘、手势或菜单路径承担；不可控的原生系统动作按上一条明确降级。这是一项显式的有限 TextInput 契约，而不是完整文档 host的行为等价声明。

### Context 查询

`get_context` 始终是纯查询，不绑定、扩张或更换 editing buffer，也不递增 revision。它使用 `ImeTextSource + start_utf16 + length_utf16`；`length_utf16 == -1` 统一表示直到所选文本源末尾，非负 length表示有限 slice：

```cpp
struct ImeTextContext {
  ImeResultCode result_code;
  int64_t slice_start_utf16;
  int64_t total_length_utf16;
  U8String text;
  ImeSelection selection;
  ImeOffsetRange composition_range;
};
```

`session_id`、`source` 与 `state_revision` 不在 response 中回显：`get_context` 是同一 UI线程上的同步调用，adapter必须已经持有请求所属的 session binding、本次请求的 source以及 TextUpdate begin返回的 revision；调用期间没有并发 Document mutation，重复返回这些值不会形成新的 generation或快照保障。Command查询也不再携带恒为 `0` 的冗余 revision。

- TextUpdate 初始化唯一使用 `get_context(EDITING_BUFFER, 0, -1)` 读取完整 session buffer；其他 session或其他参数使用 `EDITING_BUFFER` 都返回 `REJECTED`。
- `EDITING` 直接读取当前 `Document`；`COMMITTED` 按需把 current composition替换回 raw baseline。两者的 start是各自完整文本源的绝对 UTF-16 offset。
- Command 和 TextUpdate session都可以查询任意 `EDITING`/`COMMITTED` slice，不会改变 mutation origin。
- `total_length_utf16` 是整个所选文本源的长度，不是返回 slice长度；`EDITING_BUFFER` 下就是 buffer长度。
- `slice_start_utf16` 是返回 slice在所选文本源中的实际起点；`EDITING_BUFFER` 完整查询固定为 `0`。
- 完整 editing-buffer context 始终返回有效 selection；active composition必须返回有效 range，Idle时返回 composition NONE。`EDITING`/`EDITING_BUFFER`返回 current range，`COMMITTED`返回 derived baseline range；空 baseline在 committed source中仍是合法 collapsed range。
- 任意只读 slice 无法完整表示 selection/composition 时，对应字段返回 NONE。
- Apple/Swing 的任意范围查询直接使用 start/length生成所需 slice，不拉取整个文档。
- Committed projection中的 caret/selection endpoint严格按前述 collapsed、内部、start/end边界规则映射；折叠到 baseline起点的 active endpoint affinity规范化为 `DOWNSTREAM`，其他 endpoint通过 replacement map转换，不能直接复用 editing offset。
- start必须非负，length只能是 `-1` 或非负；有限长度用 checked arithmetic验证 `start + length`，end超过文本末尾时裁到末尾。`start == total_length` 可返回空 slice，完全越过末端才返回 `REJECTED`。
- Core的 UTF-8 query不能表示半个 surrogate。请求 start切开 surrogate pair时提高到下一个 scalar边界，end切开时降低到上一个 scalar边界，保证返回内容不超出请求范围；若调整后 start大于 end，则返回位于调整后 start的空 slice。`slice_start_utf16` 和实际 text长度必须报告真实结果。原生 API若允许按 Java/NSString UTF-16 index精确切到 surrogate内部，adapter可先把查询范围向两侧各扩一个 code unit，再将 Core返回的完整 scalar转成本地 UTF-16并裁回原范围；若同时消费 Context中的 selection/composition，裁剪后必须重基到新 slice，无法完整表示时置 NONE。mutation range仍严格拒绝，不能套用 query裁剪规则。

`get_state` 保留。Win32 cursor-only消息、Android镜像/通知、OHOS async host同步以及迟到 callback校验都需要一个不复制文本的权威状态读取；不能强迫这些场景都调用 `get_context`。

## 结果与 host action

### 单一结果码

Wire 只保留前文 `ImeState` 中定义的一套 `ImeResultCode`。`ImeState` 与 `ImeTextContext` 都直接携带它，不生成 `ImeStateResult`、`ImeContextResult` 或通用 envelope。

- `OK` 同时覆盖普通 `EditorActionResult` 中成功取得的 IME状态、成功 mutation和有效 no-op；调用方本来就知道当前调用来源，是否变化由 revision与普通 action flags表达。
- `SESSION_MISMATCH` 表示请求 id没有指向调用时的 current session；无 current session与已经存在更新 session对接入实现都是同一种 stale防护结果。两种诊断细节只进入 Core内部 trace，不增加 wire分支。
- `REJECTED` 表示当前 generation 的请求无法安全接受，统一覆盖 revision/oldText不匹配、非法字段/range/Unicode、错误状态转换、错误 apply入口和无法唯一映射。平台不根据原因选择恢复策略，只执行 Core返回的 host action。
- `READ_ONLY` 只用于 begin时明确表达不可建立可编辑 session；它是平台真正需要区分的业务状态。
- 详细的 revision、oldText、range、transition和ownership原因只进入 Core内部 trace和测试，不生成跨平台 `ImeResultReason`，也不让平台层分支处理。

### Host action

```cpp
enum class ImeHostAction {
  NONE,
  CLOSE_SESSION,
  RESTART_SESSION
};
```

固定不变量：

- 一次结果至多要求一个 host action，因此它是普通 enum，不是 flags，也不建立组合合法性矩阵。
- 普通 selection、surrounding text、caret rectangle通知由既有 `EditorActionResult` change flags与当前 `ImeState` 机械驱动，不再重复定义 IME专用 host action。TextUpdate也不提供同 session的 state-sync action；任何 Core-originated Flutter state变化都结束旧 session并请求 Restart，read-only语义时 Close，焦点由 adapter判断。
- Close/Restart 返回时 Core session 已经结束，`ime_state.session_id == 0`。
- `RESTART_SESSION` 是“旧 generation 必须替换、条件允许时建立新 generation”的语义请求，不是 Core 对平台焦点的判断。Core 不读取 adapter-local focus；adapter 执行时重新检查 focus、read-only、binding generation和当前是否已有更新 session，不满足就只 Close。`CLOSE_SESSION` 表示语义上必须保持关闭，例如进入 read-only。
- stale old session callback 不携带任何 host action，不能影响当前新 session。
- accepted mutation或普通action保留session时返回 `OK + NONE + 当前ImeState`，有效no-op也一样；adapter只从返回state推进revision，并只按既有change flags通知原生host。TextUpdate的Core-originated state change不保留connection，而是Restart/Close。
- Host 自己已经发出的 Commit/Finish/Cancel 不需要回声 action；Core 主动解决 Composition 时直接结束 session 并返回 Close/Restart，所以 wire 不再生成 `FINISH_COMPOSITION`、`CANCEL_COMPOSITION` host flags。

普通 `EditorActionResult` 的 IME 字段组合固定为：

| 场景 | `ime_state.result_code` | `ime_host_action` | `ime_state.session_id` |
|---|---|---|---|
| 当前没有 session | `OK` | `NONE` | `0` |
| 普通 action 后保留 session | `OK` | `NONE` | `> 0`，返回最新 state |
| 普通 action 导致 session 关闭或重建 | `OK` | `CLOSE_SESSION` 或 `RESTART_SESSION` | `0` |
| IME mutation 成功并保留 session | `OK` | `NONE` | `> 0`，返回最新 state |
| `apply_*` 成功但 Core 内部结束 session | `OK` | `CLOSE_SESSION` 或 `RESTART_SESSION` | `0` |
| `end_session` 成功 | `OK` | `NONE` | `0` |
| 旧/不存在 session 的 IME 请求 | `SESSION_MISMATCH` | `NONE` | `0` |
| 当前 generation 的 IME error并恢复 | `REJECTED` | `CLOSE_SESSION` 或 `RESTART_SESSION` | `0` |

第二行包括保留 Command session 的普通编辑，也包括没有改变 TextUpdate editing state 的真正 no-op；普通 action 只要改变 TextUpdate 的 text、selection 或 composition，就不能留在同一 connection，必须走第三行。结果码不重复编码“是否来自 IME API”，调用入口已经完整表达来源。

表外组合全部非法：存活state只允许 `OK + NONE + session_id > 0`；error或Close/Restart必须使用session id `0`。除普通action本来没有session或成功 `end_session` 外，`apply_*` 不能返回 `OK + NONE + 0`，否则host connection会悬空。

Mutation 和 `end_session` 继续返回统一 `EditorActionResult`，直接加入：

```cpp
ImeHostAction ime_host_action;
ImeState ime_state;
```

`session_id == 0` 只表示本response不携带存活state，不证明Core没有其他session，也不能单独驱动binding清理。此时revision为 `0`、selection/composition为NONE，`result_code` 仍有效；begin冲突、非法query和session mismatch都可能在其他session继续存活时返回这种state。adapter只依据调用契约与HostAction改变生命周期：成功end清理调用方主动结束的binding，apply内部结束执行Close/Restart，`SESSION_MISMATCH + NONE` 只丢弃。

所有普通 EditorCore action的统一 finish path都必须检查 current IME session：Composition活跃时执行 resolution gate，TextUpdate state被 Core主动改变时结束并生成 Restart/Close语义结果，最后填充上述 IME字段；程序化编辑不能绕过这一出口。平台焦点不属于 Core权威状态。

`begin_session`/`get_state` 直接返回 `ImeState`，`get_context` 直接返回 `ImeTextContext`。错误context固定为零长度空text和NONE selection/composition；请求session、source和TextUpdate revision由同步调用方持有。调用入口与HostAction已经区分无session、成功end和restart，不需要 `has_ime_state`、`has_value` 或result wrapper。

### Recovery 与 Restart 边界

`RESTART_SESSION` 只用于当前 generation无法安全继续，或Core主动改变了host仍可能认为活跃的editing state。正常候选提交、纯查询、普通revision、未触及guard的buffer自然增长和linked target本身都不触发Restart；linked secondary只有实际造成最终buffer与host after-state分歧时才换generation。

恢复路径固定如下，不再建立 capability 策略矩阵：

| 来源 | Core 处理 |
|---|---|
| 请求 id没有指向调用时的 current session | 返回 `SESSION_MISMATCH`，不处理任何 composition，不返回 host action；“当前为空”与“已有更新 session”只写内部 trace |
| 当前 generation 的revision/oldText、range、Unicode、transition、ownership、model或其他payload错误 | payload零应用；active时用独立recovery transaction Finish最后已接受的composition；结束session并请求Restart，read-only语义时Close |
| Core-originated active resolution | 用独立resolution transaction Finish/Cancel并结束session，再以第二个transaction执行未消费的用户动作；请求Restart，read-only语义时Close |
| Idle TextUpdate session 中的 Core-originated editing-state change | 在本次普通 action transaction中原子应用动作并结束旧 session；请求 Restart，read-only时 Close；它不是 desync，也没有 composition recovery transaction |
| accepted TextUpdate 触发 guard、revision 上界或 final-state divergence，需要新的 buffer/generation | 全量验证整个 batch；在同一个 `EditTransaction` 中提交全部 delta并 Finish 最终 active Composition；结束 session并请求 Restart，read-only 时 Close，不在原 session rebind |
| 正常失焦或 host 主动连接关闭 | Finish 后结束，不重建，也不要求 host 再执行 Close |

“payload零应用”不禁止随后独立recovery transaction提交先前已经接受的composition。切换read-only、文档整体reset、Escape和Undo/Redo属于正常resolution gate，不伪装成recovery错误。Close/Restart返回时Core已经结束session，adapter不能二次end。

Restart必须在原生callback栈返回后执行，并以经过证明的native identity或old-generation drain作为屏障，不能把一个microtask当成屏障。异步任务捕获旧session/focus generation；执行时只有仍聚焦、仍可编辑、没有更新session且begin成功才可attach。无法证明屏障的目标只允许安全Close，并保持未启用状态；具体目标约束只在“各接入实现映射”表定义一次。

Host 主动结束，或者 adapter 已知当前 native generation无法继续时，统一调用 `end_session(handle, session_id)`。该入口始终以 Finish语义原子保留最后一次已接受的 current composition，然后结束 session；正常失焦、连接关闭、native读取失败和无法判定的生命周期终止都不需要额外结束枚举。明确用户取消已经由 `CANCEL_COMPOSITION` command或 Core resolution gate表达；如果同一个主线程native回调还要求关闭连接，adapter先同步提交Cancel，再调用end即可。只有end返回 `OK` 且原focus/restart token仍匹配时，adapter才执行Close或自行请求重建。这条路径不新增 `ImeSessionEndAction` 或 `report_desync` C API，诊断来源和重建意图留在接入实现，不进入wire reason。

## C API

C API 固定为六个入口：

```text
editor_ime_begin_session
editor_ime_end_session
editor_ime_apply_commands
editor_ime_apply_text_updates
editor_ime_get_state
editor_ime_get_context
```

职责如下：

- `begin_session(handle, mutation_model)`：创建新 generation；TextUpdate 同时建立 editing buffer，直接返回扁平 `ImeState`。
- `end_session(handle, session_id)`：以 Finish语义处理 host主动结束或adapter主动终止当前 native generation，返回 `EditorActionResult`。
- `apply_commands(handle, batch)`：原子处理 `ImeCommandBatch`。
- `apply_text_updates(handle, batch)`：原子处理 Flutter delta batch。
- `get_state(handle, session_id)`：无副作用读取权威状态。
- `get_context(handle, session_id, source, start, length)`：以 `int64_t` start/length纯读取指定文本源；`length == -1` 表示直到末尾，TextUpdate用 `(EDITING_BUFFER, 0, -1)` 读取完整 session buffer。

read-only 时 begin返回 `READ_ONLY` 且不创建 session。TextUpdate begin时当前 selection无法在 hard cap内完整表示、begin时已有尚未结束的 session，或 apply入口与session mutation model不匹配，都返回 `REJECTED`；具体原因进入Core trace。begin冲突不能借机结束或恢复已经存在的session。请求id没有指向current session时返回 `SESSION_MISMATCH`，绝不能关闭或读取可能存在的当前新session。Core不得尝试把一种payload翻译成另一种协议。

请求成功完成 wire结构解码后，业务校验优先级固定为：先检查 `session_id` 是否指向 current session，再检查 apply入口与派生的mutation model，最后才检查payload或query字段。于是“mismatched id + 非法range”永远返回 `SESSION_MISMATCH` 且不触发当前generation recovery，“当前id + 错误model + malformed payload”返回 `REJECTED`并按model-mismatch原因恢复。`begin_session` 没有目标id，仍先检查read-only与既有session；结构解码失败和分配错误不进入这套业务优先级。枚举必须在结构解码时保留raw整数，不能在此之前静默回退或丢失值。

apply 进入 payload 层后也按固定顺序只报告第一个错误：

1. batch级结构与数量，例如空 `commands/steps`；
2. TextUpdate `expected_state_revision`；
3. command/step的未知enum raw value、canonical NONE、unused fields与字段组合；未知raw值不能先映射成默认枚举，也不能作为transport error绕过当前generation recovery；
4. TextUpdate `old_text` 首项及链式一致性；
5. coordinate space、range、selection、文本单位、UTF/Unicode 与 checked arithmetic；
6. reducer状态转换与ownership映射。

上述任一失败对外都返回 `REJECTED`，但内部trace只记录固定顺序中遇到的第一个原因。同一payload同时包含多种错误时不得跳序扫描，因此“revision mismatch + 非法range”记录revision原因，“合法revision + 非法range + ownership歧义”记录range原因。query在session/id检查后直接校验自身字段，返回 `REJECTED`但不触发mutation recovery。

response取值遵循前述唯一矩阵；query的 `REJECTED` 不触发recovery或HostAction。TextUpdate启动顺序固定为begin、读取完整 `EDITING_BUFFER` 建立Dart shadow、Flutter attach、`setEditingState(shadow)`、show；Core/query失败或同步本地异常时end刚建立的Core session并关闭局部connection，异步native失败交给后续lifecycle/callback恢复。

无效editor handle、payload结构解码失败和内存分配失败继续使用项目统一transport error，不伪装成IME业务结果。所有batch和结果仍由C++ `SE_PROTOCOL_*` 注解以及 `tools/se_protocol_gen` 生成，各接入实现不维护独立wire schema。入站C++ codec必须保留enum raw value，由统一canonical校验在session/model优先级之后返回 `REJECTED`；出站response的Java、Swift、Dart、ArkTS codec遇到未知enum raw value必须严格失败。任何方向都不能静默回退到默认枚举。该规则需要在协议生成器或其统一codec入口实现，不能只靠IME reducer约定。

### Public wire 类型清单

第一阶段只保留以下16个本轮相关public wire类型：8个有限枚举和8个扁平数据struct，不是16个运行时状态对象；其中 `CaretAffinity` 是Core通用caret类型，其余属于IME协议。

Enums：

- `ImeMutationModel`
- `ImeTextSource`
- `ImeCoordinateSpace`
- `CaretAffinity`
- `ImeTextUnit`
- `ImeCommandKind`
- `ImeResultCode`
- `ImeHostAction`

Structs：

- `ImeOffsetRange`
- `ImeSelection`
- `ImeCommand`
- `ImeCommandBatch`
- `ImeTextUpdateStep`
- `ImeTextUpdateBatch`
- `ImeState`
- `ImeTextContext`

`ImeState` 与 `ImeTextContext` 本身就是扁平 response，不另算 result wrapper。`EditorActionResult` 只增加 `ime_state` 与 `ime_host_action`；上述 struct不包含任何 presence `has_*`。

字段必要性固定如下，实施时不能再为“可能以后使用”增加预留字段：

| Struct | 保留字段与唯一职责 |
|---|---|
| `ImeOffsetRange` | `coordinate_space` 防止不同原点误用；`start_utf16/end_utf16` 同时表达普通、collapsed与canonical NONE range |
| `ImeSelection` | `coordinate_space` 声明原点；`anchor_utf16/active_utf16` 保留方向；`affinity` 表达active endpoint在同一逻辑offset的视觉侧 |
| `ImeCommand` | `kind` 选择内部variant；`target_range/selection_after/text` 服务各文本与selection命令；`delete_before/delete_after/text_unit` 精确表达surrounding delete。固定payload由协议生成器约束，unused字段必须canonical，不拆成更多wire variant |
| `ImeCommandBatch` | `session_id` 固定generation；`commands` 保留同一原生callback内的顺序意图并整体原子提交 |
| `ImeTextUpdateStep` | `old_text` 校验逐step链；`patch_range/replacement_text` 保留patch身份；`selection_after/composition_after` 是host明确给出的after-state |
| `ImeTextUpdateBatch` | `session_id` 隔离generation；`expected_state_revision` 拦截文本未变但selection/composition已陈旧的callback；`steps` 保留一次Flutter delta list的原子边界 |
| `ImeState` | `result_code` 是唯一业务结果；`session_id` 表示是否携带存活state；`state_revision` 同步TextUpdate shadow；`selection/composition_range` 返回Core权威编辑状态 |
| `ImeTextContext` | `result_code` 是唯一业务结果；`slice_start_utf16/total_length_utf16/text` 表达有限文本切片；`selection/composition_range` 提供同一切片坐标下的完整可表示状态。`session_id/source/state_revision` 已由同步调用方持有，明确不进入response |

8个enum各有独立协议维度：mutation模型、查询文本源、坐标原点、caret视觉侧、删除单位、命令variant、业务结果和host生命周期动作。它们不能互相合并；结束session固定使用Finish语义，不再为其生成enum，也不增加通用flags或reason enum。

Core内部的 `ImeSessionState`、`CompositionState`、`EditingBufferState`、短期 `EditTransaction` 和纯位置变换函数不属于生成协议，因此不计入这16个public wire类型；现有 `CaretState` 增加affinity state也不产生新的wire struct。

不再生成旧草案中的token/lease、window/config/capability、result wrapper/reason、script/mark、snapshot mutation、presentation预留类型或presence bool。缺失range/selection统一使用canonical NONE，缺失存活state使用session id `0`；实现时不得重新引入同义包装。

## 各接入实现映射

`CLOSE_SESSION`/`RESTART_SESSION` 返回时 Core generation 已经结束。所有 adapter都先把本地 callback路由固定到旧 session id，再执行原生动作；Restart只能在可证明的 generation边界后创建新 Core session。各接入实现约束如下：

| 接入实现 | Close | Restart 与旧 callback 隔离 |
|---|---|---|
| Android | 使当前 `InputConnection` generation 失效；是否隐藏键盘由焦点/read-only 生命周期决定 | 调用 `restartInput(view)`；只在系统创建新 `InputConnection` 时 begin，旧 connection 调用继续携带旧 id |
| Flutter Android | close 当前 `TextInputConnection`，cleanup callback不再 end Core | callback返回后异步close并重新校验；新 `InputConnectionAdaptor` 捕获client id，只有系统建立新 `InputConnection` 后才begin/取buffer/attach/set initial state/show |
| Flutter iOS | close当前 `TextInputConnection`，cleanup callback不再end Core | SweetEditor当前 `TextInputConfiguration` 不启用autofill，3.41.6的 `setClient` 会创建新的 `FlutterTextInputView` 并把旧view client id清零；callback返回后异步重连，以新view identity隔离旧generation |
| Flutter macOS | close当前 `TextInputConnection`，cleanup callback不再end Core | plugin复用当前client/model；只有独立input-context identity或discard/deactivate后的真实drain trace通过后才启用Restart。此前Close只作为异常清理，该目标不能标记为完整启用 |
| Flutter Windows | close当前 `TextInputConnection`，cleanup callback不再end Core | plugin复用当前client id/active model，同一窗口的迟到IME消息可能读取新binding；只有重建独立native identity或消息排空trace通过后才启用Restart。此前Close只作为异常清理，该目标不能标记为完整启用 |
| Flutter Linux | close 当前 `TextInputConnection`，cleanup callback不再 end Core | Flutter 3.41.6 的 clear/set client只改共享 handler id，不 reset `GtkIMContext`；同 microtask重连还会跳过 deferred hide/focus-out，旧 native preedit可伪装成新 client。修复delta并实现、实测原生reset/focus-out barrier前保持禁用 |
| iOS / UIKit | 结束当前 first-responder generation | 同一 `UITextInput` 对象内部换 helper不能隔离迟到 callback；第一阶段只 Close。只有建立独立 responder/proxy或实测证明 resign后的旧 callback已排空，才启用异步 Restart；`reloadInputViews()` 不是屏障 |
| macOS / AppKit | 结束当前 first-responder/input-context generation | 第一阶段只 Close。只有实测证明 discard/deactivate后的旧 callback已排空，才先 begin/bind新 id，再 activate新 input context |
| Swing | 结束当前 active-client/InputContext generation | 第一阶段只 Close。`endComposition/removeNotify/dispose` 加一个 EDT task不能证明旧事件排空；完成真实 trace后才允许重建 |
| WinForms | 结束当前 focused `HWND/HIMC` generation | 第一阶段只 Close。同一 HWND消息没有 generation id；只有重建 HWND或真实队列 trace证明旧消息排空后才允许 Restart |
| Avalonia | 停用并丢弃当前 `TextInputMethodClient` | 第一阶段只 Close。`ResetRequested` 没有 acknowledgment，而且 control上的 `TextInput` callback不属于 client generation；真实 backend barrier被证明前不能 Restart |
| OHOS | 用原闭包注销 callback并等待旧 detach Promise完成 | detach完成且旧 generation仍匹配后，才 begin并创建捕获新 id的闭包；attach前注册 preview callback，attach完成后复核 generation并注册其余 callback |

只有通过表中barrier验收的目标才算正确启用Restart。Restart先begin Core并创建捕获新id的binding，再执行可能同步产生callback的native activate/attach；native建立失败、generation过期或callback注册失败时必须Finish/end新Core session并清理局部native状态。host-originated close才调用 `end_session`；Core HostAction引发的cleanup不得二次end。所有异步完成和失败都校验捕获的generation，`SESSION_MISMATCH` 只丢弃，不能影响当前连接。

### Android

- 每个 `InputConnection` generation 对应一个 `COMMAND` session；surrounding text 通过纯 Context 查询获得，不为 Command 绑定 editing buffer。
- mutation model 属于 session，不属于操作系统：Android 原生接入固定使用 `COMMAND`，Flutter Android 是另一套 `TextInputClient` 接入并固定使用 `TEXT_UPDATE`，二者不会进入同一个 session。
- Android 原生所有受支持的 `InputConnection` 协议级文本 mutation 都归一为 Command，禁止调用 `apply_text_updates`。现有“先让 `BaseInputConnection` 修改本地 `Editable`，再发送 snapshot”的路径在迁移时删除，不能因某个 callback 用 snapshot 实现更方便就切换 model。
- Command-only 的含义是本 session 的 IME apply 入口只有 `apply_commands`，不是把 `sendKeyEvent`、`performContextMenuAction` 或 `performEditorAction` 等普通编辑器动作伪装成 `ImeCommand`；这些方法可以进入现有 EditorCore action，但同样不能发送 TextUpdate/snapshot，并必须经过统一 composition resolution 与 action finish path。
- adapter 为满足 Android API 保留的持久 `Editable` 只能是 Core state 的只读镜像，不能成为第二份权威 mutation buffer，也不能对它调用会预先改变文本、selection 或 composing span 的 `super.xxx()`。若需要复用 Android 的 cursor/composing 位置算法，只能在从同一次 Core state/context 构造的一次性副本上计算并立即丢弃；mutation 无论成功还是失败，都从 Core 返回的同一次 state/context 重建持久镜像。所有 query 在 batch edit 内也直接读取 Core，不能读取可能滞后的镜像。
- `InputConnection.closeConnection()`、可编辑焦点失效或 view dispose 时 Finish/end 当前 session；若系统在旧 connection 尚未 close 时请求新的 connection，先 Finish/end 旧 generation，再 begin 新 generation。
- `setComposingText` 映射为 `UPDATE_COMPOSITION`，接入实现将 `newCursorPosition` 转成 selection-after。
- Android selection API 只提供逻辑 offset，不提供视觉 affinity；构造 collapsed selection-after 时使用 Core 默认 `DOWNSTREAM`，不能从光标矩形或换行文本猜测。
- `setComposingText`、`setComposingRegion` 和 `commitText` 的 `TextAttribute` overload 与基础 overload 使用相同文本语义；第一阶段忽略样式 metadata，不能因此改走另一条 mutation 路径。
- `setComposingRegion` 先按 Android 契约交换反向端点并裁剪到当前文本边界。非零范围在 active 时发送原子的 `FINISH_COMPOSITION + BEGIN_COMPOSITION`，即使范围相同也重建 baseline；Idle 时只发送 Begin。
- 零长度 `setComposingRegion` 只 Finish。
- `commitText`、`finishComposingText`、`setSelection` 和两种 surrounding delete 使用明确 command。
- API 34 `replaceText` 先把 target 和 `newCursorPosition` 换算为 `DOCUMENT` target 与 selection-after。Idle 时发送一个 `COMMIT_TEXT(target,text)`；active 时按 Android 的 finish-then-replace 契约，在同一个原子 Command batch发送 `FINISH_COMPOSITION + COMMIT_TEXT(target,text)`。
- `deleteSurroundingText` 映射为 `DELETE_SURROUNDING + UTF16_CODE_UNIT`，`deleteSurroundingTextInCodePoints` 映射为 `DELETE_SURROUNDING + UNICODE_CODE_POINT`。
- 两种 surrounding API 都不删除 selection。Core 从调用前同一个 selection/document 状态计算 selection start 之前与 selection end 之后的两个范围，保留选中文本，并一次性原子删除两侧。
- surrounding API 必须保持精确 code-unit/code-point 语义，不能循环调用普通 Backspace/Delete，也不能把组合字符或 ZWJ 序列扩成完整 grapheme。
- `KEYCODE_DEL`、forward-delete key 和编辑器自身的 Backspace/Delete不伪装成 surrounding API；它们继续进入普通编辑器按键路径，由 Core按 grapheme cluster执行用户感知删除，并在 selection非空时删除 selection。adapter必须确保同一个物理按键不会既走普通 action又被后续 composition callback重复删除。
- SweetEditor未向 IME调用 `displayCompletions` 时，`commitCompletion` 固定返回 `false`；未来若建立 completion发布链路，再按对应 completion的 `commitText` 语义映射。`commitCorrection` 只是输入法告知编辑器“某处发生了 correction”的通知/高亮契约，不得替换文本；第一阶段直接返回 `false`。
- `commitContent` 和未知 private command 默认返回不支持，不能写入本地 `Editable` 或退化为 snapshot。普通手写识别最终仍通过 `setComposingText`/`commitText`，已经由 Command 覆盖；API 34 handwriting edit gesture 是独立可选能力，未实现时不在 `EditorInfo` 中声明，perform 回报 unsupported、preview 返回 `false`。未来实现时由 Android adapter hit-test 后调用已有 Core selection/delete/replace action，不新增 IME wire 类型，也不能退化为 TextUpdate snapshot。
- `getTextBeforeCursor/getTextAfterCursor/getSelectedText/getSurroundingText/getCursorCapsMode/takeSnapshot` 从一次权威 Context/State快照读取；`EditorInfo.initialSelStart/End` 与 initial surrounding text也必须来自同一次快照。before/after查询最多返回请求的 UTF-16 units；adapter在 Core向请求内收缩后的结果上继续遵守 Android上限。`getCursorCapsMode` 按这份 Java UTF-16 context计算。
- `getExtractedText` 的普通调用是查询，带 `GET_EXTRACTED_TEXT_MONITOR` 时还建立 adapter-local订阅；Core文本/选区变化后在最外层 batch外合并调用 `updateExtractedText`。`requestCursorUpdates` 同样是订阅协议，必须处理 IMMEDIATE、MONITOR和 filter；`requestTextBoundsInfo` 是纯几何查询。它们都不改变 mutation model。
- `beginBatchEdit/endBatchEdit` 维护嵌套计数。每个 mutation 仍立即进入 Core，使同一 batch 内随后的 query 看见最新权威状态；selection/cursor/extracted-text 通知、render flush 和其他可见 host callback 延迟到最外层 `endBatchEdit` 后合并发送。`closeConnection` 清空 batch 深度并丢弃尚未发送的旧 generation 通知。
- Core-originated selection change若保留 Command session，由既有 selection-changed flag与返回的 `ImeState` 调用 `InputMethodManager.updateSelection`，同时传递 composing start/end；host action enum不重复表达它。每个 `InputConnection` 实例固定捕获创建时的 session id，`restartInput(view)` 后只能由系统新调用 `onCreateInputConnection` 才 begin新 session。
- API返回值区分 closed/stale、accepted no-op与 unsupported，但不能用“文本是否真的变化”决定协议成功；例如 API 34 `replaceText` 的合法 no-op仍按 Android契约返回成功。
- 不再识别拉丁词、候选窗口或 `enabled` 之类文本内容。

### Flutter

- Android、iOS、macOS、Windows 和 Linux 全部继续使用 Flutter `TextInputClient`，不要求 Android 原生 host。
- 五个目标在协议设计上都使用 `TEXT_UPDATE` session与同一个 Core reducer。Android、iOS、macOS、Windows启用 Flutter delta transport；Linux只有在 engine修复或项目回补正确 delta后才启用同一路径，3.41.6原实现不启用新 IME mutation。
- 一次 delta list形成一个 `ImeTextUpdateBatch`，不能逐 step调用 Core；`updateEditingValueWithDeltas` 在 Dart UI isolate同步调用 Core一次并在返回后推进 shadow/revision，不能把多批 callback异步入队时都捕获同一个 revision。
- Dart只保存 session id、revision和一个规范化 `TextEditingValue` shadow，不保存 token、document start、system mark或 raw/canonical两份 selection。
- Dart将 `TextSelection.baseOffset/extentOffset` 映射到 anchor/active；collapsed selection机械映射真实 `TextAffinity`，non-collapsed按 active endpoint位置生成前述确定 affinity。`isDirectional` 不进入 wire。
- 正常 accepted delta只推进 Core revision与 Dart shadow，不调用 `setEditingState`。
- attached期间 `currentTextEditingValue` getter始终非空、无副作用并逐字段等于当前 shadow。Flutter 3.41.6只有 Android engine会在同一 connection发送 `requestExistingInputState`，framework随后重发 `setClient + getter shadow + setEditingState`；这是一条 Android限定的受控 reseed，不 Finish、不 end session、不更换 revision，也不触发额外 Restart。其他目标不得假定存在或支持同 session reseed。
- 完整 snapshot只用于新 connection初始化，以及上一条 Android限定 reseed；已启用 delta路径收到 text-changing `updateEditingValue(snapshot)` 是协议异常。snapshot common-prefix/suffix diff不保留 patch身份：例如旧文本 `aa` 删除第一个 `a` 后仍为 `a`，公共前后缀无法判断被删的是哪一个。它会破坏 baseline、undo、linked和持久范围所有权，因此任何目标都不得用 snapshot diff作为 mutation fallback。
- host主动触发 `connectionClosed()` 时，先调用 Flutter connection的 `connectionClosedReceived()`，再 Finish/end该 connection绑定的 Core session并 unfocus，与 Flutter `EditableText` 生命周期保持一致。Core主动 Close/Restart引发的 callback只清理旧 connection，不能二次 `end_session` 或 unfocus。
- Restart能力严格遵循前述接入表：Android与当前无autofill的iOS已有新native identity；macOS/Windows必须补独立identity或drain证明；Linux还必须修复delta和native reset屏障。所有排队工作继续使用接收时捕获的旧session id/revision。
- `performSelector`、文本/选区 action、实体键盘和自定义菜单走普通 Core action与 resolution gate；未支持的 content insertion、private command、floating cursor和 Scribble明确返回 unsupported/no-op，不能绕到 snapshot mutation。
- Flutter Web 留待未来 DOM composition/beforeinput 设计。

Core/wire 可以表示 collapsed active composition，但 Flutter 五端不都能保真上报。Flutter Linux 3.41.6 只在 composing range 非 collapsed 时序列化 composing，collapsed 会变成 `(-1,-1)`，而 `preedit-start` 本身不产生 delta。Dart adapter 只能按收到的 sentinel 映射为 Idle，不能凭空补 Begin；Linux empty-preedit、首次 nonempty preedit 与后续 commit/cancel 的真实事件序列必须单独验收，文档不能承诺该端保留 collapsed active。

Flutter 3.41.6存在以下必须绕开的 engine事实：

- Windows 读取 composing extent 时错误地再次读取 base，并且 `SetText` 会先清除 composing 状态。
- Linux 同样先 `SetText`，随后调用要求 composing 已活跃的 `SetComposingRange`。
- Linux `delete-surrounding` 的 delta路径还错误地用删除后的 composition range作 patch range，并把完整 after-text作 replacement，可能把 `Flutter -> Flutr` 编成在 offset 0插入 `Flutr`；所以 Linux 3.41.6不能启用新路径，必须先修复/回补 engine并通过 trace，不能退化成 snapshot diff。

除新连接初始化和Flutter Android 3.41.6的 `requestExistingInputState`原样reseed外，不在现有connection调用 `setEditingState`。该调用没有acknowledgment，oldText与revision也不能阻止同client的迟到NonText delta回滚selection/composition，因此不能把同连接同步包装成可靠状态机。Core-originated editing-state变化统一结束旧session并请求Restart；adapter失焦或read-only时只Close。各目标只有通过前表的identity/drain和真实IME trace后才启用，Close-only只是异常清理。

### Apple

- 每次 first-responder generation 对应一个 Command session。
- UIKit `setMarkedText(_:selectedRange:)` 没有 replacement range：active 时替换当前 marked text，Idle 时替换 selection/在 caret 插入。AppKit 的 `setMarkedText(..., replacementRange:)` 与 `insertText(..., replacementRange:)` 才需要额外 target 归一化。
- AppKit官方契约已经明确：`setMarkedText` 的 `replacementRange` 从当前marked text起点计算，`selectedRange` 从本次插入字符串起点计算；`insertText` 的 `replacementRange` 才是receiver text storage中的document范围。两者不能使用同一套target归一化。
- AppKit active `setMarkedText` 的 `NSNotFound` 映射为无target的 `UPDATE_COMPOSITION`，替换整个current composition；有效replacement range映射为 `COMPOSITION` target并替换其子区间，越界或切开surrogate时整批 `REJECTED`。如果当前没有marked text，按照官方契约替换当前selection并建立composition，不把replacement range猜成document target。
- AppKit `setMarkedText` 的selected range必须落在本次插入字符串内；adapter把它加上composition-relative replacement起点，机械转换为替换后完整composition内的 `COMPOSITION` selection-after，与text和target同批提交。Core负责保留原baseline、更新整个current range并原子处理partial replacement，adapter不维护第二套composition状态。
- AppKit `insertText` 的有效replacement range先转换为 `DOCUMENT`。active且目标不是current composition时，原子发送 `FINISH_COMPOSITION + COMMIT_TEXT(target,text)`；`NSNotFound` 或目标就是current composition时直接按当前owner Commit。UIKit没有该AppKit partial-marked-range分支。
- UIKit collapsed selection把 `selectionAffinity`映射为 Core caret affinity。non-collapsed `selectedTextRange`无法提供 anchor/active方向：endpoint集合未变时保留现有 Core方向与 affinity，否则规范化为 anchor=start、active=end、affinity=`UPSTREAM`，不能宣称机械 round-trip。AppKit `NSTextInputClient` 的 `selectedRange` 不携带 affinity；入站 setter同样在集合未变时保留，否则使用上述确定规范，不能伪造 `NSTextView.selectionAffinity`。
- `insertText` 映射为 `COMMIT_TEXT`；`unmarkText` 只映射 `FINISH_COMPOSITION`，不能重复插入 marked text，也不能当成 Cancel。
- UIKit `replace(_:withText:)`、`selectedTextRange` setter与 `deleteBackward` 必须实现；AppKit `doCommand(by:)` 进入普通 Core action。普通删除按 grapheme，普通 navigation/pointer relocation统一经过 resolution gate。
- UIKit `text(in:)`、selected/marked range与 AppKit attributed substring都描述当前 text storage，必须查询 `EDITING`；adapter不能任意选择 `COMMITTED`。
- `firstRect`、`caretRect`、`closestPosition`、`characterRange`、AppKit `firstRect(...actualRange:)` 与 `characterIndex` 必须按调用方请求的 editing position/range查询 layout/hit-test，不能总返回当前 caret。
- 用户点击 marked range外是普通 pointer relocation：Core gate先 Finish再定位，不能由 Apple adapter猜成 Cancel。
- `inputDelegate` 的 text/selection will/did通知只用于 Core-originated外部变化；will必须在 Core mutation前发送，did在 mutation和状态更新后发送，并且始终成对。若执行前只能知道“可能变化”，就保守地用一对通知包住整个 action，不能先发 will再因结果 no-op省略 did。系统刚发起并已由同一 `UITextInput` callback应用的 mutation不能再回声通知。
- UIKit `setMarkedText(nil, selectedRange:)`、active marked状态下 `replace(_:withText:)` 是否保留composition仍需真实 `UITextView` 对照trace；AppKit replacementRange坐标契约不再列为未知，但仍要用 `NSTextView` 覆盖整段、合法子区间、collapsed子区间、越界和 `NSNotFound` 事件序列，验证实现没有换错坐标空间。
- 本地 marked state 只是 Core state 的镜像，不能独立决定 Finish/Cancel。
- resign first responder、input client detach或 view dispose时 Finish/end当前 generation；重新成为 first responder必须 begin新 session。Restart是否启用由前述barrier表决定。

### Swing

- 每次获得可编辑输入焦点并激活新的 `InputContext` 连接时 begin Command session；失焦/连接移除时 Finish/end，重新激活不能复用旧 session id。
- 一个 `InputMethodEvent` 的 committed text、composed text、caret change和 `visiblePosition` 组成一个原子处理单元；visible position通过现有 ensure-visible/scroll action执行，不新增 IME command kind。
- `INPUT_METHOD_TEXT_CHANGED` 的 iterator 按 `committedCharacterCount` 拆成 committed prefix 与 composed suffix：有 prefix 时先 Commit 旧 composition，有 suffix 时在同一 batch Begin/Update 新 composition，不能逐段刷新视图。
- text iterator 为 `null` 或长度为零的 text-changed 事件不能直接忽略。active 时它表示原生回报的整段 uncommitted text 已被空文本替换，映射为 `COMMIT_TEXT("")`；不能从空文本猜成 Finish 或 Cancel。Idle 时它是有效 no-op。
- text-changed事件产生新的 composed suffix但 `getCaret() == null` 时，selection-after固定为 `COMPOSITION(0,0)`，即 composition起点；这与 JDK参考 `JTextComponent` active client一致，不能偶然落入 Command Update的默认末尾。
- caret-only 事件只有 `getCaret() != null` 时才进入 Core selection 更新，并先从 composed-relative offset 转为 `DOCUMENT`；`getCaret() == null` 表示没有新的 caret 建议，是 no-op。无 text 的 text-changed 事件按 Java 契约也不应带 caret/visiblePosition。
- `TextHitInfo` 的 leading/trailing edge 在能够结合 Core visual-line 唯一映射软换行视觉侧时转换为 `CaretAffinity`；只取 insertion index 会丢失该信息。无法保真的事件使用 Core 默认值，不能依据字符内容猜测。
- `getCommittedText(begin, end)` 使用 `COMMITTED` slice，并严格按 Java UTF-16 iterator index返回。adapter将原 `[begin,end)` 向两侧最多各扩一个 UTF-16 code unit后查询完整 scalar，转成 Java UTF-16再裁回原范围；不能直接返回 Core向内收缩的 slice。
- `getCommittedTextLength()` 使用 `total_length_utf16`。
- `getInsertPositionOffset()` 使用 committed projection；当前 caret位于 composition内部、任一边界或 collapsed owner点时都映射到 baseline start。
- `getTextLocation(TextHitInfo offset)` 必须查询参数指定的 composition-relative offset，不能总返回当前 caret。
- `getLocationOffset(x,y)` 对 current composition区域做 hit-test并返回 composition-relative `TextHitInfo`，区域外返回 `null`；`getSelectedText()` 查询 `COMMITTED` selection。
- `cancelLatestCommittedText()` 只有在明确记录了最近一次可撤回的 IME commit时才实现；第一阶段固定返回 `null`，不能猜普通 Undo history。
- 物理 Backspace/Delete走普通 Core grapheme action，不能再发送 `DELETE_SURROUNDING`，并必须避免与随后 `InputMethodEvent` 双重处理。

### WinForms

- focused `HWND/HIMC` 组合定义一个 Command session generation；窗口失焦、句柄重建或输入上下文重建都 Finish/end 旧 generation，首个 IME message 到达前 session 必须已经存在。
- `WM_IME_STARTCOMPOSITION` 以当前完整 selection 为 target 执行 Begin；selection 可能 collapsed，也可能是待替换的非空范围，不能固定成 collapsed baseline。
- 一个 `WM_IME_COMPOSITION` 的 result text、下一段 composition 和 caret 组成一个原子 batch。
- collapsed compose begin 通过显式 `BEGIN_COMPOSITION` 表达。
- `CS_INSERTCHAR` 与 `CS_NOMOVECARET` 必须在 termination判断前识别。只有 `CS_INSERTCHAR` 而没有 full-string flag时，前者才按 `wParam` 把一个 composition character插入当前 preedit并发送 Begin/Update；与 `GCS_COMPSTR`/`GCS_RESULTSTR` 同现时，以 full string为权威并忽略 `wParam` 字符，避免重复插入。`CS_NOMOVECARET` 要求 selection不前移。
- 只有既没有任何官方 `GCS_*` 文本、cursor或 metadata bit，也没有 `CS_INSERTCHAR` 时才映射为 Cancel；`lParam == 0` 属于这个分支。仅出现 ATTR、CLAUSE、DELTASTART等第一阶段不消费的官方 bit时是安全 no-op，不能误判 Cancel。
- `GCS_RESULTSTR` flag 存在时，`ImmGetCompositionStringW` 返回 `0` 是合法空 result，发送 `COMMIT_TEXT("")`；负数才是读取失败并执行下述 adapter-local termination。flag 不存在才表示没有 result 字段。
- `GCS_COMPSTR` flag 存在时，`ImmGetCompositionStringW` 返回 `0` 是合法空 composition，发送 `UPDATE_COMPOSITION("")` 并保持 collapsed active；负数是读取失败。不能把合法空串当作 Finish/Cancel。
- 同一消息同时有 result、next composition和 cursor时，flags本身没有顺序；adapter固定在一个 batch内先 Commit result，再 Begin/Update下一 composition，最后应用 cursor。
- `GCS_CURSORPOS` 可以单独到达：它通过 `ImmGetCompositionStringW(..., GCS_CURSORPOS, nullptr, 0)` 的直接 `LONG` 返回值读取，不进入字符串两次读取；`IMM_ERROR_NODATA` 表示本消息没有可应用的 cursor事实，其他负值是读取失败。有新 composition时相对该新文本生成 selection-after；没有 `GCS_COMPSTR` 但 Core仍 active时，相对现有 `current_range` 发送 `SET_SELECTION`。只有 result而没有 active/next composition时，不能把 cursor套到 result text。
- `GCS_COMPSTR` 到达但 `GCS_CURSORPOS` bit未置位时，adapter仍主动读取一次当前 `GCS_CURSORPOS`；读到合法位置就随 Update提交。若返回 `IMM_ERROR_NODATA`，不能落入 selection-after NONE的默认末尾，而是把 pre-message composition-relative caret按相同 UTF-16 offset夹到新 composition长度内；composition外 selection则按 full replacement的普通位置映射。只有明确 cursor事实才能覆盖这份保留值。
- 仅有 `CS_INSERTCHAR` 时，以 pre-state composition caret为 insertion点；带 `CS_NOMOVECARET`就保持原 relative offset，不带时移动到插入字符之后。它也必须显式构造 selection-after，不能借用 Update默认末尾。
- 非负 cursor必须落在它所指 composition的 `0..UTF-16 length`且不能切开 surrogate pair；越界或非法边界不提交半成品 batch，按 adapter-local读取失败结束 session。该校验针对新 `GCS_COMPSTR`或 Core现有 composition分别执行，不能用 result text长度校验。
- 只有字符串型 `GCS_RESULTSTR`/`GCS_COMPSTR` 使用两次读取，并且两次都要验证：第一次负数是错误；第二次返回值不能大于申请大小；UTF-16 byte count必须为偶数；只解码第二次实际返回的字节数。flag存在且实际返回 `0` 仍是合法空字符串。
- 任一字符串读取失败，或 cursor读取返回 `IMM_ERROR_GENERAL`/其他非 `IMM_ERROR_NODATA`负值时，adapter不提交该消息的半成品 batch，而是调用固定Finish语义的 `end_session`。结果为 `OK` 时必须无条件分发其普通 change flags；随后只有原 focus/restart token仍匹配才允许触碰 native host并按已验证的 barrier异步 Restart，token已变化则停止。`SESSION_MISMATCH` 整项丢弃；无法证明 barrier时只 Close并等待真实 focus/context重建。
- `WM_IME_ENDCOMPOSITION` 在 Core已 Idle时只是 lifecycle去重 no-op。若到达时 Core仍是 Composition，单看 END无法区分 Enter approve与 Esc cancel，因此执行 adapter-local `end_session` 保留最后已接受文本，再按前述generation表清理host；不能留下幽灵Composition，也不能猜Cancel。
- attribute/clause 第一阶段安全忽略，不能改变文本事务。
- SweetEditor既然自行处理并绘制 composition，已消费的 `WM_IME_COMPOSITION`必须标记 handled并直接返回，不能再调用 base/`DefWindowProc`让默认 IME窗口生成第二条 `WM_IME_CHAR/WM_CHAR`输入链。`WM_IME_CHAR`只在该 generation没有已接受的对应 result时作为替代 committed-character入口处理一次并标记 handled；其配对的后续 `WM_CHAR`由 adapter-local消息序列去重。`OnKeyPress`不能只靠 Core当前是否 active判断，否则 result提交后已 Idle仍会重复插入。
- 物理 Backspace/Delete继续走普通 Core grapheme action，不进入 IME wire。

### Avalonia

- 每次 `TextInputMethodClient` 激活/可编辑焦点 generation 对应一个 Command session；preedit、commit 与 selection setter 映射为 Command。
- client deactivate、失焦或 dispose 时 Finish/end 当前 generation；重新激活时必须创建新的 client 对象并 begin 新 session，不能复用旧对象与 session id。
- 空 preedit 本身不能证明 Commit 或 Cancel：Idle 时是 no-op，active 时先映射为 `UPDATE_COMPOSITION("")` 并保留 collapsed Composition。必须通过 Windows、macOS、Linux 各 backend trace 确认后续是否总有 commit/lifecycle；若某 backend 只用空 preedit表示结束，adapter 必须按已验证序列显式 Finish/Cancel，不能由 Core 猜测。
- `ResetRequested` 是 client请求原生 IME reset的出站事件，不是入站 mutation，也没有 acknowledgment，不能作为 restart barrier。
- `SurroundingText` 与 `Selection` getter必须读取同一份不可变 `ImeTextContext(EDITING)` cache；通知 host前刷新一次，两个 getter不能分别实时查询 Core而得到不同版本。
- Avalonia selection setter相对“最后发布给 backend的那份 surrounding slice”解释，加上该 cache的 `slice_start_utf16` 后转成 `DOCUMENT`。若 Core变化已使 cache失效，旧局部 offset不能套到新文本，必须关闭旧 generation；不能通过数值范围猜 local/document坐标。
- `SetPreeditText(..., cursorPos)` 的合法非空 cursor使用 `COMPOSITION` 坐标。`null`、负数或越过 preedit长度时映射为 Command的 selection-after NONE，由 Update的既定默认折叠到 replacement末尾；这与 Avalonia参考 `TextBox`/`TextPresenter` 的 fallback一致，不能偶然保留旧 selection。
- `RaiseSelectionChanged`、`RaiseSurroundingTextChanged` 和 `RaiseCursorRectangleChanged` 只由现有 editor action flags 与 `ImeState` 机械映射，不新增 IME sync kind。
- commit `TextInput` callback位于 control而不是 generation-specific client；它必须携带接收时绑定的旧 session token做 stale防护，这也是未证明 backend barrier前不能 Restart的原因。
- UI dispatcher 是唯一 mutation 线程。

### OHOS

- async attach/detach generation对应 session。每个 generation新建闭包捕获 session id与 focus generation，不能让共享 handler执行时读取“当前 session”。
- 建立顺序固定为：begin Core并创建闭包；attach前注册 SDK要求预注册的 preview/finish-preview callback；调用 attach；Promise resolve后再次核对 generation；注册只能在 attached状态注册的其余 callback；全部成功后才 show。任一步失败都注销已注册的同一闭包、Finish/end对应 Core session并执行 detach cleanup。
- 正常 detach、失焦或 component dispose时先标记 closing、注销完全相同的闭包并 Finish/end当前 generation，等待 detach Promise完成后才允许新的 begin/attach。`KeyboardStatus.HIDE` 只表示键盘隐藏，不能自动当成 detach barrier。
- commit、preview、selection 和 delete 映射为 Command。
- `setPreviewText(text, range)` 的 `range` 是编辑框中的 replacement target，不是 replacement后的 selection。adapter先把它按已确认单位转换为 `DOCUMENT`：Idle时发送一个带 target的 `UPDATE_COMPOSITION`，由 Core原子建立 baseline并 Update；active且 target等于 current composition时发送无 target的 Update；active target不同时在一个 batch内先 Finish旧 owner，再发送带新 target的 Update。该 callback没有 selection-after事实，不能把 target端点伪装成选区。
- `finishTextPreview` 明确映射为 `FINISH_COMPOSITION`。
- `selectByRange` 是 ordered range：按 trace确认的 end边界转成 Core半开区间后，确定构造 anchor=start、active=end并映射为 `SET_SELECTION`，不能声称 round-trip反向选择。`moveCursor` 与 `selectByMovement` 进入现有普通 Core navigation action；上下移动继续由 Core layout计算，扩展选区由普通 selection语义处理，不进入 IME command wire。`sendFunctionKey` 与 `handleExtendAction`同样进入普通 Core action/resolution gate，不能另建 IME mutation kind。
- 同步的 `getLeftTextOfCursor(length)`、`getRightTextOfCursor(length)`、`getTextIndexAtCursor()`都从 callback开始时同一份权威 `EDITING` Context/State快照计算：left以 selection较小端为界，right以较大端为界，index返回 Core active caret而不是固定 selection start。length与返回 index的 Unicode单位仍纳入下述 trace；转换前不能复用旧 document-window/context-id heuristic。
- outbound `changeSelection(text,start,end)` 的 `text` 固定为完整 `EDITING`文本，start固定取 `min(anchor,active)`，end固定取 `max(anchor,active)`再按已确认的 native边界约定转换；方向只保留在 Core。三者必须来自同一次 Context/State快照并使用完整编辑框的 document-absolute坐标，不能发送 context slice或局部 offset，也不能用数值范围 heuristic猜原点。
- `changeSelection` 和 `updateCursor` 只按 Core `EditorActionResult` change flags、同一 Context cache与 `ImeState` 执行，不维护独立权威状态。
- `changeSelection`/`updateCursor` 的 Promise都捕获发起时 generation。旧 generation迟到 resolve/reject只丢弃；current-generation reject属于 adapter-local desync，先调用固定Finish语义的 `end_session`并分发结果，再注销同一闭包、等待 detach完成。第一阶段不立即重试，统一降级为 Close并等待下一次真实 focus/attach，避免完整大文本 IPC失败后无限重建。
- OHOS preview/selection range的坐标原点已经固定为完整编辑框；仍需用 ASCII、代理对 emoji、组合字符和 ZWJ序列记录真实 trace，确认 range端点和 delete count究竟按 UTF-16、code point还是 grapheme计数，以及 end是否为半开边界。adapter随后转换为 `int64_t` UTF-16 range或标注准确的 `ImeTextUnit`。
- 未确认单位的 delete 不能先统一标成 UTF-16，也不能为获得“看起来正确”的结果统一扩成 grapheme；无法证明的 backend 路径暂不启用新协议。
- `deleteLeft/deleteRight` 在非空 selection 下究竟删除 selection 还是保留 selection 两侧，必须由 trace 确认；未确认前不能默认映射为本设计中“保留 selection”的 `DELETE_SURROUNDING`。

## 正确性与验收

### Core 必测不变量

- Idle/Composition 的Begin、Update、Commit、Finish、Cancel完整转换矩阵，包括collapsed active与Flutter empty composition；direct-Document状态只含 `current_range + baseline_text_raw + baseline_caret`，覆盖取消、候选替换和连续删除，不保存第二份current preedit。
- Command/TextUpdate batch先完成语义验证；被拒payload零应用，随后独立recovery的Finish结果另行断言。验证成功后检查同一pre-state replacement plan、history/result/effect计划与最终live state一致；不注入或承诺内存分配失败下的整Document回滚。
- TextUpdate覆盖oldText链、after selection/composition、stale session/revision、model mismatch、有限buffer创建与自然增长、guard、hard cap、超大selection拒绝和前step触guard后后step非法。Core-originated editing-state变化和accepted换区按规定结束generation，不允许原session rebind。
- Command不携带expected revision且对外revision固定为 `0`；所有inactive字段、未知enum和canonical NONE按固定校验顺序处理，不能依赖目标语言默认值或静默回退。
- ownership覆盖边界插入 `[abc]`/`ab[c]`、collapsed同点不同bias、非collapsed preimage与inserted span不一致、单端/双端/多行替换；不能唯一判断时整批拒绝，不能拆成provisional与committed两次编辑。
- `EDITING`、`COMMITTED` 任意slice和 `EDITING_BUFFER(0,-1)` 覆盖 `length=-1`、空slice、越界、checked arithmetic、surrogate内收及精确UTF-16 host扩展后裁剪；Context查询幂等且不改变buffer/revision。
- Finish最多产生一个composition `HistoryEntry`，Cancel零undo，Undo/Redo先Cancel；普通typing允许coalesce，composition、mixed、linked、recovery及零净边界形成merge barrier。Undo/Redo精确恢复反向selection和active affinity。
- provisional Document变化只更新composition/selection/redraw与当前layout；committed history/event/effect按baseline→final结算。纯Update无committed事件，Finish即使无物理replacement也可产生committed event；所有changes使用同一committed pre-state坐标和raw文本。
- Core-originated active resolution与随后普通action使用两个transaction但只发布一个聚合结果；linked target、pointer和navigation在第一阶段提交后重算，无法唯一映射时只拒绝第二个action。linked secondary只在Finish/Commit提交。
- surrounding delete从同一pre-state原子解析两侧并保留selection；部分命中composition时分别结算provisional与committed effect，覆盖保持active、Finish、Cancel和同batch Finish。IME严格验证UTF-16/code point，普通Backspace/Delete独立验证grapheme。
- `CaretAffinity` 覆盖软换行两侧、hit-test、移动、preferred-x、geometry和渲染，以及Flutter、UIKit/AppKit和Swing可保真的映射；它不得参与ownership或编辑边界粘性。
- `ImeOffsetRange`/`ImeSelection` 覆盖collapsed、正反selection、canonical NONE、混合负值、`< -1`、错误坐标和伪NONE；所有生成语言的默认构造必须逐字段为canonical NONE。必需的TextUpdate selection收到NONE时整批拒绝并恢复。
- 所有wire offset/length/delete count使用 `int64_t`，覆盖 `INT32_MAX + 1` round-trip、容器转换检查和ArkTS `2^53 - 1` 上界；session id耗尽拒绝begin，revision耗尽先完整提交当前batch再Finish并Restart/Close，均不得回绕或丢输入。
- CRLF、CR、LF与混合行尾在Update/Cancel/Finish/Undo后精确恢复raw文本；logical文本相等不能把原行尾改写为 `\n`。
- provisional edit不更新持久decoration/fold/search/history；相交effect临时停用、外部effect映射，Finish只结算一次。覆盖空baseline insertion seam、非空baseline/current collapsed和三种Context中的current/derived range。
- `ImeState`/`ImeTextContext` 的result/default、`EditorActionResult` 合法组合、begin冲突、query错误、session mismatch、end成功和apply内部结束逐项覆盖；response id `0` 不能单独驱动binding清理，Context不回显session/source/revision。
- 多错误payload只按既定优先级记录第一个内部原因；多replacement的apply与Undo/Redo全部使用同一transaction pre-state坐标。
- read-only、reset、失焦、外部编辑、Escape和Undo/Redo覆盖resolution gate。Core HostAction已结束session；延迟Restart必须复核focus、read-only和generation，`SESSION_MISMATCH` 不得关闭或重建当前连接。未通过old-generation barrier的目标只验收安全Close，不标记为正确启用。

### 接入实现必测场景

- Android 原生与 Flutter Android：点击 `enabled` 中间、候选替换为 `enables`、立即 backspace，必须得到 `enable` 且保留前方空格。
- Android 原生：两种 surrounding delete 在非空 selection 下分别按精确 UTF-16 code-unit/code-point 删除两侧且不删除 selection；非法 surrogate 边界零应用并恢复。
- Android 原生：`KEYCODE_DEL` 不进入 surrounding delete，按 grapheme 删除；有 selection 时删除 selection。
- Android 原生：所有受支持的 `InputConnection` 协议级文本 mutation 只调用 Command 入口；普通按键、菜单和 editor action 只进入现有 EditorCore action。两类路径都不得发送 TextUpdate/snapshot，本地 `Editable`/`BaseInputConnection` 不得产生未进入 Core 的 mutation，任意 callback 后镜像与 Core state 一致。
- Android 原生：active/Idle两种状态下的 API 34 `replaceText` 分别断言原子的 `FINISH_COMPOSITION + COMMIT_TEXT(target,text)` 和单独 `COMMIT_TEXT(target,text)`；`TextAttribute` overload与基础 overload文本结果一致。
- Android 原生：`commitCorrection` 不修改文本；completion、content/private command、snapshot/query和两类 handwriting的支持或拒绝路径明确，任何路径都不能临时切换到 TextUpdate。atomic initial snapshot、monitor extracted text、cursor update订阅、UTF-16 query上限、composing updateSelection和旧 InputConnection stale callback逐项覆盖。
- Flutter Android：候选替换后继续输入，不得把整个候选词错误替换成新字符。
- Flutter已启用目标：collapsed `TextAffinity` 与 non-collapsed deterministic affinity映射正确、同 connection单一 shadow保真，新 generation从 Core affinity重建；affinity-only NonText delta为 no-op且不推进 revision。Android验证新InputConnection Restart；SweetEditor当前无autofill的iOS配置验证新 `FlutterTextInputView` Restart。macOS/Windows在独立identity或drain trace通过前不得标记为完整启用；Linux在engine delta与native reset/focus-out barrier修复前保持禁用。
- Flutter Windows：先用微软拼音、日文、韩文的输入、候选切换、回退、提交、取消、移动与rollover采集barrier trace；迟到NonText delta只能携带旧binding并被丢弃。独立identity或消息排空trace通过并验收Restart前，不把该目标标记为完整启用。
- Flutter Linux：未修复3.41.6 engine时新IME mutation固定不启用；修复/回补后用IBus/Fcitx验证正确delta的preedit、delete-surrounding、commit、cancel和失焦，且不得出现snapshot diff或 `FlutrFlutter`。只有原生reset/focus-out barrier也得到证明后才启用Restart和完整输入路径。
- Flutter全目标：有限 buffer的 guard换区、超大 selection拒绝、SweetEditor Ctrl+A/Home/End等普通 Core路径，以及 linked secondary导致 final-state divergence后的 generation更换。单独验收原生系统全选/剪切/复制/粘贴只有窗口局部语义，不能误报为全文语义或由 Core猜测修复。
- Flutter Android：`requestExistingInputState` 在同 connection只原样 reseed当前 shadow，不改变 revision/session；其他目标不把这条 Android限定行为当作可用同步屏障。
- Apple：AppKit whole/subrange/collapsed/越界/`NSNotFound` marked replacement及insertText document replacement，UIKit nil marked text、marked selection、current editing range查询、请求位置的geometry/hit-test、外部点击gate、UIKit collapsed affinity、non-collapsed方向保留/规范化、AppKit无affinity默认、成对will/did顺序与first-responder迟到callback；barrier未证明时只验收安全关闭，不能宣称自动Restart。
- Swing：committed text/length、selected text、null/empty text-changed、composed suffix + null caret回到 composition起点、caret-only null no-op、visiblePosition、`getLocationOffset`、参数化 text location、可保真的 `TextHitInfo` affinity、跨行 composition和普通 Core grapheme delete。
- WinForms：`lParam == 0`、仅 metadata bits、`CS_INSERTCHAR/CS_NOMOVECARET`、full-string优先、`GCS_COMPSTR`无 cursor bit的读取/保留 fallback、空 result、空 composition、cursor-only、result + next composition + cursor、字符串两次读取短读/错误、cursor `IMM_ERROR_NODATA`、surrogate位置校验、END lifecycle去重，以及 handled composition/result后 `WM_IME_CHAR/WM_CHAR/OnKeyPress`不重复插入。
- Avalonia：各 backend空 preedit后续事件、nullable cursor语义、同一 immutable Context cache的 surrounding/selection、旧 cache setter、旧 client/control callback和 cursor rectangle通知顺序。
- OHOS：attach前 preview注册、detach Promise barrier、迟到 callback、ordered selectByRange/反向 Core selection的 outbound归一化、普通 Core navigation/function/extend action、三种同步 query、preview replacement target、完整 `EDITING` changeSelection、outbound Promise reject Close-only，以及四类 Unicode样本的 range/delete/query单位和 end边界 trace。

静态设计评审不能代替真实 IME trace。上述 trace 与 Core transition log 一致后，才允许删除旧逻辑并启用新路径。

## 实施顺序

1. 先保存Android Gboard、Flutter Android/iOS/macOS/Windows/Linux、Apple、Swing、WinForms和OHOS的可重复原生事件trace。
2. 将 `CaretState` 收敛为 anchor/active/active-affinity，接入 hit-test、左右/上下移动、preferred-x、caret geometry与渲染，并先运行 affinity/layout单元测试。
3. Document只补一个共享pre-state坐标的批量replacement接口；LineArray/PieceTable先验证全部range，再按逆序直接修改原Document。
4. 建立短期`EditTransaction`、私有raw range slice、同一pre-state replacement set与带owner-specific端点规则的纯位置变换函数；复用已经统一的`HistoryEntry`和Undo/Redo坐标语义，不建立全局range registry。
5. 实现三字段 `CompositionState`、committed slice按需合成、持久 effect映射和统一 resolution gate。
6. 定义16个CoreProtocol wire类型及canonical NONE；协议生成器对入站enum保留raw值供统一业务校验，对出站未知值严格失败，重新生成所有接入实现协议代码。
7. 实现 session、TextUpdate-only revision、有限 editing buffer、三种 Context文本源和统一结果字段。
8. 实现 7-kind Command batch与 TextUpdate batch的 staging reducer、history/event结算。
9. 迁移 Android、Apple、Swing、WinForms、Avalonia、OHOS Command接入。
10. 迁移Flutter Android/iOS/macOS/Windows delta、单一shadow、session lifecycle与recovery；Android和SweetEditor当前无autofill的iOS配置启用新native identity Restart。macOS/Windows只有在各自barrier通过后才标记为完整启用；Linux先修复/回补engine delta与native reset/focus-out，未满足时保持禁用。
11. 删除 SYSTEM_MARK、script、scope、Core/adapter snapshot mutation、token/lease、presence bool和候选启发式代码，不保留 snapshot diff fallback。
12. 运行 Core、C API、协议生成、各接入实现构建和真实 IME回归；通过后再更新正式中英文 API文档与 CHANGELOG。

## 参考资料

- [Android InputConnection](https://developer.android.com/reference/android/view/inputmethod/InputConnection)
- [Android BaseInputConnection](https://developer.android.com/reference/android/view/inputmethod/BaseInputConnection)
- [AOSP BaseInputConnection source](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/master/core/java/android/view/inputmethod/BaseInputConnection.java)
- [Android HandwritingGesture](https://developer.android.com/reference/android/view/inputmethod/HandwritingGesture)
- [Flutter DeltaTextInputClient.updateEditingValueWithDeltas](https://api.flutter.dev/flutter/services/DeltaTextInputClient/updateEditingValueWithDeltas.html)
- [Flutter TextEditingDelta](https://api.flutter.dev/flutter/services/TextEditingDelta-class.html)
- [Flutter TextAffinity](https://api.flutter.dev/flutter/dart-ui/TextAffinity.html)
- [Flutter TextSelection](https://api.flutter.dev/flutter/services/TextSelection-class.html)
- [Flutter SystemChannels.textInput contract](https://api.flutter.dev/flutter/services/SystemChannels/textInput-constant.html)
- [Flutter requestExistingInputState handling](https://github.com/flutter/flutter/blob/3.41.6/packages/flutter/lib/src/services/text_input.dart#L2036-L2044)
- [Flutter EditableText restart sequence](https://github.com/flutter/flutter/blob/3.41.6/packages/flutter/lib/src/widgets/editable_text.dart#L4001-L4040)
- [Flutter Android native context-menu actions](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/android/io/flutter/plugin/editing/InputConnectionAdaptor.java#L398-L452)
- [Flutter Android text input plugin lifecycle](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/android/io/flutter/plugin/editing/TextInputPlugin.java)
- [Flutter iOS text input plugin lifecycle](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterTextInputPlugin.mm)
- [Flutter macOS text input plugin lifecycle](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterTextInputPlugin.mm)
- [Flutter Windows text input plugin lifecycle](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/windows/text_input_plugin.cc)
- [Flutter Linux delete-surrounding implementation](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/linux/fl_text_input_handler.cc#L225-L235)
- [Flutter Linux client lifecycle](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/linux/fl_text_input_handler.cc#L244-L323)
- [Flutter engine TextEditingDelta construction](https://github.com/flutter/flutter/blob/3.41.6/engine/src/flutter/shell/platform/common/text_editing_delta.cc#L11-L25)
- [Apple AppKit setMarkedText(_:selectedRange:replacementRange:)](https://developer.apple.com/documentation/appkit/nstextinputclient/setmarkedtext(_:selectedrange:replacementrange:))
- [Apple UIKit setMarkedText(_:selectedRange:)](https://developer.apple.com/documentation/uikit/uitextinput/setmarkedtext(_:selectedrange:))
- [Apple UIKit selectionAffinity](https://developer.apple.com/documentation/uikit/uitextinput/selectionaffinity)
- [Apple UIKit UITextInput](https://developer.apple.com/documentation/uikit/uitextinput)
- [Apple NSTextInputClient.attributedSubstring](https://developer.apple.com/documentation/appkit/nstextinputclient/attributedsubstring(forproposedrange:actualrange:))
- [Apple NSTextInputContext.discardMarkedText](https://developer.apple.com/documentation/appkit/nstextinputcontext/discardmarkedtext())
- [Apple UIResponder.reloadInputViews](https://developer.apple.com/documentation/uikit/uiresponder/reloadinputviews())
- [Java InputMethodEvent](https://docs.oracle.com/en/java/javase/23/docs/api/java.desktop/java/awt/event/InputMethodEvent.html)
- [Java InputMethodRequests](https://docs.oracle.com/en/java/javase/23/docs/api/java.desktop/java/awt/im/InputMethodRequests.html)
- [Java TextHitInfo](https://docs.oracle.com/en/java/javase/23/docs/api/java.desktop/java/awt/font/TextHitInfo.html)
- [OpenJDK JTextComponent input-method caret handling](https://github.com/openjdk/jdk/blob/master/src/java.desktop/share/classes/javax/swing/text/JTextComponent.java)
- [Win32 WM_IME_COMPOSITION](https://learn.microsoft.com/windows/win32/intl/wm-ime-composition)
- [Win32 ImmGetCompositionStringW](https://learn.microsoft.com/windows/win32/api/imm/nf-imm-immgetcompositionstringw)
- [Win32 Composition String](https://learn.microsoft.com/windows/win32/intl/composition-string)
- [Avalonia TextInputMethodClient source](https://github.com/AvaloniaUI/Avalonia/blob/main/src/Avalonia.Base/Input/TextInput/TextInputMethodClient.cs)
- [Avalonia TextPresenter preedit cursor handling](https://github.com/AvaloniaUI/Avalonia/blob/main/src/Avalonia.Controls/Presenters/TextPresenter.cs)
- [OpenHarmony inputmethod API](https://gitcode.com/openharmony/docs/blob/OpenHarmony-6.0-Beta1/zh-cn/application-dev/reference/apis-ime-kit/js-apis-inputmethod.md)
