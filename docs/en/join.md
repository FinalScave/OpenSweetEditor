# Contributing

This document gives practical development entry points based on the current repository structure. If docs conflict with code, use the code.

## Suggested Reading Order

1. `docs/en/architecture.md`
2. `docs/en/api-editor-core.md`
3. `docs/en/platform-implementation-standard.md`
4. `include/sweeteditor/*.h`
5. `src/*.cpp`
6. Read `platform/*` last
7. `docs/en/guide-adding-decoration-type.md` — step-by-step guide for adding a new decoration type

## Repository Map

```text
├── 3dparty
│   ├── simdutf / json / utfcpp      third-party dependencies
├── docs
│   ├── zh/architecture.md           architecture overview (ZH)
│   ├── zh/api-editor-core.md        C API / core contract (ZH)
│   ├── zh/api-platform*.md          integration API docs (ZH)
│   ├── en/architecture.md           architecture overview (EN)
│   ├── en/api-editor-core.md        C API / core contract (EN)
│   └── en/api-platform*.md          integration API docs (EN)
├── include/sweeteditor              core headers and c_api.h
├── src                              Document / Layout / Decoration / EditorCore / c_api implementations
├── tests                            core regression tests
├── platform
│   ├── Android                      Android SDK + direct JNI
│   ├── Swing                        Java FFM + C API
│   ├── WinForms                     C# P/Invoke + C API
│   ├── Apple                        Swift Package + manual C bridge
│   ├── OHOS                         OHOS SDK + direct NAPI
│   ├── Flutter                      Dart FFI + Flutter Widget
│   ├── Avalonia                     C# P/Invoke + Avalonia Control
│   └── Emscripten                   Web ES-module core binding through an explicit C ABI subset
└── prebuilt                         prebuilt shared libs
```

## Platform Directory Responsibilities

### Core Layer

- `include/sweeteditor/document.h` / `src/document.cpp`
  - text storage, position mapping, Piece Table / LineArray
- `include/sweeteditor/layout.h` / `src/layout.cpp`
  - text layout, auto wrap, hit test, measure cache, visible-area clipping
- `include/sweeteditor/decoration.h` / `src/decoration.cpp`
  - decorations: highlight, Inlay Hint, Ghost Text, guide lines, fold, diagnostics
- `include/sweeteditor/editor_core.h` / `src/editor_core.cpp`
  - main edit coordinator: input, selection, IME, undo/redo, render model assembly
- `include/sweeteditor/c_api.h` / `src/c_api.cpp`
  - stable bridge boundary for non-Android integrations

### Android

- `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
  - control layer, semantic API for app side
- `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
  - JNI bridge and binary-result decoding
- `platform/Android/sweeteditor/src/main/cpp/jni_entry.cpp`
- `platform/Android/sweeteditor/src/main/cpp/jeditor.hpp`
  - main direct path to C++

### Swing

- `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
  - Swing control layer
- `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
  - semantic wrapper on Java side
- `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorNative.java`
  - FFM downcall / upcall

### WinForms

- `platform/WinForms/SweetEditor/SweetEditorControl.cs`
  - WinForms control layer, input and drawing
- `platform/WinForms/SweetEditor/EditorCore.cs`
  - P/Invoke wrapper and protocol bridge
- `platform/WinForms/SweetEditor/CoreProtocol.cs`
  - binary payload decoding
- `platform/WinForms/SweetEditor/EditorCompletion.cs`
  - completion providers and popup coordination
- `platform/WinForms/SweetEditor/EditorDecoration.cs`
  - decoration providers and refresh scheduling
- `platform/WinForms/SweetEditor/EditorNewLine.cs`
  - newline action provider plumbing
- `platform/WinForms/SweetEditor/Perf.cs`
  - performance logging and overlay drawing

### Apple

- `include/sweeteditor/c_api.h`
  - canonical C API imported from the native framework
- `platform/Apple/SweetEditor-Shared/api/SweetEditorCore.swift`
  - core Swift wrapper and bridge-facing entry points
- `platform/Apple/SweetEditor-Shared/core/CoreProtocol.swift`
  - binary payload encoding and decoding aligned with generated integration `CoreProtocol`
- `platform/Apple/SweetEditor-Shared/core/CoreVisual.swift`
  - shared Apple render-model DTOs
