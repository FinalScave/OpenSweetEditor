# Avalonia 平台 API

本文档对应当前 Avalonia 实现：

- 控件层：`platform/Avalonia/SweetEditor/SweetEditorControl.cs`
- 控制器：`platform/Avalonia/SweetEditor/SweetEditorController.cs`
- 桥接层：`platform/Avalonia/SweetEditor/EditorCore.cs`
- 协议编解码：`platform/Avalonia/SweetEditor/CoreProtocol.cs`
- 渲染层：`platform/Avalonia/SweetEditor/EditorRenderer.cs`
- Provider / 扩展：
  - `platform/Avalonia/SweetEditor/EditorCompletion.cs`
  - `platform/Avalonia/SweetEditor/EditorDecoration.cs`
  - `platform/Avalonia/SweetEditor/EditorNewLine.cs`
  - `platform/Avalonia/SweetEditor/EditorInlineSuggestion.cs`
  - `platform/Avalonia/SweetEditor/EditorSelectionMenu.cs`
  - `platform/Avalonia/SweetEditor/EditorPerf.cs`
- 共享 Demo：`platform/Avalonia/Demo.Shared/*`
- Android 宿主：`platform/Avalonia/Demo.Android/*`
- 桌面宿主：`platform/Avalonia/Demo.Desktop/*`

## 架构说明

- Avalonia 平台主路径是 `Avalonia UI + C# P/Invoke -> C API`。
- `EditorCore` 负责封装 native 句柄、文档生命周期、文本编辑命令与 render-model 拉取。
- `CoreProtocol` 负责二进制 payload 编解码；`EditorRenderer` 消费 `EditorRenderModel` 进行 Avalonia `DrawingContext` 绘制。
- `SweetEditorControl` 是宿主真正持有的控件入口；`SweetEditorController` 提供声明式 / MVVM 风格下的外部控制入口。
- Decorations / Completion / NewLine / InlineSuggestion / SelectionMenu 均在 Avalonia 层按标准拆成独立 manager/provider 模块。
- SweetEditor native asset 统一收敛在 Avalonia 项目构建配置中，Demo 项目只负责宿主入口；SweetLine native asset 由 SweetLine NuGet 包提供。

## 目录结构

- `SweetEditor/`：Avalonia 控件、协议桥接、渲染、事件、provider 管理
- `Demo.Shared/`：共享 UI、样例加载、SweetLine 运行时、图标与菜单逻辑
- `Demo.Android/`：Avalonia Android 宿主入口
- `Demo.Desktop/`：Avalonia Desktop 宿主
- `Demo.Mac/` / `Demo.iOS/`：平台特定 Demo 宿主
- `api-platform-avalonia.md`：平台目录入口文档（当前文档在 `docs/zh` 的规范版本）

## 环境要求

### 基础要求

- .NET SDK：`8.0+`
- Avalonia：`11.3.12`
- SweetEditor core native 预构建库：
  - Windows：`prebuilt/windows/x64/sweeteditor.dll`
  - Linux：`prebuilt/linux/x86_64/libsweeteditor.so`
  - macOS：`prebuilt/osx/*/libsweeteditor.dylib`
  - Android：`prebuilt/android/*/libsweeteditor.so`
  - iOS：`prebuilt/ios/*/libsweeteditor.dylib`

### Android 额外要求

- .NET Android workload
- Android SDK（API 34）
- `adb`
- SweetLine native asset 由 SweetLine NuGet 包提供。

## 快速开始

### 在仓库内运行桌面 Demo

```bash
cd platform/Avalonia
dotnet build Avalonia.sln -c Debug
dotnet run --project Demo.Desktop/Demo.Desktop.csproj -c Debug
```

### 在仓库内构建 Android Demo

```bash
cd platform/Avalonia
dotnet build Demo.Android/Demo.Android.csproj \
  -c Debug \
  -f net8.0-android \
  -p:RuntimeIdentifier=android-arm64
```

手动安装可使用签名后的输出包：

```bash
adb install -r Demo.Android/bin/Debug/net8.0-android/android-arm64/com.qiplat.sweeteditor.avalonia.demo.android-Signed.apk
```

### 在现有 Avalonia 应用中接入

