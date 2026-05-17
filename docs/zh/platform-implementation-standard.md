# 平台实现标准

> 本文档定义了每个 SweetEditor 平台实现必须遵循的约定和约束。
> 目标是在允许平台特定渲染和输入处理的同时，保持跨平台行为一致。
>
> 本文档描述的是当前仓库代码状态（2026-03）。若文档与源码不一致，以源码为准。
>
> 约束级别：
> - **MUST（必须）** — 所有平台必须遵守；违反即为 bug。
> - **SHOULD（建议）** — 推荐遵守；偏离需要书面说明理由。
> - **MAY（可选）** — 可选；由平台根据自身需求决定。

---

## 1. 模块结构

每个平台实现 MUST 包含以下两大层级的逻辑分类，并确保每个分类下的类型均已实现。文件组织方式（目录结构、文件粒度）MAY 因语言惯例而异（如 Java 按包分目录、C# 按命名空间一个文件、Swift 按 Sources 分层），但逻辑分类 MUST 可识别，类型 MUST 完整覆盖。

### 1.1 Core 层（纯数据 / 模型 / 协议）

Core 层不涉及 UI 渲染，仅包含桥接、数据模型和协议编解码。

| 逻辑分类 | 必须包含的类型 | 说明 |
|---|---|---|
| **Core Bridge** | `EditorCore`, `Document`, `ProtocolEncoder`, `ProtocolDecoder`, `TextMeasurer`, `EditorOptions` | 原生桥接 + 公共核心 API 封装 |
| **Foundation** | `TextPosition`, `TextRange`, `IntRange`, `TextChange`, `WrapMode`, `FoldArrowMode`, `AutoIndentMode`, `CurrentLineRenderMode`, `ScrollBehavior` | 基础值类型与枚举 |
| **IME** | `ImeActionResult`, `ImeSyncSnapshot`, `ImeInputContext`, `ImeTextRange`, `ImeScriptClass`, `ImePreeditStorage`, `ImeContextPolicy`, `ImeInputContextKind`, `ImeTextModelMode`；暴露 unit-aware 删除 API 时包含 `ImeTextUnit` | IME 语义动作、同步快照和文本上下文协议类型 |
| **Adornment** | `StyleSpan`, `SpanLayer`, `InlayHint`, `InlayType`, `PhantomText`, `CodeLensItem`, `LinkSpan`, `FoldRegion`, `GutterIcon`, `Diagnostic`, `IndentGuide`, `BracketGuide`, `FlowGuide`, `SeparatorGuide`, `SeparatorStyle`, `TextStyle` | 装饰数据类型 |
| **Visual** | `EditorRenderModel`, `VisualLine`, `VisualLineKind`, `VisualRun`, `VisualRunType`, `PointerCursorType`, `Cursor`, `CursorRect`, `SelectionRect`, `SelectionHandle`, `ScrollMetrics`, `ScrollbarModel`, `ScrollbarRect`, `GuideSegment`, `GuideType`, `GuideDirection`, `GuideStyle`, `DiagnosticDecoration`, `CompositionDecoration`, `FoldMarkerRenderItem`, `FoldState`, `GutterIconRenderItem`, `LinkedEditingRect`, `BracketHighlightRect` | 渲染模型类型（几何语义见第 2.4 节） |
| **Snippet** | `LinkedEditingModel`, `TabStopGroup` | 联动编辑 / Tab stop 分组 |
| **Keymap** | `KeyMap`, `KeyBinding`, `KeyChord`, `KeyCode`, `KeyModifier`, `EditorCommand` | 快捷键映射数据类型与命令标识 |

### 1.2 Widget 层（UI 控件 / 渲染 / 交互）

Widget 层负责平台原生渲染、用户交互和扩展系统。

| 逻辑分类 | 必须包含的类型 | 说明 |
|---|---|---|
| **Widget** | `SweetEditor`, `SweetEditorController`*(声明式框架 MUST；命令式框架 MAY)*, `EditorTheme`, `EditorSettings`, `EditorIconProvider`, `EditorMetadata`, `LanguageConfiguration` | 控件入口、控制器、主题、配置 |
| **Decoration** | `DecorationProvider`, `DecorationProviderManager`, `DecorationContext`, `DecorationResult`, `DecorationType`；若采用 Receiver 回调模式，推荐使用 `DecorationReceiver` | 装饰提供者系统 |
| **Completion** | `CompletionProvider`, `CompletionProviderManager`, `CompletionContext`, `CompletionItem`, `CompletionResult`；若采用 Receiver 回调模式，推荐使用 `CompletionReceiver` | 补全提供者系统 |
| **Event** | 类型安全事件机制、`EditorEvent`、`TextChangedEvent`、`CursorChangedEvent`、`SelectionChangedEvent`、`ScrollChangedEvent`、`ScaleChangedEvent`、`DocumentLoadedEvent`、`FoldToggleEvent`、`GutterIconClickEvent`、`InlayHintClickEvent`、`CodeLensClickEvent`、`LinkClickEvent`、`LongPressEvent`*(仅移动端)*、`DoubleTapEvent`、`ContextMenuEvent`*(具有显式上下文菜单手势入口的平台)*；若采用显式事件总线 / 监听器模式，推荐 `EditorEventBus`、`EditorEventListener` | 事件系统 |
| **NewLine** | `NewLineActionProvider`, `NewLineActionProviderManager`, `NewLineAction`, `NewLineContext` | 换行动作提供者系统 |
| **Keymap** | `EditorKeyMap` | Widget 层 keymap 扩展，用于将 commandId 绑定到宿主侧处理器 |
| **Copilot** *(SHOULD)* | `InlineSuggestion`、`InlineSuggestionListener` 或等价的 accept/dismiss 回调机制；MAY: `InlineSuggestionController` | 内联建议数据 + 回调；主路径为 listener 形态 |
| **Selection** *(移动端 SHOULD；桌面端 MAY 省略)* | `SelectionMenuItem`、`SelectionMenuItemProvider`、宿主可见的 custom item 点击回调机制；MAY: `SelectionMenuListener` | 选区菜单（移动端 SHOULD；桌面端 MAY 省略） |
| **ContextMenu** *(MAY)* | `ContextMenuRequest`、`ContextMenuSection`、`ContextMenuItem`、`ContextMenuItemProvider`、`ContextMenuTriggerKind`、宿主可见的 custom item 点击回调机制；MAY: `ContextMenuPopup` | 平台侧的上下文菜单 / 动作菜单（桌面端 SHOULD，移动端 MAY） |
| **Perf** *(SHOULD)* | `PerfOverlay`, `MeasurePerfStats`, `PerfStepRecorder` | 性能浮层 |

> `TextChangeAction` 为 SHOULD 级辅助事件枚举。平台 MAY 暴露它用于粗粒度标识一次文本变更周期（如 `INSERT` / `DELETE` / `UNDO` / `REDO` / `KEY` / `COMPOSITION`），但 MUST NOT 用它替代 `changes: List<TextChange>` 这一主增量载荷。

### 1.3 推荐内部实现模式（SHOULD）

以下类型属于**内部实现细节**，不属于公共 API 契约。各平台 SHOULD 采用这些模式来组织内部逻辑，但 MAY 根据平台特性选择其他等效方式（如直接在控件类中实现、使用平台原生 Popup 等）。

| 模式 | 推荐类型 | 适用场景 | 好处 |
|---|---|---|---|
| **Renderer** | `EditorRenderer` | 将渲染逻辑从控件入口类中分离 | 职责单一，渲染逻辑可独立迭代和测试 |
| **Controller** | `CompletionPopupController`, `InlineSuggestionController`, `SelectionMenuController`, `ContextMenuController` | 管理弹窗 / 浮层的生命周期和交互逻辑 | 解耦 UI 弹窗与数据逻辑，平台可选择直接用 Popup 实现 |

> 如果采用上述模式，平台 SHOULD 使用上表给出的推荐名称。第 2.1 节只约束宿主可见的公共类型名称，不约束这些内部 controller 模式名称。
> 不采用这些模式不视为违规，但需确保等效功能已在其他类中实现。

---

## 2. 命名约定

### 2.1 类 / 类型名（MUST）

所有平台 MUST 对下表列出的主要公共类型使用以下规范名称。后续章节中新引入的宿主可见公共类型也 MUST 遵循相同命名规则，并使用它们在各自章节中定义的规范名称。仅在语言惯例强制要求时允许使用语言特定的前缀或后缀（如 C# 接口的 `I` 前缀）。

控件入口类 MUST 以 `SweetEditor` 为前缀，MAY 附加目标平台惯例的 UI 组件后缀：

| 后缀 | 完整名称 | 适用场景 | 示例平台 |
|---|---|---|---|
| （无后缀） | `SweetEditor` | 平台不强制 UI 组件后缀 | Android View、Swing、OHOS ArkUI |
| `Control` | `SweetEditorControl` | 平台惯例使用 `Control` | WinForms、WPF |
| `Widget` | `SweetEditorWidget` | 平台惯例使用 `Widget` | Flutter、Qt |
| `View` | `SweetEditorView` | 平台惯例使用 `View` | SwiftUI、UIKit、AppKit、React Native |
| `Component` | `SweetEditorComponent` | 平台惯例使用 `Component` | Web Components、React、Vue |
| `Element` | `SweetEditorElement` | 平台惯例使用 `Element` | Lit、Angular |

> 不允许使用 `EditorControl`、`EditorView`、`EditorWidget` 等不含 `SweetEditor` 前缀的名称。
> 若目标平台的惯例后缀不在上表中，SHOULD 提交 PR 扩展本表后再实现。

其他公共类型：

| 规范名称 | 允许的变体 | 说明 |
|---|---|---|
| `EditorCore` | OC: `SEEditorCore` | 核心桥接封装 |
| `TextMeasurer` | OC: `SETextMeasurer` | 可以以任何符合平台习惯的形式出现，包括顶层 public type、嵌套类型、内部 bridge 类型、typealias、adapter 或 C# struct；只要该概念在语义上与标准保持一致即可 |
| `EditorTheme` | OC: `SEEditorTheme` | 主题定义 |
| `EditorSettings` | OC: `SEEditorSettings` | 配置 |
| `DecorationProvider` | C#/TS/Kotlin: `IDecorationProvider`; OC: `SEDecorationProvider` | 提供者接口 |
| `CompletionProvider` | C#/TS/Kotlin: `ICompletionProvider`; OC: `SECompletionProvider` | 提供者接口 |
| `DecorationReceiver` | C#/TS/Kotlin: `IDecorationReceiver`; OC: `SEDecorationReceiver` | 回调接口；仅适用于平台选择暴露显式 Receiver 类型时 |
| `CompletionReceiver` | C#/TS/Kotlin: `ICompletionReceiver`; OC: `SECompletionReceiver` | 回调接口；仅适用于平台选择暴露显式 Receiver 类型时 |
| `NewLineActionProvider` | C#/TS/Kotlin: `INewLineActionProvider`; OC: `SENewLineActionProvider` | 提供者接口 |
| `KeyMap` | OC: `SEKeyMap` | Core keymap 数据容器 |
| `EditorKeyMap` | OC: `SEEditorKeyMap` | Widget 层 keymap 扩展 |
| `EditorCommand` | OC: `SEEditorCommand` | 内建命令 id / 命令处理器概念类型 |
| `KeyBinding` | OC: `SEKeyBinding` | 单 chord 或双 chord 绑定项 |
| `KeyChord` | OC: `SEKeyChord` | 单次按键 chord 值类型 |
| `KeyCode` | OC: `SEKeyCode` | 键盘按键码常量 / 枚举 |
| `KeyModifier` | OC: `SEKeyModifier` | 键盘修饰键标志 / 枚举 |
| `EditorMetadata` | C#/TS/Kotlin: `IEditorMetadata`; OC: `SEEditorMetadata` | 元数据概念类型；仅适用于平台选择暴露显式公共类型时 |
| `EditorEventListener` | C#/TS/Kotlin: `IEditorEventListener`; OC: `SEEditorEventListener` | 监听器接口；仅适用于采用显式监听器接口模式的平台 |
| `InlineSuggestionListener` | C#/TS/Kotlin: `IInlineSuggestionListener`; OC: `SEInlineSuggestionListener` | 监听器接口；仅适用于平台选择暴露显式内联建议 listener 时 |
| `SelectionMenuItem` | OC: `SESelectionMenuItem` | 选区菜单项数据类型 |
| `SelectionMenuItemProvider` | C#/TS/Kotlin: `ISelectionMenuItemProvider`; OC: `SESelectionMenuItemProvider` | 选区菜单项提供者；用于根据当前 editor 状态构建整套菜单 |
| `SelectionMenuListener` | C#/TS/Kotlin: `ISelectionMenuListener`; OC: `SESelectionMenuListener` | 监听器接口；仅适用于平台选择暴露显式选区菜单 listener 时 |
| `ContextMenuItem` | OC: `SEContextMenuItem` | 上下文菜单项数据类型 |
| `ContextMenuSection` | OC: `SEContextMenuSection` | 上下文菜单中的一个视觉分组 |
| `ContextMenuRequest` | OC: `SEContextMenuRequest` | 构建上下文菜单时使用的不可变请求快照 |
| `ContextMenuItemProvider` | C#/TS/Kotlin: `IContextMenuItemProvider`; OC: `SEContextMenuItemProvider` | 上下文菜单项提供者；用于根据当前上下文菜单请求构建完整菜单 |
| `ContextMenuTriggerKind` | OC: `SEContextMenuTriggerKind` | 打开上下文菜单的触发类型 |
| `EditorIconProvider` | C#/TS/Kotlin: `IEditorIconProvider`; OC: `SEEditorIconProvider` | 图标提供者接口 |
| `SweetEditorController` | OC: `SESweetEditorController` | 声明式框架的外部控制入口（见 3.0 节） |
| `IntRange` | OC: `SEIntRange` | 闭区间整数范围值类型 |

> **命名变体规则：**
> - 语言惯例要求接口加 `I` 前缀的（如 C#、TypeScript、Kotlin），MAY 使用 `I` 前缀变体
> - 语言惯例要求类名加项目前缀的（如 Objective-C），MAY 使用 `SE` 前缀变体（SweetEditor 缩写）
> - 其他语言 SHOULD 直接使用规范名称

> 事件系统如果采用平台原生 `event` / delegate / stream / signal 等机制，可以不暴露 `EditorEventBus` / `EditorEventListener` 公共类型；此时只要求其语义满足第 11 节。

### 2.2 字段 / 属性名（MUST）

数据模型字段 MUST 在各平台使用相同的语义名称，按各语言的大小写惯例适配：

| Java / ArkTS (camelCase) | C# (PascalCase) | Swift (camelCase) | Dart (camelCase) |
|---|---|---|---|
| `line` | `Line` | `line` | `line` |
| `column` | `Column` | `column` | `column` |
| `startColumn` | `StartColumn` | `startColumn` | `startColumn` |
| `endColumn` | `EndColumn` | `endColumn` | `endColumn` |
| `styleId` | `StyleId` | `styleId` | `styleId` |
| `scrollX` | `ScrollX` | `scrollX` | `scrollX` |
| `backgroundColor` | `BackgroundColor` | `backgroundColor` | `backgroundColor` |

### 2.3 方法名（MUST）

公共 API 方法 MUST 遵循各语言大小写惯例。标准名称以 Java/ArkTS camelCase 为基准，各语言按自身惯例适配（如 C# PascalCase、Go 首字母大写等）。具体方法列表及允许的变体见第 3 节。

### 2.4 宿主公共 API 枚举类型（MUST）

对于宿主可见的公共 API（如 `SweetEditor`、`SweetEditorController`、`EditorSettings`、事件 payload，以及宿主直接消费的 provider / context / result 类型），若目标语言支持枚举或等价的强类型常量，平台 MUST 使用枚举或等价强类型来表达离散取值。

- 宿主公共 API MUST NOT 在语言已支持枚举 / 强类型的前提下优先暴露裸 `int`
- 若平台受语言或框架限制，宿主公共 API 只能暴露整数常量，则该层 MUST 对无效值做显式处理（见第 15 节）
- 位标志 / flags 字段 MAY 在公共模型中继续使用 `int` 编码，只要这种表示本身就是标准定义的跨平台契约（例如 `TextStyle.fontStyle`）
- 紧凑数值语义字段 MAY 在公共模型中继续使用 `int` 编码，只要本标准已显式将该数值编码定义为契约的一部分（例如 `Diagnostic.severity`）
- `EditorCore`、桥接层、FFI 层和其他内部数值传输层不属于本条要求的宿主公共 API 范围

### 2.5 几何载体类型（MUST）

对于公共 API 和事件 payload 中使用的简单几何载体，平台 MAY 使用 SweetEditor 规范几何类型，或使用语义完全一致的平台原生等价类型。

- 点类型：`PointF` 或平台原生点类型（如 Android `android.graphics.PointF`、Apple `CGPoint`）
- 矩形类型：`RectF` 或平台原生矩形类型（如 Android `android.graphics.RectF`、Apple `CGRect`）

若使用平台原生几何类型，坐标基准、轴方向和字段语义 MUST 与 SweetEditor 规范模型保持一致。

---

## 3. Public API 契约（MUST）

以下定义两层彼此独立的公共 API：
- 第 3.1 节定义 `EditorCore` 的 bridge/runtime API
- 第 3.2 节定义宿主可见的编辑器 API

除明确标注为条件性或可选的条目外，各平台 MUST 在正确的 API 载体上实现所有列出的方法。第 3.1 节的方法归属于 `EditorCore`，并不自动属于宿主可见的编辑器接口表面。命令式框架中，第 3.2 节的 API 载体是控件入口类本身（例如 `SweetEditor`）；声明式框架中，第 3.2 节的 API 载体是 `SweetEditorController`。在声明式平台上，`SweetEditor` 仍然是 runtime/session owner，只是宿主可见的 API 通过 controller 暴露。

> 生命周期 / 内存管理 API（如 `create`、`destroy`、`freeBinaryData`）不在此列，各平台按自身惯例实现。

