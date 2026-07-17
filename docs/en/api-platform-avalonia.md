# Avalonia API

For requirements, source integration, build commands, and host setup, see the [Avalonia README](../../platform/Avalonia/SweetEditor/README.md).

This reference describes the current public API in `platform/Avalonia/SweetEditor`.

## Minimal Integration

Add the source project to the host application:

```xml
<ItemGroup>
  <ProjectReference Include="platform/Avalonia/SweetEditor/SweetEditor.csproj" />
</ItemGroup>
```

Adjust the relative path for the host project. `ProjectReference` supplies the managed control but does not transitively add the repository's Android or iOS native-library items; mobile hosts must configure those assets explicitly as described below.

Create a control directly or bind it to a controller:

```csharp
using SweetEditor;

var controller = new SweetEditorController();
var editor = new SweetEditorControl(controller);
editor.ApplyTheme(EditorTheme.Dark());
editor.LoadDocument(new Document("Hello, SweetEditor!"));
editor.GetSettings().SetWrapMode(WrapMode.WORD_BREAK);
```

## `SweetEditorControl`

### Construction, Lifecycle, and Core Configuration

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

`Flush()` forces a render-model refresh for diagnostics. Normal editing, scrolling, selection, IME, provider, and decoration operations request redraws automatically. `GetTotalLineCount()` returns `-1` when no document is loaded.

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

`GetLinkTargetAt(...)` and other string queries return an empty string when no value is available.

### Styles, Decorations, and Folding

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

The control renders syntax, semantic, and overlay spans; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; fold regions; and indent, bracket, flow, and separator guides.

### Snippets and Linked Editing

```csharp
public EditorActionResult InsertSnippet(string snippetTemplate)
public void StartLinkedEditing(LinkedEditingModel model)
public bool IsInLinkedEditing()
public bool LinkedEditingNext()
public bool LinkedEditingPrev()
public void CancelLinkedEditing()
```

Snippet insertion supports tab stops. Linked editing can also be started directly with a `LinkedEditingModel`.

### Providers, Completion, Inline Suggestions, and Selection Menu

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

- Completion providers receive invoked, trigger-character, or retrigger contexts and return results through a cancellable receiver. `CompletionItem.TextEdit` defines the primary replacement range; `AdditionalTextEdits` use original-document coordinates. Snippet-format items enter snippet mode. `ICompletionItemRenderer` supplies the item height and Avalonia `Control` for each item.
- Decoration providers receive the visible range, accumulated text changes, language configuration, and editor metadata. They can return syntax, semantic, overlay, inlay, diagnostic, document-highlight, guide, fold, gutter-icon, phantom-text, CodeLens, and link data using merge, replace-all, or replace-range modes.
- New-line action providers form a chain. The first provider that returns an action supplies the text inserted for Enter; returning `null` delegates to the next provider or the default editor behavior.
- The editor owns completion and mobile selection-menu UI. Hosts provide completion results, custom menu items, custom item controls, and listeners through the public provider interfaces.

### Events

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

`SelectionChangedEventArgs.Selection` and `DoubleTapEventArgs.Selection` may be null.

## `SweetEditorController`

```csharp
public void WhenReady(Action callback)
public void Dispose()
```

The controller exposes the same command and event surface as `SweetEditorControl`, including search, settings access, providers, completion, inline suggestions, selection menu, editing, clipboard, navigation, decorations, and linked editing.

- Calls made before binding are queued and replayed after a control binds to the controller.
- `WhenReady(...)` runs immediately when already bound, or after binding otherwise.
- Unbound getters return documented default or empty values instead of throwing. In particular, controller `GetTheme()` returns `EditorTheme?` and `GetSettings()` returns `EditorSettings?`, unlike the non-null control getters.
- A controller instance cannot be bound to multiple controls at the same time.

## `EditorSettings`

Access settings through `editor.GetSettings()` or `controller.GetSettings()` after the controller is ready.

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

`SetTypeface(...)` is an alias of `SetFontFamily(...)`.

## Keymaps and Language Configuration

`EditorKeyMap.DefaultKeyMap()` and `Vscode()` create the built-in map. Hosts can add, replace, remove, or clear `KeyBinding` values and register host commands with `RegisterCommand(...)`. The current Avalonia implementation does not expose JetBrains or Sublime preset factories.

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

## Avalonia Input Behavior

- Desktop input supports configurable keyboard commands, clipboard operations, mouse selection and dragging, wheel scrolling, pointer cursors, context menus, touchpad magnification, and scroll gestures with inertia.
- Touch input supports tap, double tap, long press, drag selection, scrolling, and direct pinch scaling. Mobile hosts render selection handles and use the editor-owned selection menu.
- Avalonia text input and IME synchronization handle preedit, commit, selection, cursor geometry, and surrounding-text state. Android additionally tracks `InputPane` occlusion and repositions editor-owned popups to avoid the software keyboard.
- Completion, inline suggestions, links, CodeLens, gutter icons, fold markers, and selection-menu items participate in keyboard or pointer interaction through their corresponding events and listeners.

## Native Asset Support

The project targets .NET 10 and Avalonia 12.0.5. Integrate it from source through `ProjectReference`. Repository-level targets above the referenced project are not inherited by an external host.

- `SweetEditor.csproj` copies Windows x64, Linux x64, and macOS x64/arm64 native libraries when the selected runtime matches.
- The repository [Android demo project](../../platform/Avalonia/Demo.Android/Demo.Android.csproj) includes Android `arm64-v8a` and `x86_64` libraries with `AndroidNativeLibrary` items. An external Android host must add equivalent items for its supported ABIs.
- The repository [Directory.Build.targets](../../platform/Avalonia/Directory.Build.targets) adds macOS and iOS native references only to executable projects below `platform/Avalonia`. It extracts `SweetEditorCoreIOS.xcframework.zip` into the intermediate output directory and references the extracted XCFramework, allowing .NET to select the device or simulator framework slice. An external iOS host must add an equivalent XCFramework `NativeReference`.
