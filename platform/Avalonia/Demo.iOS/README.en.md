# Demo.iOS

iOS Avalonia demo project.

## Requirements

- .NET 8.0 SDK
- .NET iOS workload
- Xcode 15+ (macOS)
- Apple Developer Account (device debugging)

## Project Configuration

| Property | Value |
|----------|-------|
| Target Framework | net8.0-ios |
| Minimum iOS Version | 13.0 |
| Application ID | com.qiplat.sweeteditor.avalonia.demo.ios |
| Runtime Identifier | ios-arm64 |

## Quick Start

### Install workload

```bash
dotnet workload install ios
```

### Build

```bash
cd platform/Avalonia
dotnet build Demo.iOS -c Debug -f net8.0-ios
```

### Run on Simulator

```bash
dotnet run --project Demo.iOS -f net8.0-ios -p:RuntimeIdentifier=iossimulator-arm64
```

### Deploy to Device

```bash
dotnet build Demo.iOS -c Release -f net8.0-ios -p:RuntimeIdentifier=ios-arm64
```

## Native Library Dependencies

The project references native libraries from `prebuilt/ios/` directory:

| Architecture | Library Files |
|--------------|---------------|
| arm64 (device) | `libsweeteditor.dylib`, `libsweetline.dylib` |
| simulator-arm64 | `libsweeteditor.dylib`, `libsweetline.dylib` |

## Architecture

- Shares `Demo.Shared` demo logic with other platforms
- Uses Avalonia.iOS package for iOS support
- References native libraries via NativeReference

## Notes

- Device deployment requires valid developer certificate
- Simulator uses `iossimulator-arm64` runtime identifier
- Debug configuration disables linker (MtouchLink=None)
