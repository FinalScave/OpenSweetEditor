# Android 平台 API

安装、环境要求、依赖坐标和构建命令请阅读 [Android README](../../platform/Android/sweeteditor/README.md)。本文只记录当前面向宿主的公开 API。

## 公开入口

- Android View：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- 运行时设置：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/EditorSettings.java`
- 主题、语言、Metadata、图标和快捷键类型：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor`
- Provider 与 UI 扩展：`completion`、`decoration`、`newline`、`copilot`、`selection` 和 `contextmenu` 包
- 事件：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/event`
- 高级原生桥接：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`

应用代码以 `SweetEditor` 为主要入口。外观和行为选项通过 `editor.getSettings()` 配置。Android 生命周期覆写和 View 内部刷新回调不属于宿主 API，因此下文不列出。

## 最小示例

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

创建 `SweetEditor` 会初始化 `EditorCore`，后者自动加载 `libsweeteditor`。独立使用的 `Document` 构造函数会直接调用 JNI；如果在任何 `SweetEditor` 或 `EditorCore` 实例创建前构造 `Document`，应先调用 `System.loadLibrary("sweeteditor")`。

## `SweetEditor`

### 构造与配置

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

`LanguageConfiguration` 包含语言 ID、括号对、自动闭合对、Tab 宽度和空格缩进设置。`EditorMetadata` 是可供 Provider 读取的宿主自定义不透明值。

### 文本编辑与行命令

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

`applyTextEdits(...)` 在一次操作中应用多项编辑，编辑范围使用原始文档坐标。

### 搜索与替换

```java
public void search(SearchRequest request)
public void findNextSearchMatch()
public void findPreviousSearchMatch()
public void replaceCurrentSearchMatch(String replacement)
public void replaceAllSearchMatches(String replacement)
public void clearSearch()
public SearchState getSearchState()
```

`SearchOptions` 支持区分大小写、全词、正则表达式、循环查找和最大匹配数量。

### 光标、选区、剪贴板与导航

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

### 样式与 Decoration

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

`SpanLayer` 包含语法、语义和 overlay 三层。字体样式位标志为 `TextStyle.NORMAL`、`TextStyle.BOLD`、`TextStyle.ITALIC` 和 `TextStyle.STRIKETHROUGH`。

### 折叠、Snippet 与 Linked Editing

```java
public void setFoldRegions(@Nullable List<? extends FoldRegion> regions)
public void toggleFoldAt(int line)
public void foldAt(int line)
public void unfoldAt(int line)
public void foldAll()
public void unfoldAll()
public boolean isLineVisible(int line)

public void insertSnippet(String snippetTemplate)
public void startLinkedEditing(List<TabStopGroup> groups)
public boolean isInLinkedEditing()
public void linkedEditingNext()
public void linkedEditingPrev()
public void cancelLinkedEditing()
```

### Provider 与编辑器浮层

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

### 事件与诊断

```java
public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener)
public void flush()
public void setPerfOverlayEnabled(boolean enabled)
public boolean isPerfOverlayEnabled()
```

公开事件包括：

- `TextChangedEvent`、`CursorChangedEvent`、`SelectionChangedEvent`、`ScrollChangedEvent` 和 `ScaleChangedEvent`
- `DocumentLoadedEvent` 和 `FoldToggleEvent`
- `GutterIconClickEvent`、`InlayHintClickEvent`、`CodeLensClickEvent` 和 `LinkClickEvent`
- `LongPressEvent`、`DoubleTapEvent` 和 `ContextMenuEvent`
- `SelectionMenuItemClickEvent` 和 `ContextMenuItemClickEvent`

inline suggestion 的接受和关闭通过 `InlineSuggestionListener` 回调，不走通用事件总线。`flush()` 是强制刷新和诊断入口，普通编辑与 decoration 更新无需调用。性能浮层默认关闭，仅用于调试。

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

## 扩展契约

### Decoration

`DecorationProvider` 接收包含可见行范围、总行数、文本变化、语言配置和 Metadata 的 `DecorationContext`，并可通过 `DecorationReceiver` 异步提交快照；过期 Receiver 会进入取消状态。

`DecorationResult` 支持语法、语义和 overlay span、inlay hint、diagnostic、文档高亮、折叠区域、缩进线、括号线、流程线、分隔线、gutter icon、phantom text、CodeLens 和链接。每一类均支持 `MERGE`、`REPLACE_ALL` 和 `REPLACE_RANGE` 应用模式。

### 补全与换行

`CompletionProvider` 接收光标、当前行、单词范围、语言、Metadata 和触发信息，并可提交可取消的异步结果。补全项支持主文本编辑、附加编辑、snippet、过滤、排序、类型和自定义条目视图。

`NewLineActionProvider` 是用于定制 Enter 插入文本的同步调用链。

### 菜单与 Inline Suggestion

Selection Menu Provider 构建移动端选区操作；Context Menu Provider 为长按或右键请求构建分组菜单；inline suggestion 以 phantom text 展示，并通过 `InlineSuggestionListener` 报告接受和关闭操作。

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

## Android 平台行为

- 使用 Android Canvas 和 Paint 渲染，同时支持等宽与非等宽字体。
- `InputConnection` 负责组合输入、周边文本、选区同步、批量编辑和软键盘生命周期。
- View 集成触摸、鼠标、滚轮、悬停、拖动选区、缩放、选择手柄、剪贴板、补全面板、Selection Menu 和 Context Menu。
- Android 库提供 `arm64-v8a` 和 `x86_64` 原生库；当前 SDK、NDK 和发布配置请以 README 为准。

## 高级 `EditorCore`

`EditorCore` 是公开的低层 Java/JNI 桥接，供需要直接访问 render model、IME、手势或预打包 decoration 的宿主使用。普通应用应使用 `SweetEditor` 和 `EditorSettings`。Android 通过 JNI 直连共享 C++ 核心；ABI 与核心行为请参考 [EditorCore / C API 文档](./api-editor-core.md)。
