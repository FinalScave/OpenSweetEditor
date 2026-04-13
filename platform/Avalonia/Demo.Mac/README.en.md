# Demo.Mac

macOS native Avalonia demo project.

## Requirements

- .NET 8.0 SDK
- .NET macOS workload
- macOS 10.15+

## Project Configuration

| Property | Value |
|----------|-------|
| Target Framework | net8.0-macos |
| Minimum macOS Version | 10.15 |
| Application ID | com.qiplat.sweeteditor.avalonia.demo.mac |
| Runtime Identifier | osx-arm64 |

## Quick Start

### Install workload

```bash
dotnet workload install macos
```

### Build

```bash
cd platform/Avalonia
dotnet build Demo.Mac -c Debug -f net8.0-macos
```

### Run

```bash
dotnet run --project Demo.Mac -f net8.0-macos
```

### Publish

```bash
# arm64 (Apple Silicon)
dotnet publish Demo.Mac -c Release -r osx-arm64 --self-contained

# x86_64 (Intel)
dotnet publish Demo.Mac -c Release -r osx-x64 --self-contained
```

## Native Library Dependencies

The project references native libraries from `prebuilt/osx/` directory:

| Architecture | Library Files |
|--------------|---------------|
| arm64 | `libsweeteditor.dylib`, `libsweetline.dylib` |
| x86_64 | `libsweeteditor.dylib`, `libsweetline.dylib` |

## Architecture

- Shares `Demo.Shared` demo logic with other platforms
- Uses Avalonia.Desktop package for macOS support
- Native libraries are automatically copied to output directory

## Notes

- Project is configured for SelfContained mode
- Supports both Apple Silicon (arm64) and Intel (x86_64) architectures
