# Flutter API

安装、Dart 与 Flutter 要求、原生资产同步和 Demo 命令请阅读 [Flutter README](../../platform/Flutter/sweeteditor/README.md)。本文只记录当前 Widget 和 Controller 公开 API。

## 公开入口与导入方式

- 包入口：`platform/Flutter/sweeteditor/lib/sweeteditor.dart`
- Widget：`platform/Flutter/sweeteditor/lib/widget/sweet_editor_widget.dart`
- Controller：`platform/Flutter/sweeteditor/lib/widget/sweet_editor_controller.dart`
- 运行时设置：`platform/Flutter/sweeteditor/lib/editor_settings.dart`
- Provider 与扩展：`completion`、`decoration`、`newline`、`copilot` 和 `selection` 目录
- 事件：`platform/Flutter/sweeteditor/lib/event/editor_event.dart`
- 高级 FFI 桥接：`platform/Flutter/sweeteditor/lib/core/editor_core.dart`
- 原生资产 Hook：`platform/Flutter/sweeteditor/hook/build.dart`

主库导出 Widget 层 API。部分 Controller 方法使用 `Document`、`TextPosition`、`TextRange`、`TextEdit` 和 `SearchRequest` 等 core 类型，使用这些方法时还需要导入 core 库：

```dart
import 'package:sweeteditor/sweeteditor.dart';
import 'package:sweeteditor/core/editor_core.dart' as core;
```

## 最小示例

```dart
final controller = SweetEditorController();

Widget buildEditor() {
  return SweetEditorWidget(
    controller: controller,
    text: 'Hello, SweetEditor!',
    theme: EditorTheme.dark(),
  );
}
```

`SweetEditorWidget` 创建并释放原生编辑器会话。Widget 挂载期间应保持 Controller 实例稳定；已经解绑的 Controller 不能重新绑定到其他编辑器实例。

## `SweetEditorWidget`

```dart
const SweetEditorWidget({
  Key? key,
  required SweetEditorController controller,
  core.Document? document,
  String? text,
  EditorTheme? theme,
  EditorSettings? settings,
  EditorKeyMap? keyMap,
  EditorIconProvider? iconProvider,
  LanguageConfiguration? languageConfiguration,
  EditorMetadata? metadata,
  String fontFamily = 'monospace',
  double fontSize = 14,
  bool autofocus = true,
})
```

初始内容使用 `document` 或 `text` 其中之一。Widget 创建会话时会应用声明式参数，并在受支持的参数发生变化时同步更新。应用传入的 `Document` 只会被借用，Widget 不会替调用方释放。

## `SweetEditorController`

### 生命周期、文档与配置

```dart
bool get isAttached
void whenReady(VoidCallback callback)

void loadDocument(core.Document document)
void loadText(String text)
core.Document? getDocument()
String getContent()
int get lineCount
String getLineText(int line)

EditorSettings? get settings
EditorSettings? getSettings()
LanguageConfiguration? get languageConfiguration
set languageConfiguration(LanguageConfiguration? value)
LanguageConfiguration? getLanguageConfiguration()
void setLanguageConfiguration(LanguageConfiguration? value)
EditorMetadata? get metadata
set metadata(EditorMetadata? value)
EditorMetadata? getMetadata()
void setMetadata(EditorMetadata? value)

EditorKeyMap getKeyMap()
void setKeyMap(EditorKeyMap keyMap)
void setEditorIconProvider(EditorIconProvider? provider)
void applyTheme(EditorTheme theme)
void setTheme(EditorTheme theme)
EditorTheme? getTheme()
```

`getSettings()` 在 Widget 完成绑定后可用。`LanguageConfiguration` 包含语言 ID、括号对、自动闭合对、Tab 宽度和空格缩进设置。`EditorMetadata` 是可供 Provider 读取的宿主自定义不透明值。

### 文本编辑与行命令

