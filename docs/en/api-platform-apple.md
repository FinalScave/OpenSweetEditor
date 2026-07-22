# Apple Platform API

This document describes the public API exported by the Apple Swift Package in `platform/Apple`. Internal Swift wrappers and the native C API integration are implementation details unless explicitly listed here.

## Requirements and Products

- iOS 14 or newer
- macOS 11 or newer
- Public Swift Package product `SweetEditorIOS`
- Public Swift Package product `SweetEditorMacOS`

Both products use the same entry-point names, distinguished by their Swift modules:

- `SweetEditorView` is a UIKit `UIView` in `SweetEditorIOS` and an AppKit `NSView` in `SweetEditorMacOS`.
- `SweetEditor` is a `UIViewRepresentable` in `SweetEditorIOS` and an `NSViewRepresentable` in `SweetEditorMacOS`.

The two public products re-export `EditorCore`, `Document`, and the support models from `SweetEditorShared`; applications do not link that shared implementation target directly. Most applications should use `SweetEditorView`, whose methods also perform redraw, IME, provider, and state dispatch. Public `EditorCore` is intended for standalone low-level integrations.

## Package and Native Artifacts

- `SweetEditorCoreIOS.xcframework.zip` contains `SweetEditorCoreIOS.xcframework` with iOS device and simulator `SweetEditorCoreIOS.framework` slices.
- `SweetEditorCoreMacOS.xcframework.zip` contains `SweetEditorCoreMacOS.xcframework` with the universal macOS `SweetEditorCoreMacOS.framework` slice.
- Each XCFramework, Framework, module, and SwiftPM binary target uses the same platform-specific name.
- A raw Apple shared-library build produces `libsweeteditor.dylib` independently of framework packaging.

See the [Apple README](../../platform/Apple/README.md) for package integration and build commands.

## Common Native View API

`SweetEditorIOS.SweetEditorView` and `SweetEditorMacOS.SweetEditorView` share the API groups below unless a platform difference is stated.

### Document, Theme, and Content Queries

    var settings: EditorSettings { get }

    func applyTheme(_ theme: EditorTheme)
    func loadDocument(text: String)
    func loadDocument(_ document: Document)
    func getDocument() -> Document?

`Document` can be created from text or a file path. `getText()` returns the complete content with its original line endings, while `getLineText(_:)` and `getLineCount()` provide line-based access. `loadDocument(text:)` remains the convenient text-loading entry point.

### Search and Replace

    func search(_ request: SearchRequest)
    func findNextSearchMatch()
    func findPreviousSearchMatch()
    func replaceCurrentSearchMatch(_ replacement: String)
    func replaceAllSearchMatches(_ replacement: String)
    func clearSearch()
    func getSearchState() -> SearchState

`SearchRequest` supports case sensitivity, whole-word matching, regular expressions, wrap-around, and a maximum match count.

### Editing, Selection, and Navigation

    func insertText(_ text: String)
    func insertText(at position: TextPosition, text: String)
    func replaceText(in range: TextRange, with text: String)
    func deleteText(in range: TextRange)
    func applyTextEdits(_ edits: [TextEdit])
    func setKeyMap(_ bindings: [KeyBinding])

    func getSelectedText() -> String
    func setSelection(_ range: TextRange)
    func getSelection() -> TextRange?
    func hasSelection() -> Bool
    func getCursorPosition() -> TextPosition?
    func setCursorPosition(_ position: TextPosition)
    func gotoPosition(_ position: TextPosition)
    func getWordRangeAtCursor() -> TextRange
    func getWordAtCursor() -> String

    func scrollToLine(_ line: Int, behavior: ScrollBehavior)
    func setScroll(x: Float, y: Float)
    func getScrollMetrics() -> ScrollMetrics
    func getVisibleLineRange() -> IntRange
    func getTotalLineCount() -> Int
    func ensureCursorVisible()

