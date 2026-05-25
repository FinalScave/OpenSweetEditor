# 平台实现标准

> 本文档定义了每个 SweetEditor 平台实现必须遵循的约定和约束。
> 目标是在允许平台特定渲染和输入处理的同时，保持跨平台行为一致。
>
> 本文档描述的是当前仓库代码状态（2026-05）。若文档与源码不一致，以源码为准。
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
| **Core Bridge** | `EditorCore`, `Document`, `ProtocolEncoder`, `ProtocolDecoder`, `TextMeasurer`, `EditorOptions`, `EditorActionResult`, `EditorActionReason` | 原生桥接 + 公共核心 API 封装；`EditorActionResult` 是变更类 core API 的统一结果载体 |
| **Foundation** | `TextPosition`, `TextRange`, `IntRange`, `TextChange`, `WrapMode`, `FoldArrowMode`, `AutoIndentMode`, `CurrentLineRenderMode`, `ScrollBehavior` | 基础值类型与枚举 |
| **IME** | `ImeSyncSnapshot`, `ImeInputContext`, `ImeTextRange`, `ImeScriptClass`, `ImePreeditStorage`, `ImeContextPolicy`, `ImeInputContextKind`, `ImeTextModelMode`；暴露 unit-aware 删除 API 时包含 `ImeTextUnit` | IME 同步快照和文本上下文协议类型；平台侧同步决策由 `EditorActionResult` 承载 |
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
| **Event** | 类型安全事件机制、`EditorEvent`、`TextChangedEvent`、`CursorChangedEvent`、`SelectionChangedEvent`、`ScrollChangedEvent`、`ScaleChangedEvent`、`DocumentLoadedEvent`、`FoldToggleEvent`、`GutterIconClickEvent`、`InlayHintClickEvent`、`CodeLensClickEvent`、`LinkClickEvent`、`LongPressEvent`*(移动端 / 触摸平台)*、`DoubleTapEvent`、`ContextMenuEvent`*(具有显式上下文菜单手势入口的平台)*；若采用显式事件总线 / 监听器模式，推荐 `EditorEventBus`、`EditorEventListener` | 事件系统 |
| **NewLine** | `NewLineActionProvider`, `NewLineActionProviderManager`, `NewLineAction`, `NewLineContext` | 换行动作提供者系统 |
| **Keymap** | `EditorKeyMap` | Widget 层 keymap 扩展，用于将 commandId 绑定到宿主侧处理器 |
| **Copilot** *(SHOULD)* | `InlineSuggestion`、`InlineSuggestionListener` 或等价的 accept/dismiss 回调机制 | 内联建议数据 + 回调；主路径为 listener 形态 |
| **Selection** *(移动端 SHOULD；桌面端 MAY 省略)* | `SelectionMenuItem`、`SelectionMenuItemProvider`、宿主可见的 custom item 点击回调机制；MAY: `SelectionMenuListener` | 选区菜单（移动端 SHOULD；桌面端 MAY 省略） |
| **ContextMenu** *(桌面 / mouse / right-click 平台 SHOULD；纯触摸平台 MAY)* | `ContextMenuRequest`、`ContextMenuSection`、`ContextMenuItem`、`ContextMenuItemProvider`、`ContextMenuTriggerKind`、宿主可见的 custom item 点击回调机制；MAY: `ContextMenuPopup` | 平台侧的上下文菜单 / 动作菜单 |
| **Perf** *(MAY)* | `PerfOverlay`, `MeasurePerfStats`, `PerfStepRecorder` | 调试性能浮层 |

> `TextChangeAction` 为 SHOULD 级辅助事件枚举。平台 MAY 暴露它用于粗粒度标识一次文本变更周期（如 `INSERT` / `DELETE` / `UNDO` / `REDO` / `KEY` / `COMPOSITION`），但 MUST NOT 用它替代 `changes: List<TextChange>` 这一主增量载荷。

### 1.3 内部实现自由（SHOULD）

内部 renderer、popup controller、overlay controller 等都属于实现细节，不属于公共 API 契约。平台 MAY 按自身 UI 框架组织这些对象；只要第 1.1、1.2 与后续公共契约满足，不采用特定内部 controller / renderer 名称不视为违规。

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

编辑器包含大量命令式操作，不同 UI 范式的 API 载体不同，但运行时所有权必须一致。

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 命令式框架 | **MUST** | 第 3.2 节的 API，以及已实现可选模块定义的宿主 API，MUST 直接在控件入口类（如 `SweetEditor`、`SweetEditorView`、`SweetEditorControl`）上暴露；平台 MAY 额外提供 `SweetEditorController` |
| 声明式框架 | **MUST** | MUST 提供 `SweetEditorController` 作为宿主持有的唯一命令式入口；控件入口类 MUST 接受 `controller` 构造参数。`SweetEditor` 仍是 runtime/session owner，controller 仅转发调用，MUST NOT 拥有 view、runtime、`EditorCore`、provider 注册或 session 级状态 |
| Controller 绑定 | **MUST** | Controller 与 editor 实例的关联 MUST 在该 editor 实例构造时建立并保持固定。同一 Controller MUST NOT 同时绑定多个控件，且首次关联后 MUST NOT 重新绑定到其他 widget/session/editor 实例。内部 `bind` / `unbind` 只表示首次 attach 与终结性 detach；保留同一已挂载 runtime 的普通声明式重建不属于重新绑定 |
| Public API 覆盖 | **MUST** | 声明式平台的 Controller MUST 暴露第 3.2 节定义的全部必需宿主 API，以及已实现可选模块对应的宿主 API。第 3.1 节的 `EditorCore` 方法属于 bridge/runtime API，默认不属于 Controller 必需表面 |
| Ready gate | **MUST** | Controller MUST 提供 `whenReady(callback)` 或等价 ready 机制。首次 attach 前，变更类调用 MUST 被忽略或拒绝而不是排队；getter SHOULD 返回 `null` 或默认值且 MUST NOT 抛出异常；平台 MUST NOT 为 pre-ready 调用创建隐藏 runtime 或隐藏暂存层 |
| 声明式初始化输入 | **MAY / MUST** | 声明式平台 MAY 暴露 `document`、`text`、`theme`、`settings`、`keyMap` 等初始化输入；若暴露，MUST 将其视为构造/配置输入而不是 pre-ready controller 调用。`document` 与 `text` 同时存在时 `document` 优先；仅提供 `text` 时平台 MUST 物化等价 `Document`，ready 后 `getDocument()` MUST 返回该对象 |
| 显式 teardown | **MAY / MUST** | 平台 MAY 提供 `dispose()` / `close()` / `release()` 等 terminal controller teardown。若提供，它 MUST 只释放 controller 自身持有的 ready 回调、pending callback 与引用链，MUST NOT 假定 controller 拥有 session 级 provider 或 runtime；teardown 后后续调用 MUST 为 no-op 或返回默认空值 |

