# OHOS 平台 API

本文档对应当前 OHOS 实现：

- 包入口：`platform/OHOS/sweeteditor/src/main/ets/Index.ets`
- ArkUI 组件：`platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`
- 控制器 / 配置层：
  - `platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`（`SweetEditorController`）
  - `platform/OHOS/sweeteditor/src/main/ets/EditorSettings.ets`
- 桥接层：`platform/OHOS/sweeteditor/src/main/ets/core/EditorCore.ets`
- 协议编解码：`platform/OHOS/sweeteditor/src/main/ets/core/EditorProtocol.ets`
- NAPI 层：
  - `platform/OHOS/sweeteditor/src/main/cpp/napi_editor.hpp`
  - `platform/OHOS/sweeteditor/src/main/cpp/napi_init.cpp`

## 架构说明

- OHOS 主路径是 ArkTS + NAPI 直连共享 C++ 核心，通过 `libsweeteditor.so` 调用。
- `EditorCore` 在桥接边界保留原生数值协议。
- `buildRenderModel()`、手势结果、键盘结果、文本编辑结果、滚动度量当前仍通过二进制 payload 返回，再由 `EditorProtocol.ets` 解码。
- `Index.ets` 统一 re-export 公开 API，业务侧通常直接从 `@qiplat/sweeteditor` 导入，不需要使用深层路径。
- 补全面板、Inline Suggestion 条、Selection Menu 等 ArkUI 浮层由平台层实现，但数据来源仍是 C++ render/result model。

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
public addCompletionProvider(provider: CompletionProvider): void
public triggerCompletion(): void
public showInlineSuggestion(suggestion: InlineSuggestion): void
public dismissInlineSuggestion(): void
public isInlineSuggestionShowing(): boolean
public setInlineSuggestionListener(listener: InlineSuggestionListener | null): void
public requestDecorationRefresh(): void
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
public undo(): TextEditResult | null
public redo(): TextEditResult | null
public canUndo(): boolean
public canRedo(): boolean
```

移动端相关事件（如 `LongPressEvent`、`DoubleTapEvent`）以及 OHOS 特有的 `SelectionMenuItemClickEvent` 也都通过对应的 `onXxx` / `offXxx` 方法暴露。

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
public handleGestureEvent(event: GestureEvent): GestureResult
public handleSimpleGestureEvent(type: EventType, pointerCount: number, points: number[]): GestureResult
public tickEdgeScroll(): GestureResult
public tickFling(): GestureResult
public tickAnimations(): GestureResult
public handleKeyEvent(keyCode: number, text: string | null, modifiers: number): KeyEventResult
```

### 文本编辑 / 光标选区 / IME Composition

```ts
public insertText(text: string): TextEditResult
public replaceText(...): TextEditResult
public deleteText(...): TextEditResult
public backspace(): TextEditResult
public deleteForward(): TextEditResult
public getCursorPosition(): TextPosition
public getWordRangeAtCursor(): TextRange
public getWordAtCursor(): string
public setCursorPosition(line: number, column: number): void
public setSelection(...): void
public getSelection(): TextRange | null
public getSelectedText(): string
public compositionStart(): void
public compositionUpdate(text: string | null): void
public compositionEnd(committedText?: string | null): TextEditResult
public compositionCancel(): void
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
public insertSnippet(snippetTemplate: string): TextEditResult
public startLinkedEditing(modelOrData: LinkedEditingModel | ArrayBuffer, _size?: number): void
public cancelLinkedEditing(): void
public clearAllDecorations(): void
```

大部分批量 Decoration API 同时支持强类型 ArkTS 数据和预打包 `ArrayBuffer`。`ArrayBuffer` 路径适合高级 Provider 管线或大批量更新场景。

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