**通用命名变体规则：**
- 标准名称以 Java/ArkTS camelCase 为基准
- PascalCase 语言（如 C#、Go 等）：所有方法名首字母大写（如 `setDocument` → `SetDocument`），此规则适用于所有方法，不再逐行标注
- 各语言 MAY 按自身惯例适配参数命名和调用风格（如 Swift argument label、Go 导出规则、Dart named parameters 等）
- 下表"允许的变体"列仅列出与标准名称有**实质性差异**的变体（如 getter 用 property、方法名语义不同等）；`—` 表示无实质差异

### 3.0 API 载体规则（MUST）

编辑器组件天然包含大量命令式操作（如 `loadDocument()`、`undo()`、`gotoPosition()`），这些操作无法用纯声明式 state 表达。不同 UI 范式的框架需要不同的 API 暴露方式。

#### 3.0.1 命令式 UI 框架

命令式框架（Android View、UIKit、AppKit、Swing、WinForms 等）中，宿主代码可直接持有控件实例引用。

- 第 3.2 节的 API，以及后续章节中针对已实现可选模块定义的模块级公共 API，MUST 直接在控件入口类（如 `SweetEditor`、`SweetEditorView`、`SweetEditorControl`）上暴露为公共方法
- MAY 额外提供 `SweetEditorController` 以解耦控制逻辑，但不做强制要求

```java
// Android View
SweetEditor editor = findViewById(R.id.editor);
editor.loadDocument(doc);
editor.applyTheme(EditorTheme.dark());
```

#### 3.0.2 声明式 UI 框架

声明式框架（Flutter、Jetpack Compose、SwiftUI、ArkUI 等）中，Widget/Composable 是不可变的描述对象，宿主代码无法直接持有控件实例。

在声明式框架中，`SweetEditor` 仍然是 runtime view/session owner。它持有 `EditorCore`、provider manager、overlay/runtime 对象、定时器、listener、receiver 以及其他 session 级状态。`SweetEditorController` 是宿主持有的对外转发入口，用于调用这一运行时；它不是已绑定 widget、渲染运行时或 `EditorCore` 实例的所有者。

- MUST 提供 `SweetEditorController` 类，作为外部控制编辑器的唯一命令式入口
- `SweetEditorController` MUST 暴露第 3.2 节定义的宿主可见 API，以及后续章节中针对已实现可选模块定义的宿主可见模块级公共 API
- 第 3.1 节的 `EditorCore` 方法属于 bridge/runtime API，默认 MUST NOT 视为 `SweetEditorController` 的必需方法
- 控件入口类（如 `SweetEditorWidget`、`SweetEditorView`）MUST 接受 `SweetEditorController` 作为构造参数
- Controller 与 editor 的关联 MUST 在该 editor 实例构造时建立，并在该 editor 实例生命周期内保持固定不变
- 控件/session MAY 使用内部 `bind(editorApi)` / `unbind()` hook，但这些 hook 表示该 editor 实例的首次 attach 和终结性 detach，而不是可复用的重新绑定周期

```dart
// Flutter
final controller = SweetEditorController();
SweetEditorWidget(controller: controller);
controller.whenReady(() {
    controller.loadDocument(doc);
    controller.applyTheme(EditorTheme.dark());
});
```

#### 3.0.3 `SweetEditorController` 规范

| 规则 | 约束级别 | 说明 |
|---|---|---|
| Controller 角色 | **MUST** | `SweetEditorController` MUST 是且仅是面向一个声明式 editor 实例的宿主可见转发句柄。MUST NOT 将其视为已绑定 `View` / `Control` / `Widget`、渲染运行时、overlay 运行时、`EditorCore` 生命周期、provider 注册或其他 session 级运行时状态的所有者 |
| 生命周期回调 | **MUST** | 提供 `whenReady(callback)` 方法，在控件挂载完成后回调；若调用时已就绪则立即执行 |
| 首次 attach 前的调用行为 | **MUST** | 在声明式平台上，关联的 editor 实例完成首次 attach 之前，controller 的命令式调用都尚未可用。变更类调用 MUST 被忽略或拒绝，而不是被排队。getter 调用（包括 `getSettings()`）SHOULD 返回 `null` 或默认值，且 MUST NOT 抛出异常。宿主 SHOULD 只在 `whenReady()` 或其他等价 ready 信号之后调用 controller 的命令式 API。若 document、theme、settings、key map 或其他首帧前必须存在的配置需要在首次 attach 前确定，MUST 通过声明式构造参数或等价的平台原生初始化路径提供。平台 MUST NOT 为了响应 pre-ready 调用而偷偷创建隐藏运行时或隐藏暂存层 |
| 内部 attach / detach | **MUST** | 提供内部 attach/detach 机制（例如 `bind(editorApi)` / `unbind()`，命名 MAY 因平台而异）。这些 hook 表示关联 editor 实例的首次 attach 与终结性 detach，而不是可复用的重新绑定协议 |
| 多次绑定 | **MUST** | 同一 Controller 实例 MUST NOT 同时绑定多个控件，且在首次建立关联后 MUST NOT 重新绑定到其他 widget/session/editor 实例 |
| Public API 覆盖 | **MUST** | Controller MUST 暴露第 3.2 节定义的全部必需宿主可见公共操作，以及后续章节中已实现模块对应的宿主可见公共操作 |
| API 一致性 | **SHOULD** | 方法名、语义与返回行为 SHOULD 遵循第 3.2 节的宿主可见 Public API 表以及后续章节中已实现模块的宿主可见公共 API 表。平台 MAY 额外提供符合自身语言习惯的重载、便捷别名或等价入口形态，只要其与标准 API 的映射保持清晰且无歧义 |
| getter 方法 | **SHOULD** | 在关联 editor 实例尚未就绪，或在其终结性 teardown 之后，getter 方法（如 `getDocument()`、`getCursorPosition()`、`getSettings()`）SHOULD 返回 `null` 或默认值，MUST NOT 抛出异常 |
| 显式 teardown（若提供） | **MAY** | 平台 MAY 提供 `dispose()` / `close()` / `release()` 等显式 terminal controller teardown 方法。若宿主生命周期或平台原生销毁语义已经能够保证 terminal teardown，则无论 GC 还是非 GC 平台，都不强制额外暴露显式 teardown API |
| 显式 teardown 语义 | **MUST** | 若平台提供显式 controller teardown 方法，该方法 MUST 表示 controller 的终结性 teardown，而不是普通 widget 生命周期事件。它 MUST 先从关联 widget/session detach（如果仍已 attach），然后只释放 controller 自身持有的 ready 回调、内部 pending callback 与引用链。它 MUST NOT 假定 controller 拥有 session 级 provider 注册或运行时对象，也 MUST NOT 直接销毁 `View` / `Control` / `Widget` 本身。teardown 后 Controller MUST 进入终结失活状态：后续方法调用 MUST 为 no-op 或返回默认空值 |

> 保留同一个已挂载 editor runtime 的普通声明式重建不属于重新绑定。重新绑定仅指将一个 `SweetEditorController` 关联到另一个 `SweetEditor` 实例，而这在本标准中是不允许的。

#### 3.0.4 平台分类参考

| UI 范式 | 框架 | API 载体 |
|---|---|---|
| 命令式 | Android View, UIKit, AppKit, Swing, WinForms | 控件入口类直接暴露 |
| 声明式 | Flutter, Jetpack Compose, SwiftUI, ArkUI, React, Vue | `SweetEditorController` |
| 混合 | React Native, Qt (QML + C++) | 按主要 UI 层范式决定 |

> 如果一个平台同时提供命令式和声明式两种 API（如 Apple 同时有 UIKit 和 SwiftUI），则命令式 API 在控件类上暴露，声明式封装 MUST 额外提供 Controller。

#### 3.0.5 声明式初始化输入

在声明式平台上，控件入口类除了必须接收 `controller` 构造参数外，MAY 额外暴露声明式初始化输入。这些输入属于声明式 widget/view 描述的一部分，而不是命令式 controller API 的一部分。

| 输入 | 约束级别 | 说明 |
|---|---|---|
| `controller` | **MUST** | 与该 editor 实例关联的 `SweetEditorController` |
| `document` | **MAY** | 首个 attach 后 editor session 应可见的初始 `Document` 对象 |
| `text` | **MAY** | 初始纯文本内容。若未提供 `document` 而提供了 `text`，平台 MUST 基于该文本为首个 attach 后 editor session 物化一个等价的 `Document` |
| `theme` | **MAY** | 应应用到首个 attach 后 editor session 的初始主题 |
| `settings` | **MAY** | 用于配置首个 attach 后 editor session 的初始 settings 对象或平台等价 settings 快照 |
| `keyMap` | **MAY** | 首个 attach 后 editor session 使用的初始 key map 或平台等价键盘映射 |

标准不要求所有声明式平台使用完全相同的构造参数名、属性名或 widget 语法，但其语义映射 SHOULD 保持清晰且无歧义。

如果声明式平台暴露了这些初始化输入，它们 MUST 被视为声明式构造/配置输入，而不是 pre-ready controller 调用。它们 MUST NOT 依赖隐藏运行时或隐藏暂存层。若同时提供 `document` 和 `text`，则 `document` MUST 优先，`text` MUST 被忽略。若仅使用 `text` 而未提供 `document`，平台 MUST 为关联的 editor session 物化一个等价的当前 `Document`，并且在 editor ready 之后，`getDocument()` MUST 返回这个被物化出来的 `Document`。后续对这些输入的修改遵循平台自身的声明式更新模型。在同一个已挂载 editor runtime 上修改 `text`，其语义等价于用一个新物化出来的 `Document` 替换当前文档。平台 MAY 将其应用到当前已挂载的 editor runtime。若平台语义上必须创建新的 editor 实例，则宿主代码 MUST 同时为该新实例提供新的 `SweetEditorController`。将同一个 controller 复用于新的 editor 实例会构成 controller 重新绑定，而这在本标准中是不允许的。

---

### 3.1 `EditorCore` Public API

第 3.1 节定义由 `EditorCore` 承载的 bridge/runtime API。这里包含低层渲染快照、手势循环、键盘分发和动画 tick 方法。除非平台显式选择对外暴露 `EditorCore` 本身，否则这些方法不属于默认的宿主可见编辑器接口表面。

| 功能 | 标准名称 | 允许的变体 |
|---|---|---|
| **配置** | | |
| 加载文档 | `loadDocument(doc)` | — |
| 设置视口 | `setViewport(w, h)` | — |
| 字体变更通知 | `onFontMetricsChanged()` | — |
| 折叠箭头模式 | `setFoldArrowMode(mode)` | — |
| 自动换行模式 | `setWrapMode(mode)` | — |
| Tab 大小 | `setTabSize(size)` | — |
| 空格缩进 | `setInsertSpaces(enabled)` | — |
| 缩放比例 | `setScale(scale)` | — |
| 行间距 | `setLineSpacing(add, mult)` | — |
| 内容起始内边距 | `setContentStartPadding(padding)` | — |
| 分割线显示 | `setShowSplitLine(show)` | — |
| 当前行渲染模式 | `setCurrentLineRenderMode(mode)` | — |
| Gutter 固定 | `setGutterSticky(sticky)` | — |
| Gutter 可见性 | `setGutterVisible(visible)` | — |
| 选区手柄配置 | `setHandleConfig(...)` | — |
| 滚动条配置 | `setScrollbarConfig(...)` | — |
| **渲染模型** | | |
| 构建渲染模型 | `buildRenderModel()` | — |
| 获取布局指标 | `getLayoutMetrics()` | property: `layoutMetrics` / `LayoutMetrics { get; }` |
| **手势 / 键盘** | | |
| 处理手势事件 | `handleGestureEvent(...)` | — |
| 处理手势事件（扩展） | `handleGestureEventEx(...)` | — |
| 边缘滚动 tick | `tickEdgeScroll()` | — |
| 惯性滚动 tick | `tickFling()` | — |
| 动画 tick | `tickAnimations()` | — |
| 处理键盘事件 | `handleKeyEvent(...)` | — |
| 设置 keymap | `setKeyMap(keyMap)` | — |
| **文本编辑** | | |
| 插入文本 | `insertText(text)` | — |
| 替换文本 | `replaceText(range, text)` | — |
| 删除文本 | `deleteText(range)` | — |
| 退格 | `backspace()` | — |
| 向前删除 | `deleteForward()` | — |
| 上移行 | `moveLineUp()` | — |
| 下移行 | `moveLineDown()` | — |
| 向上复制行 | `copyLineUp()` | — |
| 向下复制行 | `copyLineDown()` | — |
| 删除行 | `deleteLine()` | — |
| 上方插入空行 | `insertLineAbove()` | — |
| 下方插入空行 | `insertLineBelow()` | — |
| **撤销 / 重做** | | |
| 撤销 | `undo()` | — |
| 重做 | `redo()` | — |
| 可撤销 | `canUndo()` | — |
| 可重做 | `canRedo()` | — |
| **光标 / 选区** | | |
| 设置光标位置 | `setCursorPosition(line, col)` | — |
| 获取光标位置 | `getCursorPosition()` | property: `cursorPosition` / `CursorPosition { get; }` |
| 全选 | `selectAll()` | — |
| 设置选区 | `setSelection(sL, sC, eL, eC)` | — |
| 获取选区 | `getSelection()` | property: `selection` / `Selection { get; }` |
| 获取选中文本 | `getSelectedText()` | property: `selectedText` / `SelectedText { get; }` |
| 光标处单词范围 | `getWordRangeAtCursor()` | property: `wordRangeAtCursor` / `WordRangeAtCursor { get; }` |
| 光标处单词文本 | `getWordAtCursor()` | property: `wordAtCursor` / `WordAtCursor { get; }` |
| 光标左移 | `moveCursorLeft(extend)` | — |
| 光标右移 | `moveCursorRight(extend)` | — |
| 光标上移 | `moveCursorUp(extend)` | — |
| 光标下移 | `moveCursorDown(extend)` | — |
| 光标移至行首 | `moveCursorToLineStart(extend)` | — |
| 光标移至行尾 | `moveCursorToLineEnd(extend)` | — |
| **IME** | | |
| IME 同步与上下文 | `getImeSyncSnapshot()` / `getImeInputContext(...)` / `getImeTextModelInputContext(...)` | 代表入口；平台按自身 IME 模型选择 |
| 键盘脚本分类 | `setImeKeyboardScriptClass(script)` / `getImeKeyboardScriptClass()` | — |
| preedit / composing 更新 | `updateImePreedit(...)` / `setImeComposingText(...)` | 代表入口 |
| 提交与替换 | `commitImeText(...)` / `replaceImeText(...)` | 代表入口；offset / context 变体按平台能力选择 |
| 结束或取消 preedit | `finishImePreedit()` / `cancelImePreedit()` | — |
| 标记 composition 范围 | `markImeDocumentRange(...)` / `markImeInputContextRange(...)` | 代表入口 |
| 文本模型状态同步 | `updateImeTextModelState(...)` / `updateImeTextModelDelta(...)` | 适用于暴露完整 text model 的平台 |
| IME 删除 | `deleteImeBackward(length, unit)` / `deleteImeForward(length, unit)` / `deleteImeSurrounding(before, after, unit)` | — |
| IME 驱动选区同步 | `notifyImeSelectionChanged(range)` / `notifyImeCursorChanged(cursor)` | — |
| Composition 范围 | `getComposingRange()` / `getComposingSessionRange()` | — |
| 是否组合中 | `isComposing()` | property: `isComposing` / `IsComposing { get; }` |
| **只读 / 缩进** | | |
| 设置只读 | `setReadOnly(readOnly)` | — |
| 是否只读 | `isReadOnly()` | property: `isReadOnly` / `IsReadOnly { get; }` |
| 设置自动缩进 | `setAutoIndentMode(mode)` | — |
| 获取自动缩进 | `getAutoIndentMode()` | property: `autoIndentMode` / `AutoIndentMode { get; }` |
| 设置退格反缩进 | `setBackspaceUnindent(enabled)` | — |
| **导航 / 滚动** | | |
| 滚动到行 | `scrollToLine(line, behavior)` | — |
| 跳转到位置 | `gotoPosition(line, col)` | — |
| 确保光标可见 | `ensureCursorVisible()` | — |
| 设置滚动位置 | `setScroll(x, y)` | — |
| 获取滚动指标 | `getScrollMetrics()` | property: `scrollMetrics` / `ScrollMetrics { get; }` |
| 获取位置矩形 | `getPositionRect(line, col)` | — |
| 获取光标矩形 | `getCursorRect()` | property: `cursorRect` / `CursorRect { get; }` |
| **样式 / 高亮** | | |
| 注册文本样式 | `registerTextStyle(id, color, bg, fontStyle)` | — |
| 批量注册样式 | `registerBatchTextStyles(data)` | — |
| 设置行样式 | `setLineSpans(line, layer, spans)` | — |
| 批量设置行样式 | `setBatchLineSpans(layer, entries)` | — |
| 清除行样式 | `clearLineSpans(line, layer)` | — |
| 按 layer 清除高亮 | `clearHighlights(layer)` | — |
| 清除所有高亮 | `clearHighlights()` | — |
| **Inlay Hint** | | |
| 设置行 Inlay Hint | `setLineInlayHints(line, hints)` | — |
| 批量设置 Inlay Hint | `setBatchLineInlayHints(entries)` | — |
| 清除 Inlay Hint | `clearInlayHints()` | — |
| **Phantom Text** | | |
| 设置行 Phantom Text | `setLinePhantomTexts(line, phantoms)` | — |
| 批量设置 Phantom Text | `setBatchLinePhantomTexts(entries)` | — |
| 清除 Phantom Text | `clearPhantomTexts()` | — |
| **Gutter Icon** | | |
| 设置行 Gutter Icon | `setLineGutterIcons(line, icons)` | — |
| 批量设置 Gutter Icon | `setBatchLineGutterIcons(entries)` | — |
| 设置最大 Gutter Icon 数 | `setMaxGutterIcons(count)` | — |
| 清除 Gutter Icon | `clearGutterIcons()` | — |
| **CodeLens** | | |
| 设置行 CodeLens | `setLineCodeLens(line, items)` | — |
| 批量设置 CodeLens | `setBatchLineCodeLens(entries)` | — |
| 清除 CodeLens | `clearCodeLens()` | — |
| **Link** | | |
| 设置行 links | `setLineLinks(line, links)` | — |
| 批量设置 links | `setBatchLineLinks(entries)` | — |
| 清除 links | `clearLinks()` | — |
| **Diagnostic** | | |
| 设置行诊断 | `setLineDiagnostics(line, items)` | — |
| 批量设置诊断 | `setBatchLineDiagnostics(entries)` | — |
| 清除诊断 | `clearDiagnostics()` | — |
| **Guide** | | |
| 设置缩进引导线 | `setIndentGuides(guides)` | — |
| 设置括号引导线 | `setBracketGuides(guides)` | — |
| 设置流程引导线 | `setFlowGuides(guides)` | — |
| 设置分隔线 | `setSeparatorGuides(guides)` | — |
| 清除引导线 | `clearGuides()` | — |
| **Bracket** | | |
| 设置括号对 | `setBracketPairs(open, close)` | — |
| 设置自动闭合对 | `setAutoClosingPairs(open, close)` | — |
| 设置匹配括号 | `setMatchedBrackets(oL, oC, cL, cC)` | — |
| 清除匹配括号 | `clearMatchedBrackets()` | — |
| **折叠** | | |
| 设置折叠区域 | `setFoldRegions(regions)` | — |
| 切换折叠 | `toggleFoldAt(line)` | Swift: `toggleFold(at:)` |
| 折叠 | `foldAt(line)` | Swift: `fold(at:)` |
| 展开 | `unfoldAt(line)` | Swift: `unfold(at:)` |
| 全部折叠 | `foldAll()` | — |
| 全部展开 | `unfoldAll()` | — |
| 行是否可见 | `isLineVisible(line)` | — |
| **清除** | | |
| 清除所有装饰 | `clearAllDecorations()` | — |
| **Linked Editing** | | |
| 插入 Snippet | `insertSnippet(template)` | — |
| 开始联动编辑 | `startLinkedEditing(model)` | — |
| 是否联动编辑中 | `isInLinkedEditing()` | property: `isInLinkedEditing` / `IsInLinkedEditing { get; }` |
| 下一个 Tab Stop | `linkedEditingNext()` | — |
| 上一个 Tab Stop | `linkedEditingPrev()` | — |
| 取消联动编辑 | `cancelLinkedEditing()` | — |

