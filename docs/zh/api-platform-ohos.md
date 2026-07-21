# OHOS 平台 API

安装、SDK 要求、包配置和构建命令请阅读 [OHOS README](../../platform/OHOS/sweeteditor/README.md)。本文只记录当前面向宿主的 ArkTS 公开 API。

## 公开入口

- 包入口：`platform/OHOS/sweeteditor/src/main/ets/Index.ets`
- ArkUI 组件：`platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`
- 宿主控制器：`platform/OHOS/sweeteditor/src/main/ets/SweetEditorController.ets`
- 运行时设置：`platform/OHOS/sweeteditor/src/main/ets/EditorSettings.ets`
- Provider 与扩展：`completion`、`decoration`、`newline`、`copilot` 和 `selection` 目录
- 事件：`platform/OHOS/sweeteditor/src/main/ets/event/EditorEvent.ets`
- 高级原生桥接：`platform/OHOS/sweeteditor/src/main/ets/core/EditorCore.ets`

应用通常从 `@qiplat/sweeteditor` 导入公开类型，并组合使用 `SweetEditor` 与 `SweetEditorController`。组件拥有原生会话，控制器是宿主的命令式入口。其中 `bind(...)` 和 `unbind(...)` 属于组件生命周期衔接，宿主不应调用。

## 最小示例

```ts
import {
  Document,
  EditorTheme,
  SweetEditor,
  SweetEditorController,
  WrapMode
} from '@qiplat/sweeteditor';

@Entry
@Component
struct Index {
  private readonly controller: SweetEditorController = new SweetEditorController();

  aboutToAppear(): void {
    this.controller.whenReady(() => {
      this.controller.applyTheme(EditorTheme.dark());
      this.controller.getSettings()?.setWrapMode(WrapMode.WORD_BREAK);
      this.controller.loadDocument(Document.fromString('Hello, SweetEditor!'));
    });
  }

  build() {
    SweetEditor({ controller: this.controller })
      .width('100%')
      .height('100%')
  }
}
```

一个控制器只能关联一个组件实例。`getSettings()` 在 `whenReady(...)` 触发后才可用。

## `SweetEditorController`

### 生命周期与配置

```ts
whenReady(listener: () => void): void
loadDocument(document: Document): void
getDocument(): Document | null
getSettings(): EditorSettings | null

applyTheme(theme: EditorTheme): void
getTheme(): EditorTheme | null
setLanguageConfiguration(config: LanguageConfiguration | null): void
getLanguageConfiguration(): LanguageConfiguration | null
setMetadata(metadata: EditorMetadata | null): void
getMetadata(): EditorMetadata | null
setEditorIconProvider(provider: EditorIconProvider | null): void
getKeyMap(): EditorKeyMap
setKeyMap(keyMap: EditorKeyMap): void

getVisibleLineRange(): IntRange
getTotalLineCount(): number
```

`LanguageConfiguration` 包含语言 ID、括号对、自动闭合对、Tab 宽度和空格缩进设置。`EditorMetadata` 是可供 Provider 读取的宿主自定义不透明值。

### 文本编辑与行命令

```ts
insertText(text: string): void
insertTextAt(position: TextPosition, text: string): void
replaceText(range: TextRange, newText: string): void
deleteText(range: TextRange): void
applyTextEdits(edits: TextEdit[]): void

moveLineUp(): void
moveLineDown(): void
copyLineUp(): void
copyLineDown(): void
deleteLine(): void
insertLineAbove(): void
insertLineBelow(): void

undo(): void
redo(): void
canUndo(): boolean
canRedo(): boolean
```

`applyTextEdits(...)` 在一次操作中应用多项编辑，编辑范围使用原始文档坐标。

### 搜索与替换

```ts
search(request: SearchRequest): void
findNextSearchMatch(): void
findPreviousSearchMatch(): void
replaceCurrentSearchMatch(replacement: string): void
replaceAllSearchMatches(replacement: string): void
clearSearch(): void
getSearchState(): SearchState
```

搜索选项支持区分大小写、全词、正则表达式、循环查找和最大匹配数量。

### 光标、选区、剪贴板与导航

```ts
selectAll(): void
getSelectedText(): string
setSelection(range: TextRange): void
setSelection(startLine: number, startColumn: number, endLine: number, endColumn: number): void
getSelection(): TextRange | null

getCursorPosition(): TextPosition
setCursorPosition(position: TextPosition): void
getWordRangeAtCursor(): TextRange
getWordAtCursor(): string

copyToClipboard(): void
pasteFromClipboard(): void
cutToClipboard(): void

gotoPosition(line: number, column: number): void
scrollToLine(line: number, behavior?: ScrollBehavior): void
setScroll(scrollX: number, scrollY: number): void
getScrollMetrics(): ScrollMetrics
getPositionRect(line: number, column: number): CursorRect
getCursorRect(): CursorRect
```

### 样式与 Decoration

