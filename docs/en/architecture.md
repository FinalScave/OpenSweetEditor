# SweetEditor Architecture Design

## Table of Contents

- [Design Principles](#design-principles)
- [Overall Architecture](#overall-architecture)
- [Core Module Details](#core-module-details)
  - [Document - Document Model](#document---document-model)
  - [TextLayout - Layout Engine](#textlayout---layout-engine)
  - [DecorationManager - Decoration System](#decorationmanager---decoration-system)
  - [EditorCore - Editor Coordinator](#editorcore---editor-coordinator)
  - [GestureHandler - Gesture Recognition](#gesturehandler---gesture-recognition)
  - [UndoManager - Undo/Redo](#undomanager---undoredo)
  - [Buffer - Data Source Abstraction](#buffer---data-source-abstraction)
- [Rendering Pipeline](#rendering-pipeline)
- [Cross-Platform Bridge Strategy](#cross-platform-bridge-strategy)
- [Data Flow](#data-flow)
- [Memory Management](#memory-management)
- [Performance Optimization Strategy](#performance-optimization-strategy)

---

## Design Principles

The core design principle of SweetEditor is **"complete separation of computation and rendering"**:

1. **C++ core does no rendering** - it does not depend on any graphics library (OpenGL / Skia / Metal, etc.) and does not hold any platform UI object.
2. **C++ core does no font measuring** - measuring is inverted to platform side through the `TextMeasurer` interface.
3. **C++ core outputs structured render model** - internally it builds `EditorRenderModel`; Android / C API / bridge paths are all built around this model.
4. **Platform layer stays thin** - it mainly forwards events, does font measuring, decodes binary protocol, and draws from model; it does not hold cross-platform editing semantics.

Core benefits:

- **Behavior consistency**: text edit, cursor move, selection logic all have one implementation.
- **Testability**: core logic can be unit tested without UI.
- **Controllable platform adaptation cost**: minimum loop for a new platform is `TextMeasurer` + input forwarding + payload decode + drawing. Complexity stays in core, not in platform semantic layer.
- **Best rendering quality**: each platform uses its strongest native text rendering.

---

## Overall Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                      Platform Layer (Input + Render)              │
│                                                                    │
│ Android        iOS/macOS         Swing/WinForms        Web/OHOS    │
│ Canvas        CoreText/CG          Java2D / GDI+       (reserved)  │
└───────────────┬───────────────────────────────┬────────────────────┘
                │                               │
                │ JNI direct to C++             │ C ABI / Binary Payload
                ▼                               ▼
      ┌─────────────────────┐         ┌──────────────────────────┐
      │ Android Bridge      │         │ C API Bridge             │
      │ (jni_entry+jeditor) │         │ extern "C" + intptr_t   │
      └───────────┬─────────┘         └────────────┬─────────────┘
                  └──────────────────────┬──────────┘
                                         ▼
      ┌──────────────────────────────────────────────────────────┐
      │                    SweetEditor Core (C++17)             │
      │                                                          │
      │  Document · TextLayout · DecorationManager · EditorCore │
      │  GestureHandler · UndoManager · LinkedEditing           │
      └──────────────────────────────────────────────────────────┘
```

Current integration status (code state):

- Android: integrated (JNI direct)
- Swing / WinForms: integrated (C API)
- Apple: integrated (Swift Package + manual bridge)
- Web (Emscripten): directory exists, binding file is empty for now
- OHOS: directory exists, currently placeholder only

---

## Core Module Details

### Document - Document Model

**Files**: `src/include/document.h` · `src/core/document.cpp`

Document is the abstraction layer of text content and defines a unified text operation interface.

There is one easy-to-misread point in the current string model:

- **Storage layer**: `Document` and edit entry points are mainly UTF-8
- **Layout/measure layer**: `LogicalLine.cached_text`, `TextLayout` measure cache, and `VisualRun.text` use UTF-16
- **Platform protocol layer**: complex C API structures go through binary payload; render-model text fields are currently serialized in UTF-8, while `get_document_line_text()` separately returns UTF-16 pointer

So the core model is not "all UTF-8" or "all UTF-16", but a mixed model: "UTF-8 storage + UTF-16 layout/measure + binary payload transport".

#### Abstract Interface

```cpp
class Document {
  virtual U8String getU8Text() = 0;               // full text (UTF-8)
  virtual U16String getU16Text() = 0;              // full text (UTF-16)
  virtual size_t getLineCount() const = 0;         // total line count
  virtual U16String getLineU16Text(size_t line) = 0; // text of a given line
  virtual void insertU8Text(const TextPosition& pos, const U8String& text) = 0;
  virtual void deleteU8Text(const TextRange& range) = 0;
  virtual void replaceU8Text(const TextRange& range, const U8String& text) = 0;
  virtual Vector<LogicalLine>& getLogicalLines() = 0;
  // ...
};
```

#### Two Implementations

| Implementation | Best for | Internal structure |
|------|---------|---------|
| `LineArrayDocument` | small/medium files, frequent line operations | line-based `Vector<U8String>` |
| `PieceTableDocument` | large files, frequent edits | Piece Table (original buffer + edit buffer + segment list) |

#### LogicalLine

Each logical line keeps these fields:

```cpp
struct LogicalLine {
  size_t start_byte;            // byte offset in full text
  size_t start_char;            // character offset in full text
  U16String cached_text;        // line text cache (UTF-16)
  bool is_char_dirty;           // text data needs refresh
  LineEnding line_ending;       // line ending type (LF/CR/CRLF)
  float start_y;                // start Y of this line
  float height;                 // rendered line height (with wraps)
  Vector<VisualLine> visual_lines; // visual line layout data
  bool is_layout_dirty;         // layout needs rebuild
  bool is_fold_hidden;          // hidden by fold
};
```

Key design: **dual dirty flags** - `is_char_dirty` marks stale text data, `is_layout_dirty` marks stale layout. Edit operations only mark dirty; real compute is deferred to `buildRenderModel()` on demand.

---

### TextLayout - Layout Engine

**Files**: `src/include/layout.h` · `src/core/layout.cpp`

The layout engine is one of the most critical modules. It transforms logical line text into renderable visual lines.

#### Core Responsibilities

1. **Line text layout** - zipper merge line text + highlight spans + inlay hints + phantom texts into `VisualRun` sequence
2. **Auto wrap** - split long lines into visual lines by `WrapMode`
3. **Viewport clipping** - layout/output only visible lines
4. **HitTest** - precise mapping from screen coordinates to text position
5. **Width measurement** - call platform text measure via `TextMeasurer`, with cache

#### Layout Flow

```
layoutVisibleLines()                    ← layout entry
    │
    ▼
resolveVisibleLines()                   ← compute visible range while laying out
    │  iterate all logical lines, call layoutLine() per line:
    │    · if line is_layout_dirty, relayout it
    │    · accumulate line height, locate first/last visible lines
    │    · once beyond viewport bottom, return early and skip rest
    │
    │  inside layoutLine() for dirty lines:
    │    ├→ buildLineRuns()             ← zipper merge: text + spans + inlay hints + phantom texts
    │    │                                 produce VisualRun sequence (TEXT / INLAY_HINT / PHANTOM_TEXT)
    │    ├→ layoutLineIntoVisualLines() ← split runs into VisualLines by WrapMode
    │    │    ├→ wrapLineRuns()            NONE: no wrap / CHAR_BREAK / WORD_BREAK
    │    │    └→ handle phantom text continuation across wrapped lines
    │    └→ append fold placeholder run (if this is fold start line)
    │
    ▼
iterate visible lines [first_line, last_line]
    │  for each VisualLine:
    │    · absolute to screen coordinate transform
    │    · cropVisualLineRuns()          ← horizontal clipping (non-wrap mode)
    │    · fill line number icons and fold state
    │
    ▼
Vector<VisualLine>  → output to EditorRenderModel
```

#### Wrap Modes

```cpp
enum struct WrapMode {
  NONE,        // no wrapping (horizontal scrolling)
  CHAR_BREAK,  // character-level wrap
  WORD_BREAK,  // word-level wrap (split by space/punctuation)
};
```

#### TextMeasurer Interface

```cpp
class TextMeasurer {
  virtual float measureWidth(const U16String& text, int32_t font_style) = 0;
  virtual float measureInlayHintWidth(const U16String& text) = 0;
  virtual float measureIconWidth(int32_t icon_id) = 0;
  virtual FontMetrics getFontMetrics() = 0;
};
```

Implemented by each platform. C API passes callbacks through `text_measurer_t`:

```c
typedef struct {
  float (*measure_text_width)(const U16Char* text, int32_t font_style);
  float (*measure_inlay_hint_width)(const U16Char* text);
  float (*measure_icon_width)(int32_t icon_id);
  void  (*get_font_metrics)(float* arr, size_t length);
} text_measurer_t;
```

#### Monospace vs proportional fonts

The layout engine uses `m_is_monospace_` internally:
- **Monospace**: can fast-calc with `char_count × char_width`, no per-char measure
- **Proportional**: must call `TextMeasurer`; results cached in `m_text_widths_` HashMap

---

### DecorationManager - Decoration System

**Files**: `src/include/decoration.h` · `src/core/decoration.cpp`

This module manages all non-text visual elements.

#### Managed Data Types

| Data type | Struct | Storage | Affects layout |
|---------|--------|---------|---------|
| Syntax highlight | `StyleSpan` {column, length, style_id} | by line `Vector<Vector<StyleSpan>>` | ✅ (font style affects width) |
| Inlay Hint | `InlayHint` {type, column, text, icon_id} | by line `Vector<Vector<InlayHint>>` | ✅ (adds width) |
| Phantom Text | `PhantomText` {column, text} | by line `Vector<Vector<PhantomText>>` | ✅ (may expand across lines) |
| Gutter icon | `GutterIcon` {icon_id} | `HashMap<line, Vector<GutterIcon>>` | ❌ |
| Fold region | `FoldRegion` {start_line, end_line, collapsed} | `Vector<FoldRegion>` | ✅ (hides lines) |
| Indent line | `IndentGuide` {start, end} | `Vector<IndentGuide>` | ❌ |
| Bracket branch line | `BracketGuide` {parent, end, children} | `Vector<BracketGuide>` | ❌ |
| Control-flow arrow | `FlowGuide` {start, end} | `Vector<FlowGuide>` | ❌ |
| Separator line | `SeparatorGuide` {line, style, count} | `Vector<SeparatorGuide>` | ❌ |

Extra notes:

- `InlayHint.text` / `PhantomText.text` are still stored as UTF-8 in `DecorationManager`.
- `TextLayout::buildLineRuns()` converts needed decoration text to UTF-16 when generating `VisualRun`.
- So decoration manager stores edit-semantic data, not platform-ready drawing objects.

#### StyleRegistry

```cpp
class StyleRegistry {
  void registerStyle(Style&& style);       // register: style_id → {color, font_style}
  Style& getStyle(uint32_t style_id);      // query
};
```

Platform side registers style first (ID → color + font style), then applies ranges per line through `setLineSpans`. This decouples style definition from style usage and helps theme switching.

#### Auto adjust after edits

```cpp
void adjustForEdit(const TextRange& old_range, const TextPosition& new_end);
```

When text changes, all decoration line/column offsets must be updated. `adjustForEdit` centralizes this logic so highlights and inlay hints do not drift after edits.

---

### EditorCore - Editor Coordinator

**Files**: `src/include/editor_core.h` · `src/core/editor_core.cpp`

EditorCore is the top-level class. It composes all submodules and exposes full editor APIs.

#### Internal Components

```cpp
class EditorCore {
  Ptr<TextMeasurer>       m_measurer_;         // text measure (platform impl)
  Ptr<Document>           m_document_;         // document model
  Ptr<DecorationManager>  m_decorations_;      // decoration manager
  UPtr<GestureHandler>    m_gesture_handler_;  // gesture recognition
  UPtr<TextLayout>        m_text_layout_;      // layout engine
  UPtr<UndoManager>       m_undo_manager_;     // undo/redo
  // cursor, selection, IME state...
};
```

#### Core Method Groups

| Method group | Description |
|--------|------|
| `loadDocument()` | load document |
| `handleGestureEvent()` | handle touch/mouse event → returns GestureResult |
| `handleKeyEvent()` | handle key event → returns KeyEventResult |
| `insertText()` / `backspace()` / `deleteForward()` | atomic text operations |
| `moveCursor*()` | cursor movement (up/down/left/right, line start/end) |
| `setSelection()` / `selectAll()` | selection management |
| `compositionStart/Update/End/Cancel()` | IME composition |
| `undo()` / `redo()` | undo/redo |
| `registerStyle()` / `setLineSpans()` / `setBatchLineSpans()` / `setLineInlayHints()` / `setLinePhantomTexts()` | decoration setting |
| `setFoldRegions()` / `foldAt()` / `unfoldAt()` | code folding |
| `add*Guide()` | code structure guides |
| `buildRenderModel()` | **core output**: build one frame render model |

#### Unified edit entry

All text modifications eventually go through `applyEdit()`:

```cpp
TextEditResult applyEdit(const TextRange& range, const U8String& new_text, bool record_undo = true);
```

This method:
1. records old text (for undo)
2. edits document (`Document::replaceU8Text`)
3. adjusts all decoration offsets (`DecorationManager::adjustForEdit`)
4. auto-unfolds edited folded area (`autoUnfoldForEdit`)
5. marks affected lines as dirty
6. pushes undo action
7. returns precise change info (`TextEditResult`)

---

### GestureHandler - Gesture Recognition

**Files**: `src/include/gesture.h` · `src/core/gesture.cpp`

A unified gesture recognition engine for touch and mouse input.

#### Event Types

```
Touch series: TOUCH_DOWN → TOUCH_MOVE → TOUCH_UP (with multi-touch POINTER_DOWN/UP)
Mouse series: MOUSE_DOWN → MOUSE_MOVE → MOUSE_UP + MOUSE_WHEEL + MOUSE_RIGHT_DOWN
Direct series: DIRECT_SCALE (trackpad pinch), DIRECT_SCROLL (trackpad scroll)
```

#### Recognized Gestures

| Gesture | Trigger condition |
|------|---------|
| `TAP` | down→up with move distance < touch_slop |
| `DOUBLE_TAP` | interval between two TAPs < double_tap_timeout |
| `LONG_PRESS` | hold after down > long_press_ms |
| `SCALE` | two-finger pinch or DIRECT_SCALE |
| `SCROLL` | one-finger move > touch_slop or MOUSE_WHEEL / DIRECT_SCROLL |
| `FAST_SCROLL` | fling inertial scroll |
| `DRAG_SELECT` | mouse drag or long-press drag |
| `CONTEXT_MENU` | right click or long press |

#### Modifier Keys

```cpp
enum struct Modifier : uint8_t {
  NONE  = 0,
  SHIFT = 1 << 0,  // Shift+Click = extend selection
  CTRL  = 1 << 1,  // Ctrl+Click = multi-cursor (future)
  ALT   = 1 << 2,
  META  = 1 << 3,  // Cmd (macOS)
};
```

---

### UndoManager - Undo/Redo

**File**: `src/include/undo.h`

Undo/redo is implemented with dual stacks (undo stack + redo stack).

#### Operation merge

Continuous single-character typing or deleting is auto-merged into one action (merge window: 500ms):

```
User types "hello" → not 5 undo steps, but 1 undo step for whole "hello"
```

Merge rules:
- adjacent single-char inserts (continuous position, interval < 500ms)
- adjacent backspace deletes (continuous position)
- adjacent delete-forward deletes (continuous position)
- newline is never merged (Enter is always one step)
- operations with active selection are not merged

#### Stack depth limit

Default max is 512 steps. Oldest actions are dropped when exceeded.

---

### Buffer - Data Source Abstraction

**Files**: `src/include/buffer.h` · `src/core/buffer.cpp`

| Implementation | Usage |
|------|------|
| `U8StringBuffer` | readable/writable in-memory string buffer |
| `MappedFileBuffer` | file memory mapping (mmap / CreateFileMapping), read-only, zero-copy for large files |

---

## Rendering Pipeline

### EditorRenderModel

`buildRenderModel()` is called once per frame. It first assembles complete render instructions inside core; then C API encodes it to binary payload:

```cpp
struct EditorRenderModel {
  float split_x;                        // X of line-number separator
  float scroll_x, scroll_y;             // current scroll offset
  float viewport_width, viewport_height; // viewport size
  PointF current_line;                  // current line background position
  Vector<VisualLine> lines;             // visible visual lines
  Cursor cursor;                        // cursor
  Vector<SelectionRect> selection_rects; // selection highlight rects
  SelectionHandle selection_start_handle; // selection start drag handle
  SelectionHandle selection_end_handle;  // selection end drag handle
  CompositionDecoration composition_decoration; // IME underline
  Vector<GuideSegment> guide_segments;   // code structure guides
  Vector<DiagnosticDecoration> diagnostic_decorations; // diagnostic decorations
  uint32_t max_gutter_icons;            // gutter icon count
  Vector<LinkedEditingRect> linked_editing_rects; // linked-edit highlights
  Vector<BracketHighlightRect> bracket_highlight_rects; // bracket highlights
};
```

Current C API conventions:

- `build_editor_render_model()`: returns native-endian binary payload (all supported platforms are currently little-endian)
- `get_layout_metrics()`: returns `LayoutMetrics` binary payload for platform-side layout query

### VisualLine and VisualRun

Each visible visual line contains multiple render segments:

```
VisualLine
├── VisualRun (TEXT)             - plain code text with style
├── VisualRun (WHITESPACE)       - whitespace (optional visible rendering)
├── VisualRun (INLAY_HINT)       - Inlay Hint (text or icon)
├── VisualRun (PHANTOM_TEXT)     - phantom text
├── VisualRun (FOLD_PLACEHOLDER) - fold placeholder "…"
└── VisualRun (NEWLINE)          - newline
```

Each VisualRun has exact draw coordinates `(x, y)`, width `width`, text `text`, and style `style` (color + font style).

Important distinction between internal representation and cross-language transport format:

- Core internal `VisualRun.text` is `U16String`
- `build_editor_render_model()` converts `VisualRun.text` to length-prefixed UTF-8 bytes in C API path
- Swing / WinForms / Apple / Android bridge layers decode this UTF-8 into each language `String`

### Platform-side Drawing Order

```
1. Fill background
2. Draw current line highlight background (current_line)
3. Draw selection highlight rects (selection_rects)
4. Draw code structure guides (guide_segments)
5. Draw line-number separator (split_x)
6. Iterate lines:
   a. Draw line number (line_number_position)
   b. Draw gutter icons (gutter_icon_ids)
   c. Draw fold arrow (fold_state)
   d. Iterate runs:
      - TEXT / WHITESPACE: drawText(run.text, run.x, run.y) with run.style
      - INLAY_HINT: draw rounded background + text/icon
      - PHANTOM_TEXT: draw with translucency
      - FOLD_PLACEHOLDER: draw "…" placeholder
7. Draw IME composition underline (composition_decoration)
8. Draw diagnostic decorations (diagnostic_decorations)
9. Draw linked-edit highlights (linked_editing_rects)
10. Draw bracket highlights (bracket_highlight_rects)
11. Draw cursor line (cursor)
12. Draw selection drag handles (selection handles)
```

---

## Cross-Platform Bridge Strategy

### C API Layer

Main bridge contract for non-Android platforms is `extern "C"` C API. Objects pass via `intptr_t` handles:

```c
// create
uint8_t options_data[] = {/* LE-packed EditorOptions */};
intptr_t editor = create_editor(measurer, options_data, sizeof(options_data));

// use
set_editor_viewport(editor, width, height);
set_editor_document(editor, document);
size_t payload_size = 0;
const uint8_t* payload = build_editor_render_model(editor, &payload_size);

// free
free_binary_data((intptr_t)payload);
free_editor(editor);
```

### Data Exchange Format

Current C API path uses binary payload uniformly (native-endian; all supported platforms are currently little-endian):

- `build_editor_render_model()` -> `EditorRenderModel`
- `get_layout_metrics()` -> `LayoutMetrics`
- `handle_editor_gesture_event*()` -> `GestureResult`
- `handle_editor_key_event()` -> `KeyEventResult`
- `editor_insert_text()` / `undo()` / `redo()` etc. -> `TextEditResult`
- `editor_get_scroll_metrics()` -> `ScrollMetrics`

In addition, input-style APIs such as `editor_set_line_spans()`, `editor_set_line_diagnostics()`, `editor_set_fold_regions()`, `editor_start_linked_editing()` also use compact binary payload as parameters.

String notes:

- string fields in binary payload are length-prefixed UTF-8
- `create_document_from_utf16()` / `get_document_line_text()` are explicit UTF-16 boundaries
- a few query APIs still return UTF-8 `const char*` (such as `editor_get_selected_text()`)

### Bridge by Platform

| Platform | Bridge tech | Call path |
|------|---------|---------|
| Android | JNI (`jni_entry.cpp` + `jeditor.hpp`) | Java `native*` direct to C++ objects |
| iOS/macOS | Swift Package + manual C bridge | Swift calls bridge functions |
| Windows | P/Invoke | `DllImport("sweeteditor.dll")` |
| Swing | Java FFM | downcall to C API |
| Web | Emscripten | directory exists, binding not finished |
| OHOS | - | directory exists, not integrated |

Note: Android currently does not use `c_api.h` call chain. New public features must sync both JNI path and C API path.

Extra:

- Android is JNI direct, but `buildRenderModel()`, gesture result, key result, text edit result, and scroll metrics still decode from binary protocol.
- Swing / WinForms currently read UTF-8 string fields via `ProtocolDecoder` / `EditorProtocol`.
- Apple consumes the same binary layout via manual bridge + Swift `BinaryReader`.

---

## Data Flow

### Full flow from input to render

> The flow below uses C API platforms (Swing/WinForms/Apple) as example; Android is similar but enters through direct JNI.

```
   User touch/click
        │
        ▼
  Platform captures event
        │
        ▼
  C API: handle_editor_gesture_event()
        │
        ▼
  GestureHandler.handleGestureEvent()
        │  identify gesture type (TAP/SCROLL/SCALE/...)
        ▼
  EditorCore.handleGestureEvent()
        │  run corresponding action:
        │  · TAP → placeCursorAt()
        │  · DOUBLE_TAP → selectWordAt()
        │  · SCROLL → setScroll()
        │  · SCALE → setScale()
        │  · DRAG_SELECT → dragSelectTo()
        ▼
  Return GestureResult (binary payload)
        │
        ▼
  Platform checks if redraw is needed
        │
        ▼
  C API: build_editor_render_model()
        │
        ▼
  EditorCore.buildRenderModel()
        │  1. update dirty-line text data
        │  2. relayout dirty lines
        │  3. compute visible range
        │  4. generate VisualLine + VisualRun
        │  5. compute cursor screen position
        │  6. compute selection highlight rects
        │  7. generate code structure guides
        ▼
  Return EditorRenderModel (binary payload)
        │
        ▼
  Platform draws model to screen
```

### Text edit flow

```
  User types / Backspace / paste
        │
        ▼
  EditorCore.insertText() / backspace() / deleteForward()
        │
        ▼
  applyEdit(range, new_text)
        │
        ├──→ Document.replaceU8Text()         // change text
        ├──→ DecorationManager.adjustForEdit() // shift decoration offsets
        ├──→ autoUnfoldForEdit()               // auto-unfold
        ├──→ mark dirty lines                  // defer relayout
        └──→ UndoManager.pushAction()          // record undo
        │
        ▼
  Return TextEditResult
        │  {changes:[{range:{start,end}, new_text}]}
        ▼
  Platform receives changes -> calls buildRenderModel() to redraw
```

---

## Memory Management

### Smart Pointer Strategy

| Pointer type | Usage |
|---------|---------|
| `Ptr<T>` (`shared_ptr`) | shared objects across modules: Document, TextMeasurer, DecorationManager, StyleRegistry |
| `UPtr<T>` (`unique_ptr`) | exclusive ownership: TextLayout, GestureHandler, UndoManager, Buffer |
| `WPtr<T>` (`weak_ptr`) | used when needed (not heavily used now) |

### C API Handle Management

Handles pass through `intptr_t`. C++ side uses `CPtrHolder<T>` to wrap `shared_ptr` and manage lifecycle:

```cpp
intptr_t create_editor(...) {
  return makeCPtrHolderToIntPtr<EditorCore>(config, measurer);
}

void free_editor(intptr_t handle) {
  deleteCPtrHolder<EditorCore>(handle);
}
```

Platform side should ensure:

- call `free_document()` / `free_editor()` when handles are no longer used
- free binary payload returned by `build_editor_render_model()` etc. via `free_binary_data()`
- free UTF-16 text returned by `get_document_line_text()` via `free_u16_string()`

---

## Performance Optimization Strategy

| Strategy | Description |
|------|------|
| **Deferred compute with dirty flags** | edit operations only mark dirty; layout compute is deferred to `buildRenderModel()` on demand |
| **Viewport clipping** | only layout and generate visible lines; even for huge files only tens of lines are processed |
| **Measure cache** | `TextLayout` has `HashMap<TextWidthKey, float>` cache for measured text widths |
| **SIMD Unicode** | uses simdutf for UTF-8 ↔ UTF-16 conversion, accelerated by NEON/SSE/AVX |
| **File memory mapping** | `MappedFileBuffer` uses mmap for zero-copy large-file open |
| **Undo merge** | adjacent single-char insert/delete auto-merge to reduce memory use |
| **Line-height cache** | `EditorCore` keeps line-height cache in `HashMap<size_t, float> m_line_heights_` |
| **Binary payload transport** | render model, layout metrics, event results, edit results all use compact binary protocol to lower cross-language parsing cost |
