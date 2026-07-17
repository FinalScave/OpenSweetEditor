# Apple 平台 API

本文档描述 `platform/Apple` 中 Apple Swift Package 实际对外发布的 API。除非本文明确列出，否则 Swift 内部封装和原生 C API 接入均属于实现细节。

## 环境要求与 Product

- iOS 14 或更高版本
- macOS 11 或更高版本
- 对外发布的 Swift Package Product：`SweetEditorIOS`
- 对外发布的 Swift Package Product：`SweetEditorMacOS`

公开原生入口包括：

- `SweetEditorViewiOS`：UIKit `UIView`
- `SweetEditorViewMacOS`：AppKit `NSView`
- `SweetEditorSwiftUIViewiOS`：`UIViewRepresentable` 封装
- `SweetEditorSwiftUIMacOS`：`NSViewRepresentable` 封装

`SweetEditorShared`、`SweetEditorCore` 和 `SweetDocument` 都不是应用公开入口。两个公开 Product 会重新导出 `SweetEditorShared` 中的 public 支撑模型，但应用不直接链接该共享实现 target。

## Package 与原生产物

- `SweetEditorCoreIOS.xcframework.zip` 包含 `SweetEditorCoreIOS.xcframework`，其中有 iOS 真机和模拟器 `SweetEditorCoreIOS.framework` slice。
- `SweetEditorCoreMacOS.xcframework.zip` 包含 `SweetEditorCoreMacOS.xcframework`，其中有 macOS universal `SweetEditorCoreMacOS.framework` slice。
- 每个平台的 XCFramework、Framework、模块和 SwiftPM binary target 使用相同名称。
- 普通 Apple shared-library 构建独立生成 `libsweeteditor.dylib`，不与 Framework 打包混用。

Package 接入和构建命令见 [Apple README](../../platform/Apple/README.md)。

## 原生 View 通用 API

除非下文明确说明平台差异，`SweetEditorViewiOS` 和 `SweetEditorViewMacOS` 共同提供以下 API。

### 文档、主题与内容查询

    var settings: EditorSettings { get }

    func applyTheme(isDark: Bool)
    func loadDocument(text: String)
    func documentLines() -> [String]

公开层只支持通过 `loadDocument(text:)` 加载文本。基于文件路径构造 `SweetDocument` 的能力仍属于内部实现。

### 搜索与替换

    func search(_ request: SearchRequest)
    func findNextSearchMatch()
    func findPreviousSearchMatch()
    func replaceCurrentSearchMatch(_ replacement: String)
    func replaceAllSearchMatches(_ replacement: String)
    func clearSearch()
    func getSearchState() -> SearchState

`SearchRequest` 支持大小写敏感、全词匹配、正则表达式、循环查找和最大匹配数。

### 外部文本编辑

    func insertText(at position: TextPosition, text: String)
    func applyTextEdits(_ edits: [TextEdit])

`applyTextEdits(_:)` 会将传入编辑作为一个可撤销操作应用。直接范围替换、删除、光标控制和选区控制均属于内部方法，不是公开 View API。

原生 View 仍通过 UIKit 或 AppKit 事件链提供交互式光标移动、选择、剪贴板命令、行操作、撤销重做快捷键、滚动、折叠和输入法支持。

### 已生效的运行时设置

通过公开 `settings` 对象配置运行时行为：

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

两个原生 View 还保留最大 gutter icon 数、折叠箭头模式、行间距、内容起始 padding、分隔线、当前行模式、空白字符、换行符、只读、整数 wrap mode 和 scale 的兼容包装方法。

### 样式与装饰

两个原生 View 均公开：

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

搜索 API 中已列出 `clearSearch()`。折叠区域可通过传入空列表移除，没有单独的公开 `clearFoldRegions` 方法。

### Decoration Provider

    func attachDecorationProvider(_ provider: DecorationProvider)
    func detachDecorationProvider(_ provider: DecorationProvider)
    func requestDecorationRefresh()

`DecorationProvider` 通过 `DecorationContext` 获取可见行范围、总行数和文本变更。`DecorationResult` 对支持的装饰类型提供 `merge`、`replaceAll` 和 `replaceRange` 应用模式。

### Completion Provider

    func attachCompletionProvider(_ provider: CompletionProvider)
    func detachCompletionProvider(_ provider: CompletionProvider)
    func triggerCompletion()
    func showCompletionItems(_ items: [CompletionItem])
    func dismissCompletion()

`CompletionProvider` 通过 `CompletionReceiver` 异步返回结果。Provider 结果会合并并排序。`CompletionItem` 支持直接文本、主 text edit、additional text edits，以及带联动占位符的 snippet 插入。

### 图标与交互回调

    var editorIconProvider: EditorIconProvider?
    func setEditorIconProvider(_ provider: EditorIconProvider?)

    var onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    var onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    var onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?
    var onCodeLensClick: ((SweetEditorCodeLensClickEvent) -> Void)?
    var onLinkClick: ((SweetEditorLinkClickEvent) -> Void)?

`EditorIconProvider` 为 gutter icon 和 icon 类型 inlay hint 提供 `CGImage`。

## iOS 特有公开 API

`SweetEditorViewiOS` 额外公开：

    var onDocumentTextChanged: ((String) -> Void)?
    var selectionMenuItemProvider: SweetEditorSelectionMenuItemProvider?
    var onSelectionMenuItemClick: ((SweetEditorSelectionMenuItem) -> Void)?
    var isSelectionMenuShowing: Bool { get }

    func setSelectionMenuItemProvider(_ provider: SweetEditorSelectionMenuItemProvider?)
    func dismissSelectionMenu()
    func insertText(_ text: String)
    func undo()
    func redo()
    func canUndo() -> Bool
    func canRedo() -> Bool

