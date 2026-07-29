# Changelog

## 1.0.0-rc1

### Web Runtime

- Provide a modular ES-module WebAssembly C ABI runtime for browser, Web Worker, and Node.js environments.
- Support growable WebAssembly memory, a persistent runtime, virtual filesystem access, `ccall` and `cwrap`, UTF-8 conversion helpers, heap access, and dynamic callback registration.
- Allow JavaScript hosts to supply native text-measurement callbacks and consume binary editor-action, render-model, layout, and IME payloads.

### Documents and Editor Lifecycle

- Create documents from UTF-8 text, UTF-16 text, or files in the Emscripten filesystem.
- Read complete document text and individual lines as UTF-8 or UTF-16, query line counts, and explicitly release documents and returned buffers.
- Create and destroy editor instances and attach documents to editors.

### Layout, Rendering, and View Configuration

- Configure viewport size, font-metric refresh, fold-arrow mode, wrapping, tab size, scale, line spacing, content padding, split-line visibility, current-line rendering, gutter stickiness and visibility, selection-handle hit areas, and scrollbars.
- Build binary render models and query layout metrics.
- Configure and query scrolling, scroll to a line, navigate to a document position, keep the cursor visible, and query document-position and cursor rectangles.

### Input and Editing

- Process gesture events, pointer-modifier changes, animation ticks, key events, and custom keymaps.
- Insert, replace, and delete text, perform backspace and forward delete, and move, copy, delete, or insert complete lines.
- Provide undo and redo with availability queries.
- Configure read-only mode, automatic indentation, backspace unindent, and space-based indentation.

### Cursor, Selection, and Navigation

- Set and query cursor positions, select all, set and query selections, and retrieve selected text.
- Query the word and word range at the cursor.
- Move the cursor left, right, up, down, and to line boundaries.

### Styles and Decorations

- Register individual or batched text styles and apply single-line or batched highlight spans across independent layers.
- Set and clear inlay hints, phantom text, gutter icons, CodeLens, links, diagnostics, and indent, bracket, flow, and separator guides.
- Query link targets, configure the maximum number of gutter icons, clear individual decoration families, and clear all decorations.

### Brackets, Folding, Snippets, and Linked Editing

- Configure bracket and auto-closing pairs, provide exact matched-bracket positions, and return to built-in bracket matching.
- Set fold regions, toggle, fold, or unfold individual regions, fold or unfold all regions, and query line visibility and the visible line range.
- Insert snippet templates, start linked-editing sessions, navigate linked ranges, query session state, and cancel linked editing.

### IME Protocol and Outputs

- Export the six session-based IME C APIs for beginning and ending sessions, applying command or text-update batches, and querying authoritative state or finite text context.
- Produce `sweeteditor_c_abi.js` and `sweeteditor_c_abi.wasm` with explicit native-memory release helpers, plus a separately selectable Embind target reserved for bindings.
