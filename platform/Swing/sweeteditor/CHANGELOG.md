# Changelog

## 1.0.0-rc1

### Components and Public API

- Provide the Java2D `SweetEditor` component together with `Document`, `EditorSettings`, `EditorTheme`, `LanguageConfiguration`, metadata, geometry, scroll-metric, visible-range, document-query, and generic event-bus APIs.
- Provide configurable dark and light themes and settings for font family and size, scale, wrapping, line spacing, content padding, gutter visibility and stickiness, fold arrows, current-line rendering, whitespace and line-break markers, automatic indentation, backspace unindent, read-only mode, gutter icon limits, decoration refresh and overscan behavior, and cursor and gutter animations.
- Provide configurable keymaps with VS Code, JetBrains, and Sublime presets, custom bindings, and host-defined shortcut handlers.
- Configure bracket and auto-closing pairs, tab size, spaces-for-tabs behavior, and line and block comment metadata through `LanguageConfiguration`.

### Editing and Rendering

- Support document loading, text insertion, replacement, deletion, batched text edits, cursor and selection control, word queries, line navigation, scrolling, line move, copy, delete, and insert operations, clipboard actions, and undo/redo.
- Support case-sensitive, whole-word, regular-expression, wrap-around, and bounded search, including match navigation, current-match replacement, replace all, clearing, and search-state queries.
- Render through Java2D with platform font measurement, viewport-based visual lines, wrapping, line numbers, gutters, animated fold markers and split boundaries, fold placeholders, current-line effects, animated cursors, selections, scrollbars, invisible characters, and an optional performance overlay.
- Support syntax, semantic, and overlay style layers; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; indent, bracket, flow, and separator guides; matched-bracket highlights; and configurable range effects.
- Support fold regions, targeted and bulk fold/unfold, snippets, tab stops, linked editing, and inline suggestions with accept and dismiss behavior.

### Language Tooling and Extension Points

- Provide cancellable completion providers with invoked, trigger-character, and retrigger contexts, primary and additional text edits, snippet completion, editor-owned popup UI, and custom Swing completion cell rendering.
- Provide decoration providers with visible-range, text-change, language, and metadata context and merge, replace-all, and replace-range modes across all supported decoration types.
- Provide chained new-line action providers, custom editor icon providers, inline-suggestion listeners, typed event subscriptions, and custom keyboard commands.

### Swing Integration and Packaging

- Integrate Swing keyboard input, configurable shortcuts, clipboard, mouse and drag selection, wheel scrolling, pointer-cursor changes, focus handling, and Java input-method preedit, commit, cancel, caret-location, surrounding-text, and selected-text flows.
- Publish text, cursor, selection, scroll, scale, document-loaded, long-press, double-tap, context-menu, inlay-hint, gutter-icon, fold-toggle, CodeLens, and link events through the typed event bus.
- Target Java 22 through the Foreign Function & Memory API and require `--enable-native-access=ALL-UNNAMED`; the current repository build also enables preview features.
- Support repository Gradle project dependencies and locally built JAR consumption. Bundle native libraries in the JAR for Windows x64, Linux x64 and arm64, and macOS x64 and arm64; load from `sweeteditor.lib.path` first, then extract a bundled JAR resource, and finally fall back to `java.library.path` through `System.loadLibrary`. Maven publication is not configured in this release.
