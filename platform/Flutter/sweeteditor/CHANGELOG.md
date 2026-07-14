# Changelog

## 1.0.0-rc1

### Editor and Public API

- Provide `SweetEditorWidget`, `SweetEditorController`, configurable declarative widget inputs, and low-level Dart FFI `EditorCore` and `Document` APIs.
- Support string- and file-backed documents, text and line queries, insertion, position-based insertion, range replacement and deletion, batched text edits, line move, copy, delete, and insert commands, and undo/redo.
- Support cursor and selection control, word queries, select all, document navigation, position geometry, scrolling, visible-line queries, and scroll metrics.
- Support case-sensitive, whole-word, regular-expression, wrap-around, and bounded search, including match navigation, current-match replacement, replace all, clearing, and search-state queries.
- Support code folding and placeholders, fold visibility queries, snippets, tab stops, and linked editing.
- Provide dark and light themes, custom text styles and colors, language configuration, bracket and auto-closing pairs, tab size, spaces-for-tabs behavior, metadata, icon providers, and configurable keymaps with VS Code, JetBrains, and Sublime presets.
- Provide runtime settings for font family, text size, scale, wrapping, whitespace and line-break rendering, line spacing, content padding, split lines, gutter visibility and stickiness, fold arrows, current-line rendering, auto-indent, backspace unindent, read-only mode, gutter icon limits, and decoration refresh policy.

### Rendering and Decorations

- Render through Flutter Canvas and `TextPainter` with viewport-based layout, wrapped visual lines, selections, cursors, folding, guides, gutters, decorations, and transient scrollbars.
- Support registered styles and syntax, semantic, and overlay spans, plus inlay hints, phantom text, diagnostics, document highlights, gutter icons, CodeLens, links, and matched-bracket highlights.
- Support indent, bracket, flow, and separator guides; single-line and batched decoration updates; layer-specific clearing; and complete decoration clearing.

### Language Tooling and Extension Points

- Provide asynchronous `DecorationProvider` updates with cancellation, visible-range context, incremental refresh, and merge, replace-all, or replace-range application modes.
- Provide cancellable asynchronous `CompletionProvider` requests and synchronous `NewLineActionProvider` chains.
- Support automatic completion triggers and re-triggering, snippets, primary and additional text edits, keyboard navigation, custom Flutter completion item builders, and programmatically supplied completion items.
- Provide inline suggestion ghost text and actions, selection handles and customizable selection menus, custom editor icons and keyboard commands, and language metadata.
- Publish typed streams for text, cursor, selection, scroll, scale, document load, folding, gutter icons, inlay hints, CodeLens, links, long press, double tap, context-menu gestures, and selection-menu actions.

### Flutter Integration and Packaging

- Integrate Flutter text input, including the delta input model on Android, IME composition, surrounding text, platform text actions, focus, hardware keyboards, clipboard commands, mouse pointers, touch and mouse gestures, drag selection, scrolling, and scaling.
- Adapt input, gutter, mouse-cursor, selection-handle, scrollbar, font, and selection-menu behavior between mobile and desktop targets.
- Use Dart FFI over the shared SweetEditor C ABI and expose typed Dart action, render, configuration, decoration, search, IME, and visual models.
- Select and bundle native libraries through Dart code assets for Windows x64, Linux x64 and arm64, Android `arm64-v8a` and `x86_64`, macOS x64 and arm64, iOS device arm64, and iOS simulator arm64.
- Provide a synchronization tool for copying repository prebuilts into the Flutter package before local builds and packaging.
