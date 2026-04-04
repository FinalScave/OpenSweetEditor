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
| **Foundation** | `TextPosition`, `TextRange`, `TextChange`, `WrapMode`, `FoldArrowMode`, `AutoIndentMode`, `CurrentLineRenderMode`, `ScrollBehavior` | 基础值类型与枚举 |
| **Adornment** | `StyleSpan`, `SpanLayer`, `InlayHint`, `InlayType`, `PhantomText`, `FoldRegion`, `GutterIcon`, `Diagnostic`, `IndentGuide`, `BracketGuide`, `FlowGuide`, `SeparatorGuide`, `SeparatorStyle`, `TextStyle` | 装饰数据类型 |
| **Visual** | `EditorRenderModel`, `VisualLine`, `VisualRun`, `VisualRunType`, `Cursor`, `CursorRect`, `SelectionRect`, `SelectionHandle`, `ScrollMetrics`, `ScrollbarModel`, `ScrollbarRect`, `GuideSegment`, `GuideType`, `GuideDirection`, `GuideStyle`, `DiagnosticDecoration`, `CompositionDecoration`, `FoldMarkerRenderItem`, `FoldState`, `GutterIconRenderItem`, `LinkedEditingRect`, `BracketHighlightRect` | 渲染模型类型（几何语义见第 2.4 节） |
| **Snippet** | `LinkedEditingModel`, `TabStopGroup` | 联动编辑 / Tab stop 分组 |
| **Keymap** | `KeyMap`, `KeyBinding`, `KeyChord`, `KeyCode`, `KeyModifier`, `EditorCommand` | 快捷键映射数据类型与命令标识 |

### 1.2 Widget 层（UI 控件 / 渲染 / 交互）

Widget 层负责平台原生渲染、用户交互和扩展系统。

| 逻辑分类 | 必须包含的类型 | 说明 |
|---|---|---|
| **Widget** | `SweetEditor`, `SweetEditorController`*(声明式框架 MUST；命令式框架 MAY)*, `EditorTheme`, `EditorSettings`, `EditorIconProvider`, `EditorMetadata`, `LanguageConfiguration` | 控件入口、控制器、主题、配置 |
| **Decoration** | `DecorationProvider`, `DecorationProviderManager`, `DecorationContext`, `DecorationResult`, `DecorationType`；若采用 Receiver 回调模式，推荐使用 `DecorationReceiver` | 装饰提供者系统 |
| **Completion** | `CompletionProvider`, `CompletionProviderManager`, `CompletionContext`, `CompletionItem`, `CompletionResult`；若采用 Receiver 回调模式，推荐使用 `CompletionReceiver` | 补全提供者系统 |
| **Event** | 类型安全事件机制、`EditorEvent`、`TextChangedEvent`、`CursorChangedEvent`、`SelectionChangedEvent`、`ScrollChangedEvent`、`ScaleChangedEvent`、`DocumentLoadedEvent`、`FoldToggleEvent`、`GutterIconClickEvent`、`InlayHintClickEvent`、`LongPressEvent`*(仅移动端)*、`DoubleTapEvent`、`ContextMenuEvent`*(桌面端及跨平台 UI 框架)*；若采用显式事件总线 / 监听器模式，推荐 `EditorEventBus`、`EditorEventListener` | 事件系统 |
| **NewLine** | `NewLineActionProvider`, `NewLineActionProviderManager`, `NewLineAction`, `NewLineContext` | 换行动作提供者系统 |
| **Keymap** | `EditorKeyMap` | Widget 层 keymap 扩展，用于将 commandId 绑定到宿主侧处理器 |
| **Copilot** *(SHOULD)* | `InlineSuggestion`、`InlineSuggestionListener` 或等价的 accept/dismiss 回调机制；MAY: `InlineSuggestionController` | 内联建议数据 + 回调；主路径为 listener 形态 |
| **Selection** *(MAY, 仅移动端)* | `SelectionMenuController`、`SelectionMenuItem`、`SelectionMenuItemProvider`、宿主可见的 custom item 点击回调机制；MAY: `SelectionMenuListener` | 选区菜单（桌面端 MAY 省略） |
| **Perf** *(SHOULD)* | `PerfOverlay`, `MeasurePerfStats`, `PerfStepRecorder` | 性能浮层 |

