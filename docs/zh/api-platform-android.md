# Android 平台 API

本文档对应当前 Android 实现：

- 控件层：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- 桥接层：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
- JNI 层：`platform/Android/sweeteditor/src/main/cpp/jni_entry.cpp`
- 直连头：`platform/Android/sweeteditor/src/main/cpp/jeditor.hpp`

## 架构说明

- Android 侧主路径是 JNI 直连 C++（不是通过 `c_api.h`）。
- `EditorCore` 在 JNI 边界保留 `int` 原生协议。
- `buildRenderModel()`、手势结果、键盘结果、文本编辑结果、滚动度量当前仍通过二进制协议返回，再由 `ProtocolDecoder` 解码。
- `SweetEditor` 对外提供语义化枚举 API（`WrapMode`/`FoldArrowMode`/`AutoIndentMode` 等）。

## 公开控件层：`SweetEditor`

### 构造

```java
public SweetEditor(Context context)
public SweetEditor(Context context, AttributeSet attrs)
public SweetEditor(Context context, AttributeSet attrs, int defStyleAttr)
```

### 文档与外观

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

### 文本编辑 / 行操作 / 撤销重做

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

### 剪贴板 / 导航 / 光标选区

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

### 只读 / 语言配置 / 扩展 Provider

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

`flush()` 用于提交待处理更新（装饰 / 布局 / 滚动 / 选区）并触发重绘。装饰批量更新时，建议在最后手动调用一次 `flush()`。

### 性能调试

```java
public void setPerfOverlayEnabled(boolean enabled)
public boolean isPerfOverlayEnabled()
```

启用后会在控件右上角显示 FPS、build/draw/total 耗时、测量统计、最近输入事件耗时等实时信息。默认关闭，仅建议用于调试。

### 样式 / 装饰 / 折叠 / 联动编辑

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

## `EditorCore` 关键补充

- `EditorCore` 还公开括号高亮相关低层接口：
  - `setBracketPairs(int[] openChars, int[] closeChars)`
  - `setMatchedBrackets(int openLine, int openCol, int closeLine, int closeCol)`
  - `clearMatchedBrackets()`
- `setCompositionEnabled/isCompositionEnabled` 目前在控件层不是公开 API（`SweetEditor` 内部可访问）。
- Android 主路径虽不经过 `c_api.h`，但复杂返回仍走统一的 binary payload 解码流程。
- 装饰相关接口同时提供 `ByteBuffer payload` 重载（`EditorCore` 层），可用于绕过对象装箱并减少 JNI 往返。

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

## 关键类型

位于 `com.qiplat.sweeteditor.core.foundation` 与 `com.qiplat.sweeteditor.core.adornment`：

- `FoldArrowMode`
- `WrapMode`
- `AutoIndentMode`
- `ScrollBehavior`
- `SpanLayer`
- `SeparatorStyle`

字体位标志常量：`com.qiplat.sweeteditor.core.FontStyle`。
