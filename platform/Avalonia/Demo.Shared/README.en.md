# Demo.Shared

Cross-platform shared demo logic and resource library providing core functionality for all Avalonia Demo projects.

## Project Configuration

| Property | Value |
|----------|-------|
| Target Framework | net8.0 |
| Assembly Name | SweetEditor.Avalonia.Demo.Shared |
| Avalonia Version | 11.3.12 |

## Directory Structure

```
Demo.Shared/
├── MainView.cs                 # Main view, core UI entry point
├── ViewModels/
│   ├── MainViewModel.cs        # MVVM view model
│   └── DemoSettings.cs         # User settings persistence
├── Host/
│   ├── DemoPlatformServices.cs # Platform service abstraction interface
│   └── DeferredMainViewHost.cs # Deferred loading host
├── Decoration/
│   ├── DemoDecorationProvider.cs   # Syntax highlight decoration provider
│   └── DemoSweetLineRuntime.cs     # SweetLine native engine wrapper
├── Editor/
│   ├── DemoCompletionProvider.cs       # Code completion provider
│   ├── DemoSelectionMenuItemProvider.cs # Selection menu item provider
│   ├── DemoNewLineActionProvider.cs    # New line action provider
│   ├── DemoInlineSuggestionListener.cs # Inline suggestion listener
│   ├── DemoIconProvider.cs             # Icon provider
│   └── DemoMetadata.cs                 # Metadata definitions
├── UI/
│   ├── LoadingIndicator.cs     # Loading indicator
│   ├── NotificationPanel.cs    # Notification panel
│   ├── KeyboardShortcutsDialog.cs # Keyboard shortcuts dialog
│   ├── WelcomeOverlayView.cs   # Welcome overlay
│   ├── Toolbar/
│   │   └── EditorToolbarController.cs # Toolbar controller
│   └── Samples/
│       ├── SampleDocumentLoader.cs    # Sample document loader
│       ├── EmbeddedSampleRepository.cs # Embedded sample repository
│       └── DemoSampleFile.cs          # Sample file definition
├── Performance/
│   ├── ObjectPool.cs           # Object pool
│   └── PerformanceBenchmark.cs # Performance benchmark
└── Assets/
    └── Icons/                  # Icon resources
```

## Core Components

### 1. MainView - Main View

The main view is the core UI entry point for the Demo application, responsible for:

- **Editor Initialization**: Creates `SweetEditorControl` and `SweetEditorController`
- **Event Handling**: Document load, text change, cursor movement, selection change, etc.
- **UI Component Management**: Toolbar, status bar, completion popup, selection action bar
- **Theme Switching**: Dark/light theme dynamic switching
- **Zoom Control**: Preset zoom ratios (72% - 120%)

```csharp
public sealed class MainView : UserControl
{
    private readonly SweetEditorController controller = new();
    private SweetEditorControl? editor;
    // ...
}
```

### 2. DemoDecorationProvider - Syntax Highlight Decoration

Implements `IDecorationProvider` interface, providing multiple decoration types:

| Decoration Type | Description |
|-----------------|-------------|
| SyntaxHighlight | Syntax highlighting |
| InlayHint | Inline hints (type inference, color preview) |
| Diagnostic | Diagnostics (TODO, FIXME, line length warnings) |
| FoldRegion | Fold regions |
| IndentGuide | Indent guide lines |
| BracketGuide | Bracket matching lines |
| FlowGuide | Control flow guide lines |
| GutterIcon | Line number icons |
| PhantomText | Phantom text |

**Large Document Optimization**:
- Large document mode auto-enabled for > 12,000 lines or > 900KB
- Asynchronous syntax highlight cache preloading
- Incremental update support

### 3. DemoCompletionProvider - Code Completion

Implements `ICompletionProvider` interface, providing:

- **Trigger Characters**: `.`, `:`, `#`
- **Completion Item Types**: Keywords, functions, classes, snippets
- **Async Completion**: Returns results after 120ms delay

```csharp
public bool IsTriggerCharacter(string ch) =>
    TriggerChars.Contains(ch);
```