- `platform/Apple/SweetEditor-Shared/EditorRenderer.swift`
  - shared Apple renderer consuming the visual model
- `platform/Apple/SweetEditor-iOS`
- `platform/Apple/SweetEditor-macOS`
  - iOS / macOS platform views

### Flutter

- `platform/Flutter/sweeteditor/lib/core/editor_core.dart`
  - Dart FFI core API
- `platform/Flutter/sweeteditor/lib/core/core_protocol.dart`
  - Dart-side binary protocol encoding/decoding
- `platform/Flutter/sweeteditor/lib/widget/sweet_editor_widget.dart`
  - Flutter widget and text-input integration

### Avalonia

- `platform/Avalonia/SweetEditor/SweetEditorControl.cs`
  - Avalonia control layer, input, and drawing
- `platform/Avalonia/SweetEditor/EditorCore.cs`
  - C# P/Invoke bridge
- `platform/Avalonia/SweetEditor/CoreProtocol.cs`
  - C#-side binary protocol encoding/decoding
- `platform/Avalonia/SweetEditor/EditorRenderer.cs`
  - Avalonia DrawingContext rendering

## Integration Implementation Standard

If you are adding or maintaining an integration, see the [Integration Implementation Standard](platform-implementation-standard.md) for the full list of required types, module structure, API contracts, and compliance rules that every integration must follow.

## If You Change X, Start from Y

- Change text editing semantics, undo/redo, selection, IME:
  - check `editor_core.*`, `document.*`, `gesture.*` first
- Change auto wrap, hit test, fold placeholders, inlay / ghost layout:
  - check `layout.*`, `visual.h` first
- Change decoration offsets, diagnostics, guide lines, fold:
  - check `decoration.*` first
- Change public ABI, binary protocol, enum values:
  - change `c_api.h` / `c_api.cpp` first
  - then sync Swing / WinForms / Apple / Flutter / Avalonia
  - if Android has equivalent capability, sync JNI path too
- Change integration input behavior:
  - first confirm core semantic support exists, then change integration forwarding; do not hard-code edit rules in the integration layer

## Cross-Platform Sync Checkpoints

If any item below is touched, do not change only one layer:

- New or changed function in `c_api.h`
- Binary payload field order/type/enum value changed
- `EditorActionResult` / `ScrollMetrics` / `LayoutMetrics` or other bridge return payload changed
- Render-model fields changed
- Core behavior changed for IME, gesture, fold, or decorations

Usual sync targets:

- Android: `jeditor.hpp`, `jni_entry.cpp`, Java `CoreProtocol`
- Swing: `EditorNative.java`, `CoreProtocol.java`
- WinForms: `EditorCore.cs`, `CoreProtocol.cs`
- Apple: `c_api.h`, `SweetEditorCore.swift`, `CoreProtocol.swift`
- Flutter: `editor_core.dart`, `core_protocol.dart`, `sweeteditor_bindings_generated.dart`
- Avalonia: `EditorCore.cs`, `CoreProtocol.cs`

## Build Entry

- Core / tests: repo root `cmake` + `tests/CMakeLists.txt`
- Android: `platform/Android`
- Swing: `platform/Swing`
- WinForms: `platform/WinForms/WinForms.sln`
- Apple: `platform/Apple/Package.swift`
- Flutter: `platform/Flutter/sweeteditor`
- Avalonia: `platform/Avalonia/Avalonia.sln`

## Doc and Encoding Conventions

- Doc updates should reflect capabilities already implemented in current code. Do not write roadmap items as current status.
- For Chinese files in Windows repos, verify encoding first; in this repo, `README.md` and most `docs/zh/*.md` files are UTF-8.
- After integration protocol changes, sync at least one note in `README.md`, `docs/zh/architecture.md`, `docs/en/architecture.md`, and matching `docs/zh/api-platform*.md` / `docs/en/api-platform*.md` files.

## Naming Style (Current Code Habits)

- C++ file names are lowercase; headers use `.h`, implementation files use `.cpp`
- C++ type names use PascalCase
- C++ function names use lowerCamelCase
- C++ member variables usually use `m_` prefix
- Public APIs in the integration layer should be semantic first; bridge layer should stay close to low-level protocol
