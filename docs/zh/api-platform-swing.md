# Swing API

安装、环境要求、构建命令、运行参数和依赖坐标见 [Swing README](../../platform/Swing/sweeteditor/README.md)。

本文档说明 `platform/Swing/sweeteditor` 当前真实公开的 API。

## 最小集成

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

Java 22 运行时必须启用 native access。本地库加载顺序为 `sweeteditor.lib.path`、匹配的 JAR 内资源自动解压，最后通过 `System.loadLibrary` 回退到 `java.library.path`。

## `SweetEditor`

### 构造与核心配置

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

`flush()` 用于诊断场景下强制刷新渲染模型。正常编辑、滚动、选区、Provider 和装饰操作会自动重绘。

### 文本编辑、行操作与剪贴板

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

`applyTextEdits(...)` 接收基于原始文档坐标且互不重叠的编辑，并把实际内容变更归为一次撤销操作。

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

`SearchOptions` 支持区分大小写、全词、正则表达式、循环搜索和最大匹配数。`SearchState` 会返回状态、匹配数、当前匹配、generation 和错误信息。

### 光标、选区、导航与几何信息

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

没有选区时，`getSelection()` 返回 `null`。`getLinkTargetAt(...)` 等字符串查询在没有结果时返回空字符串。

### 样式、装饰与折叠

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

组件可渲染语法、语义和 overlay spans，以及 Inlay Hint、Phantom Text、CodeLens、链接、诊断、文档高亮、gutter 图标、折叠区域和 indent、bracket、flow、separator guides。

### Snippet、联动编辑与 Inline Suggestion

```java
public void insertSnippet(String snippetTemplate)
public void startLinkedEditing(LinkedEditingModel model)
public boolean isInLinkedEditing()
public void linkedEditingNext()
public void linkedEditingPrev()
public void cancelLinkedEditing()

public void showInlineSuggestion(InlineSuggestion suggestion)
public void dismissInlineSuggestion()
public boolean isInlineSuggestionShowing()
public void setInlineSuggestionListener(InlineSuggestionListener listener)
```

Snippet 插入支持 tab stops。Inline Suggestion 显示时，Tab 接受建议，Escape 关闭建议。

### Provider 与补全

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

- 补全 Provider 接收主动触发、触发字符或 retrigger 上下文，并通过可取消 receiver 返回结果。`CompletionItem.textEdit` 定义主替换范围，`additionalTextEdits` 使用原始文档坐标；snippet 格式的补全项会进入 snippet 模式。
- 装饰 Provider 会收到可见行范围、累计文本变更、语言配置和编辑器元数据，可按 merge、replace-all 或 replace-range 模式返回语法、语义、overlay、Inlay Hint、诊断、文档高亮、guide、折叠、gutter 图标、Phantom Text、CodeLens 和链接数据。
- New-line action Provider 组成责任链。首个返回 action 的 Provider 决定 Enter 插入的文本；返回 `null` 时继续交给后续 Provider 或编辑器默认行为。

### 事件总线

```java
public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener)
public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener)
```

类型化事件总线会发布 `TextChangedEvent`、`CursorChangedEvent`、`SelectionChangedEvent`、`ScrollChangedEvent`、`ScaleChangedEvent`、`DocumentLoadedEvent`、`LongPressEvent`、`DoubleTapEvent`、`ContextMenuEvent`、`InlayHintClickEvent`、`GutterIconClickEvent`、`FoldToggleEvent`、`CodeLensClickEvent` 和 `LinkClickEvent`。

## `EditorSettings`

通过 `editor.getSettings()` 访问设置。

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

## Keymap 与语言配置

`EditorKeyMap.defaultKeyMap()`、`vscode()`、`jetbrains()` 和 `sublime()` 可创建内置映射。宿主可以增删 `KeyBinding`，并通过 `registerCommand(...)` 注册快捷键处理器。

使用 `LanguageConfiguration.Builder` 构造语言配置。它描述语言 ID、括号对、自动闭合对、行注释、块注释、Tab 宽度和以空格代替 Tab 的偏好。括号、自动闭合和缩进配置会影响编辑行为；Completion、Decoration 和 New-line Provider 也可读取完整配置。

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

`Document` 通过 `Cleaner` 释放 native handle，不公开 `close()` 方法。

## Swing 输入行为

- 键盘输入使用当前 `EditorKeyMap`；补全和 Inline Suggestion 会先拦截自身的导航或确认按键，再处理普通编辑器命令。
- 鼠标按下、拖动、悬停、右键和滚轮输入用于选区、滚动、链接、CodeLens、gutter 图标、折叠和上下文菜单。
- 剪贴板操作使用 AWT 系统剪贴板。
- Java 输入法通过 `InputMethodRequests` 提供 preedit、提交、取消、光标几何、surrounding text 和 selected text。
