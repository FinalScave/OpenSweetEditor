# Apple 平台 API

本文档对应当前 Apple SPM SDK 实现（根目录：`platform/Apple`）。

## 总览

- 对外发布 Product：`SweetEditoriOS`、`SweetEditorMacOS`
- 内部 Core target：`SweetEditorCoreInternal`（不直接对外）
- 核心通信方式：Swift -> 手工 C bridge -> C++ Core

关键文件：

- C bridge：`platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`
- Swift 核心封装：`platform/Apple/Sources/SweetEditorCoreInternal/api/SweetEditorCore.swift`
- 文档对象：`platform/Apple/Sources/SweetEditorCoreInternal/runtime/SweetDocument.swift`

## 共享 Core 能力（iOS / macOS 通用）

`SweetEditorCore` 是 iOS 与 macOS 共享的能力层，负责：

- UTF-16 指针转换
- 二进制 payload 解码（含 `LayoutMetrics`）
- 文本测量回调与渲染模型构建

### 基础与渲染

```swift
func setViewport(width: Int, height: Int)
func setDocument(_ document: SweetDocument)
func buildRenderModel() -> EditorRenderModel?
func getLayoutMetrics() -> LayoutMetrics?
func setScroll(scrollX: Float, scrollY: Float)
func getScrollMetrics() -> ScrollMetrics
func onFontMetricsChanged()
```

### 输入与文本编辑

`SweetEditorCore` 方法返回 `EditorActionResult`；`SweetEditorViewMacOS` 与 `SweetEditorViewiOS` 会在内部消费这些结果，对宿主暴露的编辑方法返回 `Void`。

```swift
func handleGestureEvent(
    type: SEEventType,
    points: [(Float, Float)],
    modifiers: SEModifier = [],
    wheelDeltaX: Float = 0,
    wheelDeltaY: Float = 0,
    directScale: Float = 1) -> EditorActionResultData?

func handleKeyEvent(
    keyCode: SEKeyCode,
    text: String? = nil,
    modifiers: SEModifier = []) -> EditorActionResultData?

func insertText(_ text: String) -> EditorActionResultData?
func insertText(at position: TextPosition, text: String)
func replaceText(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int, newText: String) -> EditorActionResultData?
func deleteText(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) -> EditorActionResultData?
func applyTextEdits(_ edits: [TextEdit]) -> EditorActionResultData?
```

### 行操作

```swift
func moveLineUp() -> EditorActionResultData?
func moveLineDown() -> EditorActionResultData?
func copyLineUp() -> EditorActionResultData?
func copyLineDown() -> EditorActionResultData?
func deleteLine() -> EditorActionResultData?
func insertLineAbove() -> EditorActionResultData?
func insertLineBelow() -> EditorActionResultData?
```

### 光标、单词、IME、只读、自动缩进

```swift
func getSelectedText() -> String
func getCursorPosition() -> (line: Int, column: Int)?
func getWordRangeAtCursor() -> (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)
func getWordAtCursor() -> String

func handleImeCommandMessage(_ message: ImeCommandMessage) -> EditorActionResult?
func handleImeTextUpdateMessage(_ message: ImeTextUpdateMessage) -> EditorActionResult?
func hasPreedit() -> Bool

func setReadOnly(_ readOnly: Bool)
func isReadOnly() -> Bool

enum AutoIndentMode: Int32
func setAutoIndentMode(_ mode: AutoIndentMode)
func getAutoIndentMode() -> AutoIndentMode

struct CursorRect { let x: CGFloat; let y: CGFloat; let height: CGFloat }
func getPositionRect(line: Int, column: Int) -> CursorRect
func getCursorRect() -> CursorRect
```

### 样式 / 装饰 / 折叠 / 联动编辑

