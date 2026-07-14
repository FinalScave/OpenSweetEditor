# Android Platform API

For installation, requirements, dependency coordinates, and build commands, see the [Android README](../../platform/Android/sweeteditor/README.md). This page documents the current host-facing API.

## Public Surface

- Android view: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- Runtime settings: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/EditorSettings.java`
- Theme, language, metadata, icon, and keymap types: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor`
- Providers and UI extensions: `completion`, `decoration`, `newline`, `copilot`, `selection`, and `contextmenu` packages
- Events: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/event`
- Advanced native bridge: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`

`SweetEditor` is the primary API for application code. Appearance and behavior options are configured through `editor.getSettings()`. Android lifecycle overrides and view-internal refresh callbacks are not host API and are intentionally omitted below.

## Minimal Usage

```xml
<com.qiplat.sweeteditor.SweetEditor
    android:id="@+id/editor"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

```java
SweetEditor editor = findViewById(R.id.editor);
editor.applyTheme(EditorTheme.dark());
editor.loadDocument(new Document("Hello, SweetEditor!"));
editor.getSettings().setWrapMode(WrapMode.WORD_BREAK);
```

Creating `SweetEditor` initializes `EditorCore`, which loads `libsweeteditor` automatically. Standalone `Document` constructors call JNI directly; when constructing a `Document` before any `SweetEditor` or `EditorCore` instance, call `System.loadLibrary("sweeteditor")` first.

## `SweetEditor`

### Construction and Configuration

```java
public SweetEditor(Context context)
public SweetEditor(Context context, AttributeSet attrs)
public SweetEditor(Context context, AttributeSet attrs, int defStyleAttr)

public void loadDocument(Document document)
@Nullable public Document getDocument()
public EditorSettings getSettings()

public EditorTheme getTheme()
public void applyTheme(EditorTheme theme)

public EditorKeyMap getKeyMap()
public void setKeyMap(EditorKeyMap keyMap)
public void setEditorIconProvider(@Nullable EditorIconProvider provider)

public void setLanguageConfiguration(@Nullable LanguageConfiguration config)
@Nullable public LanguageConfiguration getLanguageConfiguration()
public <T extends EditorMetadata> void setMetadata(@Nullable T metadata)
@Nullable public <T extends EditorMetadata> T getMetadata()

public IntRange getVisibleLineRange()
public int getTotalLineCount()
```

`LanguageConfiguration` carries the language id, bracket pairs, auto-closing pairs, tab size, and spaces-for-tabs behavior. `EditorMetadata` is an opaque application-defined value available to providers.

### Text Editing and Line Commands

```java
public void insertText(String text)
public void insertTextAt(TextPosition position, String text)
public void replaceText(TextRange range, String newText)
public void deleteText(TextRange range)
public void applyTextEdits(List<? extends TextEdit> edits)

public void moveLineUp()
public void moveLineDown()
public void copyLineUp()
public void copyLineDown()
public void deleteLine()
public void insertLineAbove()
public void insertLineBelow()

public void undo()
public void redo()
public boolean canUndo()
public boolean canRedo()
```

`applyTextEdits(...)` applies edits in one operation. Edit ranges use the original document coordinates.

### Search and Replace

```java
public void search(SearchRequest request)
public void findNextSearchMatch()
public void findPreviousSearchMatch()
public void replaceCurrentSearchMatch(String replacement)
public void replaceAllSearchMatches(String replacement)
public void clearSearch()
public SearchState getSearchState()
```

`SearchOptions` supports case sensitivity, whole-word matching, regular expressions, wrap-around, and a maximum match count.

### Cursor, Selection, Clipboard, and Navigation

```java
public void selectAll()
@Nullable public String getSelectedText()
public void setSelection(int startLine, int startColumn, int endLine, int endColumn)
public void setSelection(TextRange range)
@Nullable public TextRange getSelection()
public boolean hasSelection()

public TextPosition getCursorPosition()
public void setCursorPosition(TextPosition position)
public TextRange getWordRangeAtCursor()
public String getWordAtCursor()

public boolean copyToClipboard()
public void pasteFromClipboard()
public boolean cutToClipboard()

public void gotoPosition(int line, int column)
public void scrollToLine(int line, ScrollBehavior behavior)
public void setScroll(float scrollX, float scrollY)
public ScrollMetrics getScrollMetrics()
public CursorRect getPositionRect(int line, int column)
public CursorRect getCursorRect()
```

### Styles and Decorations

```java
public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle)
public void registerTextStyle(int styleId, int color, int fontStyle)
public void registerBatchTextStyles(@Nullable Map<Integer, TextStyle> stylesById)

