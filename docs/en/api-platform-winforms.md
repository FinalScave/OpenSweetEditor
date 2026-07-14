# WinForms API

For installation, requirements, build commands, and package consumption, see the [WinForms README](../../platform/WinForms/SweetEditor/README.md).

This reference describes the primary host-facing API and WinForms-specific helpers in `platform/WinForms/SweetEditor`.

## Minimal Integration

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

The NuGet package places `sweeteditor.dll` under `runtimes/win-x64/native`, so normal package restore does not require manual `DllImport` setup or native file copying.

## `SweetEditorControl`

### Construction and Core Configuration

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

`Flush()` forces a render-model refresh for diagnostics. Normal editing, scrolling, selection, provider, and decoration operations request redraws automatically.

### Text Editing, Line Operations, and Clipboard

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

`ApplyTextEdits(...)` accepts non-overlapping edits in original-document coordinates and groups applied content changes into one undo operation.

### Search and Replace

```csharp
public void Search(SearchRequest request)
public void FindNextSearchMatch()
public void FindPreviousSearchMatch()
public void ReplaceCurrentSearchMatch(string replacement)
public void ReplaceAllSearchMatches(string replacement)
public void ClearSearch()
public SearchState GetSearchState()
```

`SearchOptions` supports case-sensitive, whole-word, regular-expression, wrap-around, and maximum-match settings. `SearchState` reports status, match count, current match, generation, and any error message.

### Cursor, Selection, Navigation, and Geometry

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

`GetTotalLineCount()` returns `0` when no document is loaded. `GetLinkTargetAt(...)` and other string queries return an empty string when no value is available.

### Styles, Decorations, and Folding

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

The control renders syntax, semantic, and overlay spans; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; fold regions; and indent, bracket, flow, and separator guides.

### Snippets and Linked Editing

```csharp
public void InsertSnippet(string snippetTemplate)
public void StartLinkedEditing(LinkedEditingModel model)
public bool IsInLinkedEditing()
public bool LinkedEditingNext()
public bool LinkedEditingPrev()
public void CancelLinkedEditing()
```

Snippet insertion supports tab stops. Linked editing can also be started directly with a `LinkedEditingModel`.

### Providers and Completion

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

- Completion providers receive invoked, trigger-character, or retrigger contexts and return results through a cancellable receiver. `CompletionItem.TextEdit` defines the primary replacement range; `AdditionalTextEdits` use original-document coordinates. Snippet-format items enter snippet mode.
- Decoration providers receive the visible range, accumulated text changes, language configuration, and editor metadata. They can return syntax, semantic, overlay, inlay, diagnostic, document-highlight, guide, fold, gutter-icon, phantom-text, CodeLens, and link data using merge, replace-all, or replace-range modes.
- New-line action providers form a chain. The first provider that returns an action supplies the text inserted for Enter; returning `null` delegates to the next provider or the default editor behavior.

### Events

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

Access settings through `editor.Settings`.

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

`WrapMode` accepts `NONE`, `CHAR_BREAK`, or `WORD_BREAK`.

## Themes, Private Fonts, Keymaps, and Language Configuration

`EditorTheme` provides built-in palettes and application-defined text styles:

```csharp
public static EditorTheme Dark()
public static EditorTheme Light()
public EditorTheme DefineTextStyle(int styleId, TextStyle style)
public Dictionary<int, TextStyle> TextStyles { get; set; }
```

The theme also exposes individual `Color` properties for editor text and background, selection, guides, scrollbars, IME composition, decorations, search and document highlights, and completion UI. Custom style IDs should start at `EditorTheme.STYLE_USER_BASE`.

`EditorFontLoader` registers a private font with Windows and owns that registration:

```csharp
public EditorFontLoader()
public string LoadFont(string path)
public Font CreateFont(float size, FontStyle style = FontStyle.Regular)
public void Dispose()
```

`LoadFont(...)` returns the family name accepted by `EditorSettings.SetFontFamily(...)`. Keep the loader alive for as long as the editor uses that private font, then dispose it.

`EditorKeyMap` exposes the built-in presets and host customization methods:

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

`LanguageConfiguration` describes the language ID, bracket pairs, auto-closing pairs, line and block comments, tab size, and spaces-for-tabs preference. Bracket, auto-closing, and indentation settings are applied to editing behavior; the full configuration is also available to completion, decoration, and new-line providers.

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

Dispose a document when it is no longer needed. Loading a new document into a control does not transfer ownership of the managed `Document` object.

## WinForms Input Behavior

- Keyboard input uses the active `EditorKeyMap`; completion and host commands are handled before ordinary text input where applicable.
- Mouse press, drag, hover, right-click, and wheel input are forwarded to editor gestures for selection, scrolling, links, CodeLens, gutter icons, folding, and context menus.
- Clipboard operations use the WinForms clipboard.
- Windows IME integration supports preedit text, commit, cancellation, and grapheme-based surrounding-text deletion while composing.
