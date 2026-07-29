# SweetEditor Linked Editing 与 Composition 协作重构设计

> 状态：实施基准。Core、协议和 Flutter 同步改造已完成，仍需持续执行各系统真实输入法回归。
>
> 本文是 `ime-architecture-redesign.md` 的专项补充，用于固定 linked editing 与 IME composition 的协作语义、实现边界和验收条件。IME 的通用协议、session、坐标空间和各接入实现契约仍以总体文档为准。

## 设计结论

本轮采用以下唯一方案：

- composition 的 primary provisional 文本和 linked editing 的所有 secondary 镜像文本都实时写入当前 `Document`。
- 只有平台实际操作的 primary 带 composition 标记；secondary 是 Core 派生的普通文本变化。
- 每个COMMAND callback或完整TEXT_UPDATE delta batch以一个批量replacement同时提交primary和secondary，不向live Document暴露逐command/step中间状态；owned Composition Update不写history。
- Finish 不再补写 secondary，只把整组 baseline 到 final 的净变化记录成一个 `HistoryEntry`。
- Cancel 以一个批量 replacement 恢复 primary 和 secondary，不写 history。
- `LinkedEditingSession` 始终保存当前 `Document` 坐标，不在渲染或 Finish 时投影旧坐标。
- COMMAND 和 TEXT_UPDATE 共享同一 Core 事务语义；平台层不判断 linked editing。
- Flutter 有限 editing buffer 与Core派生镜像发生偏离时，Core请求同session的受控editing-state同步；该规则同时适用于Idle普通linked edit和active linked composition。

## 与总体 IME 设计的边界

`ime-architecture-redesign.md` 负责：

- `Idle` / `Composition` 生命周期。
- COMMAND 与 TEXT_UPDATE 入站协议。
- session、revision、有限 editing buffer 和 Context 查询。
- composition ownership、surrounding delete、恢复和通用 history 语义。
- 各接入实现的机械转换与生命周期。

本文只负责：

- composition target 位于 linked primary 内时如何实时镜像 secondary。
- linked ranges 的 current/baseline 坐标职责。
- Finish、Cancel、Undo/Redo 和 linked session 生命周期。
- Flutter shadow 因 Core 派生镜像发生变化时如何同步。
- 冲突、失效和降级策略。

总体文档负责共享状态、协议和通用语义；本文展开 linked-specific 字段含义、逐阶段算法和专项测试。总体文档只保留足以理解整体架构的摘要，不维护第二份 linked 实现细节。

## 目标与非目标

### 目标

- `Document`、渲染、语法分析、补全和输入法查询始终读取同一份完整当前文本。
- composition 期间 primary 与 secondary 不出现内容不一致的中间状态。
- Update、Finish、Cancel 和 Undo 在所有 linked ranges 上具有确定且原子的行为。
- secondary 位于 primary 前面、范围为空、多行或只覆盖 primary 子区间时仍保持正确坐标。
- linked editing 的复杂度全部留在 Core，平台只处理既有 IME state 和声明式 HostAction。
- 不建立全局 `TrackedRange`、range registry 或第二份 Document。

### 非目标

- secondary 不获得系统 composition 标记、候选 clause 或输入法属性。
- 不把 linked editing 信息加入 IME wire。
- 不为 linked editing 建立平台专用事件或回调。
- 不改变普通 linked typing、snippet tab stop 和 completion 的对外语义。
- 不为非法重叠 target 猜测修复或保留旧实现兼容。

## 核心不变量

- 当前 `Document` 精确等于用户正在看到的文本。
- `CompositionState.current_range` 始终位于当前 `Document`。
- primary与linked secondary的baseline ranges始终位于同一套composition pre-state坐标；composition外部修改会重定位它们，provisional变化不会。
- `LinkedEditingSession` 中所有 group ranges 始终位于当前 `Document`。
- primary 与 secondary 的物理 replacement 使用同一个 transaction pre-state 坐标。
- Update 不写 history；Finish 最多写一个 `HistoryEntry`；Cancel 不写 history。
- `text_changes` 只描述本次调用真实写入当前 `Document` 的变化。
- 同一transaction的`document_edits`使用共享pre-state坐标，公开`text_changes`则按range start降序、相同start按end降序的实际物理写入顺序发布，保证调用方可逐项重放；外层action聚合多个transaction时按执行时间追加。
- `composition_changed` 只反映 composition 是否出现、消失或 current range 是否变化，不受内部 baseline 快照变化影响。
- linked composition 存活期间，对应的 `LinkedEditingSession` 不能被直接销毁或切换 group。

