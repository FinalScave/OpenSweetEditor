# OHOS 平台 API

本文档对应当前 OHOS 实现：

- 包入口：`platform/OHOS/sweeteditor/src/main/ets/Index.ets`
- ArkUI 组件：`platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`
- 控制器 / 配置层：
  - `platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`（`SweetEditorController`）
  - `platform/OHOS/sweeteditor/src/main/ets/EditorSettings.ets`
- 桥接层：`platform/OHOS/sweeteditor/src/main/ets/core/EditorCore.ets`
- 协议编解码：`platform/OHOS/sweeteditor/src/main/ets/core/CoreProtocol.ets`
- NAPI 层：
  - `platform/OHOS/sweeteditor/src/main/cpp/napi_editor.hpp`
  - `platform/OHOS/sweeteditor/src/main/cpp/napi_init.cpp`

## 架构说明

- OHOS 主路径是 ArkTS + NAPI 直连共享 C++ 核心，通过 `libsweeteditor.so` 调用。
- `EditorCore` 在桥接边界保留原生数值协议。
- `buildRenderModel()`、`EditorActionResult`、滚动度量等复杂返回当前仍通过二进制 payload 返回，再由 `CoreProtocol.ets` 解码。
- `Index.ets` 统一 re-export 公开 API，业务侧通常直接从 `@qiplat/sweeteditor` 导入，不需要使用深层路径。
- 补全面板、Inline Suggestion 条、Selection Menu 等 ArkUI 浮层由平台层实现，但数据来源仍是 C++ render model 与 `EditorActionResult`。

## 快速开始

### 环境要求（按当前仓库配置）

- HarmonyOS SDK / API：`5.1.1(19)`
- 包管理器：`ohpm`
- 构建工具：`hvigorw`
- 包类型：HAR（`platform/OHOS/sweeteditor`）

### 在仓库内直接运行 Demo

Windows PowerShell：

```powershell
cd platform/OHOS
.\hvigorw.bat assembleApp --no-daemon
```

macOS / Linux shell：

```bash
cd platform/OHOS
./hvigorw assembleApp --no-daemon
```

### 在现有 OHOS 项目中接入

按当前仓库结构，推荐先使用本地包依赖：

```json5
{
  "dependencies": {
    "@qiplat/sweeteditor": "file:../sweeteditor"
  }
}
```

然后执行：

```bash
ohpm install
```

如果后续你把包发布到自有仓库，再把 `file:` 路径替换成发布版本号即可。

### 最小集成示例

```ts
import { Document, EditorTheme, SweetEditor, SweetEditorController, WrapMode } from '@qiplat/sweeteditor';

@Entry
@Component
struct Index {
  private controller: SweetEditorController = new SweetEditorController();

  aboutToAppear(): void {
    this.controller.whenReady(() => {
      this.controller.applyTheme(EditorTheme.dark());
      this.controller.getSettings()?.setWrapMode(WrapMode.WORD_BREAK);
      this.controller.loadDocument(Document.fromString('Hello, SweetEditor!'));
    });
  }

  build() {
    Column() {
      SweetEditor({ controller: this.controller })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
```

## 主要外部控制 API：`SweetEditorController`

对 ArkUI 业务组件来说，`SweetEditorController` 是主要控制入口。`SweetEditor` 就绪后，由控制器驱动文档、主题、Provider、事件订阅等能力。

### 生命周期与基础访问

```ts
public whenReady(listener: () => void): void
public loadDocument(document: Document): void
public getDocument(): Document | null
public getSettings(): EditorSettings | null
public applyTheme(theme: EditorTheme): void
public getTheme(): EditorTheme | null
```

### 语言配置 / Metadata / Icon Provider

```ts
public setLanguageConfiguration(config: LanguageConfiguration | null): void
public setMetadata(metadata: EditorMetadata | null): void
public setEditorIconProvider(provider: EditorIconProvider | null): void
```

### Decorations / Completion / Inline Suggestion

```ts
public addDecorationProvider(provider: DecorationProvider): void
public setLineCodeLens(line: number, items: CodeLensItem[]): void
public setBatchLineCodeLens(itemsByLine: Map<number, CodeLensItem[]>): void
public clearCodeLens(): void
public setLineLinks(line: number, links: LinkSpan[]): void
public setBatchLineLinks(linksByLine: Map<number, LinkSpan[]>): void
public getLinkTargetAt(line: number, column: number): string
public clearLinks(): void
public requestDecorationRefresh(): void
public addCompletionProvider(provider: CompletionProvider): void
public triggerCompletion(): void
public showInlineSuggestion(suggestion: InlineSuggestion): void
public dismissInlineSuggestion(): void
public isInlineSuggestionShowing(): boolean
public setInlineSuggestionListener(listener: InlineSuggestionListener | null): void
```