```dart
void insertText(String text)
void insertTextAt(core.TextPosition position, String text)
void replaceText(core.TextRange range, String text)
void replaceText(int startLine, int startColumn, int endLine, int endColumn, String text)
void deleteText(core.TextRange range)
void deleteText(int startLine, int startColumn, int endLine, int endColumn)
void applyTextEdits(List<core.TextEdit> edits)
void insertSnippet(String snippetTemplate)

void moveLineUp()
void moveLineDown()
void copyLineUp()
void copyLineDown()
void deleteLine()
void insertLineAbove()
void insertLineBelow()

void undo()
void redo()
bool get canUndo
bool get canRedo
```

`replaceText` 和 `deleteText` 同时支持上方列出的 range 与坐标调用形式。`applyTextEdits(...)` 使用原始文档坐标。

### 搜索与替换

```dart
void search(core.SearchRequest request)
void findNextSearchMatch()
void findPreviousSearchMatch()
void replaceCurrentSearchMatch(String replacement)
void replaceAllSearchMatches(String replacement)
void clearSearch()
core.SearchState getSearchState()
```

搜索选项支持区分大小写、全词、正则表达式、循环查找和最大匹配数量。

### 光标、选区与导航

```dart
core.TextPosition getCursorPosition()
void setCursorPosition(core.TextPosition position)
void setCursorPosition(int line, int column)
void gotoPosition(int line, int column)

core.TextRange? getSelection()
void setSelection(int startLine, int startColumn, int endLine, int endColumn)
void selectAll()
String getSelectedText()
bool get hasSelection
core.TextRange getWordRangeAtCursor()
String getWordAtCursor()

core.ScrollMetrics getScrollMetrics()
void setScroll(double scrollX, double scrollY)
void scrollToLine(int line, {core.ScrollBehavior behavior = core.ScrollBehavior.gotoCenter})
core.CursorRect getPositionRect(int line, int column)
core.CursorRect getCursorRect()
core.IntRange getVisibleLineRange()
int getTotalLineCount()
int get totalLineCount
bool isLineVisible(int line)
```

剪贴板复制、剪切和粘贴通过内置快捷键、平台文本操作和 Selection Menu 集成；Controller 不单独公开剪贴板方法。

### 样式与 Decoration

```dart
void registerTextStyle(int styleId, int color, {int backgroundColor = 0, int fontStyle = 0})
void registerBatchTextStyles(Map<int, core.TextStyle> stylesById)

void setLineSpans(int line, core.SpanLayer layer, List<core.StyleSpan> spans)
void setBatchLineSpans(core.SpanLayer layer, Map<int, List<core.StyleSpan>> spansByLine)
void setLineInlayHints(int line, List<core.InlayHint> hints)
void setBatchLineInlayHints(Map<int, List<core.InlayHint>> hintsByLine)
void setLinePhantomTexts(int line, List<core.PhantomText> phantoms)
void setBatchLinePhantomTexts(Map<int, List<core.PhantomText>> phantomsByLine)
void setLineGutterIcons(int line, List<core.GutterIcon> icons)
void setBatchLineGutterIcons(Map<int, List<core.GutterIcon>> iconsByLine)
void setLineCodeLens(int line, List<core.CodeLensItem> items)
void setBatchLineCodeLens(Map<int, List<core.CodeLensItem>> itemsByLine)
void setLineLinks(int line, List<core.LinkSpan> links)
void setBatchLineLinks(Map<int, List<core.LinkSpan>> linksByLine)
String getLinkTargetAt(int line, int column)
void setLineDiagnostics(int line, List<core.Diagnostic> items)
void setBatchLineDiagnostics(Map<int, List<core.Diagnostic>> itemsByLine)
void setLineDocumentHighlights(int line, List<core.DocumentHighlight> items)
void setBatchLineDocumentHighlights(Map<int, List<core.DocumentHighlight>> itemsByLine)

void setIndentGuides(List<core.IndentGuide> guides)
void setBracketGuides(List<core.BracketGuide> guides)
void setFlowGuides(List<core.FlowGuide> guides)
void setSeparatorGuides(List<core.SeparatorGuide> guides)
void setMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn)
void clearMatchedBrackets()

void clearHighlights([core.SpanLayer? layer])
void clearInlayHints()
void clearPhantomTexts()
void clearGutterIcons()
void clearCodeLens()
void clearLinks()
void clearGuides()
void clearDiagnostics()
void clearDocumentHighlights()
void clearAllDecorations()
```

