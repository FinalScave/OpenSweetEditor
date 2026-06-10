# Avalonia Platform API

This document maps to the current Avalonia implementation:

- Control layer: `platform/Avalonia/SweetEditor/SweetEditorControl.cs`
- Controller: `platform/Avalonia/SweetEditor/SweetEditorController.cs`
- Bridge layer: `platform/Avalonia/SweetEditor/EditorCore.cs`
- Protocol encode/decode: `platform/Avalonia/SweetEditor/CoreProtocol.cs`
- Rendering: `platform/Avalonia/SweetEditor/EditorRenderer.cs`
- Providers / extensions:
  - `platform/Avalonia/SweetEditor/EditorCompletion.cs`
  - `platform/Avalonia/SweetEditor/EditorDecoration.cs`
  - `platform/Avalonia/SweetEditor/EditorNewLine.cs`
  - `platform/Avalonia/SweetEditor/EditorInlineSuggestion.cs`
  - `platform/Avalonia/SweetEditor/EditorSelectionMenu.cs`
  - `platform/Avalonia/SweetEditor/EditorPerf.cs`
- Shared demo: `platform/Avalonia/Demo.Shared/*`
- Android host: `platform/Avalonia/Demo.Android/*`
- Desktop host: `platform/Avalonia/Demo.Desktop/*`

## Architecture Notes

- The Avalonia path is `Avalonia UI + C# P/Invoke -> C API`.
- `EditorCore` owns the native handle, document lifecycle, edit commands, and render-model retrieval.
- `CoreProtocol` encodes and decodes binary payloads; `EditorRenderer` consumes `EditorRenderModel` and draws through Avalonia `DrawingContext`.
- `SweetEditorControl` is the concrete widget entry. `SweetEditorController` is the external command surface for declarative / MVVM-style host code.
- Decorations, completion, newline action, inline suggestion, and selection menu are split into dedicated Avalonia-side manager/provider modules.
- SweetEditor native assets are centralized in the Avalonia project configuration; demo projects only host the control. SweetLine native assets are supplied by the SweetLine NuGet package.

## Layout

- `SweetEditor/`: Avalonia widget, bridge, rendering, events, provider management
- `Demo.Shared/`: shared UI, sample loading, SweetLine runtime, icon/menu logic
- `Demo.Android/`: Avalonia Android host entry point
- `Demo.Desktop/`: Avalonia desktop host
- `Demo.Mac/` / `Demo.iOS/`: platform-specific demo hosts

## Requirements

### Base

- .NET SDK: `8.0+`
- Avalonia: `11.3.12`
- SweetEditor core native prebuilts:
  - Windows: `prebuilt/windows/x64/sweeteditor.dll`
  - Linux: `prebuilt/linux/x86_64/libsweeteditor.so`
  - macOS: `prebuilt/osx/*/libsweeteditor.dylib`
  - Android: `prebuilt/android/*/libsweeteditor.so`
  - iOS: `prebuilt/ios/*/libsweeteditor.dylib`

### Android extras

- .NET Android workload
- Android SDK (API 34)
- `adb`
- SweetLine native assets are provided by the SweetLine NuGet package.

## Quick Start

### Run the desktop demo inside this repository

```bash
cd platform/Avalonia
dotnet build Avalonia.sln -c Debug
dotnet run --project Demo.Desktop/Demo.Desktop.csproj -c Debug
```

### Build the Android demo inside this repository

```bash
cd platform/Avalonia
dotnet build Demo.Android/Demo.Android.csproj \
  -c Debug \
  -f net8.0-android \
  -p:RuntimeIdentifier=android-arm64
```

Install the signed debug APK manually:

```bash
adb install -r Demo.Android/bin/Debug/net8.0-android/android-arm64/com.qiplat.sweeteditor.avalonia.demo.android-Signed.apk
```

### Integrate into an existing Avalonia app

Recommended in-repo integration is a project reference:

```xml
<ItemGroup>
  <ProjectReference Include="platform/Avalonia/SweetEditor/SweetEditor.csproj" />
</ItemGroup>
```

Minimal example:

```csharp
using SweetEditor;

var controller = new SweetEditorController();
var editor = new SweetEditorControl(controller);
editor.ApplyTheme(EditorTheme.Dark());
editor.LoadDocument(new Document("Hello, SweetEditor!"));
editor.GetSettings().SetWrapMode(WrapMode.WORD_BREAK);
```

## Resources and SweetLine Integration

### Sample code and syntax rules

`Demo.Shared` embeds resources from repository-level `platform/_res`:

- `../../_res/files/*.*` -> `SweetEditor.PlatformRes.files.*`
- `../../_res/syntaxes/*.json` -> `SweetEditor.PlatformRes.syntaxes.*`

Shared demo sample loader:

- `platform/Avalonia/Demo.Shared/DemoSamples.cs`