当前仓库内的推荐接入方式是项目引用：

```xml
<ItemGroup>
  <ProjectReference Include="platform/Avalonia/SweetEditor/SweetEditor.csproj" />
</ItemGroup>
```

最小示例：

```csharp
using SweetEditor;

var controller = new SweetEditorController();
var editor = new SweetEditorControl(controller);
editor.ApplyTheme(EditorTheme.Dark());
editor.LoadDocument(new Document("Hello, SweetEditor!"));
editor.GetSettings().SetWrapMode(WrapMode.WORD_BREAK);
```

## 资源与 SweetLine 对接

### 示例代码与高亮规则

`Demo.Shared` 会把仓库根目录 `platform/_res` 中的资源嵌入到程序集：

- `../../_res/files/*.*` -> `SweetEditor.PlatformRes.files.*`
- `../../_res/syntaxes/*.json` -> `SweetEditor.PlatformRes.syntaxes.*`

共享 Demo 样例加载入口：

- `platform/Avalonia/Demo.Shared/DemoSamples.cs`

### SweetLine native 对接

`Demo.Shared` 通过 SweetLine NuGet 包接入：

- `platform/Avalonia/Demo.Shared/DemoSweetLineRuntime.cs`

当前对接策略：

- Android：优先创建 `HighlightEngine`、`DocumentAnalyzer`、`TextAnalyzer`
- 语法规则：从嵌入资源 `platform/_res/syntaxes/*.json` 编译
- 大文档：优先走可见区 slice / 行级分析，避免整份高亮结果回传到托管层
- 桌面：若未提供 SweetLine native，则回退到托管高亮

## 公开入口类型

- `SweetEditorControl`
- `SweetEditorController`
- `EditorSettings`
- `EditorTheme`
- `Document`
- `LanguageConfiguration`
- `EditorKeyMap`
- `DecorationContext` / `DecorationResult`
- `CompletionContext` / `CompletionItem` / `CompletionResult`
- `InlineSuggestion`
- `SelectionMenuItem`

## 公开控件层：`SweetEditorControl`

### 构造

```csharp
public SweetEditorControl()
public SweetEditorControl(SweetEditorController controller)
```

### 公开事件

```csharp
public event EventHandler<TextChangedEventArgs>? TextChanged
public event EventHandler<CursorChangedEventArgs>? CursorChanged
public event EventHandler<SelectionChangedEventArgs>? SelectionChanged
public event EventHandler<ScrollChangedEventArgs>? ScrollChanged
public event EventHandler<ScaleChangedEventArgs>? ScaleChanged
public event EventHandler<DocumentLoadedEventArgs>? DocumentLoaded
public event EventHandler<LongPressEventArgs>? LongPress
public event EventHandler<DoubleTapEventArgs>? DoubleTap
public new event EventHandler<ContextMenuEventArgs>? ContextMenu
public event EventHandler<InlayHintClickEventArgs>? InlayHintClick
public event EventHandler<GutterIconClickEventArgs>? GutterIconClick
public event EventHandler<FoldToggleEventArgs>? FoldToggle
public event EventHandler<SelectionMenuItemClickEventArgs>? SelectionMenuItemClick
public event Action<IReadOnlyList<CompletionItem>>? CompletionItemsUpdated
public event Action? CompletionDismissed
public event Action<InlineSuggestion>? InlineSuggestionAccepted
public event Action<InlineSuggestion>? InlineSuggestionDismissed
```

说明：

- `SelectionChangedEventArgs.Selection` 允许为空
- `DoubleTapEventArgs.Selection` 允许为空
- 移动端会发出 `LongPress`
- 跨平台 / 桌面宿主可以消费 `ContextMenu`

### 文档 / 主题 / 语言 / 元数据 / 调试