`SweetEditorSelectionMenuItemProvider` 返回下一次菜单展示所需的完整菜单项列表；更换 Provider 不会改变已经可见的菜单。内建菜单项标识由 `SweetEditorSelectionMenuItem` 提供，自定义菜单项通过 `onSelectionMenuItemClick` 回调。

UIKit 实现接入 `UITextInput`、`UIKeyInput`、marked text、周边文本查询、选区、浮动 Selection Menu、候选窗定位、触摸手势、双指缩放、iPad 指针和实体键盘快捷键。

`SweetEditorSwiftUIViewiOS` 只直接公开：

- `isDarkTheme`
- fold、inlay hint、gutter icon、CodeLens 和 link 回调

它不直接公开文档加载、settings、Provider、补全控制或文档文本绑定。需要这些 API 时应使用 `SweetEditorViewiOS`。

## macOS 特有公开 API

`SweetEditorViewMacOS` 额外公开：

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

`SweetEditorViewiOS` 和两个 SwiftUI 包装都没有公开这些 metadata 方法。

AppKit 实现接入 `NSTextInputClient`、marked text、周边文本查询、候选窗定位、鼠标和触控板、滚轮、缩放、剪贴板快捷键和标准 AppKit 键绑定。

`SweetEditorSwiftUIMacOS` 只直接公开：

- `isDarkTheme`
- `showsPerformanceOverlay`
- fold、inlay hint、gutter icon、CodeLens 和 link 回调

它不直接公开文档加载、settings、Provider、补全控制或 metadata。需要这些 API 时应使用 `SweetEditorViewMacOS`。

## 公开支撑类型

两个公开 Product 会重新导出上述 API 所需的 public 支撑类型，包括：

- `EditorSettings` 及其语义化设置枚举
- `SearchRequest`、`SearchOptions` 和 `SearchState`
- `TextPosition`、`TextRange` 和 `TextEdit`
- 样式与装饰模型
- `DecorationProvider`、`DecorationReceiver`、`DecorationContext` 和 `DecorationResult`
- `CompletionProvider`、`CompletionReceiver`、`CompletionContext`、`CompletionResult` 和 `CompletionItem`
- iOS 的 `SweetEditorSelectionMenuItem` 和 `SweetEditorSelectionMenuItemProvider`
- `EditorIconProvider` 和各平台点击事件类型
- `EditorMetadata`；公开 `setMetadata` 和 `getMetadata` 入口仅存在于 macOS 原生 View

## 已知限制

- 两个原生 View 都没有公开语言配置 setter，因此当前公开路径中的 `DecorationContext.languageConfiguration` 和 `CompletionContext.languageConfiguration` 始终为 `nil`。
- `EditorSettings.setEditorTextSize` 和 `setTypeface` 只更新保存值，没有应用到原生核心或文本测量器。
- `EditorSettings.setDecorationScrollRefreshMinIntervalMs` 和 `setDecorationOverscanViewportMultiplier` 尚未连接 `DecorationProviderManager`。
- `CompletionItem.filterText` 只保存数据，当前不参与本地补全过滤。
- 尽管 macOS 源码声明了 `addNewLineActionProvider` 和 `removeNewLineActionProvider`，其 provider、context 和 result 类型均为 internal；应用无法调用这些方法或实现该 provider 契约。
- SwiftUI 封装有意只提供原生 UIKit 和 AppKit View 的一部分能力。
- Apple 实现直接导入平台专用 Core Framework 导出的标准 `c_api.h`，不再维护独立的 C 声明头文件。

## 实现参考

- Package 清单：[`platform/Apple/Package.swift`](../../platform/Apple/Package.swift)
- 共享 Swift 实现：[`platform/Apple/SweetEditor-Shared`](../../platform/Apple/SweetEditor-Shared)
- iOS 公开包装：[`platform/Apple/SweetEditor-iOS/SweetEditorSwiftUIiOS.swift`](../../platform/Apple/SweetEditor-iOS/SweetEditorSwiftUIiOS.swift)
- UIKit 内部编辑器：[`platform/Apple/SweetEditor-iOS/SweetEditorViewiOS.swift`](../../platform/Apple/SweetEditor-iOS/SweetEditorViewiOS.swift)
- macOS 公开 View：[`platform/Apple/SweetEditor-macOS/SweetEditorViewMacOS.swift`](../../platform/Apple/SweetEditor-macOS/SweetEditorViewMacOS.swift)
- macOS SwiftUI 包装：[`platform/Apple/SweetEditor-macOS/SweetEditorSwiftUIMacOS.swift`](../../platform/Apple/SweetEditor-macOS/SweetEditorSwiftUIMacOS.swift)
- 公开重新导出：[`platform/Apple/SweetEditor-iOS/PublicExports.swift`](../../platform/Apple/SweetEditor-iOS/PublicExports.swift) 和 [`platform/Apple/SweetEditor-macOS/PublicExports.swift`](../../platform/Apple/SweetEditor-macOS/PublicExports.swift)
- 标准 C API：[`include/sweeteditor/c_api.h`](../../include/sweeteditor/c_api.h)

发布内容见 [Apple CHANGELOG](../../platform/Apple/CHANGELOG.md)。