> TextChangeAction 为 SHOULD 级辅助事件枚举。平台 MAY 暴露它用于粗粒度标识一次文本变更周期（如 INSERT / DELETE / UNDO / REDO / KEY / COMPOSITION），但 MUST NOT 用它替代 changes: List<TextChange> 这一主增量载荷。

### 1.3 推荐内部实现模式（SHOULD）

以下类型属于**内部实现细节**，不属于公共 API 契约。各平台 SHOULD 采用这些模式来组织内部逻辑，但 MAY 根据平台特性选择其他等效方式（如直接在控件类中实现、使用平台原生 Popup 等）。

| 模式 | 推荐类型 | 适用场景 | 好处 |
|---|---|---|---|
| **Renderer** | `EditorRenderer` | 将渲染逻辑从控件入口类中分离 | 职责单一，渲染逻辑可独立迭代和测试 |
| **Controller** | `CompletionPopupController`, `InlineSuggestionController`, `SelectionMenuController` | 管理弹窗 / 浮层的生命周期和交互逻辑 | 解耦 UI 弹窗与数据逻辑，平台可选择直接用 Popup 实现 |

> 如果采用上述模式，命名 SHOULD 遵循第 2.1 节的规范名称。
> 不采用这些模式不视为违规，但需确保等效功能已在其他类中实现。

---

## 2. 命名约定

### 2.1 类 / 类型名（MUST）

所有平台 MUST 对公共类型使用以下规范名称。仅在语言惯例强制要求时允许使用语言特定的前缀或后缀（如 C# 接口的 `I` 前缀）。

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
| `TextMeasurer` | OC: `SETextMeasurer` | C# 中可为 struct |
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
| `SelectionMenuItemProvider` | C#/TS/Kotlin: `ISelectionMenuItemProvider`; OC: `SESelectionMenuItemProvider` | 选区菜单项提供者；用于按当前 editor 状态构建整套菜单 |
| `SelectionMenuListener` | C#/TS/Kotlin: `ISelectionMenuListener`; OC: `SESelectionMenuListener` | 监听器接口；仅适用于平台选择暴露显式选区菜单 listener 时 |
| `EditorIconProvider` | C#/TS/Kotlin: `IEditorIconProvider`; OC: `SEEditorIconProvider` | 图标提供者接口 |
| `SweetEditorController` | OC: `SESweetEditorController` | 声明式框架的外部控制入口（见 3.0 节） |

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

### 2.4 几何载体类型（MUST）

对于公共 API 和事件 payload 中使用的简单几何载体，平台 MAY 使用 SweetEditor 规范几何类型，或使用语义完全一致的平台原生等价类型。

- 点类型：`PointF` 或平台原生点类型（如 Android `android.graphics.PointF`、Apple `CGPoint`）
- 矩形类型：`RectF` 或平台原生矩形类型（如 Android `android.graphics.RectF`、Apple `CGRect`）

若使用平台原生几何类型，坐标基准、轴方向和字段语义 MUST 与 SweetEditor 规范模型保持一致。

---

## 3. Public API 契约（MUST）

以下列出 `EditorCore` 和 `SweetEditor` 两个层级 MUST 暴露的公共方法。各平台 MUST 实现所有列出的方法。

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

- MUST 提供 `SweetEditorController` 类，作为外部控制编辑器的唯一命令式入口
- `SweetEditorController` MUST 暴露第 3.2 节定义的全部 API，以及后续章节中针对已实现可选模块定义的模块级公共 API
- 控件入口类（如 `SweetEditorWidget`、`SweetEditorView`）MUST 接受 `SweetEditorController` 作为构造参数
- 控件内部 MUST 在挂载时将自身绑定到 Controller，在卸载时解绑