```csharp
public void LoadDocument(Document document)
public Document? GetDocument()
public EditorTheme GetTheme()
public void ApplyTheme(EditorTheme theme)
public EditorSettings GetSettings()
public void SetKeyMap(EditorKeyMap map)
public EditorKeyMap GetKeyMap()
public void SetEditorIconProvider(EditorIconProvider? provider)
public void SetLanguageConfiguration(LanguageConfiguration? config)
public LanguageConfiguration? GetLanguageConfiguration()
public void SetMetadata<T>(T? metadata) where T : class, IEditorMetadata
public T? GetMetadata<T>() where T : class, IEditorMetadata
public void SetPerfOverlayEnabled(bool enabled)
public bool IsPerfOverlayEnabled()
public LayoutMetrics GetLayoutMetrics()
public void Flush()
public (int start, int end) GetVisibleLineRange()
public int GetTotalLineCount()
```

`Flush()` 是强制刷新 / 诊断入口。正常编辑、装饰、滚动、选区和 IME 同步路径会通过统一分发 `EditorActionResult`，并由 `NeedsRedraw` 决定是否刷新 render model 与重绘。

### Provider / Completion / Ghost / Selection Menu

```csharp
public void AddNewLineActionProvider(INewLineActionProvider provider)
public void RemoveNewLineActionProvider(INewLineActionProvider provider)

public void AddDecorationProvider(IDecorationProvider provider)
public void RemoveDecorationProvider(IDecorationProvider provider)
public void RequestDecorationRefresh()

public void AddCompletionProvider(ICompletionProvider provider)
public void RemoveCompletionProvider(ICompletionProvider provider)
public void TriggerCompletion()
public void ShowCompletionItems(List<CompletionItem> items)
public void DismissCompletion()
public void SetCompletionItemRenderer(ICompletionItemRenderer? renderer)

public void ShowInlineSuggestion(InlineSuggestion suggestion)
public void DismissInlineSuggestion()
public void AcceptInlineSuggestion()
public bool IsInlineSuggestionShowing()
public void SetInlineSuggestionListener(IInlineSuggestionListener? listener)

public void SetSelectionMenuItemProvider(ISelectionMenuItemProvider? provider)
public void SetSelectionMenuListener(ISelectionMenuListener? listener)
public bool IsSelectionMenuShowing()
```

说明：

- Avalonia 的 completion 与 selection menu UI 由编辑器控件内部持有；宿主通过 provider/listener API 提供菜单项并监听 custom 命令。
- `SetCompletionItemRenderer(...)` 通过 `ICompletionItemRenderer` 自定义补全项视图。

### 文本编辑 / 行操作 / 剪贴板 / 撤销重做

```csharp
public void InsertText(string text)
public void InsertTextAt(TextPosition position, string text)
public void ReplaceText(TextRange range, string newText)
public void DeleteText(TextRange range)
public void ApplyTextEdits(IReadOnlyList<TextEdit> edits)

public void MoveLineUp()
public void MoveLineDown()
public void CopyLineUp()
public void CopyLineDown()
public void DeleteLine()
public void InsertLineAbove()
public void InsertLineBelow()

public bool Undo()
public bool Redo()
public bool CanUndo()
public bool CanRedo()

public void CopyToClipboard()
public void PasteFromClipboard()
public void CutToClipboard()
```

### 光标 / 选区 / 导航 / 滚动

```csharp
public void SelectAll()
public string GetSelectedText()
public void SetSelection(int startLine, int startColumn, int endLine, int endColumn)
public (bool hasSelection, TextRange range) GetSelection()
public void SetCursorPosition(TextPosition position)
public TextPosition GetCursorPosition()
public TextRange? GetWordRangeAtCursor()
public string GetWordAtCursor()
public void GotoPosition(int line, int column = 0)
public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.CENTER)
public void SetScroll(float scrollX, float scrollY)
public ScrollMetrics GetScrollMetrics()
public CursorRect GetPositionRect(int line, int column)
public CursorRect GetCursorRect()
```

### 折叠 / 装饰 / 样式 / 联动编辑