```ts
registerTextStyle(styleId: number, color: number, backgroundColorOrFontStyle: number, fontStyle?: number): void
registerBatchTextStyles(stylesById: Map<number, TextStyle>): void

setLineSpans(line: number, layer: SpanLayer, spans: StyleSpan[]): void
setBatchLineSpans(layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): void
setLineInlayHints(line: number, hints: InlayHint[]): void
setBatchLineInlayHints(hintsByLine: Map<number, InlayHint[]>): void
setLinePhantomTexts(line: number, phantoms: PhantomText[]): void
setBatchLinePhantomTexts(phantomsByLine: Map<number, PhantomText[]>): void
setLineGutterIcons(line: number, icons: GutterIcon[]): void
setBatchLineGutterIcons(iconsByLine: Map<number, GutterIcon[]>): void
setLineCodeLens(line: number, items: CodeLensItem[]): void
setBatchLineCodeLens(itemsByLine: Map<number, CodeLensItem[]>): void
setLineLinks(line: number, links: LinkSpan[]): void
setBatchLineLinks(linksByLine: Map<number, LinkSpan[]>): void
getLinkTargetAt(line: number, column: number): string
setLineDiagnostics(line: number, items: Diagnostic[]): void
setBatchLineDiagnostics(itemsByLine: Map<number, Diagnostic[]>): void
setLineDocumentHighlights(line: number, items: DocumentHighlight[]): void
setBatchLineDocumentHighlights(itemsByLine: Map<number, DocumentHighlight[]>): void

setIndentGuides(guides: IndentGuide[]): void
setBracketGuides(guides: BracketGuide[]): void
setFlowGuides(guides: FlowGuide[]): void
setSeparatorGuides(guides: SeparatorGuide[]): void

clearHighlights(layer?: SpanLayer): void
clearInlayHints(): void
clearPhantomTexts(): void
clearGutterIcons(): void
clearCodeLens(): void
clearLinks(): void
clearGuides(): void
clearDiagnostics(): void
clearDocumentHighlights(): void
clearAllDecorations(): void
```

`SpanLayer` 包含语法、语义和 overlay 三层。`getLinkTargetAt(...)` 在请求位置没有链接时返回空字符串。

### 折叠、Snippet 与 Linked Editing

```ts
setFoldRegions(regions: FoldRegion[]): void
toggleFoldAt(line: number): void
foldAt(line: number): void
unfoldAt(line: number): void
foldAll(): void
unfoldAll(): void
isLineVisible(line: number): boolean

insertSnippet(template: string): void
startLinkedEditing(groups: TabStopGroup[]): void
isInLinkedEditing(): boolean
linkedEditingNext(): void
linkedEditingPrev(): void
cancelLinkedEditing(): void
```

### Provider 与编辑器浮层

```ts
addDecorationProvider(provider: DecorationProvider): void
removeDecorationProvider(provider: DecorationProvider): void
requestDecorationRefresh(): void

addCompletionProvider(provider: CompletionProvider): void
removeCompletionProvider(provider: CompletionProvider): void
triggerCompletion(): void
showCompletionItems(items: CompletionItem[]): void
dismissCompletion(): void
setCompletionItemViewBuilder(builder: CompletionItemViewBuilder | null): void

addNewLineActionProvider(provider: NewLineActionProvider): void
removeNewLineActionProvider(provider: NewLineActionProvider): void

showInlineSuggestion(suggestion: InlineSuggestion): void
dismissInlineSuggestion(): void
isInlineSuggestionShowing(): boolean
setInlineSuggestionListener(listener: InlineSuggestionListener | null): void

setSelectionMenuItemProvider(provider: SelectionMenuItemProvider | null): void
```

### 事件与诊断

控制器为下列类型化事件提供成对的 `onXxx` 和 `offXxx` 方法：

| 事件 | 订阅 / 取消订阅 |
| --- | --- |
| 文本变化 | `onTextChanged` / `offTextChanged` |
| 光标变化 | `onCursorChanged` / `offCursorChanged` |
| 选区变化 | `onSelectionChanged` / `offSelectionChanged` |
| 滚动变化 | `onScrollChanged` / `offScrollChanged` |
| 缩放变化 | `onScaleChanged` / `offScaleChanged` |
| 长按 | `onLongPress` / `offLongPress` |
| 双击 | `onDoubleTap` / `offDoubleTap` |
| 右键菜单手势 | `onContextMenu` / `offContextMenu` |
| Gutter icon 点击 | `onGutterIconClick` / `offGutterIconClick` |
| Inlay hint 点击 | `onInlayHintClick` / `offInlayHintClick` |
| CodeLens 点击 | `onCodeLensClick` / `offCodeLensClick` |
| 链接点击 | `onLinkClick` / `offLinkClick` |
| 折叠切换 | `onFoldToggle` / `offFoldToggle` |
| 文档加载 | `onDocumentLoaded` / `offDocumentLoaded` |
| Selection Menu 自定义项 | `onSelectionMenuItemClick` / `offSelectionMenuItemClick` |

