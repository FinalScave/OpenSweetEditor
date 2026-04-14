# Avalonia Platform API

This document maps to the current Avalonia implementation:

- Control layer: `platform/Avalonia/SweetEditor/SweetEditorControl.cs`
- Controller: `platform/Avalonia/SweetEditor/SweetEditorController.cs`
- Bridge layer: `platform/Avalonia/SweetEditor/EditorCore.cs`
- Protocol encode/decode: `platform/Avalonia/SweetEditor/EditorProtocol.cs`
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
- macOS host: `platform/Avalonia/Demo.Mac/*`
- iOS host: `platform/Avalonia/Demo.iOS/*`

## Architecture Notes

- The Avalonia path is `Avalonia UI + C# P/Invoke -> C API`.
- `EditorCore` owns the native handle, document lifecycle, edit commands, and render-model retrieval.
- `EditorProtocol` decodes binary payloads; `EditorRenderer` consumes `EditorRenderModel` and draws through Avalonia `DrawingContext`.
- `SweetEditorControl` is the concrete widget entry. `SweetEditorController` is the external command surface for declarative / MVVM-style host code.
- Decorations, completion, newline action, inline suggestion, and selection menu are split into dedicated Avalonia-side manager/provider modules.
- Demo.Shared references the `SweetLine` NuGet package directly. Linux/macOS dynamic libraries are provided by NuGet RID assets; the Android host stages `libsweetline.asset` into the app-private directory and sets `SWEETLINE_LIB_PATH`.

## Layout

- `SweetEditor/`: Avalonia widget, bridge, rendering, events, provider management
- `Demo.Shared/`: shared UI, sample loading, SweetLine runtime, icon/menu logic
- `Demo.Android/`: Avalonia Android host, IME / InputPane / safe-area integration
- `Demo.Desktop/`: Avalonia desktop host
- `Demo.Mac/`: Avalonia macOS host
- `Demo.iOS/`: Avalonia iOS host

## Requirements

### Base

- .NET SDK: `8.0+`
- Avalonia: `11.3.12`
- OpenSweetEditor core native prebuilts:
  - Windows: `prebuilt/windows/x64/sweeteditor.dll`
  - Linux: `prebuilt/linux/x86_64/libsweeteditor.so`
  - macOS: `prebuilt/osx/*/libsweeteditor.dylib`

### Android extras

- .NET Android workload
- Android SDK (API 34)
- `adb`
- Android demo uses the `SweetLine` NuGet managed API and provides Android-loadable native libraries in the platform layer:
  - `platform/Avalonia/Demo.Android/native/sweetline/arm64-v8a/libsweetline.asset`
  - `platform/Avalonia/Demo.Android/native/sweetline/x86_64/libsweetline.asset`
  - runtime staging sets `SWEETLINE_LIB_PATH`

See `platform/Avalonia/Demo.Android/termux-dotnet-android-build.md` for a fuller Termux / Android toolchain walkthrough.

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

- `platform/Avalonia/Demo.Shared/UI/Samples/EmbeddedSampleRepository.cs`

### SweetLine integration

Demo.Shared references the `SweetLine` NuGet package directly through:

- `platform/Avalonia/Demo.Shared/Decoration/DemoSweetLineRuntime.cs`
- `platform/Avalonia/Demo.Shared/Decoration/DemoDecorationProvider.cs`

Current strategy:

- Shared layer: create NuGet-provided `HighlightEngine`, `DocumentAnalyzer`, and `TextAnalyzer`
- Syntax rules: compile embedded `platform/_res/syntaxes/*.json`
- Large documents: prefer visible-range slice / line-level analysis instead of returning the full highlight result to managed code
- Android: `Demo.Android/MainActivity.cs` stages `libsweetline.asset` and sets `SWEETLINE_LIB_PATH`
- Fallback resolution: if no matching library is found in NuGet bundles, set `SWEETLINE_LIB_PATH` or copy the library to the current working directory
- Stability: Android avoids the native line-range incremental analysis path that can crash and re-primes slice/session state instead

## Public Entry Types

- `SweetEditorControl`
- `SweetEditorController`
- `EditorSettings`
- `EditorTheme`
- `Document`
- `LanguageConfiguration`
- `KeyMap`
- `EditorKeyMap`
- `DecorationContext` / `DecorationResult`
- `CompletionContext` / `CompletionItem` / `CompletionResult`
- `InlineSuggestion`
- `SelectionMenuItem`
- `PerfOverlay` / `MeasurePerfStats` / `PerfStepRecorder`

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
public event EventHandler<CodeLensClickEventArgs>? CodeLensClick
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
public void SetKeyMap(KeyMap map)
public KeyMap GetKeyMap()
public void SetEditorIconProvider(EditorIconProvider? provider)
public void SetLanguageConfiguration(LanguageConfiguration? config)
public LanguageConfiguration? GetLanguageConfiguration()
public void SetMetadata(IEditorMetadata? metadata)
public IEditorMetadata? GetMetadata()
public void SetPerfOverlayEnabled(bool enabled)
public bool IsPerfOverlayEnabled()
public LayoutMetrics GetLayoutMetrics()
public void Flush()
public (int start, int end) GetVisibleLineRange()
public int GetTotalLineCount()
```

`Flush()` commits pending decoration, layout, scroll, selection, and IME state updates and triggers redraw.

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
public void SetSelectionMenuHostManaged(bool hostManaged)
public bool IsSelectionMenuShowing()
```

