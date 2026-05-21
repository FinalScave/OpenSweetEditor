# Guide: Adding a New Decoration Type

> This guide walks through every layer that must be touched when introducing a new decoration type (e.g. LinkSpan, CodeLens).
> It is derived from the real-world LinkSpan implementation and can be used as a reusable checklist for future decoration types.
>
> If this document conflicts with source code, the source code is authoritative.

---

## Prerequisites

Read these documents first:

- [Architecture](architecture.md)
- [Editor Core API](api-editor-core.md)
- [Platform Implementation Standard](platform-implementation-standard.md)

---

## Layer-by-Layer Checklist

The layers below are listed bottom-up. Complete them in this order to ensure each layer compiles before moving to the next.

### Layer 1 — C++ Data Structure

**Files**: `include/sweeteditor/decoration.h`, `src/decoration.cpp`

- Define the struct (e.g. `LinkSpan { column, length, target }`).
- Add a `HashMap` or `Vector` member to `DecorationManager` for per-line storage.
- Add a static empty sentinel (e.g. `kEmptyLinks`).
- Declare and implement `setLine*`, `getLine*`, `clear*` methods.
- If the type has column+length semantics, add a `find*At(line, column)` lookup method.
- Add cleanup calls in `clearLine()` and `clearAll()`.
- If the type carries column-range data, implement an `adjust*StartLine()` helper and wire it into `adjustForEdit()` for incremental edit tracking. Types stored only by line key (like CodeLens) only need line-number remapping in `adjustForEdit()`.

### Layer 2 — C++ EditorCore Bridge

**Files**: `include/sweeteditor/editor_core.h`, `src/editor_core.cpp`

- Declare and implement `setLine*`, `setBatchLine*`, `clear*`, and any query method (e.g. `getLinkTargetAt`).
- For decorations that affect layout (most types), each `setLine*` call should mark the affected logical line as `is_layout_dirty = true` and call `invalidateContentMetrics(line)`. Decorations that do not affect layout (GutterIcon, Diagnostic) may skip this and just delegate to `DecorationManager`.
- For `clear*`, most types call `markAllLinesDirty()` + `normalizeScrollState()`. Types that do not affect layout height (GutterIcon, Diagnostic, Highlights) may only call `markAllLinesDirty()` or skip entirely. Follow the existing pattern of the closest existing type.

### Layer 3 — C++ Layout and Hit Test

**Files**: `include/sweeteditor/visual.h`, `include/sweeteditor/gesture.h`, `include/sweeteditor/layout.h`, `src/layout.cpp`

- Add a value to `VisualRunType` enum.
- In `buildLineRuns()`: fetch the decoration data, insert split points, and assign the new `VisualRunType` to affected text segments. For inline decorations (LinkSpan), this means splitting existing TEXT runs at decoration boundaries. For block-level decorations (CodeLens), this means inserting a dedicated run that occupies an entire virtual line. For gutter-only decorations (GutterIcon), layout changes may not be needed at all.
- Update `dumpEnum()` in `visual.cpp` and the JSON mapping in `json_serde.hpp`.

**Only if the decoration is interactive (clickable):**

- Add a value to `HitTargetType` enum.
- In `hitTestDecoration()`: add a branch that returns the corresponding `HitTargetType` when a run of the new type is clicked.
- In `layoutVisibleLines()`: add active-state matching logic so the run gets `run.active = true` when hovered/pressed.
- Decide whether the new run type participates in cursor placement. If yes, include it alongside `TEXT` and `TAB` in `hitTestPointer()` and `columnToX()`. Inline decorations that overlay text (like LinkSpan) typically participate; block-level decorations (like CodeLens) typically do not.

### Layer 4 — C++ Interaction Filter (only if interactive)

Skip this layer entirely for pure-visual decorations (SyntaxSpan, PhantomText, GutterIcon).

**Files**: `src/editor_core.cpp`, `src/interaction.cpp`

