# SweetEditor for WinForms

[![NuGet](https://img.shields.io/nuget/v/SweetEditor.svg)](https://www.nuget.org/packages/SweetEditor)
[![.NET 8](https://img.shields.io/badge/.NET-8.0-blue.svg)](https://dotnet.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/FinalScave/SweetEditor/blob/main/LICENSE)

A high-performance WinForms code editor control powered by the [SweetEditor](https://github.com/FinalScave/SweetEditor) C++ core.

The C++ core handles text layout, cursor/selection logic, folding, decoration data, and interaction math; the WinForms layer provides native GDI+ rendering and input dispatch.

## Features

- Syntax and semantic highlighting via style spans
- Inlay hints and ghost text
- Diagnostics and custom decorations
- Gutter icons and fold markers
- Code folding and word-wrap modes
- Current-line rendering modes (background / border)
- Indent guides, bracket guides, flow guides
- Linked editing (multi-cursor rename)
- Undo / Redo
- IME composition support
- Completion, decoration, and newline action provider extensions
- Monospace and proportional font support
- Pinch-to-zoom scaling

## Requirements

- .NET 8+ (`net8.0-windows`)
- Windows x64
- Native runtime `sweeteditor.dll` is bundled in the NuGet package (`runtimes/win-x64/native/`)

## Install

```
dotnet add package SweetEditor
```

## Quick Start

```csharp
using SweetEditor;

public sealed class MainForm : Form {
    private readonly SweetEditorControl editor = new() { Dock = DockStyle.Fill };

    public MainForm() {
        Controls.Add(editor);

        // Theme
        editor.ApplyTheme(EditorTheme.Dark());

        // Settings
        editor.Settings.SetEditorTextSize(14f);
        editor.Settings.SetFontFamily("Cascadia Code");
        editor.Settings.SetWrapMode(WrapMode.WORD_BREAK);
        editor.Settings.SetCurrentLineRenderMode(CurrentLineRenderMode.BORDER);

        // Load content
        editor.LoadDocument(new Document("int main() {\n    return 0;\n}\n"));
    }
}
```

## Settings

All settings are available via `editor.Settings` and take effect immediately.

| Method | Description |
|--------|-------------|
| `SetEditorTextSize(float)` | Base text size in points |
| `SetFontFamily(string)` | Font family name |
| `SetScale(float)` | Editor scale factor |
| `SetWrapMode(WrapMode)` | `NONE` / `WORD_BREAK` |
| `SetLineSpacing(float add, float mult)` | Line spacing |
| `SetFoldArrowMode(FoldArrowMode)` | Fold arrow visibility |
| `SetGutterVisible(bool)` | Show/hide gutter |
| `SetGutterSticky(bool)` | Gutter sticks during horizontal scroll |
| `SetShowSplitLine(bool)` | Gutter split line |
| `SetContentStartPadding(float)` | Extra padding after gutter |
| `SetCurrentLineRenderMode(...)` | `NONE` / `BACKGROUND` / `BORDER` |
| `SetAutoIndentMode(AutoIndentMode)` | `NONE` / `KEEP_INDENT` |
| `SetBackspaceUnindent(bool)` | Smart backspace unindent |
| `SetReadOnly(bool)` | Read-only mode |
| `SetMaxGutterIcons(int)` | Max gutter icon columns |

## Theme and Styles

```csharp
var theme = EditorTheme.Dark()
    .DefineTextStyle(EditorTheme.STYLE_KEYWORD,
        new TextStyle(unchecked((int)0xFF7AA2F7), SweetEditorControl.FONT_STYLE_BOLD));

editor.ApplyTheme(theme);
```

## Events

```csharp
editor.TextChanged      += (s, e) => { /* e.Action, e.Changes */ };
editor.CursorChanged    += (s, e) => { /* e.CursorPosition */ };
editor.SelectionChanged += (s, e) => { /* selection info */ };
editor.ScrollChanged    += (s, e) => { /* scroll info */ };
editor.ScaleChanged     += (s, e) => { /* new scale */ };
editor.DocumentLoaded   += (s, e) => { /* document ready */ };
editor.FoldToggle       += (s, e) => { /* e.LocationInEditor */ };
editor.ContextMenu      += (s, e) => { /* e.LocationInEditor */ };
```

## Text Editing

```csharp
editor.InsertText("Hello");
editor.ReplaceText(new TextRange(new TextPosition(0, 0), new TextPosition(0, 5)), "Hi");
editor.DeleteText(range);
editor.SelectAll();
editor.SetSelection(0, 0, 0, 5);
editor.Undo();
editor.Redo();
```

## Decorations

```csharp
// Syntax spans
editor.SetLineSpans(line, SpanLayer.SYNTAX, spans);
editor.SetBatchLineSpans(SpanLayer.SYNTAX, spansByLine);
editor.ClearLineSpans(line, SpanLayer.SYNTAX);

// Diagnostics
editor.SetLineDiagnostics(line, diagnostics);
editor.SetBatchLineDiagnostics(diagsByLine);

// Inlay hints, ghost text, gutter icons
editor.SetLineInlayHints(line, hints);
editor.SetLinePhantomTexts(line, phantoms);
editor.SetLineGutterIcons(line, icons);

// Guides
editor.SetIndentGuides(guides);
editor.SetBracketGuides(guides);
editor.SetFoldRegions(regions);
```

## Extension Points

| Interface | Purpose |
|-----------|---------|
| `IDecorationProvider` | Provide decorations (spans, diagnostics, hints, etc.) for visible ranges |
| `ICompletionProvider` | Provide code completion items |
| `INewLineActionProvider` | Custom actions on Enter key (e.g., auto-close brackets) |
| `ICompletionItemRenderer` | Custom rendering for completion popup items |
| `EditorIconProvider` | Custom icon rendering in gutter |

```csharp
editor.AddDecorationProvider(myProvider);
editor.AddCompletionProvider(myCompletionProvider);
editor.AddNewLineActionProvider(myNewLineProvider);
```

## Linked Editing

```csharp
editor.StartLinkedEditing(model);
editor.LinkedEditingNext();
editor.LinkedEditingPrev();
editor.CancelLinkedEditing();
```

## Build from Source

```powershell
# 1. Build the native C++ shared library
.\scripts\build-shared.ps1 -Platform windows

# 2. Build and pack
dotnet build  .\platform\WinForms\SweetEditor\SweetEditor.csproj -c Release
dotnet pack   .\platform\WinForms\SweetEditor\SweetEditor.csproj -c Release
```

Output: `platform/WinForms/SweetEditor/bin/Release/SweetEditor.<version>.nupkg`

## Publish

```powershell
dotnet nuget push .\platform\WinForms\SweetEditor\bin\Release\SweetEditor.<version>.nupkg `
    --api-key <NUGET_API_KEY> `
    --source https://api.nuget.org/v3/index.json
```

## License

[MIT](https://github.com/FinalScave/SweetEditor/blob/main/LICENSE)
