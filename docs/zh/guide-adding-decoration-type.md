# 指南：添加新的装饰类型

> 本指南列出引入一种新装饰类型（如 LinkSpan、CodeLens）时需要逐层修改的所有内容。
> 内容提炼自 LinkSpan 的真实实现过程，可作为后续新装饰类型的可复用 checklist。
>
> 本文档若与源码冲突，以源码为准。

---

## 前置阅读

- [架构总览](architecture.md)
- [Editor Core API](api-editor-core.md)
- [平台实现标准](platform-implementation-standard.md)

---

## 逐层 Checklist

以下各层按自底向上的顺序排列。依次完成可确保每一层在进入下一层之前已经可以编译通过。

### 第 1 层 — C++ 数据结构

**文件**：`include/sweeteditor/decoration.h`、`src/decoration.cpp`

- 定义结构体（如 `LinkSpan { column, length, target }`）。
- 在 `DecorationManager` 中添加按行存储的 `HashMap` 或 `Vector` 成员。
- 添加静态空哨兵（如 `kEmptyLinks`）。
- 声明并实现 `setLine*`、`getLine*`、`clear*` 方法。
- 如果类型有 column+length 语义，添加 `find*At(line, column)` 查找方法。
- 在 `clearLine()` 和 `clearAll()` 中添加清理调用。
- 如果类型携带列范围数据，实现 `adjust*StartLine()` 辅助函数并在 `adjustForEdit()` 中接入，完成编辑增量追踪。仅按行存储的类型（如 CodeLens）只需做行号重映射。

### 第 2 层 — C++ EditorCore 桥接

**文件**：`include/sweeteditor/editor_core.h`、`src/editor_core.cpp`

- 声明并实现 `setLine*`、`setBatchLine*`、`clear*` 及查询方法（如 `getLinkTargetAt`）。
- 每个 `setLine*` 调用需要标记受影响的逻辑行 `is_layout_dirty = true`，并调用 `invalidateContentMetrics(line)`。
- `clear*` 需调用 `markAllLinesDirty()` + `normalizeScrollState()`。

### 第 3 层 — C++ 布局与命中测试

**文件**：`include/sweeteditor/visual.h`、`include/sweeteditor/gesture.h`、`include/sweeteditor/layout.h`、`src/layout.cpp`

- 在 `VisualRunType` 枚举中添加新值。
- `buildLineRuns()`：获取装饰数据，插入分割点，将受影响的文本段标记为新的 `VisualRunType`。对于行内装饰（如 LinkSpan），这意味着在装饰边界处分割已有的 TEXT run；对于块级装饰（如 CodeLens），这意味着插入占据整个虚拟行的独立 run；对于仅在行号区域显示的装饰（如 GutterIcon），可能完全不需要修改 layout。
- 更新 `visual.cpp` 的 `dumpEnum()` 和 `json_serde.hpp` 的 JSON 映射。

**仅当装饰可交互（可点击）时：**

- 在 `HitTargetType` 枚举中添加新值。
- `hitTestDecoration()`：添加命中分支，点击该类型 run 时返回对应 `HitTargetType`。
- `layoutVisibleLines()`：添加 active 状态匹配逻辑，hover/press 时设置 `run.active = true`。
- 决定新 run 类型是否参与光标定位。如果是，在 `hitTestPointer()` 和 `columnToX()` 中与 `TEXT`/`TAB` 同等处理。覆盖在文本上的行内装饰（如 LinkSpan）通常参与；块级装饰（如 CodeLens）通常不参与。

### 第 4 层 — C++ 交互过滤（仅当可交互时）

纯视觉装饰（SyntaxSpan、PhantomText、GutterIcon）可跳过此层。

**文件**：`src/editor_core.cpp`、`src/interaction.cpp`

- `toHotInteractiveTarget()`：决定新类型是无条件激活（如 CodeLens）还是需要修饰键（如 Link 需要 Ctrl/Meta），添加对应分支。
- `probePointer()`：当 `toHotInteractiveTarget()` 返回有效目标时，光标类型会自动设为 `PointerCursorType::HAND`，无需额外处理（除非行为有差异）。
- `interaction.cpp` 的 `handleGestureEvent()` TAP 分支：决定命中新类型是否要抑制光标放置（`intent.place_cursor = false`）。如果需要修饰键过滤（如 Link 的 Ctrl/Meta 检查），在此添加逻辑。

