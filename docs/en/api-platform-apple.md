# Apple Platform API

This document describes the public API exported by the Apple Swift Package in `platform/Apple`. Internal Swift wrappers and the C bridge are implementation details unless explicitly listed here.

## Requirements and Products

- iOS 13 or newer
- macOS 11 or newer
- Public Swift Package product `SweetEditoriOS`
- Public Swift Package product `SweetEditorMacOS`

The public native entry points are:

- `SweetEditorViewiOS`, a UIKit `UIView`
- `SweetEditorViewMacOS`, an AppKit `NSView`
- `SweetEditorSwiftUIViewiOS`, a `UIViewRepresentable` wrapper
- `SweetEditorSwiftUIMacOS`, an `NSViewRepresentable` wrapper

`SweetEditorCoreInternal`, `SweetEditorBridge`, `SweetEditorCore`, and `SweetDocument` are not public application entry points. The two public products re-export public support models from `SweetEditorCoreInternal`, but applications do not link that internal target directly.

## Package and Native Artifacts

- `SweetEditorCoreIOS.xcframework` contains iOS device and simulator framework slices.
- `SweetEditorCoreOSX.xcframework` contains the macOS universal framework slice.
- The XCFrameworks contain dynamic `SweetEditorCore.framework` binaries.
- A raw Apple shared-library build produces `libsweeteditor.dylib` independently of framework packaging.

See the [Apple README](../../platform/Apple/README.md) for package integration and build commands.

## Common Native View API

`SweetEditorViewiOS` and `SweetEditorViewMacOS` share the API groups below unless a platform difference is stated.

### Document, Theme, and Content Queries

    var settings: EditorSettings { get }

    func applyTheme(isDark: Bool)
    func loadDocument(text: String)
    func documentLines() -> [String]

Only text loading through `loadDocument(text:)` is public. File-backed `SweetDocument` construction remains internal.

### Search and Replace

    func search(_ request: SearchRequest)
    func findNextSearchMatch()
    func findPreviousSearchMatch()
    func replaceCurrentSearchMatch(_ replacement: String)
    func replaceAllSearchMatches(_ replacement: String)
    func clearSearch()
    func getSearchState() -> SearchState

`SearchRequest` supports case sensitivity, whole-word matching, regular expressions, wrap-around, and a maximum match count.

### External Text Edits

    func insertText(at position: TextPosition, text: String)
    func applyTextEdits(_ edits: [TextEdit])

`applyTextEdits(_:)` applies the supplied edits as one undoable operation. Direct range replacement, deletion, cursor control, and selection control are internal and are not public View methods.

The native views still provide interactive cursor movement, selection, clipboard commands, line actions, undo and redo shortcuts, scrolling, folding, and IME input through UIKit or AppKit event handling.

### Effective Runtime Settings

Use the public `settings` object for runtime configuration:

    settings.setScale(_:)
    settings.setFoldArrowMode(_:)
    settings.setWrapMode(_:)
    settings.setRenderWhitespace(_:)
    settings.setRenderLineBreaks(_:)
    settings.setLineSpacing(add:mult:)
    settings.setContentStartPadding(_:)
    settings.setShowSplitLine(_:)
    settings.setCurrentLineRenderMode(_:)
    settings.setAutoIndentMode(_:)
    settings.setBackspaceUnindent(_:)
    settings.setReadOnly(_:)
    settings.setCompositionEnabled(_:)
    settings.setMaxGutterIcons(_:)

The native views also retain compatibility wrappers for maximum gutter icons, fold-arrow mode, line spacing, content padding, split-line visibility, current-line mode, whitespace rendering, line-break rendering, read-only mode, integer wrap mode, and scale.

### Styles and Decorations

Both native views expose:

    func applyDecorations(_ decorations: EditorResolvedDecorations, clearExisting: Bool = true)

    func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32)
    func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32)

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

`clearSearch()` is listed in the search API above. Fold regions can be removed by setting an empty region list; there is no separate public `clearFoldRegions` method.

### Decoration Providers

    func attachDecorationProvider(_ provider: DecorationProvider)
    func detachDecorationProvider(_ provider: DecorationProvider)
    func requestDecorationRefresh()

`DecorationProvider` receives visible-line range, total line count, and text changes through `DecorationContext`. `DecorationResult` supports `merge`, `replaceAll`, and `replaceRange` modes for the supported decoration families.

### Completion Providers

    func attachCompletionProvider(_ provider: CompletionProvider)
    func detachCompletionProvider(_ provider: CompletionProvider)
    func triggerCompletion()
    func showCompletionItems(_ items: [CompletionItem])
    func dismissCompletion()

Completion providers return results asynchronously through `CompletionReceiver`. Provider results are merged and sorted. Completion items support direct text insertion, primary text edits, additional text edits, and snippet insertion with linked placeholders.

### Icons and Interaction Callbacks

    var editorIconProvider: EditorIconProvider?
    func setEditorIconProvider(_ provider: EditorIconProvider?)

    var onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    var onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    var onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?
    var onCodeLensClick: ((SweetEditorCodeLensClickEvent) -> Void)?
    var onLinkClick: ((SweetEditorLinkClickEvent) -> Void)?

`EditorIconProvider` supplies `CGImage` values for gutter and icon inlay rendering.

## iOS-Specific Public API

