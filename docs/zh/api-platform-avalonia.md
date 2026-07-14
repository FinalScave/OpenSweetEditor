# Avalonia API

环境要求、源码接入、构建命令和宿主配置见 [Avalonia README](../../platform/Avalonia/SweetEditor/README.md)。

本文档说明 `platform/Avalonia/SweetEditor` 当前真实公开的 API。

## 最小集成

在宿主应用中引用源码项目：

```xml
<ItemGroup>
  <ProjectReference Include="platform/Avalonia/SweetEditor/SweetEditor.csproj" />
</ItemGroup>
```

请根据宿主项目位置调整相对路径。`ProjectReference` 只提供托管控件，不会传递仓库为 Android 或 iOS 配置的 native library item；移动端宿主必须按下文显式配置这些资源。

可以直接创建控件，也可以绑定 Controller：

```csharp
using SweetEditor;

var controller = new SweetEditorController();
var editor = new SweetEditorControl(controller);
editor.ApplyTheme(EditorTheme.Dark());
editor.LoadDocument(new Document("Hello, SweetEditor!"));
editor.GetSettings().SetWrapMode(WrapMode.WORD_BREAK);
```

## `SweetEditorControl`

### 构造、生命周期与核心配置

```csharp
public SweetEditorControl()
public SweetEditorControl(SweetEditorController controller)
public void Dispose()

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
public void SetMaxGutterIcons(int count)
public int GetMaxGutterIcons()
```

`Flush()` 用于诊断场景下强制刷新渲染模型。正常编辑、滚动、选区、IME、Provider 和装饰操作会自动请求重绘。未加载文档时，`GetTotalLineCount()` 返回 `-1`。

### 文本编辑、行操作与剪贴板

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

`ApplyTextEdits(...)` 接收基于原始文档坐标且互不重叠的编辑，并把实际内容变更归为一次撤销操作。

### 搜索与替换

```csharp
public void Search(SearchRequest request)
public void FindNextSearchMatch()
public void FindPreviousSearchMatch()
public void ReplaceCurrentSearchMatch(string replacement)
public void ReplaceAllSearchMatches(string replacement)
public void ClearSearch()
public SearchState GetSearchState()
```

`SearchOptions` 支持区分大小写、全词、正则表达式、循环搜索和最大匹配数。`SearchState` 会返回状态、匹配数、当前匹配、generation 和错误信息。

### 光标、选区、导航与几何信息

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
public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.GOTO_CENTER)
public void SetScroll(float scrollX, float scrollY)
public ScrollMetrics GetScrollMetrics()
public CursorRect GetPositionRect(int line, int column)
public CursorRect GetCursorRect()
```

`GetLinkTargetAt(...)` 等字符串查询在没有结果时返回空字符串。

### 样式、装饰与折叠

```csharp
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
public bool ToggleFold(int line)
public bool FoldAt(int line)
public bool UnfoldAt(int line)
public bool IsLineVisible(int line)
public void FoldAll()
public void UnfoldAll()

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
public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn)
public void ClearMatchedBrackets()
```

控件可渲染语法、语义和 overlay spans，以及 Inlay Hint、Phantom Text、CodeLens、链接、诊断、文档高亮、gutter 图标、折叠区域和 indent、bracket、flow、separator guides。

### Snippet 与联动编辑

```csharp
public EditorActionResult InsertSnippet(string snippetTemplate)
public void StartLinkedEditing(LinkedEditingModel model)
public bool IsInLinkedEditing()
public bool LinkedEditingNext()
public bool LinkedEditingPrev()
public void CancelLinkedEditing()
```

Snippet 插入支持 tab stops；也可以直接使用 `LinkedEditingModel` 启动联动编辑。

### Provider、补全、Inline Suggestion 与 Selection Menu

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

- 补全 Provider 接收主动触发、触发字符或 retrigger 上下文，并通过可取消 receiver 返回结果。`CompletionItem.TextEdit` 定义主替换范围，`AdditionalTextEdits` 使用原始文档坐标；snippet 格式的补全项会进入 snippet 模式。`ICompletionItemRenderer` 为每个补全项提供高度和 Avalonia `Control`。
- 装饰 Provider 会收到可见行范围、累计文本变更、语言配置和编辑器元数据，可按 merge、replace-all 或 replace-range 模式返回语法、语义、overlay、Inlay Hint、诊断、文档高亮、guide、折叠、gutter 图标、Phantom Text、CodeLens 和链接数据。
- New-line action Provider 组成责任链。首个返回 action 的 Provider 决定 Enter 插入的文本；返回 `null` 时继续交给后续 Provider 或编辑器默认行为。
- 编辑器持有补全和移动端 Selection Menu UI。宿主通过公开 Provider 接口提供补全结果、自定义菜单项、自定义补全项控件和监听器。

### 事件

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
public event EventHandler<CodeLensClickEventArgs>? CodeLensClick
public event EventHandler<LinkClickEventArgs>? LinkClick
public event EventHandler<FoldToggleEventArgs>? FoldToggle
public event EventHandler<SelectionMenuItemClickEventArgs>? SelectionMenuItemClick
public event Action<IReadOnlyList<CompletionItem>>? CompletionItemsUpdated
public event Action? CompletionDismissed
public event Action<InlineSuggestion>? InlineSuggestionAccepted
public event Action<InlineSuggestion>? InlineSuggestionDismissed
```