```csharp
public bool ToggleFold(int line)
public bool FoldAt(int line)
public bool UnfoldAt(int line)
public bool IsLineVisible(int line)
public void FoldAll()
public void UnfoldAll()

public void RegisterTextStyle(uint styleId, int color, int backgroundColor, int fontStyle)
public void RegisterBatchTextStyles(IReadOnlyDictionary<int, TextStyle> stylesById)
public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans)
public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine)
public void ClearLineSpans(int line, SpanLayer layer)

public void SetLineInlayHints(int line, IList<InlayHint> hints)
public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine)
public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms)
public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine)
public void SetLineGutterIcons(int line, IList<GutterIcon> icons)
public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine)
public void SetLineCodeLens(int line, IList<CodeLensItem> items)
public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine)
public void SetLineLinks(int line, IList<LinkSpan> links)
public void SetBatchLineLinks(Dictionary<int, IList<LinkSpan>> linksByLine)
public string GetLinkTargetAt(int line, int column)
public void SetLineDiagnostics(int line, IList<Diagnostic> items)
public void SetBatchLineDiagnostics(Dictionary<int, IList<Diagnostic>> diagsByLine)
public void SetLineDocumentHighlights(int line, IList<DocumentHighlight> items)
public void SetBatchLineDocumentHighlights(Dictionary<int, IList<DocumentHighlight>> highlightsByLine)
public void SetIndentGuides(IList<IndentGuide> guides)
public void SetBracketGuides(IList<BracketGuide> guides)
public void SetFlowGuides(IList<FlowGuide> guides)
public void SetSeparatorGuides(IList<SeparatorGuide> guides)
public void SetFoldRegions(IList<FoldRegion> regions)

public void ClearHighlights()
public void ClearHighlights(SpanLayer layer)
public void ClearInlayHints()
public void ClearPhantomTexts()
public void ClearGutterIcons()
public void ClearCodeLens()
public void ClearLinks()
public void ClearGuides()
public void ClearDiagnostics()
public void ClearDocumentHighlights()
public void ClearAllDecorations()
public void ClearMatchedBrackets()

public EditorActionResult InsertSnippet(string snippetTemplate)
public void StartLinkedEditing(LinkedEditingModel model)
public bool IsInLinkedEditing()
public bool LinkedEditingNext()
public bool LinkedEditingPrev()
public void CancelLinkedEditing()
```

## 公开控制器层：`SweetEditorController`

### 生命周期

```csharp
public void WhenReady(Action callback)
public void Dispose()
```

### 控制器约束

- `SweetEditorController` 提供 `whenReady(callback)` 语义；若控件已绑定则立即回调。
- 控件未绑定时，命令式调用会入队，绑定后按顺序执行。
- getter 在未绑定时返回默认值或空值，不直接抛异常。
- 同一个 controller 不能同时绑定多个 `SweetEditorControl`。

### 公开事件

`SweetEditorController` 暴露的事件集合与 `SweetEditorControl` 保持一致：

```csharp
TextChanged / CursorChanged / SelectionChanged / ScrollChanged / ScaleChanged / DocumentLoaded
LongPress / DoubleTap / ContextMenu / InlayHintClick / GutterIconClick / FoldToggle
SelectionMenuItemClick / CompletionItemsUpdated / CompletionDismissed
InlineSuggestionAccepted / InlineSuggestionDismissed
```

### 公开方法

除构造函数外，`SweetEditorController` 暴露的命令面与 `SweetEditorControl` 1:1 对齐，包括：

- 文档 / 主题 / keymap / 语言配置 / 元数据 / perf overlay 开关 / LayoutMetrics
- Provider / Completion / InlineSuggestion / SelectionMenu
- 文本编辑 / 行操作 / 剪贴板 / 撤销重做
- 光标 / 选区 / 导航 / 滚动
- 折叠 / 样式 / 装饰 / linked editing
- `Flush()` / `GetVisibleLineRange()` / `GetTotalLineCount()`

控制器额外公开的唯一生命周期方法是 `WhenReady(...)` 与 `Dispose()`。

## 公开设置层：`EditorSettings`

