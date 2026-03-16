# Android Platform API

This document maps to the current Android implementation:

- Control layer: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- Bridge layer: `platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
- JNI layer: `platform/Android/sweeteditor/src/main/cpp/jni_entry.cpp`
- Direct header: `platform/Android/sweeteditor/src/main/cpp/jeditor.hpp`

## Architecture Notes

- The main Android path is JNI direct to C++ (not through `c_api.h`).
- `EditorCore` keeps the native `int` protocol at JNI boundary.
- `buildRenderModel()`, gesture result, key result, text edit result, and scroll metrics still return by binary protocol, then `ProtocolDecoder` decodes them.
- `SweetEditor` exposes semantic enum APIs (`WrapMode`/`FoldArrowMode`/`AutoIndentMode`, etc.).

## Public Control Layer: `SweetEditor`

### Constructors

```java
public SweetEditor(Context context)
public SweetEditor(Context context, AttributeSet attrs)
public SweetEditor(Context context, AttributeSet attrs, int defStyleAttr)
```

### Document and Appearance

```java
public void loadDocument(Document document)
public Document getDocument()
public void setTypeface(Typeface typeface)
public void setEditorTextSize(float textSize)
public void setScale(float scale)
public void setFoldArrowMode(FoldArrowMode mode)
public void setWrapMode(WrapMode mode)
public void setAutoIndentMode(AutoIndentMode mode)
public int getAutoIndentMode()
public void setLineSpacing(float add, float mult)
public CursorRect getPositionRect(int line, int column)
public CursorRect getCursorRect()
public void setScroll(float scrollX, float scrollY)
public ScrollMetrics getScrollMetrics()
public EditorTheme getTheme()
public void applyTheme(EditorTheme theme)
public void setEditorIconProvider(@Nullable EditorIconProvider provider)
```

### Text Edit / Line Actions / Undo Redo

```java
public EditorCore.TextEditResult insertText(String text)
public EditorCore.TextEditResult replaceText(TextRange range, String newText)
public EditorCore.TextEditResult deleteText(TextRange range)

public EditorCore.TextEditResult moveLineUp()
public EditorCore.TextEditResult moveLineDown()
public EditorCore.TextEditResult copyLineUp()
public EditorCore.TextEditResult copyLineDown()
public EditorCore.TextEditResult deleteLine()
public EditorCore.TextEditResult insertLineAbove()
public EditorCore.TextEditResult insertLineBelow()

public EditorCore.TextEditResult undo()
public EditorCore.TextEditResult redo()
public boolean canUndo()
public boolean canRedo()
```

### Clipboard / Navigation / Cursor Selection

```java
public void copyToClipboard()
public void pasteFromClipboard()
public void cutToClipboard()

public void selectAll()
public String getSelectedText()
public void gotoPosition(int line, int column)
public void scrollToLine(int line, ScrollBehavior behavior)
public void setSelection(int startLine, int startColumn, int endLine, int endColumn)
public void setSelection(TextRange range)
public TextRange getSelection()
public TextPosition getCursorPosition()
public TextRange getWordRangeAtCursor()
public String getWordAtCursor()
public void setCursorPosition(TextPosition position)
```

### Read-only / Language Config / Extension Providers

```java
public void setReadOnly(boolean readOnly)
public boolean isReadOnly()

public void setLanguageConfiguration(@Nullable LanguageConfiguration config)
public LanguageConfiguration getLanguageConfiguration()

public <T extends EditorMetadata> void setMetadata(@Nullable T metadata)
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
public void setCompletionItemViewFactory(@Nullable CompletionItemViewFactory factory)
public int[] getVisibleLineRange()
public int getTotalLineCount()
public <T extends EditorEvent> void subscribe(@NonNull Class<T> eventType, @NonNull EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(@NonNull Class<T> eventType, @NonNull EditorEventListener<T> listener)
public void flush()
```

`flush()` applies pending updates (decoration / layout / scroll / selection) and triggers redraw. For batched decoration updates, call `flush()` once at the end.

### Performance Debug

```java
public void setPerfOverlayEnabled(boolean enabled)
public boolean isPerfOverlayEnabled()
```

When enabled, the top-right corner shows live stats such as FPS, build/draw/total cost, measure stats, and last input event cost. Default is off; use only for debugging.

### Styles / Decorations / Folding / Linked Editing

```java
public void registerStyle(int styleId, int color, int backgroundColor, int fontStyle)
public void registerStyle(int styleId, int color, int fontStyle)
public void setLineSpans(int line, SpanLayer layer, List<? extends StyleSpan> spans)
public void setBatchLineSpans(int layer, @Nullable SparseArray<? extends List<? extends StyleSpan>> spansByLine)

public void setLineInlayHints(int line, @NonNull List<? extends InlayHint> hints)
public void setBatchLineInlayHints(@Nullable SparseArray<? extends List<? extends InlayHint>> hintsByLine)
public void setLinePhantomTexts(int line, @NonNull List<? extends PhantomText> phantoms)
public void setBatchLinePhantomTexts(@Nullable SparseArray<? extends List<? extends PhantomText>> phantomsByLine)
public void clearHighlights()
public void clearHighlights(SpanLayer layer)
public void clearInlayHints()
public void clearPhantomTexts()
public void clearAllDecorations()

public void setLineDiagnostics(int line, @NonNull List<? extends DiagnosticItem> items)
public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends DiagnosticItem>> diagsByLine)
public void clearDiagnostics()

public void setMaxGutterIcons(int count)
public void setLineGutterIcons(int line, @NonNull List<? extends GutterIcon> icons)
public void setBatchLineGutterIcons(@Nullable SparseArray<? extends List<? extends GutterIcon>> iconsByLine)
public void clearGutterIcons()

public void setIndentGuides(@NonNull List<IndentGuide> guides)
public void setBracketGuides(@NonNull List<BracketGuide> guides)
public void setFlowGuides(@NonNull List<FlowGuide> guides)
public void setSeparatorGuides(@NonNull List<SeparatorGuide> guides)
public void clearGuides()

public void setFoldRegions(@NonNull List<? extends FoldRegion> regions)
public boolean toggleFoldAt(int line)
public boolean foldAt(int line)
public boolean unfoldAt(int line)
public void foldAll()
public void unfoldAll()
public boolean isLineVisible(int line)

public EditorCore.TextEditResult insertSnippet(String snippetTemplate)
public void startLinkedEditing(LinkedEditingModel model)
public boolean isInLinkedEditing()
public boolean linkedEditingNext()
public boolean linkedEditingPrev()
public void cancelLinkedEditing()
```

## `EditorCore` Key Notes

- `EditorCore` also exposes low-level bracket highlight APIs:
  - `setBracketPairs(int[] openChars, int[] closeChars)`
  - `setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol)`
  - `clearMatchedBrackets()`
- `setCompositionEnabled/isCompositionEnabled` is currently not a public control-layer API (`SweetEditor` can access it internally).
- Android main path does not go through `c_api.h`, but complex return data still uses the shared binary payload decoding flow.
- Decoration APIs also provide `ByteBuffer payload` overloads (`EditorCore` layer), which can skip object boxing and reduce JNI round trips.

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

## Key Types

Located in `com.qiplat.sweeteditor.core.foundation` and `com.qiplat.sweeteditor.core.adornment`:

- `FoldArrowMode`
- `WrapMode`
- `AutoIndentMode`
- `ScrollBehavior`
- `SpanLayer`
- `SeparatorStyle`

Font-style bit flag constants: `com.qiplat.sweeteditor.core.FontStyle`.
