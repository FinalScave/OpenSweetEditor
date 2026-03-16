# Swing Platform API

This document maps to the current Swing implementation:

- Control layer: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- Bridge layer: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
- FFM layer: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorNative.java`
- Document object: `platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/Document.java`

## Architecture Notes

- Swing calls C API through Java FFM.
- `EditorCore` handles upcall measure callbacks and binary payload decoding.
- The current bridge protocol is binary payload.
- `SweetEditor` provides semantic control APIs (enums) and handles Swing input events.

## Public Control Layer: `SweetEditor`

### Constructor and Basics

```java
public SweetEditor()
public SweetEditor(EditorTheme theme)
public void loadDocument(Document document)
public EditorTheme getEditorTheme()
public void applyTheme(EditorTheme theme)
public EditorCore getEditorCore()
public void flush()
```

`flush()` applies pending updates (decoration / layout / scroll / selection) and triggers redraw. For batched decoration updates, call `flush()` once at the end.

### Edit / Line Actions / Undo Redo

```java
public void insertText(String text)
public TextEditResult replaceText(TextRange range, String newText)
public TextEditResult deleteText(TextRange range)

public TextEditResult moveLineUp()
public TextEditResult moveLineDown()
public TextEditResult copyLineUp()
public TextEditResult copyLineDown()
public TextEditResult deleteLine()
public TextEditResult insertLineAbove()
public TextEditResult insertLineBelow()

public boolean undo()
public boolean redo()
public boolean canUndo()
public boolean canRedo()
```

### Cursor Selection / Navigation / Appearance

```java
public void selectAll()
public String getSelectedText()
public int[] getCursorPosition()
public Document getDocument()
public int[] getWordRangeAtCursor()
public String getWordAtCursor()
public void setReadOnly(boolean readOnly)
public boolean isReadOnly()
public void gotoPosition(int line, int column)
public void setScroll(float scrollX, float scrollY)
public ScrollMetrics getScrollMetrics()
public void setLineSpacing(float add, float mult)

public void setFoldArrowMode(FoldArrowMode mode)
public void setWrapMode(WrapMode mode)
public void setAutoIndentMode(AutoIndentMode mode)
public int getAutoIndentMode()
public CursorRect getPositionRect(int line, int column)
public CursorRect getCursorRect()
```

### Language Config / Metadata / Extension Providers

```java
public void setLanguageConfiguration(LanguageConfiguration config)
public LanguageConfiguration getLanguageConfiguration()
public <T extends EditorMetadata> void setMetadata(T metadata)
public <T extends EditorMetadata> T getMetadata()

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
public void setEditorIconProvider(EditorIconProvider provider)
public EditorIconProvider getEditorIconProvider()
public int[] getVisibleLineRange()
public int getTotalLineCount()
public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener)
```

### Styles / Decorations / Folding / Linked Editing

```java
public void registerStyle(int styleId, int color, int bgColor, int fontStyle)
public void registerStyle(int styleId, int color, int fontStyle)
public void setLineSpans(int line, int layer, List<? extends StyleSpan> spans)
public void setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine)

public void setLineInlayHints(int line, List<? extends InlayHint> hints)
public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine)
public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms)
public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine)

public void setLineDiagnostics(int line, List<? extends DiagnosticItem> items)
public void setBatchLineDiagnostics(Map<Integer, ? extends List<? extends DiagnosticItem>> diagsByLine)
public void clearDiagnostics()

public void setLineGutterIcons(int line, List<? extends GutterIcon> icons)
public void setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine)
public void setMaxGutterIcons(int count)
public void clearGutterIcons()

public void setIndentGuides(List<? extends IndentGuide> guides)
public void setBracketGuides(List<? extends BracketGuide> guides)
public void setFlowGuides(List<? extends FlowGuide> guides)
public void setSeparatorGuides(List<? extends SeparatorGuide> guides)
public void clearGuides()

public void setFoldRegions(List<? extends FoldRegion> regions)
public boolean toggleFold(int line)
public void foldAll()
public void unfoldAll()

public void clearHighlights()
public void clearHighlights(SpanLayer layer)
public void clearInlayHints()
public void clearPhantomTexts()
public void clearAllDecorations()

public TextEditResult insertSnippet(String snippetTemplate)
public void startLinkedEditing(LinkedEditingModel model)
public boolean isInLinkedEditing()
public boolean linkedEditingNext()
public boolean linkedEditingPrev()
public void cancelLinkedEditing()
```

## Bridge Layer Notes

- `EditorCore` / `EditorNative` already include bracket highlight support:
  - `setBracketPairs(int[] openChars, int[] closeChars)`
  - `setMatchedBrackets(...)`
  - `clearMatchedBrackets()`
- Control layer usually sends bracket pairs through `setLanguageConfiguration(...)`.
- `Document` currently exposes two read APIs: `getLineText(int)` and `getLineCount()`.

## `Document`

```java
public Document(String text)
public long getHandle()
public String getLineText(int line)
public int getLineCount()
public void close()
```