```dart
// Flutter
final controller = SweetEditorController();
SweetEditorWidget(controller: controller);
controller.loadDocument(doc);
controller.applyTheme(EditorTheme.dark());
```

#### 3.0.3 `SweetEditorController` 规范

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 生命周期回调 | **MUST** | 提供 `whenReady(callback)` 方法，在控件挂载完成后回调；若调用时已就绪则立即执行 |
| 未挂载时的调用行为 | **SHOULD** | 控件未挂载时调用 Controller 方法，SHOULD 将操作排队，待挂载后依次执行；MAY 选择静默忽略（no-op） |
| 绑定 / 解绑 | **MUST** | 提供内部 `bind(editorApi)` / `unbind()` 机制（命名 MAY 因平台而异），控件挂载时调用 `bind`，卸载时调用 `unbind` |
| 多次绑定 | **MUST** | 同一 Controller 实例在前一个控件解绑后 MAY 绑定到新控件；MUST NOT 同时绑定多个控件 |
| API 一致性 | **MUST** | Controller 上暴露的方法签名 MUST 与第 3.2 节的 Public API 表以及后续章节中已实现模块的公共 API 表一致（方法名、参数、返回值） |
| getter 方法 | **SHOULD** | 控件未挂载时，getter 方法（如 `getDocument()`、`getCursorPosition()`）SHOULD 返回 null 或默认值，MUST NOT 抛出异常 |
| 资源释放 | **MUST** | 提供 `dispose()` 方法（命名 MAY 因平台而异，如 `close()`、`release()`），释放内部资源并解绑控件 |

#### 3.0.4 平台分类参考

| UI 范式 | 框架 | API 载体 |
|---|---|---|
| 命令式 | Android View, UIKit, AppKit, Swing, WinForms | 控件入口类直接暴露 |
| 声明式 | Flutter, Jetpack Compose, SwiftUI, ArkUI, React, Vue | `SweetEditorController` |
| 混合 | React Native, Qt (QML + C++) | 按主要 UI 层范式决定 |

> 如果一个平台同时提供命令式和声明式两种 API（如 Apple 同时有 UIKit 和 SwiftUI），则命令式 API 在控件类上暴露，声明式封装 MUST 额外提供 Controller。

---

### 3.1 `EditorCore` Public API

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
| 开始组合 | `compositionStart()` | — |
| 更新组合 | `compositionUpdate(text)` | — |
| 结束组合 | `compositionEnd(committed)` | — |
| 取消组合 | `compositionCancel()` | — |
| 是否组合中 | `isComposing()` | property: `isComposing` / `IsComposing { get; }` |
| 启用/禁用组合 | `setCompositionEnabled(enabled)` | — |
| 组合是否启用 | `isCompositionEnabled()` | property: `isCompositionEnabled` / `IsCompositionEnabled { get; }` |
| **只读 / 缩进** | | |
| 设置只读 | `setReadOnly(readOnly)` | — |
| 是否只读 | `isReadOnly()` | property: `isReadOnly` / `IsReadOnly { get; }` |
| 设置自动缩进 | `setAutoIndentMode(mode)` | — |
| 获取自动缩进 | `getAutoIndentMode()` | property: `autoIndentMode` / `AutoIndentMode { get; }` |
| 设置退格反缩进 | `setBackspaceUnindent(enabled)` | — |
| 是否退格反缩进 | `isBackspaceUnindent()` | property: `backspaceUnindent` / `IsBackspaceUnindent { get; }` |
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

> payload 类 API（如 `setLineSpans`、`setBatchLineSpans`）各平台 MUST 提供高层 typed 封装（如 `setLineSpans(line, layer, spans: List<StyleSpan>)`）。当宿主语言存在自然的公开二进制载体（如 `ByteBuffer`、`NSData`、`byte[]`、`Uint8List`）时，平台 SHOULD 额外公开 raw/binary payload API。若 typed API 与 payload API 同时存在，两者的参数语义与最终 Core 行为 MUST 完全一致。payload 的编码格式由平台自行定义。