---

### 3.1 `EditorCore` Public API

第 3.1 节定义由 `EditorCore` 承载的 bridge/runtime API。这里包含低层渲染快照、手势循环、键盘分发和动画 tick 方法。除非平台显式选择对外暴露 `EditorCore` 本身，否则这些方法不属于默认的宿主可见编辑器接口表面。

所有变更类 `EditorCore` API（包括配置写入、手势、键盘、文本编辑、IME 写入、光标/选区写入、滚动/导航、decoration、folding、linked editing 和动画 tick）MUST 返回 `EditorActionResult` 或平台语言中的等价类型。查询类 API 继续返回自身语义值；`buildRenderModel()` 属于渲染快照查询，不返回 `EditorActionResult`。平台层 MUST 将每个非空 `EditorActionResult` 交给统一结果分发入口处理，不能再根据调用的方法名、setter 类型或局部经验自行推断是否需要触发文本事件、IME 同步、动画、flush 或 repaint。

在 editor runtime / dispatcher 尚未建立的构造或首帧 bootstrap 阶段，平台 MAY 合并 setup 类 `EditorActionResult`，并在 dispatcher ready 后执行等价的状态分发、IME 同步和刷新。该例外只适用于 dispatcher 不存在的初始化窗口；runtime ready 后产生的每个非空 `EditorActionResult` 都 MUST 经统一分发入口处理。

| 能力族 | `EditorCore` 必须包含的 API |
|---|---|
| 配置 | `loadDocument(doc)`, `setViewport(w, h)`, `onFontMetricsChanged()`, `setFoldArrowMode(mode)`, `setWrapMode(mode)`, `setTabSize(size)`, `setInsertSpaces(enabled)`, `setScale(scale)`, `setLineSpacing(add, mult)`, `setContentStartPadding(padding)`, `setShowSplitLine(show)`, `setCurrentLineRenderMode(mode)`, `setGutterSticky(sticky)`, `setGutterVisible(visible)`, `setHandleConfig(...)`, `setScrollbarConfig(...)` |
| 渲染模型 | `buildRenderModel()`, `getLayoutMetrics()` |
| 手势 / 键盘 | `handleGestureEvent(...)`, `handleGestureEventEx(...)`, `tickEdgeScroll()`, `tickFling()`, `tickAnimations()`, `handleKeyEvent(...)`, `setKeyMap(keyMap)` |
| 文本编辑 | `insertText(text)`, `replaceText(range, text)`, `deleteText(range)`, `backspace()`, `deleteForward()`, `moveLineUp()`, `moveLineDown()`, `copyLineUp()`, `copyLineDown()`, `deleteLine()`, `insertLineAbove()`, `insertLineBelow()` |
| 撤销 / 重做 | `undo()`, `redo()`, `canUndo()`, `canRedo()` |
| 光标 / 选区 | `setCursorPosition(line, col)`, `getCursorPosition()`, `selectAll()`, `setSelection(sL, sC, eL, eC)`, `getSelection()`, `getSelectedText()`, `getWordRangeAtCursor()`, `getWordAtCursor()`, `moveCursorLeft(extend)`, `moveCursorRight(extend)`, `moveCursorUp(extend)`, `moveCursorDown(extend)`, `moveCursorToLineStart(extend)`, `moveCursorToLineEnd(extend)` |
| IME | `getImeSyncSnapshot()`, `getImeInputContext(...)`, `getImeTextModelInputContext(...)`, `setImeKeyboardScriptClass(script)`, `getImeKeyboardScriptClass()`, `updateImePreedit(...)`, `setImeComposingText(...)`, `commitImeText(...)`, `replaceImeText(...)`, `finishImePreedit()`, `cancelImePreedit()`, `markImeDocumentRange(...)`, `markImeInputContextRange(...)`, `updateImeTextModelState(...)`, `updateImeTextModelDelta(...)`, `deleteImeBackward(length, unit)`, `deleteImeForward(length, unit)`, `deleteImeSurrounding(before, after, unit)`, `notifyImeSelectionChanged(range)`, `notifyImeCursorChanged(cursor)`, `getComposingRange()`, `getComposingSessionRange()`, `isComposing()` |
| 只读 / 缩进 | `setReadOnly(readOnly)`, `isReadOnly()`, `setAutoIndentMode(mode)`, `getAutoIndentMode()`, `setBackspaceUnindent(enabled)` |
| 导航 / 滚动 | `scrollToLine(line, behavior)`, `gotoPosition(line, col)`, `ensureCursorVisible()`, `setScroll(x, y)`, `getScrollMetrics()`, `getPositionRect(line, col)`, `getCursorRect()` |
| 样式 / 高亮 | `registerTextStyle(id, color, bg, fontStyle)`, `registerBatchTextStyles(data)`, `setLineSpans(line, layer, spans)`, `setBatchLineSpans(layer, entries)`, `clearLineSpans(line, layer)`, `clearHighlights(layer)`, `clearHighlights()` |
| Inlay Hint | `setLineInlayHints(line, hints)`, `setBatchLineInlayHints(entries)`, `clearInlayHints()` |
| Phantom Text | `setLinePhantomTexts(line, phantoms)`, `setBatchLinePhantomTexts(entries)`, `clearPhantomTexts()` |
| Gutter Icon | `setLineGutterIcons(line, icons)`, `setBatchLineGutterIcons(entries)`, `setMaxGutterIcons(count)`, `clearGutterIcons()` |
| CodeLens | `setLineCodeLens(line, items)`, `setBatchLineCodeLens(entries)`, `clearCodeLens()` |
| Link | `setLineLinks(line, links)`, `setBatchLineLinks(entries)`, `clearLinks()` |
| Diagnostic | `setLineDiagnostics(line, items)`, `setBatchLineDiagnostics(entries)`, `clearDiagnostics()` |
| Guide | `setIndentGuides(guides)`, `setBracketGuides(guides)`, `setFlowGuides(guides)`, `setSeparatorGuides(guides)`, `clearGuides()` |
| Bracket | `setBracketPairs(open, close)`, `setAutoClosingPairs(open, close)`, `setMatchedBrackets(oL, oC, cL, cC)`, `clearMatchedBrackets()` |
| 折叠 | `setFoldRegions(regions)`, `toggleFoldAt(line)`, `foldAt(line)`, `unfoldAt(line)`, `foldAll()`, `unfoldAll()`, `isLineVisible(line)` |
| 清除 | `clearAllDecorations()` |
| Linked Editing | `insertSnippet(template)`, `startLinkedEditing(model)`, `isInLinkedEditing()`, `linkedEditingNext()`, `linkedEditingPrev()`, `cancelLinkedEditing()` |