### 第 5 层 — C API

**文件**：`include/sweeteditor/c_api.h`、`src/c_api.cpp`

- 声明 `editor_set_line_*`、`editor_set_batch_line_*`、`editor_clear_*` 及查询函数。
- 在头文件注释中记录二进制载荷格式（小端字节序）。
- 使用 `ByteCursor` 解析并转发到 `EditorCore`。

### 第 6 层 — 平台原生桥接（各平台）

以 Android JNI 为例：

**文件**：`jeditor.hpp`（主文件）、`jni_entry.cpp`（仅入口）

- 在 `EditorCoreJni`（位于 `jeditor.hpp`）中添加 static JNI 包装方法。set/setBatch 类通过 `GetDirectBufferAddress` 读取 `ByteBuffer` 后转发到 C API；查询类方法直接调用 `EditorCore` 并通过 JNI 返回（如字符串用 `NewStringUTF`）。
- 在 `kJMethods[]` 数组（同样在 `jeditor.hpp` 中）注册方法。`jni_entry.cpp` 只负责调用 `RegisterMethods()`，不需要修改。
- 使用 `@FastNative` 注解接受 `ByteBuffer` 参数的方法（零拷贝 direct buffer），`@CriticalNative` 用于仅含基本类型/void 签名的方法。注解与签名不匹配会导致运行时崩溃。

> 其他平台的等价模式：OHOS 使用 NAPI（`napi_editor.hpp` + `napi_init.cpp`）；iOS 使用 Objective-C 桥接。

### 第 7 层 — 平台 Core 封装

以 Android 为例：

**文件**：`<Type>.java`、`VisualRunType.java`、`EditorCore.java`、`ProtocolEncoder.java`

- 定义平台数据类（如 `public final` 不可变 POJO，字段与 C++ 结构体一致）。
- 在 `VisualRunType` 中添加枚举值。如果装饰可交互，同时在 `HitTargetType` 中添加。
- 在 `EditorCore.java` 中实现 `setLine<Type>` / `setBatchLine<Type>` / `clear<Type>` / 查询方法，通过 `ProtocolEncoder` → `ByteBuffer.allocateDirect()` 编码后调用 `native*` 方法。
- 在 `ProtocolEncoder.java` 中实现 `pack*` / `packBatch*` 二进制编码方法（两遍扫描模式：第一遍计算总大小并缓存 UTF-8 字节，第二遍一次分配 direct ByteBuffer 并写入）。

> 其他平台：OHOS 使用 ArkTS 接口，分布在 `CoreAdornments.ets` + `CoreProtocol.ets` + `EditorCore.ets`。

### 第 8 层 — 平台装饰系统与 UI

**文件**：`DecorationResult.java`、`DecorationProviderManager.java`、`SweetEditor.java`、`EditorRenderer.java`

- `DecorationResult.java`：添加数据字段（如 `SparseArray<List<T>>`）+ `ApplyMode` mode 字段；添加 getter/setter；添加 `Builder.<type>(value, mode)` 方法；更新 `copy()`。
- `DecorationProviderManager.java`：在 `applyMerged()` 中添加合并容器 + mode 变量；添加 `apply*Mode()` 和 `clear*Range()` 私有方法；在 `mergePatch()` 中添加合并分支。
- `SweetEditor.java`：暴露公开 API 方法（`setLine<Type>`、`setBatchLine<Type>`、`clear<Type>` 及查询方法）。
- `EditorRenderer.java`：添加新 `VisualRunType` 的渲染逻辑（前景色、背景色、下划线等）。

**仅当装饰可交互时：**

- `SweetEditor.java`：在 `fireGestureEvents()` 中添加新的 `HitTargetType` 分支 → `publish(new <Type>ClickEvent(...))`。
- 定义点击事件类（如 `<Type>ClickEvent.java`，继承 `EditorEvent`）。
- 暴露 `on<Type>Click` / `off<Type>Click` 事件订阅 API。

> 其他平台：OHOS 将这些分布在 `DecorationTypes.ets`、`SweetEditor.ets`、`SweetEditorController.ets`、`EditorEvent.ets`、`EditorRenderer.ets`。

### 第 9 层 — 跨平台 `DecorationType` 枚举同步

`DecorationType` 在每个平台中独立定义，以下文件都必须添加新枚举值：