public void setLineSpans(int line, SpanLayer layer, List<? extends StyleSpan> spans)
public void setBatchLineSpans(SpanLayer layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine)
public void setLineInlayHints(int line, List<? extends InlayHint> hints)
public void setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine)
public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms)
public void setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine)
public void setLineGutterIcons(int line, List<? extends GutterIcon> icons)
public void setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine)
public void setLineCodeLens(int line, List<? extends CodeLensItem> items)
public void setBatchLineCodeLens(@Nullable SparseArray<? extends List<? extends CodeLensItem>> itemsByLine)
public void setLineLinks(int line, List<? extends LinkSpan> links)
public void setBatchLineLinks(@Nullable SparseArray<? extends List<? extends LinkSpan>> linksByLine)
public String getLinkTargetAt(int line, int column)
public void setLineDiagnostics(int line, List<? extends Diagnostic> items)
public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> itemsByLine)
public void setLineDocumentHighlights(int line, List<? extends DocumentHighlight> items)
public void setBatchLineDocumentHighlights(@Nullable SparseArray<? extends List<? extends DocumentHighlight>> itemsByLine)

public void setIndentGuides(List<IndentGuide> guides)
public void setBracketGuides(List<BracketGuide> guides)
public void setFlowGuides(List<FlowGuide> guides)
public void setSeparatorGuides(List<SeparatorGuide> guides)

public void clearHighlights()
public void clearHighlights(SpanLayer layer)
public void clearInlayHints()
public void clearPhantomTexts()
public void clearGutterIcons()
public void clearCodeLens()
public void clearLinks()
public void clearGuides()
public void clearDiagnostics()
public void clearDocumentHighlights()
public void clearAllDecorations()
```

`SpanLayer` contains syntax, semantic, and overlay layers. Font-style flags are `TextStyle.NORMAL`, `TextStyle.BOLD`, `TextStyle.ITALIC`, and `TextStyle.STRIKETHROUGH`.

### Folding, Snippets, and Linked Editing

```java
public void setFoldRegions(@Nullable List<? extends FoldRegion> regions)
public void toggleFoldAt(int line)
public void foldAt(int line)
public void unfoldAt(int line)
public void foldAll()
public void unfoldAll()
public boolean isLineVisible(int line)

public void insertSnippet(String snippetTemplate)
public void startLinkedEditing(LinkedEditingModel model)
public boolean isInLinkedEditing()
public void linkedEditingNext()
public void linkedEditingPrev()
public void cancelLinkedEditing()
```

### Providers and Editor Overlays

```java
public void addDecorationProvider(DecorationProvider provider)
public void removeDecorationProvider(DecorationProvider provider)
public void requestDecorationRefresh()

public void addCompletionProvider(CompletionProvider provider)
public void removeCompletionProvider(CompletionProvider provider)
public void triggerCompletion()
public void showCompletionItems(List<CompletionItem> items)
public void dismissCompletion()
public void setCompletionItemViewFactory(@Nullable CompletionItemViewFactory factory)

public void addNewLineActionProvider(NewLineActionProvider provider)
public void removeNewLineActionProvider(NewLineActionProvider provider)

public void showInlineSuggestion(InlineSuggestion suggestion)
public void dismissInlineSuggestion()
public boolean isInlineSuggestionShowing()
public void setInlineSuggestionListener(@Nullable InlineSuggestionListener listener)

public void setSelectionMenuItemProvider(@Nullable SelectionMenuItemProvider provider)
public void setContextMenuItemProvider(@Nullable ContextMenuItemProvider provider)
public void dismissContextMenu()
public boolean isContextMenuShowing()
```

### Events and Diagnostics

```java
public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener)
public void flush()
public void setPerfOverlayEnabled(boolean enabled)
public boolean isPerfOverlayEnabled()
```

Published event types include:

- `TextChangedEvent`, `CursorChangedEvent`, `SelectionChangedEvent`, `ScrollChangedEvent`, and `ScaleChangedEvent`
- `DocumentLoadedEvent` and `FoldToggleEvent`
- `GutterIconClickEvent`, `InlayHintClickEvent`, `CodeLensClickEvent`, and `LinkClickEvent`
- `LongPressEvent`, `DoubleTapEvent`, and `ContextMenuEvent`
- `SelectionMenuItemClickEvent` and `ContextMenuItemClickEvent`

Inline suggestion acceptance and dismissal use `InlineSuggestionListener`, not the generic event bus. `flush()` is a force-refresh and diagnostic entry point; normal editing and decoration updates do not require it. The performance overlay is disabled by default and is intended only for debugging.

## `EditorSettings`

```java
public void setEditorTextSize(float textSize)
public float getEditorTextSize()
public void setTypeface(Typeface typeface)
public Typeface getTypeface()
public void setScale(float scale)
public float getScale()

