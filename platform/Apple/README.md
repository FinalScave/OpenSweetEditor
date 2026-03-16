# SweetEditor Apple SDK

This directory is the Apple SPM workspace root.

## Published products

- `SweetEditoriOS`
- `SweetEditorMacOS`

`SweetEditorCore` is an internal target and is not published as a product.

## Local commands

- `make all` runs native prebuild + `swift build` + `swift test`
- `make native` builds `binaries/SweetNativeCore.xcframework`
- `make native-if-needed` only rebuilds native when inputs changed
- `make build` builds SPM targets
- `make test` runs SPM tests
- `make verify-local` checks manifest and builds
- `make demo-macos-build` builds the macOS demo apps
- `make demo-macos-run` runs the AppKit macOS demo app
- `make demo-macos-run-swiftui` runs the SwiftUI macOS demo app

## Xcode one-click setup

1. Open `platform/Apple/Package.swift` in Xcode.
2. Edit active Scheme -> Build -> Pre-actions.
3. Add script:

```bash
cd "$SRCROOT"
./scripts/xcode_prebuild.sh
```

Optional: force native rebuild once by setting env var in pre-action:

```bash
export SWEETEDITOR_FORCE_NATIVE=1
```

## Fold toggle callback

Apple views now expose a fold toggle callback for both gutter-arrow clicks and folded-placeholder clicks.

- Event type: `SweetEditorFoldToggleEvent`
- Fields: `line`, `isGutter`, `locationInView`
- `line` is 0-based logical line index

### macOS AppKit

```swift
let editor = SweetEditorViewMacOS(frame: .zero)
editor.showsPerformanceOverlay = true
editor.onFoldToggle = { event in
    print("fold toggled at line: \(event.line), gutter: \(event.isGutter)")
}
```

### iOS UIKit

```swift
let editor = SweetEditorViewiOS(frame: .zero)
editor.onFoldToggle = { event in
    print("fold toggled at line: \(event.line), gutter: \(event.isGutter)")
}
```

### SwiftUI

```swift
SweetEditorSwiftUIMacOS(
    isDarkTheme: false,
    showsPerformanceOverlay: true,
    onFoldToggle: { event in
        print(event.line)
    }
)

SweetEditorSwiftUIViewiOS(
    isDarkTheme: false,
    onFoldToggle: { event in
        print(event.line)
    }
)
```