IME API 是平台输入事件进入 core 的请求入口。平台标准约束的是语义能力族，而不是要求每个平台调用全部 bridge 函数。平台层 MUST NOT 因为系统 IME 请求 surrounding text、候选上下文或光标矩形，就创建 editor composition。是否建立 composition 只取决于系统 IME 是否通过 composing / marked / preedit API 明确声明了组合文本或组合范围；提交、替换、删除和 selection 同步仍由 core 按 `docs/zh/ime-composition-standard.md` 裁决。

平台层向 core 标记 composition 范围时 MUST 明确这是平台 IME 声明的 composing / marked range。Android 的 `InputConnection.setComposingRegion`、Apple marked range、Windows TSF composition range 都不能由平台层直接当成整词替换命令。光标进入英文单词时平台层和 core 都不得自动开启整词 composition。

平台层 MUST 将光标变化、选区变化、composition 更新、候选提交、删除、finish/cancel 等事件同步给 core。中文键盘未声明 composition 时只表示不建立 SweetEditor 可见 composition；这不能被实现成禁用系统 IME、阻断中文候选提交或阻断中文联想候选。

IME 相关 offset MUST 明确坐标空间：文档 line/column API 使用 `TextRange`；文档 offset API 使用完整文档 offset；input-context / text-model API 使用以 `documentStartOffset` 为基准的上下文 offset。平台实现 MUST NOT 在这些坐标空间之间隐式混用。

> payload 类 API（如 `setLineSpans`、`setBatchLineSpans`）各平台 MUST 提供高层 typed 封装（如 `setLineSpans(line, layer, spans: List<StyleSpan>)`）。当宿主语言存在自然的公开二进制载体（如 `ByteBuffer`、`NSData`、`byte[]`、`Uint8List`）时，平台 SHOULD 额外公开 raw/binary payload API。若 typed API 与 payload API 同时存在，两者的参数语义与最终 Core 行为 MUST 完全一致。payload 的编码格式由平台自行定义。

#### 3.1.1 IME API 要求级别

`EditorCore` IME API 是 bridge/runtime API。它们用于标准化平台输入适配和可测试性，不要求全部暴露在宿主可见的 `SweetEditor` / controller API 上，也不要求每个平台调用完整函数集合。条件性 MUST 表示平台不需要凭空合成自身不会收到的原生 IME 能力，但一旦平台存在该能力，就 MUST 映射到对应的 core 语义能力族。

| API / 类型 | 要求 | 说明 |
|---|---|---|
| IME 协议类型 | MUST | 至少包含 `ImeSyncSnapshot`、`ImeInputContext`、`ImeTextRange`、`ImeScriptClass`、`ImePreeditStorage`、`ImeContextPolicy`、`ImeInputContextKind`；支持 text-model 同步的平台还 MUST 包含 `ImeTextModelMode` |
| `ImeTextUnit` | SHOULD / 条件性 MUST | 暴露 unit-aware 删除 API 时 MUST 存在；稳定值为 `GRAPHEME = 0`、`CODE_POINT = 1` |
| 同步快照能力 | MUST | 平台输入适配层 MUST 能处理 `EditorActionResult.needsImeSync` 与 `EditorActionResult.imeSync`；需要主动查询时使用 `getImeSyncSnapshot()` 或等价桥接入口 |
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

`ImeSyncSnapshot` 的语义字段 MUST 覆盖：文档光标、文档选区、是否存在 composition session、可见 composition 范围、平台 marked range、`ImePreeditStorage`、`ImeContextPolicy`、以及是否要求平台清除 preedit。`ImeInputContext` 的语义字段 MUST 覆盖：`id`、`revision`、`documentStartOffset`、`text`、`selection`、`hasComposition`、`composition`、`kind`；其中 `text`、`documentStartOffset`、`selection` 和 `composition` 承载 platform text window 及其 selection / composing offsets 语义。`ImeActionResult` 不属于平台协议类型；若 core 内部实现保留该结构，它的内容跨 bridge 时 MUST 汇入 `EditorActionResult`，并通过 `needsImeSync` / `imeSync` 暴露给平台输入适配层。

完整 core bridge 函数列表以 `include/sweeteditor/editor_core.h` 与 `include/sweeteditor/c_api.h` 为准。本标准只约束平台必须保持的 IME 语义和协议字段，不要求把每个 core bridge 函数都暴露为宿主可见 API。

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

