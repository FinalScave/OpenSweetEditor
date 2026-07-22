# SweetEditor macOS Demos

The `platform/Apple/Demo-macOS` package hosts runnable demo apps for `SweetEditorMacOS`. You can try both the original AppKit sample and a declarative SwiftUI sample side by side.

## Targets

- `SweetEditorMacDemo` – the AppKit sample that exercises undo/redo, wrap mode, and SweetLine-powered syntax highlighting, indent guides, and rainbow brackets.
- `SweetEditorMacDemoSwiftUI` – a declarative SwiftUI experience built with `SweetEditor`, showing the same controls rendered with SwiftUI widgets.

## Run with the Apple build script

```bash
cd platform/Apple
bash ./build.sh native-if-needed
bash ./build.sh demo-macos-run
bash ./build.sh demo-macos-run-swiftui
```

## Run manually

```bash
cd platform/Apple
bash ./build.sh native-if-needed
cd Demo-macOS
swift run SweetEditorMacDemo
swift run SweetEditorMacDemoSwiftUI
```

## Open in Xcode

1. Open `platform/Apple/Demo-macOS/Package.swift` in Xcode.
2. Select either the `SweetEditorMacDemo` (AppKit) or `SweetEditorMacDemoSwiftUI` (SwiftUI) scheme.
3. Run (`⌘R`).

## Recommended runtime configuration style

Prefer the centralized `settings` API for runtime behavior changes:

```swift
let editor = SweetEditorView(frame: .zero)
editor.settings.setScale(1.1)
editor.settings.setWrapMode(.wordBreak)
editor.settings.setRenderWhitespace(.boundary)
editor.settings.setRenderLineBreaks(true)
editor.settings.setLineSpacing(add: 1.0, mult: 1.2)
editor.settings.setReadOnly(false)
editor.settings.setMaxGutterIcons(2)
```

Use `applyTheme(_:)` for theme changes and `setLanguageConfiguration(_:)` for language metadata.
