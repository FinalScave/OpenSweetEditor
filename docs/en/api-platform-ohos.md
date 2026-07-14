# OHOS Platform API

For installation, SDK requirements, package setup, and build commands, see the [OHOS README](../../platform/OHOS/sweeteditor/README.md). This page documents the current host-facing ArkTS API.

## Public Surface

- Package entry: `platform/OHOS/sweeteditor/src/main/ets/Index.ets`
- ArkUI component: `platform/OHOS/sweeteditor/src/main/ets/SweetEditor.ets`
- Host controller: `platform/OHOS/sweeteditor/src/main/ets/SweetEditorController.ets`
- Runtime settings: `platform/OHOS/sweeteditor/src/main/ets/EditorSettings.ets`
- Providers and extensions: `completion`, `decoration`, `newline`, `copilot`, and `selection` directories
- Events: `platform/OHOS/sweeteditor/src/main/ets/event/EditorEvent.ets`
- Advanced native bridge: `platform/OHOS/sweeteditor/src/main/ets/core/EditorCore.ets`

Applications normally import public types from `@qiplat/sweeteditor` and use `SweetEditor` with `SweetEditorController`. The component owns the native session; the controller is the imperative host API. Its `bind(...)` and `unbind(...)` methods are component lifecycle plumbing and must not be called by hosts.

## Minimal Usage

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

Keep one controller associated with one component instance. `getSettings()` becomes available after `whenReady(...)` fires.

## `SweetEditorController`

### Lifecycle and Configuration

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

`LanguageConfiguration` carries the language id, bracket pairs, auto-closing pairs, tab size, and spaces-for-tabs behavior. `EditorMetadata` is an opaque application-defined value available to providers.

### Text Editing and Line Commands

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

`applyTextEdits(...)` applies edits in one operation. Edit ranges use the original document coordinates.

### Search and Replace

```ts
search(request: SearchRequest): void
findNextSearchMatch(): void
findPreviousSearchMatch(): void
replaceCurrentSearchMatch(replacement: string): void
replaceAllSearchMatches(replacement: string): void
clearSearch(): void
getSearchState(): SearchState
```

Search options support case sensitivity, whole-word matching, regular expressions, wrap-around, and a maximum match count.

### Cursor, Selection, Clipboard, and Navigation

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

### Styles and Decorations

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

`SpanLayer` contains syntax, semantic, and overlay layers. `getLinkTargetAt(...)` returns an empty string when no link matches the position.

### Folding, Snippets, and Linked Editing

```ts
setFoldRegions(regions: FoldRegion[]): void
toggleFoldAt(line: number): void
foldAt(line: number): void
unfoldAt(line: number): void
foldAll(): void
unfoldAll(): void
isLineVisible(line: number): boolean

insertSnippet(template: string): void
startLinkedEditing(model: LinkedEditingModel): void
isInLinkedEditing(): boolean
linkedEditingNext(): void
linkedEditingPrev(): void
cancelLinkedEditing(): void
```

### Providers and Editor Overlays

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

### Events and Diagnostics

The controller exposes paired `onXxx` and `offXxx` methods for these typed events:

| Event | Subscribe / unsubscribe |
| --- | --- |
| Text changes | `onTextChanged` / `offTextChanged` |
| Cursor changes | `onCursorChanged` / `offCursorChanged` |
| Selection changes | `onSelectionChanged` / `offSelectionChanged` |
| Scroll changes | `onScrollChanged` / `offScrollChanged` |
| Scale changes | `onScaleChanged` / `offScaleChanged` |
| Long press | `onLongPress` / `offLongPress` |
| Double tap | `onDoubleTap` / `offDoubleTap` |
| Context-menu gesture | `onContextMenu` / `offContextMenu` |
| Gutter icon click | `onGutterIconClick` / `offGutterIconClick` |
| Inlay hint click | `onInlayHintClick` / `offInlayHintClick` |
| CodeLens click | `onCodeLensClick` / `offCodeLensClick` |
| Link click | `onLinkClick` / `offLinkClick` |
| Fold toggle | `onFoldToggle` / `offFoldToggle` |
| Document loaded | `onDocumentLoaded` / `offDocumentLoaded` |
| Selection-menu item | `onSelectionMenuItemClick` / `offSelectionMenuItemClick` |

```ts
setPerfOverlayEnabled(enabled: boolean): void
isPerfOverlayEnabled(): boolean
flush(): void
```

Inline suggestion acceptance and dismissal use `InlineSuggestionListener`, not the editor event system. `flush()` is a force-refresh and diagnostic entry point; normal updates do not require it. The performance overlay is disabled by default and is intended only for debugging.

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

## Extension Contracts

### Decorations

`DecorationProvider` receives a `DecorationContext` containing the visible line range, total line count, text changes, language configuration, and metadata. It may publish asynchronous snapshots through `DecorationReceiver`; stale receivers become cancelled.

`DecorationResult` supports syntax, semantic, and overlay spans; inlay hints; diagnostics; document highlights; fold regions; indent, bracket, flow, and separator guides; gutter icons; phantom text; CodeLens; and links. Each category has `MERGE`, `REPLACE_ALL`, and `REPLACE_RANGE` application modes.

### Completion and Newline Actions

`CompletionProvider` receives cursor, current-line, word-range, language, metadata, and trigger information. It may publish cancellable asynchronous results. Completion items support a primary text edit, additional edits, snippets, filtering, sorting, kinds, and a custom ArkUI item builder.

`NewLineActionProvider` is a synchronous chain used to customize the text inserted for Enter.

### Selection Menu and Inline Suggestions

`SelectionMenuItemProvider` builds the mobile selection menu from current selection state. Inline suggestions display phantom text and an action bar; acceptance and dismissal are reported through `InlineSuggestionListener`.

## `Document`

```ts
static fromString(text: string): Document
static fromFile(path: string): Document
getText(): string
getLineCount(): number
getLineText(line: number): string
destroy(): void
```

The component borrows the active `Document`; it does not call `destroy()` when a document is replaced or the component is released. Keep the document alive while the editor uses it, then destroy it from application code. Do not reuse a destroyed document or a controller whose component has been released.

## OHOS Platform Behavior

- Rendering uses ArkUI Canvas and supports proportional and monospaced fonts.
- HarmonyOS input method integration covers composing and preview text, surrounding context, cursor and selection synchronization, and keyboard lifecycle.
- The component integrates pasteboard access, hardware keys, touch and mouse gestures, drag selection, scaling, selection handles, completion, inline suggestions, and the mobile selection menu.
- A context-menu gesture is published as an event; OHOS does not expose the Android context-menu popup/provider API.
- The HAR and supported native architectures are documented in the README.

## Advanced `EditorCore`

`EditorCore` is an exported low-level ArkTS/NAPI bridge for hosts that need direct render-model, IME, gesture, or pre-packed decoration access. Normal applications should use `SweetEditorController` and `EditorSettings`. Core concepts and ABI behavior are described in the [EditorCore / C API reference](./api-editor-core.md).