### 3.2 `SweetEditor` Public API

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
| 清除 guides | `clearGuides()` | — |
| 清除 diagnostics | `clearDiagnostics()` | — |
| 清除所有装饰 | `clearAllDecorations()` | — |
| **刷新** | | |
| 刷新 | `flush()` | — |
| **查询** | | |
| 可见行范围 | `getVisibleLineRange()` | property: `visibleLineRange` / `VisibleLineRange { get; }` |
| 总行数 | `getTotalLineCount()` | property: `totalLineCount` / `TotalLineCount { get; }` |

> Provider 管理方法的标准命名为 `add` / `remove`。各平台 MAY 按自身惯例使用语义等价的变体（如 `attach` / `detach`、`register` / `unregister` 等）。

> 剪贴板方法（`copyToClipboard`, `pasteFromClipboard`, `cutToClipboard`）为 **MAY**，因为剪贴板是平台特定的。

> 事件暴露方式不要求统一方法名。平台 MUST 按第 11 节提供类型安全事件机制，可以采用 `subscribe` / `unsubscribe`、平台原生 `event` / delegate、typed `Stream` getter、signal / observer 等等效形式。

> 第 3.2 节是控件入口层的公共 API 索引。部分模块相关的接口、数据模型和回调契约会在后续章节继续补充定义（例如第 4、5、6、7、10 节）；其中第 4、5、10 节定义必需模块契约，第 6、7 节定义可选或条件模块契约。

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
| `visibleStartLine` | int | 当前可见区域起始行（0-based） |
| `visibleEndLine` | int | 当前可见区域结束行（0-based） |
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
| `REPLACE_RANGE` | 仅替换可见范围内的数据 |

当多个 Provider 返回不同的 ApplyMode 时，Manager MUST 按优先级取最高：`REPLACE_ALL` > `REPLACE_RANGE` > `MERGE`。

#### DecorationResult MUST 字段

`DecorationResult` 包含 11 种装饰数据，每种数据都有对应的 `ApplyMode`（默认 `MERGE`）。数据类型 MUST 使用 Core 层定义的标准类型（如 `StyleSpan`、`InlayHint`、`Diagnostic` 等）。

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

> 按行索引的数据（syntaxSpans、semanticSpans 等）使用 `Map<int, List<T>>`，key 为行号（0-based）。

#### 多 Provider 合并策略

Manager 遍历所有已注册的 Provider，按 ApplyMode 合并各 Provider 的 snapshot：
- `MERGE`：将各 Provider 的同类型数据追加合并
- `REPLACE_ALL`：先清除全部已有数据，再写入新数据
- `REPLACE_RANGE`：仅清除可见范围内的已有数据，再写入新数据

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
- 在 widget 销毁、unbind 或 controller dispose 之后，不得再发出任何宿主可见的内联建议回调

| 回调 | 约束级别 | 触发时机 |
|---|---|---|
| `onSuggestionAccepted` | **MUST** | 用户接受当前可见建议时 |
| `onSuggestionDismissed` | **MUST** | 用户关闭当前可见建议时 |

### 6.3 `SweetEditor` Copilot API

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

## 7. Selection / SelectionMenu 接口定义（MAY，仅移动端）

Selection menu 模块整体为 MAY 级别。桌面平台 MAY 完全省略；如果实现，则 MUST 遵循以下契约。

### 7.1 `SelectionMenuItem` 数据类型

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `id` | String | **MUST** | 稳定的动作标识符，供宿主区分菜单项 |
| `label` | String | **MUST** | 菜单中显示的文本 |
| `enabled` | boolean | **MAY** | 菜单项当前是否可点击；省略时默认可用 |
| `iconId` | int? | **MAY** | 若平台支持选区菜单图标，可提供可选图标资源 ID |

> `SelectionMenuItem` 是统一的菜单项数据模型。平台若提供标准动作，推荐保留内建 `id`：`cut`、`copy`、`paste`、`select_all`；自定义动作 MAY 使用任意稳定 `id`。

