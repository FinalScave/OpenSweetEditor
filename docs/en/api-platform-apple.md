# Apple Platform API

This document maps to the current Apple SPM SDK implementation (root: `platform/Apple`).

## Overview

- Public products: `SweetEditoriOS`, `SweetEditorMacOS`
- Internal core target: `SweetEditorCore` (not exposed directly)
- Core communication path: Swift -> manual C bridge -> C++ Core

Key files:

- C bridge: `platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`
- Swift core wrapper: `platform/Apple/Sources/SweetEditorCoreInternal/api/SweetEditorCore.swift`
- Document object: `platform/Apple/Sources/SweetEditorCoreInternal/runtime/SweetDocument.swift`

## Shared Core Features (for iOS and macOS)

`SweetEditorCore` is the shared feature layer for iOS and macOS. It handles:

- UTF-16 pointer conversion
- Binary payload decoding (including `LayoutMetrics`)
- Text measure callbacks and render-model building

### Basic and Rendering

```swift
func setViewport(width: Int, height: Int)
func setDocument(_ document: SweetDocument)
func buildRenderModel() -> EditorRenderModel?
func getLayoutMetrics() -> LayoutMetrics?
func setScroll(scrollX: Float, scrollY: Float)
func getScrollMetrics() -> ScrollMetrics
func resetMeasurer()
```

### Input and Text Edit

```swift
func handleGestureEvent(
    type: SEEventType,
    points: [(Float, Float)],
    modifiers: SEModifier = [],
    wheelDeltaX: Float = 0,
    wheelDeltaY: Float = 0,
    directScale: Float = 1) -> GestureResultData?

func handleKeyEvent(
    keyCode: SEKeyCode,
    text: String? = nil,
    modifiers: SEModifier = []) -> KeyEventResultData?

func insertText(_ text: String) -> TextEditResultLite?
func replaceText(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int, newText: String) -> TextEditResultLite?
func deleteText(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) -> TextEditResultLite?
```

### Line Actions

```swift
func moveLineUp() -> TextEditResultLite?
func moveLineDown() -> TextEditResultLite?
func copyLineUp() -> TextEditResultLite?
func copyLineDown() -> TextEditResultLite?
func deleteLine() -> TextEditResultLite?
func insertLineAbove() -> TextEditResultLite?
func insertLineBelow() -> TextEditResultLite?
```

### Cursor, Word, IME, Read-only, Auto Indent

```swift
func getSelectedText() -> String
func getCursorPosition() -> (line: Int, column: Int)?
func getWordRangeAtCursor() -> (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)
func getWordAtCursor() -> String

func compositionStart()
func compositionUpdate(_ text: String)
func compositionEnd(_ committedText: String?)
func compositionCancel()
func isComposing() -> Bool

func setReadOnly(_ readOnly: Bool)
func isReadOnly() -> Bool

enum AutoIndentMode: Int32
func setAutoIndentMode(_ mode: AutoIndentMode)
func getAutoIndentMode() -> AutoIndentMode

struct CursorRect { let x: CGFloat; let y: CGFloat; let height: CGFloat }
func getPositionRect(line: Int, column: Int) -> CursorRect
func getCursorRect() -> CursorRect
```

### Styles / Decorations / Folding / Linked Editing

```swift
func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32)
func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32)
func clearHighlights()
func clearHighlights(layer: UInt8)
func setLineSpans(line: Int, layer: UInt8 = 0, spans: [StyleSpan])
func setBatchLineSpans(layer: UInt8, spansByLine: [Int: [StyleSpan]])

func setLineDiagnostics(line: Int, items: [DiagnosticItem])
func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticItem]])
func clearDiagnostics()

func setLineInlayHints(line: Int, hints: [InlayHintPayload])
func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHintPayload]])
func clearInlayHints()
func setLinePhantomTexts(line: Int, phantoms: [PhantomTextPayload])
func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomTextPayload]])
func clearPhantomTexts()
func clearAllDecorations()

func setLineGutterIcons(line: Int, icons: [GutterIcon])
func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]])
func clearGutterIcons()
func setMaxGutterIcons(_ count: UInt32)

func setIndentGuides(_ guides: [IndentGuidePayload])
func setBracketGuides(_ guides: [BracketGuidePayload])
func setFlowGuides(_ guides: [FlowGuidePayload])
func setSeparatorGuides(_ guides: [SeparatorGuidePayload])
func clearGuides()

func setFoldRegions(_ regions: [FoldRegion])
func toggleFold(line: Int) -> Bool
func foldAt(line: Int) -> Bool
func unfoldAt(line: Int) -> Bool
func foldAll()
func unfoldAll()
func isLineVisible(line: Int) -> Bool

enum FoldArrowMode: Int32
enum WrapMode: Int32
func setFoldArrowMode(_ mode: FoldArrowMode)
func setWrapMode(_ mode: WrapMode)
func setLineSpacing(add: Float, mult: Float)

func insertSnippet(_ template: String) -> TextEditResultLite?
func startLinkedEditing(model: LinkedEditingModel)
func isInLinkedEditing() -> Bool
func linkedEditingNext() -> Bool
func linkedEditingPrev() -> Bool
func cancelLinkedEditing()
```

> Compatibility note: `SweetEditorCore` still keeps some old tuple/array overloads and marks them `deprecated`. For new integrations, use the model version or `payload: Data` version.

### Bracket Highlight

```swift
func setBracketPairs(openChars: [Int32], closeChars: [Int32])
func setMatchedBrackets(openLine: Int, openColumn: Int, closeLine: Int, closeColumn: Int)
func clearMatchedBrackets()
```

## iOS (UIKit / SwiftUI)

iOS view-layer files:

- `platform/Apple/Sources/SweetEditoriOS/SweetEditorViewiOS.swift`
- `platform/Apple/Sources/SweetEditoriOS/SweetEditorSwiftUIiOS.swift`

On top of shared core, iOS adds wrappers for:

- DecorationProvider: `add/remove/requestDecorationRefresh`
- CompletionProvider: `add/remove/trigger/show/dismiss`
- Language config: `setLanguageConfiguration(_:)` (syncs bracket pairs to Core)
- Generic metadata API: `setMetadata<T: EditorMetadata>(_:)` / `getMetadata<T: EditorMetadata>() -> T?`
- `setWrapMode(_ mode: Int)`: keeps `Int` entry and maps to `SweetEditorCore.WrapMode`

SwiftUI entry: `SweetEditorSwiftUIViewiOS`.

> Current status: SwiftUI wrapper is not fully ready and should be treated as unavailable for production integration at this time.

## macOS (AppKit / SwiftUI)

macOS view-layer files:

- `platform/Apple/Sources/SweetEditorMacOS/SweetEditorViewMacOS.swift`
- `platform/Apple/Sources/SweetEditorMacOS/SweetEditorSwiftUIMacOS.swift`

macOS also wraps providers, language config, and metadata on top of shared core. Features align with iOS. Main differences come from AppKit event system and input path.

SwiftUI entry: `SweetEditorSwiftUIMacOS`.

> Current status: SwiftUI wrapper is not fully ready and should be treated as unavailable for production integration at this time.

## `SweetDocument`

```swift
init(text: String)
init(filePath: String)
func getLineText(_ line: Int) -> String
func getLineCount() -> Int
```

## Gaps and Risks

- Apple bridge/header is maintained manually, so there is risk of signature drift from `src/include/c_api.h`.
- When core API changes, at least check these together:
  - `src/include/c_api.h`
  - `platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`
  - `platform/Apple/Sources/SweetEditorCoreInternal/api/SweetEditorCore.swift`
