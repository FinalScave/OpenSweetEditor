# OHOS Platform API

This document maps to the current OHOS implementation:

- Package entry: `platform/OHOS/sweeteditor/src/main/ets/Index.ets`
- ArkUI component: `platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`
- Controller/config layer:
  - `platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets` (`SweetEditorController`)
  - `platform/OHOS/sweeteditor/src/main/ets/EditorSettings.ets`
- Bridge layer: `platform/OHOS/sweeteditor/src/main/ets/core/EditorCore.ets`
- Protocol encode/decode: `platform/OHOS/sweeteditor/src/main/ets/core/EditorProtocol.ets`
- NAPI layer:
  - `platform/OHOS/sweeteditor/src/main/cpp/napi_editor.hpp`
  - `platform/OHOS/sweeteditor/src/main/cpp/napi_init.cpp`

## Architecture Notes

- The main OHOS path is ArkTS + NAPI direct to the shared C++ core through `libsweeteditor.so`.
- `EditorCore` keeps the native numeric protocol at the bridge boundary.
- `buildRenderModel()`, gesture result, key result, text edit result, and scroll metrics still return by binary payload and are decoded by `EditorProtocol.ets`.
- `Index.ets` re-exports the public API surface, so consumers normally import from `@qiplat/sweeteditor` instead of deep module paths.
- ArkUI overlays such as completion popup, inline suggestion bar, and selection menu are platform-side UI built from the C++ render/result model.

## Quick Start

### Environment Requirements (current repository setup)

- HarmonyOS SDK / API: `5.1.1(19)`
- Package manager: `ohpm`
- Build tool: `hvigorw`
- Package type: HAR (`platform/OHOS/sweeteditor`)

### Run the Demo in this repository

On Windows PowerShell:

```powershell
cd platform/OHOS
.\hvigorw.bat assembleApp --no-daemon
```

On macOS / Linux shell:

```bash
cd platform/OHOS
./hvigorw assembleApp --no-daemon
```

### Integrate into an existing OHOS project

Current repository-friendly integration uses a local package dependency:

```json5
{
  "dependencies": {
    "@qiplat/sweeteditor": "file:../sweeteditor"
  }
}
```

Then install dependencies:

```bash
ohpm install
```

If you publish the package to your own registry later, replace the `file:` path with the released version.

### Minimal Integration Example

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

## Primary External Control API: `SweetEditorController`

`SweetEditorController` is the main host-facing API for ArkUI applications. It lets the outside component tree drive the editor after `SweetEditor` is ready.

### Lifecycle and Basic Access

```ts
public whenReady(listener: () => void): void
public loadDocument(document: Document): void
public getDocument(): Document | null
public getSettings(): EditorSettings | null
public applyTheme(theme: EditorTheme): void
public getTheme(): EditorTheme | null
```

### Language / Metadata / Icon Provider

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

### Events and Undo/Redo

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

Mobile-specific events such as `LongPressEvent`, `DoubleTapEvent`, and OHOS-specific `SelectionMenuItemClickEvent` are also exposed through matching `onXxx` / `offXxx` methods.

## Runtime Settings: `EditorSettings`

`EditorSettings` is obtained from `SweetEditorController.getSettings()` and is the main appearance / behavior configuration surface.

### Appearance and Layout

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

### Editor Behavior

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

### Decoration Refresh Tuning

```ts
public setDecorationScrollRefreshMinIntervalMs(intervalMs: number): void
public getDecorationScrollRefreshMinIntervalMs(): number
public setDecorationOverscanViewportMultiplier(multiplier: number): void
public getDecorationOverscanViewportMultiplier(): number
```

## Advanced Bridge Layer: `EditorCore`

`EditorCore` is the low-level ArkTS bridge around `libsweeteditor.so`. Normal app code should prefer `SweetEditorController` + `EditorSettings`. Use `EditorCore` when you need direct control over render-model, protocol payloads, or platform integration.

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

### Text Edit / Cursor / Selection / Composition

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

### Styles / Decorations / Folding / Linked Editing

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

Most batch decoration APIs accept either strongly typed ArkTS data or pre-packed `ArrayBuffer`. The `ArrayBuffer` path is intended for advanced provider pipelines and large batch updates.

## `Document`

```ts
public static fromString(text: string): Document
public static fromFile(path: string): Document
public getText(): string
public getLineCount(): number
public getLineText(line: number): string
public destroy(): void
```

## Notes

- The primary external integration surface on OHOS is `SweetEditor` + `SweetEditorController`, not raw `EditorCore`.
- Register text styles before applying `StyleSpan` ranges.
- `SweetEditor` itself mirrors most editor operations internally and additionally owns OHOS-specific UI such as clipboard integration, IME callbacks, selection menu overlay, completion popup, inline suggestion bar, and performance overlay.