`SweetEditorViewiOS` additionally exposes:

    var onDocumentTextChanged: ((String) -> Void)?

    func insertText(_ text: String)
    func undo()
    func redo()
    func canUndo() -> Bool
    func canRedo() -> Bool

The UIKit implementation integrates `UITextInput`, `UIKeyInput`, marked text, surrounding-text queries, selection ranges, candidate positioning, touch gestures, pinch scaling, iPad pointer input, and physical-keyboard shortcuts.

`SweetEditorSwiftUIViewiOS` exposes only:

- `isDarkTheme`
- fold, inlay hint, gutter icon, CodeLens, and link callbacks

It does not directly expose document loading, settings, providers, completion control, or document-text binding. Use `SweetEditorViewiOS` when those APIs are required.

## macOS-Specific Public API

`SweetEditorViewMacOS` additionally exposes:

    static weak var activeEditor: SweetEditorViewMacOS?
    var scrollbarHoverRevealEnabled: Bool
    var showsPerformanceOverlay: Bool

    func registerBatchStyles(
        _ stylesById: [UInt32: (color: Int32, backgroundColor: Int32, fontStyle: Int32)]
    )
    func selectedTextPreview(maxLength: Int = 80) -> String?
    func setMetadata<T: EditorMetadata>(_ metadata: T?)
    func getMetadata<T: EditorMetadata>() -> T?
    func handleForwardedKeyDown(_ event: NSEvent)
    func applyEditorSettings(_ settings: EditorSettings)

The metadata methods are not exposed by `SweetEditorViewiOS` or either SwiftUI wrapper.

The AppKit implementation integrates `NSTextInputClient`, marked text, surrounding-text queries, candidate positioning, mouse and trackpad input, wheel scrolling, magnification, clipboard shortcuts, and standard AppKit key bindings.

`SweetEditorSwiftUIMacOS` exposes:

- `isDarkTheme`
- `showsPerformanceOverlay`
- fold, inlay hint, gutter icon, CodeLens, and link callbacks

It does not directly expose document loading, settings, providers, completion control, or metadata. Use `SweetEditorViewMacOS` when those APIs are required.

## Public Support Types

The public products re-export the public support types needed by the APIs above, including:

- `EditorSettings` and its semantic setting enums
- `SearchRequest`, `SearchOptions`, and `SearchState`
- `TextPosition`, `TextRange`, and `TextEdit`
- Style and decoration models
- `DecorationProvider`, `DecorationReceiver`, `DecorationContext`, and `DecorationResult`
- `CompletionProvider`, `CompletionReceiver`, `CompletionContext`, `CompletionResult`, and `CompletionItem`
- `EditorIconProvider` and platform click-event types
- `EditorMetadata`; public `setMetadata` and `getMetadata` entry points exist only on the native macOS view

## Known Limitations

- There is no public language-configuration setter on either native View. `DecorationContext.languageConfiguration` and `CompletionContext.languageConfiguration` therefore remain `nil` through the current public path.
- `EditorSettings.setEditorTextSize` and `setTypeface` update stored values but are not applied to the native core or text measurer.
- `EditorSettings.setDecorationScrollRefreshMinIntervalMs` and `setDecorationOverscanViewportMultiplier` are not connected to `DecorationProviderManager`.
- `CompletionItem.filterText` is stored but is not used for local completion filtering.
- The Apple views do not drive the core `tickAnimations` API, so core-managed fling animation is not part of the current Apple surface.
- Although the macOS source declares `addNewLineActionProvider` and `removeNewLineActionProvider`, their provider, context, and result types are internal. Applications cannot call these methods or implement that provider contract.
- The SwiftUI wrappers intentionally expose a smaller surface than the native UIKit and AppKit views.
- The C bridge is maintained manually and must be checked when the shared C API changes.

## Implementation References

- Package manifest: [`platform/Apple/Package.swift`](../../platform/Apple/Package.swift)
- Public iOS wrapper: [`platform/Apple/Sources/SweetEditoriOS/SweetEditorSwiftUIiOS.swift`](../../platform/Apple/Sources/SweetEditoriOS/SweetEditorSwiftUIiOS.swift)
- Internal UIKit editor: [`platform/Apple/Sources/SweetEditoriOS/SweetEditorViewiOS.swift`](../../platform/Apple/Sources/SweetEditoriOS/SweetEditorViewiOS.swift)
- Public macOS view: [`platform/Apple/Sources/SweetEditorMacOS/SweetEditorViewMacOS.swift`](../../platform/Apple/Sources/SweetEditorMacOS/SweetEditorViewMacOS.swift)
- macOS SwiftUI wrapper: [`platform/Apple/Sources/SweetEditorMacOS/SweetEditorSwiftUIMacOS.swift`](../../platform/Apple/Sources/SweetEditorMacOS/SweetEditorSwiftUIMacOS.swift)
- Public re-exports: [`platform/Apple/Sources/SweetEditoriOS/PublicExports.swift`](../../platform/Apple/Sources/SweetEditoriOS/PublicExports.swift) and [`platform/Apple/Sources/SweetEditorMacOS/PublicExports.swift`](../../platform/Apple/Sources/SweetEditorMacOS/PublicExports.swift)
- Manual C bridge: [`platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`](../../platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h)

See the [Apple changelog](../../platform/Apple/CHANGELOG.md) for release contents.
