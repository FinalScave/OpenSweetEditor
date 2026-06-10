# Android 平台 API

本文档对应当前 Android 实现：

- 控件层：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/SweetEditor.java`
- 桥接层：`platform/Android/sweeteditor/src/main/java/com/qiplat/sweeteditor/core/EditorCore.java`
- JNI 层：`platform/Android/sweeteditor/src/main/cpp/jni_entry.cpp`
- 直连头：`platform/Android/sweeteditor/src/main/cpp/jeditor.hpp`

## 架构说明

- Android 侧主路径是 JNI 直连 C++（不是通过 `c_api.h`）。
- `EditorCore` 在 JNI 边界保留 `int` 原生协议。
- `buildRenderModel()`、`EditorActionResult`、滚动度量等复杂返回当前仍通过二进制协议返回，再由 `CoreProtocol` 解码。
- `SweetEditor` 对外提供语义化枚举 API（`WrapMode`/`FoldArrowMode`/`AutoIndentMode` 等）。

## 快速开始

### 环境要求（按当前仓库配置）

- Android Gradle Plugin：`8.1.3`
- Gradle Wrapper：`8.5`
- `compileSdk 34` / `minSdk 21`
- NDK：`28.2.13676358`

### 在仓库内直接运行 Demo

```bash
cd platform/Android
./gradlew :app:assembleDebug
```

Windows PowerShell 可用：

```powershell
cd platform/Android
.\gradlew.bat :app:assembleDebug
```

### 在现有 Android 项目中接入

推荐直接使用 Maven Central 依赖：

```gradle
repositories {
    mavenCentral()
    google()
}

dependencies {
    implementation("com.qiplat:sweeteditor:1.0.6")
}
```
> 依赖版本以最新版为准，当前为1.0.6
  
如果使用仓库源码模块（本地联调场景）：

1. 在 `settings.gradle` 包含模块：

```gradle
include(":sweeteditor")
```

2. 在应用模块添加本地模块依赖：

```gradle
dependencies {
    implementation(project(":sweeteditor"))
}
```

- 如果你复制了 `sweeteditor` 到不同目录层级，记得同步调整
   `platform/Android/sweeteditor/build.gradle` 里的 `externalNativeBuild.cmake.path`（当前指向 `../../../CMakeLists.txt`）。

### 最小集成示例

布局（XML）：

```xml
<com.qiplat.sweeteditor.SweetEditor
    android:id="@+id/editor"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

初始化（Java）：

```java
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;

SweetEditor editor = findViewById(R.id.editor);
editor.applyTheme(EditorTheme.dark());
editor.loadDocument(new Document("Hello, SweetEditor!"));
```

### 说明

- 不需要手动 `System.loadLibrary("sweeteditor")`，`EditorCore` 静态块已处理。
- 当前默认 ABI 过滤为 `arm64-v8a`、`x86_64`；如需其他 ABI，请在 `sweeteditor/build.gradle` 的 `ndk.abiFilters` 中调整。

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

这里列出的是 `SweetEditor` view 方法。底层 `EditorCore` 调用仍返回 `EditorActionResult`，view 会在内部统一分发这些结果。

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
public void setLineCodeLens(int line, @NonNull List<? extends CodeLensItem> items)
public void setBatchLineCodeLens(@Nullable SparseArray<? extends List<? extends CodeLensItem>> itemsByLine)
public void clearCodeLens()
public void setLineLinks(int line, @NonNull List<? extends LinkSpan> links)
public void setBatchLineLinks(@Nullable SparseArray<? extends List<? extends LinkSpan>> linksByLine)
public String getLinkTargetAt(int line, int column)
public void clearLinks()

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

`flush()` 是强制刷新 / 诊断入口。正常编辑、装饰、滚动、选区和 IME 同步路径会通过统一分发 `EditorActionResult`，并由 `needsRedraw` 决定是否刷新 render model 与重绘；宿主通常不需要在批量装饰更新后手动调用。

`CodeLensClickEvent` 与 `LinkClickEvent` 也通过同一个泛型 `subscribe(...)` API 分发。`getLinkTargetAt(...)` 在请求位置未命中 link 时返回空字符串。

### 补全触发规则

| 入口 | 触发方式 | TriggerKind | 说明 |
| --- | --- | --- | --- |
| 手动调用 | `triggerCompletion()` | `INVOKED` | 直接请求补全 |
| 快捷键 | `Ctrl + Space` | `INVOKED` | 最终同样调用 `triggerCompletion()` |
| 自动触发入口 | `dispatchTextChanged` | 见下表 | 按优先级短路判断 |

