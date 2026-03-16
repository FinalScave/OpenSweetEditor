# Platform API Entry

This document describes the current repository code state (2026-03). If the document and source code are different, use the source code.

## Document List

- [Android Platform API](./api-platform-android.md)
- [Swing Platform API](./api-platform-swing.md)
- [Apple Platform API](./api-platform-apple.md)
- [WinForms Platform API](./api-platform-winforms.md)
- [C++ Core / C API](./api-editor-core.md)

## Current Platform Status

| Platform | Bridge Path | Status | Notes |
|---|---|---|---|
| Android | JNI direct to C++ (`jni_entry.cpp` + `jeditor.hpp`) | ✅ Active | Does not use `c_api.h` in main path, but complex return values still decode binary payload |
| Swing | Java FFM -> C API | ✅ Active | Consumes binary payload |
| WinForms | P/Invoke -> C API | ✅ Active | Consumes binary payload |
| Apple | Swift Package + manual C bridge | ✅ Active | Mainly consumes binary payload; bridge header and `c_api.h` need explicit cross-check |
| Web (Emscripten) | Reserved directory | 🚧 Not integrated | `platform/Emscripten/sweeteditor_bindings.cpp` is empty now |
| OHOS | Reserved directory | 🚧 Not integrated | `platform/OHOS` is placeholder only |

## Current Platform Layer Conventions

- Public control APIs should use semantic enums first (`WrapMode`, `FoldArrowMode`, `SpanLayer`, etc.).
- Bridge layers keep native numeric protocol (`int`/`byte`) for JNI/FFM/PInvoke/C bridge.
- Keep bit flags like `FontStyle` as constants, not mutually exclusive enums.

## Suggested Reading Order

1. Read the platform control API first (most direct for product use).
2. Then read the platform bridge layer (JNI/FFM/PInvoke/Swift bridge).
3. If you need ABI, binary payload layout, or enum values, go back to [C++ Core / C API](./api-editor-core.md).
