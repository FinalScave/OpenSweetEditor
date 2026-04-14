# Avalonia Demo Projects

## Project Structure

```
platform/Avalonia/
├── SweetEditor/          # Core control library
├── Demo.Shared/          # Shared demo logic and resources
├── Demo.Desktop/         # Desktop demo (Windows/Linux/macOS)
├── Demo.Android/         # Android demo
├── Demo.iOS/             # iOS demo
└── Demo.Mac/             # macOS native demo
```

## Platform Support

| Platform | Project | Target Framework | Status |
|----------|---------|------------------|--------|
| Windows | Demo.Desktop | net8.0 | ✅ Supported |
| Linux | Demo.Desktop | net8.0 | ✅ Supported |
| macOS | Demo.Desktop | net8.0 | ✅ Supported |
| Android | Demo.Android | net8.0-android | ✅ Supported |
| iOS | Demo.iOS | net8.0-ios | ✅ Supported |
| macOS (Native) | Demo.Mac | net8.0-macos | ✅ Supported |

## Quick Start

### Desktop

```bash
cd platform/Avalonia
dotnet run --project Demo.Desktop
```

### Android

```bash
cd platform/Avalonia
dotnet build Demo.Android/Demo.Android.csproj -c Debug -f net8.0-android -p:RuntimeIdentifier=android-arm64
```

In Termux, prefer the full template in [Demo.Android/termux-dotnet-android-build.en.md](./Demo.Android/termux-dotnet-android-build.en.md), which explicitly sets Android SDK, `aapt2`, `zipalign`, and `UseInterpreter=true`.

### iOS

```bash
cd platform/Avalonia
dotnet build Demo.iOS -c Release -f net8.0-ios
```

## Resource References

Demo.Shared directly references shared resources from `platform/_res/` directory via csproj:

```xml
<EmbeddedResource Include="../../_res/files/*.*">
  <LogicalName>SweetEditor.PlatformRes.files.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
<EmbeddedResource Include="../../_res/syntaxes/*.json">
  <LogicalName>SweetEditor.PlatformRes.syntaxes.%(Filename)%(Extension)</LogicalName>
</EmbeddedResource>
```

## Native Library Dependencies

The Avalonia control library still uses the repository `prebuilt/` `sweeteditor` core native libraries to bridge to C++ Core. Demo.Shared depends on the `SweetLine` NuGet package directly and no longer maintains a local SweetLine P/Invoke wrapper.

| Component | Resolution Strategy |
|-----------|---------------------|
| `sweeteditor` core | Platform hosts reference repository `prebuilt/*/sweeteditor` native libraries through existing project configuration |
| `SweetLine` Linux/macOS | Dynamic libraries are provided by `SweetLine` NuGet RID assets |
| `SweetLine` Android | `Demo.Android` stages `libsweetline.asset` into the app-private directory and sets `SWEETLINE_LIB_PATH` |
| `SweetLine` fallback | If no matching bundle is available, set `SWEETLINE_LIB_PATH` or copy the library to the current working directory |

## Design Goals

- Unified entry through `SweetEditorControl` / `SweetEditorController`
- Coverage: decorations / diagnostics / CodeLens / completion / inline suggestion / snippet / selection menu / new line action / perf overlay / keymap / large document switching
- Platform differences isolated to platform service layer only

## Integration Status

Current completeness, verification commands, and remaining SHOULD/MAY items are tracked in [AVALONIA_INTEGRATION_STATUS.md](./AVALONIA_INTEGRATION_STATUS.md).

## Performance Optimization

Demo includes the following performance optimization components:

- **LruCache**: LRU cache implementation
- **FrameRateMonitor**: Real-time frame rate monitoring
- **GlyphRunCache**: Glyph run caching optimization
- **RenderOptimizer**: Dirty region rendering optimization
- **RenderBufferPool**: Array pooling to reduce GC pressure

See [PERFORMANCE_OPTIMIZATION_REPORT.md](./PERFORMANCE_OPTIMIZATION_REPORT.md) for details.