`SelectionChangedEventArgs.Selection` 和 `DoubleTapEventArgs.Selection` 允许为空。

## `SweetEditorController`

```csharp
public void WhenReady(Action callback)
public void Dispose()
```

Controller 暴露与 `SweetEditorControl` 相同的命令和事件面，包括搜索、Settings 访问、Provider、补全、Inline Suggestion、Selection Menu、编辑、剪贴板、导航、装饰和联动编辑。

- 绑定前发出的调用会进入队列，并在控件绑定后按顺序执行。
- 已绑定时 `WhenReady(...)` 立即执行，否则在绑定后执行。
- 未绑定的 getter 返回约定的默认值或空值，不抛异常。Controller 的 `GetTheme()` 返回 `EditorTheme?`，`GetSettings()` 返回 `EditorSettings?`，与控件的非空 getter 不同。
- 一个 Controller 不能同时绑定多个控件。

## `EditorSettings`

通过 `editor.GetSettings()` 访问；使用 Controller 时，应在 Controller ready 后调用 `controller.GetSettings()`。

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
public void SetRenderWhitespace(WhitespaceRenderMode mode)
public WhitespaceRenderMode GetRenderWhitespace()
public void SetRenderLineBreaks(bool enabled)
public bool IsRenderLineBreaks()
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

`SetTypeface(...)` 是 `SetFontFamily(...)` 的别名。

## Keymap 与语言配置

`EditorKeyMap.DefaultKeyMap()` 和 `Vscode()` 可创建内置映射。宿主可以增加、替换、移除或清空 `KeyBinding`，并通过 `RegisterCommand(...)` 注册宿主命令。当前 Avalonia 实现不公开 JetBrains 或 Sublime preset factory。

`LanguageConfiguration` 描述语言 ID、括号对、自动闭合对、行注释、块注释、Tab 宽度和以空格代替 Tab 的偏好。括号、自动闭合和缩进配置会影响编辑行为；Completion、Decoration 和 New-line Provider 也可读取完整配置。

## `Document`

```csharp
public Document(string text)
public Document(FileInfo? file)
public static Document FromPath(string path)
public int GetLineCount()
public string GetLineText(int line)
public string GetText()
public void Dispose()
```

文档不再使用时应调用 `Dispose()`。把文档加载到控件不会转移托管 `Document` 对象的所有权。

## Avalonia 输入行为

- 桌面输入支持可配置键盘命令、剪贴板、鼠标选择与拖动、滚轮滚动、pointer cursor、上下文菜单、触控板缩放和带惯性的滚动手势。
- 触摸输入支持 tap、double tap、long press、拖选、滚动和直接 pinch 缩放；移动端宿主会渲染选区手柄并使用编辑器持有的 Selection Menu。
- Avalonia 文本输入与 IME 同步会处理 preedit、提交、选区、光标几何和 surrounding-text 状态；Android 还会跟踪 `InputPane` 遮挡，并重新定位编辑器持有的 popup 以避开软键盘。
- 补全、Inline Suggestion、链接、CodeLens、gutter 图标、折叠标记和 Selection Menu 项通过对应事件或 listener 参与键盘和 pointer 交互。

## Native Asset 支持

项目目标为 .NET 10 和 Avalonia 12.0.5，通过 `ProjectReference` 从源码接入。引用项目上级目录中的仓库级 targets 不会被外部宿主继承。

- `SweetEditor.csproj` 会在运行时匹配时复制 Windows x64、Linux x64 和 macOS x64/arm64 native 库。
- 仓库的 [Android 示例项目](../../platform/Avalonia/Demo.Android/Demo.Android.csproj) 通过 `AndroidNativeLibrary` item 包含 Android `arm64-v8a` 和 `x86_64` native 库。外部 Android 宿主必须为其支持的 ABI 添加等价 item。
- 仓库的 [Directory.Build.targets](../../platform/Avalonia/Directory.Build.targets) 只为 `platform/Avalonia` 目录树下的可执行项目添加 macOS 和 iOS native reference。外部 iOS 宿主必须为所选 arm64 真机或 arm64 模拟器库添加等价 `NativeReference`，并启用 `CopyToAppBundle`。