IME API 是平台输入事件进入 core 的请求入口。平台标准约束的是语义能力族，而不是要求每个平台调用全部 bridge 函数。平台层 MUST NOT 因为系统 IME 请求 surrounding text、候选上下文或光标矩形，就创建 editor composition。是否建立 composition 只取决于系统 IME 是否通过 composing / marked / preedit API 明确声明了组合文本或组合范围；提交、替换、删除和 selection 同步仍由 core 按 `docs/zh/ime-composition-standard.md` 裁决。

平台层向 core 标记 composition 范围时 MUST 明确这是平台 IME 声明的 composing / marked range。Android 的 `InputConnection.setComposingRegion`、Apple marked range、Windows TSF composition range 都不能由平台层直接当成整词替换命令。光标进入英文单词时平台层和 core 都不得自动开启整词 composition。

平台层 MUST 将光标变化、选区变化、composition 更新、候选提交、删除、finish/cancel 等事件同步给 core。中文键盘未声明 composition 时只表示不建立 SweetEditor 可见 composition；这不能被实现成禁用系统 IME、阻断中文候选提交或阻断中文联想候选。

IME 相关 offset MUST 明确坐标空间：文档 line/column API 使用 `TextRange`；文档 offset API 使用完整文档 offset；input-context / text-model API 使用以 `documentStartOffset` 为基准的上下文 offset。平台实现 MUST NOT 在这些坐标空间之间隐式混用。

> payload 类 API（如 `setLineSpans`、`setBatchLineSpans`）各平台 MUST 提供高层 typed 封装（如 `setLineSpans(line, layer, spans: List<StyleSpan>)`）。当宿主语言存在自然的公开二进制载体（如 `ByteBuffer`、`NSData`、`byte[]`、`Uint8List`）时，平台 SHOULD 额外公开 raw/binary payload API。若 typed API 与 payload API 同时存在，两者的参数语义与最终 Core 行为 MUST 完全一致。payload 的编码格式由平台自行定义。

#### 3.1.1 IME API 要求级别

`EditorCore` IME API 是 bridge/runtime API。它们用于标准化平台输入适配和可测试性，不要求全部暴露在宿主可见的 `SweetEditor` / controller API 上，也不要求每个平台调用完整函数集合。条件性 MUST 表示平台不需要凭空合成自身不会收到的原生 IME 能力，但一旦平台存在该能力，就 MUST 映射到对应的 core 语义能力族。

| API / 类型 | 要求 | 说明 |
|---|---|---|
| IME 协议类型 | MUST | 至少包含 `ImeActionResult`、`ImeSyncSnapshot`、`ImeInputContext`、`ImeTextRange`、`ImeScriptClass`、`ImePreeditStorage`、`ImeContextPolicy`、`ImeInputContextKind`；支持 text-model 同步的平台还 MUST 包含 `ImeTextModelMode` |
| `ImeTextUnit` | SHOULD / 条件性 MUST | 暴露 unit-aware 删除 API 时 MUST 存在；稳定值为 `GRAPHEME = 0`、`CODE_POINT = 1` |
| 同步快照能力 | MUST | 平台输入适配层 MUST 能处理 core 返回的 `ImeActionResult.sync`；需要主动查询时使用 `getImeSyncSnapshot()` 或等价桥接入口 |
| 键盘脚本 hint 能力 | SHOULD / 条件性 MUST | SHOULD 记录键盘脚本 hint；平台提供 script hint 时 MUST 映射 |
| preedit / composing 能力 | SHOULD / 条件性 MUST | 平台收到原生 preedit、composing text 或 marked text 时 MUST 映射到 core 的 preedit / composing 语义族 |
| commit / replacement 能力 | MUST / 条件性 MUST | 原生提交 MUST 映射；平台报告明确 replacement 范围时 MUST 映射到 document、input-context 或 text-model 中对应的 replacement 语义族 |
| document range / offset 能力 | 条件性 MUST | 平台报告文档范围或文档 offset 时 MUST 使用文档坐标语义，不能混入 input-context offset |
| input-context 能力 | 条件性 MUST | 平台基于 surrounding text / extracted text window 操作时 MUST 使用以 `documentStartOffset` 为基准的上下文 offset 语义 |
| text-model state / delta 能力 | 条件性 MUST | 平台原生 API 暴露完整文本模型快照或增量时 SHOULD 使用 text-model 语义族，而不是强行拆成旧 preedit / commit 流程 |
| 删除能力 | SHOULD / 条件性 MUST | 平台请求 backward、forward 或 surrounding 删除时 MUST 映射到 core 删除语义族 |
| selection / cursor 同步能力 | SHOULD / 条件性 MUST | IME 驱动 selection、cursor 或 text-model selection 同步时 MUST 映射到 core |
| `isComposing()` | MUST | 报告 editor-visible composition 是否活跃 |
| `getComposingRange()` | SHOULD | 供平台同步和诊断使用；未活跃时返回无 range |
| `getComposingSessionRange()` | SHOULD | 供平台同步和诊断使用；未活跃时返回无 range |

`ImeSyncSnapshot` 的语义字段 MUST 覆盖：文档光标、文档选区、是否存在 composition session、可见 composition 范围、平台 marked range、platform text window 文本及其 start offset、selection/composing offsets、`ImePreeditStorage`、`ImeContextPolicy`、以及是否要求平台清除 preedit。`ImeInputContext` 的语义字段 MUST 覆盖：`id`、`revision`、`documentStartOffset`、`text`、`selection`、`hasComposition`、`composition`、`kind`。`ImeActionResult` 的语义字段 MUST 覆盖：`handled`、`contentChanged`、`cursorChanged`、`selectionChanged`、`editResult`、`sync`。

完整 core bridge 函数列表以 `src/include/editor_core.h` 与 `src/include/c_api.h` 为准。本标准只约束平台必须保持的 IME 语义和协议字段，不要求把每个 core bridge 函数都暴露为宿主可见 API。

#### 3.1.2 `EditorOptions` 标准字段

`EditorOptions` 是 bridge 层配置 payload。平台 MAY 将其暴露为公共类型，也 MAY 仅在内部使用；但若它跨越 bridge 边界或被序列化为二进制 payload，下列字段语义与顺序 MUST 与 Core 保持一致：

| 字段 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `touchSlop` | float | `10` | 超过该阈值才将手势视为移动，否则仍按 tap 处理 |
| `doubleTapTimeout` | int64 | `300` | 双击识别超时，单位毫秒 |
| `longPressMs` | int64 | `500` | 长按识别超时，单位毫秒 |
| `flingFriction` | float | platform-defined | fling 摩擦系数；平台 MAY 根据原生交互手感自行调整 |
| `flingMinVelocity` | float | platform-defined | fling 最小速度阈值，单位 px/s；平台 MAY 根据原生交互手感自行调整 |
| `flingMaxVelocity` | float | platform-defined | fling 最大速度上限，单位 px/s；平台 MAY 根据原生交互手感自行调整 |
| `maxUndoStackSize` | uint64 / size_t 对齐整数 | `512` | undo 栈最大深度；`0` 表示无限制 |
| `keyChordTimeoutMs` | int64 | `2000` | 等待多段 key chord 完成的超时时间 |
| `revealSelectionEndOnSelectAll` | boolean | `false` | 为 true 时，`selectAll()` 在更新选区后 SHOULD 让选区尾端可见 |

> 若平台将 `EditorOptions` 序列化为二进制 bridge payload，字段顺序 MUST 与 Core 保持一致：`touch_slop`、`double_tap_timeout`、`long_press_ms`、`fling_friction`、`fling_min_velocity`、`fling_max_velocity`、`max_undo_stack_size`、`key_chord_timeout_ms`、`reveal_selection_end_on_select_all`。

### 3.2 宿主可见的编辑器公共 API

第 3.2 节定义宿主可见的编辑器 API。这里有意排除了低层 `EditorCore` 手势循环、动画 tick 和渲染模型生成方法，例如 `handleGestureEvent(...)`、`tickEdgeScroll()`、`buildRenderModel()`。`flush()` 继续保留在这一层，作为宿主触发的同步 API。命令式平台上，该 API 由控件入口类直接暴露；声明式平台上，该 API 由 `SweetEditorController` 暴露，并转发到关联的 `SweetEditor` runtime，而不意味着 controller 持有 editor/session 状态。除 `whenReady(...)` 本身及等价的 ready helper 外，声明式平台上的 controller 命令式调用只有在关联 editor 实例 ready 之后才有效。若 document、theme、settings、key map 或其他首帧前必须存在的配置需要在首次 attach 前确定，MUST 通过声明式构造参数或等价的平台原生初始化路径提供。

| 功能 | 标准名称 | 允许的变体 |
|---|---|---|
| **文档 / 主题** | | |
| 加载文档 | `loadDocument(doc)` | — |
| 获取文档 | `getDocument()` | property: `document` / `Document { get; }` |
| 应用主题 | `applyTheme(theme)` | — |
| 获取主题 | `getTheme()` | property: `theme` / `Theme { get; }` |
| **配置** | | |
| 获取配置对象 | `getSettings()` | property: `settings` / `Settings { get; }` |
| 获取 keymap *(SHOULD)* | `getKeyMap()` | property: `keyMap` / `KeyMap { get; }` |
| 设置 keymap | `setKeyMap(keyMap)` | — |
| 图标提供者 | `setEditorIconProvider(provider)` | — |
| **文本编辑** | | |
| 插入文本 | `insertText(text)` | — |
| 替换文本 | `replaceText(range, text)` | — |
| 删除文本 | `deleteText(range)` | — |
| 上移行 | `moveLineUp()` | — |
| 下移行 | `moveLineDown()` | — |
| 向上复制行 | `copyLineUp()` | — |
| 向下复制行 | `copyLineDown()` | — |
| 删除行 | `deleteLine()` | — |
| 上方插入空行 | `insertLineAbove()` | — |
| 下方插入空行 | `insertLineBelow()` | — |
| **撤销 / 重做** | | |
| 撤销 | `undo()` | — |
| 重做 | `redo()` | — |
| 可撤销 | `canUndo()` | — |
| 可重做 | `canRedo()` | — |
| **剪贴板（MAY）** | | |
| 复制 | `copyToClipboard()` | — |
| 粘贴 | `pasteFromClipboard()` | — |
| 剪切 | `cutToClipboard()` | — |
| **光标 / 选区** | | |
| 全选 | `selectAll()` | — |
| 获取选中文本 | `getSelectedText()` | property: `selectedText` / `SelectedText { get; }` |
| 设置选区 | `setSelection(sL, sC, eL, eC)` | — |
| 获取选区 | `getSelection()` | property: `selection` / `Selection { get; }` |
| 设置光标 | `setCursorPosition(pos)` | — |
| 获取光标 | `getCursorPosition()` | property: `cursorPosition` / `CursorPosition { get; }` |
| 光标处单词范围 | `getWordRangeAtCursor()` | property: `wordRangeAtCursor` / `WordRangeAtCursor { get; }` |
| 光标处单词文本 | `getWordAtCursor()` | property: `wordAtCursor` / `WordAtCursor { get; }` |
| **导航 / 滚动** | | |
| 跳转到位置 | `gotoPosition(line, col)` | — |
| 滚动到行 | `scrollToLine(line, behavior)` | — |
| 设置滚动位置 | `setScroll(x, y)` | — |
| 获取滚动指标 | `getScrollMetrics()` | property: `scrollMetrics` / `ScrollMetrics { get; }` |
| 获取位置矩形 | `getPositionRect(line, col)` | — |
| 获取光标矩形 | `getCursorRect()` | property: `cursorRect` / `CursorRect { get; }` |
| **折叠** | | |
| 切换折叠 | `toggleFoldAt(line)` | Swift: `toggleFold(at:)` |
| 折叠单行 | `foldAt(line)` | — |
| 展开单行 | `unfoldAt(line)` | — |
| 行是否可见 | `isLineVisible(line)` | — |
| 全部折叠 | `foldAll()` | — |
| 全部展开 | `unfoldAll()` | — |
| **语言 / 元数据** | | |
| 设置语言配置 | `setLanguageConfiguration(config)` | — |
| 获取语言配置 | `getLanguageConfiguration()` | property: `languageConfiguration` / `LanguageConfiguration { get; }` |
| 设置元数据 | `setMetadata(metadata)` | — |
| 获取元数据 | `getMetadata()` | property: `metadata` / `Metadata { get; }` |
| **Provider 管理** | | |
| 添加装饰 Provider | `addDecorationProvider(provider)` | `attachDecorationProvider(provider)` |
| 移除装饰 Provider | `removeDecorationProvider(provider)` | `detachDecorationProvider(provider)` |
| 请求装饰刷新 | `requestDecorationRefresh()` | — |
| 添加补全 Provider | `addCompletionProvider(provider)` | `attachCompletionProvider(provider)` |
| 移除补全 Provider | `removeCompletionProvider(provider)` | `detachCompletionProvider(provider)` |
| 添加换行 Provider | `addNewLineActionProvider(provider)` | `attachNewLineActionProvider(provider)` |
| 移除换行 Provider | `removeNewLineActionProvider(provider)` | `detachNewLineActionProvider(provider)` |
| **补全** | | |
| 触发补全 | `triggerCompletion()` | — |
| 展示补全项 | `showCompletionItems(items)` | — |
| 关闭补全 | `dismissCompletion()` | — |
| 配置补全项渲染 | `setCompletionItemRenderer(renderer)` | `setCompletionItemViewFactory(factory)`, `setCompletionCellRenderer(renderer)`, 其他平台惯用的渲染定制 API |
| **样式** | | |
| 注册文本样式 | `registerTextStyle(id, ...)` | — |
| 批量注册文本样式 | `registerBatchTextStyles(stylesById)` | — |
| **Decoration / Adornment 写入** | | |
| 设置单行 spans | `setLineSpans(line, layer, spans)` | — |
| 批量设置 spans | `setBatchLineSpans(layer, spansByLine)` | — |
| 设置单行 inlay hints | `setLineInlayHints(line, hints)` | — |
| 批量设置 inlay hints | `setBatchLineInlayHints(hintsByLine)` | — |
| 设置单行 phantom texts | `setLinePhantomTexts(line, phantoms)` | — |
| 批量设置 phantom texts | `setBatchLinePhantomTexts(phantomsByLine)` | — |
| 设置单行 gutter icons | `setLineGutterIcons(line, icons)` | — |
| 批量设置 gutter icons | `setBatchLineGutterIcons(iconsByLine)` | — |
| 设置单行 CodeLens | `setLineCodeLens(line, items)` | — |
| 批量设置 CodeLens | `setBatchLineCodeLens(itemsByLine)` | — |
| 设置单行 links | `setLineLinks(line, links)` | — |
| 批量设置 links | `setBatchLineLinks(linksByLine)` | — |
| 设置单行 diagnostics | `setLineDiagnostics(line, items)` | — |
| 批量设置 diagnostics | `setBatchLineDiagnostics(diagsByLine)` | — |
| 设置 indent guides | `setIndentGuides(guides)` | — |
| 设置 bracket guides | `setBracketGuides(guides)` | — |
| 设置 flow guides | `setFlowGuides(guides)` | — |
| 设置 separator guides | `setSeparatorGuides(guides)` | — |
| 设置 fold regions | `setFoldRegions(regions)` | — |
| **Decoration / Adornment 清理** | | |
| 清除高亮 | `clearHighlights()` | — |
| 按 layer 清除高亮 | `clearHighlights(layer)` | — |
| 清除 inlay hints | `clearInlayHints()` | — |
| 清除 phantom texts | `clearPhantomTexts()` | — |
| 清除 gutter icons | `clearGutterIcons()` | — |
| 清除 CodeLens | `clearCodeLens()` | — |
| 清除 links | `clearLinks()` | — |
| 清除 guides | `clearGuides()` | — |
| 清除 diagnostics | `clearDiagnostics()` | — |
| 清除所有装饰 | `clearAllDecorations()` | — |
| **刷新** | | |
| 刷新 | `flush()` | — |
| **查询** | | |
| 可见行范围 | `getVisibleLineRange()` | property: `visibleLineRange` / `VisibleLineRange { get; }` |
| 总行数 | `getTotalLineCount()` | property: `totalLineCount` / `TotalLineCount { get; }` |
| 位置上的 link target | `getLinkTargetAt(line, column)` | 返回 `String` / non-null string；未命中时返回空字符串 |