### SweetLine native path

`Demo.Shared` uses the SweetLine NuGet package through:

- `platform/Avalonia/Demo.Shared/DemoSweetLineRuntime.cs`

Current strategy:

- Android: create `HighlightEngine`, `DocumentAnalyzer`, and `TextAnalyzer`
- Syntax rules: compile embedded `platform/_res/syntaxes/*.json`
- Large documents: prefer visible-range slice / line-level analysis instead of returning the full highlight result to managed code
- Desktop: fall back to managed highlighting if SweetLine native is unavailable

## Public Entry Types

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

## Public Control Layer: `SweetEditorControl`

### Constructors

```csharp
public SweetEditorControl()
public SweetEditorControl(SweetEditorController controller)
```

### Public events

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

Notes:

- `SelectionChangedEventArgs.Selection` may be null
- `DoubleTapEventArgs.Selection` may be null
- mobile hosts emit `LongPress`
- cross-platform / desktop hosts may consume `ContextMenu`

### Document / theme / language / metadata / debug

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

`Flush()` is a force-refresh / diagnostic entrypoint. Normal edit, decoration, scroll, selection, and IME synchronization paths dispatch `EditorActionResult` through the unified result path, and `NeedsRedraw` decides whether to refresh the render model and redraw.

### Providers / completion / ghost / selection menu

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

Notes:

- Completion and selection menu UI are editor-owned in Avalonia. Hosts provide items and listen for custom selection-menu commands through the provider/listener APIs.
- `SetCompletionItemRenderer(...)` customizes completion item views through `ICompletionItemRenderer`.

### Text edit / line operations / clipboard / undo-redo

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

### Cursor / selection / navigation / scroll

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

### Fold / decoration / styles / linked editing

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

## Public Controller Layer: `SweetEditorController`

### Lifecycle

```csharp
public void WhenReady(Action callback)
public void Dispose()
```

### Controller rules

- `SweetEditorController` provides `whenReady(callback)` semantics; if the control is already bound, the callback runs immediately.
- When the control is not bound, command calls are queued and replayed after binding.
- Getters return default / empty values when unbound instead of throwing.
- One controller instance must not be bound to multiple `SweetEditorControl` instances at the same time.

### Public events

The controller exposes the same event set as `SweetEditorControl`.

### Public methods

Except for constructors, `SweetEditorController` mirrors `SweetEditorControl` 1:1, including:

- document / theme / keymap / language configuration / metadata / perf overlay toggles / layout metrics
- providers / completion / inline suggestion / selection menu
- text editing / line operations / clipboard / undo-redo
- cursor / selection / navigation / scroll
- fold / styles / decorations / linked editing
- `Flush()` / `GetVisibleLineRange()` / `GetTotalLineCount()`

The only extra lifecycle surface is `WhenReady(...)` and `Dispose()`.

## Public Settings Layer: `EditorSettings`

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

## Provider and data model notes

### Completion

- `CompletionItem`
- `CompletionContext`
- `CompletionResult`
- `ICompletionProvider`
- `ICompletionReceiver`
- `ICompletionItemRenderer`
- `CompletionTriggerKind`

`CompletionItem.TextEdit` is the only source of replacement range semantics. Without it, completion inserts `InsertText` / `Label` at the cursor; `AdditionalTextEdits` is appended after the primary edit.

`ICompletionItemRenderer` supplies both item height and an Avalonia `Control` for each completion item.

### Decoration

- `DecorationType`
- `DecorationApplyMode`
- `DecorationContext`
- `DecorationResult`
- `IDecorationProvider`
- `IDecorationReceiver`

### New line

- `NewLineAction`
- `NewLineContext`
- `INewLineActionProvider`

### Ghost / selection menu

- `InlineSuggestion`
- `IInlineSuggestionListener`
- `SelectionMenuItem`
- `ISelectionMenuItemProvider`
- `ISelectionMenuListener`

## Android vs desktop

### Android

- `SweetEditorControl` owns `InputPane` occlusion handling and popup repositioning.
- `SweetEditorControl` disables `SupportsSurroundingText` on Android to avoid large-text IME overhead.
- Touch, long-press, double-tap, drag-select, IME avoidance, and selection-menu behavior get extra Avalonia control adaptation on Android.
- Native assets:
  - SweetEditor Android, Windows, and Linux assets are declared by `SweetEditor.csproj`.
  - SweetEditor macOS and iOS app bundle references are injected by `platform/Avalonia/Directory.Build.targets`.
  - SweetLine native assets are provided by the SweetLine NuGet package.

### Desktop

- `Demo.Desktop` and `Demo.Android` share `Demo.Shared/MainView.cs`.
- If SweetLine native is not available on desktop, syntax highlighting falls back to managed implementation.
- Desktop and Android share the same `SweetEditorControl` / `SweetEditorController` / provider API contract.