### Text edit / line operations / clipboard / undo-redo

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
public bool ToggleFoldAt(int line)
public bool FoldAt(int line)
public bool UnfoldAt(int line)
public bool IsLineVisible(int line)
public void FoldAll()
public void UnfoldAll()

public void RegisterTextStyle(uint styleId, int color, int backgroundColor, int fontStyle)
public void RegisterBatchTextStyles(IReadOnlyDictionary<uint, TextStyle> stylesById)
public void SetLineSpans(int line, SpanLayer layer, IList<StyleSpan> spans)
public void SetBatchLineSpans(SpanLayer layer, Dictionary<int, IList<StyleSpan>> spansByLine)
public void ClearLineSpans(int line, SpanLayer layer)

public void SetLineInlayHints(int line, IList<InlayHint> hints)
public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine)
public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms)
public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine)
public void SetLineGutterIcons(int line, IList<GutterIcon> icons)
public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine)
public void SetMaxGutterIcons(int count)
public int GetMaxGutterIcons()
public void SetLineCodeLens(int line, IList<CodeLensItem> items)
public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine)
public void SetLineDiagnostics<TDiagnostic>(int line, IList<TDiagnostic> items) where TDiagnostic : Diagnostic
public void SetBatchLineDiagnostics<TDiagnostic>(Dictionary<int, IList<TDiagnostic>> diagsByLine) where TDiagnostic : Diagnostic
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
public void ClearGuides()
public void ClearDiagnostics()
public void ClearAllDecorations()
public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn)
public void ClearMatchedBrackets()

public TextEditResult InsertSnippet(string snippetTemplate)
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

```csharp
TextChanged / CursorChanged / SelectionChanged / ScrollChanged / ScaleChanged / DocumentLoaded
LongPress / DoubleTap / ContextMenu / InlayHintClick / GutterIconClick / CodeLensClick / FoldToggle
SelectionMenuItemClick / CompletionItemsUpdated / CompletionDismissed
InlineSuggestionAccepted / InlineSuggestionDismissed
```

### Public methods

Except for constructors, `SweetEditorController` mirrors `SweetEditorControl` 1:1, including:

- document / theme / keymap / language configuration / metadata / perf overlay / layout metrics
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

Notes:

- `SetMaxGutterIcons(...)` is exposed both through `EditorSettings` and as a direct control/controller API to stay aligned with the Core API surface.

## Provider and data model notes

### Completion

- `CompletionItem`
- `CompletionContext`
- `CompletionResult`
- `ICompletionProvider`
- `ICompletionReceiver`
- `ICompletionItemRenderer`
- `CompletionTriggerKind`

### Decoration

- `DecorationType`
- `DecorationApplyMode`
- `DecorationContext`
- `DecorationResult`
- `Diagnostic` (canonical diagnostic model)
- `DiagnosticItem` (legacy Avalonia name kept as a compatibility alias)
- `IDecorationProvider`
- `IDecorationReceiver`
- `CodeLensItem`

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

- `Demo.Android/MainActivity.cs` injects `DemoPlatformServices` for safe-area / `InputPane` occlusion handling.
- `SweetEditorControl` disables `SupportsSurroundingText` on Android to avoid large-text IME overhead.
- Touch, long-press, double-tap, drag-select, IME avoidance, and selection-menu behavior get extra Avalonia-host adaptation on Android.
- Android demo packages:
  - `libsweeteditor.so` from `prebuilt/android/*`
  - `libsweetline.asset` from `Demo.Android/native/sweetline/*`, staged as `libsweetline.so` at runtime
- `MainActivity` sets `SWEETLINE_LIB_PATH` before Avalonia initialization. The shared layer only uses the `SweetLine` NuGet API and contains no Android-specific loading logic.

### Desktop

- `Demo.Desktop`, `Demo.Mac`, `Demo.iOS`, and `Demo.Android` share `Demo.Shared/MainView.cs`.
- Linux/macOS SweetLine dynamic libraries are resolved from NuGet RID assets first; if a matching bundle is unavailable, use `SWEETLINE_LIB_PATH` or place the library in the current working directory.
- All hosts share the same `SweetEditorControl` / `SweetEditorController` / provider API contract. Platform differences are isolated behind `IDemoPlatformServices`.

## Demo and Documentation Entry Points

- `platform/Avalonia/README.demo.md`
- `platform/Avalonia/AVALONIA_INTEGRATION_STATUS.md`
- `platform/Avalonia/Demo.Shared/README.md`
- `platform/Avalonia/Demo.Desktop/README.md`
- `platform/Avalonia/Demo.Mac/README.md`
- `platform/Avalonia/Demo.iOS/README.md`
- `platform/Avalonia/Demo.Android/README.md`
- `platform/Avalonia/Demo.Android/termux-dotnet-android-build.md`

## Current Implementation Notes

- Avalonia currently implements the project-standard host API surface for `SweetEditorControl`, `SweetEditorController`, `EditorSettings`, provider management, events, selection menu, inline suggestion, perf overlay, CodeLens, diagnostics, guides, matched brackets, and linked editing.
- `EditorCore.Dispose()` releases the C++ `free_editor` handle exactly once. Direct access after explicit disposal raises `ObjectDisposedException`.
- Android demo uses the `SweetLine` NuGet managed API plus platform-layer native library staging, with no local SweetLine P/Invoke wrapper.
- Remaining work is SHOULD/MAY level: platform-layer tests, provider timeout policy, and systematic accessibility support. The Android APK has been build/install/cold-start smoke tested.
- Host-side IME, touch, selection menu, completion popup, and large-document highlighting have platform compatibility handling. If documentation and code conflict, code is authoritative.