`core.SpanLayer` 包含语法、语义和 overlay 三层。`getLinkTargetAt(...)` 在请求位置没有链接时返回空字符串。

### 折叠

```dart
void setFoldRegions(List<core.FoldRegion> regions)
void toggleFoldAt(int line)
void foldAt(int line)
void unfoldAt(int line)
void foldAll()
void unfoldAll()
```

如果 snippet 模板包含 tab stop，插入后会进入 linked editing。直接控制 linked-editing model 需要使用高级 `core.EditorCore` API。

### Provider 与编辑器浮层

```dart
void addDecorationProvider(DecorationProvider provider)
void removeDecorationProvider(DecorationProvider provider)
void requestDecorationRefresh()

void addCompletionProvider(CompletionProvider provider)
void removeCompletionProvider(CompletionProvider provider)
void triggerCompletion()
void showCompletionItems(List<CompletionItem> items)
void dismissCompletion()
void setCompletionItemRenderer(CompletionItemWidgetBuilder? renderer)
bool get isCompletionShowing

void addNewLineActionProvider(NewLineActionProvider provider)
void removeNewLineActionProvider(NewLineActionProvider provider)

void showInlineSuggestion(InlineSuggestion suggestion)
void dismissInlineSuggestion()
bool get isInlineSuggestionShowing
void setInlineSuggestionListener(InlineSuggestionListener? listener)

void setSelectionMenuItemProvider(SelectionMenuItemProvider? provider)
void flush()
```

### 事件 Stream

```dart
Stream<TextChangedEvent> get onTextChanged
Stream<CursorChangedEvent> get onCursorChanged
Stream<SelectionChangedEvent> get onSelectionChanged
Stream<ScrollChangedEvent> get onScrollChanged
Stream<ScaleChangedEvent> get onScaleChanged
Stream<LongPressEvent> get onLongPress
Stream<DoubleTapEvent> get onDoubleTap
Stream<ContextMenuEvent> get onContextMenu
Stream<GutterIconClickEvent> get onGutterIconClick
Stream<InlayHintClickEvent> get onInlayHintClick
Stream<CodeLensClickEvent> get onCodeLensClick
Stream<LinkClickEvent> get onLinkClick
Stream<FoldToggleEvent> get onFoldToggle
Stream<DocumentLoadedEvent> get onDocumentLoaded
Stream<SelectionMenuItemClickEvent> get onSelectionMenuItemClick
```

inline suggestion 的接受和关闭通过 `InlineSuggestionListener` 回调，不属于事件 Stream。右键菜单手势以事件公开；Flutter 当前不提供 Android 的 Context Menu Popup/Provider API。`flush()` 是强制刷新和诊断入口，普通更新无需调用。

## `EditorSettings`

```dart
EditorSettings()
EditorSettings copy()
void replaceFrom(EditorSettings other)

void setEditorTextSize(double size)
double getEditorTextSize()
void setFontFamily(String fontFamily)
String getFontFamily()
void setScale(double scale)
double getScale()

void setFoldArrowMode(core.FoldArrowMode mode)
core.FoldArrowMode getFoldArrowMode()
void setWrapMode(core.WrapMode mode)
core.WrapMode getWrapMode()
void setRenderWhitespace(core.WhitespaceRenderMode mode)
core.WhitespaceRenderMode getRenderWhitespace()
void setRenderLineBreaks(bool enabled)
bool isRenderLineBreaks()
void setLineSpacing(double add, double mult)
double getLineSpacingAdd()
double getLineSpacingMult()
void setContentStartPadding(double padding)
double getContentStartPadding()
void setShowSplitLine(bool show)
bool isShowSplitLine()
void setGutterSticky(bool sticky)
bool isGutterSticky()
void setGutterVisible(bool visible)
bool isGutterVisible()
void setCurrentLineRenderMode(core.CurrentLineRenderMode mode)
core.CurrentLineRenderMode getCurrentLineRenderMode()

void setAutoIndentMode(core.AutoIndentMode mode)
core.AutoIndentMode getAutoIndentMode()
void setBackspaceUnindent(bool enabled)
bool isBackspaceUnindent()
void setReadOnly(bool readOnly)
bool isReadOnly()
void setMaxGutterIcons(int count)
int getMaxGutterIcons()

void setDecorationScrollRefreshMinIntervalMs(int intervalMs)
int getDecorationScrollRefreshMinIntervalMs()
void setDecorationOverscanViewportMultiplier(double multiplier)
double getDecorationOverscanViewportMultiplier()
```

