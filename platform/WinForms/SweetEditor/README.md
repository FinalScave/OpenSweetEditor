# SweetEditor for WinForms

`SweetEditor` is a WinForms editor control backed by the SweetEditor C++ core.
The core handles text layout, cursor/selection logic, folding, decoration data, and interaction math; WinForms handles native rendering and input dispatch.

GitHub:
- Main repository: [https://github.com/FinalScave/OpenSweetEditor](https://github.com/FinalScave/OpenSweetEditor)
- WinForms package source: `platform/WinForms/SweetEditor`

## Features

- Syntax/semantic style spans
- Inlay hints and ghost text
- Diagnostics and custom decorations
- Gutter icons and fold markers
- Code folding and wrap mode switching
- Current-line rendering modes
- Completion and newline extension providers
- Monospace and proportional font support

## Requirements

- .NET 8 (`net8.0-windows`)
- Windows x64
- Native runtime: `sweeteditor.dll` (included in NuGet package under `runtimes/win-x64/native/`)

## Install

```powershell
dotnet add package SweetEditor
```

## Quick Start

```csharp
using System.IO;
using System.Windows.Forms;
using SweetEditor;

public sealed class MainForm : Form
{
    private readonly SweetEditorControl editor = new SweetEditorControl { Dock = DockStyle.Fill };

    public MainForm()
    {
        Controls.Add(editor);

        editor.ApplyTheme(EditorTheme.Dark());
        editor.Settings.SetWrapMode(WrapMode.WORD_BREAK);
        editor.Settings.SetCurrentLineRenderMode(CurrentLineRenderMode.BORDER);

        var code = "int main() {\n    return 0;\n}\n";
        editor.LoadDocument(new Document(code));

        // Load another file later:
        // editor.LoadDocument(new Document(File.ReadAllText(\"sample.cpp\")));
    }
}
```

## Common API

```csharp
editor.InsertText("Hello");
editor.ReplaceText(new TextRange(new TextPosition(0, 0), new TextPosition(0, 5)), "Hi");
editor.SelectAll();
editor.SetSelection(0, 0, 0, 2);
editor.ScrollToLine(100);
editor.ToggleFold(42);
editor.TriggerCompletion();
```

## Theme and Style Registration

```csharp
var theme = EditorTheme.Dark()
    .DefineTextStyle(EditorTheme.STYLE_KEYWORD, new TextStyle(unchecked((int)0xFF7AA2F7), SweetEditorControl.FONT_STYLE_BOLD));
editor.ApplyTheme(theme);
```

## Extension Points

- Decoration providers: `IDecorationProvider`
- Completion providers: `ICompletionProvider`
- Newline action providers: `INewLineActionProvider`
- Icon rendering: `EditorIconProvider`

## Build and Pack

From repository root:

```powershell
dotnet build .\platform\WinForms\SweetEditor\SweetEditor.csproj -c Release
dotnet pack .\platform\WinForms\SweetEditor\SweetEditor.csproj -c Release
```

Output package:
- `platform/WinForms/SweetEditor/bin/Release/SweetEditor.<version>.nupkg`

## Publish to NuGet

```powershell
dotnet nuget push .\platform\WinForms\SweetEditor\bin\Release\SweetEditor.<version>.nupkg `
  --api-key <NUGET_API_KEY> `
  --source https://api.nuget.org/v3/index.json
```