public void setFoldArrowMode(FoldArrowMode mode)
public FoldArrowMode getFoldArrowMode()
public void setWrapMode(WrapMode mode)
public WrapMode getWrapMode()
public void setRenderWhitespace(WhitespaceRenderMode mode)
public WhitespaceRenderMode getRenderWhitespace()
public void setRenderLineBreaks(boolean enabled)
public boolean isRenderLineBreaks()
public void setLineSpacing(float add, float mult)
public float getLineSpacingAdd()
public float getLineSpacingMult()
public void setContentStartPadding(float padding)
public float getContentStartPadding()
public void setShowSplitLine(boolean show)
public boolean isShowSplitLine()
public void setGutterSticky(boolean sticky)
public boolean isGutterSticky()
public void setGutterVisible(boolean visible)
public boolean isGutterVisible()
public void setCurrentLineRenderMode(CurrentLineRenderMode mode)
public CurrentLineRenderMode getCurrentLineRenderMode()

public void setAutoIndentMode(AutoIndentMode mode)
public AutoIndentMode getAutoIndentMode()
public void setBackspaceUnindent(boolean enabled)
public boolean isBackspaceUnindent()
public void setReadOnly(boolean readOnly)
public boolean isReadOnly()
public void setMaxGutterIcons(int count)
public int getMaxGutterIcons()

public void setDecorationScrollRefreshMinIntervalMs(long intervalMs)
public long getDecorationScrollRefreshMinIntervalMs()
public void setDecorationOverscanViewportMultiplier(float multiplier)
public float getDecorationOverscanViewportMultiplier()
public void setCursorAnimationEnabled(boolean enabled)
public boolean isCursorAnimationEnabled()
```

## Extension Contracts

### Decorations

`DecorationProvider` receives a `DecorationContext` containing the visible line range, total line count, text changes, language configuration, and metadata. It may publish asynchronous snapshots through `DecorationReceiver`; stale receivers become cancelled.

`DecorationResult` supports syntax, semantic, and overlay spans; inlay hints; diagnostics; document highlights; fold regions; indent, bracket, flow, and separator guides; gutter icons; phantom text; CodeLens; and links. Each category has `MERGE`, `REPLACE_ALL`, and `REPLACE_RANGE` application modes.

### Completion and Newline Actions

`CompletionProvider` receives cursor, current-line, word-range, language, metadata, and trigger information. It may publish cancellable asynchronous results. Completion items support a primary text edit, additional edits, snippets, filtering, sorting, kinds, and custom item views.

`NewLineActionProvider` is a synchronous chain used to customize the text inserted for Enter.

### Menus and Inline Suggestions

Selection menu providers build mobile selection actions. Context menu providers build sections for long-press or right-click requests. Inline suggestions display phantom text with accept and dismiss actions reported through `InlineSuggestionListener`.

## `Document`

```java
public Document(String content)
public Document(File file)
public String getText()
public int getLineCount()
public String getLineText(int line)
public TextPosition getPositionFromCharIndex(int index)
public int getCharIndexFromPosition(TextPosition position)
```

## Android Platform Behavior

- Rendering uses Android Canvas and Paint and supports proportional and monospaced typefaces.
- `InputConnection` integrates composing text, surrounding text, selection synchronization, batch edits, and soft-keyboard lifecycle.
- Touch, mouse, wheel, hover, drag selection, scaling, selection handles, clipboard, completion, selection menus, and context menus are integrated by the view.
- The packaged Android library supports `arm64-v8a` and `x86_64`; consult the README for the current SDK, NDK, and publishing configuration.

## Advanced `EditorCore`

`EditorCore` is a public low-level Java/JNI bridge for hosts that need direct render-model, IME, gesture, or pre-packed decoration access. Normal applications should use `SweetEditor` and `EditorSettings`. Android connects directly to the shared C++ core through JNI; ABI and core behavior are described in the [EditorCore / C API reference](./api-editor-core.md).