- `toHotInteractiveTarget()`: decide whether the new type activates unconditionally (like CodeLens) or requires modifier keys (like Link requires Ctrl/Meta). Add the corresponding branch.
- `probePointer()`: when `toHotInteractiveTarget()` returns a valid target, the cursor type is set to `PointerCursorType::HAND` automatically. No extra work needed unless behavior differs.
- `interaction.cpp` `handleGestureEvent()` TAP branch: decide whether hitting the new type should suppress cursor placement (`intent.place_cursor = false`). Add filtering logic if modifier keys are required (like Link's Ctrl/Meta check).

### Layer 5 — C API

**Files**: `include/sweeteditor/c_api.h`, `src/c_api.cpp`

- Declare `editor_set_line_*`, `editor_set_batch_line_*`, `editor_clear_*`, and any query function.
- Document the binary payload format (LE byte order) in the header comment.
- Implement with `ByteCursor` parsing, then forward to `EditorCore`.

### Layer 6 — Platform Native Bridge (per platform)

For Android JNI as example:

**Files**: `jeditor.hpp`, `jni_entry.cpp`

- Add static JNI wrapper methods in `EditorCoreJni`. For set/setBatch, read `ByteBuffer` via `GetDirectBufferAddress` and forward to the C API. For query methods, call `EditorCore` directly and return via JNI (e.g. `NewStringUTF` for strings).
- Register the methods in the `JNINativeMethod` array inside `RegisterMethods()`.
- Use `@FastNative` annotation for methods that take `ByteBuffer` parameters (zero-copy direct buffer) and `@CriticalNative` for methods with only primitive/void signatures. Mismatching annotations will crash at runtime.

> Other platforms follow equivalent patterns: OHOS uses NAPI (`napi_editor.hpp` + `napi_init.cpp`); iOS uses Objective-C bridging.

### Layer 7 — Platform Core Wrapper

For Android as example:

**Files**: `<Type>.java`, `VisualRunType.java`, `EditorCore.java`, `ProtocolEncoder.java`

- Define the platform data class (e.g. `public final` immutable POJO with the same fields as the C++ struct).
- Add the enum value to `VisualRunType`. If the decoration is interactive, also add to `HitTargetType`.
- Implement `setLine<Type>` / `setBatchLine<Type>` / `clear<Type>` / query methods in `EditorCore.java`, encoding via `ProtocolEncoder` → `ByteBuffer.allocateDirect()` then calling `native*` methods.
- Implement `pack*` / `packBatch*` binary encoding methods in `ProtocolEncoder.java` (two-pass pattern: first pass calculates total size and caches UTF-8 bytes, second pass allocates one direct ByteBuffer and writes).

> Other platforms: OHOS uses ArkTS interfaces in `CoreAdornments.ets` + `CoreProtocol.ets` + `EditorCore.ets`.

### Layer 8 — Platform Decoration System and UI

**Files**: `DecorationResult.java`, `DecorationProviderManager.java`, `SweetEditor.java`, `EditorRenderer.java`

- `DecorationResult.java`: add data field (e.g. `SparseArray<List<T>>`) + `ApplyMode` mode field; add getter/setter; add `Builder.<type>(value, mode)` method; update `copy()`.
- `DecorationProviderManager.java`: add merge container + mode variable in `applyMerged()`; add `apply*Mode()` and `clear*Range()` private methods; add merge branch in `mergePatch()`.
- `SweetEditor.java`: expose public API methods (`setLine<Type>`, `setBatchLine<Type>`, `clear<Type>`, plus any query methods).
- `EditorRenderer.java`: add rendering logic for the new `VisualRunType` (foreground color, background, underline, etc.).

**Only if the decoration is interactive:**

- `SweetEditor.java`: add the new `HitTargetType` branch in `fireGestureEvents()` → `publish(new <Type>ClickEvent(...))`.
- Define a click event class (e.g. `<Type>ClickEvent.java`, extends `EditorEvent`).
- Expose `on<Type>Click` / `off<Type>Click` event subscription APIs.

> Other platforms: OHOS distributes these across `DecorationTypes.ets`, `SweetEditor.ets`, `SweetEditorController.ets`, `EditorEvent.ets`, `EditorRenderer.ets`.

### Layer 9 — Cross-platform `DecorationType` Enum Sync

`DecorationType` is defined independently in every platform. All of the following files must be updated with the new enum value:

- Android: `DecorationType.java`
- Swing: `DecorationType.java`
- OHOS: `DecorationTypes.ets` (string enum)
- Flutter: `decoration_types.dart`
- Apple (Swift): `DecorationProvider.swift` (OptionSet bitfield)
- Avalonia: `EditorDecoration.cs` (Flags enum)
- WinForms: `EditorDecoration.cs` (Flags enum)

Missing a platform causes that platform's `DecorationProvider` to be unable to declare the new capability.

### Layer 10 — Tests

**Files**: `tests/decoration_adjust.cpp`, `tests/layout_decorations.cpp`

- Add `adjustForEdit` test cases in `decoration_adjust.cpp` covering the new type's column/line adjustment behavior.
- If the new type is inline and participates in hitTest/screen-coord, add consistency checks in `layout_decorations.cpp`.
- Platform-level tests (Swift, Android instrumentation) may also need coverage for the new event type.

---

## Key Integration Points to Watch

### `clearAll()` coverage

Every new storage container in `DecorationManager` must be cleared in `clearAll()`. Missing this causes stale decorations to survive document reloads.

### `toHotInteractiveTarget()` gating

This function controls which decoration types get hover/press visual feedback and hand-cursor treatment. If the new type is clickable, it must have a branch here. Decide whether activation is unconditional or requires modifier keys.

### `adjustForEdit()` incremental tracking

Types with column+length semantics (like LinkSpan, DiagnosticSpan) need column-level adjustment when text is edited. Types stored only by line key (like CodeLens, GutterIcon) only need line-number remapping.

### Binary protocol consistency

The C API payload format (little-endian u32 sequences) must exactly match the platform-side `pack*` encoder. Variable-length payloads (e.g. UTF-8 strings) use the pattern `u32 byte_length + u8[byte_length]`.

### Platform bridge annotation and signature matching

Each platform has its own rules for native bridge declarations. On Android, `@FastNative` / `@CriticalNative` annotations must match the JNI signature exactly or it will crash at runtime. On OHOS, ArkTS requires explicit return types on `forEach` callbacks and explicit generic type parameters. Always verify that the platform-side native declarations match the C API signatures.

### Cursor placement interaction

Decide whether clicking the new decoration should place the cursor (like regular text) or suppress it (like CodeLens). This is controlled in `interaction.cpp`'s TAP handler via `intent.place_cursor`.

### Render model coordinate system

LINK runs participate in `getPositionScreenCoord()` / `columnToX()` the same way as TEXT runs, meaning the cursor can land inside the decoration text. CodeLens runs are skipped. Choose the appropriate behavior for the new type.

---

## Reference: Files Touched for LinkSpan (Android example)

> The table below uses Android file names. Other platforms have equivalent files:
> OHOS → `napi_editor.hpp`, `CoreAdornments.ets`, `DecorationTypes.ets`, `SweetEditor.ets`, etc.
> iOS → corresponding Objective-C / Swift bridging files.

| Layer | Files Modified |
|-------|---------------|
| C++ Data | `decoration.h`, `decoration.cpp` |
| C++ Core | `editor_core.h`, `editor_core.cpp` |
| C++ Layout | `visual.h`, `gesture.h`, `layout.h`, `layout.cpp`, `visual.cpp`, `json_serde.hpp` |
| C API | `c_api.h`, `c_api.cpp` |
| JNI Bridge | `jeditor.hpp` (JNI wrappers + `kJMethods[]` table) |
| Java Core | `<Type>.java`, `VisualRunType.java`, `HitTargetType` (in `EditorCore.java`), `EditorCore.java`, `ProtocolEncoder.java` |
| Java Decoration | `DecorationResult.java`, `DecorationType.java`, `DecorationProviderManager.java` |
| Java UI | `SweetEditor.java`, `<Type>ClickEvent.java` (if interactive), `EditorRenderer.java` |
| DecorationType Enum | `DecorationType.java` (Android, Swing), `DecorationTypes.ets` (OHOS), `decoration_types.dart` (Flutter), `DecorationProvider.swift` (Apple), `EditorDecoration.cs` (Avalonia, WinForms) |
| Tests | `decoration_adjust.cpp`, `layout_decorations.cpp` |