## CompositionState

实时 secondary 可能位于 primary 前面并改变 primary 的当前位置，因此不能再由 `current_range.start + baseline_text` 推导composition baseline range。Core 必须同时保存 current 和 baseline 两套必要坐标，但不新增 linked 专用状态类型。

```cpp
struct CompositionState {
  TextRange current_range;
  std::optional<TextChange> text_change;
  Vector<TextChange> linked_secondary_changes;
  CaretState baseline_caret;
};
```

### 字段语义

`current_range`：

- 位于当前 `Document`。
- 只圈定平台拥有的 primary composition 文本。
- 用于 IME state、composition 装饰、editing Context 和几何查询。

`text_change`：

- `nullopt` 表示 marked-only composition，Core 尚未取得文本 ownership。
- `range` 是 primary composition 在composition baseline中的范围。
- `old_text` 是 Cancel 和 Undo 使用的 raw baseline。
- `new_text` 是随每次成功 transaction 原子刷新的当前 primary composing 文本快照。
- 它只描述 baseline→current 净变化并服务于 history 与内部一致性校验，不是第二份当前文档；当前可见文本仍以 `Document[current_range]` 为权威。

`linked_secondary_changes`：

- 只保存当前 active group 的 secondary，不重复保存 primary。
- 元素顺序与 active group 的 `ranges[1..]` 一致。
- `range` 是 secondary 在composition baseline中的范围。
- `old_text` 是 Cancel 和 Undo 使用的 raw baseline。
- `new_text` 是随每次成功 transaction 原子刷新的当前完整 linked target 文本快照，同样不是可独立修改的权威状态。
- 空数组表示当前 composition 没有取得有效 linked ownership。

`baseline_caret`：

- 保存 Composition 从Idle建立前的完整`CaretState`；Idle直接Update时就是该Update前，显式Begin或TextUpdate NonText Begin时就是Begin前。
- marked-only期间的selection变化以及第一次取得文本ownership都不能重新捕获它。
- committed 外部修改会重定位它。
- provisional primary/secondary 修改不会改变它。

### 状态比较

`CompositionState` 的内部快照不能直接决定 `EditorActionResult.composition_changed`。对外可见比较只检查：

- optional composition 是否出现或消失。
- 两侧都有 composition 时 `current_range` 是否变化。

`text_change.new_text`、secondary 快照和 baseline caret 的内部变化不单独触发 `composition_changed`；真实文本变化已经由 `text_changes` 表达。

实现应使用专门的对外比较 helper，不调用完整 `CompositionState::operator==`。`ActionSnapshot`只保存`std::optional<TextRange> composition_range`这一份轻量可见状态，不能为每个普通action复制完整`CompositionState`及全部secondary文本。如果完整相等运算没有其他内部用途，应删除它及对应的`operator!=`。

## 两套坐标

### Current Document 坐标

用于：

- primary 和 secondary 的物理 replacement。
- composition range、caret、selection 和 hit-test。
- linked highlights。
- Cancel 时定位当前文本。
- decoration、fold、search、layout 和渲染。

权威来源：

- primary：`CompositionState.current_range`。
- linked ranges：`LinkedEditingSession` 当前 group。

### Composition baseline 坐标

用于：

- Finish 构造一个 baseline 到 final 的 `HistoryEntry`。
- Undo/Redo。
- composition 外部修改发生后继续重定位 baseline。

权威来源：

- primary：`CompositionState.text_change.range`。
- secondary：`linked_secondary_changes[].range`。

provisional replacement 只能调整 current 坐标；composition外部修改和最终history结算才调整baseline坐标。两者不能复用同一range更新列表。

### 事务局部 batch replacement map

owned composition 存活期间，Core按需从已有状态构造一张局部映射表：

- primary项使用稳定owner index `0`配对`text_change.range`与`current_range`。
- secondary项使用稳定owner index `i + 1`配对`linked_secondary_changes[i].range`与当前group的`ranges[i + 1]`。
- 状态存储始终保持owner index顺序，不要求primary位于文档最前；secondary位于primary前方是正常情况。
- 映射时分别按baseline位置和current位置生成临时有序视图；两个视图的owner index序列必须一致，且各自不能存在真实文本区间重叠。排序只能服务纯计算，不能改变group或snapshot中的owner身份。

