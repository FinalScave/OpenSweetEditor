# SweetEditor iOS Demo

The `platform/Apple/Examples-iOS` project hosts a runnable iOS demo app for `SweetEditorIOS`. It is intended as the fastest way to try the UIKit-backed editor inside a SwiftUI app shell, switch between bundled sample files, and preview theme, wrap mode, and decoration behavior.

## Quick start

1. Open `platform/Apple/Examples-iOS/SweetEditorDemo.xcodeproj` in Xcode.
2. Open the `SweetEditorDemo` scheme.
3. If this is your first run, build the native bridge first from `platform/Apple`:

   ```bash
   bash ./build.sh native-if-needed
   ```

More comvenient commands:

   ```bash
   bash ./build.sh all
   ```

4. Choose an iPhone simulator or a connected iOS device.
5. Run (`⌘R`).

## Targets

- `SweetEditorDemo` – the main iOS demo app. It loads bundled sample files, supports theme switching, cycles wrap mode, and applies demo decorations for supported samples.
- `SweetEditorDemoTests` – unit tests for demo support logic.
- `SweetEditorDemoUITests` – UI-level coverage for the demo app.

## Open in Xcode

1. Open `platform/Apple/Examples-iOS/SweetEditorDemo.xcodeproj`.
2. Select the `SweetEditorDemo` scheme.
3. Pick an iOS simulator or device destination.
4. Run (`⌘R`).

If the native binary needs to be refreshed, run `bash ./build.sh native-if-needed` from `platform/Apple` before launching the app.

## Recommended runtime configuration style

Prefer the centralized `settings` API for runtime behavior changes:

```swift
let editor = SweetEditorViewiOS(frame: .zero)
editor.settings.setEditorTextSize(16)
editor.settings.setWrapMode(.wordBreak)
editor.settings.setRenderWhitespace(.boundary)
editor.settings.setRenderLineBreaks(true)
editor.settings.setFoldArrowMode(.auto)
editor.settings.setCurrentLineRenderMode(.border)
editor.settings.setMaxGutterIcons(1)
editor.settings.setContentStartPadding(8)
```

Use `applyTheme(isDark:)` for theme changes, `loadDocument(text:)` for content updates, and `applyDecorations(_:)` when you want to preview fold regions, diagnostics, inlays, or phantom text in the demo.
