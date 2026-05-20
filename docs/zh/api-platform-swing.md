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

## 快速开始

### 环境要求（按当前仓库配置）

- JDK：`22`
- Gradle Wrapper：`8.10`
- 运行参数：`--enable-native-access=ALL-UNNAMED`
- 当前 demo 配置默认开启 `--enable-preview`

### 在仓库内直接运行 Demo

```bash
cd platform/Swing
./gradlew :demo:run
```

Windows PowerShell 可用：

```powershell
cd platform/Swing
.\gradlew.bat :demo:run
```

### 在现有 Java Swing 项目中接入

推荐使用 Maven Central 依赖：

```gradle
repositories {
    mavenCentral()
}

dependencies {
    implementation("com.qiplat:sweeteditor-swing:0.0.1")
}
```

Maven（pom.xml）可使用：

```xml
<dependency>
    <groupId>com.qiplat</groupId>
    <artifactId>sweeteditor-swing</artifactId>
    <version>0.0.1</version>
    <scope>compile</scope>
</dependency>
```
> 仓库内模块版本当前为 `0.0.1`；如果通过 Maven Central 接入，请替换为你实际要使用的发布版本。

运行 JVM 需开启：

```text
--enable-native-access=ALL-UNNAMED
```

如果使用仓库源码模块（本地联调场景）：

```gradle
dependencies {
    implementation(project(":sweeteditor"))
}
```

### 最小集成示例

```java
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

import javax.swing.JFrame;
import javax.swing.SwingUtilities;

SwingUtilities.invokeLater(() -> {
    JFrame frame = new JFrame("SweetEditor");
    frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

    SweetEditor editor = new SweetEditor(EditorTheme.dark());
    editor.loadDocument(new Document("Hello, SweetEditor!"));

    frame.setContentPane(editor);
    frame.setSize(1000, 700);
    frame.setLocationRelativeTo(null);
    frame.setVisible(true);
});
```

### 说明

- `EditorNative` 会按顺序尝试加载本地库：`-Dsweeteditor.lib.path` -> 源码候选目录 -> JAR 内 native 自动解压 -> `java.library.path`。
- Maven 发布场景可选调用 `NativeLibraryExtractor.extractToDefaultDir()` 预先解压本地库。

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

`flush()` 是强制刷新 / 兼容入口。正常编辑、装饰、滚动和选区路径会通过统一分发 `EditorActionResult`，并由 `needsRedraw` 决定是否刷新 render model 与重绘；宿主通常不需要在批量装饰更新后手动调用。

### 编辑 / 行操作 / 撤销重做

```java
public EditorCore.EditorActionResult insertText(String text)
public EditorCore.EditorActionResult replaceText(TextRange range, String newText)
public EditorCore.EditorActionResult deleteText(TextRange range)

public EditorCore.EditorActionResult moveLineUp()
public EditorCore.EditorActionResult moveLineDown()
public EditorCore.EditorActionResult copyLineUp()
public EditorCore.EditorActionResult copyLineDown()
public EditorCore.EditorActionResult deleteLine()
public EditorCore.EditorActionResult insertLineAbove()
public EditorCore.EditorActionResult insertLineBelow()

public EditorCore.EditorActionResult undo()
public EditorCore.EditorActionResult redo()
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
public void registerTextStyle(int styleId, int color, int bgColor, int fontStyle)
public void registerTextStyle(int styleId, int color, int fontStyle)
public void registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles)
public void setLineSpans(int line, int layer, List<? extends StyleSpan> spans)
public void setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine)

public void setLineInlayHints(int line, List<? extends InlayHint> hints)
public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine)
public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms)
public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine)
public void setLineCodeLens(int line, List<? extends CodeLensItem> items)
public void setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine)
public void clearCodeLens()
public void setLineLinks(int line, List<? extends LinkSpan> links)
public void setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine)
public String getLinkTargetAt(int line, int column)
public void clearLinks()

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

public EditorCore.EditorActionResult insertSnippet(String snippetTemplate)
public void startLinkedEditing(LinkedEditingModel model)
public boolean isInLinkedEditing()
public boolean linkedEditingNext()
public boolean linkedEditingPrev()
public void cancelLinkedEditing()
```

`CodeLensClickEvent` 和 `LinkClickEvent` 通过泛型 `subscribe(...)` 事件总线分发。`getLinkTargetAt(...)` 在请求位置未命中 link 时返回空字符串。

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