> Provider 管理方法的标准命名为 `add` / `remove`。各平台 MAY 按自身惯例使用语义等价的变体（如 `attach` / `detach`、`register` / `unregister` 等）。

> 剪贴板方法（`copyToClipboard`, `pasteFromClipboard`, `cutToClipboard`）为 **MAY**，因为剪贴板是平台特定的。

> 事件暴露方式不要求统一方法名。平台 MUST 按第 11 节提供类型安全事件机制，可以采用 `subscribe` / `unsubscribe`、平台原生 `event` / delegate、typed `Stream` getter、signal / observer 等等效形式。

> 第 3.2 节是宿主可见的编辑器公共 API 索引。部分模块相关的接口、数据模型和回调契约会在后续章节继续补充定义（例如第 4、5、6、7、10 节）；其中第 4、5、10 节定义必需模块契约，第 6、7 节定义可选或条件模块契约。

---

## 4. Provider 接口（MUST）

> **通用规则：**
> - `provideDecorations` 和 `provideCompletions` MUST 同时支持**同步**和**异步**结果交付
> - `DecorationProvider` MUST 支持多次结果更新，同一个请求可以产生 0 次、1 次或多次连续 snapshot
> - `CompletionProvider` MUST 至少支持单次结果交付，MAY 支持多次 / 增量结果更新
> - 进行中的 decoration / completion 请求 MUST 具有明确的取消 / 过期契约；一旦请求被取消或过期，该请求的任何延迟结果 MUST 被忽略
> - 平台 MAY 使用 Receiver 回调、`Future` / `Promise` / `Task`、协程 / `suspend` API、stream / observable，或其他符合平台习惯的异步形式暴露 Provider 结果
> - **Receiver 回调模式仍是推荐的公共接口形态**，因为它天然同时支持同步返回、异步返回、多次更新和取消检查
> - 若平台不暴露 Receiver 形态，仍 MUST 文档化其所选 API 如何表达即时交付、延后交付、适用场景下的多次更新，以及取消 / 过期语义
> - 同一类型 Provider 支持注册多个实例，Manager 负责遍历并合并结果
> - Provider-Manager 模式（注册 -> 遍历 -> 分发）MUST 在所有平台保持一致

### 4.1 DecorationProvider

#### 推荐的 Receiver 签名

```
interface DecorationProvider {
    getCapabilities() -> Set<DecorationType>
    provideDecorations(context: DecorationContext, receiver: DecorationReceiver) -> void
}

interface DecorationReceiver {
    accept(result: DecorationResult) -> boolean
    isCancelled() -> boolean
}
```

> 平台 MAY 暴露与 `DecorationReceiver` 语义等价的异步 API，而不是显式 Receiver 类型；但契约 MUST 仍支持即时结果、延后结果以及取消 / 过期检查。若平台暴露显式 Receiver 类型，推荐命名为 `DecorationReceiver`。

#### DecorationContext MUST 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `visibleLineRange` | IntRange | 当前 decoration 上下文的行范围。通常对应可见行范围，但平台 MAY 根据 overscan 或其他策略适当扩大 |
| `totalLineCount` | int | 文档总行数 |
| `textChanges` | List\<TextChange\> | 本次刷新周期累计的文本变更；空列表表示非文本变更触发 |
| `languageConfiguration` | LanguageConfiguration? | 当前语言配置（nullable） |
| `editorMetadata` | EditorMetadata? | 当前编辑器元数据（nullable） |

#### ApplyMode 枚举（MUST）

每种装饰数据 MUST 有对应的 `ApplyMode`，控制 Manager 合并时的行为：

| 值 | 说明 |
|---|---|
| `MERGE` | 与已有数据合并（默认） |
| `REPLACE_ALL` | 替换全部已有数据 |
| `REPLACE_RANGE` | 仅替换 `visibleLineRange`（即当前 decoration 上下文范围）内的数据 |

当多个 Provider 返回不同的 ApplyMode 时，Manager MUST 按优先级取最高：`REPLACE_ALL` > `REPLACE_RANGE` > `MERGE`。

#### DecorationResult MUST 字段

`DecorationResult` 包含 13 种装饰数据，每种数据都有对应的 `ApplyMode`（默认 `MERGE`）。数据类型 MUST 使用 Core 层定义的标准类型（如 `StyleSpan`、`InlayHint`、`CodeLensItem`、`LinkSpan`、`Diagnostic` 等）。

| 数据字段 | 类型 | ApplyMode 字段 |
|---|---|---|
| `syntaxSpans` | Map\<int, List\<StyleSpan\>\>? | `syntaxSpansMode` |
| `semanticSpans` | Map\<int, List\<StyleSpan\>\>? | `semanticSpansMode` |
| `inlayHints` | Map\<int, List\<InlayHint\>\>? | `inlayHintsMode` |
| `diagnostics` | Map\<int, List\<Diagnostic\>\>? | `diagnosticsMode` |
| `indentGuides` | List\<IndentGuide\>? | `indentGuidesMode` |
| `bracketGuides` | List\<BracketGuide\>? | `bracketGuidesMode` |
| `flowGuides` | List\<FlowGuide\>? | `flowGuidesMode` |
| `separatorGuides` | List\<SeparatorGuide\>? | `separatorGuidesMode` |
| `foldRegions` | List\<FoldRegion\>? | `foldRegionsMode` |
| `gutterIcons` | Map\<int, List\<GutterIcon\>\>? | `gutterIconsMode` |
| `phantomTexts` | Map\<int, List\<PhantomText\>\>? | `phantomTextsMode` |
| `codeLensItems` | Map\<int, List\<CodeLensItem\>\>? | `codeLensItemsMode` |
| `links` | Map\<int, List\<LinkSpan\>\>? | `linksMode` |

> 按行索引的数据（syntaxSpans、semanticSpans 等）使用 `Map<int, List<T>>`，key 为行号（0-based）。

#### DecorationType 枚举（MUST）

平台在暴露装饰能力集合时，MUST 在 `DecorationType` 中包含 `CODELENS` 和 `LINK`。

#### 多 Provider 合并策略

Manager 遍历所有已注册的 Provider，按 ApplyMode 合并各 Provider 的 snapshot：
- `MERGE`：将各 Provider 的同类型数据追加合并
- `REPLACE_ALL`：先清除全部已有数据，再写入新数据
- `REPLACE_RANGE`：仅清除 `visibleLineRange`（即当前 decoration 上下文范围）内的已有数据，再写入新数据

### 4.2 CompletionProvider

#### 推荐的 Receiver 签名

```
interface CompletionProvider {
    isTriggerCharacter(ch: String) -> boolean
    provideCompletions(context: CompletionContext, receiver: CompletionReceiver) -> void
}

interface CompletionReceiver {
    accept(result: CompletionResult) -> boolean
    isCancelled() -> boolean
}
```

> 平台 MAY 暴露与 `CompletionReceiver` 语义等价的异步 API，而不是显式 Receiver 类型；但契约 MUST 仍支持即时结果、延后结果以及取消 / 过期检查。若平台暴露显式 Receiver 类型，推荐命名为 `CompletionReceiver`。

#### CompletionTriggerKind 枚举（MUST）

| 值 | 说明 |
|---|---|
| `INVOKED` | 用户手动触发（如 Ctrl+Space） |
| `CHARACTER` | 输入触发字符（如 `.`） |
| `RETRIGGER` | 内容变更后重新触发 |

#### CompletionContext MUST 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `triggerKind` | CompletionTriggerKind | 触发类型 |
| `triggerCharacter` | String? | 触发字符（nullable，仅 CHARACTER 类型时有值） |
| `cursorPosition` | TextPosition | 光标位置 |
| `lineText` | String | 当前行文本 |
| `wordRange` | TextRange | 光标处单词范围 |
| `languageConfiguration` | LanguageConfiguration? | 当前语言配置（nullable） |
| `editorMetadata` | EditorMetadata? | 当前编辑器元数据（nullable） |

#### CompletionResult MUST 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `items` | List\<CompletionItem\> | 补全项列表 |
| `isIncomplete` | boolean | 结果是否不完整（true 表示后续输入应重新请求） |

#### 多 Provider 合并排序策略

Manager 遍历所有 Provider，将各 Provider 返回的 `CompletionItem` 合并后按 `sortKey`（fallback 到 `label`）排序。

### 4.3 NewLineActionProvider

#### 接口签名

```
interface NewLineActionProvider {
    provideNewLineAction(context: NewLineContext) -> NewLineAction?
}
```

> `NewLineActionProvider` 保持同步，因为换行处理属于即时输入路径。

#### NewLineContext MUST 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `lineNumber` | int | 光标行号（0-based） |
| `column` | int | 光标列号（0-based） |
| `lineText` | String | 当前行文本 |
| `languageConfiguration` | LanguageConfiguration? | 当前语言配置（nullable） |
| `editorMetadata` | EditorMetadata? | 当前编辑器元数据（nullable） |

#### NewLineAction MUST 字段

| 字段 | 类型 | 说明 |
|---|---|---|
| `text` | String | 要插入的完整文本（包含换行符和缩进） |

#### 多 Provider 链式优先级策略

Manager 按注册顺序遍历所有 Provider，返回第一个非 null 的 `NewLineAction`。若所有 Provider 均返回 null，则使用默认换行行为。

---
## 5. `CompletionItem` 字段定义（MUST）

`CompletionItem` 是补全系统的核心数据类型。确认时的应用优先级为：`textEdit` → `insertText` → `label`。

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `label` | String | **MUST** | 显示标签（用于列表展示和 fallback 插入） |
| `detail` | String? | **MAY** | 详细描述（显示在标签右侧或下方） |
| `insertText` | String? | **MAY** | 插入文本（优先于 `label` 插入） |
| `insertTextFormat` | int | **MUST** | 插入文本格式：`PLAIN_TEXT=1`（默认）, `SNIPPET=2`（VSCode Snippet 格式，支持 `$1`、`${1:default}`、`$0` 占位符） |
| `textEdit` | CompletionTextEdit? | **MAY** | 精确替换编辑（指定替换范围 + 新文本），优先级最高 |
| `filterText` | String? | **MAY** | 过滤/匹配文本（null 时 fallback 到 `label`） |
| `sortKey` | String? | **MAY** | 排序键（null 时 fallback 到 `label`） |
| `kind` | int | **MUST** | 补全项类型（影响图标显示） |

**Kind 常量（MUST）：**

| 常量 | 值 |
|---|---|
| `KIND_KEYWORD` | 0 |
| `KIND_FUNCTION` | 1 |
| `KIND_VARIABLE` | 2 |
| `KIND_CLASS` | 3 |
| `KIND_INTERFACE` | 4 |
| `KIND_MODULE` | 5 |
| `KIND_PROPERTY` | 6 |
| `KIND_SNIPPET` | 7 |
| `KIND_TEXT` | 8 |

**`CompletionTextEdit`** 子类型：

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `range` | TextRange | **MUST** | 替换范围 |
| `newText` | String | **MUST** | 替换文本 |

---

## 6. Copilot / InlineSuggestion 接口定义（SHOULD）

内联建议（Copilot）模块为 SHOULD 级别，但实现时 MUST 遵循以下接口规范。

### 6.1 `InlineSuggestion` 数据类型

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `line` | int | **MUST** | 目标行号（0-based） |
| `column` | int | **MUST** | 插入列（0-based，UTF-16 偏移） |
| `text` | String | **MUST** | 建议文本内容 |

> `InlineSuggestion` SHOULD 为不可变对象。

### 6.2 内联建议回调契约

平台 MUST 提供宿主可见的方式来观察内联建议的接受与关闭。

平台 MAY 采用以下任一形式：
- 显式 listener 接口
- delegate / closure / callback setter
- 平台原生事件 / typed stream / signal

若平台暴露显式 listener 接口，推荐形态为：

```
interface InlineSuggestionListener {
    onSuggestionAccepted(suggestion: InlineSuggestion) -> void
    onSuggestionDismissed(suggestion: InlineSuggestion) -> void
}
```

该回调契约 MUST 同时满足以下条件：
- 一个可见的内联建议 MUST 具有两个离散的宿主可见事件：`accepted` 和 `dismissed`
- `accepted` 的 payload MUST 包含被接受的 `InlineSuggestion`，或其他能无歧义标识同一建议的等价 payload
- `dismissed` 的 payload MUST 包含被关闭的 `InlineSuggestion`，或其他等价 payload / identifier；若平台回调形态天然只能提供无 payload 的 dismissed 信号，必须显式文档化这一限制
- 对于同一个已展示的建议实例，`accepted` 最多触发一次，`dismissed` 最多触发一次
- 一旦某个建议实例触发了 `accepted` 或 `dismissed`，该建议实例后续不得再触发任何回调
- 若 `showInlineSuggestion()` 替换了当前已显示的建议，平台 MAY 在切换前为旧建议实例发出 `dismissed`，也 MAY 静默替换而不发 `dismissed`；无论采用哪种方式，旧建议实例在被替换后都 MUST NOT 再发出任何后续回调
- 在 editor 进入终结性 teardown、内部 detach 或 controller dispose 之后，不得再发出任何宿主可见的内联建议回调

| 回调 | 约束级别 | 触发时机 |
|---|---|---|
| `onSuggestionAccepted` | **MUST** | 用户接受当前可见建议时 |
| `onSuggestionDismissed` | **MUST** | 用户关闭当前可见建议时 |

### 6.3 宿主可见的 Copilot API

| 方法 | 约束级别 | 说明 |
|---|---|---|
| `showInlineSuggestion(suggestion)` | **MUST** | 显示内联建议，并使其可被 accept / dismiss |
| `dismissInlineSuggestion()` | **MUST** | 关闭当前内联建议并移除其可见呈现 |
| `isInlineSuggestionShowing()` | **MUST** | 查询当前是否有内联建议正在显示 |
| `setInlineSuggestionListener(listener)` | **MUST** | 注册宿主可见的 accepted / dismissed listener；传入 `null` 时清除监听 |

> 平台 MAY 暴露语义等价的 API，例如 `setInlineSuggestionCallbacks(callbacks)`、delegate setter、事件订阅或 typed stream。

### 6.4 自动关闭行为

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 文本变更 | **MUST** | 用户输入文本时 MUST 自动关闭当前内联建议 |
| 光标移动 | **MUST** | 光标位置变化时 MUST 自动关闭当前内联建议 |
| 滚动 | **SHOULD** | 滚动时若平台存在可见建议控件，SHOULD 更新其位置；SHOULD NOT 自动关闭 |

### 6.5 `InlineSuggestionController`（MAY）

`InlineSuggestionController` 是推荐的内部实现模式（见 1.3 节），负责管理内联建议的完整生命周期：

- 建议呈现与移除
- 事件监听（TextChanged / CursorChanged / ScrollChanged）的订阅与退订
- accept / dismiss 交互及相关可视控件的位置管理
- 在适用场景下的 accept / dismiss 按键处理

各平台 MAY 选择不使用 Controller 模式，但 MUST 实现等效功能。

---

## 7. Selection / SelectionMenu 接口定义（移动端 SHOULD，桌面端 MAY 省略）

Selection menu 模块在移动端为 SHOULD 级别。桌面平台 MAY 完全省略；如果实现，则 MUST 遵循以下契约。

### 7.1 `SelectionMenuItem` 数据类型

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `id` | String | **MUST** | 稳定的动作标识符，供宿主区分菜单项 |
| `label` | String | **MUST** | 菜单中显示的文本 |
| `enabled` | boolean | **MAY** | 菜单项当前是否可点击；省略时默认可用 |
| `iconId` | int? | **MAY** | 若平台支持选区菜单图标，可提供可选图标资源 ID |

> `SelectionMenuItem` 是统一的菜单项数据模型。平台若提供标准动作，推荐保留内建 `id`：`cut`、`copy`、`paste`、`select_all`；自定义动作 MAY 使用任意稳定 `id`。

### 7.2 `SelectionMenuItemProvider`

标准规定的 provider 形态如下：

```
interface SelectionMenuItemProvider {
    provideMenuItems(editor) -> List<SelectionMenuItem>
}
```

其中 `editor` 指平台对外暴露的 editor/widget 本对象。平台 MAY 额外暴露其他
provider 参数，但 provider 应基于当前 editor 状态构建完整的选区菜单模型，而不是
基于增量 patch 载荷。

选区菜单语义：
- Provider 返回当前这一次展示应显示的整套菜单项，而不是增量追加项
- 当 provider 为 `null` 时，平台 SHOULD 恢复默认选区菜单
- 当 provider 返回空列表时，平台 MAY 不显示选区菜单
- Provider SHOULD 在菜单即将显示时重新调用，使菜单项可以随当前 editor 状态动态变化

### 7.3 Selection Menu 回调契约

实现 `SelectionMenu` 的平台 MUST 提供宿主可见的方式来观察 custom 选区菜单项被触发。平台 MAY 采用显式 listener 接口、delegate / closure / callback setter，或平台原生事件 / typed stream / signal。

若平台暴露显式 listener 接口，推荐形态为：

```
interface SelectionMenuListener {
    onSelectionMenuItemSelected(itemId: String) -> void
}
```

该回调契约 MUST 同时满足以下条件：
- 宿主可见回调可以只覆盖 custom menu item；内建 cut / copy / paste / select all 等平台动作不要求统一发出 `item-selected`
- `item-selected` 的 payload SHOULD 包含被点击 custom item 的 `itemId`，或其他能无歧义标识该菜单项的等价 payload
- 标准不要求平台暴露宿主可见的 `dismissed` 事件
- 在 editor 进入终结性 teardown、内部 detach 或 controller dispose 之后，不得再发出任何宿主可见的 custom selection-menu 回调

