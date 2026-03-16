# WinForms Platform API

This document maps to the current WinForms implementation:

- Control layer: `platform/WinForms/SweetEditor/EditorControl.cs`
- Bridge layer: `platform/WinForms/SweetEditor/EditorCore.cs`
- Protocol decode: `platform/WinForms/SweetEditor/EditorProtocol.cs`
- Extension/Provider: `platform/WinForms/SweetEditor/EditorExtension.cs`
- Performance debug: `platform/WinForms/SweetEditor/Perf.cs`
- Demo: `platform/WinForms/Demo/Form1.cs`

## Architecture Notes

- WinForms calls C API by P/Invoke (`sweeteditor.dll`).
- `EditorCore` wraps native calls, and `EditorProtocol` decodes binary payload.
- The current bridge protocol is binary payload.
- `EditorControl` handles input, drawing, event publishing, and provider management.
- `Document` creation and line-text query use UTF-16 boundary; text fields in render model and edit results are currently decoded as UTF-8.

## Public Control Layer: `EditorControl`

### Constructors

```csharp
public EditorControl()
public EditorControl(IContainer container)
```

### Document / Appearance / Language Config / Debug

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

`Flush()` applies pending updates (decoration / layout / scroll / selection) and triggers redraw. For batched decoration updates, call `Flush()` once at the end.

### Edit / Line Actions / Undo Redo

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

### Cursor Selection / Navigation

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

### Styles / Decorations / Folding / Linked Editing

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

### Provider / Completion

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

`GetTotalLineCount()` currently returns `-1` (to be improved).

## Bridge Layer Notes

- `EditorCore` (P/Invoke) already has bracket highlight bridge:
  - `SetBracketPairs(int[] openChars, int[] closeChars)`
  - `SetMatchedBrackets(...)`
  - `ClearMatchedBrackets()`
- Common control entry is `SetLanguageConfiguration(...)`, which sends bracket pairs to core.
- Performance overlay is provided by `Perf.cs`, off by default, for debug/build troubleshooting only.

## `Document`

```csharp
public Document(string text)
public string GetLineText(int line)
```
