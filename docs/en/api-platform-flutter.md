# Flutter API

For installation, Dart and Flutter requirements, native asset synchronization, and demo commands, see the [Flutter README](../../platform/Flutter/sweeteditor/README.md). This page documents the current widget and controller API.

## Public Surface and Imports

- Package entry: `platform/Flutter/sweeteditor/lib/sweeteditor.dart`
- Widget: `platform/Flutter/sweeteditor/lib/widget/sweet_editor_widget.dart`
- Controller: `platform/Flutter/sweeteditor/lib/widget/sweet_editor_controller.dart`
- Runtime settings: `platform/Flutter/sweeteditor/lib/editor_settings.dart`
- Providers and extensions: `completion`, `decoration`, `newline`, `copilot`, and `selection` directories
- Events: `platform/Flutter/sweeteditor/lib/event/editor_event.dart`
- Advanced FFI bridge: `platform/Flutter/sweeteditor/lib/core/editor_core.dart`
- Native asset hook: `platform/Flutter/sweeteditor/hook/build.dart`

The main library exports the widget-layer API. Several controller methods use core types such as `Document`, `TextPosition`, `TextRange`, `TextEdit`, and `SearchRequest`; import the core library when using those methods:

```dart
import 'package:sweeteditor/sweeteditor.dart';
import 'package:sweeteditor/core/editor_core.dart' as core;
```

## Minimal Usage

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

`SweetEditorWidget` creates and releases the native editor session. Keep its controller stable while the widget is mounted; a detached controller cannot be rebound to another editor instance.

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

Use either `document` or `text` as the initial content. Declarative inputs are applied when the widget creates its session and when supported inputs change. A `Document` supplied by the application is borrowed; the widget does not dispose it.

## `SweetEditorController`

### Lifecycle, Documents, and Configuration

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

`getSettings()` becomes available after the widget has attached. `LanguageConfiguration` carries the language id, bracket pairs, auto-closing pairs, tab size, and spaces-for-tabs behavior. `EditorMetadata` is an opaque application-defined value available to providers.

### Text Editing and Line Commands

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

The range and coordinate forms shown for `replaceText` and `deleteText` are both accepted. `applyTextEdits(...)` uses the original document coordinates.

### Search and Replace

```dart
void search(core.SearchRequest request)
void findNextSearchMatch()
void findPreviousSearchMatch()
void replaceCurrentSearchMatch(String replacement)
void replaceAllSearchMatches(String replacement)
void clearSearch()
core.SearchState getSearchState()
```

Search options support case sensitivity, whole-word matching, regular expressions, wrap-around, and a maximum match count.

### Cursor, Selection, and Navigation

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

Clipboard copy, cut, and paste are integrated through built-in keyboard commands, platform text actions, and the selection menu; the controller does not expose separate clipboard methods.

### Styles and Decorations

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

`core.SpanLayer` contains syntax, semantic, and overlay layers. `getLinkTargetAt(...)` returns an empty string when no link matches the position.

### Folding

```dart
void setFoldRegions(List<core.FoldRegion> regions)
void toggleFoldAt(int line)
void foldAt(int line)
void unfoldAt(int line)
void foldAll()
void unfoldAll()
```

Snippet insertion enters linked editing when the template contains tab stops. Direct linked-editing model control is available on the advanced `core.EditorCore` API.

### Providers and Editor Overlays

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

### Event Streams

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

Inline suggestion acceptance and dismissal use `InlineSuggestionListener`, not an event stream. A context-menu gesture is published as an event; Flutter does not currently provide the Android context-menu popup/provider API. `flush()` is a force-refresh and diagnostic entry point; normal updates do not require it.

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

Settings supplied to the widget are copied into the editor session. Use the bound settings returned by the controller for runtime changes. `copy()` and `replaceFrom(...)` support settings composition. Session binding and default seeding are widget lifecycle details, not host API.

## Extension Contracts

### Decorations

`DecorationProvider` receives a `DecorationContext` containing the visible line range, total line count, text changes, language configuration, and metadata. It may publish asynchronous snapshots through `DecorationReceiver`; stale receivers become cancelled.

`DecorationResult` supports syntax, semantic, and overlay spans; inlay hints; diagnostics; document highlights; fold regions; indent, bracket, flow, and separator guides; gutter icons; phantom text; CodeLens; and links. Each category has merge, replace-all, and replace-range application modes.

### Completion and Newline Actions

`CompletionProvider` receives cursor, current-line, word-range, language, metadata, and trigger information. It may publish cancellable asynchronous results. Completion items support a primary text edit, additional edits, snippets, filtering, sorting, kinds, and a custom Flutter item builder.

`NewLineActionProvider` is a synchronous chain used to customize the text inserted for Enter.

### Selection Menu and Inline Suggestions

`SelectionMenuItemProvider` builds the mobile selection menu from current selection state. Inline suggestions display phantom text and an action bar; acceptance and dismissal are reported through `InlineSuggestionListener`.

## Flutter Behavior

| Area | Android / iOS mobile behavior | Desktop behavior |
| --- | --- | --- |
| Text input | Platform text input and soft keyboard; Android enables the delta input model | Platform text input without a soft keyboard request |
| Pointer | Touch gestures and pinch scaling | Mouse pointer, wheel input, Ctrl-wheel scaling, and trackpad pan/zoom |
| Selection | Selection handles and floating selection menu | No floating mobile selection menu |
| Gutter | Non-sticky by default | Sticky by default |
| Scrollbar | Transient, draggable scrollbar with a larger mobile hit area | Transient, draggable scrollbar with desktop geometry |
| Default monospace family | Platform-resolved family | Consolas on Windows, Menlo on macOS, platform default elsewhere |

Completion and inline suggestion overlays are available on supported mobile and desktop targets; they do not have separate platform-specific provider contracts.

## Native Assets and Supported Targets

The Dart code-assets hook selects a bundled native library for:

- Windows x64
- Linux x64 and arm64
- Android `arm64-v8a` and `x86_64`
- macOS x64 and arm64
- iOS device arm64 and simulator arm64

See the README for the synchronization command and current package setup.

## Advanced `core.EditorCore` and `core.Document`

`core.EditorCore` is the low-level Dart FFI API for direct render-model, IME, gesture, raw decoration, scrollbar, and linked-editing control. Normal Flutter applications should use `SweetEditorWidget` and `SweetEditorController`.

```dart
core.Document.fromString(String text)
core.Document.fromFile(String path)
String get text
int get lineCount
String getLineText(int line)
void close()
void dispose()
```

Documents and low-level editor instances own native handles and must be disposed. A `Document` created by `loadText(...)` is managed internally, while a `Document` passed to the widget or `loadDocument(...)` remains caller-owned and must stay alive until the editor stops using it. Core ABI concepts are described in the [EditorCore / C API reference](./api-editor-core.md).