```csharp
public void SetEditorTextSize(float size)
public float GetEditorTextSize()
public void SetFontFamily(string family)
public string GetFontFamily()
public void SetTypeface(string typeface)
public string GetTypeface()
public void SetScale(float scale)
public float GetScale()
public void SetFoldArrowMode(FoldArrowMode mode)
public FoldArrowMode GetFoldArrowMode()
public void SetWrapMode(WrapMode mode)
public WrapMode GetWrapMode()
public void SetCompositionEnabled(bool enabled)
public bool IsCompositionEnabled()
public void SetLineSpacing(float add, float mult)
public float GetLineSpacingAdd()
public float GetLineSpacingMult()
public void SetContentStartPadding(float padding)
public float GetContentStartPadding()
public void SetShowSplitLine(bool show)
public bool IsShowSplitLine()
public void SetGutterSticky(bool sticky)
public bool IsGutterSticky()
public void SetGutterVisible(bool visible)
public bool IsGutterVisible()
public void SetCurrentLineRenderMode(CurrentLineRenderMode mode)
public CurrentLineRenderMode GetCurrentLineRenderMode()
public void SetAutoIndentMode(AutoIndentMode mode)
public AutoIndentMode GetAutoIndentMode()
public void SetBackspaceUnindent(bool enabled)
public bool IsBackspaceUnindent()
public void SetReadOnly(bool readOnly)
public bool IsReadOnly()
public void SetMaxGutterIcons(int count)
public int GetMaxGutterIcons()
public void SetDecorationScrollRefreshMinIntervalMs(long ms)
public long GetDecorationScrollRefreshMinIntervalMs()
public void SetDecorationOverscanViewportMultiplier(float multiplier)
public float GetDecorationOverscanViewportMultiplier()
```

说明：

- `SetTypeface(...)` 是 `SetFontFamily(...)` 的别名。
- `SetDecorationScrollRefreshMinIntervalMs(...)` 与 `SetDecorationOverscanViewportMultiplier(...)` 用于控制装饰刷新节流与 overscan。
- Android Demo 当前会根据移动端场景对 `GutterSticky`、文本尺寸和装饰刷新频率做默认收口。

## Provider / 数据模型补充

### Completion

- `CompletionItem`
- `CompletionContext`
- `CompletionResult`
- `ICompletionProvider`
- `ICompletionReceiver`
- `ICompletionItemRenderer`
- `CompletionTriggerKind`

`CompletionItem.TextEdit` 是唯一替换范围语义来源。没有它时，补全会在光标处直接插入 `InsertText` / `Label`；`AdditionalTextEdits` 会追加到主编辑之后。

`ICompletionItemRenderer` 同时提供补全项高度和每个补全项对应的 Avalonia `Control`。

### Decoration

- `DecorationType`
- `DecorationApplyMode`
- `DecorationContext`
- `DecorationResult`
- `IDecorationProvider`
- `IDecorationReceiver`

### New Line

- `NewLineAction`
- `NewLineContext`
- `INewLineActionProvider`

### Ghost / Selection Menu

- `InlineSuggestion`
- `IInlineSuggestionListener`
- `SelectionMenuItem`
- `ISelectionMenuItemProvider`
- `ISelectionMenuListener`

## Android 与桌面差异

### Android

- `SweetEditorControl` 内部负责 `InputPane` 遮挡处理与 popup 位置更新。
- `SweetEditorControl` 在 Android 上关闭 `SupportsSurroundingText`，避免大文本 IME 查询开销。
- 触摸、长按、双击、拖选、IME 遮挡与 selection menu 行为由 Avalonia 控件层做额外适配。
- Native asset：
  - SweetEditor Android、Windows、Linux 资产由 `SweetEditor.csproj` 声明。
  - SweetEditor macOS、iOS app bundle 引用由 `platform/Avalonia/Directory.Build.targets` 注入。
  - SweetLine native asset 由 SweetLine NuGet 包提供。

### 桌面

- `Demo.Desktop` 与 `Demo.Android` 共用 `Demo.Shared/MainView.cs`。
- 若桌面环境未提供 SweetLine native，语法高亮会回退到托管实现。
- 桌面与 Android 共用 `SweetEditorControl` / `SweetEditorController` / Provider API 契约。

## 当前实现说明

- 当前 Avalonia 平台已经按项目标准实现 `SweetEditorControl`、`SweetEditorController`、`EditorSettings`、provider 管理、事件系统、selection menu、ghost、perf overlay 等宿主 API。
- Android Demo 主路径明确要求使用 SweetLine native，不自行实现另一套高亮引擎。
- 输入法、触摸、选区菜单、completion popup 和大文档高亮都由 Avalonia 控件层或 Demo provider 明确分工处理。
