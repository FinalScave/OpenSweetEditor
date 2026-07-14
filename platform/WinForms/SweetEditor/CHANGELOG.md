# Changelog

## 1.0.0-rc1

### Components and Public API

- Provide the native `SweetEditorControl` component together with `Document`, `EditorSettings`, `EditorTheme`, `LanguageConfiguration`, metadata, geometry, scroll-metric, visible-range, and document-query APIs.
- Provide configurable dark and light themes and settings for font family and size, scale, wrapping, line spacing, content padding, gutter visibility and stickiness, fold arrows, current-line rendering, whitespace and line-break markers, automatic indentation, backspace unindent, read-only mode, gutter icon limits, decoration refresh intervals, and decoration overscan.
- Provide configurable keymaps with VS Code, JetBrains, and Sublime presets, custom bindings, and host-defined commands.
- Configure bracket and auto-closing pairs, tab size, spaces-for-tabs behavior, and line and block comment metadata through `LanguageConfiguration`.

### Editing and Rendering

- Support document loading, text insertion, replacement, deletion, batched text edits, cursor and selection control, word queries, line navigation, scrolling, line move, copy, delete, and insert operations, clipboard actions, and undo/redo.
- Support case-sensitive, whole-word, regular-expression, wrap-around, and bounded search, including match navigation, current-match replacement, replace all, clearing, and search-state queries.
- Render through GDI+ with platform text measurement, viewport-based visual lines, wrapping, line numbers, configurable gutters, fold markers and placeholders, current-line effects, cursors, selections, scrollbars, invisible characters, and an optional performance overlay.
- Support syntax, semantic, and overlay style layers; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; indent, bracket, flow, and separator guides; matched-bracket highlights; and configurable range effects.
- Support fold regions, targeted and bulk fold/unfold, snippets, tab stops, and linked-editing navigation.

### Language Tooling and Extension Points

- Provide cancellable completion providers with invoked, trigger-character, and retrigger contexts, primary and additional text edits, snippet completion, editor-owned popup UI, and custom completion item rendering.
- Provide decoration providers with visible-range, text-change, language, and metadata context and merge, replace-all, and replace-range modes across all supported decoration types.
- Provide chained new-line action providers for host-defined smart indentation, comment continuation, and bracket-aware insertion, plus custom editor icon providers.

### WinForms Integration and Packaging

- Integrate WinForms keyboard, configurable shortcuts, mouse and drag selection, wheel scrolling, clipboard, focus, pointer-cursor updates, and Windows IME preedit, commit, cancel, and surrounding-text deletion flows.
- Publish text, cursor, selection, scroll, scale, document-loaded, long-press, double-tap, context-menu, inlay-hint, gutter-icon, fold-toggle, CodeLens, and link events.
- Target .NET 8 WinForms on Windows x64 and ship `sweeteditor.dll` in the NuGet runtime layout for automatic P/Invoke loading.