### 7.4 宿主可见的 Selection API

| 方法 | 约束级别 | 说明 |
|---|---|---|
| `setSelectionMenuItemProvider(provider)` | **MUST** | 配置 custom 选区菜单项；传入 `null` 时恢复平台默认菜单 |

> 平台 MAY 暴露语义等价的 API，例如 `setSelectionMenuListener(listener)`、custom item 点击事件订阅、delegate setter 或 typed stream。平台 MAY 额外暴露只读查询 API（如 `isSelectionMenuShowing()`），但标准不强制要求。

### 7.5 定位与生命周期

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 选区锚点 | **MUST** | 菜单可见时 MUST 锚定到当前选区 / 光标几何信息，或平台等价的原生选区承载体 |
| 选区失效 | **MUST** | 若选区变为空、失效，或已与当前文档状态脱离，菜单 MUST 关闭 |
| 滚动 / 视口变化 | **SHOULD** | 滚动或视口变化时 SHOULD 更新菜单位置；除非平台无法安全重定位，否则 SHOULD NOT 强制关闭 |
| 命令完成后 | **SHOULD** | 用户触发选区菜单命令后，菜单 SHOULD 关闭；除非平台有意支持多步操作流保持开启 |

### 7.6 `SelectionMenuController`（MAY）

`SelectionMenuController` 是移动端选区菜单的推荐内部实现模式。它可以负责菜单项更新、显示状态、定位以及回调分发；平台也 MAY 直接在 widget 层实现等价行为。

---
## 8. EditorTheme（MUST）

所有平台 MUST 定义包含以下颜色字段的 `EditorTheme`。字段名遵循第 2.2 节大小写规则。

### 8.1 预定义样式常量

| 常量 | 值 |
|---|---|
| `STYLE_KEYWORD` | 1 |
| `STYLE_STRING` | 2 |
| `STYLE_COMMENT` | 3 |
| `STYLE_NUMBER` | 4 |
| `STYLE_BUILTIN` | 5 |
| `STYLE_TYPE` | 6 |
| `STYLE_CLASS` | 7 |
| `STYLE_FUNCTION` | 8 |
| `STYLE_VARIABLE` | 9 |
| `STYLE_PUNCTUATION` | 10 |
| `STYLE_ANNOTATION` | 11 |
| `STYLE_PREPROCESSOR` | 12 |
| `STYLE_USER_BASE` | 100 |

### 8.2 必需颜色字段

所有颜色字段类型为平台颜色类型（ARGB），按功能分组如下：

**基础颜色**

| 字段 | 说明 |
|---|---|
| `backgroundColor` | 编辑器背景色 |
| `textColor` | 默认文本颜色，未被语法高亮覆盖时使用 |
| `cursorColor` | 光标颜色 |
| `selectionColor` | 选区高亮填充色（建议含透明度） |

**行号与当前行**

| 字段 | 说明 |
|---|---|
| `lineNumberColor` | 行号文本颜色 |
| `currentLineNumberColor` | 当前行行号文本颜色 |
| `currentLineColor` | 当前行高亮背景色（建议含透明度） |

**辅助线**

| 字段 | 说明 |
|---|---|
| `guideColor` | 代码结构线颜色（缩进/括号/流程引导线） |
| `separatorLineColor` | 分隔线颜色（SeparatorGuide） |
| `splitLineColor` | 行号区域分割线颜色 |

**滚动条**

| 字段 | 说明 |
|---|---|
| `scrollbarTrackColor` | 滚动条轨道颜色 |
| `scrollbarThumbColor` | 滚动条滑块颜色 |
| `scrollbarThumbActiveColor` | 滚动条滑块激活（拖拽中）颜色 |

**输入法**

| 字段 | 说明 |
|---|---|
| `compositionUnderlineColor` | IME 组合输入下划线颜色 |

**InlayHint**

| 字段 | 说明 |
|---|---|
| `inlayHintBgColor` | InlayHint 圆角背景色 |
| `inlayHintTextColor` | InlayHint 文本颜色（通常含透明度） |
| `inlayHintIconColor` | InlayHint 图标着色（通常含透明度） |

**折叠占位符**

| 字段 | 说明 |
|---|---|
| `foldPlaceholderBgColor` | 折叠占位符背景色（通常含透明度） |
| `foldPlaceholderTextColor` | 折叠占位符文本颜色 |

**PhantomText**

| 字段 | 说明 |
|---|---|
| `phantomTextColor` | PhantomText 颜色（通常含透明度） |

**CodeLens**

| 字段 | 说明 |
|---|---|
| `codeLensColor` | CodeLens 文本颜色 |
| `codeLensActiveColor` | CodeLens 激活文本颜色 |

**Link**

| 字段 | 说明 |
|---|---|
| `linkColor` | 链接文本颜色 |
| `linkActiveColor` | 链接激活文本颜色 |

**诊断装饰**

| 字段 | 说明 |
|---|---|
| `diagnosticErrorColor` | 诊断 ERROR 级别默认颜色 |
| `diagnosticWarningColor` | 诊断 WARNING 级别默认颜色 |
| `diagnosticInfoColor` | 诊断 INFO 级别默认颜色 |
| `diagnosticHintColor` | 诊断 HINT 级别默认颜色 |

**联动编辑**

| 字段 | 说明 |
|---|---|
| `linkedEditingActiveColor` | 联动编辑活跃 tab stop 边框色 |
| `linkedEditingInactiveColor` | 联动编辑非活跃 tab stop 边框色 |

**括号匹配**

| 字段 | 说明 |
|---|---|
| `bracketHighlightBorderColor` | 括号匹配高亮边框色 |
| `bracketHighlightBgColor` | 括号匹配高亮背景色（半透明） |

**补全弹窗**

| 字段 | 说明 |
|---|---|
| `completionBgColor` | 补全弹窗背景色 |
| `completionBorderColor` | 补全弹窗边框色 |
| `completionSelectedBgColor` | 补全弹窗选中行高亮色 |
| `completionLabelColor` | 补全弹窗标签文本颜色 |
| `completionDetailColor` | 补全弹窗详情文本颜色 |

### 8.3 工厂方法

每个平台 MUST 至少提供 `dark()` 和 `light()` 工厂方法，返回预配置的主题；内建主题 MUST 为 8.2 中全部必需颜色字段显式赋值，包括 `codeLensColor`、`codeLensActiveColor`、`linkColor`、`linkActiveColor`。

### 8.4 TextStyle 映射

每个 `EditorTheme` MUST 包含 `textStyles` 映射（`Map<int, TextStyle>`）和 `defineTextStyle(styleId, style)` 方法。

---

## 9. EditorSettings（MUST）

编辑器选项以及行为/布局类配置 MUST 通过 `EditorSettings` 对象统一收拢管理。这里指的是 wrap mode、scale、spacing、padding 等 settings-like editor options。`EditorTheme` 与 `EditorKeyMap` 仍然是独立的宿主配置对象，不受本条“并入 `EditorSettings`”约束。宿主可见 API 载体 MUST NOT 直接暴露 settings-like 配置 setter（如 `setWrapMode`、`setScale` 等），而是通过 `getSettings()` 暴露配置对象，并在该对象可用后由调用方进行配置。命令式平台上，该宿主 API 载体是 `SweetEditor`；声明式平台上则是 `SweetEditorController`。在声明式平台上，`getSettings()` 只有在 `whenReady()` 或其他等价 ready 信号之后才有效。在此之前，它 SHOULD 返回 `null` 或默认的不可用值，MUST NOT 为此创建隐藏运行时或隐藏暂存对象，也 MUST NOT 被视为 pre-ready 配置通道。若首个 attach 前就必须确定初始 settings，MUST 通过声明式构造参数或等价的平台原生初始化路径提供。这个宿主接口规则不改变第 3.1 节定义的 `EditorCore` Public API。

所有平台 MUST 通过 getter/setter 对（或属性）暴露以下设置：

| 字段 | 类型 | 默认值 | setter | getter | 副作用 | 说明 |
|---|---|---|---|---|---|---|
| `editorTextSize` | float | 平台相关 | `setEditorTextSize(size)` | `getEditorTextSize()` | `relayout` | 编辑器文本字号 |
| `typeface` / `fontFamily` | 平台字体类型 | `monospace` | `setTypeface(typeface)` / `setFontFamily(family)` | `getTypeface()` / `getFontFamily()` | `relayout` | 字体 |
| `scale` | float | 1.0 | `setScale(scale)` | `getScale()` | `relayout` | 缩放比例 |
| `foldArrowMode` | FoldArrowMode | ALWAYS | `setFoldArrowMode(mode)` | `getFoldArrowMode()` | `repaint` | 折叠箭头显示模式 |
| `wrapMode` | WrapMode | NONE | `setWrapMode(mode)` | `getWrapMode()` | `relayout` | 自动换行模式 |
| `lineSpacingAdd` | float | 0 | `setLineSpacing(add, mult)` | `getLineSpacingAdd()` | `relayout` | 行间距附加值（像素） |
| `lineSpacingMult` | float | 1.0 | *(同上)* | `getLineSpacingMult()` | `relayout` | 行间距倍数 |
| `contentStartPadding` | float | 平台相关 | `setContentStartPadding(padding)` | `getContentStartPadding()` | `relayout` | gutter 分割线与文本渲染起始之间的额外水平内边距（像素） |
| `showSplitLine` | boolean | true | `setShowSplitLine(show)` | `isShowSplitLine()` | `repaint` | 是否渲染 gutter 分割线 |
| `gutterSticky` | boolean | 平台相关 | `setGutterSticky(sticky)` | `isGutterSticky()` | `repaint` | gutter 是否在水平滚动时固定（true=固定，false=随内容滚动） |
| `gutterVisible` | boolean | true | `setGutterVisible(visible)` | `isGutterVisible()` | `relayout` | gutter 区域是否可见（false=隐藏行号、图标、折叠箭头） |
| `currentLineRenderMode` | CurrentLineRenderMode | BACKGROUND | `setCurrentLineRenderMode(mode)` | `getCurrentLineRenderMode()` | `repaint` | 当前行渲染模式 |
| `autoIndentMode` | AutoIndentMode | KEEP_INDENT | `setAutoIndentMode(mode)` | `getAutoIndentMode()` | `runtime-transition` | 自动缩进模式 |
| `backspaceUnindent` | boolean | true | `setBackspaceUnindent(enabled)` | `isBackspaceUnindent()` | `runtime-transition` | 退格键在行首是否按缩进级别删除空白 |
| `readOnly` | boolean | false | `setReadOnly(readOnly)` | `isReadOnly()` | `runtime-transition` | 只读模式，阻止所有编辑操作 |
| `maxGutterIcons` | int | 0 | `setMaxGutterIcons(count)` | `getMaxGutterIcons()` | `relayout` | gutter 图标最大数量 |
| `decorationScrollRefreshMinIntervalMs` | long | 16 | `setDecorationScrollRefreshMinIntervalMs(ms)` | `getDecorationScrollRefreshMinIntervalMs()` | `provider-policy` | 装饰滚动刷新最小间隔（毫秒） |
| `decorationOverscanViewportMultiplier` | float | 1.5 | `setDecorationOverscanViewportMultiplier(mult)` | `getDecorationOverscanViewportMultiplier()` | `provider-policy` | 装饰预渲染视口倍数 |

> 所有 setter 调用后 MUST 立即生效。
>
> 副作用分类：
> - `repaint`：MUST 立即触发重绘或等效的视觉刷新，不要求文本重新布局。
> - `relayout`：MUST 立即触发布局失效，并重建 render model 或走等效的重新布局路径。
> - `runtime-transition`：MUST 立即生效，并安全处理该设置要求的运行态切换。`runtime-transition` 设置只有在当前可见状态实际发生变化时，才要求重绘或重新布局。
> - `provider-policy`：MUST 立即影响后续 provider 的调度 / 刷新策略。除非实现明确在应用新策略时主动触发 refresh，否则不要求重绘或重新布局。
>
> `autoIndentMode`、`backspaceUnindent` 和 `readOnly` 也属于 `runtime-transition` 设置。它们必须立即影响后续编辑行为，但在 setter 调用当下若没有可见状态变化，则不要求 `flush()`、重绘或重新布局。
>
> `contentStartPadding` 的默认值为平台相关，且 MUST `>= 0`。`0` 是中性的基线值，但平台 MAY 选择非零的视觉默认值。
>
> `gutterSticky` 的默认值为平台相关。桌面风格平台 SHOULD 默认 `true`；移动端 / touch-first 平台 SHOULD 默认 `false`。

---

## 10. Keymap / 快捷键映射（MUST）

### 10.1 Core 数据模型

所有平台 MUST 提供 Core 层 `KeyMap`、`KeyBinding`、`KeyChord`、`KeyCode`、`KeyModifier` 和 `EditorCommand`。

- `KeyMap` MUST 是从 `KeyBinding` 到 commandId 的纯数据映射
- `KeyBinding` MUST 同时支持单 chord 和双 chord 绑定
- `KeyChord` MUST 表示一次按键的 `modifiers + keyCode`
- 单 chord 绑定 MUST 将第二段编码为空 chord / none chord
- `EditorCore.setKeyMap(keyMap)` MUST 将完整绑定表同步到 C++ Core

### 10.2 数值对齐

如果平台暴露 `KeyCode`、`KeyModifier` 或内建 `EditorCommand` 常量，其数值 MUST 与 C++ Core 保持一致。

- `KeyModifier` MUST 使用位标志，以便通过按位或组合修饰键
- `KeyCode.NONE`、空第二 chord 与 `EditorCommand.NONE` 的语义 MUST 与 C++ Core 一致
- `EditorCore`、桥接层或 FFI 层 MAY 继续使用与 C++ Core 对齐的原始整数枚举值作为内部传输表示
- 对于这类桥接层整数枚举值，平台不要求重复实现宿主公共 API 级别的业务枚举校验，但 MUST 保证无效输入不会导致 native / C++ 层崩溃或未定义行为

### 10.3 Widget 层扩展

- `SweetEditor` MUST 支持 `setKeyMap(keyMap)`，并 SHOULD 暴露 `getKeyMap()`
- 平台 MUST 暴露 `EditorKeyMap` 作为 `KeyMap` 的 widget 层扩展，使宿主代码可以额外将 commandId 绑定到宿主侧 handler
- `EditorKeyMap` MUST 支持 `registerCommand(binding, handler)`
- 若 `binding.command == EditorCommand.NONE`，`registerCommand(binding, handler)` MUST 自动分配自定义 commandId 并返回
- 平台 MAY 额外提供自定义命令注册的便捷 API，但 `registerCommand(binding, handler)` 仍是标准契约
- 自动分配的自定义 commandId MUST 大于 `BUILT_IN_MAX`
- 平台 MUST 提供 `defaultKeyMap()` 作为默认绑定工厂
- 平台 MUST 提供 `vscode()`，并且 `defaultKeyMap()` MUST 在语义上等价于 `vscode()`
- 平台 SHOULD 提供 `jetbrains()`、`sublime()` 等命名预设工厂
- `SweetEditor.setKeyMap()` MUST 替换当前 keymap，并让新绑定立即生效
- Widget 层 handler 保持在平台侧，不序列化到 C++ Core
- 若平台不暴露 `getKeyMap()`，平台文档 MUST 明确宿主如何构建和替换当前生效的 keymap

---

## 11. 事件系统（MUST）

### 11.1 事件机制

所有平台 MUST 提供**类型安全**的编辑器事件暴露机制，使宿主代码能够订阅特定事件类型，并以取消订阅 / 释放订阅 / 取消监听等**等效方式**管理订阅生命周期。

平台 MAY 采用以下任一实现形态：
- `EditorEventBus` + `subscribe` / `unsubscribe` / `publish` / `clear`
- 平台原生事件 / 委托 / 监听器机制（如 C# `event`、Java listener callback）
- 类型化 stream / signal / observable getter（如 Dart `Stream<T>`）

若平台采用显式事件总线 / 监听器模式，相关公共类型 SHOULD 命名为 `EditorEventBus` / `EditorEventListener`。

### 11.2 必需事件类型

所有平台 MUST 支持以下事件类型：

```
TextChangedEvent, CursorChangedEvent, SelectionChangedEvent,
ScrollChangedEvent, ScaleChangedEvent, DocumentLoadedEvent,
FoldToggleEvent, GutterIconClickEvent, InlayHintClickEvent, CodeLensClickEvent, LinkClickEvent,
LongPressEvent,       // 仅移动端（iOS/Android）
DoubleTapEvent,
ContextMenuEvent      // 具有显式上下文菜单手势入口的平台
```

> `LongPressEvent` 用于移动端（iOS/Android），表示原始长按手势本身。`ContextMenuEvent` 用于暴露显式的上下文菜单手势入口（例如桌面右键或框架原生 context-menu gesture）。平台实现 SHOULD 仅注册与自身平台相关的事件。

> 上述事件类型 MUST 能通过平台选择的事件机制被类型安全地区分和消费。

平台特定事件（如移动端的 `SelectionMenuItemClickEvent`）MAY 额外添加。

### 11.3 事件 Payload 契约

事件 payload 必须按事件逐个定义。除事件类型本身外，平台 MUST NOT 假定或要求统一的基类 payload 结构。

