# SweetEditor for Avalonia

SweetEditor for Avalonia is a source-integrated Avalonia control backed by the SweetEditor C API through C# P/Invoke.

## Integration

Install the Avalonia package:

```powershell
dotnet add package SweetEditor.Avalonia --version 1.0.0-rc1
```

The package supplies the managed control and native assets for supported platforms. Repository demos use `ProjectReference` for source development and configure their local prebuilt assets in each host project.

## Requirements

- .NET SDK 10
- Avalonia 12.0.5
- The platform workload required by the selected demo target
- SweetEditor native assets support iOS 14 or newer and macOS 11 or newer; the Avalonia iOS demo targets iOS 15
- Source-based repository demo builds require matching native libraries under the repository `prebuilt` directory

The repository includes configured hosts for Windows, Linux, macOS, Android, and iOS.

## Features

- `SweetEditorControl` for direct UI integration
- `SweetEditorController` for external and MVVM-style command handling
- Native rendering model, editing, selection, folding, and scrolling
- Completion, decorations, inline suggestions, selection menus, and provider extensions
- Shared desktop and mobile demo code

## Quick Start

Add the package reference:

```xml
<ItemGroup>
  <PackageReference Include="SweetEditor.Avalonia" Version="1.0.0-rc1" />
</ItemGroup>
```

Create the editor:

```csharp
using SweetEditor;

var controller = new SweetEditorController();
var editor = new SweetEditorControl(controller);
editor.ApplyTheme(EditorTheme.Dark());
editor.LoadDocument(new Document("Hello, SweetEditor!"));
editor.GetSettings().SetWrapMode(WrapMode.WORD_BREAK);
```

## Build and Run

```powershell
cd platform/Avalonia
dotnet build Avalonia.sln -c Debug
dotnet run --project Demo.Desktop/Demo.Desktop.csproj -c Debug
```

Build the Android host with its current target framework:

```powershell
dotnet build Demo.Android/Demo.Android.csproj -c Debug -f net10.0-android36.0 -p:RuntimeIdentifier=android-arm64
```

## Native Libraries

- NuGet consumers receive Windows x64, Linux x64/arm64, macOS x64/arm64, and Android arm64/x64 assets from runtime-specific package folders.
- NuGet iOS consumers receive a `NativeReference` to `SweetEditorCoreIOS.xcframework` through the package's `buildTransitive` target. Set `SweetEditorDisableIosNativeReference=true` when the host provides the native reference itself.
- Repository demos use local prebuilts directly because `ProjectReference` does not consume NuGet runtime assets or `buildTransitive` targets. Each host project contains its own native-library configuration.

Use `scripts/build-release.ps1` for Windows, Android, OHOS, WASM, and Linux through WSL. Use `scripts/build-release.sh` on an appropriate host for macOS and iOS prebuilts.

## Links

- [Avalonia API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-avalonia.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](../../../LICENSE)
