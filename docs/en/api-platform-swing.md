# Swing API

For installation, requirements, build commands, runtime flags, and dependency coordinates, see the [Swing README](../../platform/Swing/sweeteditor/README.md).

This reference describes the current public API in `platform/Swing/sweeteditor`.

## Minimal Integration

```java
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;

SwingUtilities.invokeLater(() -> {
    JFrame frame = new JFrame("SweetEditor");
    SweetEditor editor = new SweetEditor(EditorTheme.dark());
    editor.loadDocument(new Document("Hello, SweetEditor!"));

    frame.setContentPane(editor);
    frame.setSize(1000, 700);
    frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    frame.setVisible(true);
});
```

Java 22 native access must be enabled at runtime. Native loading checks `sweeteditor.lib.path`, then extracts the matching bundled JAR resource, and finally falls back to `java.library.path` through `System.loadLibrary`.

## `SweetEditor`

### Construction and Core Configuration

```java
public SweetEditor()
public SweetEditor(EditorTheme theme)

public void loadDocument(Document document)
public Document getDocument()
public EditorSettings getSettings()
public EditorTheme getTheme()
public void applyTheme(EditorTheme theme)
public EditorCore getEditorCore()
public EditorKeyMap getKeyMap()
public void setKeyMap(EditorKeyMap keyMap)
public void setLanguageConfiguration(LanguageConfiguration config)
public LanguageConfiguration getLanguageConfiguration()
public <T extends EditorMetadata> void setMetadata(T metadata)
public <T extends EditorMetadata> T getMetadata()
public void setEditorIconProvider(EditorIconProvider provider)
public EditorIconProvider getEditorIconProvider()
public void setPerfOverlayEnabled(boolean enabled)
public boolean isPerfOverlayEnabled()
public void flush()
```

`flush()` forces a render-model refresh for diagnostics. Normal editing, scrolling, selection, provider, and decoration operations repaint automatically.

### Text Editing, Line Operations, and Clipboard

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

public void copyToClipboard()
public void pasteFromClipboard()
public void cutToClipboard()
```

`applyTextEdits(...)` accepts non-overlapping edits in original-document coordinates and groups applied content changes into one undo operation.

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

`SearchOptions` supports case-sensitive, whole-word, regular-expression, wrap-around, and maximum-match settings. `SearchState` reports status, match count, current match, generation, and any error message.

### Cursor, Selection, Navigation, and Geometry

```java
public void selectAll()
public String getSelectedText()
public void setSelection(int startLine, int startColumn, int endLine, int endColumn)
public TextRange getSelection()
public void setCursorPosition(TextPosition position)
public TextPosition getCursorPosition()
public TextRange getWordRangeAtCursor()
public String getWordAtCursor()

public void gotoPosition(int line, int column)
public void scrollToLine(int line, ScrollBehavior behavior)
public void setScroll(float scrollX, float scrollY)
public ScrollMetrics getScrollMetrics()
public CursorRect getPositionRect(int line, int column)
public CursorRect getCursorRect()
public IntRange getVisibleLineRange()
public int getTotalLineCount()
```

`getSelection()` returns `null` when there is no selection. `getLinkTargetAt(...)` and other string queries return an empty string when no value is available.

### Styles, Decorations, and Folding

```java
public void registerTextStyle(int styleId, int color, int bgColor, int fontStyle)
public void registerTextStyle(int styleId, int color, int fontStyle)
public void registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles)
public void setLineSpans(int line, SpanLayer layer, List<? extends StyleSpan> spans)
public void setBatchLineSpans(SpanLayer layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine)

public void setLineInlayHints(int line, List<? extends InlayHint> hints)
public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine)
public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms)
public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine)
public void setLineCodeLens(int line, List<? extends CodeLensItem> items)
public void setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine)
public void setLineLinks(int line, List<? extends LinkSpan> links)
public void setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine)
public String getLinkTargetAt(int line, int column)
public void setLineDiagnostics(int line, List<? extends Diagnostic> items)
public void setBatchLineDiagnostics(Map<Integer, ? extends List<? extends Diagnostic>> diagsByLine)
public void setLineDocumentHighlights(int line, List<? extends DocumentHighlight> items)
public void setBatchLineDocumentHighlights(Map<Integer, ? extends List<? extends DocumentHighlight>> highlightsByLine)
public void setLineGutterIcons(int line, List<? extends GutterIcon> icons)
public void setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine)

public void setIndentGuides(List<? extends IndentGuide> guides)
public void setBracketGuides(List<? extends BracketGuide> guides)
public void setFlowGuides(List<? extends FlowGuide> guides)
public void setSeparatorGuides(List<? extends SeparatorGuide> guides)

public void setFoldRegions(List<? extends FoldRegion> regions)
public void toggleFoldAt(int line)
public void foldAt(int line)
public void unfoldAt(int line)
public void foldAll()
public void unfoldAll()
public boolean isLineVisible(int line)

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

