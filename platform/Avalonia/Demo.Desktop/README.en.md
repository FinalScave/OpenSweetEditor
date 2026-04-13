# Demo.Desktop

Desktop Avalonia demo project supporting Windows, Linux, and macOS.

## Requirements

- .NET 8.0 SDK
- Avalonia 11.3.12

## Project Configuration

| Property | Value |
|----------|-------|
| Target Framework | net8.0 |
| Output Type | WinExe |
| Assembly Name | SweetEditor.Avalonia.Demo.Desktop |

## Quick Start

### Build

```bash
cd platform/Avalonia
dotnet build Demo.Desktop
```

### Run

```bash
dotnet run --project Demo.Desktop
```

### Publish

```bash
# Windows
dotnet publish Demo.Desktop -c Release -r win-x64 --self-contained

# Linux
dotnet publish Demo.Desktop -c Release -r linux-x64 --self-contained

# macOS
dotnet publish Demo.Desktop -c Release -r osx-arm64 --self-contained
```

## Native Library Dependencies

The project references native libraries from `prebuilt/` directory:

| Platform | Library File |
|----------|--------------|
| Windows x64 | `sweeteditor.dll` |
| Linux x86_64 | `libsweeteditor.so` |
| macOS x86_64 | `libsweeteditor.dylib` |
| macOS arm64 | `libsweeteditor.dylib` |

## Architecture

- Shares `Demo.Shared` demo logic with other platforms
- Uses Avalonia.Desktop package for cross-platform desktop support
- Native libraries are automatically copied to output directory
