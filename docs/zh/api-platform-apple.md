# Apple 平台 API

本文档描述 `platform/Apple` 中 Apple Swift Package 实际对外发布的 API。除非本文明确列出，否则 Swift 内部封装和原生 C API 接入均属于实现细节。

## 环境要求与 Product

- iOS 14 或更高版本
- macOS 11 或更高版本
- 对外发布的 Swift Package Product：`SweetEditorIOS`
- 对外发布的 Swift Package Product：`SweetEditorMacOS`

两个 Product 都使用相同的入口名称，由 Swift 模块区分：

- `SweetEditorView`：`SweetEditorIOS` 中为 UIKit `UIView`，`SweetEditorMacOS` 中为 AppKit `NSView`
- `SweetEditor`：`SweetEditorIOS` 中为 `UIViewRepresentable`，`SweetEditorMacOS` 中为 `NSViewRepresentable`

两个公开 Product 会重新导出 `SweetEditorShared` 中的 `EditorCore`、`Document` 和支撑模型，应用不直接链接该共享实现 target。多数应用应使用 `SweetEditorView`，由它统一处理重绘、IME、Provider 和状态派发。公开的 `EditorCore` 主要供独立的底层接入使用。

## Package 与原生产物

- `SweetEditorCoreIOS.xcframework.zip` 包含 `SweetEditorCoreIOS.xcframework`，其中有 iOS 真机和模拟器 `SweetEditorCoreIOS.framework` slice。
- `SweetEditorCoreMacOS.xcframework.zip` 包含 `SweetEditorCoreMacOS.xcframework`，其中有 macOS universal `SweetEditorCoreMacOS.framework` slice。
- 每个平台的 XCFramework、Framework、模块和 SwiftPM binary target 使用相同名称。
- 普通 Apple shared-library 构建独立生成 `libsweeteditor.dylib`，不与 Framework 打包混用。

Package 接入和构建命令见 [Apple README](../../platform/Apple/README.md)。

## 原生 View 通用 API

除非下文明确说明平台差异，`SweetEditorIOS.SweetEditorView` 和 `SweetEditorMacOS.SweetEditorView` 共同提供以下 API。

### 文档、主题与内容查询

    var settings: EditorSettings { get }

    func applyTheme(_ theme: EditorTheme)
    func loadDocument(text: String)
    func loadDocument(_ document: Document)
    func getDocument() -> Document?

`Document` 可从文本或文件路径创建。`getText()` 返回保留原始换行符的完整内容，`getLineText(_:)` 和 `getLineCount()` 提供按行访问。`loadDocument(text:)` 仍是直接加载文本的便捷入口。

### 搜索与替换

    func search(_ request: SearchRequest)
    func findNextSearchMatch()
    func findPreviousSearchMatch()
    func replaceCurrentSearchMatch(_ replacement: String)
    func replaceAllSearchMatches(_ replacement: String)
    func clearSearch()
    func getSearchState() -> SearchState

`SearchRequest` 支持大小写敏感、全词匹配、正则表达式、循环查找和最大匹配数。

### 编辑、选区与导航

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

两个 View 还公开行操作、折叠、snippet、linked editing 和显式剪贴板方法。`applyTextEdits(_:)` 会将传入编辑作为一个可撤销操作应用。所有 View 修改都会派发对应的 Core 结果，保证渲染、IME、Provider 和公开状态保持同步。

### 底层 Core API

`EditorCore` 公开与其他平台绑定一致的类型安全能力，包括文档加载、viewport 与外观配置、渲染、手势和按键处理、文本与行编辑、光标与选区、IME、滚动、装饰、搜索、折叠、snippet、linked editing 和历史。native handle、二进制 payload 重载、字体回调和平台 scale 同步继续属于实现细节。

Core 编辑动作统一返回非 optional 的 `EditorActionResult`；只有确实允许不存在的查询结果保留 optional。构造 `EditorCore` 时可传入 `EditorOptions`，公开的 decoration 与 gesture API 使用 `SpanLayer`、`CurrentLineRenderMode` 和 `GestureEvent`，不暴露原始传输值。直接使用 `EditorCore` 的调用方需要自行消费 action result，并接入重绘及平台服务。`SweetEditorView` 不公开它持有的 Core 实例，避免绕过 View 派发后造成 UI 状态不同步。

### 已生效的运行时设置

通过公开 `settings` 对象配置运行时行为：

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

### 语言与 Metadata

两个原生 View 均公开：

    var languageConfiguration: LanguageConfiguration? { get }
    var metadata: EditorMetadata?

    func setLanguageConfiguration(_ config: LanguageConfiguration?)

语言配置会更新 Core 编辑行为，并随 Provider context 传递。Metadata 由宿主定义，供 completion、decoration 和 newline Provider 使用。

### 样式与装饰

两个原生 View 均公开：

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

`EditorTheme` 持有当前主题的 `textStyles` 映射。Apple View 默认使用 `xcodeDark()`，同时提供 `xcodeLight()`；`dark()` 和 `light()` 继续作为跨平台通用预设。`applyTheme(_:)` 会将主题的样式映射统一注册到 Core。自定义主题可通过 `defineTextStyle(_:style:)` 增加或替换样式，不由主题管理样式的调用方仍可直接注册。

搜索 API 中已列出 `clearSearch()`。折叠区域可通过传入空列表移除，没有单独的公开 `clearFoldRegions` 方法。

### Decoration Provider

    func attachDecorationProvider(_ provider: DecorationProvider)
    func detachDecorationProvider(_ provider: DecorationProvider)
    func requestDecorationRefresh()

