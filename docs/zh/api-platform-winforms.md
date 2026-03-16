# WinForms 平台 API

本文档对应当前 WinForms 实现：

- 控件层：`platform/WinForms/SweetEditor/EditorControl.cs`
- 桥接层：`platform/WinForms/SweetEditor/EditorCore.cs`
- 协议解码：`platform/WinForms/SweetEditor/EditorProtocol.cs`
- 扩展/Provider：`platform/WinForms/SweetEditor/EditorExtension.cs`
- 性能调试：`platform/WinForms/SweetEditor/Perf.cs`
- Demo：`platform/WinForms/Demo/Form1.cs`

## 架构说明

- WinForms 通过 P/Invoke 调用 C API（`sweeteditor.dll`）。
- `EditorCore` 封装 native 调用，`EditorProtocol` 负责二进制 payload 解码。
- 当前桥接协议为二进制 payload。
- `EditorControl` 负责输入、绘制、事件发布、Provider 管理。
- `Document` 创建 / 行文本查询走 UTF-16 边界；渲染模型与编辑结果里的文本字段当前按 UTF-8 解码。

## 公开控件层：`EditorControl`

### 构造

```csharp
public EditorControl()
public EditorControl(IContainer container)
```

### 文档 / 外观 / 语言配置 / 调试

```csharp
public void LoadDocument(Document document)
public EditorTheme GetTheme()
public void ApplyTheme(EditorTheme theme)
public void SetPerfOverlayEnabled(bool enabled)
public bool IsPerfOverlayEnabled()
public void SetFoldArrowMode(FoldArrowMode mode)
public void SetWrapMode(WrapMode mode)
public void SetAutoIndentMode(AutoIndentMode mode)
public AutoIndentMode GetAutoIndentMode()
public void SetLanguageConfiguration(LanguageConfiguration? config)
public LanguageConfiguration? GetLanguageConfiguration()
public void SetMetadata<T>(T? metadata) where T : class, IEditorMetadata
public T? GetMetadata<T>() where T : class, IEditorMetadata
public void SetLineSpacing(float add, float mult)
public CursorRect GetPositionRect(int line, int column)
public CursorRect GetCursorRect()
public void SetEditorIconProvider(EditorIconProvider? provider)
public void SetMaxGutterIcons(int count)
public void Flush()
```

`Flush()` 用于提交待处理更新（装饰 / 布局 / 滚动 / 选区）并触发重绘。装饰批量更新时，建议在最后手动调用一次 `Flush()`。

### 编辑 / 行操作 / 撤销重做

```csharp
public void InsertText(string text)
public void ReplaceText(TextRange range, string newText)
public void DeleteText(TextRange range)

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
```

### 光标选区 / 导航

```csharp
public string GetSelectedText()
public TextPosition GetCursorPosition()
public Document? GetDocument()
public TextRange? GetWordRangeAtCursor()
public string GetWordAtCursor()
public void SetCursorPosition(TextPosition position)
public void SetSelection(int startLine, int startColumn, int endLine, int endColumn)
public void SetSelection(TextRange range)
public (bool hasSelection, TextRange range) GetSelection()
public void SelectAll()

public void ScrollToLine(int line, ScrollBehavior behavior = ScrollBehavior.CENTER)
public void SetScroll(float scrollX, float scrollY)
public ScrollMetrics GetScrollMetrics()
public void GotoPosition(int line, int column = 0)
```

### 样式 / 装饰 / 折叠 / 联动编辑

```csharp
public void RegisterStyle(uint styleId, int color, int backgroundColor, int fontStyle)
public void RegisterStyle(uint styleId, int color, int fontStyle)
public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans)
public void SetLineSpans(int line, IList<StyleSpan> spans)
public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine)

public void SetLineInlayHints(int line, IList<InlayHint> hints)
public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine)
public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms)
public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine)

public void SetLineDiagnostics(int line, IList<DiagnosticItem> items)
public void SetBatchLineDiagnostics(Dictionary<int, IList<DiagnosticItem>> diagsByLine)
public void ClearDiagnostics()

public void SetLineGutterIcons(int line, IList<GutterIcon> icons)
public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine)
public void ClearGutterIcons()

public void SetIndentGuides(IList<IndentGuide> guides)
public void SetBracketGuides(IList<BracketGuide> guides)
public void SetFlowGuides(IList<FlowGuide> guides)
public void SetSeparatorGuides(IList<SeparatorGuide> guides)
public void ClearGuides()

public void SetFoldRegions(IList<FoldRegion> regions)
public bool ToggleFold(int line)
public bool FoldAt(int line)
public bool UnfoldAt(int line)
public void FoldAll()
public void UnfoldAll()
public bool IsLineVisible(int line)

public void ClearHighlights()
public void ClearHighlights(SpanLayer layer)
public void ClearInlayHints()
public void ClearPhantomTexts()
public void ClearAllDecorations()
public void ClearMatchedBrackets()

public TextEditResult InsertSnippet(string snippetTemplate)
public void StartLinkedEditing(LinkedEditingModel model)
public bool IsInLinkedEditing()
public bool LinkedEditingNext()
public bool LinkedEditingPrev()
public void CancelLinkedEditing()
```

### Provider / 补全

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
public (int start, int end) GetVisibleLineRange()
public int GetTotalLineCount()
```

`GetTotalLineCount()` 当前返回 `-1`（待完善）。

## 桥接层补充

- `EditorCore`（P/Invoke）已具备括号高亮桥接：
  - `SetBracketPairs(int[] openChars, int[] closeChars)`
  - `SetMatchedBrackets(...)`
  - `ClearMatchedBrackets()`
- 控件层常见入口是 `SetLanguageConfiguration(...)`，会把括号对下发到核心。
- 性能 overlay 由 `Perf.cs` 提供，默认关闭，仅用于调试构建 / 开发排查。

## `Document`

```csharp
public Document(string text)
public string GetLineText(int line)
```