### 7.2 `SelectionMenuItemProvider`

若平台允许宿主自定义选区菜单项，推荐形态为：

```
interface SelectionMenuItemProvider {
    provideMenuItems(editor: SweetEditor) -> List<SelectionMenuItem>
}
```

该能力 SHOULD 满足以下语义：
- Provider 返回当前这一次展示应显示的整套菜单项，而不是增量追加项
- 当 provider 为 `null` 时，平台 SHOULD 恢复默认选区菜单
- 当 provider 返回空列表时，平台 MAY 不显示选区菜单
- Provider SHOULD 在菜单即将显示时重新调用，使菜单项可以随编辑器状态动态变化

### 7.3 Selection Menu 回调契约

若平台暴露 `SelectionMenuItemProvider` 或其他 custom item 注入能力，平台 MUST 提供宿主可见的方式来观察 custom 选区菜单项被触发。平台 MAY 采用显式 listener 接口、delegate / closure / callback setter，或平台原生事件 / typed stream / signal。

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
- 在 widget 销毁、unbind 或 controller dispose 之后，不得再发出任何宿主可见的 custom selection-menu 回调

### 7.4 `SweetEditor` Selection API

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

每个平台 MUST 至少提供 `dark()` 和 `light()` 工厂方法，返回预配置的主题。

### 8.4 TextStyle 映射

每个 `EditorTheme` MUST 包含 `textStyles` 映射（`Map<int, TextStyle>`）和 `defineTextStyle(styleId, style)` 方法。

---

## 9. EditorSettings（MUST）

所有编辑器外观和行为配置 MUST 通过 `EditorSettings` 对象统一收拢管理。`SweetEditor` 本身 MUST NOT 直接暴露任何配置 setter（如 `setWrapMode`、`setScale`、`setCompositionEnabled` 等），而是通过 `getSettings()` 返回 `EditorSettings` 实例，由调用方在该实例上进行配置。这个 widget 层规则不改变第 3.1 节定义的 `EditorCore` Public API。

所有平台 MUST 通过 getter/setter 对（或属性）暴露以下设置：

