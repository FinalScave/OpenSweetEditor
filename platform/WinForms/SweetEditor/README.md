# SweetEditor for WinForms

[![.NET 8](https://img.shields.io/badge/.NET-8.0-blue.svg)](https://dotnet.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/FinalScave/SweetEditor/blob/main/LICENSE)

A high-performance WinForms code editor control that uses P/Invoke to access the shared [SweetEditor](https://github.com/FinalScave/SweetEditor) C++ core and renders with GDI+.

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
- Ctrl+mouse-wheel zoom and programmatic scaling

## Requirements

- .NET 8+ (`net8.0-windows`)
- Windows x64
- Native runtime `sweeteditor.dll` is bundled in the NuGet package (`runtimes/win-x64/native/`)

## Install

```powershell
dotnet add package SweetEditor --version 1.0.0-rc1
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
        editor.Settings.SetRenderWhitespace(WhitespaceRenderMode.BOUNDARY);
        editor.Settings.SetRenderLineBreaks(true);
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
| `SetWrapMode(WrapMode)` | `NONE` / `CHAR_BREAK` / `WORD_BREAK` |
| `SetRenderWhitespace(WhitespaceRenderMode)` | Invisible whitespace marker mode |
| `SetRenderLineBreaks(bool)` | Show/hide line-break markers |
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

The control publishes text, cursor, selection, scroll, scale, document, gesture, decoration, folding, CodeLens, and link events. See the [API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-winforms.md#events) for the current event list and payload types.

## Text Editing

Text insertion, replacement, deletion, batched edits, line operations, clipboard commands, search and replace, selection, navigation, and undo/redo are exposed by `SweetEditorControl`. See the [API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-winforms.md#text-editing-line-operations-and-clipboard) for signatures.

## Decorations

The editor supports syntax, semantic, and overlay spans; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; fold regions; and indent, bracket, flow, and separator guides. The [API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-winforms.md#styles-decorations-and-folding) is the canonical method list.

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

Snippets, tab stops, and linked-editing navigation are documented in the [API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-winforms.md#snippets-and-linked-editing).

## Build from Source

Run these commands from the repository root:

```powershell
# Build the native C++ shared library
.\scripts\build-release.ps1 -Platform windows

# Build and pack the NuGet package
dotnet build  .\platform\WinForms\SweetEditor\SweetEditor.csproj -c Release
dotnet pack   .\platform\WinForms\SweetEditor\SweetEditor.csproj -c Release
```

Output: `platform/WinForms/SweetEditor/bin/Release/SweetEditor.<version>.nupkg`

## License

[MIT](https://github.com/FinalScave/SweetEditor/blob/main/LICENSE)

## Links

- [WinForms API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-winforms.md)
- [Changelog](https://github.com/FinalScave/SweetEditor/blob/main/platform/WinForms/SweetEditor/CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