第 3.2 节定义宿主可见的编辑器 API。这里有意排除了低层 `EditorCore` 手势循环、动画 tick 和渲染模型生成方法。变更类宿主 API 可以按平台习惯返回 `void`、`EditorActionResult` 或平台等价结果；但只要底层调用产生非空 `EditorActionResult`，平台 runtime 就 MUST 经统一结果分发入口处理它。`flush()` 不再是宿主可见 API 的标准必备项；平台 MAY 保留它作为强制刷新、诊断或兼容 API，但正常刷新/重绘决策 MUST 来自 `EditorActionResult.needsRedraw`。API 载体遵循第 3.0 节。

除标注为 SHOULD / MAY 的项外，下表列出的宿主 API 都是 MUST。各语言 MAY 使用 property、delegate setter、typed stream 或符合平台习惯的等价入口，只要映射清晰且无歧义。

| 能力族 | 宿主可见 API |
|---|---|
| 文档 / 主题 | `loadDocument(doc)`, `getDocument()`, `applyTheme(theme)`, `getTheme()` |
| 配置 | `getSettings()`, `getKeyMap()` *(SHOULD)*, `setKeyMap(keyMap)`, `setEditorIconProvider(provider)` |
| 文本编辑 | `insertText(text)`, `replaceText(range, text)`, `deleteText(range)`, `moveLineUp()`, `moveLineDown()`, `copyLineUp()`, `copyLineDown()`, `deleteLine()`, `insertLineAbove()`, `insertLineBelow()` |
| 撤销 / 重做 | `undo()`, `redo()`, `canUndo()`, `canRedo()` |
| 剪贴板 *(MAY)* | `copyToClipboard()`, `pasteFromClipboard()`, `cutToClipboard()` |
| 光标 / 选区 | `selectAll()`, `getSelectedText()`, `setSelection(sL, sC, eL, eC)`, `getSelection()`, `setCursorPosition(pos)`, `getCursorPosition()`, `getWordRangeAtCursor()`, `getWordAtCursor()` |
| 导航 / 滚动 | `gotoPosition(line, col)`, `scrollToLine(line, behavior)`, `setScroll(x, y)`, `getScrollMetrics()`, `getPositionRect(line, col)`, `getCursorRect()` |
| 折叠 | `toggleFoldAt(line)`, `foldAt(line)`, `unfoldAt(line)`, `isLineVisible(line)`, `foldAll()`, `unfoldAll()` |
| 语言 / 元数据 | `setLanguageConfiguration(config)`, `getLanguageConfiguration()`, `setMetadata(metadata)`, `getMetadata()` |
| Provider 管理 | `addDecorationProvider(provider)`, `removeDecorationProvider(provider)`, `requestDecorationRefresh()`, `addCompletionProvider(provider)`, `removeCompletionProvider(provider)`, `addNewLineActionProvider(provider)`, `removeNewLineActionProvider(provider)` |
| 补全 | `triggerCompletion()`, `showCompletionItems(items)`, `dismissCompletion()`, `setCompletionItemRenderer(renderer)` 或平台等价补全项渲染定制 API |
| 样式 | `registerTextStyle(id, ...)`, `registerBatchTextStyles(stylesById)` |
| Decoration / Adornment 写入 | `setLineSpans(line, layer, spans)`, `setBatchLineSpans(layer, spansByLine)`, `setLineInlayHints(line, hints)`, `setBatchLineInlayHints(hintsByLine)`, `setLinePhantomTexts(line, phantoms)`, `setBatchLinePhantomTexts(phantomsByLine)`, `setLineGutterIcons(line, icons)`, `setBatchLineGutterIcons(iconsByLine)`, `setLineCodeLens(line, items)`, `setBatchLineCodeLens(itemsByLine)`, `setLineLinks(line, links)`, `setBatchLineLinks(linksByLine)`, `setLineDiagnostics(line, items)`, `setBatchLineDiagnostics(diagsByLine)`, `setIndentGuides(guides)`, `setBracketGuides(guides)`, `setFlowGuides(guides)`, `setSeparatorGuides(guides)`, `setFoldRegions(regions)` |
| Decoration / Adornment 清理 | `clearHighlights()`, `clearHighlights(layer)`, `clearInlayHints()`, `clearPhantomTexts()`, `clearGutterIcons()`, `clearCodeLens()`, `clearLinks()`, `clearGuides()`, `clearDiagnostics()`, `clearAllDecorations()` |
| 查询 | `getVisibleLineRange()`, `getTotalLineCount()`, `getLinkTargetAt(line, column)`；link 未命中时返回空字符串或等价 non-null empty value |

> Provider 管理方法的标准命名为 `add` / `remove`。各平台 MAY 按自身惯例使用语义等价的变体（如 `attach` / `detach`、`register` / `unregister` 等）。

> 剪贴板方法（`copyToClipboard`, `pasteFromClipboard`, `cutToClipboard`）为 **MAY**，因为剪贴板是平台特定的。

> 事件暴露方式不要求统一方法名。平台 MUST 按第 11 节提供类型安全事件机制，可以采用 `subscribe` / `unsubscribe`、平台原生 `event` / delegate、typed `Stream` getter、signal / observer 等等效形式。

> 第 3.2 节是宿主可见的编辑器公共 API 索引。部分模块相关的接口、数据模型和回调契约会在后续章节继续补充定义（例如第 4、5、6、7、10 节）；其中第 4、5、10 节定义必需模块契约，第 6、7 节定义可选或条件模块契约。

---

## 4. Provider 接口（MUST）

Provider-Manager 模式（注册 -> 遍历 -> 分发）MUST 在所有平台保持一致。同一类型 Provider MAY 注册多个实例，Manager 负责遍历、合并和丢弃过期结果。`provideDecorations` 与 `provideCompletions` MUST 支持同步和异步结果交付；`DecorationProvider` MUST 支持同一请求的 0 次、1 次或多次 snapshot，`CompletionProvider` MUST 至少支持单次结果交付并 MAY 支持增量结果。进行中的 decoration / completion 请求 MUST 有取消或过期契约；取消或过期后的延迟结果 MUST 被忽略。

平台 MAY 使用 Receiver 回调、`Future` / `Promise` / `Task`、协程、stream / observable 或其他平台惯用形式。若不暴露 Receiver 形态，仍 MUST 文档化即时交付、延后交付、多次更新适用性，以及取消 / 过期语义。

