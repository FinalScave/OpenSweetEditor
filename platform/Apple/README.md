# SweetEditor Apple SDK

The Apple SDK provides native SweetEditor views for iOS and macOS as a local Swift Package. Its Swift/C bridge uses the shared core packaged in XCFrameworks.

## Requirements

- iOS 13 or newer
- macOS 11 or newer
- Xcode with Swift Package Manager support
- Prebuilt `SweetEditorCore` XCFrameworks, or a local toolchain capable of rebuilding them

## Products

- `SweetEditoriOS`: UIKit and SwiftUI integration
- `SweetEditorMacOS`: AppKit and SwiftUI integration

`SweetEditorCoreInternal`, `SweetEditorBridge`, and the native binary targets are package implementation details and are not published as products.

## Local Package Integration

After checking out the repository, build or verify the native artifacts:

```bash
cd platform/Apple
make native-if-needed
make verify-local
```

Add `platform/Apple` as a local Swift Package in Xcode, then link the product for the target platform.

## Quick Start

### iOS UIKit

```swift
import SweetEditoriOS

let editor = SweetEditorViewiOS(frame: .zero)
editor.applyTheme(isDark: true)
editor.loadDocument(text: "Hello, SweetEditor!")
editor.settings.setWrapMode(.wordBreak)
```

### macOS AppKit

```swift
import SweetEditorMacOS

let editor = SweetEditorViewMacOS(frame: .zero)
editor.applyTheme(isDark: true)
editor.loadDocument(text: "Hello, SweetEditor!")
editor.settings.setWrapMode(.wordBreak)
```

SwiftUI entry points are `SweetEditorSwiftUIViewiOS` and `SweetEditorSwiftUIMacOS`.

## Features

- Native UIKit, AppKit, and SwiftUI views
- Shared editing, selection, folding, scrolling, search, and undo/redo behavior
- Decorations, diagnostics, inlay hints, phantom text, links, code lens, and gutter icons
- Completion and decoration provider extensions
- Typed metadata and selection previews on the native macOS view
- Runtime settings for wrapping, whitespace, line breaks, scale, spacing, and read-only mode
- Fold, decoration, and interaction callbacks

Neither public native view currently exposes a language-configuration setter. The macOS newline-provider methods depend on internal provider types and are not usable as an application extension point. Metadata access is public only on `SweetEditorViewMacOS`; it is not exposed by `SweetEditorViewiOS` or either SwiftUI wrapper.

## Native Artifacts

- `binaries/SweetEditorCoreIOS.xcframework` contains iOS device and simulator slices.
- `binaries/SweetEditorCoreOSX.xcframework` contains the macOS universal slice.
- Each XCFramework contains dynamic `SweetEditorCore.framework` slices.
- Intermediate native builds stay under the repository `build/apple-*` directories.

Raw Apple shared-library builds produce `libsweeteditor.dylib`. Framework packaging is selected independently with `SWEETEDITOR_BUILD_APPLE_FRAMEWORK=ON`; framework binaries are never copied or renamed as raw dylibs.

## Local Commands

- `make all`: native prebuild, Swift build, and Swift tests
- `make native`: rebuild both XCFrameworks
- `make native-if-needed`: rebuild native artifacts only when inputs changed
- `make build`: build Swift Package targets
- `make test`: run Swift tests
- `make verify-local`: validate the package and local build
- `make demo-macos-build`: build the macOS demos
- `make demo-macos-run`: run the AppKit demo
- `make demo-macos-run-swiftui`: run the SwiftUI demo

## Xcode Prebuild

Add this script as an Xcode scheme pre-action when the native artifact should be refreshed automatically:

```bash
cd "$SRCROOT"
./scripts/xcode_prebuild.sh
```

Set `SWEETEDITOR_FORCE_NATIVE=1` to force a one-time rebuild.

## Links

- [Apple API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-apple.md)
- [iOS demo](Examples-iOS/README.md)
- [macOS demos](Examples-MacOS/README.md)
- [Native binary layout](binaries/README.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](../../LICENSE)