这张表只在当前 composition 或 `EditTransaction` 内进行纯计算，不注册、不跨 composition 持久化，也不参与 rendering、hit-test 或普通 Document 读取。它提供：

- current→baseline：解释composition外部修改并重定位baseline ranges与baseline caret。
- baseline→current：仅在history、Cancel和外部range变换确实需要时使用。

公开`COMMITTED` Context与这张内部表无关。它只从当前`Document`删除primary的`current_range`，保留linked secondary，不恢复任何`old_text`；selection按这一次删除映射，`composition_range`返回`NONE`。这与Java `InputMethodRequests`读取“当前文本去掉未提交span”的契约一致，不是composition baseline视图。

## Linked session 建立条件

`startLinkedEditing()`和snippet展开在绑定`LinkedEditingSession`前必须建立强不变量：

- 每个group至少有一个range，`ranges[0]`只按语义身份表示primary，不要求它是文档中位置最靠前的target。
- 所有range已正规化、位于当前`Document`内，端点位于UTF-16 code point边界。
- 同一group中需要同步写入文本的ranges不能真实重叠；两个collapsed owner位于同一点同样拒绝，因为无法定义两次插入的文本顺序。
- 第一阶段不支持跨group的non-collapsed嵌套或真实重叠；这种输入在建立session时整体拒绝，不进入运行中失效状态。
- 不同group的collapsed tab stop可以位于同一点或落在其他range边界；它是被动位置，不是当前批次的第二个文本owner，并按后文固定点粘性变换。

校验失败时不创建或替换linked session，也不移动caret。新`startLinkedEditing()`发生在active composition期间时，先按总体resolution gate结算旧composition，再把调用方提供的ranges通过该resolution实际产生的`document_edits`映射到新Document；无法唯一映射或映射后无效就不绑定新session。实现不为非法groups猜测排序、clamp或拆分。

在这些不变量下，合法active owner replacement只会确定性地更新其他groups的位置，不会凭空使inactive group反序或失效。真正切入其他target的只能是同一IME batch中的composition外committed片段或普通Core action，统一进入后文冲突路径；不再把“合法Update试算后意外失效”设计成正常业务分支。

## 未取得 composition ownership 的普通 IME 编辑

linked session活跃并不要求composition存在。以下committed mutation继续复用既有普通linked editing批量替换能力：

- Idle `COMMIT_TEXT`和Idle `DELETE_SURROUNDING`。
- Flutter Idle→Idle text patch。
- marked-only Composition直接`COMMIT_TEXT`，没有经过取得ownership的Update。

Core按command/step顺序处理每个committed mutation。一个mutation可以包含一段replacement，也可以像surrounding delete一样包含同一pre-state上的两侧replacement；只要这组replacement全部位于active primary并能唯一得到最终primary文本，Core就同时替换primary和全部secondary，并向本callback唯一的`HistoryEntry`贡献linked净变化。第一次离开primary、跨越primary边界或与其他target冲突的mutation仍完整保留本次输入，但不再派生新的secondary镜像，并在解释后续command/step前结束linked session；先前已经stage的linked镜像不回退。整个callback最后仍把这些顺序语义规范化为一个transaction pre-state上的物理replacement set。没有跨callback存活的provisional状态，因此不创建`linked_secondary_changes`。

TEXT_UPDATE路径若因此使有限buffer中的host可见文本、selection或composition偏离host after-state，使用同一个`SYNC_EDITING_STATE`流程；此时Core可以保持Idle。

## 取得 linked ownership

Begin 只建立 marked-only composition，不立即捕获 secondary。

第一次 Update 取得 primary 文本 ownership 时，Core 执行：

1. 捕获 primary 的 `text_change`。
2. 验证 linked session 仍 active 且 current group 有效。
3. 验证composition baseline没有进入active primary外部；owner身份固定为当前active primary，不能通过数值containment反推。
4. 验证 primary 和 secondary ranges 有效、互不重叠且端点位于 UTF-16 code point 边界。
5. 为 `ranges[1..]` 捕获 `linked_secondary_changes`。

collapsed composition位于active collapsed primary时，即使该点同时是相邻secondary或inactive tab stop的边界，也仍只属于active primary；邻接边界不构成第二个owner。只有两个实际需要写入文本的collapsed owner位于同一点，才属于无法接受的多owner冲突。