### 4.1 DecorationProvider

`DecorationProvider` MUST 提供 `getCapabilities() -> Set<DecorationType>` 与 `provideDecorations(context, receiver/equivalent)`。若暴露显式 Receiver，推荐命名为 `DecorationReceiver`，并提供 `accept(result) -> boolean` 与 `isCancelled() -> boolean`。

| 对象 | 必须字段 / 值 |
|---|---|
| `DecorationContext` | `visibleLineRange`, `totalLineCount`, `textChanges`, `languageConfiguration`, `editorMetadata` |
| `ApplyMode` | `MERGE`, `REPLACE_ALL`, `REPLACE_RANGE`；合并优先级为 `REPLACE_ALL` > `REPLACE_RANGE` > `MERGE` |
| `DecorationResult` | `syntaxSpans`, `semanticSpans`, `inlayHints`, `diagnostics`, `indentGuides`, `bracketGuides`, `flowGuides`, `separatorGuides`, `foldRegions`, `gutterIcons`, `phantomTexts`, `codeLensItems`, `links`，且每种数据 MUST 有对应的 `ApplyMode` 字段 |
| `DecorationType` | MUST 包含 `CODELENS` 和 `LINK` |

按行索引的数据使用 `Map<int, List<T>>`，key 为 0-based 行号。Manager MUST 按 `ApplyMode` 合并 snapshot：`MERGE` 追加同类数据，`REPLACE_ALL` 清除全部已有数据后写入，`REPLACE_RANGE` 仅替换 `visibleLineRange` 内的数据。

### 4.2 CompletionProvider

`CompletionProvider` MUST 提供 `isTriggerCharacter(ch)` 与 `provideCompletions(context, receiver/equivalent)`。若暴露显式 Receiver，推荐命名为 `CompletionReceiver`，并提供 `accept(result) -> boolean` 与 `isCancelled() -> boolean`。

| 对象 | 必须字段 / 值 |
|---|---|
| `CompletionTriggerKind` | `INVOKED`, `CHARACTER`, `RETRIGGER` |
| `CompletionContext` | `triggerKind`, `triggerCharacter`, `cursorPosition`, `lineText`, `wordRange`, `languageConfiguration`, `editorMetadata` |
| `CompletionResult` | `items`, `isIncomplete` |

Manager MUST 遍历所有 Provider，将各 Provider 返回的 `CompletionItem` 合并后按 `sortKey` 排序，`sortKey` 为空时 fallback 到 `label`。

### 4.3 NewLineActionProvider

`NewLineActionProvider` MUST 提供同步 `provideNewLineAction(context) -> NewLineAction?`，因为换行处理属于即时输入路径。`NewLineContext` MUST 包含 `lineNumber`, `column`, `lineText`, `languageConfiguration`, `editorMetadata`。`NewLineAction` MUST 包含 `text`。Manager MUST 按注册顺序遍历所有 Provider，返回第一个非 null 的 `NewLineAction`；若全部返回 null，则使用默认换行行为。

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

### 6.1 数据、回调与 API

| 对象 / API | 约束级别 | 要求 |
|---|---|---|
| `InlineSuggestion` | **MUST** | 字段包含 `line`, `column`, `text`；`line` 为 0-based 行号，`column` 为 0-based UTF-16 偏移 |
| `InlineSuggestionListener` 或等价事件机制 | **MUST** | 必须能观察 `accepted` 与 `dismissed`；显式 listener 推荐提供 `onSuggestionAccepted(suggestion)` 与 `onSuggestionDismissed(suggestion)` |
| `showInlineSuggestion(suggestion)` | **MUST** | 显示内联建议，并使其可被 accept / dismiss |
| `dismissInlineSuggestion()` | **MUST** | 关闭当前内联建议并移除其可见呈现 |
| `isInlineSuggestionShowing()` | **MUST** | 查询当前是否有内联建议正在显示 |
| `setInlineSuggestionListener(listener)` | **MUST** | 注册宿主可见的 accepted / dismissed listener；传入 `null` 时清除监听。平台 MAY 使用 callbacks、delegate、事件订阅或 typed stream 表达同一语义 |

对于同一个已展示的建议实例，`accepted` 和 `dismissed` 最多各触发一次；触发其中任一事件后，该实例后续不得再触发任何回调。替换当前建议时，平台 MAY 为旧建议发出 `dismissed`，也 MAY 静默替换，但旧建议被替换后 MUST NOT 再发出回调。editor 进入终结性 teardown、内部 detach 或 controller dispose 后，不得再发出宿主可见的内联建议回调。

### 6.2 自动关闭行为

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 文本变更 | **MUST** | 用户输入文本时 MUST 自动关闭当前内联建议 |
| 光标移动 | **MUST** | 光标位置变化时 MUST 自动关闭当前内联建议 |
| 滚动 | **SHOULD** | 滚动时若平台存在可见建议控件，SHOULD 更新其位置；SHOULD NOT 自动关闭 |

---

## 7. Selection / SelectionMenu 接口定义（移动端 SHOULD，桌面端 MAY 省略）

Selection menu 模块在移动端为 SHOULD 级别。桌面平台 MAY 完全省略；如果实现，则 MUST 遵循以下契约。

### 7.1 数据、Provider 与回调

| 对象 / API | 约束级别 | 要求 |
|---|---|---|
| `SelectionMenuItem` | **MUST** | 字段包含 `id`, `label`；MAY 包含 `enabled`, `iconId`。内建动作推荐使用 `cut`, `copy`, `paste`, `select_all`，自定义动作 MAY 使用任意稳定 `id` |
| `SelectionMenuItemProvider` | **MUST** | 提供 `provideMenuItems(editor/equivalent) -> List<SelectionMenuItem>` 或等价 API；返回当前这一次展示的完整菜单项集合，而不是增量 patch |
| custom item 回调 | **MUST** | 平台 MUST 提供 listener、delegate、事件、typed stream 或等价机制观察 custom item 被触发；显式 listener 推荐提供 `onSelectionMenuItemSelected(itemId)` |
| `setSelectionMenuItemProvider(provider)` | **MUST** | 配置 custom 选区菜单项；传入 `null` 时 SHOULD 恢复平台默认菜单 |