```ts
setPerfOverlayEnabled(enabled: boolean): void
isPerfOverlayEnabled(): boolean
flush(): void
```

inline suggestion 的接受和关闭通过 `InlineSuggestionListener` 回调，不走编辑器事件系统。`flush()` 是强制刷新和诊断入口，普通更新无需调用。性能浮层默认关闭，仅用于调试。

## `EditorSettings`

```ts
setEditorTextSize(size: number): void
getEditorTextSize(): number
setFontFamily(fontFamily: string): void
getFontFamily(): string
setScale(scale: number): void
getScale(): number

setFoldArrowMode(mode: FoldArrowMode): void
getFoldArrowMode(): FoldArrowMode
setWrapMode(mode: WrapMode): void
getWrapMode(): WrapMode
setRenderWhitespace(mode: WhitespaceRenderMode): void
getRenderWhitespace(): WhitespaceRenderMode
setRenderLineBreaks(enabled: boolean): void
isRenderLineBreaks(): boolean
setLineSpacing(add: number, mult: number): void
getLineSpacingAdd(): number
getLineSpacingMult(): number
setContentStartPadding(padding: number): void
getContentStartPadding(): number
setShowSplitLine(show: boolean): void
isShowSplitLine(): boolean
setGutterSticky(sticky: boolean): void
isGutterSticky(): boolean
setGutterVisible(visible: boolean): void
isGutterVisible(): boolean
setCurrentLineRenderMode(mode: CurrentLineRenderMode): void
getCurrentLineRenderMode(): CurrentLineRenderMode

setAutoIndentMode(mode: AutoIndentMode): void
getAutoIndentMode(): AutoIndentMode
setBackspaceUnindent(enabled: boolean): void
isBackspaceUnindent(): boolean
setReadOnly(readOnly: boolean): void
isReadOnly(): boolean
setMaxGutterIcons(count: number): void
getMaxGutterIcons(): number

setDecorationScrollRefreshMinIntervalMs(intervalMs: number): void
getDecorationScrollRefreshMinIntervalMs(): number
setDecorationOverscanViewportMultiplier(multiplier: number): void
getDecorationOverscanViewportMultiplier(): number
```

## 扩展契约

### Decoration

`DecorationProvider` 接收包含可见行范围、总行数、文本变化、语言配置和 Metadata 的 `DecorationContext`，并可通过 `DecorationReceiver` 异步提交快照；过期 Receiver 会进入取消状态。

`DecorationResult` 支持语法、语义和 overlay span、inlay hint、diagnostic、文档高亮、折叠区域、缩进线、括号线、流程线、分隔线、gutter icon、phantom text、CodeLens 和链接。每一类均支持 `MERGE`、`REPLACE_ALL` 和 `REPLACE_RANGE` 应用模式。

### 补全与换行

`CompletionProvider` 接收光标、当前行、单词范围、语言、Metadata 和触发信息，并可提交可取消的异步结果。补全项支持主文本编辑、附加编辑、snippet、过滤、排序、类型和自定义 ArkUI 条目构建器。

`NewLineActionProvider` 是用于定制 Enter 插入文本的同步调用链。

### Selection Menu 与 Inline Suggestion

`SelectionMenuItemProvider` 根据当前选区状态构建移动端选择菜单。inline suggestion 展示 phantom text 和操作条，并通过 `InlineSuggestionListener` 报告接受和关闭操作。

## `Document`

```ts
static fromString(text: string): Document
static fromFile(path: string): Document
getText(): string
getLineCount(): number
getLineText(line: number): string
destroy(): void
```

组件只借用活动 `Document`；替换文档或释放组件时不会调用 `destroy()`。编辑器使用期间必须保持 Document 存活，停止使用后由应用自行销毁。不要复用已经销毁的文档，也不要复用其组件已释放的控制器。

## OHOS 平台行为

- 使用 ArkUI Canvas 渲染，同时支持等宽与非等宽字体。
- HarmonyOS 输入法集成覆盖组合输入、preview text、周边上下文、光标与选区同步以及键盘生命周期。
- 组件集成系统 pasteboard、硬件按键、触摸与鼠标手势、拖动选区、缩放、选择手柄、补全面板、inline suggestion 和移动端选择菜单。
- 右键菜单手势通过事件公开；OHOS 不提供 Android 的 Context Menu Popup/Provider API。
- HAR 和支持的原生架构请以 README 为准。

## 高级 `EditorCore`

`EditorCore` 是导出的低层 ArkTS/NAPI 桥接，供需要直接访问 render model、IME、手势或预打包 decoration 的宿主使用。普通应用应使用 `SweetEditorController` 和 `EditorSettings`。核心概念与 ABI 行为请参考 [EditorCore / C API 文档](./api-editor-core.md)。