如果composition进入primary外部、实际文本owners重叠或运行中状态已违反session不变量：

- 不捕获 secondary。
- 结束非法 linked session。
- composition 继续按 primary-only 处理。
- 不拒绝或丢弃输入法文本。

第一次写入secondary前仍要用统一纯位置变换计算全部groups的新current ranges，并在提交前检查强不变量；这是同一replacement plan的预提交验证，不是一个可能由合法输入触发的独立降级状态。仅端点相接不算重叠，collapsed tab stop与相邻range共享位置时按明确粘性正常变换，不能因为数值相等就误判session非法。

## Update

### 计算完整 linked 文本

composition 可以只覆盖 primary 的一个子范围。Core 先从当前 primary 中取得 composition 左右两侧文本：

```text
linked_text = primary_prefix + new_composition_text + primary_suffix
```

例如：

```text
primary:      getValue
composition:     Value
Update:          Name
linked_text:  getName
```

secondary 必须替换成完整 `getName`，不能只替换其中与 composition 对齐的子区间。

### 批量提交

COMMAND中的一次Update在其callback transaction内形成最终净修改；TEXT_UPDATE中的“本次Update”指完整`ImeTextUpdateBatch`，不是单个delta step。最终`document_edits`包含：

- primary composition replacement。
- 所有 old/new 不同的 secondary 完整 replacement。

所有range都相对同一个transaction pre-state。TEXT_UPDATE先在有限host buffer中逐step重放Flutter报告的oldText/patch/after-state；Core派生的secondary不注入同一delta list后续step的oldText或offset，而是在事务局部保存active target当前文本，并持续规范化成最终净replacement。Command batch同样只更新事务局部状态。验证完成后只调用一次Document批量replacement：

```text
IME callback / TextUpdate batch
    ↓
顺序解析 command / host delta step
    ↓
更新事务局部 primary 与 ownership
    ↓
计算最终 linked_text 与净 replacement set
    ↓
一次修改 Document
    ↓
统一更新 current composition、caret 和 linked ranges
    ↓
发布一组 text_changes
```

同一batch内发生Finish→Begin等可唯一解释的ownership rollover时，旧owner的history语义和新owner的baseline都基于事务局部target文本结算，仍不提前写入live Document，也不复制整个Document。最终仍只有一次物理提交和一次结果发布。

保持active的owned Update不向`history_changes`添加primary或secondary provisional变化；只有同batch已经发生Finish/Commit的旧owner才按其baseline→final净变化贡献history。

### Range 更新

`LinkedEditingSession::adjustRangesForEditBatch` 必须使用明确的 owner身份。`EditTransaction`为每个计划中的物理edit只保存一个可选、事务局部的active group range索引，不增加公开owner类型、长期owner层级或tracker：

- 索引`0`表示active primary，`1..n`表示对应secondary；非linked composition同样以`0`表示primary。
- owner由构造replacement plan的语义路径直接赋值，不能通过range数值相等或包含关系反推。
- 其他变化没有 owner，按外部 committed edit 处理。
- non-collapsed owner的start使用插入前粘性，end使用插入后粘性；owner replacement完成后直接以实际插入span作为新owner range。
- non-collapsed non-owner的start使用插入后粘性，end使用插入前粘性。
- collapsed range必须作为一个点整体变换，不能分别应用start/end bias。active collapsed owner的插入结果扩成自己的新range；被动的inactive collapsed tab stop固定使用插入后粘性，整体移动到同点插入文本之后。
- non-owner 与 replacement 真实重叠时，range 更新失败并使 linked session 失效。

批量变化按文档位置从后向前更新ranges。range start相同时先处理end更大的non-collapsed replacement，再处理同点collapsed insertion；同一owner重复产生的完全相同replacement先规范化为一项，不同文本owner的collapsed insertion位于同一点时整批拒绝，不能按owner索引人为规定文本先后。被动inactive collapsed tab stop不是文本owner，不进入该冲突。范围更新依据是`applyEditBatch()`实际产生的`result.changes`，不能依据`history_changes`，因为保持active的Update没有history。提交前用同一纯变换更新并验证全部groups；强不变量成立时合法owner replacement只产生确定性平移，边界相接和collapsed range按上述粘性正常保留。