Provider 返回空列表时平台 MAY 不显示选区菜单；Provider SHOULD 在菜单即将显示时重新调用，使菜单项随当前 editor 状态动态变化。内建 cut / copy / paste / select all 等平台动作不要求统一发出 custom item 回调。editor 进入终结性 teardown、内部 detach 或 controller dispose 后，不得再发出宿主可见的 custom selection-menu 回调。

### 7.2 定位与生命周期

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 选区锚点 | **MUST** | 菜单可见时 MUST 锚定到当前选区 / 光标几何信息，或平台等价的原生选区承载体 |
| 选区失效 | **MUST** | 若选区变为空、失效，或已与当前文档状态脱离，菜单 MUST 关闭 |
| 滚动 / 视口变化 | **SHOULD** | 滚动或视口变化时 SHOULD 更新菜单位置；除非平台无法安全重定位，否则 SHOULD NOT 强制关闭 |
| 命令完成后 | **SHOULD** | 用户触发选区菜单命令后，菜单 SHOULD 关闭；除非平台有意支持多步操作流保持开启 |

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

所有颜色字段类型为平台颜色类型（ARGB）。平台 MUST 提供下列字段：

| 分组 | 字段 |
|---|---|
| 基础颜色 | `backgroundColor`, `textColor`, `cursorColor`, `selectionColor` |
| 行号与当前行 | `lineNumberColor`, `currentLineNumberColor`, `currentLineColor` |
| 辅助线 | `guideColor`, `separatorLineColor`, `splitLineColor` |
| 滚动条 | `scrollbarTrackColor`, `scrollbarThumbColor`, `scrollbarThumbActiveColor` |
| 输入法 | `compositionUnderlineColor` |
| InlayHint | `inlayHintBgColor`, `inlayHintTextColor`, `inlayHintIconColor` |
| 折叠占位符 | `foldPlaceholderBgColor`, `foldPlaceholderTextColor` |
| PhantomText | `phantomTextColor` |
| CodeLens | `codeLensColor`, `codeLensActiveColor` |
| Link | `linkColor`, `linkActiveColor` |
| 诊断装饰 | `diagnosticErrorColor`, `diagnosticWarningColor`, `diagnosticInfoColor`, `diagnosticHintColor` |
| 联动编辑 | `linkedEditingActiveColor`, `linkedEditingInactiveColor` |
| 括号匹配 | `bracketHighlightBorderColor`, `bracketHighlightBgColor` |
| 补全弹窗 | `completionBgColor`, `completionBorderColor`, `completionSelectedBgColor`, `completionLabelColor`, `completionDetailColor` |

### 8.3 工厂方法

每个平台 MUST 至少提供 `dark()` 和 `light()` 工厂方法，返回预配置的主题；内建主题 MUST 为 8.2 中全部必需颜色字段显式赋值，包括 `codeLensColor`、`codeLensActiveColor`、`linkColor`、`linkActiveColor`。

### 8.4 TextStyle 映射

每个 `EditorTheme` MUST 包含 `textStyles` 映射（`Map<int, TextStyle>`）和 `defineTextStyle(styleId, style)` 方法。

---

## 9. EditorSettings（MUST）

编辑器选项以及行为/布局类配置 MUST 通过 `EditorSettings` 对象统一收拢管理。这里指的是 wrap mode、scale、spacing、padding 等 settings-like editor options。`EditorTheme` 与 `EditorKeyMap` 仍然是独立的宿主配置对象，不受本条“并入 `EditorSettings`”约束。宿主可见 API 载体 MUST NOT 直接暴露 settings-like 配置 setter（如 `setWrapMode`、`setScale` 等），而是通过 `getSettings()` 暴露配置对象，并在该对象可用后由调用方进行配置。命令式平台上，该宿主 API 载体是 `SweetEditor`；声明式平台上则是 `SweetEditorController`。在声明式平台上，`getSettings()` 只有在 `whenReady()` 或其他等价 ready 信号之后才有效。在此之前，它 SHOULD 返回 `null` 或默认的不可用值，MUST NOT 为此创建隐藏运行时或隐藏暂存对象，也 MUST NOT 被视为 pre-ready 配置通道。若首个 attach 前就必须确定初始 settings，MUST 通过声明式构造参数或等价的平台原生初始化路径提供。这个宿主接口规则不改变第 3.1 节定义的 `EditorCore` Public API。

所有平台 MUST 通过 getter/setter 对（或属性）暴露以下设置：

| 字段 | 类型 | 默认值 | setter | getter | 典型影响 | 说明 |
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

> 所有 setter 调用后 MUST 立即生效，并将 core 返回的 `EditorActionResult` 交给统一结果分发入口处理。
>
> 典型影响仅用于说明宿主可预期的语义，不是平台判断 flush、repaint 或 relayout 的依据。是否重建 render model、刷新 IME 状态、触发动画或重绘，MUST 由 `EditorActionResult` 的 `needsRedraw`、`needsImeSync`、`needsAnimation` 等字段决定。
>
> 典型影响说明：
> - `repaint`：通常只影响视觉刷新，不要求文本重新布局。
> - `relayout`：通常影响布局或 render model。
> - `runtime-transition`：立即影响后续编辑行为，并安全处理该设置要求的运行态切换。
> - `provider-policy`：立即影响后续 provider 的调度 / 刷新策略。
>
> `autoIndentMode`、`backspaceUnindent` 和 `readOnly` 也属于 `runtime-transition` 设置。它们必须立即影响后续编辑行为；若 setter 调用当下没有可见状态变化，core 返回的 `EditorActionResult` 不应要求平台刷新可见状态。
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
- `EditorEventBus` + `subscribe` / `unsubscribe` / `clear`
- 平台原生事件 / 委托 / 监听器机制（如 C# `event`、Java listener callback）
- 类型化 stream / signal / observable getter（如 Dart `Stream<T>`）