| 事件 | 字段 | 说明 |
|---|---|---|
| `TextChangedEvent` | `changes: List<TextChange>`、`action: TextChangeAction?` *(SHOULD)* | 当前编辑周期内的增量文本变更列表；`action` 为可选的粗粒度语义提示 |
| `CursorChangedEvent` | `cursorPosition: TextPosition` | 当前光标位置 |
| `SelectionChangedEvent` | `hasSelection: boolean`, `selection: TextRange?`, `cursorPosition: TextPosition` | 当前选区状态与光标位置 |
| `ScrollChangedEvent` | `scrollX: float`, `scrollY: float` | 当前视图滚动偏移 |
| `ScaleChangedEvent` | `scale: float` | 当前编辑器缩放值 |
| `DocumentLoadedEvent` | — | 不要求 payload 字段 |
| `FoldToggleEvent` | `line: int`, `isGutter: boolean`, `locationInEditor: PointF 或平台原生点类型` | 被切换的折叠行、是否来自 gutter 点击，以及相对 editor 本地坐标系的点位 |
| `GutterIconClickEvent` | `line: int`, `iconId: int`, `locationInEditor: PointF 或平台原生点类型` | 被点击的 gutter icon 所在行、icon id，以及相对 editor 本地坐标系的点位 |
| `InlayHintClickEvent` | `line: int`, `column: int`, `type: InlayType`, `intValue: int`, `locationInEditor: PointF 或平台原生点类型` | 被点击的 inlay 位置、inlay 类型、类型相关值，以及相对 editor 本地坐标系的点位 |
| `CodeLensClickEvent` | `line: int`, `column: int`, `commandId: int`, `locationInEditor: PointF 或平台原生点类型` | 被点击的 CodeLens 行/列锚点、唯一命令 id，以及相对 editor 本地坐标系的点位 |
| `LinkClickEvent` | `line: int`, `column: int`, `target: String`, `locationInEditor: PointF 或平台原生点类型` | 被点击的链接行/列锚点、解析后的链接目标，以及相对 editor 本地坐标系的点位 |
| `LongPressEvent` | `cursorPosition: TextPosition`, `locationInEditor: PointF 或平台原生点类型` | 原始长按命中的位置与相对 editor 本地坐标系的点位 |
| `DoubleTapEvent` | `cursorPosition: TextPosition`, `hasSelection: boolean`, `selection: TextRange?`, `locationInEditor: PointF 或平台原生点类型` | 双击命中的位置、结果选区状态，以及相对 editor 本地坐标系的点位 |
| `ContextMenuEvent` | `cursorPosition: TextPosition`, `locationInEditor: PointF 或平台原生点类型` | 显式 context-menu 手势命中的位置与相对 editor 本地坐标系的点位 |
| `ContextMenuItemClickEvent` *(平台特定)* | `item: ContextMenuItem`, `request: ContextMenuRequest` | 被点击的自定义上下文菜单项，以及构建该菜单时使用的不可变请求快照 |
| `SelectionMenuItemClickEvent` *(平台特定)* | `item: SelectionMenuItem` | 被点击的自定义选择菜单项 |

### 11.4 GestureResult 契约

平台 MAY 直接暴露 `handleGestureEvent(...)` / `handleGestureEventEx(...)` 的返回值，也 MAY 仅在内部消费；但若它出现在公共 API 或平台内部桥接类型中，下列字段 MUST 保持与 Core 一致的语义：

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `hitTarget` | `HitTargetType` + 与平台对齐的 payload | **MUST** | 当前手势位置的命中测试结果 |
| `pointerCursorType` | `PointerCursorType` | 桌面端 **MUST**，纯触摸平台 **MAY** | 当前鼠标位置对应的指针样式提示 |

> 桌面平台 SHOULD 在手势处理后立即应用 `pointerCursorType`，以获得及时的鼠标形状反馈。纯触摸平台 MAY 完全省略该字段；若仍保留该字段用于兼容，也 MAY 忽略视觉上的鼠标形状变化。

### 11.5 ContextMenu 标准契约

`ContextMenu` 是 widget 层、平台侧的 UI 能力。它 MUST NOT 被建模为 C++ Core 的 render model 概念，也 MUST NOT 作为 Core decoration 类型序列化。若平台实现了上下文菜单，就 MUST 遵循以下标准数据模型与语义。

#### 推荐类型

```
enum ContextMenuTriggerKind {
    LONG_PRESS,
    RIGHT_CLICK
}

interface ContextMenuItemProvider {
    provideMenuItems(request: ContextMenuRequest) -> List<ContextMenuSection>
}
```

#### `ContextMenuRequest` 必备字段

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `triggerKind` | `ContextMenuTriggerKind` | **MUST** | 当前这轮菜单显示的触发类型 |
| `cursorPosition` | `TextPosition` | **MUST** | 触发手势完成后的光标位置 |
| `locationInEditor` | `PointF 或平台原生点类型` | **MUST** | 相对 editor 本地坐标系的指针位置 |
| `hasSelection` | boolean | **MUST** | 当前 editor 是否存在非空选区 |
| `selection` | `TextRange?` | **MAY** | 当前选区快照；当 `hasSelection == false` 时为 `null` |
| `hitTarget` | 与平台对齐的 `HitTarget` payload | **MUST** | 触发位置上的命中测试结果 |
| `linkTarget` | String | **MAY** | 当 `hitTarget` 为 `LINK` 时解析出的链接目标；不适用时为空字符串 |

#### `ContextMenuItem` 必备字段

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `id` | String | **MUST** | 稳定的动作标识符 |
| `label` | String | **MUST** | 主显示文本 |
| `secondaryLabel` | String? | **MAY** | 同一行中的可选次级文本 |
| `enabled` | boolean | **MAY** | 菜单项当前是否可执行；省略时默认可用 |
| `icon` | 平台原生前置图标对象或等价物 | **MAY** | 可选前置图标。这里 SHOULD 使用平台原生图像对象，而不是跨平台数值型 icon id |

#### `ContextMenuSection` 必备字段

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `items` | `List<ContextMenuItem>` | **MUST** | 该分组中的完整菜单项列表 |

上下文菜单语义：
- `LongPressEvent` 和/或 `ContextMenuEvent` MAY 作为触发信号；`ContextMenuRequest` 是用于构建真实菜单模型的不可变快照
- provider 返回的是当前这次显示应使用的完整菜单模型，而不是增量追加项
- 将 provider 设为 `null` 时 SHOULD 恢复平台默认上下文菜单
- provider 返回空列表时 MAY 不显示菜单
- `locationInEditor` MUST 始终保持 editor-local 语义；平台只在真正展示 Popup 或原生菜单时再换算成 screen / window 坐标
- 平台 MAY 由 `LongPressEvent` 直接打开 context menu，而不额外发布 `ContextMenuEvent`；此时 `ContextMenuRequest.triggerKind` MUST 仍为 `LONG_PRESS`
- 若 `hitTarget == LINK` 且 `linkTarget` 非空，默认菜单 SHOULD 包含内建动作 `open_link` 与 `copy_link`
- 若 `hasSelection == true`，默认菜单 SHOULD 包含内建动作 `cut` 与 `copy`
- 通用 / 默认分组 SHOULD 包含内建动作 `paste` 与 `select_all`
- `ContextMenuItem.icon` MAY 为 `null`；若同一个菜单中存在带图标的行，平台 SHOULD 预留一致的前置图标槽位以保持对齐
- 平台 MUST 提供宿主可见的方式，通过 `ContextMenuItemClickEvent` 或等价回调 payload 观察 custom item 被触发
- 在命令执行、文本变化、或其他会使当前目标失效的手势之后，菜单 SHOULD 关闭；除非平台有意支持持久化的多步工作流

实现 `ContextMenu` 的平台 MUST 暴露语义等价于 `setContextMenuItemProvider(provider)` 的宿主可见 API。

---

## 12. 枚举与常量值（MUST）

枚举值和类枚举常量值 MUST 与 C++ 核心定义匹配。以下分组 MUST 在所有平台与 C++ 核心保持对齐。若下表显式给出了数值，各平台 MUST 使用相同数值；若某一行只列出成员名或注明“与 C++ 核心对齐”，各平台仍 MUST 与对应的 core 定义保持一致。

| 枚举 | 值 |
|---|---|
| `WrapMode` | NONE=0, CHAR_BREAK=1, WORD_BREAK=2 |
| `FoldArrowMode` | AUTO=0, ALWAYS=1, HIDDEN=2 |
| `AutoIndentMode` | NONE=0, KEEP_INDENT=1 |
| `CurrentLineRenderMode` | BACKGROUND=0, BORDER=1, NONE=2 |
| `ScrollBehavior` | TOP=0, CENTER=1, BOTTOM=2 |
| `SpanLayer` | SYNTAX=0, SEMANTIC=1 |
| `InlayType` | TEXT=0, ICON=1, COLOR=2 |
| `VisualRunType` | TEXT=0, WHITESPACE=1, NEWLINE=2, INLAY_HINT=3, PHANTOM_TEXT=4, FOLD_PLACEHOLDER=5, TAB=6, CODELENS=7, LINK=8 |
| `VisualLineKind` | CONTENT=0, PHANTOM=1, CODELENS=2 |
| `PointerCursorType` | DEFAULT=0, TEXT=1, HAND=2 |
| `FoldState` | NONE=0, EXPANDED=1, COLLAPSED=2 |
| `DecorationType` | SYNTAX_HIGHLIGHT, SEMANTIC_HIGHLIGHT, INLAY_HINT, DIAGNOSTIC, FOLD_REGION, INDENT_GUIDE, BRACKET_GUIDE, FLOW_GUIDE, SEPARATOR_GUIDE, GUTTER_ICON, PHANTOM_TEXT, CODELENS, LINK |
| `HitTargetType` | NONE=0, INLAY_HINT_TEXT=1, INLAY_HINT_ICON=2, GUTTER_ICON=3, FOLD_PLACEHOLDER=4, FOLD_GUTTER=5, INLAY_HINT_COLOR=6, CODELENS=7, LINK=8 |
| `GuideType` | INDENT=0, BRACKET=1, FLOW=2, SEPARATOR=3 |
| `GuideDirection` | （与 C++ 核心对齐） |
| `GuideStyle` | SOLID=0, DASHED=1, DOUBLE=2 |
| `SeparatorStyle` | SINGLE=0, DOUBLE=1 |
| `KeyCode` | NONE=0, BACKSPACE=8, TAB=9, ENTER=13, ESCAPE=27, DELETE_KEY=46, LEFT=37, UP=38, RIGHT=39, DOWN=40, HOME=36, END=35, PAGE_UP=33, PAGE_DOWN=34, A=65, C=67, D=68, V=86, X=88, Y=89, Z=90, K=75, SPACE=32 |
| `KeyModifier` | NONE=0, SHIFT=1, CTRL=2, ALT=4, META=8 |
| `EditorCommand` | NONE=0, CURSOR_LEFT=1, CURSOR_RIGHT=2, CURSOR_UP=3, CURSOR_DOWN=4, CURSOR_LINE_START=5, CURSOR_LINE_END=6, CURSOR_PAGE_UP=7, CURSOR_PAGE_DOWN=8, SELECT_LEFT=9, SELECT_RIGHT=10, SELECT_UP=11, SELECT_DOWN=12, SELECT_LINE_START=13, SELECT_LINE_END=14, SELECT_PAGE_UP=15, SELECT_PAGE_DOWN=16, SELECT_ALL=17, BACKSPACE=18, DELETE_FORWARD=19, INSERT_TAB=20, INSERT_NEWLINE=21, INSERT_LINE_ABOVE=22, INSERT_LINE_BELOW=23, UNDO=24, REDO=25, MOVE_LINE_UP=26, MOVE_LINE_DOWN=27, COPY_LINE_UP=28, COPY_LINE_DOWN=29, DELETE_LINE=30, COPY=31, PASTE=32, CUT=33, TRIGGER_COMPLETION=34 |

---

## 13. 平台特定允许差异

### 13.1 桥接层（MAY 不同）

每个平台使用自己的原生桥接技术，这是预期的，不做约束：

| 平台 | 桥接技术 |
|---|---|
| Android | JNI (`jeditor.hpp`) |
| Swing | Java FFM (`EditorNative.java`) |
| WinForms | P/Invoke (`NativeMethods`) |
| Apple | Swift C bridge (`CBridge.swift`) |
| OHOS | NAPI (`napi_editor.hpp`) |
| Flutter | FFI (Dart) |

### 13.2 输入法接入（平台 API MAY 不同，core 语义 MUST 一致）

输入法集成天然是平台特定的，但 SweetEditor 的 composition 语义 MUST 在各平台保持一致。平台实现可以使用不同系统 API 接入 IME，但必须把原生 IME 事件归一化到 core 的 IME 语义能力族：只有系统 IME 明确声明 composing / marked / preedit 时才建立 editor composition；candidate context、surrounding text、光标矩形、键盘语言或光标进入 Latin 单词都不能自动创建 composition。

| 平台 | IME API | 推荐映射 |
|---|---|---|
| Android | `InputConnection` | 根据 `setComposingText` / `setComposingRegion` / `commitText` / delete / extracted-text 能力选择 preedit、document range、input-context 或 deletion 语义族 |
| iOS | `UITextInput` | marked text / `markedTextRange` 映射到 marked/preedit 语义；text range 操作按平台提供的坐标能力选择 document 或 input-context 语义 |
| macOS | `NSTextInputClient` | `setMarkedText` / marked range 映射到 marked/preedit 语义；selected range 和 replacement range 必须保持坐标空间一致 |
| Swing | `InputMethodEvent` / `InputMethodRequests` | `InputMethodEvent` 中的 composed text 段映射到 preedit/commit；`InputMethodRequests` 用于同步候选上下文和光标矩形 |
| WinForms | TSF / IMM | TSF composition range 或 IMM composition string 按可获得的信息映射到 preedit、document range 或 input-context 语义 |
| OHOS | IME Kit | 平台 composing / preedit 回调或范围按其坐标空间映射到 preedit、document range、input-context 或 text-model 语义 |
| Flutter | `TextInputClient` | 优先使用 `TextEditingValue` 的 text-model state / delta 语义；有效 `composing` range 表示平台声明的 composition |

各平台 MUST 将原生 composition 来源映射到 core 的 preedit / composing / marked-range 语义族，将原生提交映射到 commit 语义族，将明确替换映射到 replacement 语义族，将原生 finish/cancel 映射到 finish/cancel 语义族。平台 MAY 根据原生 API 选择 document line/column、document offset、input-context offset 或 text-model state/delta 路径；但 MUST 明确坐标空间并保持一致。

传入 core 的 document range MUST 使用文档坐标；传入 input-context / text-model 的 offset MUST 相对于对应 `documentStartOffset`；平台 surrounding-text window 的临时 offset 不能被当成文档 offset。可编辑状态下始终支持平台 IME composition；只读模式负责阻止文本变更，MUST NOT 实现为 composition enable / disable 开关。

### 13.3 可选模块

| 模块 | 移动端 | 桌面端 |
|---|---|---|
| `copilot/`（内联建议） | SHOULD | SHOULD |
| `contextmenu/`（上下文菜单） | MAY | SHOULD |
| `selection/`（选区菜单） | SHOULD | MAY 省略 |
| `perf/`（性能浮层） | SHOULD | SHOULD |

### 13.4 渲染细节（MAY 不同）

以下视觉差异是可接受的：
- 行号背景渲染模式
- 滚动条视觉样式和动画
- 光标闪烁频率
- 选区拖拽手柄形状
- 平台原生字体渲染差异

---

## 14. 线程与并发模型（MUST）

状态变更类编辑器操作和对宿主可见的回调默认与 UI 线程绑定。平台 MAY 暴露额外的线程安全查询面，但 MUST 选择具体线程模型；平台 SHOULD 通过代码注释、类型注解或 README 任一形式明确说明该模型。

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 状态变更 API 线程 | **MUST** | 会修改编辑器状态或触发可见 UI 更新的公共方法，除非平台显式文档化了等价的串行线程模型，否则 MUST 在 UI 线程调用 |
| API 线程契约文档 | **SHOULD** | 平台 SHOULD 通过代码注释、类型注解或 README 任一形式说明哪些公共 API 只能在 UI 线程调用，以及哪些纯查询 / 快照 API（如果有）可安全在后台线程调用 |
| 纯查询 API 线程 | **SHOULD** | 纯查询 / 快照 API SHOULD 要么保持 UI 线程限定，要么被显式文档化为后台安全；仅在实现安全时平台 MAY 允许后台读取 |
| 事件回调线程 | **MUST** | 所有事件回调 / 委托调用 / stream emission（对宿主可见的事件分发）MUST 在 UI 线程执行 |
| Provider 调用线程 | **MUST** | 平台 MUST 为 `provideDecorations()` 和 `provideCompletions()` 选择稳定的调用模型（UI 线程、工作线程或其他串行执行器）；平台 SHOULD 通过代码注释、类型注解或 README 任一形式向宿主说明该模型 |
| Provider 异步回调线程 | **MUST** | Provider 结果回传可以发生在任意线程，但 Manager 在将结果应用到 Core 或修改宿主可见编辑器状态前 MUST 切回 UI 线程 |
| `buildRenderModel()` | **MUST** | `buildRenderModel()` MUST 观察稳定的编辑器快照。平台 MAY 要求 UI 线程调用，也 MAY 提供更强的线程安全快照契约；返回的 `EditorRenderModel` SHOULD 视为不可变对象，MAY 在渲染线程安全读取 |
| `NewLineActionProvider` | **MUST** | `provideNewLineAction()` MUST 在输入路径上同步完成，确保 Enter 处理不依赖后续异步回调 |
| 线程安全标注 | **SHOULD** | 各平台 SHOULD 在公共 API 文档中标注线程约束（如 Java `@MainThread`、Swift `@MainActor`） |

---
## 15. 错误处理（MUST）

公共 API 对非法输入采用防御性处理；托管语言宿主公共 API MAY 按语言惯例快速失败，但桥接层 / FFI 边界 MUST 保证不会导致 native / C++ 崩溃或未定义行为；Provider 回调中的异常由 Manager 隔离。

### 15.1 公共 API 参数校验