- Android：`DecorationType.java`
- Swing：`DecorationType.java`
- OHOS：`DecorationTypes.ets`（字符串枚举）
- Flutter：`decoration_types.dart`
- Apple (Swift)：`DecorationProvider.swift`（OptionSet 位域）
- Avalonia：`EditorDecoration.cs`（Flags 枚举）
- WinForms：`EditorDecoration.cs`（Flags 枚举）

遗漏任何一个平台会导致该平台的 `DecorationProvider` 无法声明新的 capability。

### 第 10 层 — 测试

**文件**：`tests/decoration_adjust.cpp`、`tests/layout_decorations.cpp`

- 在 `decoration_adjust.cpp` 中添加新类型的 `adjustForEdit` 测试用例，覆盖列/行调整行为。
- 如果新类型是行内装饰且参与 hitTest / 屏幕坐标，在 `layout_decorations.cpp` 中添加一致性检查。
- 平台级测试（Swift、Android instrumentation）可能也需要覆盖新的事件类型。

---

## 关键关联点

### `clearAll()` 覆盖

`DecorationManager` 中每个新存储容器都必须在 `clearAll()` 中清理。遗漏会导致文档重新加载后残留旧装饰。

### `toHotInteractiveTarget()` 门控

此函数控制哪些装饰类型获得 hover/press 视觉反馈和手型光标。如果新类型可点击，必须在此添加分支。需决定是无条件激活还是需要修饰键。

### `adjustForEdit()` 增量追踪

具有 column+length 语义的类型（如 LinkSpan、DiagnosticSpan）需要在文本编辑时做列级精确调整。仅按行存储的类型（如 CodeLens、GutterIcon）只需做行号重映射。

### 二进制协议一致性

C API 载荷格式（小端 u32 序列）必须与平台侧 `pack*` 编码器完全一致。变长载荷（如 UTF-8 字符串）使用 `u32 byte_length + u8[byte_length]` 模式。

### 平台桥接注解与签名匹配

各平台有各自的原生桥接声明规则。Android 上 `@FastNative` / `@CriticalNative` 注解必须与 JNI 签名精确匹配，否则运行时崩溃。OHOS 上 ArkTS 要求 `forEach` 回调显式标注返回类型，泛型函数调用需要显式类型参数。务必验证平台侧 native 声明与 C API 签名的一致性。

### 光标放置交互

决定点击新装饰是否应该放置光标（如普通文本）还是抑制它（如 CodeLens）。这在 `interaction.cpp` 的 TAP 处理器中通过 `intent.place_cursor` 控制。

### 渲染模型坐标系

LINK run 在 `getPositionScreenCoord()` / `columnToX()` 中与 TEXT run 同等参与，即光标可以落在装饰文字内部。CodeLens run 则被跳过。需根据新类型选择合适的行为。

---

## 参考：LinkSpan 涉及的文件清单（Android 为例）

> 下表使用 Android 文件名。其他平台有等价文件：
> OHOS → `napi_editor.hpp`、`CoreAdornments.ets`、`DecorationTypes.ets`、`SweetEditor.ets` 等。
> iOS → 对应的 Objective-C / Swift 桥接文件。

| 层 | 修改的文件 |
|----|-----------|
| C++ 数据 | `decoration.h`、`decoration.cpp` |
| C++ 核心 | `editor_core.h`、`editor_core.cpp` |
| C++ 布局 | `visual.h`、`gesture.h`、`layout.h`、`layout.cpp`、`visual.cpp`、`json_serde.hpp` |
| C API | `c_api.h`、`c_api.cpp` |
| JNI 桥接 | `jeditor.hpp`（JNI 包装 + `kJMethods[]` 注册表） |
| Java Core | `<Type>.java`、`VisualRunType.java`、`HitTargetType`（在 `EditorCore.java` 内）、`EditorCore.java`、`ProtocolEncoder.java` |
| Java 装饰 | `DecorationResult.java`、`DecorationType.java`、`DecorationProviderManager.java` |
| Java UI | `SweetEditor.java`、`<Type>ClickEvent.java`（如果可交互）、`EditorRenderer.java` |
| DecorationType 枚举 | `DecorationType.java`（Android、Swing）、`DecorationTypes.ets`（OHOS）、`decoration_types.dart`（Flutter）、`DecorationProvider.swift`（Apple）、`EditorDecoration.cs`（Avalonia、WinForms） |
| 测试 | `decoration_adjust.cpp`、`layout_decorations.cpp` |
