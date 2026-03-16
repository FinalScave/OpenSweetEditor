# Swing 平台 API

本文档对应当前 Swing 实现：

- 控件层：`platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- 桥接层：`platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
- FFM 层：`platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorNative.java`
- 文档对象：`platform/Swing/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/Document.java`

## 架构说明

- Swing 通过 Java FFM 调用 C API。
- `EditorCore` 负责 upcall 测量回调 + 二进制 payload 解码。
- 当前桥接协议为二进制 payload。
- `SweetEditor` 提供语义化控件 API（枚举）并处理 Swing 输入事件。

## 公开控件层：`SweetEditor`

### 构造与基础

```java
public SweetEditor()
public SweetEditor(EditorTheme theme)
public void loadDocument(Document document)
public EditorTheme getEditorTheme()
public void applyTheme(EditorTheme theme)
public EditorCore getEditorCore()
public void flush()
```

`flush()` 用于提交待处理更新（装饰 / 布局 / 滚动 / 选区）并触发重绘。装饰批量更新时，建议在最后手动调用一次 `flush()`。

### 编辑 / 行操作 / 撤销重做

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

### 光标选区 / 导航 / 外观

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

### 语言配置 / 元数据 / 扩展 Provider

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

### 样式 / 装饰 / 折叠 / 联动编辑

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

## 桥接层说明

- `EditorCore` / `EditorNative` 已包含括号高亮能力：
  - `setBracketPairs(int[] openChars, int[] closeChars)`
  - `setMatchedBrackets(...)`
  - `clearMatchedBrackets()`
- 控件层通常通过 `setLanguageConfiguration(...)` 触发括号对下发。
- `Document` 当前公开 `getLineText(int)` 与 `getLineCount()` 两个读取入口。

## `Document`

```java
public Document(String text)
public long getHandle()
public String getLineText(int line)
public int getLineCount()
public void close()
```