### 4. SweetLine - Native Syntax Highlight Engine

Demo.Shared depends on the `SweetLine` NuGet package directly for the high-performance native syntax highlight engine; it no longer maintains local P/Invoke wrapper sources:

**Core Classes**:
- `HighlightEngine`: Highlight engine, compiles syntax rules
- `Document`: Managed document with incremental update support
- `DocumentAnalyzer`: Document analyzer
- `TextAnalyzer`: Plain text analyzer

**Features**:
- JSON syntax definition compilation
- Incremental analysis (re-analyze changed portions only)
- Visible range slice extraction
- Indent guide analysis

```csharp
using var engine = new HighlightEngine();
engine.CompileSyntaxFromJson(syntaxJson);
var analyzer = engine.CreateAnalyzerByName("java");
var highlight = analyzer.AnalyzeText(sourceCode);
```

### 5. DemoPlatformServices - Platform Service Abstraction

Platform difference abstraction interface, implemented by each platform:

```csharp
public interface IDemoPlatformServices : IDisposable
{
    bool IsAndroid { get; }
    bool TryGetImeTopInEditorHostDip(Visual visual, Control editorHost,
        out double imeTopInHostDip);
}
```

**Android Special Handling**:
- IME visible area adaptation
- Large document gesture anchor optimization
- Deferred UI refresh strategy

## Resource References

### Embedded Resources

```xml
<EmbeddedResource Include="../../_res/files/*.*">
  <LogicalName>SweetEditor.PlatformRes.files.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
<EmbeddedResource Include="../../_res/syntaxes/*.json">
  <LogicalName>SweetEditor.PlatformRes.syntaxes.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
```

### SweetLine Native Library

Demo.Shared references the `SweetLine` NuGet package directly. It no longer manually copies desktop native libraries and no longer maintains a local P/Invoke wrapper.

- Linux/macOS dynamic libraries are provided by the NuGet package RID assets.
- If runtime resolution cannot find the matching library in package bundles, set `SWEETLINE_LIB_PATH` to the library path or copy the library to the current working directory.
- Android Demo stages `libsweetline.asset` into the app private directory and sets `SWEETLINE_LIB_PATH` in the platform layer, keeping Android-specific loading outside the shared layer.

## MVVM Architecture

`MainViewModel` implements `INotifyPropertyChanged`, providing:

- **State Management**: Loading state, document state, undo/redo capability
- **Settings Persistence**: Theme, zoom, wrap mode auto-save
- **Data Binding**: Sample list, cursor position, zoom ratio

```csharp
public sealed class MainViewModel : INotifyPropertyChanged, IDisposable
{
    public bool DarkTheme { get; set; }
    public WrapMode WrapMode { get; set; }
    public float CurrentScale { get; set; }
    // ...
}
```

## Performance Optimization

### Object Pool

Object reuse pool to reduce GC pressure:

```csharp
public class ObjectPool<T> where T : class, new()
{
    public T Rent();
    public void Return(T obj);
}
```

### Deferred Refresh Strategy

UI updates are merged via `DeferredChromeWork` flags:

```csharp
[Flags]
private enum DeferredChromeWork
{
    None = 0,
    Summary = 1 << 0,
    CompletionPopup = 1 << 1,
    SelectionActionBar = 1 << 2,
    CursorVisibility = 1 << 3,
    SamplePickerPopup = 1 << 4,
}
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| F1 | Trigger code completion |
| F2 | Show inline suggestion |
| F3 | Insert snippet |
| Ctrl+K, Ctrl+D | Trigger completion (custom mapping) |
| Escape | Close popup |

## Extension Points

### Custom Decoration Provider

Implement `IDecorationProvider` interface:

```csharp
public interface IDecorationProvider
{
    DecorationType Capabilities { get; }
    void PrimeDocument(string fileName, string content);
    void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver);
}
```

### Custom Completion Provider

Implement `ICompletionProvider` interface:

```csharp
public interface ICompletionProvider
{
    bool IsTriggerCharacter(string ch);
    void ProvideCompletions(CompletionContext context, ICompletionReceiver receiver);
}
```
