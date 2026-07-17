# SweetEditor for Avalonia

SweetEditor for Avalonia is a source-integrated Avalonia control backed by the SweetEditor C API through C# P/Invoke.

## Integration

Add the Avalonia project through `ProjectReference`. The project reference supplies the managed control, while native asset wiring remains the responsibility of the host platform project.

## Requirements

- .NET SDK 10
- Avalonia 12.0.5
- The platform workload required by the selected demo target
- SweetEditor native assets support iOS 14 or newer and macOS 11 or newer; the Avalonia iOS demo targets iOS 15
- A matching native SweetEditor library under the repository `prebuilt` directory

The repository includes configured hosts for Windows, Linux, macOS, Android, and iOS. External hosts must reproduce the mobile native-library items described below.

## Features

- `SweetEditorControl` for direct UI integration
- `SweetEditorController` for external and MVVM-style command handling
- Native rendering model, editing, selection, folding, and scrolling
- Completion, decorations, inline suggestions, selection menus, and provider extensions
- Shared desktop and mobile demo code

## Quick Start

Add a project reference, adjusting the relative path for the host project:

```xml
<ItemGroup>
  <ProjectReference Include="platform/Avalonia/SweetEditor/SweetEditor.csproj" />
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

- `SweetEditor.csproj` copies matching Windows x64, Linux x64, and macOS x64/arm64 libraries for desktop builds.
- The repository [Android demo project](../Demo.Android/Demo.Android.csproj) adds `AndroidNativeLibrary` items for `arm64-v8a` and `x86_64`. An external Android host must add equivalent items; they are not supplied transitively by `ProjectReference`.
- The repository [Directory.Build.targets](../Directory.Build.targets) adds macOS and iOS `NativeReference` items only to executable projects below `platform/Avalonia`. It extracts `SweetEditorCoreIOS.xcframework.zip` into the intermediate output directory and references the extracted XCFramework, allowing .NET to select the device or simulator framework slice. An external iOS host must add an equivalent XCFramework `NativeReference`.

Use `scripts/build-release.ps1` for Windows, Android, OHOS, WASM, and Linux through WSL. Use `scripts/build-release.sh` on an appropriate host for macOS and iOS prebuilts.

## Links

- [Avalonia API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-avalonia.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](../../../LICENSE)