Both views also expose line operations, folding, snippets, linked editing, and explicit clipboard methods. `applyTextEdits(_:)` applies the supplied edits as one undoable operation. Every View mutation dispatches the resulting Core action so rendering, IME, providers, and public state stay synchronized.

### Low-Level Core API

`EditorCore` exposes the same typed operation groups as the other platform bindings: document loading, viewport and appearance configuration, rendering, gesture and key handling, text and line editing, cursor and selection control, IME, scrolling, decorations, search, folding, snippets, linked editing, and history. Native handles, binary payload overloads, font callbacks, and platform scale synchronization remain implementation details.

Core editing actions return a non-optional `EditorActionResult`; query results remain optional where absence is meaningful. `EditorCore` construction accepts an optional `EditorOptions`, and its public decoration and gesture APIs use `SpanLayer`, `CurrentLineRenderMode`, and `GestureEvent` rather than raw transport values. Callers that use `EditorCore` directly are responsible for consuming action results and integrating redraw and platform services. A `SweetEditorView` does not expose its owned Core instance because bypassing View dispatch would desynchronize the UI.

### Effective Runtime Settings

Use the public `settings` object for runtime configuration:

    settings.setScale(_:)
    settings.setEditorTextSize(_:)
    settings.setTypeface(_:)
    settings.setFoldArrowMode(_:)
    settings.setWrapMode(_:)
    settings.setRenderWhitespace(_:)
    settings.setRenderLineBreaks(_:)
    settings.setLineSpacing(add:mult:)
    settings.setContentStartPadding(_:)
    settings.setShowSplitLine(_:)
    settings.setGutterSticky(_:)
    settings.setGutterVisible(_:)
    settings.setCurrentLineRenderMode(_:)
    settings.setAutoIndentMode(_:)
    settings.setBackspaceUnindent(_:)
    settings.setReadOnly(_:)
    settings.setCompositionEnabled(_:)
    settings.setMaxGutterIcons(_:)
    settings.setDecorationScrollRefreshMinIntervalMs(_:)
    settings.setDecorationOverscanViewportMultiplier(_:)

### Language and Metadata

Both native views expose:

    var languageConfiguration: LanguageConfiguration? { get }
    var metadata: EditorMetadata?

    func setLanguageConfiguration(_ config: LanguageConfiguration?)

The language configuration updates Core editing behavior and is included in provider contexts. Metadata is host-defined context shared with completion, decoration, and newline providers.

### Styles and Decorations

Both native views expose:

    func registerTextStyle(styleId: Int32, color: Int32, fontStyle: Int32)
    func registerTextStyle(styleId: Int32, color: Int32, backgroundColor: Int32, fontStyle: Int32)
    func registerBatchTextStyles(_ stylesById: [Int32: TextStyle])

    func setLineSpans(line: Int, layer: SpanLayer, spans: [StyleSpan])
    func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [StyleSpan]])

    func setLineInlayHints(line: Int, hints: [InlayHint])
    func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHint]])
    func setLinePhantomTexts(line: Int, phantoms: [PhantomText])
    func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomText]])
    func setLineGutterIcons(line: Int, icons: [GutterIcon])
    func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]])
    func setLineCodeLens(line: Int, items: [CodeLensItem])
    func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensItem]])
    func setLineLinks(line: Int, links: [LinkSpan])
    func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]])
    func getLinkTargetAt(line: Int, column: Int) -> String

    func setLineDiagnostics(line: Int, items: [Diagnostic])
    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [Diagnostic]])
    func setLineDocumentHighlights(line: Int, items: [DocumentHighlight])
    func setBatchLineDocumentHighlights(_ highlightsByLine: [Int: [DocumentHighlight]])

    func setIndentGuides(_ guides: [IndentGuide])
    func setBracketGuides(_ guides: [BracketGuide])
    func setFlowGuides(_ guides: [FlowGuide])
    func setSeparatorGuides(_ guides: [SeparatorGuide])
    func setFoldRegions(_ regions: [FoldRegion])

    func clearHighlights()
    func clearHighlights(layer: SpanLayer)
    func clearInlayHints()
    func clearPhantomTexts()
    func clearGutterIcons()
    func clearCodeLens()
    func clearLinks()
    func clearGuides()
    func clearDiagnostics()
    func clearDocumentHighlights()
    func clearAllDecorations()

