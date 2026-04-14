# Demo.Android

Android Avalonia demo project.

## Requirements

- .NET 8.0 SDK
- .NET Android workload
- Android SDK (API 21+)
- Java 11+

## Project Configuration

| Property | Value |
|----------|-------|
| Target Framework | net8.0-android |
| Minimum Android Version | API 21 |
| Application ID | com.qiplat.sweeteditor.avalonia.demo.android |

## Quick Start

### Install workload

```bash
dotnet workload install android
```

### Build

```bash
cd platform/Avalonia
dotnet build Demo.Android/Demo.Android.csproj -c Debug -f net8.0-android -p:RuntimeIdentifier=android-arm64
```

### Run

```bash
adb install -r Demo.Android/bin/Debug/net8.0-android/android-arm64/com.qiplat.sweeteditor.avalonia.demo.android-Signed.apk
adb shell am start -W -n com.qiplat.sweeteditor.avalonia.demo.android/crc6458426131d5b6d3ae.MainActivity
```

## Native Library Dependencies

The project references `libsweeteditor.so` from repository `prebuilt/android/`. SweetLine uses the managed API from the `SweetLine` NuGet package, while the Android platform layer provides an Android-loadable native library:

| Architecture | SweetEditor Core | SweetLine Staging Asset |
|--------------|------------------|-------------------------|
| arm64-v8a | `libsweeteditor.so` | `native/sweetline/arm64-v8a/libsweetline.asset` |
| x86_64 | `libsweeteditor.so` | `native/sweetline/x86_64/libsweetline.asset` |

At startup, `MainActivity` copies `libsweetline.asset` to the app-private directory and sets `SWEETLINE_LIB_PATH` before Avalonia initialization. If future NuGet bundles cover Android directly, the staging asset can be removed while keeping shared-layer NuGet calls unchanged.

## Architecture

- Shares `Demo.Shared` demo logic with desktop
- Injects Android IME visible area adaptation via `DemoPlatformServices`
- Keeps SweetLine loading, IME visible area handling, and Android lifecycle diagnostics in the platform layer; the rest of the demo logic stays in `Demo.Shared`
- Platform differences isolated to platform service layer

## Termux Build

For building in Termux environment, see [termux-dotnet-android-build.en.md](./termux-dotnet-android-build.en.md).