尚未取得linked ownership时若发现运行中session已违反强不变量，在写入secondary前结束linked session并降级为primary-only。`linked_secondary_changes`非空后，任何实际切入其他target、销毁或切换`LinkedEditingSession`的路径都必须先通过resolution gate结算当前composition；不能让composition继续引用已经失效的secondary owner。合法active owner Update本身不进入这条失效分支。

secondary 位于 primary 前面时，其长度变化必须同步移动：

- primary current range。
- 当前 caret 与 selection。
- composition geometry。
- 其他 linked groups 的 current ranges。

baseline ranges 不跟随这次 provisional 位移。

## Finish 与 Commit

如果 Finish/Commit 同时提供不同的最终文本，Core 先按 Update 规则应用最后一次 primary 与 secondary 镜像。

随后：

1. 从 `text_change` 取得 primary baseline 到 final。
2. 从 `linked_secondary_changes` 取得 secondary baseline 到 final。
3. 对每个target独立比较logical old/new：相同但raw不同就把该target恢复为自己的raw baseline并过滤history no-op；存在真实logical变化时，secondary沿用primary最终完整target的raw文本，与普通linked editing一致。
4. 按composition baseline range排序。
5. 一次调用 `recordHistory()`。
6. 清除 composition state。

正常 Finish 不再写 `Document`，因此：

- 通常没有新的 `text_changes`。
- 不再次调整 linked ranges、decoration、fold 或 search。
- `composition_changed` 为 true。
- 一次 Undo 恢复 primary 和所有 secondary。

## Cancel

Cancel 从当前 group 取得 primary 和 secondary 的 current ranges，并构造一次恢复批量：

- primary current range 替换为 `text_change.old_text`。
- 每个 secondary current range 替换为对应的 `old_text`。

提交后：

- `LinkedEditingSession` ranges 随真实恢复变化回到 baseline 位置。
- caret 恢复为 committed 外部变化重定位后的 `baseline_caret`。
- 发布真实反向 `text_changes`。
- 不创建 history。
- linked editing 继续 active。

owned composition 下 Undo/Redo 仍先执行 Cancel 并消费本次用户命令，因此也会恢复整组 provisional linked 文本。

## Composition 外 committed 修改与冲突

### 同一 accepted IME batch 内可保持 composition 的 committed 片段

本节的“composition外committed片段”只指同一个accepted IME Command/TextUpdate batch中不属于当前composition owner的实际编辑，例如surrounding delete位于owner外的部分或TextUpdate明确报告的owner外patch。它不包括普通键盘、鼠标或程序化Core action；后者始终遵循总体resolution gate先结算composition。

composition外committed片段若不切入任何linked target：

- 正常写入 Document 和 history。
- 按 current map 调整 `LinkedEditingSession` ranges。
- 按composition baseline map调整primary和secondary baseline ranges。
- 重定位 `baseline_caret`。
- linked composition 保持 active。

端点相接或collapsed tab stop共享位置不自动进入冲突路径，按明确的endpoint bias变换。只要committed片段真实切入active或inactive target，就属于下一节冲突。

### 同一 IME batch 的 committed 片段碰到 target

composition外committed片段若切入、吞并或跨越active primary/secondary或任一inactive target，就不能继续维持同一个provisional linked transaction。

如果冲突修改与 Finish/Commit 来自同一个已经接受的 IME Command/TextUpdate batch：

1. 在同一个`EditTransaction`内先把当前linked composition的baseline→current净变化stage为history语义；它已经存在于当前`Document`，不能当作新的物理写入再应用一次。
2. 基于结算后的逻辑状态 stage 外部 committed 修改。
3. 如果composition净变化与外部修改涉及同一target，将`history_changes`合成为共享baseline pre-state上的baseline→final规范replacement，不能保留两条坐标系不同且互相重叠的history change；`document_edits`及公开`text_changes`仍只描述当前Document pre-state→final的真实物理写入。
4. 完整验证后一次 apply，最多生成一个 `HistoryEntry`；不能在两步之间单独提交 Finish 或暴露 observer 回调。
5. 结束linked editing；强不变量不允许删除、吞并或猜测修复被命中的target后继续复用旧session。
6. 保留已经接受的输入法文本，不自动回退secondary。

如果冲突来自普通键盘、鼠标、导航、程序化编辑或其他Core-originated action，则遵循总体resolution gate：

