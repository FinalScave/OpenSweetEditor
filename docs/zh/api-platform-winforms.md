# WinForms API

安装、环境要求、构建命令和包接入方式见 [WinForms README](../../platform/WinForms/SweetEditor/README.md)。

本文档说明 `platform/WinForms/SweetEditor` 面向宿主的主要 API 和 WinForms 专用辅助类型。

## 最小集成

```csharp
using System.Windows.Forms;
using SweetEditor;

public sealed class MainForm : Form
{
    public MainForm()
    {
        var editor = new SweetEditorControl { Dock = DockStyle.Fill };
        Controls.Add(editor);

        editor.ApplyTheme(EditorTheme.Dark());
        editor.LoadDocument(new Document("Hello, SweetEditor!"));
        editor.Settings.SetWrapMode(WrapMode.WORD_BREAK);
    }
}
```

NuGet 包会把 `sweeteditor.dll` 放到 `runtimes/win-x64/native`，正常包还原流程不需要手动配置 `DllImport` 或复制 native 文件。

## `SweetEditorControl`

### 构造与核心配置

```csharp
public SweetEditorControl()
public SweetEditorControl(IContainer container)

public EditorSettings Settings { get; }
public void LoadDocument(Document document)
public Document? GetDocument()
public EditorTheme? GetTheme()
public void ApplyTheme(EditorTheme theme)
public EditorKeyMap? GetKeyMap()
public void SetKeyMap(EditorKeyMap editorKeyMap)
public void SetLanguageConfiguration(LanguageConfiguration? config)
public LanguageConfiguration? GetLanguageConfiguration()
public void SetMetadata<T>(T? metadata) where T : class, IEditorMetadata
public T? GetMetadata<T>() where T : class, IEditorMetadata
public void SetEditorIconProvider(EditorIconProvider? provider)
public void SetPerfOverlayEnabled(bool enabled)
public bool IsPerfOverlayEnabled()
public void Flush()
```

`Flush()` 用于诊断场景下强制刷新渲染模型。正常编辑、滚动、选区、Provider 和装饰操作会自动请求重绘。

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
public string GetSelectedText()
public TextPosition GetCursorPosition()
public TextRange GetWordRangeAtCursor()
public string GetWordAtCursor()
public void SetCursorPosition(TextPosition position)
public void SetSelection(int startLine, int startColumn, int endLine, int endColumn)
public void SetSelection(TextRange range)
public (bool hasSelection, TextRange range) GetSelection()
public void SelectAll()

public void GotoPosition(int line, int column = 0)
public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.GOTO_CENTER)
public void SetScroll(float scrollX, float scrollY)
public ScrollMetrics GetScrollMetrics()
public CursorRect GetPositionRect(int line, int column)
public CursorRect GetCursorRect()
public IntRange GetVisibleLineRange()
public int GetTotalLineCount()
```

未加载文档时，`GetTotalLineCount()` 返回 `0`。`GetLinkTargetAt(...)` 等字符串查询在没有结果时返回空字符串。

### 样式、装饰与折叠

```csharp
public void RegisterTextStyle(int styleId, int color, int backgroundColor, int fontStyle)
public void RegisterTextStyle(int styleId, int color, int fontStyle)
public void RegisterBatchTextStyles(IReadOnlyDictionary<int, TextStyle> stylesById)
public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans)
public void SetLineSpans(int line, IList<StyleSpan> spans)
public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine)
public void ClearLineSpans(int line, SpanLayer layer)

public void SetLineInlayHints(int line, IList<InlayHint> hints)
public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine)
public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms)
public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine)
public void SetLineCodeLens(int line, IList<CodeLensItem> items)
public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine)
public void SetLineLinks(int line, IList<LinkSpan> links)
public void SetBatchLineLinks(Dictionary<int, IList<LinkSpan>> linksByLine)
public string GetLinkTargetAt(int line, int column)
public void SetLineDiagnostics(int line, IList<Diagnostic> items)
public void SetBatchLineDiagnostics(Dictionary<int, IList<Diagnostic>> diagsByLine)
public void SetLineDocumentHighlights(int line, IList<DocumentHighlight> items)
public void SetBatchLineDocumentHighlights(Dictionary<int, IList<DocumentHighlight>> highlightsByLine)
public void SetLineGutterIcons(int line, IList<GutterIcon> icons)
public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine)

public void SetIndentGuides(IList<IndentGuide> guides)
public void SetBracketGuides(IList<BracketGuide> guides)
public void SetFlowGuides(IList<FlowGuide> guides)
public void SetSeparatorGuides(IList<SeparatorGuide> guides)

public void SetFoldRegions(IList<FoldRegion> regions)
public bool ToggleFold(int line)
public bool ToggleFoldAt(int line)
public bool FoldAt(int line)
public bool UnfoldAt(int line)
public void FoldAll()
public void UnfoldAll()
public bool IsLineVisible(int line)

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
```

控件可渲染语法、语义和 overlay spans，以及 Inlay Hint、Phantom Text、CodeLens、链接、诊断、文档高亮、gutter 图标、折叠区域和 indent、bracket、flow、separator guides。

### Snippet 与联动编辑

```csharp
public void InsertSnippet(string snippetTemplate)
public void StartLinkedEditing(IReadOnlyList<TabStopGroup> groups)
public bool IsInLinkedEditing()
public bool LinkedEditingNext()
public bool LinkedEditingPrev()
public void CancelLinkedEditing()
```

Snippet 插入支持 tab stops；也可以直接使用 `TabStopGroup` 列表启动联动编辑。

### Provider 与补全

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
```