```swift
func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32)
func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32)
func clearHighlights()
func clearHighlights(layer: UInt8)
func setLineSpans(line: Int, layer: UInt8 = 0, spans: [StyleSpan])
func setBatchLineSpans(layer: UInt8, spansByLine: [Int: [StyleSpan]])

func setLineDiagnostics(line: Int, items: [Diagnostic])
func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [Diagnostic]])
func clearDiagnostics()

func setLineInlayHints(line: Int, hints: [InlayHintPayload])
func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHintPayload]])
func clearInlayHints()
func setLinePhantomTexts(line: Int, phantoms: [PhantomTextPayload])
func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomTextPayload]])
func clearPhantomTexts()
func setLineCodeLens(line: Int, items: [CodeLensPayload])
func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensPayload]])
func clearCodeLens()
func setLineLinks(line: Int, links: [LinkSpan])
func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]])
func getLinkTargetAt(line: Int, column: Int) -> String
func clearLinks()
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
enum WhitespaceRenderMode: Int32
func setFoldArrowMode(_ mode: FoldArrowMode)
func setWrapMode(_ mode: WrapMode)
func setRenderWhitespace(_ mode: WhitespaceRenderMode)
func setRenderLineBreaks(_ enabled: Bool)
func setLineSpacing(add: Float, mult: Float)

func insertSnippet(_ template: String) -> EditorActionResultData?
func startLinkedEditing(model: LinkedEditingModel)
func isInLinkedEditing() -> Bool
func linkedEditingNext() -> Bool
func linkedEditingPrev() -> Bool
func cancelLinkedEditing()
```

> `SweetEditorCore` 对已经走生成协议模型的路径提供 model helper 和 payload helper。

`getLinkTargetAt(line:column:)` 在请求位置未命中 link 时返回空字符串。

### 括号高亮

```swift
func setBracketPairs(openChars: [Int32], closeChars: [Int32])
func setMatchedBrackets(openLine: Int, openColumn: Int, closeLine: Int, closeColumn: Int)
func clearMatchedBrackets()
```

## iOS（UIKit / SwiftUI）

iOS 视图层文件：

- `platform/Apple/Sources/SweetEditoriOS/SweetEditorViewiOS.swift`
- `platform/Apple/Sources/SweetEditoriOS/SweetEditorSwiftUIiOS.swift`

iOS 侧在共享 Core 之上额外封装：

- DecorationProvider：`add/remove/requestDecorationRefresh`
- DecorationProvider 返回 `DecorationResult`；每种 decoration family 都有对应的 `DecorationApplyMode`（`merge`、`replaceAll`、`replaceRange`）。
- CompletionProvider：`add/remove/trigger/show/dismiss`
- 语言配置：`setLanguageConfiguration(_:)`（同步 bracket pairs 到 Core）
- 元数据泛型接口：`setMetadata<T: EditorMetadata>(_:)` / `getMetadata<T: EditorMetadata>() -> T?`
- CodeLens / Link 点击回调：`onCodeLensClick`、`onLinkClick`
- `setWrapMode(_ mode: Int)`：保留 `Int` 入口并映射到 `SweetEditorCore.WrapMode`

SwiftUI 使用入口：`SweetEditorSwiftUIViewiOS`。

> 当前状态：SwiftUI 封装已提供，但仍在持续完善；用于生产接入前请结合目标场景验证焦点、输入法、弹层与 Provider 行为。

## macOS（AppKit / SwiftUI）

macOS 视图层文件：

- `platform/Apple/Sources/SweetEditorMacOS/SweetEditorViewMacOS.swift`
- `platform/Apple/Sources/SweetEditorMacOS/SweetEditorSwiftUIMacOS.swift`

macOS 侧同样在共享 Core 之上封装 Provider、语言配置、元数据以及点击回调（`onCodeLensClick`、`onLinkClick`）；能力对齐 iOS，主要差异来自平台事件系统（AppKit）与输入链路。

SwiftUI 使用入口：`SweetEditorSwiftUIMacOS`。

> 当前状态：SwiftUI 封装已提供，但仍在持续完善；用于生产接入前请结合目标场景验证焦点、输入法、弹层与 Provider 行为。

## `SweetDocument`

```swift
init(text: String)
init(filePath: String)
func getLineText(_ line: Int) -> String
func getLineCount() -> Int
```

## 差异与风险

- Apple bridge/header 为手工维护，与 `include/sweeteditor/c_api.h` 存在签名漂移风险。
- 变更核心 API 时，至少同步检查：
  - `include/sweeteditor/c_api.h`
  - `platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`
  - `platform/Apple/Sources/SweetEditorCoreInternal/api/SweetEditorCore.swift`