`EditorTheme` owns the active `textStyles` map. Apple views default to `xcodeDark()` and also provide `xcodeLight()`; `dark()` and `light()` remain the cross-platform presets. `applyTheme(_:)` registers the theme's style map with Core. Use `defineTextStyle(_:style:)` to add or replace a style in a custom theme. Direct style registration remains available for callers that do not manage styles through a theme.

`clearSearch()` is listed in the search API above. Fold regions can be removed by setting an empty region list; there is no separate public `clearFoldRegions` method.

### Decoration Providers

    func attachDecorationProvider(_ provider: DecorationProvider)
    func detachDecorationProvider(_ provider: DecorationProvider)
    func requestDecorationRefresh()

`DecorationProvider` receives visible-line range, total line count, text changes, language configuration, and editor metadata through `DecorationContext`. `DecorationResult` directly uses Core adornment types and supports `merge`, `replaceAll`, and `replaceRange` modes for the supported decoration families.

### Completion Providers

    func attachCompletionProvider(_ provider: CompletionProvider)
    func detachCompletionProvider(_ provider: CompletionProvider)
    func triggerCompletion()
    func showCompletionItems(_ items: [CompletionItem])
    func dismissCompletion()

Completion providers return results asynchronously through `CompletionReceiver`. `CompletionContext` includes the current language configuration and editor metadata. Provider results are merged and sorted. Completion items support direct text insertion, primary text edits, additional text edits, and snippet insertion with linked placeholders.

### Newline Providers

    func attachNewLineActionProvider(_ provider: NewLineActionProvider)
    func detachNewLineActionProvider(_ provider: NewLineActionProvider)

Providers receive `NewLineContext`, including the caret location, current line text, language configuration, and editor metadata. The first provider that returns an action supplies the text inserted for Enter.

### Icons and Interaction Callbacks

    var editorIconProvider: EditorIconProvider?

    var onFoldToggle: ((FoldToggleEvent) -> Void)?
    var onInlayHintClick: ((InlayHintClickEvent) -> Void)?
    var onGutterIconClick: ((GutterIconClickEvent) -> Void)?
    var onCodeLensClick: ((CodeLensClickEvent) -> Void)?
    var onLinkClick: ((LinkClickEvent) -> Void)?
    var onTextChanged: ((TextChangedEvent) -> Void)?
    var onCursorChanged: ((CursorChangedEvent) -> Void)?
    var onSelectionChanged: ((SelectionChangedEvent) -> Void)?
    var onScrollChanged: ((ScrollChangedEvent) -> Void)?
    var onScaleChanged: ((ScaleChangedEvent) -> Void)?
    var onDocumentLoaded: ((DocumentLoadedEvent) -> Void)?
    var onLongPress: ((LongPressEvent) -> Void)?
    var onDoubleTap: ((DoubleTapEvent) -> Void)?
    var onContextMenu: ((ContextMenuEvent) -> Void)?

`EditorIconProvider` supplies `CGImage` values for gutter and icon inlay rendering. Completion popup colors come from the canonical completion fields on `EditorTheme`, matching the other platform integrations.

## iOS-Specific Public API

`SweetEditorIOS.SweetEditorView` additionally exposes:

    var selectionMenuItemProvider: SelectionMenuItemProvider?
    var onSelectionMenuItemClick: ((SelectionMenuItem) -> Void)?
    var isSelectionMenuShowing: Bool { get }

    func dismissSelectionMenu()
    func insertText(_ text: String)
    func undo()
    func redo()
    func canUndo() -> Bool
    func canRedo() -> Bool