1. 第一个`EditTransaction`先Finish/Cancel当前linked composition，并按Finish或Cancel各自语义决定是否产生history。
2. 基于结算后的Document、caret、layout和ranges重新解释普通action。
3. 第二个`EditTransaction`执行普通action，并按自身净变化决定history。
4. 两个transaction之间不派发observer；外层只聚合一次`EditorActionResult`。

因此“一次history”只适用于同一个accepted IME batch；普通Core action可以保留两条history，不能为了形式统一把不同action边界强行压成一个transaction。

如果TEXT_UPDATE的同一payload在结算和应用committed片段后仍报告active composition，Core只有在patch/after-range几何关系能唯一建立新的primary-only owner时才继续；否则完整保留本batch已经接受的文本与selection，Finish最终状态、结束当前Core session并返回`RESTART_SESSION`。不能按文本前后缀猜测新ownership，也不能丢弃已接受输入。

### 运行中不变量失败

非法groups应在建立session时拒绝。尚未写入secondary时如果因Core内部错误或未通过验证的旧状态发现越界、真实重叠或多owner，写入前结束linked session并降级为primary-only composition，不丢输入。已经存在`linked_secondary_changes`时不得直接销毁session，必须先结算composition。这是安全恢复断言，不是合法Update可以触发的常规状态转换。

## Linked session 生命周期

`linked_secondary_changes` 非空期间，所有可能销毁或切换 linked session 的路径必须先解析 composition：

- Tab、Shift+Tab：Finish 后切换 tab stop。
- Enter：Finish 后结束 linked editing。
- 显式 `finishLinkedEditing()`：Finish composition 后结束。
- 显式 `cancelLinkedEditing()`：Finish composition 后取消 linked editing；它不等于 Cancel composition。
- Escape：优先 Cancel composition；composition 已结束后下一次 Escape 才取消 linked editing。
- Undo/Redo：owned composition活跃时先Cancel整组provisional文本并消费本次命令，linked session继续；composition已经Finish或当前Idle时，按普通linked editing既有语义先结束linked session，再移动history cursor并一次恢复/重做整组primary与secondary。
- 新 snippet 或 `startLinkedEditing()`：Finish composition 后重新绑定。
- 点击、导航和程序化编辑：遵循总体 IME resolution gate。
- document load、read-only：先按总体gate解析composition，再按这些操作的既有普通linked语义结束session，不能先释放secondary owner。
- focus/IME session teardown：先Finish composition再结束IME session；是否保留Idle linked session沿用普通linked editing现有焦点语义，IME重构不另行改变。

低层 `cancelLinkedEditingInternal()` 不负责猜测 composition 语义；调用它时必须已经没有 active linked composition。

## COMMAND 路径

COMMAND adapter 不需要任何 linked editing 逻辑：

- 平台仍只发送 Begin、Update、Commit、Finish、Cancel、selection 和 surrounding delete。
- Core在`replaceCompositionText`和统一transaction staging中追加owned composition的secondary replacements；Idle Commit/Delete和marked-only Commit则复用普通linked editing批量替换。
- `ImeState.composition_range` 始终只返回 primary。
- `EDITING`/`EDITING_BUFFER` Context、geometry和系统composing span只描述primary；`COMMITTED` Context不含composition并返回NONE。任何一类都不暴露secondary为系统composition。
- `EditorActionResult.text_changes` 可以包含多个文档变化。

Android、Apple、Swing、WinForms、Avalonia 和 OHOS 只需继续消费既有 state 和文本变化列表。

## TEXT_UPDATE 与有限 editing buffer

### 问题

Flutter delta 的 `oldText` 来自平台持有的有限 `TextEditingValue`。如果 Core 实时修改落在该 buffer 内的 secondary，而平台 shadow 仍保留旧文本，下一条 delta 会因 `oldText` 不一致被拒绝。

secondary 位于 buffer 之前时会移动buffer的absolute Document range以及primary的absolute位置；两者移动量相同则host看到的text、selection和composition相对offset保持不变，不能仅因absolute range变化请求同步。

### HostAction

新增：

```cpp
ImeHostAction::SYNC_EDITING_STATE
```

它只表示：

- Core session 继续存活。
- composition若存在则继续存活；Idle普通linked edit也可以返回该动作。
- host 需要从 Core 重新读取当前 `EDITING_BUFFER` 并更新同一输入连接的 editing state。

它不表示 Close、Restart、Finish 或新的 session generation。