| 字段 | 类型 | 默认值 | setter | getter | 副作用 | 说明 |
|---|---|---|---|---|---|---|
| `editorTextSize` | float | 平台相关 | `setEditorTextSize(size)` | `getEditorTextSize()` | `relayout` | 编辑器文本字号 |
| `typeface` / `fontFamily` | 平台字体类型 | `monospace` | `setTypeface(typeface)` / `setFontFamily(family)` | `getTypeface()` / `getFontFamily()` | `relayout` | 字体 |
| `scale` | float | 1.0 | `setScale(scale)` | `getScale()` | `relayout` | 缩放比例 |
| `foldArrowMode` | FoldArrowMode | ALWAYS | `setFoldArrowMode(mode)` | `getFoldArrowMode()` | `repaint` | 折叠箭头显示模式 |
| `wrapMode` | WrapMode | NONE | `setWrapMode(mode)` | `getWrapMode()` | `relayout` | 自动换行模式 |
| `compositionEnabled` | boolean | 平台相关 | `setCompositionEnabled(enabled)` | `isCompositionEnabled()` | `runtime-transition` | 是否启用 IME 组合输入模式 |
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
> `compositionEnabled` 是 `runtime-transition` 的典型例子：当设置从启用切换为禁用且当前存在活动 IME composition 时，平台 MUST 在新设置生效前先取消或安全终止当前 composition。
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
FoldToggleEvent, GutterIconClickEvent, InlayHintClickEvent,
LongPressEvent,       // 仅移动端（iOS/Android）
DoubleTapEvent,
ContextMenuEvent      // 桌面端（macOS/Windows/Linux）及跨平台 UI 框架
```

> `LongPressEvent` 用于移动端（iOS/Android），`ContextMenuEvent` 用于桌面端（macOS/Windows/Linux）及跨平台 UI 框架。平台实现 SHOULD 仅注册与自身平台相关的事件。

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
| `FoldToggleEvent` | `line: int`, `isGutter: boolean`, `screenPoint: PointF 或平台原生点类型` | 被切换的折叠行、是否来自 gutter 点击，以及屏幕坐标 |
| `GutterIconClickEvent` | `line: int`, `iconId: int`, `screenPoint: PointF 或平台原生点类型` | 被点击的 gutter icon 所在行、icon id，以及屏幕坐标 |
| `InlayHintClickEvent` | `line: int`, `column: int`, `type: InlayType`, `intValue: int`, `screenPoint: PointF 或平台原生点类型` | 被点击的 inlay 位置、inlay 类型、类型相关值，以及屏幕坐标 |
| `LongPressEvent` | `cursorPosition: TextPosition`, `screenPoint: PointF 或平台原生点类型` | 长按命中的位置与屏幕坐标 |
| `DoubleTapEvent` | `cursorPosition: TextPosition`, `hasSelection: boolean`, `selection: TextRange?`, `screenPoint: PointF 或平台原生点类型` | 双击命中的位置、结果选区状态，以及屏幕坐标 |
| `ContextMenuEvent` | `cursorPosition: TextPosition`, `screenPoint: PointF 或平台原生点类型` | 上下文菜单命中的位置与屏幕坐标 |
| `SelectionMenuItemClickEvent` *(平台特定)* | `item: SelectionMenuItem` | 被点击的自定义选择菜单项 |

---

## 12. 枚举与常量值（MUST）

枚举值和类枚举常量值 MUST 与 C++ 核心定义匹配。以下分组 MUST 在所有平台具有相同的成员与数值：

| 枚举 | 值 |
|---|---|
| `WrapMode` | NONE=0, CHAR_BREAK=1, WORD_BREAK=2 |
| `FoldArrowMode` | AUTO=0, ALWAYS=1, HIDDEN=2 |
| `AutoIndentMode` | NONE=0, KEEP_INDENT=1 |
| `CurrentLineRenderMode` | BACKGROUND=0, BORDER=1, NONE=2 |
| `ScrollBehavior` | TOP=0, CENTER=1, BOTTOM=2 |
| `SpanLayer` | SYNTAX=0, SEMANTIC=1 |
| `InlayType` | TEXT=0, ICON=1, COLOR=2 |
| `VisualRunType` | TEXT=0, WHITESPACE=1, NEWLINE=2, INLAY_HINT=3, PHANTOM_TEXT=4, FOLD_PLACEHOLDER=5, TAB=6 |
| `FoldState` | NONE=0, EXPANDED=1, COLLAPSED=2 |
| `DecorationType` | SYNTAX_HIGHLIGHT, SEMANTIC_HIGHLIGHT, INLAY_HINT, DIAGNOSTIC, FOLD_REGION, INDENT_GUIDE, BRACKET_GUIDE, FLOW_GUIDE, SEPARATOR_GUIDE, GUTTER_ICON, PHANTOM_TEXT |
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

### 13.2 输入法处理（MAY 不同）

输入法集成天然是平台特定的：

| 平台 | IME API |
|---|---|
| Android | `InputConnection` |
| iOS | `UITextInput` |
| macOS | `NSTextInputClient` |
| Swing | `InputMethodRequests` |
| WinForms | `ImmAssociateContext` / TSF |
| OHOS | IME Kit |

### 13.3 可选模块

| 模块 | 移动端 | 桌面端 |
|---|---|---|
| `copilot/`（内联建议） | SHOULD | SHOULD |
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

状态变更类编辑器操作和对宿主可见的回调默认与 UI 线程绑定。平台 MAY 暴露额外的线程安全查询面，但 MUST 选择具体线程模型并明确文档化。

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 状态变更 API 线程 | **MUST** | 会修改编辑器状态或触发可见 UI 更新的公共方法，除非平台显式文档化了等价的串行线程模型，否则 MUST 在 UI 线程调用 |
| API 线程契约文档 | **MUST** | 平台文档 MUST 明确标注哪些公共 API 只能在 UI 线程调用，以及哪些纯查询 / 快照 API（如果有）可安全在后台线程调用 |
| 纯查询 API 线程 | **SHOULD** | 纯查询 / 快照 API SHOULD 要么保持 UI 线程限定，要么被显式文档化为后台安全；仅在实现安全时平台 MAY 允许后台读取 |
| 事件回调线程 | **MUST** | 所有事件回调 / 委托调用 / stream emission（对宿主可见的事件分发）MUST 在 UI 线程执行 |
| Provider 调用线程 | **MUST** | 平台 MUST 为 `provideDecorations()` 和 `provideCompletions()` 选择稳定的调用模型（UI 线程、工作线程或其他文档化的串行执行器），并 MUST 对宿主文档化该模型 |
| Provider 异步回调线程 | **MUST** | Provider 结果回传可以发生在任意线程，但 Manager 在将结果应用到 Core 或修改宿主可见编辑器状态前 MUST 切回 UI 线程 |
| `buildRenderModel()` | **MUST** | `buildRenderModel()` MUST 观察稳定的编辑器快照。平台 MAY 要求 UI 线程调用，也 MAY 提供更强的线程安全快照契约；返回的 `EditorRenderModel` SHOULD 视为不可变对象，MAY 在渲染线程安全读取 |
| `NewLineActionProvider` | **MUST** | `provideNewLineAction()` MUST 在输入路径上同步完成，确保 Enter 处理不依赖后续异步回调 |
| 线程安全标注 | **SHOULD** | 各平台 SHOULD 在公共 API 文档中标注线程约束（如 Java `@MainThread`、Swift `@MainActor`） |

---
## 15. 错误处理（MUST）

公共 API 对非法输入采用防御性处理，不抛出异常；Provider 回调中的异常由 Manager 隔离。

### 15.1 公共 API 参数校验

| 场景 | 约束级别 | 行为 |
|---|---|---|
| 行号 / 列号越界 | **MUST** | 自动 clamp 到有效范围 `[0, max)`，MUST NOT 抛出异常 |
| null / 空参数 | **MUST** | 对于 MUST 非空的参数传入 null 时，MUST 静默忽略（no-op）并通过日志记录警告；MUST NOT 抛出异常或崩溃 |
| 无效枚举值 | **MUST** | 使用默认值（如 `WrapMode.NONE`），MUST NOT 抛出异常 |
| 控件未挂载时调用 | **SHOULD** | getter 返回 null 或默认值；命令式方法 SHOULD 排队或静默忽略（与 3.0.3 节一致） |

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

### 16.1 `EditorCore` 生命周期

| 阶段 | 约束级别 | 规则 |
|---|---|---|
| 创建 | **MUST** | `EditorCore` 实例 MUST 在控件初始化阶段创建（命令式框架：构造函数或 init；声明式框架：控件首次挂载时） |
| 资源释放路径 | **MUST** | 平台 MUST 保证 `EditorCore` 及其 native / C++ 侧资源最终会被释放；释放机制 MAY 是显式 `dispose()` / `close()`、宿主管理生命周期、基于 GC / finalizer / ARC 的自动回收、平台等价清理钩子，或其他平台惯用机制。view detach、widget unmount 或视图树中的临时移除，本身 NOT 必须构成最终释放时机 |
| 释放后调用 | **MUST** | 若平台暴露显式释放 API，或对象在内部释放后仍可能继续被访问，则释放后的任何方法调用 MUST 为 no-op 或抛出明确的"已销毁"异常，MUST NOT 访问已释放的 C++ 内存 |
| 重复释放 | **MUST** | 若平台暴露显式释放逻辑，多次调用 MUST 为幂等操作（no-op），MUST NOT 导致 double-free |

### 16.2 Provider 生命周期

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 注册时机 | **SHOULD** | Provider SHOULD 在 `loadDocument()` 之后注册，以确保 Context 中有有效的文档数据 |
| 释放阶段清理 | **MUST** | 若平台定义了显式的 editor 释放 / dispose / close / teardown 阶段，则 MUST 自动注销所有已注册的 Provider，并取消或标记所有进行中的异步请求为过期，使延迟结果被忽略；若平台完全依赖自动回收，SHOULD 仍保证延迟异步结果不会修改已释放的 native 资源或宿主可见的 editor 状态 |
| Provider 引用 | **SHOULD** | 平台实现 SHOULD 避免 Provider 强引用控件实例，防止循环引用导致内存泄漏（Java/Kotlin 使用 WeakReference、Swift 使用 weak/unowned、Dart 无需特殊处理） |

### 16.3 `SweetEditorController` 生命周期（声明式框架）

| 阶段 | 约束级别 | 规则 |
|---|---|---|
| 创建 | **MUST** | Controller MUST 由宿主代码创建，生命周期由宿主管理 |
| 绑定 | **MUST** | 控件挂载时 MUST 调用 `bind()`，卸载时 MUST 调用 `unbind()`（与 3.0.3 节一致） |
| `dispose()` 顺序 | **MUST** | `dispose()` MUST 先解绑控件（如果仍绑定），再释放内部资源；`dispose()` 后任何方法调用 MUST 为 no-op |
| 控件重建 | **SHOULD** | 声明式框架中控件可能因 state 变化被重建；Controller SHOULD 在旧控件 `unbind()` 后无缝 `bind()` 到新控件，不丢失排队的操作 |

### 16.4 资源释放顺序

当平台执行 editor 释放 / dispose / close / 最终 teardown 时，各子系统 MUST 按以下顺序释放：

```
1. 取消所有进行中的异步 Provider 请求
2. 注销所有 Provider（Decoration / Completion / NewLine）
3. 清除所有对宿主可见的事件订阅 / 监听器 / observer
4. 释放 EditorCore / native 资源
5. 释放平台特定资源（纹理、画布、定时器等）
```

> 步骤 1-3 的内部顺序 MAY 调整，但 MUST 在步骤 4 之前完成。步骤 4 MUST 在步骤 5 之前完成。标准不要求步骤 4 必须与 view detach、widget unmount，或控件永久移除视图树这一特定时机绑定。

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

**`TextChange`** — 增量文本变更

| 字段 | 类型 | MUST/MAY | 说明 |
|---|---|---|---|
| `range` | TextRange | **MUST** | 文档坐标中的变更范围 |
| `text` | String | **MUST** | 替换后的文本；空字符串表示纯删除 |

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
| `color` | int | **MUST** | 自定义颜色（ARGB），0 表示使用 severity 默认颜色 |

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
| `style` | int | **MUST** | 样式：SINGLE=0, DOUBLE=1 |
| `count` | int | **MUST** | 重复次数 |
| `textEndColumn` | int | **MUST** | 文本结束列（用于确定分隔线起始绘制位置） |

---

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
| 资源释放 | **MUST** | 当 `Document` 按平台生命周期被销毁 / dispose 时，桥接层 MUST 最终释放 C++ 侧文档内存；具体清理机制由平台决定 |
| 编码模型 | **MUST** | 平台层 MUST NOT 假设或暴露特定的内部存储 / 布局编码；只可依赖公共 API 保证的语义 |
| 行尾符 | **MUST** | C++ Core 支持 LF、CR、CRLF 三种行尾符；`getLineText()` 返回的文本 MUST NOT 包含行尾符 |

### 18.4 与 `loadDocument()` 的关系

| 规则 | 约束级别 | 说明 |
|---|---|---|
| 加载时机 | **MUST** | `Document` 创建后 MUST 通过 `loadDocument(doc)` 加载到编辑器；未加载的 `Document` 不会触发任何渲染或事件 |
| 文档替换 | **MUST** | 再次调用 `loadDocument()` 会替换当前文档；旧文档的引用由宿主代码管理 |
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