### 事件与撤销重做

```ts
public onTextChanged(listener: EditorEventListener<TextChangedEvent>): void
public offTextChanged(listener: EditorEventListener<TextChangedEvent>): void
public onCursorChanged(listener: EditorEventListener<CursorChangedEvent>): void
public offCursorChanged(listener: EditorEventListener<CursorChangedEvent>): void
public onSelectionChanged(listener: EditorEventListener<SelectionChangedEvent>): void
public offSelectionChanged(listener: EditorEventListener<SelectionChangedEvent>): void
public onScrollChanged(listener: EditorEventListener<ScrollChangedEvent>): void
public offScrollChanged(listener: EditorEventListener<ScrollChangedEvent>): void
public onScaleChanged(listener: EditorEventListener<ScaleChangedEvent>): void
public offScaleChanged(listener: EditorEventListener<ScaleChangedEvent>): void
public onDocumentLoaded(listener: EditorEventListener<DocumentLoadedEvent>): void
public offDocumentLoaded(listener: EditorEventListener<DocumentLoadedEvent>): void
public onFoldToggle(listener: EditorEventListener<FoldToggleEvent>): void
public offFoldToggle(listener: EditorEventListener<FoldToggleEvent>): void
public onGutterIconClick(listener: EditorEventListener<GutterIconClickEvent>): void
public offGutterIconClick(listener: EditorEventListener<GutterIconClickEvent>): void
public onInlayHintClick(listener: EditorEventListener<InlayHintClickEvent>): void
public offInlayHintClick(listener: EditorEventListener<InlayHintClickEvent>): void
public onCodeLensClick(listener: EditorEventListener<CodeLensClickEvent>): void
public offCodeLensClick(listener: EditorEventListener<CodeLensClickEvent>): void
public onLinkClick(listener: EditorEventListener<LinkClickEvent>): void
public offLinkClick(listener: EditorEventListener<LinkClickEvent>): void
public undo(): EditorActionResult
public redo(): EditorActionResult
public canUndo(): boolean
public canRedo(): boolean
```

移动端相关事件（如 `LongPressEvent`、`DoubleTapEvent`）以及 OHOS 特有的 `SelectionMenuItemClickEvent` 也都通过对应的 `onXxx` / `offXxx` 方法暴露。

`getLinkTargetAt(...)` 在请求位置未命中 link 时返回空字符串。

## 运行时配置：`EditorSettings`

`EditorSettings` 通过 `SweetEditorController.getSettings()` 获取，是主要的外观 / 行为配置入口。

### 外观与布局

```ts
public setEditorTextSize(size: number): void
public getEditorTextSize(): number
public setFontFamily(fontFamily: string): void
public getFontFamily(): string
public setScale(scale: number): void
public getScale(): number
public setLineSpacing(add: number, mult: number): void
public getLineSpacingAdd(): number
public getLineSpacingMult(): number
public setContentStartPadding(padding: number): void
public getContentStartPadding(): number
public setShowSplitLine(show: boolean): void
public isShowSplitLine(): boolean
public setGutterSticky(sticky: boolean): void
public isGutterSticky(): boolean
public setGutterVisible(visible: boolean): void
public isGutterVisible(): boolean
public setCurrentLineRenderMode(mode: CurrentLineRenderMode): void
public getCurrentLineRenderMode(): CurrentLineRenderMode
public setRenderWhitespace(mode: WhitespaceRenderMode): void
public getRenderWhitespace(): WhitespaceRenderMode
public setRenderLineBreaks(enabled: boolean): void
public isRenderLineBreaks(): boolean
```

### 编辑器行为

```ts
public setFoldArrowMode(mode: FoldArrowMode): void
public getFoldArrowMode(): FoldArrowMode
public setWrapMode(mode: WrapMode): void
public getWrapMode(): WrapMode
public setAutoIndentMode(mode: AutoIndentMode): void
public getAutoIndentMode(): AutoIndentMode
public setReadOnly(readOnly: boolean): void
public isReadOnly(): boolean
public setMaxGutterIcons(count: number): void
public getMaxGutterIcons(): number
```

### Decoration 刷新调优

```ts
public setDecorationScrollRefreshMinIntervalMs(intervalMs: number): void
public getDecorationScrollRefreshMinIntervalMs(): number
public setDecorationOverscanViewportMultiplier(multiplier: number): void
public getDecorationOverscanViewportMultiplier(): number
```

完整跨平台 settings 与 theme 契约见[平台实现标准](./platform-implementation-standard.md)。

## 高级桥接层：`EditorCore`

`EditorCore` 是围绕 `libsweeteditor.so` 的低层 ArkTS bridge。正常业务代码优先使用 `SweetEditorController` + `EditorSettings`；只有在需要直接控制 render-model、协议 payload 或平台集成时，才建议直接使用 `EditorCore`。

