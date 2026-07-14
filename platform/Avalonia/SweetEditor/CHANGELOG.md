# Changelog

## 1.0.0-rc1

### Components and Public API

- Provide `SweetEditorControl` for direct UI composition and `SweetEditorController` for external or MVVM-style command handling, including queued commands and `WhenReady` lifecycle support before attachment.
- Expose `Document`, `EditorSettings`, `EditorTheme`, `LanguageConfiguration`, metadata, keymap, layout-metric, position-geometry, scroll-metric, visible-range, and document-query APIs through the control and controller.
- Provide configurable dark and light themes and settings for font family and size, scale, wrapping, IME composition, line spacing, content padding, gutter visibility and stickiness, fold arrows, current-line rendering, whitespace and line-break markers, automatic indentation, backspace unindent, read-only mode, gutter icon limits, and decoration refresh and overscan behavior.
- Provide configurable keymaps with a VS Code preset, custom bindings, and host-defined commands.
- Configure bracket and auto-closing pairs, tab size, spaces-for-tabs behavior, and line and block comment metadata through `LanguageConfiguration`.

### Editing and Rendering

- Support document loading, text insertion, replacement, deletion, batched text edits, cursor and selection control, word queries, line navigation, scrolling, line move, copy, delete, and insert operations, clipboard actions, and undo/redo.
- Support case-sensitive, whole-word, regular-expression, wrap-around, and bounded search, including match navigation, current-match replacement, replace all, clearing, and search-state queries.
- Render through Avalonia `DrawingContext` and Skia with native text layout, viewport clipping, wrapping, line numbers, gutters, fold markers and placeholders, current-line effects, cursors, selections, mobile selection handles, scrollbars, invisible characters, and an optional performance overlay.
- Support syntax, semantic, and overlay style layers; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; indent, bracket, flow, and separator guides; matched-bracket highlights; and configurable range effects.
- Support fold regions, targeted and bulk fold/unfold, snippets, tab stops, linked editing, and editor-owned inline suggestions with accept and dismiss flows.

### Language Tooling and Extension Points

- Provide cancellable completion providers with invoked, trigger-character, and retrigger contexts, primary and additional text edits, snippet completion, editor-owned popup UI, and custom Avalonia completion item controls.
- Provide decoration providers with visible-range, text-change, language, and metadata context and merge, replace-all, and replace-range modes across all supported decoration types.
- Provide chained new-line action providers, custom editor icon providers, inline-suggestion listeners, and customizable mobile selection-menu item providers and listeners.

### Input and Interaction

- Integrate keyboard shortcuts, clipboard, mouse selection and wheel scrolling, touch tapping and drag selection, long press, double tap, direct pinch zoom, touchpad magnification, scroll gestures and inertia, pointer cursors, Avalonia text input, and IME synchronization.
- Adapt mobile input with Android `InputPane` occlusion handling, IME avoidance, popup repositioning, touch-first selection handles, and editor-owned selection menus while retaining desktop context-menu behavior.
- Publish text, cursor, selection, scroll, scale, document-loaded, long-press, double-tap, context-menu, inlay-hint, gutter-icon, fold-toggle, CodeLens, link, selection-menu, completion, and inline-suggestion events through the control and controller.

### Native Asset Support

- Target .NET 10 and Avalonia 12.0.5 with managed source integration through `ProjectReference`, plus configured repository demo hosts for Windows, Linux, macOS, Android, and iOS.
- Integrate repository native assets for Windows x64, Linux x64, macOS x64 and arm64, Android `arm64-v8a` and `x86_64`, and iOS arm64 device and arm64 simulator targets. Android and iOS asset items are configured by the repository host projects and targets rather than exported transitively; external mobile hosts must add equivalent platform-specific native-library items.