| 场景 | 约束级别 | 行为 |
|---|---|---|
| 行号 / 列号越界 | **MUST** | 自动 clamp 到有效范围 `[0, max)`，MUST NOT 抛出异常 |
| null / 空参数 | **MUST** | 对于语义上可空的参数，平台 MUST 按该参数的可空语义处理。对于 MUST 非空的参数，托管语言公共 API SHOULD 使用平台惯用方式快速失败（如 Java `NullPointerException` / `IllegalArgumentException`、C# `ArgumentNullException`），并 MUST NOT 导致 native / C++ 层崩溃或未定义行为；桥接层 / FFI 边界 MUST 安全处理无效输入 |
| 无效枚举值 | **MUST** | 对于宿主可见公共 API，若因平台限制暴露整数枚举值，则 MUST 对无效值做显式处理；托管语言公共 API SHOULD 使用平台惯用方式快速失败（如 `IllegalArgumentException`），也 MAY 回退到默认值。对于 `EditorCore`、桥接层或 FFI 层的原始整数枚举值，不要求重复实现宿主级业务校验，但 MUST NOT 导致 native / C++ 层崩溃或未定义行为 |
| 超出 ready / active 生命周期的调用 | **SHOULD** | 平台 SHOULD 遵循第 3.0.3 节和第 16.3 节的生命周期规则。在声明式 editor 实例 ready 之前或在终结性 teardown 之后，getter SHOULD 返回 `null` 或默认值。变更类命令式调用 MUST 被忽略或拒绝，且 MUST NOT 被排队。终结性 teardown 之后，影响运行时的调用 MUST 为 no-op 或返回默认值。该规则主要适用于声明式 controller、显式 teardown API，或存在已定义 terminal session lifecycle boundary 的平台 |

### 15.2 Provider 异常处理

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 异常捕获 | **SHOULD** | 平台 SHOULD 尽量隔离 Provider 异常，避免单个 Provider 影响其他 Provider 或导致编辑器崩溃；对于同步输入热路径上的 Provider（如 `NewLineActionProvider`），平台 MAY 不采用统一的 try-catch 包裹，而使用更轻量或平台惯用的处理方式 |
| 异常日志 | **MAY** | 平台 MAY 将捕获的异常记录到日志系统；标准不强制日志格式，也不强制包含 Provider 类名等字段 |
| 异常后行为 | **SHOULD** | 异常 Provider 的本次结果 SHOULD 被丢弃；后续刷新周期 SHOULD 继续调用该 Provider（不自动禁用） |

### 15.3 C++ Core 错误传播

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 桥接层错误转换 | **MUST** | C++ Core 返回的错误码 MUST 在桥接层转换为平台惯用的错误表示（如 Java 日志 + no-op、Swift `Result` 类型等），MUST NOT 将 C++ 异常直接传播到上层 |
| 内存分配失败 | **MUST** | C++ Core 内存分配失败时，桥接层 MUST 安全处理（如返回空模型），MUST NOT 导致未定义行为 |

---

## 16. 生命周期管理（MUST）

资源的创建和销毁遵循明确的顺序约束，防止悬挂引用和内存泄漏。

对于所有平台，标准的合规目标都是“终态释放路径安全”加“native 资源最终释放”。标准并不要求每个平台都暴露显式 `dispose()` / `close()` / `release()` API，也不要求所有平台在同一个时刻以确定性方式销毁资源。平台可以通过显式 teardown API、宿主管理生命周期、widget 或 controller 销毁、析构 / RAII / `Drop`、ARC / `deinit`、GC / finalizer 回收，或其他符合平台习惯的清理机制来满足释放路径要求。对于 GC 管理的命令式 widget 平台，标准不要求平台仅为了合规而额外发明 synthetic terminal session-teardown hook；核心要求是 native 资源最终释放，以及在 teardown 或资源释放之后保持安全。

### 16.1 `EditorCore` 生命周期

| 阶段 | 约束级别 | 规则 |
|---|---|---|
| 创建 | **MUST** | `EditorCore` 实例 MUST 在控件初始化阶段创建（命令式框架：构造函数或 init；声明式框架：控件首次挂载时） |
| 资源释放路径 | **MUST** | 平台 MUST 保证 `EditorCore` 及其 native / C++ 侧资源最终会被释放。显式 `dispose()` / `close()` / `release()` API 是可选的。平台也 MAY 改为依赖宿主管理的 editor 生命周期、widget/session 销毁、析构 / RAII / `Drop`、ARC / `deinit`、基于 GC / finalizer 的自动回收、等价的平台清理钩子，或其他平台惯用策略。对于 GC 管理的命令式 widget 平台，即使平台没有独立的 terminal session callback，只要能够通过 GC、finalizer、Cleaner 或等价的运行时清理机制实现最终回收，即可视为满足释放路径要求。只有当 controller 销毁属于其关联 editor 实例的终结性清理路径时，controller 销毁才可计入释放路径。view detach、widget unmount 或视图树中的临时移除，本身 NOT 必须构成最终回收时机 |
| teardown 后调用 | **MUST** | 若平台暴露了显式 terminal teardown API，或对象在逻辑 teardown / 内部释放后仍然可达且可被调用，则后续调用 MUST NOT 访问无效的 native / C++ 资源，且 MUST NOT 再触发编辑器副作用或回调。变更类调用 MUST 为 no-op 或返回默认值。getter 调用 MAY 返回 `null`、默认值，或托管侧最后一次已知快照，只要这些返回不依赖 live native state，且不会触发针对已释放资源的惰性重计算 |
| 重复释放 | **MUST** | 若平台暴露显式释放逻辑，多次调用 MUST 为幂等操作（no-op），MUST NOT 导致 double-free |

> 标准要求的是 native 资源最终释放，但**不要求**每个平台，或每个 `Document` / bridge wrapper，都额外暴露一个显式 release API；若平台已有自身生命周期模型，应优先遵循该模型。平台 SHOULD 优先保证逻辑 teardown 安全：停止定时器、解绑 listener、取消或标记异步 receiver 为 stale，并切断原本会阻止 editor 对象图被回收的引用链。若平台暴露了显式 teardown 逻辑，或存在已知的 terminal cleanup callback，则它 MUST 执行对应的逻辑 teardown 清理。对于不存在此类 terminal cleanup hook 的 GC 管理命令式 widget 平台，主动 cleanup 仍是 SHOULD 而非 MUST。若平台在 teardown 后仍返回托管侧最后一次已知快照，SHOULD 在文档中明确这些值是陈旧快照，而不是仍可操作的实时 editor 状态。

### 16.2 Provider 生命周期

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 注册时机 | **MUST** | 关联的 editor 实例 ready 之后，Provider MUST 可以在任意时刻注册。标准 MUST NOT 要求注册必须发生在 `loadDocument(...)` 之后，也 MUST NOT 要求注册必须等到文档可用之后 |
| 首次 attach 前调用 | **MUST** | 在声明式平台上，Provider 注册调用只有在关联的 editor 实例完成首次 attach 之后才有效。宿主 SHOULD 在 `whenReady()` 或其他等价 ready 信号中注册 Provider。在此之前的调用 MAY 被忽略或拒绝，但 MUST NOT 由 `SweetEditorController` 排队，也 MUST NOT 为此创建隐藏运行时 |
| 触发前提 | **MUST** | 只有当当前 session 具备该 provider 类型所需的 context/data 时，Provider 才 MAY 被触发。若前置的文档或上下文数据尚不可用，平台 MAY 延迟触发、跳过触发，或在模块契约已定义时遵循该模块的空/default-context 语义 |
| 注册归属 | **MUST** | 宿主可见的 Provider 注册 MUST 归属于当前关联的 `SweetEditor` session/runtime。它们属于 session 级注册，而不是 controller 自身持有的状态 |
| Session 清理 | **MUST** | 若平台定义了显式 session teardown 阶段、internal detach hook，或其他在语义上代表 terminal session cleanup 的平台原生销毁回调，则平台 MUST 取消或将该 session 关联的所有进行中 Provider 工作标记为 stale，停止相关定时器 / listener / receiver，并忽略来自旧 session 的延迟结果；同时 MUST 在该 session teardown 过程中清空或终结性停用 session 自身持有的 Provider 注册。若 GC 管理的命令式平台不存在此类 terminal cleanup hook，则主动 session cleanup 为 SHOULD 而非 MUST；由托管运行时完成最终回收是可接受的，但前提是 native 资源释放后，延迟结果不得访问无效 native state |
| Controller 转发边界 | **MUST** | `SweetEditorController` MAY 将 Provider 注册调用转发给已绑定的 `SweetEditor`，但标准 MUST NOT 要求 controller 在 editor 生命周期之间或在终结性 session teardown 之后保留这些 Provider 注册 |
| 终结性 teardown 清理 | **MUST** | 若平台定义了显式 controller `dispose()` / `close()` / `release()` 阶段，或其他等价的最终逻辑 teardown hook，则 MUST 清空 controller 自身持有的 ready 回调与内部 pending callback，并取消或标记 controller 自身持有的异步工作为 stale，使延迟结果被忽略。它 MUST NOT 暗示 controller 拥有 session 级 Provider 注册。对于 GC 管理平台，当存在此类显式或平台原生的 terminal cleanup hook 时，等价的逻辑 teardown 仍 MUST 解绑 listener、停止定时器，并取消或标记异步 receiver 为 stale，确保延迟结果既不会阻止对象图被回收，也不会修改已释放的 native 资源或宿主可见状态。若 GC 管理的命令式平台不存在此类 terminal cleanup hook，则主动 cleanup 仍为 SHOULD 而非 MUST |
| Provider 引用 | **SHOULD** | 平台实现 SHOULD 避免 Provider 强引用控件实例，防止循环引用导致内存泄漏（Java/Kotlin 使用 WeakReference、Swift 使用 weak/unowned、Dart 无需特殊处理） |

### 16.3 `SweetEditorController` 生命周期（声明式框架）

`SweetEditorController` 只关联一个声明式 editor 实例。它由宿主代码创建，在 `SweetEditor` 构造时传入，并且仅作为该 editor 实例的宿主可见转发入口存在。显式 `close()` / `dispose()` / `release()` 仅在存在时表示 controller 的终结性 teardown，而不是普通 widget 移除。

| 阶段 | 约束级别 | 规则 |
|---|---|---|
| 创建 | **MUST** | Controller MUST 由宿主代码创建，并在 `SweetEditor` 构造时传入；生命周期由宿主管理 |
| 关联建立 | **MUST** | `SweetEditorController` 与 `SweetEditor` 实例之间的关联 MUST 在该 editor 实例构造时建立，并在该 editor 生命周期内保持固定不变 |
| 内部 attach | **MUST** | widget/session MUST 在初始化或挂载时完成内部 attach，并在该 editor 实例的终结性清理过程中完成内部 detach |
| teardown 后状态 | **MUST** | 关联的 editor 实例进入终结性 teardown 后，Controller MUST 进入 inactive 状态。后续影响运行时的操作 MUST 为 no-op 或返回默认值 |
| 所有权边界 | **MUST** | Controller MUST NOT 拥有已绑定 widget/session 的运行时。`EditorCore`、render/runtime 对象、overlay 运行时、focus/gesture 管线以及当前绑定下的定时器 / listener 都归当前已绑定 widget/session 所有 |
| 显式 teardown（若提供） | **MAY** | 平台 MAY 提供 `dispose()` / `close()` / `release()` 等显式 terminal controller teardown 方法；若宿主生命周期或平台原生销毁语义已经能够保证 terminal teardown，则无论 GC 还是非 GC 平台，都不强制额外提供 |
| 重新绑定 | **MUST NOT** | `SweetEditorController` 在首次建立关联后 MUST NOT 重新绑定到其他 widget/session/editor 实例 |
| teardown 顺序与边界 | **MUST** | 若平台提供显式 controller teardown 方法，该方法 MUST 先从关联 widget/session detach（如果仍已 attach），再释放 controller 自身持有的内部状态，清空 ready 回调与内部 pending callback，取消定时器 / listener / receiver / 在途异步工作，并切断引用链。teardown 后任何方法调用 MUST 为 no-op 或返回默认空值。Controller MUST NOT 假定自己拥有绑定的控件，也 MUST NOT 直接销毁 `View` / `Control` / `Widget` 本身 |
| 声明式重建 | **SHOULD** | 只要底层已挂载的 editor runtime 未变化，普通声明式重建 SHOULD 继续复用同一个 controller 关联，且 MUST NOT 被视为重新绑定 |

> 本节只适用于存在独立 controller 对象的平台；不得据此要求所有命令式 `View` / `Control` / `Widget` / `Document` 类型都新增库自定义的 `dispose()` / `close()` 方法。内部 detach 表示 controller 不再连接其关联的 editor session。controller 的 teardown 语义是 controller 自身的终结性失活，而不是接管或销毁其绑定控件的生命周期。

### 16.4 资源释放顺序

当平台执行 editor 释放 / dispose / close / 最终 teardown 时，MUST 满足以下安全约束。对于 GC 管理平台，这些约束首先适用于逻辑 teardown 与引用链清理；native 最终回收 MAY 稍后发生，只要已 teardown 的对象图不再产生用户可见副作用，也不再触达无效 native 状态。

- 所有进行中的异步 Provider 请求 MUST 在其结果可能到达无效 native 状态之前被取消或标记为 stale
- Provider 注册 MUST 在其继续向已销毁 editor 发出回调之前被清除或终结性停用
- 对宿主可见的事件订阅 / listener / observer MUST 在销毁后的回调发生之前被清除
- `EditorCore` / native 资源 MUST 恰好释放一次，并且只能在后续不会再有合法平台回调使用它们之后释放
- 平台特定资源（纹理、画布、定时器等）MAY 按平台惯用顺序释放，只要上述约束得到满足

> 本节定义的是依赖 / 安全约束，而不是所有平台都必须逐条照搬的固定步骤顺序。

---

## 17. 数据模型字段定义（MUST）

Core 层定义了大量装饰数据类型，各平台 MUST 实现完全一致的字段。本节明确每个数据类型的 MUST 字段、构造约束和不可变性要求。

### 17.1 通用约束

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 不可变性 | **SHOULD** | 所有 Adornment 数据类型（`StyleSpan`、`InlayHint` 等）SHOULD 为不可变对象（Java: `final` 字段、C#: `sealed record` 或只读属性、Swift: `struct` / `let`、Dart: `final` 字段） |
| 构造方式 | **MUST** | 每个数据类型 MUST 提供包含所有 MUST 字段的构造函数（或等效工厂方法）；MAY 额外提供 Builder 模式 |
| 字段名 | **MUST** | 字段名 MUST 遵循第 2.2 节的跨平台命名规则 |
| 坐标基准 | **MUST** | 所有行号（`line`）和列号（`column`）MUST 为 0-based；列号以 UTF-16 字符偏移为单位 |

### 17.2 共享数据类型

**`IntRange`** — 闭区间整数范围

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `start` | int | **MUST** | 闭区间起点 |
| `end` | int | **MUST** | 闭区间终点；当 `end < start` 时表示空范围 |

**`TextChange`** — 增量文本变更

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `range` | TextRange | **MUST** | 文档坐标中的变更范围 |
| `newText` | String | **MUST** | 替换后的文本；空字符串表示纯删除 |

### 17.3 Adornment 数据类型

**`StyleSpan`** — 行内高亮区间

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `column` | int | **MUST** | 起始列（0-based，UTF-16 偏移） |
| `length` | int | **MUST** | 字符长度 |
| `styleId` | int | **MUST** | 通过 `registerTextStyle()` 注册的样式 ID |

**`TextStyle`** — 文本样式定义

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `color` | int | **MUST** | 前景色（ARGB） |
| `backgroundColor` | int | **MUST** | 背景色（ARGB），0 表示透明 |
| `fontStyle` | int | **MUST** | 字体样式位标志：`BOLD=1`, `ITALIC=2`, `STRIKETHROUGH=4` |

**`InlayHint`** — 行内嵌入提示

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `type` | InlayType | **MUST** | 类型：TEXT=0, ICON=1, COLOR=2 |
| `column` | int | **MUST** | 插入列（0-based，UTF-16 偏移） |
| `text` | String? | **MUST** | 文本内容（TEXT 类型时 MUST 非空；其他类型 MAY 为 null） |
| `intValue` | int | **MUST** | 整数值（ICON 类型时为 iconId；COLOR 类型时为 ARGB 颜色值；TEXT 类型时为 0） |

> 各平台 SHOULD 提供便捷工厂方法：`TextHint(column, text)`、`IconHint(column, iconId)`、`ColorHint(column, color)`。

**`PhantomText`** — 幽灵文本

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `column` | int | **MUST** | 插入列（0-based，UTF-16 偏移） |
| `text` | String | **MUST** | 幽灵文本内容 |

**`CodeLensItem`** — 显示在代码行上方的可点击标签

同一代码行上的多个 CodeLens **MUST** 按 `column` 升序排列，同时仍然渲染在该代码行上方。

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `column` | int | **MUST** | 逻辑行内的列锚点，用于排序和点击命中回传 |
| `text` | String | **MUST** | 显示文本 |
| `commandId` | int | **MUST** | 回传到 `CodeLensClickEvent` 的唯一命令标识 |

**`LinkSpan`** — 逻辑行内的可点击文本区间

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `column` | int | **MUST** | 逻辑行内的起始列（0-based，UTF-16 偏移） |
| `length` | int | **MUST** | 可点击区间的字符长度 |
| `target` | String | **MUST** | 由 `getLinkTargetAt()` 和 `LinkClickEvent` 返回的解析后链接目标 |

**`GutterIcon`** — 行号区图标

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `iconId` | int | **MUST** | 图标资源 ID（由平台侧 `EditorIconProvider` 解析和绘制） |

**`Diagnostic`** — 诊断信息

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `column` | int | **MUST** | 起始列（0-based，UTF-16 偏移） |
| `length` | int | **MUST** | 字符长度 |
| `severity` | int | **MUST** | 严重级别：ERROR=0, WARNING=1, INFO=2, HINT=3 |

> 本标准中的 `Diagnostic` 是最小诊断装饰模型，用于诊断渲染与轻量交互，不等同于完整 IDE 诊断对象。

**`FoldRegion`** — 可折叠区域

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `startLine` | int | **MUST** | 折叠区域起始行（0-based，该行保持可见） |
| `endLine` | int | **MUST** | 折叠区域结束行（0-based，inclusive） |

**`IndentGuide`** — 缩进引导线

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `start` | TextPosition | **MUST** | 起始位置 |
| `end` | TextPosition | **MUST** | 结束位置 |

**`BracketGuide`** — 括号配对引导线

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `parent` | TextPosition | **MUST** | 父括号位置 |
| `end` | TextPosition | **MUST** | 结束括号位置 |
| `children` | List\<TextPosition\> | **MUST** | 子节点位置列表 |

**`FlowGuide`** — 控制流引导线

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `start` | TextPosition | **MUST** | 起始位置 |
| `end` | TextPosition | **MUST** | 结束位置 |