### View / Render / Metrics

```ts
public setViewport(width: number, height: number): void
public onFontMetricsChanged(): void
public buildRenderModel(): EditorRenderModel
public getViewState(): ArrayBuffer | undefined
public getLayoutMetrics(): ArrayBuffer | undefined
public ensureCursorVisible(): void
public getPositionRect(line: number, column: number): CursorRect
public getCursorRect(): CursorRect
public setScroll(scrollX: number, scrollY: number): void
public getScrollMetrics(): ScrollMetrics
```

### Gesture / Keyboard / Animation

```ts
public handleGestureEvent(event: GestureEvent): EditorActionResult
public handleSimpleGestureEvent(type: EventType, pointerCount: number, points: number[]): EditorActionResult
public tickAnimations(): EditorActionResult
public handleKeyEvent(keyCode: number, text: string | null, modifiers: number): EditorActionResult
```

### 文本编辑 / 光标选区 / IME

这里列出的是 `SweetEditor` view 方法。底层 `EditorCore` 调用仍返回 `EditorActionResult`，view 会在内部统一分发这些结果。

```ts
public insertText(text: string): void
public insertTextAt(position: TextPosition, text: string): void
public replaceText(...): void
public deleteText(...): void
public applyTextEdits(edits: TextEdit[]): void
public backspace(): void
public deleteForward(): void
public getCursorPosition(): TextPosition
public getWordRangeAtCursor(): TextRange
public getWordAtCursor(): string
public setCursorPosition(line: number, column: number): void
public setSelection(...): void
public getSelection(): TextRange | null
public getSelectedText(): string
public handleImeCommandMessage(message: ImeCommandMessage): EditorActionResult | undefined
public handleImeTextUpdateMessage(message: ImeTextUpdateMessage): EditorActionResult | undefined
public hasPreedit(): boolean
```

### 样式 / Decoration / Folding / Linked Editing

```ts
public registerTextStyle(styleId: number, color: number, backgroundColorOrFontStyle: number, fontStyle?: number): void
public registerBatchTextStyles(stylesByIdOrData: Map<number, TextStyle> | ArrayBuffer, _size?: number): void
public setLineSpans(...): void
public setBatchLineSpans(...): void
public setLineInlayHints(...): void
public setBatchLineInlayHints(...): void
public setLinePhantomTexts(...): void
public setBatchLinePhantomTexts(...): void
public setLineCodeLens(lineOrData: number | ArrayBuffer, itemsOrSize?: CodeLensItem[] | number): void
public setBatchLineCodeLens(itemsByLineOrData: Map<number, CodeLensItem[]> | ArrayBuffer, _size?: number): void
public clearCodeLens(): void
public setLineLinks(lineOrData: number | ArrayBuffer, linksOrSize?: LinkSpan[] | number): void
public setBatchLineLinks(linksByLineOrData: Map<number, LinkSpan[]> | ArrayBuffer, _size?: number): void
public getLinkTargetAt(line: number, column: number): string
public clearLinks(): void
public setLineGutterIcons(...): void
public setBatchLineGutterIcons(...): void
public setLineDiagnostics(...): void
public setBatchLineDiagnostics(...): void
public setIndentGuides(...): void
public setBracketGuides(...): void
public setFlowGuides(...): void
public setSeparatorGuides(...): void
public setFoldRegions(...): void
public toggleFold(line: number): boolean
public foldAt(line: number): boolean
public unfoldAt(line: number): boolean
public foldAll(): void
public unfoldAll(): void
public insertSnippet(snippetTemplate: string): EditorActionResult
public startLinkedEditing(modelOrData: LinkedEditingModel | ArrayBuffer, _size?: number): void
public cancelLinkedEditing(): void
public clearAllDecorations(): void
```

大部分批量 Decoration API 同时支持强类型 ArkTS 数据和预打包 `ArrayBuffer`。`ArrayBuffer` 路径适合高级 Provider 管线或大批量更新场景。

对于 Link 查询，`getLinkTargetAt(...)` 在请求位置未命中时返回空字符串。

## `Document`

```ts
public static fromString(text: string): Document
public static fromFile(path: string): Document
public getText(): string
public getLineCount(): number
public getLineText(line: number): string
public destroy(): void
```

## 说明

- OHOS 侧主要公开集成面是 `SweetEditor` + `SweetEditorController`，不是裸 `EditorCore`。
- 在应用 `StyleSpan` 之前，先注册对应 `TextStyle`。
- `SweetEditor` 组件内部还承担了 OHOS 特有 UI 与系统集成，例如剪贴板、IME 回调、Selection Menu 浮层、Completion Popup、Inline Suggestion Bar、Perf Overlay。