`DecorationProvider` 通过 `DecorationContext` 获取可见行范围、总行数、文本变更、语言配置和编辑器 metadata。`DecorationResult` 直接使用 Core adornment 类型，并对支持的装饰类型提供 `merge`、`replaceAll` 和 `replaceRange` 应用模式。

### Completion Provider

    func attachCompletionProvider(_ provider: CompletionProvider)
    func detachCompletionProvider(_ provider: CompletionProvider)
    func triggerCompletion()
    func showCompletionItems(_ items: [CompletionItem])
    func dismissCompletion()

`CompletionProvider` 通过 `CompletionReceiver` 异步返回结果。`CompletionContext` 包含当前语言配置和编辑器 metadata。Provider 结果会合并并排序。`CompletionItem` 支持直接文本、主 text edit、additional text edits，以及带联动占位符的 snippet 插入。

### NewLine Provider

    func attachNewLineActionProvider(_ provider: NewLineActionProvider)
    func detachNewLineActionProvider(_ provider: NewLineActionProvider)

Provider 通过 `NewLineContext` 获取光标位置、当前行文本、语言配置和编辑器 metadata。按注册顺序返回的第一个 action 决定按下 Enter 时插入的文本。

### 图标与交互回调

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

`EditorIconProvider` 为 gutter icon 和 icon 类型 inlay hint 提供 `CGImage`。代码补全弹窗统一使用 `EditorTheme` 中的标准 completion 颜色字段，与其他平台保持一致。

## iOS 特有公开 API

`SweetEditorIOS.SweetEditorView` 额外公开：

    var selectionMenuItemProvider: SelectionMenuItemProvider?
    var onSelectionMenuItemClick: ((SelectionMenuItem) -> Void)?
    var isSelectionMenuShowing: Bool { get }

    func dismissSelectionMenu()
    func insertText(_ text: String)
    func undo()
    func redo()
    func canUndo() -> Bool
    func canRedo() -> Bool

`SelectionMenuItemProvider` 返回下一次菜单展示所需的完整菜单项列表；更换 Provider 不会改变已经可见的菜单。内建菜单项标识由 `SelectionMenuItem` 提供，自定义菜单项通过 `onSelectionMenuItemClick` 回调。

UIKit 实现接入 `UITextInput`、`UIKeyInput`、marked text、周边文本查询、选区、浮动 Selection Menu、候选窗定位、触摸手势、双指缩放、iPad 指针和实体键盘快捷键。

`SweetEditor` 只直接公开：

- `theme`，默认值为 `EditorTheme.xcodeDark()`
- fold、inlay hint、gutter icon、CodeLens 和 link 回调

它不直接公开文档加载、settings、Provider、补全控制或文档文本绑定。需要这些 API 时应使用 `SweetEditorView`。

## macOS 特有公开 API

`SweetEditorMacOS.SweetEditorView` 额外公开：

    var showsPerformanceOverlay: Bool

AppKit 实现接入 `NSTextInputClient`、marked text、周边文本查询、候选窗定位、鼠标和触控板、滚轮、缩放、剪贴板快捷键和标准 AppKit 键绑定。

`SweetEditor` 只直接公开：

- `theme`，默认值为 `EditorTheme.xcodeDark()`
- `showsPerformanceOverlay`
- fold、inlay hint、gutter icon、CodeLens 和 link 回调

它不直接公开文档加载、settings、Provider、补全控制或 metadata。需要这些 API 时应使用 `SweetEditorView`。

## 公开支撑类型

两个公开 Product 会重新导出上述 API 所需的 public 支撑类型，包括：

- `EditorSettings` 及其语义化设置枚举
- `EditorCore` 和 `Document`
- `SearchRequest`、`SearchOptions` 和 `SearchState`
- `TextPosition`、`TextRange` 和 `TextEdit`
- 样式与装饰模型
- `DecorationProvider`、`DecorationReceiver`、`DecorationContext` 和 `DecorationResult`
- `CompletionProvider`、`CompletionReceiver`、`CompletionContext`、`CompletionResult` 和 `CompletionItem`
- iOS 的 `SelectionMenuItem` 和 `SelectionMenuItemProvider`
- `EditorIconProvider` 和各平台点击事件类型
- `EditorMetadata`；两个原生 View 通过符合 Swift 习惯的 `metadata` 属性公开

## 已知限制

- `CompletionItem.filterText` 只保存数据，当前不参与本地补全过滤。
- SwiftUI 封装有意只提供原生 UIKit 和 AppKit View 的一部分能力。
- Apple 实现直接导入平台专用 Core Framework 导出的标准 `c_api.h`，不再维护独立的 C 声明头文件。

## 实现参考

- Package 清单：[`platform/Apple/Package.swift`](../../platform/Apple/Package.swift)
- 共享 Swift 实现：[`platform/Apple/SweetEditor-Shared`](../../platform/Apple/SweetEditor-Shared)
- iOS 公开包装：[`platform/Apple/SweetEditor-iOS/SweetEditor.swift`](../../platform/Apple/SweetEditor-iOS/SweetEditor.swift)
- UIKit 公开 View：[`platform/Apple/SweetEditor-iOS/SweetEditorView.swift`](../../platform/Apple/SweetEditor-iOS/SweetEditorView.swift)
- macOS 公开 View：[`platform/Apple/SweetEditor-macOS/SweetEditorView.swift`](../../platform/Apple/SweetEditor-macOS/SweetEditorView.swift)
- macOS SwiftUI 包装：[`platform/Apple/SweetEditor-macOS/SweetEditor.swift`](../../platform/Apple/SweetEditor-macOS/SweetEditor.swift)
- 公开模块导出声明与各平台入口放在同一文件中。
- 标准 C API：[`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h)

发布内容见 [Apple CHANGELOG](../../platform/Apple/CHANGELOG.md)。