`SYNC_EDITING_STATE`是TextUpdate通用host同步动作。本节只定义同一IME batch派生linked secondary时如何使用它；普通Core action改变text、selection或composition后，由总体IME设计围绕最终selection重新materialize有限buffer并复用同一动作。

### Core 流程

TextUpdate一次性提交最终primary和secondary后：

1. 用本次accepted batch的实际`document_edits`变换原有buffer range和guard，不重新选窗、不围绕caret重新居中；absolute `document_range`整体平移不算更换buffer identity。
2. 从变换后的同一逻辑窗口读取当前 Document，并与平台本次提交后应持有的shadow比较。
3. secondary完全位于buffer之前时平移起止；完全位于buffer之后时不影响窗口；两种情况只要host可见state相同都保持`HostAction::NONE`。
4. secondary位于buffer内并使文本、selection或composition相对offset不同时，原子刷新Core buffer并返回`SYNC_EDITING_STATE`；该规则不要求最终存在composition。
5. non-collapsed secondary恰好结束于buffer start视为完全在前，恰好开始于buffer end视为完全在后；跨越任一buffer边界，或collapsed secondary edit正好位于边界时，旧窗口身份没有唯一变换，先安全结算再返回`RESTART_SESSION`，不能任选endpoint bias原地rebind。
6. 无法容纳 selection/composition或变换后超过hard cap时，同样先安全结算再返回 `RESTART_SESSION`。

不能每次 Update 都无条件请求同步。

一个被接受且改变 TextUpdate 状态的 `ImeTextUpdateBatch` 恰好推进一次 revision，不按 delta step、primary/secondary 数量或 buffer 重建次数分别计数。返回 revision 标识所有派生镜像和 buffer 重建完成后的最终状态；`SYNC_EDITING_STATE` 只是要求 host 获取该状态，不得再额外推进 revision。

### Flutter 流程

Flutter 收到 `SYNC_EDITING_STATE` 后：

1. 不关闭 `TextInputConnection`。
2. 使用现有 `getImeContext(session, EDITING_BUFFER, 0, -1)` 取得完整有限 buffer。
3. 构造新的 `TextEditingValue`。
4. 更新本地 shadow 和 `state_revision`。
5. 仅当值确实变化时调用同一连接的 `setEditingState()`。

同步后的 value 必须保留 Core 返回的 primary composing range。平台回送的旧 delta 若基于同步前文本，会被 oldText/revision 校验拒绝；完全相同的 echo 必须成为 no-op，不能产生重复输入。

该路径必须分别通过 Flutter Android、iOS、macOS、Windows 和修复后的 Linux 原生 IME trace。目标未证明同 connection 同步不会破坏候选或产生迟到回调时，不得标记为完整启用。

## 事件与消费者

- Update 发布 primary 和实际变化的 secondary。
- Cancel 发布 primary 和 secondary 的反向恢复。
- Finish 通常没有文本事件。
- 列表保持可逐项重放的实际物理顺序：range start降序、相同start按end降序，不表达primary身份。
- 需要定位 composition 的消费者使用 `ImeState.composition_range`。
- linked editing 活跃期间 completion 保持现有 dismiss/retrigger 策略，不从 `text_changes[0]` 推断 primary。
- decoration provider、syntax analysis、search和LSP读取当前 Document，并按整组 `text_changes` 增量刷新。
- provisional/committed 不新增到 `TextChange`；消费者可以结合 `EditorActionSource::IME` 和当前 composition state判断输入阶段。

## 性能约束

每个Core原子batch需要处理active group文本，并用同一纯变换更新、验证全部linked ranges，复杂度为：

```text
O(total linked ranges + primary text + all changed secondary text)
```

实现必须：

- 跳过 old/new 相同的 secondary。
- 一次构造 replacement set。
- 一次调用 Document batch replacement。
- 一次推进search generation，并统一调整decoration、layout和渲染失效。
- 不复制整个 Document。
- 普通action的`ActionSnapshot`不复制完整`CompositionState`或secondary文本，只保存用于对外比较的optional current range。
- 不为每个 secondary 单独写 history或派发平台回调。

linked group 数量或文本极大时的成本是实时镜像的固有成本，不为 IME 建立延迟 secondary 的第二套语义。

## Core 测试矩阵

### Update、Finish 与 Cancel

