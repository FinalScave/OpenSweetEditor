# SweetEditor macOS Demos

The `platform/Apple/Examples-MacOS` package hosts runnable demo apps for `SweetEditorMacOS`. You can try both the original AppKit sample and a declarative SwiftUI sample side by side.

## Targets

- `SweetEditorMacDemo` – the existing AppKit window controller sample that exercises undo/redo, wrap mode, decorations, etc.
- `SweetEditorMacDemoSwiftUI` – a new declarative SwiftUI experience built with `SweetEditorSwiftUIMacOS`, showing the same controls rendered with SwiftUI widgets.

## Run with Makefile helpers

```bash
cd platform/Apple
make native-if-needed
make demo-macos-run           # AppKit demo
make demo-macos-run-swiftui   # SwiftUI demo
```

## Run manually

```bash
cd platform/Apple
make native-if-needed
cd Examples-MacOS
swift run SweetEditorMacDemo
swift run SweetEditorMacDemoSwiftUI
```

## Open in Xcode

1. Open `platform/Apple/Examples-MacOS/Package.swift` in Xcode.
2. Select either the `SweetEditorMacDemo` (AppKit) or `SweetEditorMacDemoSwiftUI` (SwiftUI) scheme.
3. Run (`⌘R`).

## Recommended runtime configuration style

Prefer the centralized `settings` API for runtime behavior changes:

```swift
let editor = SweetEditorViewMacOS(frame: .zero)
editor.settings.setScale(1.1)
editor.settings.setWrapMode(.wordBreak)
editor.settings.setRenderWhitespace(.boundary)
editor.settings.setRenderLineBreaks(true)
editor.settings.setLineSpacing(add: 1.0, mult: 1.2)
editor.settings.setReadOnly(false)
editor.settings.setMaxGutterIcons(2)
```

Use `applyTheme(_:)` for theme changes and `setLanguageConfiguration(_:)` for language metadata. Legacy setters remain available, but new demo code should prefer `settings`.
