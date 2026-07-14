# SweetEditor for Flutter

SweetEditor for Flutter is a Dart FFI wrapper and Flutter widget built on the shared SweetEditor native core.

## Installation

```yaml
dependencies:
  sweeteditor:
    path: ../sweeteditor
```

Adjust the path to the checked-out `platform/Flutter/sweeteditor` directory in the consuming workspace.

## Requirements

- Dart SDK `^3.11.4`
- A Flutter SDK compatible with the workspace
- Native prebuilts synchronized into the package before running or packaging

The build hook supports Windows x64, Linux x64/arm64, Android arm64/x64, macOS x64/arm64, and iOS device/simulator arm64.

## Features

- `SweetEditorWidget` and `SweetEditorController`
- Native editing, rendering model, selection, scrolling, folding, and search
- Completion, decorations, inline suggestions, snippets, and selection menus
- Flutter text input, gestures, canvas rendering, and platform behavior adaptation
- Automatic native asset selection through Dart code assets

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:sweeteditor/sweeteditor.dart';

final controller = SweetEditorController();

Widget buildEditor() {
  return SweetEditorWidget(
    controller: controller,
    text: 'Hello, SweetEditor!',
    theme: EditorTheme.dark(),
  );
}
```

`SweetEditorWidget` owns and releases its native editor session. Keep the controller instance stable while the widget is mounted. A `Document` created internally from `text` is released by the widget; a `Document` passed through the widget or `controller.loadDocument(...)` is borrowed and remains the caller's responsibility. Dispose it only after the editor no longer uses it.

## Native Assets

The build hook selects a matching library from `native/<platform>/<architecture>`. Synchronize repository prebuilts into the package with:

```bash
cd platform/Flutter/sweeteditor
dart run tool/sync_native_binaries.dart
```

## Run the Demo

```bash
cd platform/Flutter/demo
flutter pub get
flutter run
```

## Links

- [Flutter API reference](https://github.com/FinalScave/SweetEditor/blob/main/docs/en/api-platform-flutter.md)
- [Changelog](CHANGELOG.md)
- [Repository](https://github.com/FinalScave/SweetEditor)
- [MIT License](LICENSE)