- 第一次 Update 立即同步一个和多个 secondary。
- 多次同长度和变长度 Update 都不产生 history。
- no-op Update 不发布虚假 secondary 变化。
- Idle Commit/Delete、Idle→Idle TextUpdate和marked-only Commit复用普通linked editing；一次callback内的全部committed变化合并为一个整组`HistoryEntry`。
- Finish 通常没有 `text_changes`，但生成一个完整 history。
- 一次 Undo/Redo恢复 primary、secondary、selection和affinity。
- Cancel恢复整组且不增加history。
- zero-net Finish恢复raw行尾且不增加history。

### Range

- secondary 位于 primary 前面、后面和两侧。
- composition等于完整primary、位于primary内部、贴住start或end。
- collapsed primary和collapsed secondary插入，包括primary insertion与相邻secondary replacement具有相同start。
- 相邻range共享边界但不互相吸收插入；active collapsed primary与相邻secondary同点时owner仍固定为primary。两个同组文本owner的collapsed target位于同一点在session建立时拒绝；不同group的被动collapsed tab stop同点时整体右移，不能形成反向range。
- primary和多个secondary长度同时变化时，current↔composition baseline map双向转换正确。
- 公开`COMMITTED` Context只删除primary当前span，保留linked secondary且不恢复primary baseline；文本、总长度和selection使用单次删除映射，`composition_range == NONE`。slice覆盖结束于删除接缝、开始于接缝、跨接缝、接缝处空slice、whole-document与collapsed composition。
- 同一accepted IME batch中的composition外committed片段位于多个provisional target之前、之间和之后时，都使用内部完整baseline map解释坐标。
- 单行、多行、CRLF、CR和LF。
- supplementary code point端点。
- 其他tab stop group随active group变化正确移动。
- composition外committed片段真实切入inactive target时先resolution并结束linked session；相邻group和collapsed tab stop共享边界时按粘性正常保留。

### 生命周期与冲突

- Tab、Shift+Tab、Enter、Escape和显式finish/cancel linked editing。
- 点击、导航、read-only、失焦、session结束和document load。
- 不相交committed edit只移动current/baseline ranges。
- 同一accepted IME batch中的committed edit碰到primary/secondary时，在一个transaction内合成baseline→final replacement并且最多生成一个history。
- Core-originated普通action统一先用一个transaction结算composition，再用第二个transaction重新解释并执行action；history按两阶段语义保留。
- `startLinkedEditing()`拒绝越界、surrogate中间端点、同组真实重叠、同点多文本owner和不支持的跨group嵌套，不创建部分session。
- Undo/Redo在owned composition下先Cancel整组并保留linked session；Idle或Finish后执行普通Undo/Redo时先结束linked session。

### 渲染与事件

- composition underline只覆盖primary。
- linked highlights直接使用当前ranges。
- 同一transaction的`text_changes`按实际物理写入顺序逐项可重放；多个transaction的结果按执行时间追加。secondary在primary前时仍不能把第一项当primary，任何消费者都不得从列表位置推断owner。
- `composition_changed`不因同range composing文本或内部快照变化误触发。
- 普通action快照不复制完整CompositionState，composition range未变时secondary文本刷新不误报`composition_changed`。
- decoration、fold、search和layout只按真实Document变化调整一次。

### TextUpdate

- secondary完全位于buffer内、前、后、贴住边界、跨越边界，以及collapsed edit位于边界。
- 前方secondary只平移absolute Document range、后方secondary不影响窗口时HostAction为NONE。
- buffer内secondary使host可见state偏离时返回SYNC_EDITING_STATE且session保持；active时composition保持，Idle普通linked edit同样覆盖。
- secondary跨越buffer边界、collapsed edit正好位于边界、窗口无法容纳状态或超过hard cap时Finish并Restart，不在原session rebind。
- 同一delta list含多个step时，后续oldText只匹配前一host after-text，Core派生secondary不污染该链；全部step结束后只提交一次最终净replacement。
- 同一delta list发生可唯一解释的Finish→Begin时，旧history与新baseline基于事务局部target文本结算，不向live Document暴露中间状态。
- 一个accepted batch无论包含多少step和secondary变化都只推进一次revision，SYNC不二次推进。
- 同步后下一条delta的oldText和revision被接受。
- 同步前迟到delta被拒绝且不重复输入。
- hard cap和非法边界安全Restart。
- 所有启用的Flutter目标都覆盖候选替换、连续输入、删除、Finish和Cancel真实IME trace，其中至少Android和Windows完成独立实机回归。