**`SeparatorGuide`** — 分隔线

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `line` | int | **MUST** | 所在行号（0-based） |
| `style` | `SeparatorStyle` | **MUST** | 分隔线样式 |
| `count` | int | **MUST** | 重复次数 |
| `textEndColumn` | int | **MUST** | 文本结束列（用于确定分隔线起始绘制位置） |

---

### 17.4 Visual 渲染类型

**`EditorRenderModel`** — `buildRenderModel()` 返回的不可变渲染快照

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `pointerCursorType` | PointerCursorType | 桌面端 **MUST**，纯触摸平台 **MAY** | 当前快照中鼠标位置对应的指针样式提示 |

> 桌面平台 SHOULD 将 `pointerCursorType` 映射到原生鼠标形状，通常文本编辑区域使用 `TEXT`，可点击交互内容使用 `HAND`，滚动条或 gutter 等中性区域在合适时使用 `DEFAULT`。

> 在同时暴露这两个字段的平台上，`GestureResult.pointerCursorType` 与 `EditorRenderModel.pointerCursorType` SHOULD 保持语义一致。平台 MAY 用前者做即时鼠标更新，用后者作为最新稳定快照状态。

**`VisualRun`** — 一条已解析的渲染 run

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `type` | VisualRunType | **MUST** | run 的语义类型 |
| `iconId` | int | **MUST** | 对 `INLAY_HINT(ICON)` 表示图标资源 id；对 `CODELENS` 表示唯一 `commandId` |
| `active` | boolean | **MUST** | 可点击 run 的渲染期交互激活态，例如 `CODELENS` 和 `LINK` |

**`VisualLine`** — 一条已解析的视觉行

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `kind` | VisualLineKind | **MUST** | 视觉行语义类型 |
| `ownsGutterSemantics` | boolean | **MUST** | 是否承担行号、gutter icon、fold marker 的语义归属 |

> `CODELENS` 表示虚拟 visual line。同一逻辑行对应的第一条真实内容行 MUST 通过 `ownsGutterSemantics` 标识，而不是根据 `wrapIndex` 推断。

> 平台 MUST 使用 Core 提供的 `active` 状态渲染可点击 run，并对 `CODELENS` 与 `LINK` 一致应用对应的 hover 或 pressed 样式。

## 18. Document 规范（MUST）

`Document` 是编辑器的核心数据类型，包装 C++ 侧文档句柄。

### 18.1 构造方式

所有平台 MUST 至少支持以下两种构造方式：

| 方式 | 约束级别 | 说明 |
|---|---|---|
| 从字符串 | **MUST** | `Document(text: String)` - 从内存中文本内容创建 |
| 从文件路径 | **SHOULD** | `Document(file: File)` / `Document(path: String)` - 从本地文件创建；大文件加载策略由平台自行决定 |

> 构造参数命名和类型 MAY 因平台不同而变化（如 Java `File`、C# `string path`、Swift `URL`），但语义 MUST 一致。

### 18.2 公共方法

| 方法 | 约束级别 | 说明 |
|---|---|---|
| `getLineCount()` | **MUST** | 返回文档总行数 |
| `getLineText(line)` | **MUST** | 返回指定行的文本内容（不含行尾符） |
| `getText()` | **SHOULD** | 返回完整文档文本 |

### 18.3 内部实现

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 原生文档引用 | **MUST** | `Document` 内部 MUST 保留一个指向 C++ 侧文档实例的桥接层引用；无论其表示为 opaque handle、pointer wrapper、object wrapper 还是其他机制，都属于实现细节 |
| 资源释放 | **MUST** | 当 `Document` 到达其平台生命周期中的终止状态时，桥接层 MUST 最终释放 C++ 侧文档内存。具体清理机制由平台决定；无论 GC 还是非 GC 平台，显式 `dispose()` / `close()` API 都是可选的 |
| 编码模型 | **MUST** | 平台层 MUST NOT 假设或暴露特定的内部存储 / 布局编码；只可依赖公共 API 保证的语义 |
| 行尾符 | **MUST** | C++ Core 支持 LF、CR、CRLF 三种行尾符；`getLineText()` 返回的文本 MUST NOT 包含行尾符 |

### 18.4 与 `loadDocument()` 的关系

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 加载时机 | **MUST** | `Document` 创建后 MUST 通过 `loadDocument(doc)` 成为编辑器的当前文档，或者在声明式平台上通过声明式初始化输入成为首个 attach 后 editor session 的当前文档。若声明式初始化使用的是 `text` 而不是 `document`，平台 MUST 先基于该文本物化一个等价的 `Document`，并将该物化出来的 `Document` 视为当前文档。尚未成为任何 editor session 当前文档的 `Document` 不会触发渲染或编辑器事件 |
| 文档替换 | **MUST** | 再次调用 `loadDocument()` 会替换当前文档。在声明式平台上，若同一个已挂载 editor runtime 的声明式当前文档输入发生变化，其语义等价于替换当前文档。若声明式更新使用的是 `text`，则替换后的文档就是基于该文本新物化出来的 `Document`。旧文档的引用由宿主代码管理 |
| 文档所有权 | **SHOULD** | 同一个 `Document` 实例 SHOULD NOT 同时加载到多个编辑器实例 |

---
## 19. `EditorMetadata` 与 `LanguageConfiguration` 字段定义（MUST）

### 19.1 `EditorMetadata`

`EditorMetadata` 是一个**语义概念类型**，表示宿主附加到编辑器实例上的自定义元数据。平台层只负责存取，不解释其内部结构。

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 表示形式 | **MUST** | 平台 MUST 提供一种可承载任意宿主自定义元数据的表示形式；MAY 使用 marker interface / protocol / abstract class / base class / `Object` / `any` / `unknown` / 泛型 payload 等 |
| 显式类型命名 | **SHOULD** | 若平台选择暴露显式公共类型，SHOULD 命名为 `EditorMetadata`；按语言惯例 MAY 使用 `IEditorMetadata`、`SEEditorMetadata` 等允许变体 |
| 用途 | **MUST** | 宿主代码通过 `setMetadata()` / `getMetadata()` 存取自定义元数据（如文件路径、语言 ID 等）；平台层 MUST 将其视为 opaque value，不做语义解析 |
| 取回语义 | **MUST** | `getMetadata()` MUST 返回之前设置的同一 metadata 值或 `null`；如果平台暴露的是宽泛类型（如 `Object?`），宿主代码负责自行断言 / 转型到具体类型 |

### 19.2 `LanguageConfiguration`

`LanguageConfiguration` 描述特定编程语言的元信息。

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `languageId` | String | **MUST** | 语言标识符（如 `"java"`、`"cpp"`、`"swift"`） |
| `brackets` | List\<BracketPair\>? | **MAY** | 括号对列表（null 表示未配置；为 null 时平台 MUST NOT 同步到 Core） |
| `autoClosingPairs` | List\<BracketPair\>? | **MAY** | 自动闭合括号对列表（null 表示未配置；为 null 时平台 MUST NOT 同步到 Core） |
| `tabSize` | int / int? | **MAY** | 制表位宽度 |
| `insertSpaces` | bool / bool? | **MAY** | 按下 Tab 时是否插入空格而不是硬 Tab 字符 |

**`BracketPair`** 子类型：

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `open` | String | **MUST** | 开括号（如 `"("`、`"{"`、`"["`） |
| `close` | String | **MUST** | 闭括号（如 `")"`、`"}"`、`"]"`） |

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 构造方式 | **SHOULD** | SHOULD 提供 Builder 模式构造（Java/Kotlin），MAY 使用直接构造函数或命名参数构造函数（Swift/C#/Dart/ArkTS） |
| 不可变性 | **SHOULD** | 构造完成后 SHOULD 为不可变对象 |
| 可空性与默认值 | **MUST** | 平台 MAY 将 `tabSize` / `insertSpaces` 暴露为可空或非可空字段。若为可空，`null` MAY 表示“使用编辑器默认值”；若为非可空，其默认值 MUST 与编辑器默认值一致 |
| 运行时效果 | **MUST** | 调用 `setLanguageConfiguration()` 后，编辑器可见的括号匹配、自动闭合行为，以及 Tab 插入行为 MUST 与新配置保持一致 |
| `tabSize` 语义 | **MUST** | `tabSize` 与 `insertSpaces` MUST 被视为两个独立维度：`tabSize` 控制制表位宽度，`insertSpaces` 控制 Tab 键插入空格还是硬 Tab 字符 |
| `insertSpaces=true` 行为 | **MUST** | 当 `insertSpaces` 为 `true` 时，Tab 键 / `INSERT_TAB` 命令 MUST 插入到下一个制表位所需数量的空格，而不是始终插入固定 `tabSize` 个空格 |

---
## 20. 性能指导与参考目标（SHOULD）

基于 `perf/` 模块（`PerfOverlay`、`PerfStepRecorder`、`MeasurePerfStats`）和 C++ Core 的 `PERF_TIMER` 宏，本节定义跨平台性能指导和参考目标，而不是硬性的合规门槛。

### 20.1 运行时性能不变量

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 视口范围渲染 | **MUST** | 平台侧 layout 和 paint MUST 限于可见区域（必要时可带少量前瞻 buffer）；普通滚动 MUST NOT 依赖整篇文档重排或重绘 |
| Provider 非阻塞 | **MUST** | 慢速 decoration / completion provider MUST NOT 阻塞宿主可见交互路径上的输入、滚动或绘制 |
| 过期异步结果 | **MUST** | 过期的异步 provider 结果 MUST 在修改可见编辑器状态前被取消或丢弃 |
| Core / 布局重复计算 | **MUST** | 平台热路径 MUST NOT 冗余重算 Core 已经产出且可直接消费的几何或布局信息 |
| 性能诊断 | **SHOULD** | 平台 SHOULD 保留足够的计时钩子，以支持 PerfOverlay 或等效 debug-only 性能诊断 |

### 20.2 参考目标

以下数值是面向 release build 和代表性硬件的参考目标，属于优化目标，不作为合规判定。

| 指标 | 约束级别 | 目标值 | 说明 |
|---|---|---|---|
| 滚动帧率 | **SHOULD** | >= 60fps（参考硬件） | 10K 行以内文档滚动应尽量接近 60fps |
| `buildRenderModel()` 耗时 | **SHOULD** | <= 8ms | 超过 8ms 记为 SLOW（与各平台 `WARN_BUILD_MS` 保持一致） |
| 单帧绘制耗时 | **SHOULD** | <= 8ms | 超过 8ms 记为 SLOW（与各平台 `WARN_PAINT_MS` 保持一致） |
| 单帧总耗时 | **SHOULD** | <= 16.6ms | 超过 16.6ms 记为 SLOW FRAME |
| 单个渲染步骤 | **SHOULD** | <= 2ms | 超过 2ms 在 PerfOverlay 中以 `!` 标记（与 `WARN_PAINT_STEP_MS` 一致） |
| 输入路径延迟 | **SHOULD** | <= 3ms | 从手势 / 键盘事件到 Core 处理完成的时间（与 `WARN_INPUT_MS` 一致） |

### 20.3 大文档性能指导

| 场景 | 约束级别 | 指导 |
|---|---|---|
| 100K 行文档加载 | **SHOULD** | 使用 memory mapping、streaming load 或其他等效大文件策略，避免一次性分配全部内存；参考目标是在代表性硬件上 <= 500ms |
| 100K 行文档滚动 | **SHOULD** | 依赖视口渲染（仅布局和绘制可见行）；参考目标是在代表性硬件上 >= 30fps |
| 内存占用 | **SHOULD** | 100K 行文档的平台层内存占用参考目标 <= 50MB（不含 C++ Core 文档存储） |

### 20.4 Provider 超时指导

| 规则 | 约束级别 | 说明 |
|---|---|---|
| `DecorationProvider` timeout | **SHOULD** | 若 5 秒内没有交付 decoration 结果，Manager SHOULD 取消或将该请求标记为过期 |
| `CompletionProvider` timeout | **SHOULD** | 若 3 秒内没有交付 completion 结果，Manager SHOULD 取消或将该请求标记为过期 |
| `NewLineActionProvider` 延迟 | **MUST/SHOULD** | `provideNewLineAction()` MUST 保持输入路径同步，并且在参考硬件上 SHOULD 落在亚毫秒到 1ms 预算内；MUST NOT 引入用户可感知的 Enter 延迟 |

### 20.5 `PerfOverlay` 调试面板（SHOULD）

| 规则 | 约束级别 | 说明 |
|---|---|---|
| API | **SHOULD** | 各平台 SHOULD 提供 `setPerfOverlayEnabled(bool)` / `isPerfOverlayEnabled()` API |
| 默认状态 | **MUST** | PerfOverlay MUST 默认关闭，仅用于调试 |
| 显示位置 | **SHOULD** | 开启时 SHOULD 在编辑器区域左上角显示半透明性能面板 |
| 显示内容 | **SHOULD** | SHOULD 至少包含：FPS、每帧总/build/draw 耗时、文本测量统计 |
| 稳定性 | **MUST** | PerfOverlay 的字段名、阈值和 step 名称仅用于调试显示，MUST NOT 视为稳定 API 契约 |

---
## 21. 测试规范（SHOULD）

### 21.1 C++ Core 测试

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 测试框架 | **MUST** | C++ Core 使用 Catch2 框架（`tests/` 目录） |
| 回归测试 | **MUST** | 每个核心模块（Document、Layout、Decoration、EditorCore）MUST 有对应的回归测试 |
| 性能基线 | **SHOULD** | SHOULD 使用 Catch2 `BENCHMARK` 宏建立性能基线测试（如 `performance_baseline.cpp`） |
| 覆盖范围 | **SHOULD** | SHOULD 覆盖：文本编辑操作、光标/选区、撤销重做、IME 组合输入、装饰偏移调整、布局映射、滚动指标 |

### 21.2 平台层测试

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 单元测试 | **SHOULD** | 各平台 SHOULD 提供 Core 层数据类型的单元测试（如 `EditorSettings` 默认值验证、`EditorTheme` 工厂方法验证） |
| 集成测试 | **MAY** | MAY 提供控件级集成测试（如创建控件 → 加载文档 → 验证行数） |
| 测试框架 | **SHOULD** | 使用平台惯用的测试框架（Android: JUnit/Espresso、Apple: XCTest、C#: xUnit/NUnit、OHOS: Hypium） |

### 21.3 跨平台一致性验证

| 规则 | 约束级别 | 说明 |
|---|---|---|
| API 契约测试 | **SHOULD** | 各平台 SHOULD 验证 Public API 的行为与标准文档一致（如 `setWrapMode()` 后 `getWrapMode()` 返回相同值） |
| 渲染模型一致性 | **MAY** | MAY 对比不同平台在相同输入下 `buildRenderModel()` 的输出结构（行数、VisualRun 数量等） |
| 事件一致性 | **SHOULD** | SHOULD 验证相同操作在各平台触发相同的事件序列 |

---

## 22. 无障碍规范（MAY）

无障碍（Accessibility）支持为 MAY 级别，但实现时 SHOULD 遵循以下指导。

### 22.1 基础无障碍属性

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 角色标注 | **SHOULD** | 编辑器控件 SHOULD 标注为"文本编辑器"角色（Android: `AccessibilityNodeInfo.setClassName("android.widget.EditText")`、iOS: `accessibilityTraits = .updatesFrequently`、macOS: `NSAccessibilityRole.textArea`） |
| 文本内容 | **SHOULD** | SHOULD 向无障碍服务暴露当前可见文本内容 |
| 光标位置 | **SHOULD** | SHOULD 向无障碍服务暴露当前光标位置和选区范围 |
| 行号信息 | **MAY** | MAY 向无障碍服务暴露当前行号和总行数 |

### 22.2 键盘导航

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 焦点管理 | **SHOULD** | 编辑器控件 SHOULD 能通过 Tab 键获取和释放焦点 |
| 键盘快捷键 | **SHOULD** | 桌面平台 SHOULD 支持标准键盘快捷键（Ctrl/Cmd+C/V/X/Z/A 等） |
| 屏幕阅读器兼容 | **MAY** | MAY 支持屏幕阅读器的文本朗读（VoiceOver、TalkBack、Narrator） |

### 22.3 视觉辅助

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 高对比度 | **MAY** | MAY 提供高对比度主题或响应系统高对比度设置 |
| 字体缩放 | **SHOULD** | SHOULD 响应系统字体缩放设置（通过 `setScale()` 或 `setEditorTextSize()`） |
| 光标可见性 | **SHOULD** | 光标 SHOULD 有足够的视觉对比度，且闪烁频率 SHOULD 在 0.5–2Hz 之间 |

---

## 23. 版本管理

本标准适用于 2026-03 起的 SweetEditor 平台实现。当 C++ 核心新增枚举、事件或 API 方法时，所有平台 MUST 在同一发布周期内同步更新。

### 23.1 平台包版本号规范

平台层发布包的版本号 MUST 与 C++ Core 版本号保持对齐关系。版本号格式为 `a.b.c`（主版本.次版本.修订号）。

| 版本段 | 约束级别 | 规则 | 示例（Core 版本 `1.0.0`） |
|---|---|---|---|
| `a`（主版本） | **MUST** | 平台包主版本号 MUST 与 Core 主版本号一致，不得超过 | 平台包 `1.x.x` ✅；`2.0.0` ❌ |
| `b`（次版本） | **SHOULD** | 平台包次版本号 SHOULD 不超过 Core 次版本号 `+9`；超出需书面说明理由 | Core `1.0.0` → 平台包 `1.9.x` 为上限建议 |
| `c`（修订号） | **MAY** | 平台包修订号可自由递增，用于平台特定的 bugfix 或补丁 | `1.0.15` ✅ |

- 当 Core 发布新的主版本（如 `2.0.0`）时，所有平台包 MUST 在同一发布周期内升级主版本号。
- 平台包 MAY 在 Core 版本不变的情况下独立发布修订版本（`c` 段递增），用于修复平台特定问题。
- 次版本号（`b` 段）的建议上限是为了避免平台包版本号与 Core 版本号差距过大，造成版本对应关系混乱。