The component renders syntax, semantic, and overlay spans; inlay hints; phantom text; CodeLens; links; diagnostics; document highlights; gutter icons; fold regions; and indent, bracket, flow, and separator guides.

### Snippets, Linked Editing, and Inline Suggestions

```java
public void insertSnippet(String snippetTemplate)
public void startLinkedEditing(List<TabStopGroup> groups)
public boolean isInLinkedEditing()
public void linkedEditingNext()
public void linkedEditingPrev()
public void cancelLinkedEditing()

public void showInlineSuggestion(InlineSuggestion suggestion)
public void dismissInlineSuggestion()
public boolean isInlineSuggestionShowing()
public void setInlineSuggestionListener(InlineSuggestionListener listener)
```

Snippet insertion supports tab stops. While an inline suggestion is visible, Tab accepts it and Escape dismisses it.

### Providers and Completion

```java
public void addNewLineActionProvider(NewLineActionProvider provider)
public void removeNewLineActionProvider(NewLineActionProvider provider)

public void addDecorationProvider(DecorationProvider provider)
public void removeDecorationProvider(DecorationProvider provider)
public void requestDecorationRefresh()

public void addCompletionProvider(CompletionProvider provider)
public void removeCompletionProvider(CompletionProvider provider)
public void triggerCompletion()
public void showCompletionItems(List<CompletionItem> items)
public void dismissCompletion()
public void setCompletionCellRenderer(CompletionCellRenderer renderer)
```

- Completion providers receive invoked, trigger-character, or retrigger contexts and return results through a cancellable receiver. `CompletionItem.textEdit` defines the primary replacement range; `additionalTextEdits` use original-document coordinates. Snippet-format items enter snippet mode.
- Decoration providers receive the visible range, accumulated text changes, language configuration, and editor metadata. They can return syntax, semantic, overlay, inlay, diagnostic, document-highlight, guide, fold, gutter-icon, phantom-text, CodeLens, and link data using merge, replace-all, or replace-range modes.
- New-line action providers form a chain. The first provider that returns an action supplies the text inserted for Enter; returning `null` delegates to the next provider or the default editor behavior.

### Event Bus

```java
public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener)
```

The typed event bus publishes `TextChangedEvent`, `CursorChangedEvent`, `SelectionChangedEvent`, `ScrollChangedEvent`, `ScaleChangedEvent`, `DocumentLoadedEvent`, `LongPressEvent`, `DoubleTapEvent`, `ContextMenuEvent`, `InlayHintClickEvent`, `GutterIconClickEvent`, `FoldToggleEvent`, `CodeLensClickEvent`, and `LinkClickEvent`.

## `EditorSettings`

Access settings through `editor.getSettings()`.

```java
public void setScale(float scale)
public float getScale()
public void setEditorTextSize(float textSize)
public float getEditorTextSize()
public void setFontFamily(String fontFamily)
public String getFontFamily()
public void setGutterVisible(boolean visible)
public boolean isGutterVisible()
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
public void setDecorationScrollRefreshMinIntervalMs(int intervalMs)
public int getDecorationScrollRefreshMinIntervalMs()
public void setDecorationOverscanViewportMultiplier(float multiplier)
public float getDecorationOverscanViewportMultiplier()
public void setCursorAnimationEnabled(boolean enabled)
public boolean isCursorAnimationEnabled()
public void setGutterAnimationEnabled(boolean enabled)
public boolean isGutterAnimationEnabled()
```

## Keymaps and Language Configuration

`EditorKeyMap.defaultKeyMap()`, `vscode()`, `jetbrains()`, and `sublime()` create built-in maps. Hosts can add or remove `KeyBinding` values and register shortcut handlers with `registerCommand(...)`.

Build `LanguageConfiguration` with `LanguageConfiguration.Builder`. It describes the language ID, bracket pairs, auto-closing pairs, line and block comments, tab size, and spaces-for-tabs preference. Bracket, auto-closing, and indentation settings are applied to editing behavior; the full configuration is also available to completion, decoration, and new-line providers.

## `Document`

```java
public Document(String text)
public Document(Path path)
public Document(File file)
public long getHandle()
public String getLineText(int line)
public int getLineCount()
public String getText()
```

`Document` releases its native handle through a `Cleaner`; it does not expose a public `close()` method.

## Swing Input Behavior

- Keyboard input uses the active `EditorKeyMap`; completion and inline suggestions intercept their navigation or confirmation keys before ordinary editor commands.
- Mouse press, drag, hover, right-click, and wheel input drive selection, scrolling, links, CodeLens, gutter icons, folding, and context menus.
- Clipboard operations use the AWT system clipboard.
- Java input-method integration exposes preedit, commit, cancellation, caret geometry, surrounding text, and selected text through `InputMethodRequests`.