若平台采用显式事件总线 / 监听器模式，相关公共类型 SHOULD 命名为 `EditorEventBus` / `EditorEventListener`。

宿主可见的事件表面是 observer surface。平台 MAY 在内部保留 `publish` / `emit` 或等价方法，但状态类事件（如文本、光标、选区、滚动、缩放）MUST 由统一 `EditorActionResult` 分发入口发布，宿主 API 不应暴露可任意发布编辑器状态事件的入口。

### 11.2 必需事件类型

所有平台 MUST 支持以下事件类型：

```
TextChangedEvent, CursorChangedEvent, SelectionChangedEvent,
ScrollChangedEvent, ScaleChangedEvent, DocumentLoadedEvent,
FoldToggleEvent, GutterIconClickEvent, InlayHintClickEvent, CodeLensClickEvent, LinkClickEvent,
LongPressEvent,       // 仅移动端 / 触摸平台（包括 iOS、Android、OHOS）
DoubleTapEvent,
ContextMenuEvent      // 具有显式上下文菜单手势入口的平台
```

> `LongPressEvent` 用于移动端 / 触摸平台（包括 iOS、Android、OHOS），表示原始长按手势本身。`ContextMenuEvent` 用于暴露显式的上下文菜单手势入口（例如桌面右键或框架原生 context-menu gesture）。平台实现 SHOULD 仅注册与自身平台相关的事件。

> 上述事件类型 MUST 能通过平台选择的事件机制被类型安全地区分和消费。

平台特定事件（如移动端的 `SelectionMenuItemClickEvent`）MAY 额外添加。

`DocumentLoadedEvent` 是文档生命周期事件，不要求从 `EditorActionResult` 字段直接推导；平台 MAY 在 `loadDocument(...)` 生命周期路径中发布它。但 `loadDocument(...)` 返回的非空 `EditorActionResult` 仍 MUST 交给统一分发入口，不能用 `DocumentLoadedEvent` 替代 result 分发。

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

### 11.4 `EditorActionResult` 手势字段契约

平台 MAY 直接暴露 `handleGestureEvent(...)` / `handleGestureEventEx(...)` 的返回值，也 MAY 仅在内部消费；但手势处理的返回值 MUST 是 `EditorActionResult` 或平台等价类型。下列手势相关字段 MUST 保持与 Core 一致的语义，并通过统一结果分发入口消费：

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `gestureType` | `GestureType` | **MUST** | 当前 core 识别出的手势语义；为 `UNDEFINED` 时表示本次 action 不是手势处理产生的语义动作 |
| `gestureEventType` | `EventType` | **MUST** | 产生该手势语义动作的原始事件类型 |
| `tapPoint` | `PointF` | **MUST** | 手势命中的 editor 本地坐标 |
| `hitTarget` | `HitTargetType` + 与平台对齐的 payload | **MUST** | 当前手势位置的命中测试结果 |
| `pointerCursorAfter` / `pointerCursorChanged` | `PointerCursorType` / boolean | 桌面端或具备 mouse / hover 输入的平台 **MUST**，纯触摸平台 **MAY** | 当前鼠标位置对应的指针样式提示，以及是否需要更新平台鼠标形状 |
| `needsEdgeScroll` / `needsFling` / `needsAnimation` | boolean | **MUST** | 平台是否需要继续边缘滚动、惯性滚动或统一动画 tick |
| `isHandleDrag` | boolean | 移动端 **SHOULD** | 当前手势是否为选择手柄拖拽 |

> 这些字段 MUST 按自身语义独立消费，不能依赖 `needsRedraw` 顺带生效。桌面或具备 mouse / hover 输入的平台 SHOULD 在 `pointerCursorChanged` 为 true 时立即应用 `pointerCursorAfter`，即使本次 result 不需要重绘；平台也 MUST 根据 `needsAnimation` 启动或停止 animation tick，不能等待下一次 render model rebuild。纯触摸且没有鼠标指针概念的平台 MAY 完全忽略鼠标形状变化。

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
| `perf/`（性能浮层） | MAY | MAY |

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

| 类型 | MUST 字段 | 特殊语义 |
|---|---|---|
| `IntRange` | `start`, `end` | 闭区间；`end < start` 表示空范围 |
| `TextChange` | `range`, `newText` | `range` 为文档坐标，`newText` 为空字符串表示纯删除 |

### 17.3 Adornment 数据类型

| 类型 | MUST 字段 | 特殊语义 |
|---|---|---|
| `StyleSpan` | `column`, `length`, `styleId` | `styleId` 来自 `registerTextStyle()` |
| `TextStyle` | `color`, `backgroundColor`, `fontStyle` | 颜色为 ARGB；`fontStyle` 位标志为 `BOLD=1`, `ITALIC=2`, `STRIKETHROUGH=4` |
| `InlayHint` | `type`, `column`, `text`, `intValue` | `type` 为 `TEXT=0`, `ICON=1`, `COLOR=2`；TEXT 类型时 `text` MUST 非空，其他类型 MAY 为 null |
| `PhantomText` | `column`, `text` | 幽灵文本内容 |
| `CodeLensItem` | `column`, `text`, `commandId` | 同一逻辑行上的多个 CodeLens MUST 按 `column` 升序排列；`commandId` 回传到 `CodeLensClickEvent` |
| `LinkSpan` | `column`, `length`, `target` | `target` 由 `getLinkTargetAt()` 和 `LinkClickEvent` 返回 |
| `GutterIcon` | `iconId` | 图标资源由平台侧 `EditorIconProvider` 解析和绘制 |
| `Diagnostic` | `column`, `length`, `severity` | `severity` 为 `ERROR=0`, `WARNING=1`, `INFO=2`, `HINT=3`；这是最小诊断装饰模型，不等同于完整 IDE 诊断对象 |
| `FoldRegion` | `startLine`, `endLine` | `startLine` 保持可见，`endLine` 为 inclusive |
| `IndentGuide` | `start`, `end` | 缩进引导线端点 |
| `BracketGuide` | `parent`, `end`, `children` | 括号配对引导线结构 |
| `FlowGuide` | `start`, `end` | 控制流引导线端点 |
| `SeparatorGuide` | `line`, `style`, `count`, `textEndColumn` | `textEndColumn` 用于确定分隔线起始绘制位置 |

