# WinForms Platform API

This document maps to the current WinForms implementation:

- Control layer: `platform/WinForms/SweetEditor/SweetEditorControl.cs`
- Bridge layer: `platform/WinForms/SweetEditor/EditorCore.cs`
- Protocol encode/decode: `platform/WinForms/SweetEditor/CoreProtocol.cs`
- Extension/Provider:
  - `platform/WinForms/SweetEditor/EditorCompletion.cs`
  - `platform/WinForms/SweetEditor/EditorDecoration.cs`
  - `platform/WinForms/SweetEditor/EditorNewLine.cs`
- Performance debug: `platform/WinForms/SweetEditor/Perf.cs`
- Demo: `platform/WinForms/Demo/Form1.cs`

## Architecture Notes

- WinForms calls C API by P/Invoke (`sweeteditor.dll`).
- `EditorCore` wraps native calls, and `CoreProtocol` encodes and decodes binary payloads.
- The current bridge protocol is binary payload.
- `SweetEditorControl` handles input, drawing, event publishing, and provider management.
- `Document` creation and line-text query use UTF-16 boundary; text fields in the render model and `EditorActionResult` payload are currently decoded as UTF-8.

## Quick Start

### Environment Requirements (current repository setup)

- .NET SDK: `8.0+`
- Runtime platform: Windows x64

### Run the WinForms Demo in this repository

```powershell
cd platform/WinForms
dotnet build .\WinForms.sln -c Release
dotnet run --project .\Demo\Demo.csproj -c Release
```

### Integrate into an existing WinForms app via NuGet

Recommended: install from NuGet directly:

```powershell
dotnet add package SweetEditor --version 1.0.4
```

Or add this in your project file:

```xml
<ItemGroup>
  <PackageReference Include="SweetEditor" Version="1.0.4" />
</ItemGroup>
```

> Use the latest published version when integrating; `1.0.4` is the current example in this document.

### Minimal Integration Example

```csharp
using System.Windows.Forms;
using SweetEditor;

public sealed class MainForm : Form
{
    public MainForm()
    {
        var editor = new SweetEditorControl
        {
            Dock = DockStyle.Fill
        };
        Controls.Add(editor);

        editor.ApplyTheme(EditorTheme.Dark());
        editor.LoadDocument(new Document("Hello, SweetEditor!"));
        editor.Settings.SetWrapMode(WrapMode.WORD_BREAK);
    }
}
```

### Notes

- The NuGet package includes native runtime:
  `runtimes/win-x64/native/sweeteditor.dll`
- No manual `DllImport` setup or manual native file copy is required in normal NuGet restore flow.

## Public Control Layer: `SweetEditorControl`

### Constructors

```csharp
public SweetEditorControl()
public SweetEditorControl(IContainer container)
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

`Flush()` is a force-refresh / diagnostic entrypoint. Normal edit, decoration, scroll, and selection paths dispatch `EditorActionResult` through the unified result path, and `NeedsRedraw` decides whether to refresh the render model and redraw; hosts usually do not need to call it after batched decoration updates.

### Edit / Line Actions / Undo Redo

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
```

### Cursor Selection / Navigation

```csharp
public string GetSelectedText()
public TextPosition GetCursorPosition()
public Document? GetDocument()
public TextRange GetWordRangeAtCursor()
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
public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle)
public void registerBatchTextStyles(IReadOnlyDictionary<int, TextStyle> stylesById)
public void registerTextStyle(int styleId, int color, int fontStyle)
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
public void ClearCodeLens()
public void SetLineLinks(int line, IList<LinkSpan> links)
public void SetBatchLineLinks(Dictionary<int, IList<LinkSpan>> linksByLine)
public string GetLinkTargetAt(int line, int column)
public void ClearLinks()

public void SetLineDiagnostics(int line, IList<Diagnostic> items)
public void SetBatchLineDiagnostics(Dictionary<int, IList<Diagnostic>> diagsByLine)
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

public EditorActionResult InsertSnippet(string snippetTemplate)
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

`GetTotalLineCount()` returns the current document line count, or `-1` when no document is loaded.

`CompletionItem.TextEdit` uses the generated `TextEdit` type for precise replacement edits. Without `TextEdit`, completion inserts `InsertText` / `Label` at the cursor; `AdditionalTextEdits` is appended after the primary edit.

### Interaction Events

```csharp
public event EventHandler<CodeLensClickEventArgs> CodeLensClick
public event EventHandler<LinkClickEventArgs> LinkClick
```

`GetLinkTargetAt()` returns an empty string when no link matches the requested position.

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