传给 Widget 的 Settings 会复制到编辑器会话中。运行时修改应使用 Controller 返回的已绑定 Settings。`copy()` 和 `replaceFrom(...)` 用于组合配置。会话绑定与默认值填充属于 Widget 生命周期细节，不是宿主 API。

## 扩展契约

### Decoration

`DecorationProvider` 接收包含可见行范围、总行数、文本变化、语言配置和 Metadata 的 `DecorationContext`，并可通过 `DecorationReceiver` 异步提交快照；过期 Receiver 会进入取消状态。

`DecorationResult` 支持语法、语义和 overlay span、inlay hint、diagnostic、文档高亮、折叠区域、缩进线、括号线、流程线、分隔线、gutter icon、phantom text、CodeLens 和链接。每一类均支持 merge、replace-all 和 replace-range 应用模式。

### 补全与换行

`CompletionProvider` 接收光标、当前行、单词范围、语言、Metadata 和触发信息，并可提交可取消的异步结果。补全项支持主文本编辑、附加编辑、snippet、过滤、排序、类型和自定义 Flutter 条目构建器。

`NewLineActionProvider` 是用于定制 Enter 插入文本的同步调用链。

### Selection Menu 与 Inline Suggestion

`SelectionMenuItemProvider` 根据当前选区状态构建移动端选择菜单。inline suggestion 展示 phantom text 和操作条，并通过 `InlineSuggestionListener` 报告接受和关闭操作。

## Flutter 行为

| 范围 | Android / iOS 移动端行为 | 桌面端行为 |
| --- | --- | --- |
| 文本输入 | 平台文本输入与软键盘；Android 启用 delta input model | 平台文本输入，不主动请求软键盘 |
| 指针 | 触摸手势与双指缩放 | 鼠标指针、滚轮、Ctrl+滚轮缩放和触控板 pan/zoom |
| 选区 | 选择手柄与浮动 Selection Menu | 不显示移动端浮动 Selection Menu |
| Gutter | 默认不固定 | 默认固定 |
| Scrollbar | 瞬态、可拖动，并扩大移动端命中区域 | 瞬态、可拖动，使用桌面端尺寸 |
| 默认等宽字体 | 按平台解析 | Windows 使用 Consolas，macOS 使用 Menlo，其他平台使用默认等宽字体 |

补全面板和 inline suggestion 浮层在受支持的移动端与桌面端均可用，但 Provider 契约没有平台差异。

## 原生资产与支持目标

Dart code-assets Hook 会为以下目标选择随包原生库：

- Windows x64
- Linux x64 和 arm64
- Android `arm64-v8a` 和 `x86_64`
- macOS x64 和 arm64
- iOS device arm64 和 simulator arm64

同步命令和当前包配置请以 README 为准。

## 高级 `core.EditorCore` 与 `core.Document`

`core.EditorCore` 是低层 Dart FFI API，用于直接控制 render model、IME、手势、原始 decoration、scrollbar 和 linked editing。普通 Flutter 应用应使用 `SweetEditorWidget` 与 `SweetEditorController`。

```dart
core.Document.fromString(String text)
core.Document.fromFile(String path)
String get text
int get lineCount
String getLineText(int line)
void close()
void dispose()
```

Document 与低层编辑器实例拥有原生句柄，必须释放。`loadText(...)` 创建的 `Document` 由内部管理；传给 Widget 或 `loadDocument(...)` 的 `Document` 仍由调用方持有，并且必须存活到编辑器停止使用它。核心 ABI 概念请参考 [EditorCore / C API 文档](./api-editor-core.md)。