### 17.4 Visual 渲染类型

| 类型 | MUST 字段 | 特殊语义 |
|---|---|---|
| `EditorRenderModel` | `pointerCursorType` | 桌面端或具备 mouse / hover 输入的平台 MUST，纯触摸平台 MAY；应与 `EditorActionResult.pointerCursorAfter` 保持语义一致 |
| `VisualRun` | `type`, `iconId`, `active` | `iconId` 对 `INLAY_HINT(ICON)` 表示图标资源 id，对 `CODELENS` 表示唯一 `commandId`；`active` 用于可点击 run 的 hover / pressed 渲染 |
| `VisualLine` | `kind`, `ownsGutterSemantics` | `CODELENS` 表示虚拟 visual line；同一逻辑行对应的第一条真实内容行 MUST 通过 `ownsGutterSemantics` 标识，而不是根据 `wrapIndex` 推断 |

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

本节定义平台实现必须守住的性能不变量。具体数值是优化目标，不作为合规判定。

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 视口范围渲染 | **MUST** | 平台侧 layout 和 paint MUST 限于可见区域（必要时可带少量前瞻 buffer）；普通滚动 MUST NOT 依赖整篇文档重排或重绘 |
| Provider 非阻塞 | **MUST** | 慢速 decoration / completion provider MUST NOT 阻塞宿主可见交互路径上的输入、滚动或绘制 |
| 过期异步结果 | **MUST** | 过期的异步 provider 结果 MUST 在修改可见编辑器状态前被取消或丢弃 |
| Core / 布局重复计算 | **MUST** | 平台热路径 MUST NOT 冗余重算 Core 已经产出且可直接消费的几何或布局信息 |
| 性能诊断 | **SHOULD** | 平台 SHOULD 保留足够的计时钩子，以支持 debug-only 性能诊断 |
| 大文档策略 | **SHOULD** | 大文档加载 SHOULD 使用 memory mapping、streaming load 或等效策略；滚动 MUST 依赖视口渲染 |
| Provider 超时 | **SHOULD** | Decoration 请求超过 5 秒、completion 请求超过 3 秒未交付时，Manager SHOULD 取消或标记过期 |
| NewLine 延迟 | **MUST / SHOULD** | `provideNewLineAction()` MUST 保持同步且不得引入用户可感知的 Enter 延迟 |
| PerfOverlay | **MAY / MUST** | 若提供 `PerfOverlay`，MUST 默认关闭且仅用于调试；其字段名、阈值和 step 名称 MUST NOT 视为稳定 API 契约 |

---
## 21. 测试规范（SHOULD）

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 回归测试 | **MUST** | 每个核心模块（Document、Layout、Decoration、EditorCore）MUST 有对应的回归测试 |
| 平台 API 测试 | **SHOULD** | 各平台 SHOULD 验证宿主 API、settings/theme 默认值、provider 注册与释放、事件订阅与释放 |
| 结果分发测试 | **SHOULD** | 各平台 SHOULD 覆盖 `EditorActionResult` 分发、IME 同步、文本 / 光标 / 选区 / 滚动事件、动画 tick、指针样式更新 |
| 异步 stale 测试 | **SHOULD** | decoration / completion 的过期异步结果 SHOULD 被取消或丢弃 |
| 生命周期测试 | **SHOULD** | teardown 后不应再触达无效 native 状态，也不应再发出宿主可见回调 |

---

## 22. 无障碍规范（MAY）

无障碍（Accessibility）支持为 MAY 级别；实现时 SHOULD 遵循以下最小指导。

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 角色标注 | **SHOULD** | 编辑器控件 SHOULD 标注为文本编辑器或平台等价角色 |
| 文本内容 | **SHOULD** | SHOULD 向无障碍服务暴露当前可见文本内容 |
| 光标位置 | **SHOULD** | SHOULD 向无障碍服务暴露当前光标位置和选区范围 |
| 行号信息 | **MAY** | MAY 向无障碍服务暴露当前行号和总行数 |
| 焦点管理 | **SHOULD** | 编辑器控件 SHOULD 能通过 Tab 键获取和释放焦点 |
| 键盘快捷键 | **SHOULD** | 桌面平台 SHOULD 支持标准键盘快捷键（Ctrl/Cmd+C/V/X/Z/A 等） |
| 高对比度 | **MAY** | MAY 提供高对比度主题或响应系统高对比度设置 |
| 字体缩放 | **SHOULD** | SHOULD 响应系统字体缩放设置（通过 `setScale()` 或 `setEditorTextSize()`） |
| 光标可见性 | **SHOULD** | 光标 SHOULD 有足够的视觉对比度 |

---

## 23. 版本管理

本标准适用于 2026-05 起的 SweetEditor 平台实现。当 C++ 核心新增枚举、事件或 API 方法时，所有平台 MUST 在同一发布周期内同步更新。

### 23.1 平台包版本号规范

平台层发布包的版本号 MUST 与 C++ Core 版本号保持对齐关系。版本号格式为 `a.b.c`（主版本.次版本.修订号）。

| 版本段 | 约束级别 | 规则 |
|---|---|---|
| `a`（主版本） | **MUST** | 平台包主版本号 MUST 与 Core 主版本号一致，不得超过 |
| `b`（次版本） | **SHOULD** | 平台包次版本号 SHOULD 不超过 Core 次版本号 `+9`；超出需书面说明理由 |
| `c`（修订号） | **MAY** | 平台包修订号可自由递增，用于平台特定 bugfix 或补丁 |

- 当 Core 发布新的主版本（如 `2.0.0`）时，所有平台包 MUST 在同一发布周期内升级主版本号。
- 平台包 MAY 在 Core 版本不变的情况下独立发布修订版本（`c` 段递增），用于修复平台特定问题。
- 次版本号（`b` 段）的建议上限是为了避免平台包版本号与 Core 版本号差距过大，造成版本对应关系混乱。
