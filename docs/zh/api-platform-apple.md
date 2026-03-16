# Apple 平台 API

本文档对应当前 Apple SPM SDK 实现（根目录：`platform/Apple`）。

## 总览

- 对外发布 Product：`SweetEditoriOS`、`SweetEditorMacOS`
- 内部 Core target：`SweetEditorCore`（不直接对外）
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
func resetMeasurer()
```

### 输入与文本编辑

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

### 行操作

```swift
func moveLineUp() -> TextEditResultLite?
func moveLineDown() -> TextEditResultLite?
func copyLineUp() -> TextEditResultLite?
func copyLineDown() -> TextEditResultLite?
func deleteLine() -> TextEditResultLite?
func insertLineAbove() -> TextEditResultLite?
func insertLineBelow() -> TextEditResultLite?
```

### 光标、单词、IME、只读、自动缩进

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

### 样式 / 装饰 / 折叠 / 联动编辑

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

> 兼容性说明：`SweetEditorCore` 仍保留部分 tuple/数组形态的旧重载并标注 `deprecated`，新接入建议统一使用 model 版本或 `payload: Data` 版本。

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
- CompletionProvider：`add/remove/trigger/show/dismiss`
- 语言配置：`setLanguageConfiguration(_:)`（同步 bracket pairs 到 Core）
- 元数据泛型接口：`setMetadata<T: EditorMetadata>(_:)` / `getMetadata<T: EditorMetadata>() -> T?`
- `setWrapMode(_ mode: Int)`：保留 `Int` 入口并映射到 `SweetEditorCore.WrapMode`

SwiftUI 使用入口：`SweetEditorSwiftUIViewiOS`。

> 当前状态：SwiftUI 封装暂未完善，现阶段不建议作为可用接入路径。

## macOS（AppKit / SwiftUI）

macOS 视图层文件：

- `platform/Apple/Sources/SweetEditorMacOS/SweetEditorViewMacOS.swift`
- `platform/Apple/Sources/SweetEditorMacOS/SweetEditorSwiftUIMacOS.swift`

macOS 侧同样在共享 Core 之上封装 Provider、语言配置和元数据接口；能力对齐 iOS，主要差异来自平台事件系统（AppKit）与输入链路。

SwiftUI 使用入口：`SweetEditorSwiftUIMacOS`。

> 当前状态：SwiftUI 封装暂未完善，现阶段不建议作为可用接入路径。

## `SweetDocument`

```swift
init(text: String)
init(filePath: String)
func getLineText(_ line: Int) -> String
func getLineCount() -> Int
```

## 差异与风险

- Apple bridge/header 为手工维护，与 `src/include/c_api.h` 存在签名漂移风险。
- 变更核心 API 时，至少同步检查：
  - `src/include/c_api.h`
  - `platform/Apple/Sources/SweetEditorBridge/include/SweetEditorBridge.h`
  - `platform/Apple/Sources/SweetEditorCoreInternal/api/SweetEditorCore.swift`
