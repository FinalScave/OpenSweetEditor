# Changelog

## 1.0.0-rc1

### Platform Integration

- Provide the `SweetEditoriOS` and `SweetEditorMacOS` Swift Package products for iOS 13 or newer and macOS 11 or newer.
- Offer native UIKit and AppKit editor views together with `UIViewRepresentable` and `NSViewRepresentable` SwiftUI entry points.
- Distribute the shared native runtime as dynamic `SweetEditorCore.framework` slices through iOS device, iOS simulator, and macOS XCFrameworks.

### Editing and Native Input

- Render UTF-16 documents with wrapped visual lines, line numbers, gutters, cursors, selections, current-line effects, folded regions and placeholders, decorations, and horizontal and vertical scrollbars.
- Support interactive insertion, replacement, deletion, backspace, forward delete, cursor and word navigation, line-boundary movement, selection extension, select all, clipboard commands, and standard keyboard shortcuts.
- Support line move, copy, delete, insert-above, and insert-below actions, plus undo/redo, automatic indentation, backspace unindent, composition control, and read-only mode.
- Expose document line snapshots, link-target queries, programmatic insertion at a document position, and batched text-edit application; iOS additionally exposes insertion at the active cursor and public undo, redo, and availability queries.
- Integrate UIKit text input and AppKit `NSTextInputClient` for native IME preedit, selection, candidate-window positioning, surrounding-text synchronization, and committed text.
- Support touch, mouse, trackpad, wheel, drag, pinch, and magnification interactions, including iPad pointer and physical-keyboard input.

### Search and Replace

- Provide case-sensitive, whole-word, regular-expression, wrap-around, and bounded search.
- Support next and previous match navigation, current-match replacement, replace all, search clearing, and observable search state.

### Appearance and Runtime Settings

- Provide built-in light and dark themes, span-based syntax coloring, and custom foreground, background, and font-style registration.
- Configure scale, wrapping, whitespace and line-break rendering, line spacing, content padding, split-line visibility, current-line rendering, fold-arrow behavior, and gutter icon limits.
- Configure read-only state, automatic indentation, backspace unindent, and IME composition.
- Apply single-line and batched spans across syntax, semantic, and overlay layers, with batch text-style registration available on macOS.

### Decorations and Folding

- Support diagnostics, document highlights, text, color, and icon inlay hints, phantom text, CodeLens, links, gutter icons, fold regions, and indent, bracket, flow, and separator guides.
- Provide single-line and batched decoration updates; clear highlights, inlay hints, phantom text, gutter icons, CodeLens, links, diagnostics, document highlights, and guides; clear individual highlight layers or all decorations.
- Support interactive fold markers and folded placeholders, built-in bracket-pair highlighting, and custom gutter and inlay icon rendering through `EditorIconProvider`.
- Expose callbacks for fold toggles and inlay hint, gutter icon, CodeLens, and link clicks.

### Provider Extensions and Completion

- Support attachable decoration providers with visible-range, line-count, and text-change input and merge, replace-all, and replace-range application modes.
- Support asynchronous completion providers, trigger characters, explicit triggering, direct item display, dismissal, sorting, popup keyboard navigation, primary and additional text edits, and linked snippet placeholders.
- Notify iOS hosts when document text changes and provide macOS active-editor lookup, selection previews, typed metadata storage, forwarded key-event handling, optional hover-revealed scrollbars, and an optional performance overlay.