`SelectionMenuItemProvider` returns the complete item list for the next menu show cycle. Replacing the provider does not mutate an already visible menu. Built-in item identifiers are available from `SelectionMenuItem`, and custom item activation is delivered through `onSelectionMenuItemClick`.

The UIKit implementation integrates `UITextInput`, `UIKeyInput`, marked text, surrounding-text queries, selection ranges, the floating selection menu, candidate positioning, touch gestures, pinch scaling, iPad pointer input, and physical-keyboard shortcuts.

`SweetEditor` exposes only:

- `theme`, defaulting to `EditorTheme.xcodeDark()`
- fold, inlay hint, gutter icon, CodeLens, and link callbacks

It does not directly expose document loading, settings, providers, completion control, or document-text binding. Use `SweetEditorView` when those APIs are required.

## macOS-Specific Public API

`SweetEditorMacOS.SweetEditorView` additionally exposes:

    var showsPerformanceOverlay: Bool

The AppKit implementation integrates `NSTextInputClient`, marked text, surrounding-text queries, candidate positioning, mouse and trackpad input, wheel scrolling, magnification, clipboard shortcuts, and standard AppKit key bindings.

`SweetEditor` exposes:

- `theme`, defaulting to `EditorTheme.xcodeDark()`
- `showsPerformanceOverlay`
- fold, inlay hint, gutter icon, CodeLens, and link callbacks

It does not directly expose document loading, settings, providers, completion control, or metadata. Use `SweetEditorView` when those APIs are required.

## Public Support Types

The public products re-export the public support types needed by the APIs above, including:

- `EditorSettings` and its semantic setting enums
- `EditorCore` and `Document`
- `SearchRequest`, `SearchOptions`, and `SearchState`
- `TextPosition`, `TextRange`, and `TextEdit`
- Style and decoration models
- `DecorationProvider`, `DecorationReceiver`, `DecorationContext`, and `DecorationResult`
- `CompletionProvider`, `CompletionReceiver`, `CompletionContext`, `CompletionResult`, and `CompletionItem`
- `SelectionMenuItem` and `SelectionMenuItemProvider` on iOS
- `EditorIconProvider` and platform click-event types
- `EditorMetadata`; both native views expose it through the Swift-native `metadata` property

## Known Limitations

- `CompletionItem.filterText` is stored but is not used for local completion filtering.
- The SwiftUI wrappers intentionally expose a smaller surface than the native UIKit and AppKit views.
- The Apple implementation imports the canonical `c_api.h` exported by the platform-specific core Framework; it does not maintain a separate C declaration header.

## Implementation References

- Package manifest: [`platform/Apple/Package.swift`](../../platform/Apple/Package.swift)
- Shared Swift implementation: [`platform/Apple/SweetEditor-Shared`](../../platform/Apple/SweetEditor-Shared)
- Public iOS wrapper: [`platform/Apple/SweetEditor-iOS/SweetEditor.swift`](../../platform/Apple/SweetEditor-iOS/SweetEditor.swift)
- Public UIKit view: [`platform/Apple/SweetEditor-iOS/SweetEditorView.swift`](../../platform/Apple/SweetEditor-iOS/SweetEditorView.swift)
- Public macOS view: [`platform/Apple/SweetEditor-macOS/SweetEditorView.swift`](../../platform/Apple/SweetEditor-macOS/SweetEditorView.swift)
- macOS SwiftUI wrapper: [`platform/Apple/SweetEditor-macOS/SweetEditor.swift`](../../platform/Apple/SweetEditor-macOS/SweetEditor.swift)
- Public module exports are declared with each platform entry point.
- Canonical C API: [`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h)

See the [Apple changelog](../../platform/Apple/CHANGELOG.md) for release contents.