自动触发优先级（短路顺序，命中即停止）：

| 顺序 | 条件 | TriggerKind | 额外信息 |
| --- | --- | --- | --- |
| 1 | `isInLinkedEditing()==true` | 不触发 | 联动编辑模式跳过自动补全 |
| 2 | 主变更为单字符，且命中任一 Provider 的 trigger character | `CHARACTER` | 透传 `triggerCharacter` |
| 3 | 主变更为单字符，且补全面板已显示 | `RETRIGGER` | 面板已开时重触发 |
| 4 | 主变更为单字符，且字符为字母/数字/`_` | `INVOKED` | 常规字符输入触发 |
| 5 | 主变更非单字符，且补全面板已显示 | `RETRIGGER` | 非单字符变更时仅在面板已显示下重触发 |

| 规则类型 | 条件 | 行为 |
| --- | --- | --- |
| 防抖 | `INVOKED` | 0ms（立即触发） |
| 防抖 | `CHARACTER` / `RETRIGGER` | 50ms |
| 键盘交互 | `Up/Down` / `Enter` / `Escape` | 切换候选 / 确认 / 关闭 |
| 手势交互 | `TAP` 或 `SCROLL` | 关闭当前补全面板 |

### 性能调试

```java
public void setPerfOverlayEnabled(boolean enabled)
public boolean isPerfOverlayEnabled()
```

`setPerfOverlayEnabled(true)` 后，会在编辑区**左上角**显示实时性能面板（默认关闭，仅建议调试使用）。

> 实现细节说明（v1.0.6 当前实现）：以下字段名、阈值和步骤名用于调试展示，不属于稳定 API 契约；版本升级后请以代码与发布说明为准。

面板字段（当前实现）：

| 字段标签 | 含义 |
| --- | --- |
| `FPS` | 实时帧率 |
| `Frame: total/build/draw` | 单帧总耗时、build 耗时、draw 耗时 |
| `Step: ...` | 分阶段渲染耗时 |
| `measure{...}` | text/inlay/icon 测量统计 |
| `Input[tag]: ...` | 最近输入路径耗时 |

可视标记阈值（当前实现）：

| 维度 | 条件 | 面板标记 |
| --- | --- | --- |
| 慢帧 | `total > 16.6ms` | `Frame` 行追加 `SLOW` |
| 慢渲染步骤 | 单步骤耗时 `>= 2ms` | 该步骤追加 `!` |
| 慢输入路径 | 输入耗时 `> 3ms` | `Input` 行追加 `SLOW` |

日志阈值（当前实现）：

| 日志类别 | 条件 | 输出说明 |
| --- | --- | --- |
| `[PERF][SLOW]` 输入日志 | 输入慢路径 `>= 3ms` | 记录慢输入路径 |
| `[PERF][Build]` 日志 | build `>= 8ms` 或测量统计达到阈值 | 周期输出，默认每 60 帧检查一次 |

### 样式 / 装饰 / 折叠 / 联动编辑

```java
public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle)
public void registerTextStyle(int styleId, int color, int fontStyle)
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

public void setLineDiagnostics(int line, @NonNull List<? extends Diagnostic> items)
public void setBatchLineDiagnostics(@Nullable SparseArray<? extends List<? extends Diagnostic>> diagsByLine)
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

public EditorCore.EditorActionResult insertSnippet(String snippetTemplate)
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
- 可编辑状态下始终支持 IME composition；只读模式负责阻止文本变更。
- Android `InputConnection` 必须覆盖 selection、batch edit、surrounding text、empty commit、`newCursorPosition`、`setComposingRegion`、`finishComposingText`、subtype 脚本判定和 stale connection 处理。
- `commitText("")` 在活动 composing session 内是空文本替换，不是 finish/cancel。
- `setSelection` 与 cursor movement 必须同步给 core；batch edit 期间应延迟渲染刷新和 `updateSelection`。
- `isAsciiCapable()` 不得单独推断 Latin 输入态。
- 平台层处理 tap 时应通知系统 IME view clicked，并随后同步 selection / surrounding text。
- `setComposingRegion` 是 IME 明确声明的 composition range，即使 cursor 不在该 range 内也必须接收；平台层只能裁剪到合法文档范围，不能用 cursor containment 拒绝。
- surrounding text 必须来自文档全局 UTF-16 offset，并保留跨行上下文。
- `setComposingText` 和 `setComposingRegion` 是 Android composition 的事实来源；没有这两类声明时不得显示 composition。
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
