# Changelog

## 1.0.0-rc1

### Editor and Public API

- Provide the native `SweetEditor` Android view, the low-level `EditorCore` bridge, and string- or file-backed `Document` APIs with text, line, and position queries.
- Support text insertion, position-based insertion, range replacement and deletion, batched text edits, line move, copy, delete, and insert commands, and undo/redo.
- Support cursor and selection control, word queries, select all, clipboard operations, document navigation, position geometry, scrolling, visible-line queries, and scroll metrics.
- Support case-sensitive, whole-word, regular-expression, wrap-around, and bounded search, including match navigation, current-match replacement, replace all, clearing, and search-state queries.
- Support code folding and placeholders, fold visibility queries, snippets, tab stops, and linked editing.
- Provide dark and light themes, custom text styles and colors, language configuration, bracket and auto-closing pairs, tab size, spaces-for-tabs behavior, metadata, icon providers, and configurable keymaps with VS Code, JetBrains, and Sublime presets.
- Provide runtime settings for typeface, text size, scale, wrapping, whitespace and line-break rendering, line spacing, content padding, split lines, gutter visibility and stickiness, fold arrows, current-line rendering, auto-indent, backspace unindent, read-only mode, gutter icon limits, decoration refresh policy, and cursor animation.

### Rendering and Decorations

- Render through Android Canvas and Paint with viewport-based layout, proportional or monospaced typefaces, wrapped visual lines, selections, cursors, folding, guides, gutters, scrollbars, and configurable range effects.
- Support registered styles and syntax, semantic, and overlay spans, plus inlay hints, phantom text, diagnostics, document highlights, gutter icons, CodeLens, links, and matched-bracket highlights.
- Support indent, bracket, flow, and separator guides; single-line and batched decoration updates; layer-specific clearing; and complete decoration clearing.

### Language Tooling and Extension Points

- Provide asynchronous `DecorationProvider` updates with cancellation, visible-range context, incremental refresh, and merge, replace-all, or replace-range application modes.
- Provide cancellable asynchronous `CompletionProvider` requests and synchronous `NewLineActionProvider` chains.
- Support automatic completion triggers and re-triggering, snippets, primary and additional text edits, keyboard navigation, custom completion item views, and programmatically supplied completion items.
- Provide inline suggestion ghost text and actions, customizable mobile selection menus and desktop-style context menus, custom editor icons and keyboard commands, and language metadata.
- Publish typed events for text, cursor, selection, scroll, scale, document load, folding, gutter icons, inlay hints, CodeLens, links, long press, double tap, context menus, and custom menu items.

### Android Integration and Packaging

- Integrate Android `InputConnection` composition, surrounding-text synchronization, cursor and selection updates, batch edits, soft-keyboard lifecycle, hardware keyboard input, and read-only behavior.
- Integrate clipboard access, touch and mouse gestures, drag selection, selection handles, scrolling, scaling, hover and pointer feedback, completion popups, selection menus, and an optional performance overlay.
- Use the shared C++ editor core through Java and JNI while exposing Android-native controls and models, with automatic loading of `libsweeteditor`.
- Package the `com.qiplat:sweeteditor` Android library with Maven publishing and Gradle, CMake, and Android NDK source builds for Android API 21 or newer on `arm64-v8a` and `x86_64`.