- 补全 Provider 接收主动触发、触发字符或 retrigger 上下文，并通过可取消 receiver 返回结果。`CompletionItem.TextEdit` 定义主替换范围，`AdditionalTextEdits` 使用原始文档坐标；snippet 格式的补全项会进入 snippet 模式。
- 装饰 Provider 会收到可见行范围、累计文本变更、语言配置和编辑器元数据，可按 merge、replace-all 或 replace-range 模式返回语法、语义、overlay、Inlay Hint、诊断、文档高亮、guide、折叠、gutter 图标、Phantom Text、CodeLens 和链接数据。
- New-line action Provider 组成责任链。首个返回 action 的 Provider 决定 Enter 插入的文本；返回 `null` 时继续交给后续 Provider 或编辑器默认行为。

### 事件

```csharp
public event EventHandler<TextChangedEventArgs> TextChanged
public event EventHandler<CursorChangedEventArgs> CursorChanged
public event EventHandler<SelectionChangedEventArgs> SelectionChanged
public event EventHandler<ScrollChangedEventArgs> ScrollChanged
public event EventHandler<ScaleChangedEventArgs> ScaleChanged
public event EventHandler<DocumentLoadedEventArgs> DocumentLoaded
public event EventHandler<LongPressEventArgs> LongPress
public event EventHandler<DoubleTapEventArgs> DoubleTap
public event EventHandler<ContextMenuEventArgs> ContextMenu
public event EventHandler<InlayHintClickEventArgs> InlayHintClick
public event EventHandler<GutterIconClickEventArgs> GutterIconClick
public event EventHandler<FoldToggleEventArgs> FoldToggle
public event EventHandler<CodeLensClickEventArgs> CodeLensClick
public event EventHandler<LinkClickEventArgs> LinkClick
```

## `EditorSettings`

通过 `editor.Settings` 访问设置。

```csharp
public void SetEditorTextSize(float size)
public float GetEditorTextSize()
public void SetFontFamily(string family)
public string GetFontFamily()
public void SetScale(float scale)
public float GetScale()
public void SetFoldArrowMode(FoldArrowMode mode)
public FoldArrowMode GetFoldArrowMode()
public void SetWrapMode(WrapMode mode)
public WrapMode GetWrapMode()
public void SetRenderWhitespace(WhitespaceRenderMode mode)
public WhitespaceRenderMode GetRenderWhitespace()
public void SetRenderLineBreaks(bool enabled)
public bool IsRenderLineBreaks()
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
public void SetDecorationScrollRefreshMinIntervalMs(int intervalMs)
public int GetDecorationScrollRefreshMinIntervalMs()
public void SetDecorationOverscanViewportMultiplier(float multiplier)
public float GetDecorationOverscanViewportMultiplier()
```

`WrapMode` 可取 `NONE`、`CHAR_BREAK` 或 `WORD_BREAK`。

## 主题、私有字体、Keymap 与语言配置

`EditorTheme` 提供内置配色和应用自定义文本样式：

```csharp
public static EditorTheme Dark()
public static EditorTheme Light()
public EditorTheme DefineTextStyle(int styleId, TextStyle style)
public Dictionary<int, TextStyle> TextStyles { get; set; }
```

主题还公开编辑器文字与背景、选区、辅助线、滚动条、IME 组合输入、Decoration、搜索与文档高亮、Completion UI 等独立 `Color` 属性。自定义样式 ID 应从 `EditorTheme.STYLE_USER_BASE` 开始分配。

`EditorFontLoader` 会向 Windows 注册私有字体，并持有该注册资源：

```csharp
public EditorFontLoader()
public string LoadFont(string path)
public Font CreateFont(float size, FontStyle style = FontStyle.Regular)
public void Dispose()
```

`LoadFont(...)` 返回可传给 `EditorSettings.SetFontFamily(...)` 的字体族名称。编辑器使用该私有字体期间应保持 loader 存活，结束使用后再调用 `Dispose()`。

`EditorKeyMap` 公开内置预设和宿主自定义方法：

```csharp
public static EditorKeyMap DefaultKeyMap()
public static EditorKeyMap Vscode()
public static EditorKeyMap JetBrains()
public static EditorKeyMap Sublime()
public void AddBinding(KeyBinding binding)
public bool RemoveBinding(KeyBinding binding)
public IReadOnlyList<KeyBinding> GetBindings()
public int RegisterCommand(KeyBinding binding, Action<KeyBinding, SweetEditorControl> handler)
public Action<KeyBinding, SweetEditorControl>? GetCommand(int commandId)
```

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

## WinForms 输入行为

- 键盘输入使用当前 `EditorKeyMap`；适用时会先处理补全和宿主命令，再处理普通文本输入。
- 鼠标按下、拖动、悬停、右键和滚轮输入会转为编辑器手势，用于选区、滚动、链接、CodeLens、gutter 图标、折叠和上下文菜单。
- 剪贴板操作使用 WinForms 剪贴板。
- Windows IME 支持 preedit、提交、取消，以及组合输入期间按 grapheme 删除 surrounding text。
